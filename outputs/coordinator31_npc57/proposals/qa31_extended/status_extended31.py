"""Compact read-only live view; not a terminal acceptance report."""
from pathlib import Path
from collections import Counter
import json
import re

run = Path(__file__).resolve().parent / "runs/release57_1200_01"
lines = (run / "stdout.log").read_text(encoding="utf-8", errors="replace").splitlines()
live = [json.loads(line.removeprefix("SOAK31_LIVE ")) for line in lines if line.startswith("SOAK31_LIVE ")]
counts = Counter()
for line in lines:
    if line.startswith("NPC_ECONOMY28 "):
        match = re.search(r"\bstage=(\w+)", line)
        if match:
            counts[match[1]] += 1
    elif line.startswith("NPC_ROAM51 ") and "result=arrived" in line:
        counts["walk_arrived"] += 1
violations = [{"measure_ms":row["measure_ms"], **actor} for row in live for actor in row["highlights"] if actor["motion_idle_s"] > 10 or actor["queue_idle_s"] > 30]
worst = {}
for row in violations:
    previous = worst.setdefault(row["id"], {"motion_idle_s":0.0,"queue_idle_s":0.0})
    previous["motion_idle_s"] = max(previous["motion_idle_s"], row["motion_idle_s"])
    previous["queue_idle_s"] = max(previous["queue_idle_s"], row["queue_idle_s"])
latest = {"measure_ms":live[-1]["measure_ms"],"actors":live[-1]["actors"],"highlights":[{key:row[key] for key in ("id","motion_idle_s","queue_idle_s","life_phase","outer_phase","door_stage","venue")} for row in live[-1]["highlights"]]} if live else None
result = {"terminal":(run / "RUN.json").exists(), "latest_live":latest,
          "worst_live_violations_by_id":worst, "process_lifetime_event_counts":dict(counts),
          "stderr_bytes":(run / "stderr.log").stat().st_size,
          "current_disk_bytes":sum(p.stat().st_size for p in run.iterdir() if p.is_file())}
print(json.dumps(result, ensure_ascii=True))
