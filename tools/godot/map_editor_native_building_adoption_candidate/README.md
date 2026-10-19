# Actual native building inventory — source-only adoption audit

27 September 2026. **HOLD: diagnostic, not native editor permission or full-map integration.** No production/frozen files changed. The test loads actual `scenes/main.tscn` in the Document agent's imported source closure `outputs/actual-main-pause-probe-qAWF1V`. Main revision is `s01-20260927-melee21`; default transport/melee enabled, residents disabled. No GPU or renderer visual readback.

## Reproduction

Use Godot 4.7.2 console with `--headless --path <absolute closure> --quit-after 1200 --script <absolute test_inventory.gd>`. Repeat with trailing `-- --preview-static-batch`.

- Default actual scene: **326 checks PASS**, exit 0, no engine diagnostics.
- Actual startup static batches enabled: **962 checks PASS**, exit 0, no engine diagnostics; 69 CPU batch receipts.
- Reports are closure-local `BUILDING_INVENTORY_REPORT.json` and `BUILDING_BATCH_INVENTORY_REPORT.json`. Source placement SHA matches the real block's pinned full source.
- Each synchronous audit preserves exact node/parent/child identities, transforms, visibility, collision filters, shape identities and convex/concave point arrays, mesh/material resource identities and shadows. This is not a complete material-content or native MultiMesh GPU upload attestation.
- Initial faulty fixture disabled the entire main subtree BEFORE `_ready`, causing `body_A->get_space() is null` during ragdoll joint configuration. That was a **fixture error**, not a discovered production bug. Corrected fixture permits normal bootstrap, awaits the actual owner `preview_ready` with a 120-physics-frame limit (default attains it synchronously), then reads synchronously and defers teardown. Initial batch test also incorrectly assumed batches were main siblings; actual source-owned parent hierarchy is now asserted.
- Separate small explicitly synthetic native lifetime fixtures reject queued owner/visual/sibling/interior/interior-collider references before deferred deletion, duplicate/unknown source records and ambiguous full-source IDs. No adversarial disposal is performed on the original house inventory.

## Observed real hierarchy

Full original `buildings_placement.v1.json`: 75 buildings, SHA `90e0b27196b51fc1f09ccc67d4c5f8374d5c37611576106f34b30559e86ed3ca`. Current main's crop has 8 buildings, so **67 source building IDs are outside this scene**, including three banks, hospital, civic hall and other homes. They cannot be adopted from nonexistent native nodes; constructing standalone editor fixtures is not full native map adoption. The report lists every missing ID. Separate detention/special/procedural/catalog families remain separate inventories; this 75-record result does not claim coverage of all ~9901 objects.

| Native source building | Existing direct-main sibling bodies |
|---|---:|
| print_shop-001 | 0 (special owner instead) |
| old_town_narrow_townhouse_v1-013 | 2 |
| old_town_narrow_townhouse_v1-005 | 2 |
| gun_shop-001 | 3 |
| pawnshop-001 | 3 |
| old_town_narrow_townhouse_v1-004 | 2 |
| old_town_narrow_townhouse_v1-012 | 2 |
| old_town_narrow_townhouse_v1-007 | 2 |

All IDs have actual prefix `REBUILD-VISUAL-`. `main._add_asset` creates a direct-main `Node3D` root with `source_id`, native yaw/nonuniform scale and an offset imported visual child. Ordinary `StaticBody3D` collision siblings have the same `source_id` plus original `source_index`, identity transform, and source convex points already in preview-local coordinates. There are **16 ordinary building sibling bodies**; main's summary `source_colliders=27` also counts decor and is not the Printshop generated interior count. Don't parent/copy/rebuild sibling collision bodies or apply a visual-local transform directly to their world-coordinate points.

`inventory.inspect` only resolves actual references and classifications. Its `registry_id=buildings:<source_id>` is the canonical key mapping, not a registration. Every row and report explicitly refuses edit/authority admission. The helper trusts caller-supplied diagnostic records; it is not a JSON validation or security boundary.

## Required reversible native adoption contract (proposed, not existing)

