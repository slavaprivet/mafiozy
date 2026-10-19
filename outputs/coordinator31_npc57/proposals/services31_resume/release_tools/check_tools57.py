"""CPU-only release-gate checks. Never calls either script's main or a native process."""
from pathlib import Path
import ast
import copy
import hashlib
import json
import tempfile
import zipfile

import freeze57 as freeze


def main():
    checks = {}
    for name in ("freeze57.py", "startup57.py"):
        ast.parse((freeze.HERE / name).read_text(encoding="utf-8"))
        checks[name + "_syntax"] = True
    tree = ast.parse((freeze.HERE / "freeze57.py").read_text(encoding="utf-8"))
    news_assignments = [node for node in ast.walk(tree) if isinstance(node, ast.Assign)
                        and any(isinstance(target, ast.Subscript) and isinstance(target.value, ast.Name)
                                and target.value.id == "news" and isinstance(target.slice, ast.Constant)
                                and target.slice.value == "items" for target in node.targets)]
    items = ast.literal_eval(news_assignments[0].value) if len(news_assignments) == 1 else []
    checks["news_exactly_five_without_old_items"] = len(items) == 5 and all(isinstance(item, str) and item for item in items)

    def rejected(call):
        try:
            call()
        except (RuntimeError, KeyError, FileNotFoundError, ValueError):
            return True
        return False

    # Synthetic validator inputs only, never native acceptance receipts.
    state = {key: [1920, 1080] for key in ("window_size", "display_window_size", "root_texture", "viewport_visible", "content_scale_size")}
    state["viewport_visible"] = [1920.0, 1080.0]
    state["content_scale_factor"] = 1.0
    window = {"schema": "mafiozi.qa31.window/v1", "qa_only": True, "npc_or_source_mutations": False,
              "ready": True, "requested": [1920, 1080], "after": state, "final": copy.deepcopy(state)}
    camera = {"render_size": [1920, 1080], "viewport": [1920.0, 1080.0], "window_protocol": copy.deepcopy(state)}
    native = {"camera": camera, "final_camera": copy.deepcopy(camera)}
    run = {"requested_resolution": "1920x1080", "resolution_ok": True,
           "command": ["engine", "--resolution", "1920x1080", "--", "--qa-render-resolution=1920x1080"],
           "window_protocol": window}
    freeze.validate_window_protocol(run, native, window, "validator_fixture")
    checks["window_exact_physical_and_logical_1080p_accepts"] = True
    wrong = copy.deepcopy(native); wrong["camera"]["render_size"] = [2778, 1563]
    checks["scaled_physical_target_rejected"] = rejected(lambda: freeze.validate_window_protocol(run, wrong, window, "validator_fixture"))
    wrong = copy.deepcopy(native); wrong["camera"]["viewport"] = [1280, 720]
    checks["wrong_logical_viewport_rejected"] = rejected(lambda: freeze.validate_window_protocol(run, wrong, window, "validator_fixture"))
    wrong = copy.deepcopy(window); wrong["final"]["display_window_size"] = [1920, 1061]
    checks["window_final_dimension_drift_rejected"] = rejected(lambda: freeze.validate_window_protocol(dict(run, window_protocol=wrong), native, wrong, "validator_fixture"))
    wrong = dict(window, ready=False)
    checks["window_startup_not_ready_rejected"] = rejected(lambda: freeze.validate_window_protocol(dict(run, window_protocol=wrong), native, wrong, "validator_fixture"))
    wrong = dict(run, command=["engine", "--resolution", "1920x1080", "--"])
    checks["missing_v4_render_protocol_flag_rejected"] = rejected(lambda: freeze.validate_window_protocol(wrong, native, window, "validator_fixture"))

    original = freeze.PROPOSALS
    with tempfile.TemporaryDirectory(prefix="review57_", dir=freeze.HERE) as temporary:
        base = Path(temporary)
        freeze.PROPOSALS = base
        try:
            live = base / "attention31_resume"
            run = base / "run"
            live.mkdir(); run.mkdir()
            tested = b"extends SceneTree\n"
            (live / "entry.gd").write_bytes(b"later diagnostic edits\n")
            pins = {"entry.gd": hashlib.sha256(tested).hexdigest()}
            freeze.save(run / "HARNESS.json", pins)
            with zipfile.ZipFile(run / "HARNESS.zip", "w") as archive:
                archive.writestr("entry.gd", tested)
            command = ["engine", "--script", str(live / "entry.gd")]
            actual = freeze.tested_harness(run, "threat", command)
            checks["archived_tested_bytes_survive_later_live_edits"] = actual["entry.gd"] == tested
            freeze.save(run / "HARNESS.json", {"entry.gd": "0" * 64})
            checks["archive_pin_mismatch_rejected"] = rejected(lambda: freeze.tested_harness(run, "threat", command))
            freeze.save(run / "HARNESS.json", {"../entry.gd": pins["entry.gd"]})
            checks["archive_traversal_rejected"] = rejected(lambda: freeze.tested_harness(run, "threat", command))
            freeze.save(run / "HARNESS.json", pins)
            checks["unpinned_native_entry_rejected"] = rejected(lambda: freeze.tested_harness(run, "threat", ["engine", "--script", str(live / "other.gd")]))
            checks["seeded_city_flags_rejected"] = rejected(lambda: freeze.city_flags(["engine", "--", "--city-sandbox-seed=1"]))
        finally:
            freeze.PROPOSALS = original

    previous_services = freeze.PROPOSALS / "services_regression31/runs/merged_graphical01"
    run = freeze.read(previous_services / "RUN.json")
    tested = freeze.tested_harness(previous_services, "services", run["command"])
    wanted = sorted(str(row["source_id"]) for row in freeze.read(freeze.GAME / "assets/npc_city/session_packet.json")["rows"][:10])
    freeze.validate_services(previous_services, run, wanted, tested)
    checks["real_historical_service_archive_and_checker"] = True
    failed_soak = freeze.PROPOSALS / "qa31_resume/runs/merged600_01"
    checks["known_failed_600s_soak_rejected"] = rejected(lambda: freeze.validate_soak(failed_soak, freeze.read(failed_soak / "RUN.json"), wanted, 600))
    result = {"passed": all(checks.values()), "checks": checks,
              "engine_launched": False, "freeze_executed": False, "production_modified": False,
              "source_pins": {name: freeze.sha(freeze.HERE / name) for name in ("freeze57.py", "startup57.py", "check_tools57.py")}}
    freeze.save(freeze.HERE / "REVIEW_CHECKS.json", result)
    print(json.dumps(result, ensure_ascii=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
