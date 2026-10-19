# Full procedural frame-slice candidate — source-only HOLD

`frame_budget_factory.gd` subclasses the existing detached incremental V3
factory. After its pinned `begin_configure/configure_step` and
`begin_exploration`, use `step_exploration_parts(1..64)` until complete, then
`finish_exploration`, `begin_roads`, `step_road_parts(1..64)` and `finish_all`.
The old whole-batch step methods are refused. All 531 original batch identities,
their order, source IDs, materials, Float32 matrix/color buffers, shadow and
road-world transforms, original 59 paint meshes and six-vertex paint slots are
retained. No 1702-part batch is split into separate draw calls. Roots stay
detached; the inherited exact 9394-ID closure is still mandatory.

At most 64 *part-loop iterations* run per call, including inside the original
1702-slot road equipment batch. This is not a millisecond/frame guarantee:
initial manifest/catalog JSON parsing, Float32 conversion, mesh creation,
final full-batch `MultiMesh.buffer` upload, and road bounds are still atomic.
In particular, uploading one 1702-instance buffer may still hitch. It needs
opt-in native timing, memory and one-game GPU parity under Coordinator23's
window before any integration. No production scene, main script, Godot project,
GPU session or owner file is modified here.

Run `node tools/godot/map_editor_frame_budget_candidate/test_source_parity.mjs`
for pinned-source shape, ordered slice and guard checks. These are static/source
checks only, not native execution. The candidate intentionally has no stage or
installation command until that owner window is approved.
