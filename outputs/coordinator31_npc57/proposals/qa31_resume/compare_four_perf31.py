"""Read-only cost and repeatability analysis of the forward/reverse native pairs."""
from pathlib import Path
import hashlib
import json
import re
import statistics
from bisect import bisect_left
from collections import Counter
from diagnose_trends31 import analyze, stats

HERE = Path(__file__).resolve().parent
NAMES = ("baseline56_perf1080_03", "merged57_perf1080_03", "merged57_perf1080_04", "baseline56_perf1080_04")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def describe(name):
    path = HERE / "runs" / name
    result = analyze(path)
    mass, soak, run = (read(path / file) for file in ("MASS30.json", "SOAK31.json", "RUN.json"))
    samples = [row for row in mass["samples"] if row["measure_ms"] >= 0]
    result["mean_fps"] = 1000 / statistics.mean(mass["frame_ms"])
    result["frame_ms"] = stats(mass["frame_ms"])
    result["native_passed"] = run["passed"]
    result["liveness_errors"] = run["soak_errors"]
    result["max_required_motion_idle_s"] = max(row["max_motion_idle_s"] for row in run["resident_summaries"])
    result["max_queue_idle_s"] = max(row["max_queue_idle_s"] for row in run["resident_summaries"])
    result["exclusive_clean"] = run["perf_environment_clean"]
    result["camera"] = mass["camera"]
    result["editors"] = run["lease"]["editor_identities"]
    result["harness"] = read(path / "HARNESS.json")
    result["source_unchanged"] = read(path / "SOURCE.json") == read(path / "SOURCE_AFTER.json")
    result["warmup_seconds"] = mass["warmup_seconds"]
    result["draw_counters_1hz"] = {key: stats([row[key] for row in samples]) for key in ("draw_calls", "primitives", "video_memory", "texture_memory", "buffer_memory", "objects", "nodes", "resources", "orphans")}
    trace = mass["snapshot"]["logic_frame_trace"]
    result["terminal_2048_physics_ticks_cost_us"] = {key: stats(val) for key, val in trace.items() if key.endswith("_us") and isinstance(val, list)}
    result["all_render_frames_by_physics_ticks"] = result.pop("frames_grouped_by_physics_steps")
    frame_axis = [row["frame"] for row in samples]
    daily_rows = []
    for line in (path / "stdout.log").read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.startswith("DSH_DAILY "):
            continue
        row = {k: float(v) for k, v in re.findall(r"\b([a-zA-Z_0-9]+)=(-?\d+(?:\.\d+)?)", line)}
        i = max(1, min(len(samples) - 1, bisect_left(frame_axis, row["f"])))
        left, right = samples[i - 1], samples[i]
        second = (left["measure_ms"] + (row["f"] - left["frame"]) / (right["frame"] - left["frame"]) * (right["measure_ms"] - left["measure_ms"])) / 1000
        if 0 <= second < result["duration"] and row.get("physical_steps30", 0) > 0:
            daily_rows.append(row)
    result["sampled_physical_work_per_dispatched_actor_step"] = {
        "logged_ticks": len(daily_rows),
        "actor_steps_histogram": dict(Counter(int(row["physical_steps30"]) for row in daily_rows)),
        "mean_actor_steps": statistics.mean(row["physical_steps30"] for row in daily_rows),
        "mean_us_per_step_weighted": sum(row["physical_us30"] for row in daily_rows) / sum(row["physical_steps30"] for row in daily_rows),
        "us_per_step_distribution": stats([row["physical_us30"] / row["physical_steps30"] for row in daily_rows]),
        "limitation": "Physical actor steps mix route, travel and ambient work. This normalization is descriptive, not a controlled same-state benchmark.",
    }
    result["actor_sample_fractions"] = {}
    rows = [actor for row in soak["samples"] for actor in row["actors"][:row["count"]]]
    for key, predicate in {
        "required_motion": lambda a: a["required_motion"],
        "route_searching": lambda a: a["route_phase"].startswith("search"),
        "service_inbound": lambda a: a["economy_phase"] == "INBOUND",
        "service_outbound": lambda a: a["economy_phase"] == "OUTBOUND",
        "ambient": lambda a: a["life_phase"] == "AMBIENT",
        "resting": lambda a: a["life_phase"] == "RESTING",
    }.items():
        result["actor_sample_fractions"][key] = sum(bool(predicate(a)) for a in rows) / len(rows)
    for window in result["windows"].values():
        window["measured_render_frame_frequency"] = window.pop("mean_headless_frame_frequency")
    result["full_window_sampled_cost"] = result["windows"].pop("first_180")
    result["passage_cost_exported"] = False
    return result


