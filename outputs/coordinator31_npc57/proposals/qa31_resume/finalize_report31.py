"""Build the final QA handoff from retained native reports, without changing them."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(name):
    path = HERE / "runs" / name
    run, analysis = read(path / "RUN.json"), read(path / "ANALYSIS.json")
    source = read(path / "SOURCE.json")
    return {
        "run": name,
        "passed": run["passed"],
        "mode": run["mode"],
        "seconds": analysis["seconds"],
        "source_pin_count": len(source),
        "source_unchanged": source == read(path / "SOURCE_AFTER.json"),
        "source_control_harness_drift": {k: run[k] for k in ("source_drift", "control_drift", "harness_drift")},
        "stderr_bytes": run["stderr_bytes"],
        "moved_residents": analysis["moved_residents"],
        "max_required_motion_idle_s": max(r["max_motion_idle_s"] for r in analysis["per_id"]),
        "max_queue_idle_s": max(r["max_queue_idle_s"] for r in analysis["per_id"]),
        "physical_ticks": analysis["physics_steps"],
        "render_frames": analysis["render_frames"],
        "completion_deltas": {key: sum(r["completion_deltas_within_measurement"].get(key, 0) for r in analysis["per_id"]) for key in ("shop", "walk", "bank", "hospital", "restaurant")},
        "quarter_median_deltas": {group: {key: val["last_minus_first_quarter_median"] for key, val in analysis[group].items()} for group in ("os_trends", "native_trends")},
        "log_counts": analysis["matching_log_line_counts"],
        "evidence_sha256": {file: digest(path / file) for file in ("RUN.json", "SOURCE.json", "SOURCE_AFTER.json", "HARNESS.json", "HARNESS.zip", "HARNESS_ARCHIVE.json", "MASS30.json", "SOAK31.json", "ANALYSIS.json") if (path / file).exists()},
    }


def main():
    candidate = HERE / "runs" / "merged57_perf1080_03"
    perf = read(candidate / "PERF_COMPARISON.json")
    integrated = read(ROOT / "outputs/coordinator31_npc57/INTEGRATION_merged02.json")["source_pins"]
    matches = {name: read(HERE / "runs" / name / "SOURCE.json") == integrated for name in ("merged600_02", "merged57_perf1080_03")}
    assert all(matches.values()), "Final QA must match complete merged02 source exactly"
    result = {
        "schema": "mafiozi.qa31.final-handoff/v1",
        "final_functional_passed": True,
        "matched_perf_gates_passed": perf["measured_timing_gates_passed"],
        "performance_accepted": False,
        "release_authority": "Root coordinator; QA reports evidence only",
        "complete_source_matches_integration_merged02": matches,
        "functional": summarize("merged600_02"),
        "failed_pre_fix": summarize("merged600_01"),
        "baseline_perf": summarize("baseline56_perf1080_03"),
        "candidate_perf": summarize("merged57_perf1080_03"),
        "perf": {side: {key: perf[side][key] for key in ("mean_fps", "p95_ms", "p99_ms", "early_third_p95_ms", "late_third_p95_ms")} for side in ("baseline", "candidate")},
        "perf_gates": perf["gates"],
        "perf_changes_percent": {key: (perf["candidate"][key] / perf["baseline"][key] - 1) * 100 for key in ("mean_fps", "p95_ms", "p99_ms")},
        "perf_comparison_sha256": digest(candidate / "PERF_COMPARISON.json"),
        "presentation_contract": "V4 QA-only native Window/Display/root texture/logical viewport/content target all 1920x1080, content factor1, stable before warmup and matched camera; no game source or NPC state mutation.",
        "limitations": [
            "Natural RNG retained; final600 did not select the historical failing venue1559777848406. Targeted native services fixtures provide that geometry coverage separately.",
            "Natural final600 observed shopping and walking, not bank/hospital/restaurant; targeted service acceptance remains separate.",
            "No threat was injected by the observer; attention/threat fixtures remain separate.",
            "Headless600 timing is functional only; only the exclusive90-second matched V4 pair is performance evidence.",
            "Candidate mean FPS is 8 percent lower in this pair, within unchanged gates; no acceleration is claimed.",
            "Bounded observer allocations and finite duration prevent proving absence of leaks. Node/resource counts and OS memory remain recorded.",
            "Earlier perf1080_01 wrong resolution and perf1080_02 startup guard failures are preserved, not reclassified."
        ],
    }
    assert result["functional"]["passed"] and result["matched_perf_gates_passed"]
    target = HERE / "FINAL_QA31.json"
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(target), "complete_source_matches": matches, "perf_changes_percent": result["perf_changes_percent"]}, ensure_ascii=True))


if __name__ == "__main__":
    main()
