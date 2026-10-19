"""Run only the owned small fixture against read-only accepted57 sources."""
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
PROJECT = ROOT / "outputs/coordinator31_release57/game"
SCHEDULER_SHA = "adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373"
PHYSICS_PINS = {
    "scripts/hospital/npc_physical_route51.gd": "ce8bca0c9d45b88ae45ec3973544838267ef88db2d62911f781e25bed6b7168f",
    "scripts/hospital/npc_walk_surface28.gd": "fe28870674944d9b9fc45f338a40f4ced0dfd9e312a7e44fcb3ffc6e416192b1",
    "scripts/navigation/npc_passage31.gd": "49ab9e218f37aac086dfe2fd3817f08b759cf2ecb1dc41091cce97c29a5b518e",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def pins(directory):
    return {p.relative_to(directory).as_posix(): sha(p) for p in directory.rglob("*")
            if p.is_file() and ".godot" not in p.parts}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--algorithm", choices=["custom", "rvo"], required=True)
    parser.add_argument("--case-set", choices=["smoke", "full"], default="full")
    parser.add_argument("--mode", choices=["headless", "graphical"], default="headless")
    args = parser.parse_args()
    assert re.fullmatch(r"[A-Za-z0-9_-]+", args.name)
    scheduler = ROOT / "tools/godot/test_scheduler.py"
    assert sha(scheduler) == SCHEDULER_SHA
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    for rel, expected in PHYSICS_PINS.items():
        assert sha(PROJECT / rel) == expected, "Accepted physics source drift: " + rel
    run = HERE / "runs" / args.name
    run.mkdir(parents=True, exist_ok=False)
    source = pins(PROJECT)
    harness = {p.relative_to(HERE).as_posix(): sha(p) for p in HERE.rglob("*")
               if p.is_file() and "runs" not in p.parts and p.suffix in [".py", ".gd"]}
    controls = {rel: sha(ROOT / rel) for rel in ["godot/current_version.json", ".vscode/launch.json"] if (ROOT / rel).exists()}
    save(run / "SOURCE.json", source); save(run / "HARNESS.json", harness); save(run / "CONTROL_PINS.json", controls)
    with zipfile.ZipFile(run / "HARNESS.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for rel in harness: archive.write(HERE / rel, rel)
    exe = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
    lock = json.loads((ROOT / "docs/godot/ENGINE_LOCK.json").read_text(encoding="utf-8-sig"))
    assert sha(exe) == lock["editor"]["gui"]["sha256"]
    command = [str(exe)] + (["--headless"] if args.mode == "headless" else ["--resolution", "640x480"])
    command += ["--path", str(PROJECT), "--script", str(HERE / "entry31.gd"), "--",
                "--algorithm=" + args.algorithm, "--case-set=" + args.case_set, "--qa-out=" + str(run)]
    record = {"algorithm":args.algorithm, "case_set":args.case_set, "mode":args.mode,
              "project":str(PROJECT), "access":"read", "command":command,
              "scheduler_sha256":SCHEDULER_SHA, "engine_sha256":sha(exe), "passed":False,
              "full_city_acceptance":False, "performance_accepted":False, "harness_archive_sha256":sha(run / "HARNESS.zip")}
    child = None
    try:
        with Lease(args.mode, PROJECT, "read", 90) as lease:
            assert pins(PROJECT) == source, "Source drift during lease wait"
            record["lease"] = lease.request
            with (run / "stdout.log").open("wb") as stdout, (run / "stderr.log").open("wb") as stderr:
                started = time.monotonic()
                child = subprocess.Popen(command, cwd=PROJECT, stdout=stdout, stderr=stderr,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    record["child"] = lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic() - started > 120:
                            raise TimeoutError("Owned small fixture exceeded120s")
                        if (run / "stderr.log").stat().st_size:
                            raise RuntimeError("Native stderr; preserving failed run")
                        time.sleep(.1)
                finally:
                    if child.poll() is None:
                        child.terminate(); child.wait(timeout=10)
                record.update(exit_code=child.returncode, wall_s=time.monotonic()-started)
        logs = [(run / name).read_text(encoding="utf-8-sig", errors="replace") for name in ["stdout.log", "stderr.log"]]
        record["errors"] = [line for log in logs for line in log.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", line)]
        native = json.loads((run / "NATIVE.json").read_text(encoding="utf-8-sig"))
        record["checks"] = native["checks"]
        record["native_sha256"] = sha(run / "NATIVE.json")
    except Exception as error:
        record["error"] = type(error).__name__ + ": " + str(error)
    finally:
        after = pins(PROJECT); save(run / "SOURCE_AFTER.json", after)
        record["source_drift"] = sorted(rel for rel in source.keys() | after.keys() if source.get(rel) != after.get(rel))
        record["harness_drift"] = [rel for rel, expected in harness.items() if not (HERE / rel).exists() or sha(HERE / rel) != expected]
        record["control_drift"] = [rel for rel, expected in controls.items() if not (ROOT / rel).exists() or sha(ROOT / rel) != expected]
        record["stderr_bytes"] = (run / "stderr.log").stat().st_size if (run / "stderr.log").exists() else None
        record["execution_clean"] = (record.get("exit_code") == 0 and not record.get("error") and not record.get("errors")
            and not record["source_drift"] and not record["harness_drift"] and not record["control_drift"] and record["stderr_bytes"] == 0)
        record["passed"] = record["execution_clean"] and bool(record.get("checks")) and all(record["checks"].values())
        save(run / "RUN.json", record)
    print(json.dumps({key:record.get(key) for key in ["algorithm","case_set","passed","execution_clean","error","wall_s","checks"]}))
    return 0 if record["execution_clean"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
