"""Finalize the extension handoff only after the native child has terminated."""
from pathlib import Path
import hashlib
import json
from collections import Counter

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
RUN = OUT / "runs/release57_1200_01"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    run, analysis, slow, cycles = (read(RUN / file) for file in ("RUN.json", "ANALYSIS.json", "SLOW_PLANNER31.json", "CYCLES31.json"))
    assert "exit_code" in run, "No native terminal exit yet"
    assembly = read(ROOT / "outputs/coordinator31_release57/ASSEMBLY.json")
    temporal = read(RUN / "TEMPORAL_AUDIT31.json")
    failed = [row for row in analysis["per_id"] if row["max_motion_idle_s"] > 10 or row["max_queue_idle_s"] > 30]
    geometry = {}
    for actor in failed:
        relevant = [row for row in slow["samples"] if row["actor"]["id"] == actor["id"] and row["actor"]["generation"] == actor["generation"]]
        geometry[actor["id"]] = {"native_slow_snapshot_count":len(relevant), "first":relevant[0] if relevant else None, "last":relevant[-1] if relevant else None,
                                  "outer_phase_counts":dict(Counter(row["actor"]["outer_phase"] for row in relevant)),
                                  "door_stage_counts":dict(Counter(row["actor"]["door_stage"] for row in relevant))}
    report = {
        "schema":"mafiozi.qa31.extended-handoff/v1", "passed":run["passed"], "performance_accepted":False,
        "scope":"Exact released57,10 original residents plus12staff, natural headless1200-second extension alongside user game. Previous acceptance evidence remains immutable.",
        "source_pins_match_release_assembly_before_and_after":all(read(RUN/file) == assembly["source_pins"] for file in ("SOURCE.json", "SOURCE_AFTER.json")),
        "native_elapsed_seconds":temporal["actual_frame_timeline_end_s"], "physical_ticks":run["physical_ticks_observed"],
        "physical_ticks_per_wall_second":temporal["physical_ticks_per_observation_second"], "render_samples":analysis["render_frames"],
        "temporal_audit":temporal,
        "actor_samples":analysis["sample_count"], "moved_residents":analysis["moved_residents"], "gates_s":{"required_motion":10,"queue":30},
        "failures":run["soak_errors"], "failed_actor_summaries":failed, "failed_actor_slow_geometry":geometry,
        "completion_deltas":{key:sum(row["completion_deltas_within_measurement"].get(key,0) for row in analysis["per_id"]) for key in ("shop", "walk", "restaurant", "bank", "hospital")},
        "full_shopping_cycles_with_native_log_entry_payment_exit":cycles["full_observed_shopping_cycles"],
        "log_counts":analysis["matching_log_line_counts"], "native_memory_object_trends":analysis["native_trends"], "os_memory_trends":analysis["os_trends"],
        "stderr_bytes":run["stderr_bytes"], "source_control_harness_drift":{key:run[key] for key in ("source_drift", "control_drift", "harness_drift")},
        "harness_archive":read(RUN / "HARNESS_ARCHIVE.json"),
        "evidence_sha256":{name:hashlib.sha256((RUN/name).read_bytes()).hexdigest() for name in ("RUN.json","SOURCE.json","SOURCE_AFTER.json","SOAK31.json","SLOW_PLANNER31.json","MASS30.json","OS_MEMORY.json","stdout.log","ANALYSIS.json","CYCLES31.json","HARNESS.zip")},
        "limitations":["This run is functional; it makes no FPS claim beside the user's ordinary game.", "Opening condition door_fraction versus support.standing(inner) cannot be disambiguated by this frozen V3-derived telemetry. Planner colliders may be stale after route arrival; no fresh physics query was injected.", "Natural activity does not guarantee all services or threats are exercised. No NPC state/RNG was changed to force them.", "Object/static memory include bounded observer records; finite data do not establish a leak.", "No automatic restart or source fix was performed by QA. Root owns subsequent changes and acceptance."]
    }
    target = OUT / "EXTENDED_RESULT31.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({key:report[key] for key in ("passed", "native_elapsed_seconds", "physical_ticks", "actor_samples", "moved_residents", "failures", "completion_deltas", "full_shopping_cycles_with_native_log_entry_payment_exit", "source_pins_match_release_assembly_before_and_after")}, ensure_ascii=True))


if __name__ == "__main__":
    main()
