# Two canonical police models — ready, no scene activation

Latest user instruction defers police dispatch/behaviour. This package supplies **only two distinct presentation models** for future patrol. No main scene, roster, transport, police report port or AI is connected. Shared game untouched.

Delivery allowlist: `scripts/police/npc_police_model30.gd` only. Strict idempotent `apply_police_models30.py` installs that one new module; it does not spawn anything. `create_model30(0|1)` explicitly returns an unattached Node3D model, motion, canonical appearance and receipt. The future owner decides when/how to insert it. Invalid variant rejected. `dress30` is idempotent.

A uses verified existing male visual72 (warm skin, 1.876m source height); B uses male visual252 (light skin, 1.711m, fuller build). These are **new service model identities** `police_service_model_a30` and `police_service_model_b30`. Source bridge ids/descriptors are preserved only as asset provenance; neither model is a resident/boss/health owner. No source citizen record is changed.

Uniform: navy coat, peaked cap, black visor, gold cap/chest badges and name strip, shoulder-board geometry, belt/buckle/pouch. Original face/brows/skin, proportions, rig and locomotion remain. Covered extra hair pieces are hidden; original canonical HAIR (including shoes) retained. Each model recolours the same proved 1648 coat vertices via packed native COLOR bytes; all other buffers are equal to canonical originals. 28 bones and their names/parents/rest/initial pose unchanged. No colliders, Node processing, physics processing or automatic animation is introduced.

Cost per model: 3 added batched meshes + 3 BoneAttachments = 6 presentation nodes, 893 vertices, 612 triangles. Including two model/motion wrappers, A has29 nodes/14 stored meshes/8403vertices/11820triangles; B30nodes/15stored meshes/8518vertices/11988triangles. After covered hair is hidden, both have9 visible meshes/7693vertices/10716triangles. Both models combined:59nodes/18visible meshes/15386visible vertices/21432visible triangles. No texture/GLB duplication on disk. One script only. This geometry accounting is not an FPS claim.

Proof: `runs/models02/RESULT.json` import/native PASS, stderr0, source drift0. `observed/POLICE_MODELS30.json`:349 assertions including source buffer equality, 28bone invariants, idempotence, separate service ids, no behaviour/collision, existing gait binding/finite transforms, free cleanup, measured rest boot ground≈0.000002m. All five renders reviewed (`VISUAL_REVIEW30.json`). Model01 was native PASS but visual cap defects; preserved and fixed in02.

Screens: `runs/models02/observed/police_front.png`, `police_side_a.png`, `police_side_b.png`, `police_cap.png`, `police_gait.png`.

QA uses the existing own reusable ambient30/oracle01 project through scheduler write/read leases, no full clone. Runner `run_police_models30.py` stages only the delivery module and QA; source pins and tested source snapshots retained. Preview spawns exactly2 standalone presentation models and frees both. It does not instantiate the city scene.

## Deferred work, excluded
`INITIAL_AUDIT30.md` is historical read-only transport/police audit. `scripts/police/npc_police_road_plan30.gd` is UNTESTED route-planner WIP, never staged/native-validated and **excluded from apply/runtime manifest allowlist**. No police dispatch or submit_report owner exists in this package. Do not connect a fake accepted/arrival port. Future physical patrol, road drive, stops, doors, crew exit, response AI and combat require a separate user-authorized stage.
