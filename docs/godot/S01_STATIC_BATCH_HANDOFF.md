# S01 static rendering batch — Artist21

2026-09-27 local. New helper and test only; main/project/assets/exporter/interior/player were not edited. Root21 owns the hook, export dependency and single-game GPU measurement. The helper is not yet integrated in the visible game.

## Contract and hook

```gdscript
const StaticBatch = preload("res://scripts/preview_static_batch.gd")
var static_lease := StaticBatch.new() # Root retains this through scene lifetime.
var declarations := []
# Only explicitly owned static building/lamp roots. Do not include printshop.
for owner in approved_static_roots:
    declarations.append({
        "root": owner,
        "source_id": owner.get_meta("source_id"),
        "static_authorized": true,
        "shared_sun_sky_only": true,
        "allow_static_gi_without_capture": true,
    })
var plan: Dictionary = static_lease.plan(self, declarations, 16.0)
if plan.ok:
    var applied: bool = static_lease.apply()
    # applied=false leaves every original untouched. Inspect errors if needed.
# Restore BEFORE activating local lights/probes/GI or modifying source content.
static_lease.restore()
```

Root explicitly admitted current quarter's shared sun/sky and absence of baked lightmaps/GI capture/probes/local lights. GI_STATIC is copied unchanged, not disabled. A new world without that contract must not set allow_static_gi_without_capture. Whole-tree bounded preflight at plan and commit rejects non-directional lights, ReflectionProbe, LightmapGI, VoxelGI and enabled environment SDFGI. Owner scan rejects animation/skeleton/light/probe branches; commit repeats admission so new dependencies cannot slip in between planning and applying. `lighting_contract_valid()` is available for an owner feature gate; restore must precede dependency activation. There is no per-frame polling.

Explicit declaration means all source geometry/resources and their ancestors remain static during the lease. Restore/rebuild before source movement, hiding, material mutation, interaction activation or model replacement. It is a caller ownership contract, not proof that a scriptless mesh can never move. Main-thread calls only. Root retains the handle and calls restore on its scene cleanup. Preserved source nodes do not preserve original renderer-RID picking identity: use the unchanged authoritative physics/source IDs.

## What is preserved

Original nodes, parents, meshes, materials, source metadata and collision nodes are retained. Only accepted leaf MeshInstance3D.visible changes; restore reinstates its saved local visibility. Batches are children of the same source owner, so owner visibility ancestry is retained. Different owners never share a batch. All transforms are admitted and source colors/textures/vertex channels are retained through the representative original mesh/material. No color/custom-data modulation is introduced. Render layers, shadows, GI mode, cull margin, occlusion setting and lod_bias are grouped and copied. No source geometry/UV/index/material or physics data is rewritten.

Resource identity alone found zero useful groups in the current imports. The helper therefore compares full native packed surface bytes (format, primitive, vertices, attributes, indices, UV scale and bounds), including shadow mesh bytes. It uses SHA buckets plus full byte equality, not a hash-only or approximate match. Effective opaque StandardMaterial STORAGE properties are compared exactly; texture/resource object identity is retained. Resource names/paths/local-to-scene and editor metadata do not affect that material equivalence. Unknown material types, overrides, transparency, next passes, displacement/billboard/fade/triplanar cases are excluded. LOD, skin/bone/blendshape, dynamic geometry, unknown/empty packed buffers and nested shadow chains are excluded rather than flattened or removed.

The native shader's per-instance normal transform cannot safely handle arbitrary nonuniform scaling. Each group factors its first source global basis into the batch node; only positive uniform orthogonal residual bases are admitted. Native batch model normal uses inverse-transpose, so the common nonuniform authored scale is preserved. Normal parity is subject to numerical tolerances in tests, not a bitwise GPU claim. Reflections, shear, singular transforms and incompatible residual scale are excluded.

Spatial cells use floor for negative coordinates. Each full world AABB, including cull margin, must fit the same16m XZ cell. Each group has at least2 and at most64 instances; roots32/owner scan4096/lighting scan16384 limits fail closed. MultiMesh custom bounds union all uploaded transformed mesh AABBs. One node is not one total draw: surfaces, passes and shadows matter. MultiMesh culls a group as a whole; exact individual frustum/occlusion/LOD behavior is not claimed. No global world mesh is created.

Plan and commit are synchronous startup operations. Signatures/buffer caches are released after a successful commit; the runtime lease retains only restoration references and bounded CPU upload receipts. No update loop or per-frame traversal is added. Receipts are CPU arguments sent to native setters, not native buffer readback: Godot's headless dummy backend returns identity/empty MultiMesh buffers. Root GPU verification remains required.

## Tests and acceptance

Author actual Godot4.7.2 ed1daf0bf headless:71 checks PASS, exit0/no script errors. Tests cover independent identical mesh resources, colors/shadow/layers differences, LOD exclusion, material/visibility/owner gates, geometry and normal composition with common nonuniform scale, idempotent restore/rebuild, IDs/collision authority and precommit mutation. Intentional unsupported cases remain unchanged.

Independent actual Godot headless adversarial review:130 checks PASS, exit0, final helper bytes. Dynamic ancestor and post-plan sibling/dependency findings were fixed and retested; no outstanding bounded defect. `outputs/astra21_static_batch_audit/REVIEW.md` and independent_test.gd contain the complete receipt.

Independent actual imported quarter/helper verification:172452 checks PASS,69groups/248batched source nodes,291eligible. Batched surface-submission estimate248→69 (179 reduction);43singletons remain original. This is not179 measured GPU draws.50676world vertices maxerror3.9321e-6m,50676normals maxvectorerror1.3328e-7; original552mesh identities/frames/material properties/main+shadow bytes and27separate collider IDs/shapes retained. The entire printshop owner remains untouched. Actual owner-hide, restore/double-restore/rebuild/double-apply checked. The fixture does not run main/terrain/player/interior, so it does not certify absence of dependencies in root's full world.

Single actual headless startup sample: plan77.655ms/apply34.954ms/restore1.073ms/replan71.853ms. Plan+apply112.609ms is one-time loading work, not a frame-time distribution. Run before preview readiness/controlled rebuild; no live per-frame apply. Native dummy MultiMesh transform readback remains unavailable. Full receipt: `outputs/astra21_static_batch_audit/ACTUAL_HELPER_RESULT.md`, actual_helper_test.gd, actual_helper_result.json and actual_helper_headless.log.

| Final file | SHA256 |
|---|---|
| scripts/preview_static_batch.gd |53618a287f52310ef4acea9ec4e2fbad0e5a79d4d29d2ad125a453f32c74ebf3|
| scripts/tests/test_preview_static_batch.gd |e747f9cc0732b1859d6ee63f20efb90405150e01d8f01b0526297a05c7f0eae8|
| independent_test.gd |8c01730aefd045b386bd00480b5601363008877af8fd9729bdeb4bab642e3714|
| actual_helper_test.gd |1123b4da80069cf1bb6c1b2908fa216c2a2567c39fb615bb51d92c8c34c2b89e|
| actual_helper_result.json |3d14cb85e98d109c45f90de0bb82e71b4c52e052fe2d2da817da8f5cda55afb0|

## Root acceptance still required

Add the helper's literal file dependency to export before hooking main. In the single game, compare OFF/ON with identical camera/settings/population/warm-up: frame p50/p95, actual draw calls/triangles, material/shadow appearance and geometry/culling around gun shop/pawnshop. Keep all source content and physical doors/collisions. Verify native MultiMesh transport/rendered normals and clipping: CPU/dummy tests cannot close those gates. Do not equate startup CPU cost or estimated grouped submissions with full-scene FPS.
