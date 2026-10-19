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

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SCHEDULER_SHA = "adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def pins(directory):
    return {p.relative_to(directory).as_posix(): sha(p)
            for p in directory.rglob("*") if p.is_file() and ".godot" not in p.parts}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--candidate", action="store_true")
    parser.add_argument("--case", choices=["recovery","pause","cancel","closed","revoke","player","retire","watch"], default="recovery")
    parser.add_argument("--project", type=Path, default=ROOT / "outputs/coordinator31_release57/game")
    args = parser.parse_args()
    assert re.fullmatch(r"[a-zA-Z0-9_-]+", args.name)
    scheduler = ROOT / "tools/godot/test_scheduler.py"
    assert sha(scheduler) == SCHEDULER_SHA, "Scheduler drift: review before launching"
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease

    project = args.project.resolve()
    run = HERE / "runs" / args.name
    run.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((HERE / "PATCH.json").read_text(encoding="utf-8-sig")) if args.candidate else {}
    for rel, hashes in manifest.items():
        assert sha(HERE / "patch" / rel) == hashes["candidate_sha256"], rel
        if hashes["base_sha256"]:
            assert sha(project / rel) == hashes["base_sha256"], "Unexpected base source: " + rel
        else:
            assert not (project / rel).exists(), "Baseline already contains candidate: " + rel

    sources = pins(project)
    assert sources == json.loads((ROOT/"outputs/coordinator31_release57/ASSEMBLY.json").read_text(encoding="utf-8-sig"))["source_pins"]
    harness = {p.relative_to(HERE).as_posix(): sha(p) for p in HERE.rglob("*")
               if p.is_file() and "runs" not in p.parts and p.suffix in (".gd", ".py") and (args.candidate or "patch" not in p.parts) and p.name not in ["prepare_fixture31.py", "derive_cause31.py", "build_patch31.py"]}
    save(run / "SOURCE.json", sources)
    save(run / "HARNESS.json", harness)
    with zipfile.ZipFile(run / "HARNESS.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for rel in harness:
            archive.write(HERE / rel, rel)

    exe = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
    lock = json.loads((ROOT / "docs/godot/ENGINE_LOCK.json").read_text(encoding="utf-8-sig"))
    assert sha(exe) == lock["editor"]["gui"]["sha256"]
    cmd = [str(exe), "--headless", "--path", str(project), "--script", str(HERE / "entry.gd"),
           "--", "--candidate31=" + str(int(args.candidate)), "--qa-out=" + str(run), "--door-case="+args.case]
    record = {"candidate": args.candidate, "project": str(project), "access": "read",
              "command": cmd, "passed": False, "scheduler_sha256": SCHEDULER_SHA,
              "engine_sha256": sha(exe), "full_city_acceptance": False, "performance_accepted": False}
    child = None
    try:
        with Lease("headless", project, "read", 60) as lease:
            record["lease"] = lease.request
            started = time.monotonic()
            with (run / "stdout.log").open("wb") as stdout, (run / "stderr.log").open("wb") as stderr:
                child = subprocess.Popen(cmd, cwd=project, stdout=stdout, stderr=stderr,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    record["child"] = lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic() - started > 90:
                            raise TimeoutError("Owned native child timeout")
                        if (run / "stderr.log").stat().st_size:
                            raise RuntimeError("Native script stderr")
                        time.sleep(.1)
                finally:
                    if child.poll() is None:
                        child.terminate()
                        child.wait(timeout=10)
                record.update(exit_code=child.returncode, wall_s=time.monotonic() - started)
        logs = [(run / name).read_text(encoding="utf-8-sig", errors="replace")
                for name in ("stdout.log", "stderr.log")]
        record["errors"] = [line for log in logs for line in log.splitlines()
                            if re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", line)]
        native = json.loads((run / "NATIVE31.json").read_text(encoding="utf-8"))
        record["native_checks"] = native["checks"]
        record["native_sha256"] = sha(run / "NATIVE31.json")
    except Exception as error:
        record["error"] = type(error).__name__ + ": " + str(error)
    finally:
        current = pins(project)
        save(run / "SOURCE_AFTER.json", current)
        record["source_drift"] = sorted(rel for rel in sources.keys() | current.keys()
                                         if sources.get(rel) != current.get(rel))
        record["harness_drift"] = [rel for rel, expected in harness.items()
                                    if not (HERE / rel).exists() or sha(HERE / rel) != expected]
        record["execution_clean"] = (record.get("exit_code") == 0 and not record.get("error")
                                     and not record.get("errors") and not record["source_drift"]
                                     and not record["harness_drift"]
                                     and (run / "stderr.log").exists()
                                     and (run / "stderr.log").stat().st_size == 0)
        record["passed"] = record["execution_clean"] and bool(record.get("native_checks")) and all(record["native_checks"].values())
        save(run / "RUN.json", record)
    print(json.dumps({key: record.get(key) for key in ("candidate", "passed", "execution_clean", "error", "wall_s", "source_drift", "harness_drift", "native_checks")}))
    raise SystemExit(0 if record["execution_clean"] else 2)
