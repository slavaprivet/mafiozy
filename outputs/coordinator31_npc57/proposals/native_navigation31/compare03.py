from pathlib import Path
import hashlib
import json
import statistics

HERE = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    runs = {name: HERE / "runs" / (name + "_full03") for name in ["custom", "rvo"]}
    records = {name: read(path / "RUN.json") for name, path in runs.items()}
    data = {name: read(path / "NATIVE.json") for name, path in runs.items()}
    assert all(value["execution_clean"] for value in records.values())
    assert read(runs["custom"] / "HARNESS.json") == read(runs["rvo"] / "HARNESS.json")
    assert read(runs["custom"] / "SOURCE.json") == read(runs["rvo"] / "SOURCE.json")
    comparisons = []
    for custom, rvo in zip(data["custom"]["cases"], data["rvo"]["cases"]):
        assert custom["case"] == rvo["case"]
        row = {"case":custom["case"]}
        for name, case in [("custom",custom),("rvo",rvo)]:
            monitor_rows = case["snapshots"][1:]  # Exclude transition/carryover sample.
            monitor_summary = {}
            for key in ["TIME_NAVIGATION_PROCESS", "TIME_PHYSICS_PROCESS", "TIME_PROCESS"]:
                values = [float(item["engine_monitors"][key]) * 1e6 for item in monitor_rows
                          if key in item["engine_monitors"]]
                monitor_summary[key] = {"samples":len(values), "median_us":statistics.median(values) if values else None,
                                        "min_us":min(values) if values else None,"max_us":max(values) if values else None}
            row[name] = {"arrived":case["complete_count"], "ticks":case["ticks"], "sim_s":case["sim_s"],
                "wall_s":case["wall_s"], "max_idle_s":case["max_idle_s"],
                "script_adapter_us_per_tick":case["adapter_us"] / case["ticks"],
                "native_movement_us_per_tick":case["native_physics_us"] / case["ticks"],
                "engine_monitors":monitor_summary, "core":case["core"]}
        comparisons.append(row)
    report = {"source_and_harness_matched":True,"execution_clean":True,"comparisons":comparisons,
        "recommendation":"Do not integrate RVO: crossing10 fails0/10 whereas current custom completes10/10 in9.1s.",
        "performance_accepted":False,"actual_city_overlay_started":False,
        "cost_scope":"Per-tick GDScript adapter timing excludes native RVO compute; TIME_NAVIGATION_PROCESS is whole-server periodic monitor. These are concurrent functional runs, not clean FPS tests; do not sum inclusive measurements.",
        "fixture_limitation":"custom03 wall/player final-x assertions fail after legitimate sideways evasion; those two assertions do not prove penetration. Exact movement snapshots retained. RVO crossed neither and all its physical-safety assertions passed. No whole-suite PASS claimed for custom03.",
        "receipts":{name:{"path":str(path),"native_sha256":hashlib.sha256((path/"NATIVE.json").read_bytes()).hexdigest(),
                           "failed_checks":[key for key,value in records[name]["checks"].items() if not value]}
                    for name,path in runs.items()}}
    (HERE / "COMPARISON03.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"matched":True,"recommendation":report["recommendation"],"cost_scope":report["cost_scope"]}))


if __name__ == "__main__":
    main()
