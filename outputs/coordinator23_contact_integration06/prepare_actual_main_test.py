"""Record the hand-maintained integrated harness; never overwrite it.

The former generator recreated the failed prepared harness (main07_01).
The scheduled-player rewrite is now authoritative. This script only hashes
its exact local closure, result, and external candidate runtime dependencies.
"""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
files = [
    out / "test_actual_main_integrated.gd",
    root / "outputs/artist23_combat_next/test_combined_eyes_input.gd",
    out / "main07_01/RESULT.json",
    out / "main07_02/RESULT.json",
    root / "outputs/coordinator23_contact_port_proposal/MEASURED_LIMITS.json",
    root / "outputs/coordinator23_quality/candidate07/INTEGRATION.json",
]
stage = root / "outputs/coordinator23_quality/candidate07/godot/mafiozi_walk"
files += [stage / "scripts" / name for name in [
    "preview_main.gd", "preview_player.gd", "player_corpse_contact.gd",
    "preview_population.gd", "npc_visual/preview_resident_host.gd",
    "npc_visual/final_dead_contact_port.gd", "npc_visual/npc_local_preview_hit_owner.gd",
]]
rows = []
for path in files:
    if not path.is_file():
        if path.name == "preview_main.gd":
            path = stage / "scripts/main.gd"
        if not path.is_file():
            raise SystemExit(f"Missing required closure/runtime input: {path}")
    data = path.read_bytes()
    rows.append({"path": path.relative_to(root).as_posix(), "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
receipt = {
    "status": "HEADLESS_PASS_64; scheduled player/main07_02; GPU and paired performance not run",
    "local_extends": "outputs/artist23_combat_next/test_combined_eyes_input.gd",
    "local_preloads": [],
    "production_modified": False,
    "external_runtime_required": "Complete candidate07 project/imports, explicit measured limits, root move receipt/sampler/public population binding and reviewed NPC accessor/port. A PCK lacking these methods is not a substitute.",
    "files": rows,
}
(out / "TEST_ORIGIN.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
print("Recorded scheduled-player harness closure; no GDScript/runtime changes")
