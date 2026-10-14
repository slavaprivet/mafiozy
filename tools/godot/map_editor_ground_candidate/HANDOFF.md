# Native ground editor staged package

Output-only isolated Godot 4.7.2 package. Nothing in the running project's
`res://`, main, renderer, gameplay or exports was changed by this package.

## Actual checks

`Godot_v4.7.2-stable_win64_console.exe --headless --path outputs/map_editor_ground --script res://test_ground_document.gd`

126 model assertions + 66 brush/UI assertions PASS, exit 0, clean logs. Actual authored full topology
`assets/maps/city_rebuild_v1/topology_for_placement.json` admitted: 200 rows,
180 cols, 4.1 m cells, all original unknown fields and masks retained unchanged.
100-cell stroke on that grid stores 100 changed cells, not a grid clone per
pointer sample. This is headless CPU/resource admission, not LIVE/FPS acceptance.

## API

- `setup_baseline(source, origin_m: Vector3, history_limit=100)`: full topology
  (`map`, `grid`, top-level masks), preview surface, or block with `surface`.
  Setup copies and hashes the immutable source once. No baseline mutation.
- `pick_cell(local_world_xz: Vector2)`: restores source origin, then returns
  absolute row/col and exact `cell:r:c` ID. Far edges remain exclusive; a
  0.00001-cell snap handles native float32 representation at tile boundaries.
- `begin_stroke`, `set_tile(r,c,tile)`, `set_named_layer(r,c,name)`,
  `cancel_stroke`, `prepare_stroke`: staged deltas only; tile painting does not
  commit the model or touch source masks.
- `commit_stroke(physical_apply, nav_invalidate, physical_rollback)`;
  `undo`/`redo` take the same three callbacks. Callbacks return bool or `{ok}`.
  Physical row-strip replacement must succeed, then nav invalidation, then the
  model changes. On failure the physical rollback is called. If `rollback_ok`
  is false the host must stop editing/rebuild, rather than continuing on a
  potentially inconsistent physical scene. Callbacks must not reenter the model.
- `export_patch`, `validate_patch`, `load_patch(patch, callbacks...)`: sparse
  schema 1 overlays bound to canonical SHA256 of original source plus origin.
  Import rejects bounds/NaN/unknown fields/duplicates/protected cells/wrong base.
- `build_chunk(chunk_col, chunk_row, include_pending=false)`: at most 16x16
  cells, grouped transforms and changed chunk/row descriptors. There are no
  individual scene nodes per cell. `prepare_stroke` returns only dirty chunks,
  complete replacement strips for each dirty row, and cell before/after data.
- `build_chunk_delta(chunk_col, chunk_row, desired)`: uses explicit `delta.desired`
  after-states for undo, redo and imports even without an active stroke. Bounds,
  named-layer semantics and protected cells validate before building any plan.
- `row_strips(source_row)`, `surface_palette()`, `coordinate_info()`: read-only
  initial physics/render setup accessors. Palette and containers are detached.
- `build_multimesh_resources(plan, shared_materials, primitive_cache={},
  water_host_enabled=true)`: creates native MultiMesh resources only, one per
  tile kind per chunk. Returns reusable primitive cache; never changes existing
  host materials or meshes. Shared materials keys match source tile strings.

## Integration boundaries / unfinished host work

Painting preserves 0 asphalt, 8 grass, 9 sidewalk, 14 sand, 16 water semantics.
19 bridge is preserved but not paintable. Police, protected and bridge masks
remain immutable and prevent editing; unknown baseline data also stays intact.
The original road/walkable/etc masks are not silently rewritten. Host navigation
must explicitly consume desired edited cells; canonical road IDs and traffic
graph updates need their own owner adapter.

`dirt` and `earth` are separate named visual layers over dry tiles. They do not
reuse water/sand/sidewalk tile IDs and cannot cover water. Their original
approved materials must be provided as `layer:dirt` and `layer:earth`; the
factory refuses a missing material instead of guessing a color/shader.

Water remains delegated to the current source water host by default. Its
surface, swimming, surface-containment and topology receipts must be refreshed
by an explicit owner adapter whenever dirty cells affect water. The returned
`water_host_dirty` is a notification, not an implemented water integration.

## Brush and Russian UI package

`ground_brush.gd` is RefCounted input adapter, `ground_panel.gd` is signal-only
CanvasLayer UI, `test_ground_brush.gd` is the actual 200x180 source test runner.

