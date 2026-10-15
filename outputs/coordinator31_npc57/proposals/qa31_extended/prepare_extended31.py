"""Create a small, independent 1200s QA adapter; never copy or modify a game."""
from pathlib import Path
import hashlib
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
OLD = OUT.parent / "qa31_resume"
PERF = ROOT / "outputs/coordinator30_npc54/proposals/perf30"
MASS = ROOT / "outputs/coordinator30_npc54/proposals/mass30"


def transformed(source, target, changes):
    text = source.read_text(encoding="utf-8-sig")
    for old, new in changes:
        assert old in text, (source, old)
        text = text.replace(old, new)
    target.write_text(text, encoding="utf-8")
    return {"source": source.relative_to(ROOT).as_posix(), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "target": target.relative_to(ROOT).as_posix(), "target_sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "replacements": changes}


def main():
    assert not (OUT / "runs").exists(), "Never rewrite an adapter after native runs exist"
    receipts = []
    definitions = [
        (PERF / "observer_perf30.gd", "observer_perf_extended.gd", [("_measure_s>600", "_measure_s>1200")]),
        (MASS / "observer_mass30.gd", "observer_mass_extended.gd", [("extends \"../perf30/observer_perf30.gd\"", "extends \"observer_perf_extended.gd\""), ('"measurement_seconds":_measure_s,', '"measurement_seconds":_measure_s,"actual_measurement_elapsed_s":float(Time.get_ticks_msec()-_sample_start_ms)/1000.0,')]),
        (OLD / "observer_soak31_v2.gd", "observer_soak31_v2.gd", [("extends \"../../../coordinator30_npc54/proposals/mass30/observer_mass30.gd\"", "extends \"observer_mass_extended.gd\""), ("_intervals31.size() >= 512", "_intervals31.size() >= 4096"), ('"interval_capacity":512', '"interval_capacity":4096')]),
        (OLD / "observer_soak31_v3.gd", "observer_soak31_v3.gd", []),
        (OLD / "entry_soak31_v3.gd", "entry_soak31_extended.gd", []),
        (OLD / "archive_harness31.py", "archive_harness31.py", []),
    ]
    for source, name, changes in definitions:
        receipts.append(transformed(source, OUT / name, changes))
    changes = [
        ("import os\n", "import os\nimport shutil\n"),
        ("GAME = OUT.parent.parent / 'game'", "GAME = ROOT / 'outputs/coordinator31_release57/game'"),
        ("default=180", "default=1200"),
        ("default=15)", "default=30)"),
        ("choices=['headless', 'graphical', 'perf']", "choices=['headless']"),
        ("args.seconds <= 600", "args.seconds <= 1200"),
        ("'outputs/coordinator30_release56/ASSEMBLY.json'", "'outputs/coordinator31_release57/ASSEMBLY.json'"),
        ("OUT / 'entry_soak31_v3.gd'", "OUT / 'entry_soak31_extended.gd'"),
        ("previous / 'mass30/observer_mass30.gd', previous / 'perf30/observer_perf30.gd'", "OUT / 'observer_mass_extended.gd', OUT / 'observer_perf_extended.gd'"),
        ("need((game / 'project.godot').is_file(), 'Project missing')", "need((game / 'project.godot').is_file(), 'Project missing')\n    need(game == GAME.resolve(), 'Extended QA is pinned to release57')\n    need(not args.extra and args.resolution is None and args.fixed_camera_from is None, 'No extra behavior or presentation overrides')\n    need(args.max_motion_idle == 10.0 and args.max_queue_idle == 30.0, 'Preserve exact10/30s liveness gates')\n    need(shutil.disk_usage(ROOT).free >= 256 * 1024**2, 'Less than256MiB free before launch')"),
        ("before = pins(game)\n            save", "before = pins(game)\n            need(before == read(assembly_path)['source_pins'], 'Exact release57 ASSEMBLY source mismatch')\n            record['release_source_matches_assembly'] = True\n            save"),
        ("if time.monotonic() >= next_sample:\n", "if time.monotonic() >= next_sample:\n                                output_bytes = sum(p.stat().st_size for p in run.iterdir() if p.is_file())\n                                need(output_bytes <= 100 * 1024**2, 'Owned output exceeds100MiB cap')\n                                need(shutil.disk_usage(ROOT).free >= 128 * 1024**2, 'Disk reserve below128MiB')\n"),
        ("record['mean_fps'] = 1000 / statistics.mean(frames)", "record['headless_frame_frequency_descriptive_only'] = 1000 / statistics.mean(frames)\n            record['physical_ticks_observed'] = sum(soak['physics_steps_per_render'])\n            record['actual_measurement_elapsed_s'] = native['actual_measurement_elapsed_s']\n            record['physical_ticks_per_wall_second'] = record['physical_ticks_observed'] / record['actual_measurement_elapsed_s']\n            record['functional_only_not_fps_acceptance'] = True"),
        ("save(run / 'OS_MEMORY.json', {'samples': memory})", "save(run / 'OS_MEMORY.json', {'samples': memory})\n        record['output_bytes_at_terminal'] = sum(p.stat().st_size for p in run.iterdir() if p.is_file())\n        record['disk_free_bytes_at_terminal'] = shutil.disk_usage(ROOT).free"),
    ]
    receipts.append(transformed(OLD / "run_soak31_v3.py", OUT / "run_extended31.py", changes))
    result = {"scope": "Small QA script adapters only; no game copies, source writes, imports or changes to historical harness", "max_seconds":1200, "max_output_bytes":100*1024**2, "expected_normal_output_bytes":22*1024**2, "estimated_all_actors_slow_output_bytes":65*1024**2, "changes":receipts}
    (OUT / "PREPARE.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files":len(receipts), "bytes":sum((ROOT / row['target']).stat().st_size for row in receipts)}, ensure_ascii=True))


if __name__ == "__main__":
    main()
