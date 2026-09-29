# Contact selection continuation — 29 September 2026

Godot 4.7.2 headless: **522 checks PASS**, exit 0, no script errors. No native
extension was loaded, no main/player/HP/runtime registration or GPU changes.

## Proven changes

- Carry the accepted kernel's original-order barycentric coordinates as a
  `PackedFloat64Array` in `contact.weights`, plus `contact.normal_side` relative
  to the original triangle winding. The existing face indices, mesh ID and owner
  receipt remain unchanged. The complete original source actually produces these
  anchor fields; the former selector discarded them.
- Revalidate the winning actor after all actors have been visited. A later actor's
  synchronous query/occlusion callback can retire the earlier winner. The previous
  code rechecked only the actor currently being visited and returned that stale win.

## Evidence

`build_melee_contact_selection_oracle.mjs` executes the unchanged original
`npc_melee_contact.mjs` and its unchanged `npc_contact_anchor.mjs` using real
Three r180 SkinnedMesh/obstacle fixtures. Both source files are hash pinned.
Packaging correction: source pins explicitly declare
`source_hash_normalization='crlf_to_lf'`. Both generator and test hash UTF-8 text
after CRLF → LF only, with no other transformation. This accommodates the source
worktree's mixed line endings and a fresh Git checkout's LF bytes. The original
source files are unchanged; this changes no executed source semantics. The marker
itself is checked. Root owns the subsequent clean staging-checkout validation.
36 cases / 21 hits include original actor/mesh/face/limb ties and strict identity,
visible ancestors, near boundary, radius precedence, head interpolation, source
AABB rejection of the native epsilon superset, original ordered occlusion rays,
thin-wall body ray and epsilon-clear/block cases. The new test compares exact ray
sequence/count as well as the resulting target, face, point, normal, zone, score
distance, barycentrics and winding sign.

The query test port evaluates every triangle using the previously independently
accepted scalar kernel and deliberately reverses result order. Additional checks
retire an actor inside query or ray callbacks, invalidate an earlier winner during
the next actor's query, dispose/reenter the selector, and return incomplete pages.
All fail closed. This is useful hostile host coverage, not production authority.

`report_before_fix.json` preserves the first failing run. Its three strict-ID
failures were a test fixture conversion issue (JSON numeric IDs became floats),
fixed in the harness. Missing anchor fields and stale winner were selector defects.
The final receipt is `report.json`.

## Remaining boundaries

The added fields are surface coordinates, **not a complete durable anchor**:
the actual host still must bind actor/life/session and native mesh/Skin/geometry
instance identities and revalidate them when resolving an anchor. Browser UUIDs
were not fabricated. A receipt tied to a current pose cannot be reused for another
pose/life without a proper anchor resolver. No source damage or physical impulse
permission follows from this geometry result.

Native refit/query/page wiring, current blocker snapshot lifetime, admitted source
targets, sweep scheduling/window, HP/medical/death consequences and loaded scene
performance remain integration work. No full-scene FPS is claimed or measured.
The hot-path change is one extra current-owner callback per successful selection
and a small final candidate payload; callback cost needs measurement in the real
host. Existing selection does synchronous complete queries and source-order scans.

## Frozen files (SHA256)

- `godot/mafiozi_walk/scripts/combat/melee_contact_selection.gd`:
  `58b43da1d21badd08003ae8b0aad59db631c6946467cdff8892f259f528039e8`
- `godot/mafiozi_walk/scripts/tests/test_melee_contact_selection.gd`:
  `df9969ade3b4b471950676eba0642f29d325d8a9aef62786efc00204af1aa827`
- `tools/godot/build_melee_contact_selection_oracle.mjs`:
  `63be534422dc869f5fe0829c7fbefb6c80b11789ee5b52072b95f681d2e3d271`
- `godot/mafiozi_walk/scripts/tests/fixtures/melee_contact_selection_oracle.json`:
  `5b5e41bafa953faa2c16117f5abab480e893af6caabebf89e8be41511f8fa511`

Run existing official Godot console with `--headless --path godot/mafiozi_walk
--script res://scripts/tests/test_melee_contact_selection.gd --quit-after 180`.
Only this test's report is written to `outputs/coordinator22_contact_selection`.
No commit/push was performed.

## Root22 acceptance

Independent read-only review found no concrete selector defect within the stated
trusted synchronous-port contract. Root reproduced **522 PASS /36 cases** in a
fresh minimal project using the committed Git HEAD source files and scalar kernel,
with no shared Godot import cache: `outputs/coordinator22_contact_clean/clean_test.log`.
The source pin is explicitly CRLF-to-LF normalized because the working source has
mixed endings while Git stores LF; source code was not changed. This check covers
portable fixture/source pins, not native extension packaging or main integration.
The existing interactive melee21b remains open and does not load this new module.