Brush setup requires document plus `preview_chunks`, `physical_apply`,
`nav_invalidate`, `rollback` callables. Preview receives only touched chunk plans
as `{dirty_chunks, chunks, cancelled, preview}`. Painting LMB stages one stroke;
pointer movement interpolates a cell line with a bounded radius disk. Radius 1
means exactly one cell. Already touched cells are deduplicated, and only new
dirty chunks rebuild per pointer event. Source grid and physical rows are never
cloned/scanned per pointer sample. Release invokes the model transaction once.

`handle_input(event, camera, panel.input_guard)` refuses painting over the panel
or while its SpinBox text input has focus. A missing guard refuses painting.
`focus_lost()` and `set_active(false)` cancel unfinished strokes and request a
committed-state preview refresh. The host must call focus_lost on app focus loss.
It must route brush mouse input before object picking while ground mode is on.
`setup(..., ground_frame, plane_y)` uses camera ray against the owner's native
city plane, then converts world intersection to exact source grid coordinates.

Panel emits `ground_tile`, `ground_layer`, `ground_radius`, `ground_undo`,
`ground_redo`; the owner routes these to brush methods. Dirt/earth are explicit
named-layer choices, with a separate clear-layer action. No UI unlock Boolean
exists. Protected cells are skipped with a visible Russian message.

The brush `committed(result)` signal fires after successful data commit. The
owner must finalize the renderer transaction there, retaining rollback resources
until then. Before invoking any physical callback, the owner must hold a paused
edit lease and stop resident jobs/invalidate receipts. Nav refresh follows the
physical swap and precedes the model commit. A failed rollback disables brush
activation and requires owner scene recovery.

## Frozen native renderer and repeated source-copy verification

`ground_renderer.gd` supplies staged renderer/strip-body replacement, with
shared source materials and meshes, 16x16 render chunks and physical row strips.
The source copy here was independently rerun: model126, brush66 and renderer19956
checks PASS with Godot4.7.2, including actual200x180 and cropped31x31 topology.
The repeated40-transaction CPU scenario: p50/p95 3336/4781us, one dirty chunk
and one row per action; initial source hashing/build1112454us. Not gameplayFPS.

API: configure(document, materials, paused_lease, water_phase_adapter,
navigation_gate). commit_stroke/undo/redo finalize resources after model commit.
Manual apply/validate_navigation/rollback callbacks support the brush; call
finalize(true) only after model commit. Water owns prepare/apply/rollback/finalize.
Failed cleanup after commit returns committed:true,retry_finalize:true; keep
the session paused and retry cleanup. Never roll back physics alone after model
commit or resume play while a transaction remains pending.

The owner still needs actual navigation/water adapters, main input/UI attachment
and persistence alongside object patches. Native material visual parity and
full-scene frame p50/p95 are NOT_RUN. This source candidate remains outside the
live Godot res tree; it does not replace the user's current floor automatically.

Root integration follow-up: brush undo/redo now emit committed, just like an
actual stroke, so the host can finalize each pending renderer transaction.
Unchanged strokes do not emit that signal. Updated brush69 checks PASS and
test_brush_renderer12 checks PASS using actual renderer callbacks: no pending
resources remain after stroke/undo/redo, no absent transaction is finalized.

Atomic follow-up: GroundDocument now provides sparse capture/restore checkpoint,
begin/end install guard, prepare_patch and callback-free commit_prepared_patch.
Normal paint/history APIs refuse while the cross-owner import holds the guard.
GroundRenderer validates lease again after callbacks and retains a denied water
rollback receipt after restoring core floor/render scene; retry is idempotent.
These changes were independently checked in full atomic actual242/243 +200x180
test66599 PASS. Actual nav/water callback admission remains the production owner.

Editor-only brush hints now have a real native owner `ground_preview.gd`.
`configure(document, edit_lease)` then pass `preview.apply` as preview_chunks
and the node as optional seventh workspace.setup argument. Its transform must
be supplied explicitly in the same coordinate frame as the brush/terrain.
Only changed pending cells in dirty chunks are highlighted; cursor is a bounded
radius1..8 disk (maximum149 cells), protected cells have distinct marker tint.
Resources are editor-owned/shared, no source materials/water/collisions/nav are
changed. Identical cursor reuses resources. Cancel/GUI/focus/exit hides hints;
callbacks reject lost lease. The green marker is a hint, not simulated water or
an assertion of the painted material's visual quality.

Root native preview24 + document126 + brush69 + workspace25 checks PASS.
Fresh196GLB source import + actual242/fresh243/full200x180 assembly12782PASS
now routes native LMB to real preview nodes, brush, renderer and atomic file
workflow; load874829us CPU, no GPU/LIVE proof. `preview_chunk_cells` scans at
most256 cells per requested dirty chunk and never builds navigation/rows.
