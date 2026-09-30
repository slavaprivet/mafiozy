"""Read-only promotion-scope inspection. Does not invoke engine or change runtime."""
from pathlib import Path
import hashlib
import json
import re

here = Path(__file__).resolve().parent
root = here.parents[1]
candidate = root / "outputs/coordinator24_quality/candidate20"
game = candidate / "godot/mafiozi_walk"
shared = root / "godot/mafiozi_walk"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
manifest = json.loads((candidate / "INTEGRATION.json").read_text(encoding="utf-8"))
receipt_path = game / "exports/win64/s01-20260930-quality24a/build_receipt.json"
receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
expected_scope = {
    "scripts/weapons/preview_weapon_cargo.gd", "scripts/weapons/preview_weapons.gd",
    "scripts/main.gd", "data/preview_updates.json",
}
assert set(manifest["changes"]) == expected_scope
assert sha(receipt_path) == "ce19b634175f77890b9e8de86675d10352316c09cb8bd81640799b9de7248e07"
inputs = {row["path"]: row for row in receipt["inputs"]}
rows = []
for name, pin in manifest["changes"].items():
    before = sha(shared / name)
    after = sha(game / name)
    rows.append({"path": name, "expected_before": pin["before"], "shared_now": before,
                 "expected_after": pin["after"], "candidate_now": after,
                 "shared_before_matches": before == pin["before"],
                 "candidate_after_matches": after == pin["after"],
                 "export_receipt_matches_candidate": inputs[name]["sha256"] == after})
notes = json.loads((game / "data/preview_updates.json").read_text(encoding="utf-8"))
main = (game / "scripts/main.gd").read_text(encoding="utf-8")
match = re.search(r'const PREVIEW_RUNTIME_REVISION := "([^\"]+)"', main)
assert match and match.group(1) == notes["runtime_revision"] == "s01-20260930-quality24a"
assert len(notes["items"]) == 5 and all(isinstance(x, str) and 0 < len(x) <= 240 for x in notes["items"])
unscoped = []
for name, row in inputs.items():
    if name in expected_scope:
        continue
    path = shared / name
    current = sha(path) if path.is_file() else None
    if current != row["sha256"]:
        unscoped.append({"path": name, "shared_sha256": current,
                         "candidate_sha256": row["sha256"], "action": "PRESERVE_SHARED_UNSCOPED"})
report = {
    "status": "READY_FOR_ROOT_GUARDED_FOUR_PATH_PROMOTION" if all(
        row["shared_before_matches"] and row["candidate_after_matches"]
        and row["export_receipt_matches_candidate"] for row in rows) else "HOLD_GUARD_MISMATCH",
    "integration_sha256": sha(candidate / "INTEGRATION.json"), "paths": rows,
    "candidate_revision": match.group(1), "candidate_note_count": len(notes["items"]),
    "unscoped_receipt_differences": unscoped,
    "scope": "Only four guarded paths may be promoted. Shared player/transport/NPC/palette/scene WIP stays untouched. Native startup prepared but NOT_RUN.",
}
(here / "FOUR_PATH_GUARDS.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": report["status"], "guarded_paths": len(rows), "revision": match.group(1),
                  "items": len(notes["items"]), "unscoped_differences": [x["path"] for x in unscoped]}))
