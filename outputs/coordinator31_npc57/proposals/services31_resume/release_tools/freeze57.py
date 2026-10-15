"""Validate final receipts; --go freezes release57. Never activates F5 or runs Godot/Git."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
import re
import shutil
import sys
import types
import uuid
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
GAME = ROOT / "outputs/coordinator31_npc57/game"
PREVIOUS = ROOT / "outputs/coordinator30_release56"
RELEASE = ROOT / "outputs/coordinator31_release57"
SCHEDULER_SHA = "adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373"
REVISION = "s01-20261015-residents57"
TITLE = "15.10 · Проходы и реакции жителей · версия57"
NON_GAMEPLAY = {"scripts/main.gd", "data/preview_updates.json"}
PROPOSALS = GAME.parent / "proposals"
ENTRIES = {
    "soak": PROPOSALS / "qa31_resume/entry_soak31_v3.gd",
    "services": PROPOSALS / "services_regression31/entry_services56.gd",
    "threat": PROPOSALS / "attention31_resume/regression/threat/entry56.gd",
    "visual": PROPOSALS / "attention31_resume/entry_visual31.gd",
    "perf_baseline": PROPOSALS / "qa31_resume/entry_soak31_v2.gd",
    "perf_candidate": PROPOSALS / "qa31_resume/entry_soak31_v2.gd",
}


def need(value, message):
    if not value:
        raise RuntimeError(message)


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def inside(path):
    path = Path(path).resolve()
    path.relative_to(ROOT)
    return path


def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob("*")
            if p.is_file() and ".godot" not in p.relative_to(project).parts}


def all_pins(folders, files=()):
    paths = {p.resolve() for folder in folders for p in folder.rglob("*") if p.is_file()}
    paths.update(Path(p).resolve() for p in files)
    return {str(p): sha(p) for p in sorted(paths)}


def unchanged(values):
    return all(Path(path).is_file() and sha(path) == digest for path, digest in values.items())


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def one_replace(text, old, new):
    need(text.count(old) == 1, "Template anchor drift: " + old)
    return text.replace(old, new, 1)


def tested_harness(folder, role, command):
    """Recover exact tested bytes, preferring the immutable run archive.

    Historical diagnostic edits outside this inventory are irrelevant. If an old
    runner did not archive a file, its current bytes must still match the test pin.
    No archive member is extracted or executed here.
    """
    harness = read(folder / ("HARNESS_PINS.json" if role == "services" else "HARNESS.json"))
    harness_root = ROOT if role in ("soak", "perf_baseline", "perf_candidate") else PROPOSALS / ("services_regression31" if role == "services" else "attention31_resume")
    archive_path = next((folder / name for name in ("HARNESS.zip", "HARNESS_SOURCES.zip") if (folder / name).is_file()), None)
    archive = zipfile.ZipFile(archive_path) if archive_path else None
    recovered = {}
    try:
        if archive:
            need(len(archive.namelist()) == len(set(archive.namelist())), role + ": duplicate archive names")
        for rel, digest in harness.items():
            need(isinstance(rel, str) and not Path(rel).is_absolute() and ".." not in Path(rel).parts, role + ": unsafe harness path")
            path = (harness_root / rel).resolve()
            path.relative_to(harness_root.resolve())
            data = archive.read(rel) if archive and rel in archive.namelist() else path.read_bytes()
            need(hashlib.sha256(data).hexdigest() == digest, role + ": tested harness bytes unavailable: " + rel)
            recovered[rel] = data
        entry = Path(command[command.index("--script") + 1]).resolve().relative_to(harness_root).as_posix()
        need(entry in recovered, role + ": native entry not pinned")
    finally:
        if archive:
            archive.close()
    return recovered


def city_flags(command):
    need(isinstance(command, list) and command.count("--") == 1, "Invalid native command")
    result = {}
    for arg in command[command.index("--") + 1:]:
        if arg.startswith("--qa-"):
            continue
        need(re.fullmatch(r"--city-[a-z0-9-]+(?:=[^\s\"';]+)?", arg), "Nonordinary/overlay flag: " + arg)
        key = arg.split("=", 1)[0]
        need(key not in result and "seed" not in key, "Duplicate/seeded city flag")
        need(key not in {"--city-resident-name", "--city-wallet-start", "--city-energy-start",
                         "--city-play-check", "--city-quit-after"}, "Forbidden global QA flag")
        result[key] = arg
    required = {"--city-qa=10", "--city-hp=100", "--city-venue-staff29=1", "--city-venue-sites29=1",
                "--city-threat30=1", "--city-physical-dispatch30=1", "--city-multi-lifecycle30=1",
                "--city-simple-hospital=1"}
    need(required.issubset(result.values()), "Ordinary batch10 behaviors missing")
    return result


def validate_receipt(folder, role, source, project, engine):
    run = read(folder / "RUN.json")
    need(run.get("passed") is True and run.get("exit_code") == 0 and not run.get("error"), role + ": run not clean PASS")
    need(run.get("errors") == [] and run.get("stderr_bytes") == 0, role + ": error fields not clean")
    need(run.get("source_drift") == run.get("harness_drift") == [], role + ": source/harness drift")
    need(read(folder / "SOURCE.json") == read(folder / "SOURCE_AFTER.json") == source, role + ": sources are not exact current pins")
    need((folder / "stdout.log").is_file() and (folder / "stderr.log").is_file(), role + ": logs missing")
    need((folder / "stderr.log").stat().st_size == 0, role + ": native stderr nonempty")
    text = (folder / "stdout.log").read_text(encoding="utf-8-sig", errors="replace")
    need(not re.search(r"(^|\n)(?:SCRIPT ERROR|ERROR:|.*Parse Error:)", text), role + ": native errors in stdout")
    command = run.get("command", [])
    need(command and Path(command[0]).resolve() == engine.resolve(), role + ": engine path mismatch")
    need(command.count("--path") == 1 and Path(command[command.index("--path") + 1]).resolve() == project.resolve(), role + ": unexpected project")
    allowed_entries = {ENTRIES[role].resolve()}
    if role in ("perf_baseline", "perf_candidate"):
        allowed_entries.add((PROPOSALS / "qa31_resume/entry_soak31_v3.gd").resolve())
        allowed_entries.add((PROPOSALS / "qa31_resume/entry_soak31_v4.gd").resolve())
    need(command.count("--script") == 1 and Path(command[command.index("--script") + 1]).resolve() in allowed_entries, role + ": unexpected native entry")
    need(run.get("child", {}).get("command") == command, role + ": exact registered child missing")
    need(not any(run.get(key) for key in ("candidate_resource_overlay", "overlay_not_merged_acceptance", "runtime_candidate_overlay")), role + ": runtime overlay")
    controls_path = folder / "CONTROL_PINS.json"
    if controls_path.exists():
        controls = read(controls_path)
        need(controls == read(folder / "CONTROL_PINS_AFTER.json"), role + ": transitive controls changed during test")
        need(run.get("control_drift") == [], role + ": control drift")
    return run, city_flags(command), tested_harness(folder, role, command)


def validate_soak(folder, run, wanted, min_seconds):
    native = read(folder / "MASS30.json")
    soak = read(folder / "SOAK31.json")
    need(run.get("native_ok") is True and run.get("composition_and_movement_ok") is True, "Soak native composition gate")
    need(run.get("ordinary_rng") is True and run.get("requested_residents") == 10, "Soak cohort/RNG gate")
    need(native.get("ok") is True and native.get("errors") == soak.get("errors") == run.get("soak_errors") == [], "Soak errors")
    need(native.get("measurement_seconds", 0) >= min_seconds, "Soak measurement too short")
    need(native.get("expected_residents") == native.get("moved_residents") == 10 and native.get("expected_staff") == 12, "Soak counts")
    need(native.get("actual_ids") == native.get("wanted_ids") == wanted, "Soak original roster mismatch")
    need(native.get("npc_or_hp_writes") is False and all(float(native["travel_metres"].get(k, 0)) > .5 for k in wanted), "Soak did not observe ordinary movement")
    need(len(soak.get("samples", [])) >= min_seconds - 3 and soak.get("physics_sample_count") == native.get("frame_count"), "Soak sample coverage")
    need(run.get("liveness_limits_s", {}).get("motion", math.inf) <= 10 and run.get("liveness_limits_s", {}).get("queue", math.inf) <= 30, "Soak idle thresholds weakened")
    need(len(soak.get("resident_summaries", [])) == 10, "Soak per-resident summary missing")
    need(all(row.get("max_motion_idle_s", math.inf) <= 10 and row.get("max_queue_idle_s", math.inf) <= 30 for row in soak["resident_summaries"]), "Soak liveness summary failed")
    if min_seconds >= 600:
        slow = read(folder / "SLOW_PLANNER31.json")
        need(slow.get("schema") == "mafiozi.soak31.slow-planner/v1" and slow.get("read_only") is True, "Final soak requires V3 read-only planner diagnostics")
        need(slow.get("sample_count") == len(slow.get("samples", [])) == run.get("slow_planner_sample_count"), "Slow planner sample count mismatch")
        need(slow.get("sample_count", math.inf) <= slow.get("capacity", -1) and slow.get("motion_threshold_s", math.inf) <= 5 and slow.get("queue_threshold_s", math.inf) <= 15, "Slow planner diagnostic coverage weakened")
    return native


def validate_services(folder, run, wanted, harness):
    checker = types.ModuleType("release57_tested_services")
    checker.__file__ = str(PROPOSALS / "services_regression31/accept_services56.py")
    exec(compile(harness["accept_services56.py"].decode("utf-8-sig"), checker.__file__, "exec"), checker.__dict__)
    checks = checker.accept(read(folder / "SERVICES56.json"))
    need(checks and checks == run.get("checks") and all(value is True for value in checks.values()), "Actual four-service checks failed")
    native = read(folder / "SERVICES56.json")
    need(sorted(native["composition"]["original_ids"]) == wanted and native["expected_residents"] == 10, "Service roster mismatch")
    need(run.get("mode") == "graphical", "Final service receipt must be graphical")


def validate_threat_visual(folder, run, role, wanted):
    native = read(folder / ("CITY_THREAT56.json" if role == "threat" else "VISUAL31.json"))
    checks = native.get("checks", {})
    need(native.get("passed") is True and native.get("reason") == "complete" and run.get("native_passed") is True, role + ": incomplete native cycle")
    need(checks and checks == run.get("checks") and all(value is True for value in checks.values()), role + ": native check failure")
    if role == "threat":
        composition = native.get("batch_composition", {})
        need(sorted(composition.get("ids", [])) == wanted and composition.get("staff") == 12 and composition.get("new_sites") == 8, "Threat cohort mismatch")
        need(all(native.get(k) is False for k in ("synthetic_damage", "npc_relocated", "routes_replaced")), "Threat uses synthetic behavior")
    else:
        need(all(native.get(k) is False for k in ("npc_position_written", "hp_written", "threat_events_injected")), "Visual fixture wrote NPC/threat state")
        need(native.get("source_catalogue_preserved") is True and checks.get("actual_visible_turn") is True, "Visible turn not proven")
        need("--headless" not in run["command"], "Visual acceptance must be graphical")
        photos = native.get("photographs", [])
        need(photos and all(row.get("ok") is True and Path(row["file"]).name == row["file"] and (folder / row["file"]).stat().st_size > 0 for row in photos), "Visual photographs missing or failed")


def validate_window_protocol(run, native, window, role):
    wanted = [1920, 1080]
    command = run.get("command", [])
    need(run.get("requested_resolution") == "1920x1080" and run.get("resolution_ok") is True, role + ": requested/observed resolution gate failed")
    need(command.count("--resolution") == 1 and command[command.index("--resolution") + 1] == "1920x1080"
         and command.count("--qa-render-resolution=1920x1080") == 1 and "--headless" not in command, role + ": native V4 resolution flags missing")
    need(window.get("schema") == "mafiozi.qa31.window/v1" and window.get("qa_only") is True
         and window.get("npc_or_source_mutations") is False and window.get("ready") is True
         and window.get("requested") == wanted, role + ": window protocol incomplete")
    need(run.get("window_protocol") == window, role + ": RUN/window receipt differs")
    camera = native.get("camera", {})
    final_camera = native.get("final_camera", {})
    need(camera.get("render_size") == camera.get("viewport") == wanted
         and final_camera.get("render_size") == final_camera.get("viewport") == wanted, role + ": physical/logical resolution must remain 1920x1080")
    after = window.get("after", {})
    need(after and after == window.get("final") == camera.get("window_protocol") == final_camera.get("window_protocol"), role + ": window metadata changed during measurement")
    dimensions = ("window_size", "display_window_size", "root_texture", "viewport_visible", "content_scale_size")
    need(all(after.get(key) == wanted for key in dimensions) and after.get("content_scale_factor") == 1.0, role + ": native window/output/viewport dimensions mismatch")


def validate_perf(evidence, receipts, comparison, wanted, engine_sha):
    for role in ("perf_baseline", "perf_candidate"):
        run = receipts[role]
        need(run.get("mode") == "perf" and run.get("perf_environment_clean") is True, role + ": not exclusive rendered measurement")
        need(run.get("engine_sha256") == engine_sha and run.get("scheduler_sha256") == SCHEDULER_SHA, role + ": engine/scheduler identity")
        native = validate_soak(evidence[role], run, wanted, 90)
        need(native.get("camera") == native.get("final_camera"), role + ": camera moved")
        need(native["camera"].get("render_size") == [1920, 1080] and native["camera"].get("viewport") == [1920, 1080], role + ": expected 1920x1080")
        validate_window_protocol(run, native, read(evidence[role] / "WINDOW31.json"), role)
        need(all(isinstance(v, (int, float)) and math.isfinite(v) and v > 0 for v in native["frame_ms"]), role + ": invalid timing samples")
    compare_module = module(PROPOSALS / "qa31_resume/compare_perf31.py", "release57_perf")
    base = compare_module.summarize(evidence["perf_baseline"])
    candidate = compare_module.summarize(evidence["perf_candidate"])
    value = read(comparison)
    need(value.get("schema") == "mafiozi.soak31.perf-pair/v1" and value.get("baseline") == base and value.get("candidate") == candidate, "Perf comparison no longer matches native evidence")
    gates = {
        "both_native_and_liveness_passed": base["passed"] and candidate["passed"],
        "both_exclusive_perf": all(x["mode"] == "perf" and x["clean"] for x in (base, candidate)),
        "same_camera_and_resolution": base["camera"] == candidate["camera"],
        "same_harness": base["harness"] == candidate["harness"],
        "same_editor_environment": base["editors"] == candidate["editors"],
        "same_timing": base["seconds"] == candidate["seconds"] and base["warmup"] == candidate["warmup"],
        "both_ten_residents_and_twelve_staff": all(x["resident_count"] == x["movement_count"] == 10 and x["staff_count"] == 12 for x in (base, candidate)),
        "p95_no_material_regression": candidate["p95_ms"] <= max(base["p95_ms"] * 1.10, base["p95_ms"] + 1.0),
        "p99_no_material_regression": candidate["p99_ms"] <= max(base["p99_ms"] * 1.15, base["p99_ms"] + 2.0),
        "p95_within_60fps_budget": candidate["p95_ms"] <= 1000 / 60,
        "mean_fps_preserved": candidate["mean_fps"] >= max(60, base["mean_fps"] * .90),
        "no_material_late_slowdown": candidate["late_third_p95_ms"] <= max(candidate["early_third_p95_ms"] * 1.15, candidate["early_third_p95_ms"] + 2.0),
    }
    need(value.get("gates") == gates and value.get("measured_timing_gates_passed") is True and all(gates.values()), "Matched performance gates failed")
    return {"gates": gates, "candidate": {key: candidate[key] for key in ("mean_fps", "p95_ms", "p99_ms", "early_third_p95_ms", "late_third_p95_ms", "seconds", "camera")}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ENTRIES:
        parser.add_argument("--" + role.replace("_", "-"), type=Path, required=True, help="Completed run directory containing RUN.json and native evidence")
    parser.add_argument("--perf-comparison", type=Path, required=True, help="PERF_COMPARISON.json produced by compare_perf31.py")
    parser.add_argument("--integration", type=Path, required=True, help="Root's exact integration manifest")
    parser.add_argument("--reserve-mib", type=int, default=128)
    parser.add_argument("--go", action="store_true", help="Create the immutable copy after every gate passes; never activate F5")
    args = parser.parse_args()
    need(args.reserve_mib >= 128, "At least 128 MiB copy/receipt reserve is required")
    evidence = {role: inside(getattr(args, role)) for role in ENTRIES}
    comparison = inside(args.perf_comparison); integration = inside(args.integration)
    need(not RELEASE.exists(), "Immutable release57 exists: do not overwrite")
    pointer = ROOT / "godot/current_version.json"; old = read(pointer)
    need(old.get("revision") == "s01-20261015-residents56", "Expected preserved current56")
    assembly56 = inside(ROOT / old["assembly"]); bootstrap56 = inside(ROOT / old["bootstrap"])
    need(assembly56.parent == bootstrap56.parent == PREVIOUS, "Unexpected baseline release")
    need(sha(assembly56) == old["assembly_sha256"] and sha(bootstrap56) == old["bootstrap_sha256"], "Frozen56 control drift")
    base_manifest = read(assembly56); baseline_source = pins(PREVIOUS / "game")
    need(baseline_source == base_manifest["source_pins"], "Frozen56 sources changed")
    scheduler = ROOT / "tools/godot/test_scheduler.py"; lock = ROOT / "docs/godot/ENGINE_LOCK.json"
    engine = Path(os.environ["LOCALAPPDATA"]) / "MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
    engine_sha = sha(engine)
    need(sha(scheduler) == SCHEDULER_SHA and engine_sha == old["engine_sha256"] == read(lock)["editor"]["gui"]["sha256"], "Engine/scheduler lock changed")
    control = all_pins([], [pointer, assembly56, bootstrap56, scheduler, lock, engine, Path(__file__), HERE / "startup57.py",
                            PROPOSALS / "qa31_resume/compare_perf31.py", PROPOSALS / "services_regression31/accept_services56.py"])
    proof_files = [comparison, integration, Path(__file__), HERE / "startup57.py", PROPOSALS / "qa31_resume/compare_perf31.py"]
    proof_pins = all_pins(evidence.values(), proof_files)
    source = pins(GAME)
    merged = read(integration)
    need(merged.get("applied") is True and all(source.get(k) == v["candidate_sha256"] for k, v in merged["changes"].items()), "Integration source drift")
    need(merged.get("source_pins") == source, "Use the final cumulative integration manifest with exact current source_pins")
    changed = {key for key in baseline_source.keys() | source.keys() if baseline_source.get(key) != source.get(key)}
    need(changed == set(merged["changes"]) and all(row.get("base_sha256") == baseline_source.get(key) for key, row in merged["changes"].items()), "Cumulative integration does not cover the complete release56-to-candidate delta")
    packet = read(GAME / "assets/npc_city/session_packet.json")
    need(len(packet["rows"]) == 287, "Keep all 287 original residents in catalogue")
    wanted = sorted(str(row["source_id"]) for row in packet["rows"][:10])
    receipts = {}; flags = {}; harnesses = {}
    for role, folder in evidence.items():
        need(folder.is_dir(), "Missing evidence: " + str(folder))
        is_base = role == "perf_baseline"
        receipts[role], flags[role], harnesses[role] = validate_receipt(folder, role, baseline_source if is_base else source, PREVIOUS / "game" if is_base else GAME, engine)
    launch_flags = city_flags([str(engine), "--", *base_manifest["launch_arguments"]])
    need(all(value == launch_flags for value in flags.values()), "Ordinary city flags differ across evidence or release56")
    validate_soak(evidence["soak"], receipts["soak"], wanted, 600)
    validate_services(evidence["services"], receipts["services"], wanted, harnesses["services"])
    for role in ("threat", "visual"):
        validate_threat_visual(evidence[role], receipts[role], role, wanted)
    metrics = validate_perf(evidence, receipts, comparison, wanted, engine_sha)
    need(pins(GAME) == source and unchanged(control) and all_pins(evidence.values(), proof_files) == proof_pins, "Source/evidence/control changed while validating")
    source_bytes = sum(p.stat().st_size for p in GAME.rglob("*") if p.is_file() and "shader_cache" not in p.relative_to(GAME).parts)
    proof_bytes = sum(Path(p).stat().st_size for p in proof_pins) + sum(len(data) for files in harnesses.values() for data in files.values())
    reserve_bytes = args.reserve_mib * 1024 * 1024
    need(shutil.disk_usage(RELEASE.parent).free > source_bytes + proof_bytes + reserve_bytes, "Insufficient disk for one cache-inclusive copy, evidence archive and reserve")
    plan = {"validated": True, "target": str(RELEASE), "source_bytes": source_bytes, "evidence_bytes": proof_bytes,
            "reserve_bytes": reserve_bytes, "source_count": len(source), "pointer_activated": False,
            "candidate_modified": False, "engine_launched": False, "metrics": metrics}
    if not args.go:
        print(json.dumps(plan, ensure_ascii=True)); return 0
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease
    partial = inside(ROOT / ("outputs/coordinator31_release57.partial_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:8]))
    state = {"status": "UNACCEPTED_PARTIAL", "target": str(RELEASE), "pointer_activated": False, "candidate_modified": False,
             "recovery": "Preserve incomplete copy; never activate it. A retry uses a new partial directory."}
    try:
        with Lease("headless", GAME, "read", 30):
            with Lease("headless", partial / "game", "write", 30):
                need(pins(GAME) == source and unchanged(control) and unchanged(proof_pins), "Inputs changed before copy")
                need(shutil.disk_usage(RELEASE.parent).free > source_bytes + proof_bytes + reserve_bytes, "Copy disk reserve no longer available")
                partial.mkdir(); save(partial / "PARTIAL_STATE.json", state)
                shutil.copytree(GAME, partial / "game", ignore=shutil.ignore_patterns("shader_cache"))
                need(pins(partial / "game") == source == pins(GAME), "Copied source mismatch")
                main_path = partial / "game/scripts/main.gd"
                original = main_path.read_text(encoding="utf-8-sig")
                main_path.write_text(one_replace(original, 'const PREVIEW_RUNTIME_REVISION := "s01-20261015-residents56"', 'const PREVIEW_RUNTIME_REVISION := "' + REVISION + '"'), encoding="utf-8")
                news = read(partial / "game/data/preview_updates.json")
                news.update(title=TITLE, runtime_revision=REVISION)
                news["items"] = ["В узких входах жители проходят друг сквозь друга; стены и двери сохраняют столкновения.",
                                 "Исправлены ложный выход снаружи магазина и зависание очереди.",
                                 "Жители поворачиваются к замеченной угрозе, затем возвращаются к обычным делам.",
                                 "Магазин, ресторан, банк и больница работают с физическим входом и выходом.",
                                 "Активны 10 жителей и 12 сотрудников; следующие партии проверяются отдельно."]
                save(partial / "game/data/preview_updates.json", news)
                after = pins(partial / "game")
                need(set(after) == set(source) and {k for k in source if source[k] != after[k]} == NON_GAMEPLAY, "Unexpected release source delta")
                bootstrap = one_replace(bootstrap56.read_text(encoding="utf-8-sig"), 'var _revision:="s01-20261015-residents56"', 'var _revision:="' + REVISION + '"')
                bootstrap = one_replace(bootstrap, 'var _title:="15.10 · Первая партия: 10 жителей · версия56"', 'var _title:="' + TITLE + '"')
                (partial / "bootstrap_play57.gd").write_text(bootstrap, encoding="utf-8")
                archived = {}
                with zipfile.ZipFile(partial / "EVIDENCE.zip", "w", zipfile.ZIP_DEFLATED) as archive:
                    for absolute, digest in proof_pins.items():
                        path = Path(absolute); name = path.relative_to(ROOT).as_posix()
                        need(sha(path) == digest, "Evidence drift during archive: " + name)
                        archive.write(path, name); archived[name] = digest
                    for role, files in harnesses.items():
                        for rel, data in files.items():
                            name = "tested_harness/" + role + "/" + rel
                            archive.writestr(name, data); archived[name] = hashlib.sha256(data).hexdigest()
                with zipfile.ZipFile(partial / "EVIDENCE.zip") as archive:
                    need(set(archive.namelist()) == set(archived), "Evidence archive inventory mismatch")
                    need(all(hashlib.sha256(archive.read(name)).hexdigest() == digest for name, digest in archived.items()), "Evidence archive verification failed")
                save(partial / "EVIDENCE_PINS.json", archived)
                manifest = {"schema": "mafiozi.residents-batch57/v1", "revision": REVISION, "game": str(RELEASE / "game"),
                    "game_relative": "outputs/coordinator31_release57/game", "source_count": len(after), "source_pins": after,
                    "launch_arguments": list(launch_flags.values()), "ready_timeout_seconds": 120, "requested_population": 10,
                    "staff": 12, "catalogue_count": 287, "performance_accepted": True,
                    "performance_scope": "10 original residents +12 staff; matched fixed camera1920x1080 bounded trial; all287 unaccepted.",
                    "full_city_performance_accepted": False, "ordinary_rng": True, "police_models_only": True}
                save(partial / "ASSEMBLY.json", manifest)
                save(partial / "ACCEPTANCE.json", {"status": "BATCH10_VERIFIED_PENDING_ORDINARY_START", "tested_source_pins": source,
                    "release_source_pins": after, "non_gameplay_changes_after_tests": sorted(NON_GAMEPLAY), "metrics": metrics,
                    "evidence_file_pins": proof_pins, "evidence_archive_sha256": sha(partial / "EVIDENCE.zip"),
                    "controls": control, "candidate_unchanged": True, "full_city_performance_accepted": False,
                    "limitations": "Finite behavioral and matched performance observations; no claim that memory can never grow."})
                save(partial / "PREVIOUS_CURRENT.json", old)
                save(partial / "PROPOSED_CURRENT.json", {"schema": "mafiozi.current-play/v1", "title": TITLE, "revision": REVISION,
                    "assembly": "outputs/coordinator31_release57/ASSEMBLY.json", "assembly_sha256": sha(partial / "ASSEMBLY.json"),
                    "bootstrap": "outputs/coordinator31_release57/bootstrap_play57.gd", "bootstrap_sha256": sha(partial / "bootstrap_play57.gd"),
                    "engine_sha256": engine_sha, "scope": "Verified batch10+12; full287 catalogue retained. Root activates only after startup57 passes."})
                need(pins(GAME) == source and unchanged(control) and unchanged(proof_pins), "Inputs changed during copy")
                state.update(status="VALIDATED_COPY_PENDING_PROMOTION"); save(partial / "PARTIAL_STATE.json", state)
        with Lease("headless", RELEASE / "game", "write", 30):
            with Lease("headless", partial / "game", "write", 30):
                need(not RELEASE.exists() and pins(partial / "game") == after, "Promotion target appeared or source changed")
                need(unchanged(control) and unchanged(proof_pins), "Control/evidence drift before promotion")
                state.update(status="FROZEN_PENDING_BOOTSTRAP_CHECK"); save(partial / "PARTIAL_STATE.json", state)
                # Both paths are explicit validated children of ROOT/outputs. No overwrite/delete.
                partial.rename(RELEASE)
        print(json.dumps({**plan, "frozen": True}, ensure_ascii=True)); return 0
    except Exception as error:
        state.update(status="FAILED_UNACCEPTED_PARTIAL", error=str(error))
        if partial.is_dir():
            try: save(partial / "PARTIAL_STATE.json", state)
            except OSError: pass
        raise


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({"passed": False, "error": str(error), "pointer_activated": False, "candidate_modified": False})); raise SystemExit(1)