def pair(base, candidate):
    return {
        "mean_fps_delta_percent": (candidate["mean_fps"] / base["mean_fps"] - 1) * 100,
        "p95_delta_percent": (candidate["frame_ms"]["p95"] / base["frame_ms"]["p95"] - 1) * 100,
        "p99_delta_percent": (candidate["frame_ms"]["p99"] / base["frame_ms"]["p99"] - 1) * 100,
        "sampled_physical_mean_delta_ms": candidate["full_window_sampled_cost"]["sampled_physical_ms"]["mean"] - base["full_window_sampled_cost"]["sampled_physical_ms"]["mean"],
        "sampled_process_mean_delta_ms": candidate["full_window_sampled_cost"]["native_process_ms"]["mean"] - base["full_window_sampled_cost"]["native_process_ms"]["mean"],
        "sampled_native_physics_mean_delta_ms": candidate["full_window_sampled_cost"]["native_physics_ms"]["mean"] - base["full_window_sampled_cost"]["native_physics_ms"]["mean"],
        "sampled_planner_mean_delta_us": candidate["full_window_sampled_cost"]["native_route_service_us"]["mean"] - base["full_window_sampled_cost"]["native_route_service_us"]["mean"],
    }


def main():
    data = {name: describe(name) for name in NAMES if (HERE / "runs" / name / "RUN.json").exists()}
    first = data[NAMES[0]]
    consistent = {
        "all_native_passed": all(item["native_passed"] for item in data.values()),
        "all_exclusive_clean": all(item["exclusive_clean"] for item in data.values()),
        "same_camera": all(item["camera"] == first["camera"] for item in data.values()),
        "same_harness": all(item["harness"] == first["harness"] for item in data.values()),
        "same_editor_identities": all(item["editors"] == first["editors"] for item in data.values()),
        "all_sources_unchanged": all(item["source_unchanged"] for item in data.values()),
        "same_90_plus20": all(item["duration"] == 90 and item["warmup_seconds"] == 20 for item in data.values()),
    }
    pairs = {"forward03": pair(data[NAMES[0]], data[NAMES[1]])}
    if len(data) == 4:
        pairs["reverse04"] = pair(data[NAMES[3]], data[NAMES[2]])
        pairs["baseline_repeat"] = pair(data[NAMES[0]], data[NAMES[3]])
        pairs["candidate_repeat"] = pair(data[NAMES[1]], data[NAMES[2]])
        consistent["same_baseline_source_across_repeats"] = read(HERE / "runs" / NAMES[0] / "SOURCE.json") == read(HERE / "runs" / NAMES[3] / "SOURCE.json")
        consistent["same_candidate_source_across_repeats"] = read(HERE / "runs" / NAMES[1] / "SOURCE.json") == read(HERE / "runs" / NAMES[2] / "SOURCE.json")
    report = {
        "schema": "mafiozi.qa31.four-perf/v1",
        "completed_runs": len(data),
        "launch_order": list(data),
        "consistency": consistent,
        "pairs": pairs,
        "runs": data,
        "performance_accepted": False,
        "limitations": [
            "Exact frame intervals and physics steps per render cover all frames. Native process/physics/planner/objects/draw counters are1Hz samples, not per-render component timing.",
            "Daily physical timings are logged every15 physics ticks. Terminal component trace covers only the final2048 physical ticks (~34 seconds); means/percentiles there are not full90-second measurements.",
            "Process and physics monitor values can overlap; do not add them to reconstruct a frame. Draw calls/primitives are counts, not GPU time.",
            "Passage diagnostics are absent in the frozen harness. Its source has max_refresh_us but no cumulative cost counter, and refresh runs as a separate physics Node. No causal passage attribution can be derived from these reports.",
            "Natural RNG and resident activity differ; no actor state was forced. Two ordered pairs expose repeat variability and cannot isolate thermal effects, background system load, or source cost individually.",
            "A timing gate pass does not dismiss the user's FPS concern. Root decides acceptance and further optimization.",
        ],
    }
    target = HERE / "PERF_FOUR_RUNS31.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if len(data) == 4:
        lines = ["# Четыре сопоставимых прогона QA31", "", "Порядок: baseline56_03 → candidate57_03 → candidate57_04 → baseline56_04.", "Все: 90 секунд измерения +20 прогрева, настоящий1920×1080, та же камера и архивированныйV4.", "", "| Прогон | Результат | Средний FPS | p95, мс | p99, мс | Daily physical, среднее мс | Требуемое движение, доля наблюдений |", "|---|---|---:|---:|---:|---:|---:|"]
        for name, item in data.items():
            lines.append(f"| {name} | {'PASS' if item['native_passed'] else 'FAIL'} | {item['mean_fps']:.3f} | {item['frame_ms']['p95']:.3f} | {item['frame_ms']['p99']:.3f} | {item['full_window_sampled_cost']['sampled_physical_ms']['mean']:.3f} | {item['actor_sample_fractions']['required_motion'] * 100:.1f}% |")
        for name, item in data.items():
            if not item["native_passed"]:
                lines.extend(["", f"**{name} FAIL:** {item['liveness_errors']}; максимум простоя требуемого движения {item['max_required_motion_idle_s']:.3f}с, очереди {item['max_queue_idle_s']:.3f}с. Timing сохранён, но обратная пара не объявляется PASS и не заменяет первую пару, прошедшую проверки."])
        lines.extend(["", f"Разница candidate/baseline: прямая пара {pairs['forward03']['mean_fps_delta_percent']:+.3f}%, обратная {pairs['reverse04']['mean_fps_delta_percent']:+.3f}%.", f"Повтор самой версии: baseline {pairs['baseline_repeat']['mean_fps_delta_percent']:+.3f}%, candidate {pairs['candidate_repeat']['mean_fps_delta_percent']:+.3f}%.", "", "Это измерения при естественной активности жителей. Два повтора не отделяют влияние случайных маршрутов, теплового режима и фоновой работы ОС. Прохождение прежних границ не закрывает жалобу пользователя само по себе.", "", "Для каждого кадра сохранены интервал и число физических тиков. Process/physics/planner/objects/draw counters измерены раз в секунду; daily physical — каждые15 физических тиков; компонентный trace содержит только последние2048 тиков. Их нельзя выдавать за полную покадровую декомпозицию или складывать пересекающиеся monitors.", "", "Отдельная стоимость passage не измерена: frozen harness не экспортирует diagnostics этого отдельного physics Node. Наличие max_refresh_us в source не позволяет восстановить его значения задним числом. Draw calls и primitives показывают объём, а не GPU-время.", "", "Точные распределения, память, активность, размеры, совпадения источников/камеры/harness/editor и hashes исходных доказательств — в PERF_FOUR_RUNS31.json. Решение о выпуске и оптимизации принимает root."])
        (HERE / "PERF_FOUR_RUNS31.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(target), "completed_runs": len(data), "pairs": pairs, "consistency": consistent}, ensure_ascii=True))


if __name__ == "__main__":
    main()
