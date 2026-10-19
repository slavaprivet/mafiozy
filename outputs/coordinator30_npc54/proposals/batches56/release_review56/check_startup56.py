"""Proposed bounded release-bootstrap check. Dry plan unless --go is supplied."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
SCHEDULER_SHA = "adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob("*")
            if p.is_file() and ".godot" not in p.relative_to(project).parts}


def within_repo(relative):
    path = (ROOT / relative).resolve()
    path.relative_to(ROOT)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name")
    parser.add_argument("--release", type=Path, default=ROOT / "outputs/coordinator30_release56")
    parser.add_argument("--go", action="store_true")
    args = parser.parse_args()
    assert re.fullmatch(r"[A-Za-z0-9_-]+", args.name), "Use a simple unique run name"
    release = args.release.resolve()
    release.relative_to(ROOT)
    pointer_path = release / "PROPOSED_CURRENT.json"
    pointer = read(pointer_path)
    assert pointer["schema"] == "mafiozi.current-play/v1"
    assembly_path = within_repo(pointer["assembly"])
    bootstrap = within_repo(pointer["bootstrap"])
    assert assembly_path.parent == release and bootstrap.parent == release
    assert sha(assembly_path) == pointer["assembly_sha256"]
    assert sha(bootstrap) == pointer["bootstrap_sha256"]
    assembly = read(assembly_path)
    assert pointer["revision"] == assembly["revision"] == "s01-20261015-residents56"
    assert assembly["requested_population"] == 10 and assembly["staff"] == 12
    project = within_repo(assembly["game_relative"])
    assert project == release / "game"
    flags = assembly["launch_arguments"]
    assert isinstance(flags, list) and all(isinstance(f, str) for f in flags)
    assert all(re.fullmatch(r"--city-[a-z0-9-]+(?:=[^\s\"';]+)?", f) for f in flags)
    assert len(flags) == len({f.split("=", 1)[0] for f in flags}), "Duplicate city option"
    required = {"--city-qa=10", "--city-venue-staff29=1", "--city-venue-sites29=1",
                "--city-physical-dispatch30=1", "--city-multi-lifecycle30=1", "--city-threat30=1",
                "--city-hp=100", "--city-simple-hospital=1"}
    assert required.issubset(flags)
    assert not any(f.startswith(("--city-sandbox-seed=", "--city-resident-name=",
                                 "--city-wallet-start=", "--city-energy-start=",
                                 "--city-play-check=", "--city-quit-after=")) for f in flags)
    expected = assembly["source_pins"]
    assert assembly["source_count"] == len(expected)
    assert pins(project) == expected, "Release source pins do not match manifest"
    scheduler = ROOT / "tools/godot/test_scheduler.py"
    assert sha(scheduler) == SCHEDULER_SHA
    engine = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
    engine_sha = sha(engine)
    assert engine_sha == pointer["engine_sha256"] == read(ROOT / "docs/godot/ENGINE_LOCK.json")["editor"]["gui"]["sha256"]
    run = HERE / "runs" / args.name
    assert not run.exists(), "Use a new run name; prior evidence is immutable"
    command = [sys.executable, "-B", str(scheduler), "run", "--mode", "headless",
               "--project", str(project), "--access", "read", "--wait-seconds", "30",
               "--timeout", "150", "--out", str(run / "engine"), "--", str(engine),
               "--headless", "--path", str(project), "--script", str(bootstrap), "--",
               *flags, "--city-play-check=1", "--qa-out=" + str(run)]
    plan = {"prepared": True, "engine_launched": False, "run": str(run),
            "project": str(project), "command": command,
            "scope": "Exact frozen bootstrap, headless readiness only; no activation or FPS claim"}
    if not args.go:
        print(json.dumps(plan, ensure_ascii=True))
        return 0
    run.mkdir(parents=True, exist_ok=False)
    pinned_files = {str(p): sha(p) for p in (pointer_path, assembly_path, bootstrap, scheduler, engine)}
    save(run / "SOURCE.json", expected)
    save(run / "CONTROL_PINS.json", pinned_files)
    record = dict(plan, engine_launched=True, passed=False, performance_accepted=False)
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True)
        (run / "scheduler.stdout.log").write_bytes(result.stdout)
        (run / "scheduler.stderr.log").write_bytes(result.stderr)
        record["scheduler_exit_code"] = result.returncode
        scheduler_result = read(run / "engine/SCHEDULER_RUN.json")
        ready = read(run / "CURRENT_READY.json")
        after = pins(project)
        record["source_drift"] = sorted(k for k in set(expected) | set(after) if expected.get(k) != after.get(k))
        record["control_drift"] = [p for p, digest in pinned_files.items() if sha(Path(p)) != digest]
        checks = {
            "scheduler_passed": result.returncode == 0 and scheduler_result.get("passed") is True,
            "bootstrap_passed": ready.get("ok") is True,
            "revision": ready.get("revision") == ready.get("actual_revision") == assembly["revision"],
            "exact_counts": ready.get("requested_residents") == ready.get("resident_count") == ready.get("current_resident_count") == 10,
            "staff_and_sites": ready.get("staff_count") == 12 and ready.get("new_venues") == 8,
            "behavior_enabled": all(ready.get(k) is True for k in ("avoidance", "threat_reactions", "independent_lifecycle", "population_ready")),
            "source_and_controls_unchanged": not record["source_drift"] and not record["control_drift"],
        }
        record["checks"] = checks
        record["passed"] = all(checks.values())
    except Exception as error:
        record["error"] = str(error)
    finally:
        save(run / "RUN.json", record)
    print(json.dumps({k: v for k, v in record.items() if k != "command"}, ensure_ascii=True))
    return 0 if record["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
