"""Bounded graphical observation of the preserved step boundary failure."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))

def verify(folder, pins):
    bad = [name for name, pin in pins.items() if digest(folder / name) != pin]
    assert not bad, bad

manifest_path = ROOT / "outputs/coordinator27_step48_native/ASSEMBLY.json"
assert digest(manifest_path) == "83f01445e883e1fa7ee98938d6ae7a19ec2c523938ab6d7ea90ff3b999e31550"
manifest = read(manifest_path)
game = Path(manifest["game"])
base_path = ROOT / "outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json"
assert digest(base_path) == "51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7"
base = read(base_path)
baseline = Path(base["game"])
boundary = ROOT / "outputs/coordinator27_step48_native/runs/boundary01/frozen_helpers/boundary.gd"
assert digest(boundary) == "5911af274a127460b193dbe7dbacdae9f768348a9cf4e3f31bd1b3704cf73781"
copy = HERE / "base_boundary.gd"
if copy.exists():
    assert copy.read_bytes() == boundary.read_bytes()
else:
    copy.write_bytes(boundary.read_bytes())
engine = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
assert digest(engine) == "ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
label = sys.argv[1]
assert label and Path(label).name == label
out = HERE / "runs" / label
out.mkdir(parents=True, exist_ok=False)
pins = {p.name: digest(p) for p in (Path(__file__), copy, HERE / "visual.gd")}
for name in pins:
    (out / name).write_bytes((HERE / name).read_bytes())
record = {"helper_pins": pins, "source_pins": manifest["source_pins"],
          "performance_accepted": False, "production_accepted": False, "execution_verified": False}
try:
    with Lease("graphical", game, "read", 120) as lease:
        verify(game, manifest["source_pins"])
        verify(baseline, base["source_pins"])
        verify(HERE, pins)
        marker = out / "REGISTERED"
        command = [str(engine), "--path", str(game), "--resolution", "960x720", "--windowed",
                   "--script", str(HERE / "visual.gd"), "--", "--out=" + str(out), "--parent-marker=" + str(marker)]
        record.update(command=command, lease=lease.request)
        started = time.monotonic()
        with (out / "stdout.log").open("wb") as stdout, (out / "stderr.log").open("wb") as stderr:
            child = subprocess.Popen(command, cwd=game, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
            record["child"] = lease.register_child(child)
            marker.write_text("registered", encoding="ascii")
            record["exit_code"] = child.wait(timeout=max(0.1, 60 - (time.monotonic() - started)))
        record["seconds"] = time.monotonic() - started
        verify(game, manifest["source_pins"])
        verify(baseline, base["source_pins"])
        verify(HERE, pins)
        record["source_unchanged"] = True
        record["stderr_bytes"] = (out / "stderr.log").stat().st_size
        assert record["stderr_bytes"] == 0
        result = read(out / "RESULT.json")
        record["functional_passed"] = result["passed"]
        record["errors"] = result["errors"]
        record["checks"] = result["checks"]
        assert record["exit_code"] == (0 if result["passed"] else 1)
        captures = read(out / "CAPTURES.json")["captures"]
        assert len(captures) > 0 and all((out / row["image"]).is_file() for row in captures)
        record["capture_count"] = len(captures)
        record["execution_verified"] = True
except Exception as error:
    record["error"] = str(error)
finally:
    (out / "RUN.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps({key: record[key] for key in ("execution_verified", "functional_passed", "errors", "error", "capture_count", "seconds") if key in record}))
sys.exit(0 if record["execution_verified"] else 1)
