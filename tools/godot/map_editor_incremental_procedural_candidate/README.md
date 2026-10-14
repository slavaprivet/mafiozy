# Procedural 9,394-ID incremental preview boundary — source-only HOLD

`source_index.mjs` is an executable, read-only dependency index, **not a native
preview builder**. It pins the frozen V3 native factory/registry, original
Three-180 procedural manifest, catalog and all 982 binary buffers. Its
`batchWindow(index,cursor,maxBatches,maxParts)` returns original-order batch
descriptors and refuses a budget smaller than one indivisible batch. It always
returns `renderedIds:0`: metadata coverage is not scene or GPU coverage.
`test_source_index.mjs` passes 1,085 assertions including incomplete/foreign
ID, missing material/buffer, duplicate batch, stale catalog and too-small
budget negatives. No Godot, GPU, production, frozen source or `main.gd` was run
or edited.

## Executable 531-batch geometry slice — unrun native fixture

`incremental_factory.gd` subclasses the exact pinned V3 factory. Its
`begin_configure` / `configure_step(1..64)` load the 982 original buffer hashes,
86 meshes, 10 materials and 9,394 source descriptors in source order. Its
`begin_exploration` / `build_batch_step(1..4)` submit the original Float32
matrices/colors and mesh/material references for each of the **464 exploration
batches** into a detached root. `finish_exploration` requires exactly 464
batches, 2,440 IDs and 464 uploads, but does **not** return a publishable root.
`begin_roads` / `build_road_batch_step(1..4)` then build the exact 5 equipment,
3 traffic-bulb and 59 merged-paint batches into a second detached root. Original
material, mesh, Float32 upload, six-vertex paint slot, world transform and
shadow settings are retained. `source_stage_complete(id)` requires every
distinct original batch containing that ID, not its first part. Only
`finish_all` can return both roots, after exact 9,394-ID, 505 road-control,
6,449 paint-ID and 472 MultiMesh batch closure; even then it reports
`renderedIds:0` because no scene owner has attached or published the roots.
Eager bypass, edits/undo/LOD while partially built, stale/destroyed/reparented
roots and partial publication fail closed.

The copied source formulas for geometry, material and MultiMesh submission
pass 147/147 static parity checks against pinned factory SHA-256
`280880c927809d0d773c3175cdf43fc7534a772af286d77fbf0b50a85fe53628`.
The current candidate SHA-256 is
`bbe59b30a045b16e68829f621860f5f85e338dc4d3b676357c26ee683b367f37`.
The read-only stager verified 989 source/fixture files, 23,962,015 bytes and all
982 original binary hashes without creating a stage. `test_incremental_factory.gd`
is an **unrun** opt-in headless fixture that compares every buffer, geometry,
material, all 531 batch CPU uploads, road paint mapping, traffic phase,
source part/frame and LOD result to the eager factory, and checks
partial-publication and stale-SHA negatives. No native
parse/pass is claimed until Coordinator22 gives a separate Godot CPU GO.

Each step bounds *item count*, not milliseconds. Initial manifest decoding,
catalog JSON parsing and a single geometry or 1,702-part road batch can
still be long; a ≤2 ms frame guarantee needs native measurement and possibly
finer within-batch staging without changing final MultiMesh identity. The
detached root is not a gameplay pause lease or atomic scene publication.

Exact index: 9,394 unique IDs, 531 shared batches (464 exploration, 5 road
equipment, 3 dynamic traffic-bulb, 59 merged paint), 38,738 mapped instance/
paint slots, 982 hashed buffers. Index SHA-256:
`fc68958f48def5cd4d8f90795874cca94df145690549a5166b306a9a1da322d6`.
At most 1,702 slots occur in one indivisible batch; 2,733 source IDs span
2–6 different batches. A batch contains up to 505 distinct source IDs. The
existing native factory has only eager `configure`, `build_exploration` and
`build_roads`: no source-exact `build_one_id` or resumable API. Building each ID
as a separate mesh would break the original shared batch/material/LOD and
paint-slot relationships, so this candidate deliberately does **not** fabricate
one. The 267 example metadata windows (≤2 batches, ≤1,702 slots) do not imply
267 render frames or a 2 ms frame budget.

Full-world native implementation contract, still HOLD:

1. Native-verify the new 531-batch slice and split any oversized individual
   configure/batch operation; current item-count steps are not a time budget.
2. Attest original mesh/material, world-origin, LOD, paint/depth, traffic phase
   and cast/receive parity in native/GPU checks. The source-only formula proof
   is not native execution or pixels; geometry completion is not rendering.
3. Keep the growing roots detached and inaccessible to gameplay/editor
   selection. Pin the factory/source generation and source-ID index across
   every yield; reject stale owner, changed source, failed buffer, partial
   batch, missing dependency, reentry or concurrent edit. On failure discard
   the unpublished root/resources; never publish a partial registry/undo state.
4. Publish the complete root and 9,394-ID registry only under the actual
   gameplay pause/owner lease, then verify collision/nav/traffic owners and
   original visual equality. An individual 1,702-slot batch may itself exceed
   the eventual frame budget and require a within-batch CPU staging/upload
   design without changing its final MultiMesh identity.

This package does not yet claim native parity, initialization speedup,
whole-world FPS or default editor readiness. The
frozen V3's earlier native parity receipts remain evidence for that **eager**
factory only; a future incremental native factory needs independent headless
and root-coordinated one-game LIVE checks.
