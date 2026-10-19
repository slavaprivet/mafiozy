# Full 9901-map editor: bounded-load plan (30 September 2026)

Update 30 September: the first preparation-only cursor now has a native
fixture receipt at `tools/godot/map_editor_incremental_prepare_candidate/native_verification.json`.
Godot 4.7.2 imported its isolated full assembly cleanly; two sequential
20,328-check runs matched the existing normalized document and rejection
errors across all 9,901 source records. The cursor was driven in 474–582
process-frame batches for a valid document. These timings include waits, not
exclusive CPU cost. This does **not** split composite/owner application,
remove the final 13–17 s hitch, or establish a real gameplay pause lease,
full-world rendering or GPU performance. The following design and gates remain.

Status: source-only analysis; no new Godot run, benchmark, GPU measurement or production change. The timed operation is **fresh `Controller.install_document()` after `make_session()` has already constructed the world**, not complete startup or render readiness. The 9901 source records comprise 242 authored, 9394 procedural and 265 transport records; 6 special buildings and 32 railway records remain protected/HOLD, not fully editable scene owners. Actual pause/navigation/traffic callbacks in these tests are fixtures.

## Existing CPU evidence and call graph

| Existing report | Scope / inclusive phase | Time |
| --- | --- | ---: |
| [full assembly](../../tools/godot/map_editor_assembly_candidate/README.md) | 9901→9904 paged-editor install; separate exact-record verification | 13.018 s; 0.583 s (single run) |
| [import profile](../../tools/godot/map_editor_import_perf_candidate/benchmark.json) | baseline/optimized full install medians, three sequential pairs | 15.431→13.792 s (−10.6%; earlier MapDocument snapshot) |
| same profile, baseline instrumented | procedural `_check`, 56,381 calls; procedural `apply_document` inclusive; composite partition twice; controller prepare | 6.321 s; 7.956 s; 2.149 s; 1.684 s |
| same profile | procedural geometry-owner `_prepare`, 20 calls; transport `_check`, 1607 calls | 0.000373 s; 0.303 s |
| [authored profile](../../tools/godot/map_editor_authored_perf_candidate/benchmark.json) | 33 placed GLB resources cold load/SHA; 242 warm authored spawn+register | 0.315 s; median 0.194 s |

The profiled phases **nest and overlap**; their numbers cannot be added into a total. Authored resource load/spawn and initial 9901-world construction happen before the timed install in the full assembly, so the 13–17 s is only a lower bound for a cold editor startup. The 196 imported GLBs are a palette; only 33 distinct GLBs are currently placed. Existing CPU optimizations preserve validation and source geometry but do not establish frame time or FPS.

The synchronous path is `Controller.install_document` → `prepare_install_document` (whole-document schema and provenance) → copies → `Composite.apply_document(..., true)` → `Composite.apply_document(...)` → `MapDocument.load_document`. Each composite invocation partitions the whole document, calls each owner `apply_record(..., true)` for every row, then each owner `apply_document`; the non-dry invocation repeats full preflight, captures an owner checkpoint and applies the owners. Procedural/transport `apply_document` repeat validation, then traverse desired records and update owner geometry/MultiMesh synchronously. The separate `AtomicMapImport.install_bundle` adds the shared pause lease, scene/model/ground checkpoints and guards, ground/nav preparation, silent model commits and final notifications; it is also one synchronous call. No current API yields at a safe row boundary. Simply inserting `await process_frame` inside these calls would expose partially staged owners and invalidate their local rollback/checkpoint assumptions.

## Proposed one-scene incremental design (new API, not yet implemented)

1. **Admit and pin:** In the sole editor scene, acquire the actual gameplay pause lease, then `begin_atomic_install` plus document/ground guards. Pin source hash, owner instances/generations, input/selection state, model/history checkpoints and intended 9901 IDs. Refuse play, edits, save/reload and second import until finalization. The controller's existing `atomic_install_active` already blocks actions/exit/input, but a real host must prove game physics, melee, NPC, transport, water and navigation quiescence; fixture callbacks do not.
2. **Budgeted preparation:** Add explicit cursor/state-machine APIs for whole-document validation/provenance, copy/resource preparation, per-owner row preflight and geometry staging. Process small bounded batches from an editor coordinator that continues in `PROCESS_MODE_ALWAYS` while gameplay is paused; schedule the next batch at `process_frame`, recheck lease and pinned owner lifetimes/generations each boundary. Keep candidate records and staged visuals detached/hidden from gameplay and the live registry. Never treat a partially checked chunk as accepted. Choose batch size by subsequent whole-scene p50/p95 measurements, not the present 13 s average.
3. **Atomic publication:** After all owners, ground and navigation attest the complete target, revalidate the pinned snapshot and dependencies. Publish one coherent registry/document/ground revision, one history policy (load resets undo/redo exactly as current `MapDocument` does), and one notification; then rebuild/verify play-side colliders/routes before lease release. If publication itself still exceeds the frame budget, it needs a double-buffered owner representation with constant-time root/revision swap; current per-record `apply_document` cannot provide that. On any precommit failure discard hidden staging and restore checkpoints; on postcommit finalization failure retain the paused lease and retry. Do not split a full-map load into thousands of user-visible undo entries or allow a frame with a half-new map.

An immediately feasible lower-risk first step is *precompute/warm in bounded slices* while the lease is held, leaving the existing synchronous commit untouched. This may improve responsiveness during preparation but cannot claim removal of the final hitch. A genuine bounded install requires redesigned owner APIs and rollback receipts; a long lease is necessary but not sufficient for atomicity.

## Graphics constraint, separate from CPU admission

The authored census has 6820 mesh nodes, 6772 visible nodes and 7065 potential surface submissions (plus 7065 shadow-surface potential) for the 33 placed GLB types; these are not measured draw calls. PackedScene meshes/materials are already shared (1968 unique mesh resources, 298 materials), so repeated resource loading is not the only graphics question. A future batch/instancing prototype must group only compatible mesh **surface**, effective material, shader/texture/parameter state, shadow cast/receive, GI/lightmap mode, render layers, visibility/culling/LOD and any per-instance shader state. Preserve a reverse mapping `(source ID, child/surface) → batch slot`; ID is an identity/index key, **not** part of the equality grouping, or no cross-object batching occurs. Mutable per-object transform, visibility, selection, delete and undo must update or restore exactly that slot and preserve original collision nodes, doors/interiors and protected owners. Do not pool private collision shapes or flatten unlike GLB helpers merely to reduce submissions. This is a separate LIVE GPU hypothesis, not a proven benefit of the CPU import optimization.

Acceptance gates before production: exact 9901 ID/source/byte and 38-HOLD parity; failure/retry/rollback and stale-owner tests across yield boundaries; save/reload/undo and protected-object behavior; bounded max-frame and total-load measurements in the **same loaded scene**; then a single coordinated visible-game GPU comparison (p50/p95 frame time, draw calls/triangles, fidelity/collision/nav), with no second GPU scene. Until then this plan is HOLD for production.
