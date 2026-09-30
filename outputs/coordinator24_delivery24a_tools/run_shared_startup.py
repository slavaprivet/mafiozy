"""Prepared post-promotion check; fail before engine start unless exact4after pins match."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
here = Path(__file__).resolve().parent
root = here.parents[1]
game = root / "godot/mafiozi_walk"
manifest_path = root / "outputs/coordinator24_quality/candidate20/INTEGRATION.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
pins = {}
assert len(manifest["changes"]) == 4
for name, row in manifest["changes"].items():
    actual = sha(game / name)
    assert actual == row["after"], "NOT PROMOTED: " + name
    pins[name] = actual
out = args.out.resolve()
assert out.is_relative_to(here) and not out.exists(), "Use a fresh output folder within tools"
out.mkdir(parents=True)
engine = Path.home() / "AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
harness = here / "test_shared_startup24a.gd"
command = [str(engine), "--headless", "--fixed-fps", "60", "--path", str(game),
           "--script", str(harness), "--", "--qa-out=" + str(out)]
start = time.monotonic()
with (out / "engine.log").open("w", encoding="utf-8") as log:
    try:
        run = subprocess.run(command, cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=30)
        result = {"exit_code": run.returncode}
    except subprocess.TimeoutExpired:
        result = {"timeout_seconds": 30}
result.update(seconds=time.monotonic() - start, command=command, before=pins,
              after={name: sha(game / name) for name in pins}, harness_sha256=sha(harness))
result["stable_guarded_sources"] = result["before"] == result["after"]
if (out / "RESULT.json").exists():
    native = json.loads((out / "RESULT.json").read_text(encoding="utf-8"))
    result.update(native_valid=native["valid"], checks=native["checks"], errors=native["errors"])
log_text = (out / "engine.log").read_text(encoding="utf-8")
result["clean_engine_log"] = "SCRIPT ERROR" not in log_text and "ERROR:" not in log_text
result["valid"] = result.get("exit_code") == 0 and result.get("native_valid") is True and result["stable_guarded_sources"] and result["clean_engine_log"]
(out / "RUN.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, ensure_ascii=True))
raise SystemExit(0 if result["valid"] else 1)
