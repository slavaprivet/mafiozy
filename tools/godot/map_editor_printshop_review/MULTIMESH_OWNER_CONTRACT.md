# Actual printshop MultiMesh: read-only owner contract audit

Source descriptor SHA256 `958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b`. Canonical source `REBUILD-VISUAL-print_shop-001`; original GLB `ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97`.

`audit_multimesh.mjs` reads source only and prints exact descriptor/geometry/matrix/color hashes, never approval. There are **15 batches / 280 instances**, of which 215 have source linear instance colors. Keep all batches: replacing them with 280 nodes is not the desired optimization.

| Descriptor index | Source name | Instances | Material index | Parent/motion |
|---|---|---:|---|---|
|24|unnamed|12|21|adapter/static|
|25|unnamed|24|21|adapter/static|
|26|RoofAccessSigns|16 colored|22|adapter/static|
|27|Storey_Walls_And_Ceilings|11|16 brick finish shader|adapter/static; floor collision|
|28|Room_Door_Frames|9|23|adapter/static|
|31|Interior_Furnishings_box0|160 colored|26|adapter/static|
|32|Interior_Furnishings_cylinder0|12 colored|26|adapter/static|
|33|Interior_Furnishings_box1|4 colored|27|adapter/static|
|34|Interior_Furnishings_cylinder1|2 colored|27|adapter/static|
|35|InteriorDoorWood|5|28|adapter/static snapshot|
|36|InteriorDoorBrass|4|29|adapter/static snapshot|
|37|Interior_Furnishings_box0|5 colored|26|service door pivot|
|38|Interior_Furnishings_box1|4 colored|27|service door pivot|
|39|Interior_Furnishings_box0|10 colored|26|adapter/static|
|40|Interior_Furnishings_box1|2 colored|27|adapter/static|

## Actual writes and lifecycle

`preview_printshop_interior.gd:98–115` creates all batches, sets TRANSFORM_3D, source color flag, shared source ArrayMesh, count, and each matrix/color. No subsequent instance setter appears in that native class. `advance():173–185` changes public/service pivot transforms, not instance arrays; batches 37/38 follow the service pivot. `restore_original():192–208` frees generated children, clears resources and returns overridden original meshes. Reattach constructs another generation. Main `:642–650` creates/attaches this owner; `:497–500` advances doors. Those are actual current paths, not proof no other code can obtain resources.

The original JS `interior_mesh_pool.mjs:81–82` writes matrices/colors during flush and disposes meshes/resources later. `building_storeys.mjs:166` writes storey matrices during construction; its disposal releases shared source resources. **Original `interior_room_doors.mjs:17–30` rewrites instanced InteriorDoorWood/Brass matrices on door animation and updates bounds.** Native records 35/36 are static exported snapshots today: source owner integration must either explicitly keep those source doors frozen under the editor lease or rebuild/update from the real source door owner. This audit does not claim those interior door mechanics have migrated.

Other native MultiMesh writers found in main surface batches, static batch factory and vehicle tyre tracks are separate owners, not printshop write paths. Resource references are nevertheless publicly obtainable through nodes/caches; GDScript privacy is conventional. Direct `multimesh.buffer`, instance setters, RenderingServer RID writes, mesh surface mutation, material parameter mutation, resource replacement, child insertion/reparenting, script reload and teardown can bypass a merely immutable descriptor.

## Trustworthy observations versus unsupported conclusions

Native object identities/lifetimes, node topology, configured property flags/counts, CPU ArrayMesh surface inputs, material/shader references and exact known shader parameter values are available for guards. Watch nested mesh/material/Shader resources separately. `changed` is helpful poisoning but does not cover all writes.

Godot 4.7.2 headless dummy rendering does not retain readable MultiMesh instance storage (also explicitly documented by the existing tyre-track test at lines 83–85). Matrix/color/buffer getters may return defaults: they cannot certify submitted instances. In a real renderer getter availability still does not prove no external mutation between checks, and renderer precision/colors need renderer-specific parity acceptance. No GPU readback or visual parity was performed here.

## Minimal future actual-owner admission

1. A **fresh actual owner generation** constructs each native MultiMesh from the admitted exact descriptor. The same constructor path records immutable CPU matrices/colors and source mesh/material recipes before submitting them; a descriptor copied afterward is not a submission witness. Bind receipt to owner instance, generation, exact node/resource IDs, descriptor index (names repeat), source hashes and source-to-native conversion version.
2. All instance/buffer/count/visibility/custom-AABB writes must route through that owner. Seal external write access by a trusted project ownership convention and code audit; do not claim the language makes exposed Resources immutable. Any unknown external writer, RenderingServer RID use, reload or replaced object invalidates the generation. The current native class lacks this shadow/writer receipt, so it remains HOLD.
3. While a paused editor lease is held, freeze instance data, doorway phase and teardown/reload. Placement moves only the admitted common root plus sibling interior frame: unchanged instance shadows require no 280-instance rewrite or GPU readback. Keep 15 batches and exact linear colors/material/mesh sharing. Guard nested resources, shader numeric uniforms and complete topology; guard checks can be proportional to batches, not instances, only under the genuine sealed writer contract.
4. Any legitimate instance mutation increments an owner epoch, invalidates editor admission and ends editability until a fresh exact source rebuild/admission. For future animated interior doors, route mutations through a dedicated actual door owner and capture an immutable editor-pause phase snapshot; never silently accept static export as current animated storage.
5. Build candidate resources off-scene from source and new CPU shadows; preflight owner/collider/nav/door callbacks before an atomic swap. Preserve old generation/resources and receipt until all participants commit; refusal restores old identities exactly. Failed/unknown rollback retains the lease. Dispose old resources only after successful finalization. Source rebuild is a lifecycle operation, not a flag resetting poison.
6. CPU tests compare shadow matrices/colors against all 280 source inputs, preserve 15 resource batches, shared mesh/material identity and source frame, and reject mutation/reload/epoch change before document mutation. Separately obtain coordinated live renderer/visual parity; CPU shadow acceptance cannot replace that GPU gate or actual gameplay/nav/authority callbacks.

This document proposes a contract only. No true owner admission, production wiring, source storage parity or ability to move all special buildings is asserted.
