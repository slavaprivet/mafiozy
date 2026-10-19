# Printshop placement — source-only, NOT admitted to main

27 September 2026. Original `preview_printshop_interior.gd`, main, player,
source geometry/materials and source JSON are untouched.

This separate subclass explores relocation of actual
`REBUILD-VISUAL-print_shop-001`: upright rigid placement moves visual root and
sibling interior together, projects source door/proximity/occupant anchors,
preserves open-door phase and original native collision resources. Scaling,
pitch and foreign transaction handles are refused. Source-owner callbacks
must genuinely stage/validate/commit/rollback navigation, water, support,
HUD/actions and authority. Fixture approvals are NOT production callbacks.

Immutable descriptor adoption creates a recursively readonly private copy,
never freezes the main caller's dictionary. Exact original values remain.
Optional adoption avoids repeatedly comparing the whole source geometry
descriptor; it does not skip node/resource/source-lifetime guards.

Independent review found and root corrected:

- Forged/reentrant rollback previously changed retention state. Invalid
  handles now fail without changing any transaction state.
- Added source child nodes were invisible to the initial inventory. Exact
  ordered child membership, including internal children, is now checked.
- ShaderMaterial parameter setters emit no `changed`; exact serialized
  non-resource uniform values and resource identities are now checked.

## Actual source remains HOLD

Actual printshop contains MultiMesh. Native instance setters do not emit
`changed`; nested mesh changes are not forwarded by MultiMesh. Headless
Dummy readback cannot prove instance storage. Candidate therefore refuses
ALL MultiMesh admission by default. No de-instancing, collider simplification
or geometry removal was used to evade this gate. Requires genuine owner
immutable/CPU-shadow storage contract and visual acceptance.

Script identity and source hashes cannot prove compiled code lifecycle:
GDScript reload plus restoring source text can leave compiled getters/code
changed with identical identity/metadata and zero changed signals. Requires
trusted sealed source-owner lifecycle; this package does not provide one.
No special-building placement is production-admitted here.

## Native branch tests, not scene acceptance

`test_printshop_placement.gd`, Godot4.7.2 headless: 127 checks PASS. First
assertion verifies actual MultiMesh/default scene HOLD. Then explicitly
TEST-ONLY bypasses the private MultiMesh negative gate to exercise transaction
branches on original GLB/interior. This does NOT prove MultiMesh storage,
compiled-script lifecycle, real owner callbacks or gameplay/FPS.

Branches include forged/replayed handles, reentrant rollback, retained unknown
partial prepare, failed external rollback/retry, original shape/mesh identities,
moved public-door proximity and occupant sweep, preserved animation phase,
actual native floor raycast, immutable source replacement, source metadata,
surface material replacement, added collider and silent shader uniform change.

Descriptor guard median in this branch-only test: 136261us before /1818us
after readonly adoption. Not a whole-game frame or loading measurement.

Run with existing console `--headless --path godot/mafiozi_walk --quit-after
1200 --script ABSOLUTE_PATH/test_printshop_placement.gd`. Inspect SCRIPT ERROR
even when process exits0. No extra GPU game window.
