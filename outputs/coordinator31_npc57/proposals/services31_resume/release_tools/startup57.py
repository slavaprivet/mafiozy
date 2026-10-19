"""Check frozen57 bootstrap. Default is a read-only plan; --go runs one bounded child.

Never changes F5/current_version, the candidate, a source file, or Git.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import zipfile

from freeze57 import ROOT, HERE, RELEASE, REVISION, TITLE, SCHEDULER_SHA
from freeze57 import need, read, sha, save, pins, inside, city_flags, all_pins, unchanged


def validate_release(release):
    need(release == RELEASE, "Only the new immutable coordinator31_release57 is accepted")
    pointer_path = release / "PROPOSED_CURRENT.json"
    pointer = read(pointer_path)
    need(pointer.get("schema") == "mafiozi.current-play/v1", "Proposed pointer schema")
    assembly_path = inside(ROOT / pointer["assembly"])
    bootstrap = inside(ROOT / pointer["bootstrap"])
    need(assembly_path.parent == bootstrap.parent == release, "Pointer escapes release57")
    need(sha(assembly_path) == pointer["assembly_sha256"] and sha(bootstrap) == pointer["bootstrap_sha256"], "Release control hash mismatch")
    assembly = read(assembly_path)
    acceptance = read(release / "ACCEPTANCE.json")
    need(pointer.get("revision") == assembly.get("revision") == REVISION and pointer.get("title") == TITLE, "Release identity mismatch")
    need(assembly.get("requested_population") == 10 and assembly.get("staff") == 12 and assembly.get("catalogue_count") == 287, "Expected10 active residents,12 staff,287 catalogue")
    need(assembly.get("performance_accepted") is True and assembly.get("full_city_performance_accepted") is False, "Batch performance acceptance missing")
    project = inside(ROOT / assembly["game_relative"])
    need(project == release / "game", "Unexpected release game path")
    expected = assembly["source_pins"]
    need(assembly.get("source_count") == len(expected) and pins(project) == expected == acceptance.get("release_source_pins"), "Release source mismatch")
    tested = acceptance["tested_source_pins"]
    need(set(tested) == set(expected), "Release source inventory differs from tested source")
    need({key for key in tested if tested[key] != expected[key]} == {"scripts/main.gd", "data/preview_updates.json"}, "Unexpected changes after tests")
    need(acceptance.get("candidate_unchanged") is True, "Candidate copy integrity missing")
    need(sha(release / "EVIDENCE.zip") == acceptance["evidence_archive_sha256"], "Evidence archive hash mismatch")
    evidence = read(release / "EVIDENCE_PINS.json")
    with zipfile.ZipFile(release / "EVIDENCE.zip") as archive:
        need(len(archive.namelist()) == len(set(archive.namelist())) and set(archive.namelist()) == set(evidence), "Evidence archive inventory mismatch")
        need(all(hashlib.sha256(archive.read(name)).hexdigest() == digest for name, digest in evidence.items()), "Evidence archived bytes changed")
    flags = assembly["launch_arguments"]
    city_flags(["engine", "--", *flags])
    packet = read(project / "assets/npc_city/session_packet.json")
    need(len(packet["rows"]) == 287, "Original catalogue count changed")
    wanted = sorted(str(row["source_id"]) for row in packet["rows"][:10])
    return pointer, assembly, bootstrap, project, expected, wanted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", help="Unique receipt directory name")
    parser.add_argument("--release", type=Path, default=RELEASE)
    parser.add_argument("--mode", choices=("headless", "graphical"), default="headless")
    parser.add_argument("--go", action="store_true", help="Run the bounded frozen bootstrap check; never activate F5")
    args = parser.parse_args()
    need(re.fullmatch(r"[A-Za-z0-9_-]+", args.name), "Use a simple unique run name")
    release = inside(args.release)
    pointer, assembly, bootstrap, project, expected, wanted = validate_release(release)
    scheduler = ROOT / "tools/godot/test_scheduler.py"
    lock = ROOT / "docs/godot/ENGINE_LOCK.json"
    engine = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
    need(sha(scheduler) == SCHEDULER_SHA, "Scheduler source changed")
    need(sha(engine) == pointer["engine_sha256"] == read(lock)["editor"]["gui"]["sha256"], "Engine lock mismatch")
    run = HERE / "runs" / args.name
    need(not run.exists(), "Existing evidence is immutable; choose another run name")
    command = [str(engine), *(["--headless"] if args.mode == "headless" else ["--resolution", "1920x1080"]),
               "--path", str(project), "--script", str(bootstrap), "--", *assembly["launch_arguments"],
               "--city-play-check=1", "--qa-out=" + str(run)]
    plan = {"prepared": True, "engine_launched": False, "run": str(run), "command": command,
            "project": str(project), "mode": args.mode, "pointer_activated": False, "candidate_modified": False,
            "scope": "Exact frozen bootstrap readiness only; no FPS or long-soak claim"}
    if not args.go:
        print(json.dumps(plan, ensure_ascii=True))
        return 0
    controls = all_pins([], [ROOT / "godot/current_version.json", release / "PROPOSED_CURRENT.json",
                            release / "ASSEMBLY.json", release / "ACCEPTANCE.json", release / "EVIDENCE_PINS.json",
                            release / "EVIDENCE.zip", bootstrap, scheduler, lock, engine,
                            Path(__file__), HERE / "freeze57.py"])
    run.mkdir(parents=True, exist_ok=False)
    save(run / "SOURCE.json", expected)
    save(run / "CONTROL_PINS.json", controls)
    record = dict(plan, passed=False, performance_accepted=False, scheduler_sha256=SCHEDULER_SHA,
                  engine_sha256=sha(engine), access="read")
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    child = None
    try:
        with Lease(args.mode, project, "read", 30) as lease:
            need(pins(project) == expected and unchanged(controls), "Release/control drift before launch")
            record["lease"] = lease.request
            started = time.monotonic()
            with (run / "stdout.log").open("wb") as stdout, (run / "stderr.log").open("wb") as stderr:
                child = subprocess.Popen(command, cwd=project, stdout=stdout, stderr=stderr,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                record["engine_launched"] = True
                try:
                    record["child"] = lease.register_child(child)
                    while child.poll() is None:
                        need(time.monotonic() - started <= 150, "Owned bootstrap child timed out")
                        need((run / "stderr.log").stat().st_size == 0, "Native bootstrap stderr")
                        time.sleep(.2)
                finally:
                    if child.poll() is None:
                        child.terminate()
                        child.wait(timeout=10)
                record.update(exit_code=child.returncode, wall_s=time.monotonic() - started)
            ready = read(run / "CURRENT_READY.json")
            record["native_sha256"] = sha(run / "CURRENT_READY.json")
            record["resident_count"] = ready.get("resident_count")
            record["staff_count"] = ready.get("staff_count")
            record["revision"] = ready.get("actual_revision")
            record["checks"] = {
                "bootstrap_passed": ready.get("ok") is True,
                "revision": ready.get("revision") == ready.get("actual_revision") == REVISION,
                "exact_counts": ready.get("requested_residents") == ready.get("resident_count") == ready.get("current_resident_count") == ready.get("batch_size") == 10,
                "exact_catalogue_and_roster": ready.get("original_catalogue_count") == 287 and ready.get("exact_roster_complete") is True and ready.get("actual_ids") == wanted,
                "staff_sites_actions": ready.get("staff_count") == 12 and ready.get("new_venues") == 8 and ready.get("ambient_actions") == 18,
                "behavior_enabled": all(ready.get(key) is True for key in ("avoidance", "threat_reactions", "independent_lifecycle", "population_ready")),
                "graphical_capture": args.mode == "headless" or ((run / "opened.png").is_file() and (run / "opened.png").stat().st_size > 0),
            }
    except Exception as error:
        record["error"] = type(error).__name__ + ": " + str(error)
    finally:
        after = pins(project)
        after_controls = {path: sha(path) if Path(path).is_file() else None for path in controls}
        save(run / "SOURCE_AFTER.json", after)
        save(run / "CONTROL_PINS_AFTER.json", after_controls)
        record["source_drift"] = sorted(key for key in set(expected) | set(after) if expected.get(key) != after.get(key))
        record["control_drift"] = sorted(path for path in controls if controls[path] != after_controls[path])
        record["errors"] = [line for name in ("stdout.log", "stderr.log") if (run / name).exists()
                            for line in (run / name).read_text(encoding="utf-8-sig", errors="replace").splitlines()
                            if re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", line)]
        record["stderr_bytes"] = (run / "stderr.log").stat().st_size if (run / "stderr.log").exists() else None
        record["passed"] = (record.get("exit_code") == 0 and not record.get("error") and not record["errors"]
                            and record["stderr_bytes"] == 0 and not record["source_drift"] and not record["control_drift"]
                            and bool(record.get("checks")) and all(record["checks"].values()))
        record["ordinary_ready"] = record["passed"]
        save(run / "RUN.json", record)
    print(json.dumps({key: record.get(key) for key in ("passed", "error", "checks", "source_drift", "control_drift", "pointer_activated")}, ensure_ascii=True))
    return 0 if record["passed"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({"passed": False, "error": str(error), "engine_launched": False, "pointer_activated": False}))
        raise SystemExit(1)
