from pathlib import Path
import difflib
import hashlib
import json
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE.with_name("services31")
BASE = ROOT / "outputs/coordinator30_release56/game"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


manifest = read(HERE / "PATCH.json")
old_harness = read(OLD / "runs/candidate04/HARNESS.json")
inherited = {}
diff = []
for rel, values in manifest.items():
    patch = HERE / "patch" / rel
    assert sha(patch) == values["candidate_sha256"] == old_harness["patch/" + rel]
    assert sha(OLD / "patch" / rel) == sha(patch)
    base = BASE / rel
    assert (sha(base) if base.exists() else None) == values["base_sha256"]
    inherited[rel] = {"old": sha(OLD / "patch" / rel), "new": sha(patch), "unchanged": True}
    diff.extend(difflib.unified_diff(base.read_text(encoding="utf-8-sig").splitlines(keepends=True) if base.exists() else [],
                                    patch.read_text(encoding="utf-8-sig").splitlines(keepends=True),
                                    fromfile="a/" + rel if base.exists() else "/dev/null", tofile="b/" + rel))
(HERE / "PASSAGE31.patch").write_text("".join(diff), encoding="utf-8")
results = {}
for name in ("physics_baseline06", "physics_candidate06", "streams_physics_baseline03", "streams_physics_candidate03"):
    run = read(HERE / "runs" / name / "RUN.json")
    native = read(HERE / "runs" / name / "NATIVE31.json")
    assert run["execution_clean"] and not run["source_drift"] and not run["harness_drift"]
    results[name] = {"passed": run["passed"], "execution_clean": run["execution_clean"],
                     "checks": native["checks"], "run_sha256": sha(HERE / "runs" / name / "RUN.json"),
                     "native_sha256": sha(HERE / "runs" / name / "NATIVE31.json"),
                     "source_sha256": sha(HERE / "runs" / name / "SOURCE.json"),
                     "metrics": {key: native[key] for key in ("blocked", "frames", "head_on_frames", "head_on_min_separation_m", "nearest_peer_m", "max_native_step_m", "passage", "movement_frames", "arrived", "positions", "min_cross_pair_m", "physics_hz", "controller_delta", "observed_delta_min", "observed_delta_max", "physics_context_misses", "exit_elapsed_s", "exit_wall_s", "headon_elapsed_s", "headon_wall_s", "movement_elapsed_s", "movement_wall_s") if key in native}}
    assert native["checks"]["native_moves_in_physics_context"] and native["checks"]["fixed_60hz_controller_and_engine"]
assert results["physics_baseline06"]["source_sha256"] == results["physics_candidate06"]["source_sha256"]
assert not results["physics_baseline06"]["passed"] and results["physics_candidate06"]["passed"]
assert all(not results["physics_baseline06"]["checks"][key] for key in (
    "physical_entry_then_exit", "bounded_exit_under_8_seconds", "claim_released_only_after_physical_exit",
    "head_on_both_complete_within_8s", "head_on_actual_overlap"))
assert results["streams_physics_baseline03"]["source_sha256"] == results["streams_physics_candidate03"]["source_sha256"]
assert not results["streams_physics_baseline03"]["passed"] and results["streams_physics_candidate03"]["passed"]
assert results["streams_physics_baseline03"]["checks"]["real_door_open"]
assert not results["streams_physics_baseline03"]["checks"]["two_streams_all_six_complete_under_12s"]
assert not results["streams_physics_baseline03"]["checks"]["all_nine_opposed_pairs_physically_cross"]
with zipfile.ZipFile(HERE / "PASSAGE31_SOURCE.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for rel in manifest:
        archive.write(HERE / "patch" / rel, rel)
acceptance = {"status": "PASS_NATIVE_COMPONENT_READY_FOR_ROOT_INTEGRATION", "date": "2026-10-15",
              "predecessor_thread": "01a13f76-b441-73f2-bcdb-9f85a7a648de", "predecessor_status": "idle/interrupted",
              "predecessor_code_unchanged": inherited, "base": str(BASE), "patch": manifest,
              "patch_manifest_sha256": sha(HERE / "PATCH.json"), "source_zip_sha256": sha(HERE / "PASSAGE31_SOURCE.zip"),
              "unified_diff_sha256": sha(HERE / "PASSAGE31.patch"), "results": results,
              "full_city_acceptance": False, "performance_accepted": False,
              "superseded_timing_runs": {"runs": ["baseline05", "candidate05", "streams_baseline02", "streams_candidate02"], "reason": "Old step waited physics_frame then process_frame, so native movement occurred in process context. Retained as history; only new physics_* pairs support timing/movement acceptance. New step waits only physics_frame and asserts Engine.is_in_physics_frame plus observed 1/60 delta, Engine60/time_scale1; records simulated and wall elapsed separately."},
              "preserved_fixture_failure": {"runs": ["streams_candidate01", "streams_baseline01"], "reason": "Outbound initial poses obstructed real opening leaf sweep before measured travel. Fixture02 opens the real door before initializing the six initial poses and requests it open via native API during the streams. Production unchanged."},
              "limits": ["Native compact service shop fixture; all four actual city services require merged validation.",
                         "Hit ray still reaches peer; no real weapon damage/reaction cycle in this fixture.",
                         "No city FPS claim. Initial poses/reset are allowed only between isolated test cases; measured service/head-on travel is native.",
                         "Scoped zones cover registered live service doors. World/player/door/debris masks unchanged.",
                         "No shared game, frozen release, F5, Git, or user process was changed."]}
save(HERE / "ACCEPTANCE.json", acceptance)
print(json.dumps({"status": acceptance["status"], "acceptance_sha256": sha(HERE / "ACCEPTANCE.json"),
                  "source_zip_sha256": acceptance["source_zip_sha256"], "candidate_checks": len(results["physics_candidate06"]["checks"]), "streams_checks": len(results["streams_physics_candidate03"]["checks"])}))
