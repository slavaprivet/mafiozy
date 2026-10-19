# Authored model CPU preparation audit/candidate

Isolated original source objects, no production/main/player/GPU/Git writes.
Frozen catalog factory, object registry, materials, meshes, source ID/ownership,
collision contours/masks and pending special interiors stay unchanged.

## Measurement and actual resource census

242 current authored objects use **33 placed GLB SHAs**, not196 simultaneous
assets. All196 original palette/LOD GLBs remain admitted/imported;163 are not
currently placed. Do not preload them all as an alleged optimization.

Native census7484 checks PASS:6772 visible MeshInstance3Ds,7065 source surfaces
and7065 shadow surface potential submissions,1968 shared Mesh resources,
298 shared Materials; no scene-local materials, no texture resources in these
33 current placed models. No texture is removed or downsampled. Source rest of
palette remains untouched; this statement is not a full palette texture audit.

All355 admitted original convex bodies remain private; strict point bytes +
float64 margin census finds293 unique payloads/62duplicates. Pooling them would
introduce cross-owner in-place mutation risk for little measured benefit, so
**no pooling or collider merging implemented**. Six special owners remain
pending their trusted adapter, not accidentally unlocked.

Cold source-SHA/nativePackedScene load33 resources315103us. Warm original
creation/registration profile median193960us; helper predicates35.6ms over7946
nodes; registry traverses9140 nodes twice for body/bounds snapshots. Inclusive
profile timings overlap; these are not GPU/FPS measurements.

## Narrow separate subclasses

authored_factory_perf.gd extends res://scripts/map_editor/catalog_factory.gd.
Only original helper-name decisions are memoized; exact regex pattern + array
of str(explicitNames) is the context key. No path cache/scene pruning or new
heuristics. Preserve validated explicit names, Node3D-only hiding, existing
inherited visibility; get_pattern binds changes to original regex. configure
clears the context cache, max64 contexts. Resource SHA/size/path admission,
original PackedScene loading/instantiation and all collider/owner logic remain
inherited. .new()/configure/spawn/spawn_key signatures unchanged.

authored_registry_perf.gd extends res://scripts/map_editor/object_registry.gd.
Original participant/dependency admission, ordering, descendant skipping,
WeakRef/frame/visibility/bodymask snapshots, source opaque+JSON transport and
transform extras stay exact. Root body+visible-mesh bounds collect in one
original-order walk; external dependencies retain original body collection.
No selection BVH, picking, apply, clone, lifetime guard, checkpoint, rollback,
publication or paused-pipeline mutation. Those remain inherited unchanged.
Constructor and public API identical. Only register_object/one new helper differ.

## Native exact proof and measured benefit

8960 checks PASS: every actual node topology/authored name, local transform,
visibility, shadow state, same original PackedScene/Mesh/active Material
identity, original355 point bytes/margin/body layer/mask; original registry
snapshot equality on SAME source roots including exact body/participant
WeakRefs/order/bounds/source/opaque variants. Runtime-generated @ collision
names are compared by source child-index topology, not unstable allocator IDs.
Explicit helper fixtures COLON/Columns/NavalMuseum/Fascade_proxyDecoration and
validated names match original; predicate-change invalidation is tested.

Uninstrumented1warm+7sample variant-order-rotated complete242-object batches:
baseline median/p95179143/186796us; helperOnly159602/169824us;
registryOnly169835/181061us; both149355/152038us.
Both save29788us (**16.6%**) for this warm preparation phase.
This is approximately30ms across all242 objects, not a dramatic whole-game
frame/loading claim. Only7 samples; CPU background noise remains possible.
Cold native resource loading is unchanged; no FPS/draw-call GPU claim.

Original actual Controller assembly12782 PASS (242→fresh243 + full200×180ground).
Original atomic/rollback/fresh-load66599 PASS using ONLY these two explicit
constructor substitutions. No shortcuts in safety tests.

benchmark.json contains raw measurements/census. Prior source render audit
already quantified strict32m/64m batch eligibility; this package does NOT create
another batcher or reinterpret7065 potential surfaces as measured GPU calls.

## Reproduce

node tools/godot/map_editor_authored_perf_candidate/stage.mjs --check
node tools/godot/map_editor_authored_perf_candidate/stage.mjs --stage
Creates source-only fresh outputs assembly, noUID/import-cache copy. Use
approved console --headless --editor --path OUTPUT --import once; sequential
--headless scripts test_authored_audit.gd, test_authored_perf.gd,
test_authored_atomic.gd, test_authored_assembly.gd. No second GPU window.
Root may explicitly copy the two runtime subclasses + select constructors in
another test assembly after review. Do not overwrite frozen base files.
Keep regular gameplay/visual/live collision/performance owner acceptance open.
