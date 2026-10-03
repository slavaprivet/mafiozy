"""Validate this exact saved eight-charge pair; no engine, stage or source edits."""
from pathlib import Path
import copy
import hashlib
import json
import runpy
import sys
import argparse

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load(relative, pin):
    path = ROOT / relative
    assert sha(path) == pin, str(path)
    return runpy.run_path(str(path))

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

parser=argparse.ArgumentParser(); parser.add_argument("--charges",type=int,choices=[1,8],required=True); args=parser.parse_args()
builder = load("outputs/coordinator27_c4_meta_perf/release48/prepare_capture.py", "106d18c19ad740ee78de8986b732834c48a4578eac7233b1002e87c29a2b2690")
strict = load("outputs/coordinator27_c4_47/check_perf47.py", "01d710c8c9ef305f7ef33fbe1c2b1ffa0f311d813b58e75d4a37faed10206b0c")
owner = load("outputs/buildings3_c4_input_perf45/compare_measurements.py", "30ccc46790be08b2d261f13bca240d36a833761af91b1638d8c4f73ab01c9986")
guard = load("outputs/coordinator26_marks37_qa/run37.py", "1687441c667d09ce66e4b0a305e9e69171469f1b5cef265596208a5bdbf07cbf")
# Only the explicitly reviewed derived entry identity differs. All existing
# windows, raw/summary, memory, native input, physics and workload checks remain.
strict["PINS"]["fixture_sha256"] = builder["SETTLED_SHA"]
strict["PINS"]["observer_sha256"] = "77722c376d5dc0e0aaf217039813fd0cad5cf7a57786e3f391e7e538f6716c01"
records, runs, bindings, failures = {}, {}, {}, []
for plan in builder["prepare"]():
    variant = plan["manifest"]["variant"]
    assembly = Path(plan["assembly"])
    assert read(assembly) == plan["manifest"]
    guard["full_pins"](Path(plan["manifest"]["game"]), plan["manifest"]["source_pins"])
    directory = ROOT / ("outputs/coordinator26_frames45/runs/c4_release48_" + variant + str(args.charges) + "_01")
    report, run = read(directory / "RESULT.json"), read(directory / "RUN.json")
    records[variant], runs[variant] = report, run
    failures += strict["validate"](report, run, read(directory / "MEMORY.json"),
        (directory / "stdout.log").read_text(encoding="utf-8-sig"),
        (directory / "stderr.log").read_text(encoding="utf-8-sig"), variant)
    e = report["evidence"]
    assert e["provenance"]["manifest_sha256"] == run["assembly_sha256"] == sha(assembly)
    assert e["provenance"]["checked_sources"] == plan["manifest"]["source_count"]
    if not run["valid_run"]:
        failures.append(variant + ": adapter rejected native run; retained data is diagnostic only")
    assert run["scheduler_mode"] == "perf" and run["perf_environment_clean"]
    assert run["scheduler_sha256"] == "6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9"
    assert e["focus_diagnostic47"]["interrupted"] is False
    assert e["charges"]==args.charges and len(e["settle_after_q47"]) == len(e["hold_diagnostic47"]["holds"]) == args.charges
    assert all(x["accepted"] and x["dropped_events"] == 0 for x in e["hold_diagnostic47"]["holds"])
    assert all(x["stable_frames"] >= 3 and x["actor_drift_m"] < .001 and len(x["samples"]) <= 30 for x in e["settle_after_q47"])
    bindings[variant] = {"assembly": str(assembly), "assembly_sha256": sha(assembly), "run": str(directory),
        "run_sha256": sha(directory / "RUN.json"), "result_sha256": sha(directory / "RESULT.json"),
        "source_count": plan["manifest"]["source_count"]}

views = copy.deepcopy(records)
periodic = {}
for variant, report in views.items():
    periodic[variant] = {}
    for phase in report["evidence"]["phases"]:
        periodic[variant][phase["label"]] = {k: phase["summary"].pop(k) for k in ("process_ms", "physics_ms")}
        for key in ("process_ms", "physics_ms"):
            phase["samples"].pop(key)
        phase["summary"]["wall_frame_ms"] = phase["summary"].pop("frame_ms")
        phase["samples"]["wall_frame_ms"] = phase["samples"].pop("frame_ms")
comparison = owner["compare"](views["baseline"], views["candidate"])
failures += comparison["failures"]
result = {"status": "STRICT_RELEASE48_PAIR_COMPARABLE" if not failures else "NOT_COMPARABLE", "failures": failures,
    "source_bindings": bindings, "comparison": comparison,
    "engine_periodic_max_diagnostics": {"semantics": "Periodic maxima, not individual frame cost or a subtractable CPU/GPU decomposition", "runs": periodic},
    "external_memory": {k: {"baseline": runs["baseline"]["memory_peak"][k], "candidate": runs["candidate"]["memory_peak"][k],
        "delta_mib": (runs["candidate"]["memory_peak"][k]-runs["baseline"]["memory_peak"][k])/1048576} for k in strict["MEMORY"]},
    "assessment_scope": "Accepted45 versus exact release48 full-scene same-count pair with identical QA. Trace snapshot/signature work is restricted to placement holds. Every process frame retains one focus check plus an empty active-hold branch. Authored rows are recorded before timing. Foundation difference is NOT automatically accepted; a separately reviewed predicate is required. All other owner geometry/camera/NPC/settings gates remain unchanged.",
    "performance_accepted": False}
with (HERE / ("COMPARISON"+str(args.charges)+"_RAW.json")).open("x", encoding="utf-8") as stream:
    json.dump(result, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(json.dumps({"status": result["status"], "failures": failures}, ensure_ascii=True))
raise SystemExit(2 if failures else 0)
