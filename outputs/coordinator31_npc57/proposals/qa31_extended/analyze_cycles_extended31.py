"""Summarize real service transactions and physical exits from native evidence."""
from pathlib import Path
from bisect import bisect_left
from collections import Counter, defaultdict
import argparse
import hashlib
import json
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    run = parser.parse_args().run.resolve()
    mass = json.loads((run / "MASS30.json").read_text(encoding="utf-8"))
    soak = json.loads((run / "SOAK31.json").read_text(encoding="utf-8"))
    samples = soak["samples"]
    frames = [row["frame"] for row in samples]
    cycles = defaultdict(list)
    complete_lines = Counter()
    economy_rows = []
    for line_number, line in enumerate((run / "stdout.log").read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if not line.startswith("NPC_ECONOMY28 "):
            continue
        row = dict(re.findall(r"\b(id|kind|stage|cash|serial|frame)=([^\s]*)", line))
        if not all(key in row for key in ("id", "frame", "serial", "stage")):
            continue
        row["frame"] = int(row["frame"])
        row["serial"] = int(row["serial"])
        row["cash"] = float(row["cash"])
        reason = re.search(r"\breason=(.*?) frame=", line)
        row["reason"] = reason.group(1) if reason else ""
        row["stdout_line"] = line_number
        i = max(1, min(len(samples) - 1, bisect_left(frames, row["frame"])))
        left, right = samples[i - 1], samples[i]
        row["approx_measure_s"] = (left["measure_ms"] + (row["frame"] - left["frame"]) / (right["frame"] - left["frame"]) * (right["measure_ms"] - left["measure_ms"])) / 1000
        row["within_measurement"] = 0 <= row["approx_measure_s"] <= mass["measurement_seconds"]
        if row["within_measurement"]:
            complete_lines[row["stage"]] += 1
        if row["stage"] in {"started", "entered", "paid", "leaving", "complete", "exit_blocked", "interrupted"}:
            for actor in right["actors"][:right["count"]]:
                if actor["id"] == row["id"]:
                    row["nearby_native_state"] = {key:actor[key] for key in ("id", "generation", "position", "venue", "life_phase", "outer_phase", "route_phase", "door_stage", "motion_idle_s", "queue_idle_s")}
                    row["nearby_native_state"]["sample_frame"] = right["frame"]
                    break
            cycles[(row["id"], row["serial"], row["kind"])].append(row)
        economy_rows.append(row)
    summaries = []
    for (ident, serial, kind), events in cycles.items():
        started = next((r for r in events if r["stage"] == "started"), None)
        paid = next((r for r in events if r["stage"] == "paid"), None)
        exited = next((r for r in events if r["stage"] == "complete" and r["reason"] == "physical_exit"), None)
        entered = next((r for r in events if r["stage"] == "entered"), None)
        observed_sequence = bool(started and entered and paid and exited and started["frame"] <= entered["frame"] <= paid["frame"] <= exited["frame"])
        summaries.append({"id":ident, "serial":serial, "kind":kind, "started_entered_paid_physical_exit_sequence":observed_sequence,
                          "paid_and_physical_exit_both_in_measurement":bool(paid and exited and paid["within_measurement"] and exited["within_measurement"]),
                          "cash_spent":started["cash"]-paid["cash"] if started and paid else None,
                          "paid_to_exit_physics_ticks":exited["frame"]-paid["frame"] if paid and exited else None,
                          "events":events})
    report = {"schema":"mafiozi.qa31.extended-cycles/v1", "actual_measurement_elapsed_s":mass["actual_measurement_elapsed_s"],
              "physical_ticks":sum(soak["physics_steps_per_render"]), "render_steps":mass["frame_count"],
              "economy_stages_during_measurement":dict(complete_lines), "cycles":summaries,
              "full_observed_shopping_cycles":sum(row["kind"] == "shop" and row["started_entered_paid_physical_exit_sequence"] and row["paid_and_physical_exit_both_in_measurement"] for row in summaries),
              "source_sha256":{name:hashlib.sha256((run/name).read_bytes()).hexdigest() for name in ("stdout.log", "SOAK31.json", "MASS30.json", "SOURCE.json", "HARNESS.zip")},
              "limitations":["No synthetic trips or actor state changes. Finite natural selection can leave services unobserved.", "Exact log physics frames are retained. Approximate wall times interpolate between1Hz native anchors; nearby state is a separate later sample, not an exact event-time position.", "Transactions still active at the measurement boundary are retained and do not by themselves imply failure.", "Headless with an open user game is functional evidence only, not FPS acceptance."]}
    (run / "CYCLES31.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({key:report[key] for key in ("actual_measurement_elapsed_s", "physical_ticks", "render_steps", "economy_stages_during_measurement", "full_observed_shopping_cycles")}, ensure_ascii=True))


if __name__ == "__main__":
    main()