| Owner / actual API | Safe source-only integration requirement |
|---|---|
| `main._add_asset`; no public adoption capsule API | Main must issue an opaque native inventory capsule binding owner instance, generation, source script lifecycle, exact source descriptor/origin, canonical full ID, visual root, sibling collider IDs/source indices, resources and parents. Main must admit **existing** nodes under an actual paused lease; no scene rebuild and no permissive JSON flag. |
| Editor `ObjectRegistry.register_object(id, root, record, dependencies, editable)` | Ordinary candidate may supply existing root + explicit same-source sibling bodies as dependencies. Register only after owner admission and batch detachment. Registry applies shared `delta = new_root_frame * old_root_frame.affine_inverse()` to each independent participant ONCE; descendants inherit once. Keep native resources/shape points unchanged. Baseline record must preserve source metadata/origin and full canonical ID, not pretend preview-local coordinates are original global source coordinates. |
| Registry move/delete/undo existing node mechanics | Native source owner must prepare/checkpoint/apply/preflight-restore/finalize, including exact frames, prior visibility, prior layer/mask, disabled state, all collider parents/resource identities and support/door/nav participant versions. Delete retains owned nodes and disables exact source participants; undo restores historical flags, not default `true`/`1`. Never `free` original nodes. Sibling world frames transformed during edit mean original block collision descriptors no longer directly describe current geometry. Source owner must publish an explicit admitted current geometry view for downstream consumers. |
| `main.apply_preview_static_batches` / `restore_preview_static_batches(reason)` | These are startup/rebuild helpers, NOT transactional editor ownership. Restore currently returns void, frees batches, skips missing source weakrefs and main clears the lease. Native admission needs read-only ALL-owner restore preflight + opaque captured original visibility/parent/frame/material bindings + checked restore outcome/retained failure. Restore **before** bounds capture/edit. Reapply only through source owner after committed current source geometry/lighting admission. |
| `preview_static_batch.batch_receipts` | 69 real batches are children of ORIGINAL visual source roots, not main siblings. Receipts bind weak source meshes, source IDs, exact CPU instance transforms, custom AABB and mesh/material signatures. Do not register each generated batch as a new source object. Registry's current `_collect_bounds` reads visible `MeshInstance3D`, not generated `MultiMeshInstance3D`; active batching hides originals and therefore cannot supply complete editor bounds without proper owner restoration. Moving active source roots may mechanically move their batches but does not prove future source batching/light/nav/support correctness. |
| `PrintshopInterior.attach_existing`, `anchor`, `nearest_action`, `request_door`, `advance`, `restore_original` | Keep Printshop **protected** until its actual owner implements a reversible transform/delete capsule. Imported root and generated interior are siblings; generated adapter owns 103 source-static bodies, 4 floor/ceiling bodies and 2 bodies per public/service door = **111 bodies**. These have `source_id` + `interior_kind`, NOT source_index. The three original envelope collision bodies are deliberately absent. `restore_original` destroys generated children and material overrides and is NOT edit undo. |
| Printshop `_data`, `_doors`, `_restores`, shader world-coordinate origin | Generated mesh matrices, floor/static points, door base/current frames, door source anchor/proximity/sweep, all `_data.anchors`, exact original mesh override/visibility restore refs, occupancy tests and finish material origin form one owner packet. `anchor()` returns `_data` coordinates directly; moving the adapter/root alone leaves action/nav anchors stale. No generic `register_object` admission can transform these CPU fields correctly. Special source authority/staff access must remain unchanged. |
| `preview_navigation_host.attach_existing`, `door_transition_started`, `update_access_version`, `pump` | Existing host captures original direct sibling shapes and Printshop source arrays and checks exact frames against source descriptors. It caches static geometry in `_static`; later private `_publish()` only updates door leaves. There is no public arbitrary-building/ground transactional geometry API. Need trusted prepare-geometry/current-node capture, pending-job invalidation under lease, checked async publication readiness, exact rollback and current version/support bindings. `update_access_version()` is access-only, not geometry rebuild. `door_transition_started()` is door-only, not building migration. Never call private functions or dispose/recreate the whole host to fake admission. |
| Real pause/NPC/transport/native bodies and source queries | Main owner must provide the genuine compound pause/input lease, current pending query/job capsules, NPC/transport/building-support and occupant admissions. Residents disabled in this fixture do NOT grant admission when NPCs are enabled. Resume only after both geometry and support/nav readiness; no deleting/moving an actor's support and then simply restoring velocities. Main generation/script reload and new authority controls must retain HOLD. |

### Transaction ordering required from native owner

1. Explicit native full inventory/version/lifetime verification; genuine paused lease; all participant owners admitted. Refuse missing/protected/changed owners.
2. Prepare ALL source and downstream checkpoints before mutation. Checked source static-batch restore with failure retention before Registry baselines/bounds; source owner owns any later re-batching.
3. Stage root + sibling deltas/delete and owner-specific data together. Keep collider shape/material resources original. Registry must not invent source ownership or special transform callbacks.
4. Validate native source geometry/current CPU descriptors, all support/occupancy/door and pending nav jobs. No success while required asynchronous publication is pending. Failed precommit restores ALL old objects, filters, source data and admitted owner state; don't silently rewind newer controls/authority.
5. Commit joint editor object+ground model only after scene/owner validation. Postcommit cleanup failure remains committed and paused with retry, never rolls back just one scene half.
6. Verify all owners ready and version-consistent before resume. Full-map completion additionally needs actual outside-crop native population under real source owner; absent objects cannot be invented through registry permission callbacks.

No native source owner currently supplies this complete contract. This package is a concrete inventory/proof handoff, **not** permission to enable all native houses in editor or an FPS/GPU acceptance.

## Pinned source/test hashes

- Actual main: `0916381441df9a9d111006aed2b34e4e1c2ec195ee24609757a552b388017571`
- Actual Printshop: `300b48c8efa0d0b953514b36e0c0319febfd6d9a2ff61450601a45e1109e37f4`
- Actual static batch: `53618a287f52310ef4acea9ec4e2fbad0e5a79d4d29d2ad125a453f32c74ebf3`
- Actual nav host: `0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4`
- Inventory helper: `d198f419636ca493f5c7b6726421b5790478a3ab3347a0f49b7d546362ddc527`
- Final test: `b56aae735ca44161833d3520bb1ff7355b0b877059db4af18cba455676554434`
