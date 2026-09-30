# Narrow anatomical head merge atop candidate07

Status: **800 native checks PASS / 39 cases / engine exit0 in51.57s**. No production or candidate07 edit. No GPU, Git or user game operation.

Apply only the three files in `files/scripts/npc_visual`, guarded by RECEIPT.json before hashes. Base owner must be exactly fa1c551a8501f1f731126d374c25ab07ac209137862febd5ee40ec0b7102049e. Merge patch is reviewable but never blanket-copy Artist's older owner.

- Owner0a3e311d adds exact head admission and an atomic selected-pellet tuple. Source HP direction stays unchanged; physical/marks direction uses the selected native pellet. Existing blood/marks, no-slide, lifecycle guards, medical75Ns cap, pointshare10%/2.5Ns and total impulse budget are preserved.
- Classifierf83544fd retains original anatomical triangles/obstruction checks and returns the winning skin triangle normal. Rigid head normals use inverse-transpose bone basis; dynamically blended triangles use the current world triangle. Unit normals face the incoming ray.
- Lifecycle80f7a0cb adds only explicit admitted head final-death policy; invulnerable and nonhead source medical handling precede/remain unchanged.

Tests resolve `res://scripts/npc_visual/npc_local_preview_hit_owner.gd` and its merged lifecycle/classifier. STAGE_INPUTS pins all resources before execution; post-run hash drift is empty. RUN01 records engine command and timing; RESULT01 preserves scenario rows. Historical head04 had only four candidate hashes and is not the execution closure for this result.

The39 scenarios cover three original rigs, four head directions, shotgun, adversarial body-first/head-later native pellets, torso damage, medical survival, independent exact forearm occlusion, near miss, invulnerability, world wall and duplicate receipts. Camera direction differs from muzzle by0.7rad. Assertions bind selected head point, normal, direction and projectile index and check unchanged physical joint bound. The mixed scenario changes test-only pellet angles to force a real native body contact before a head contact; it does not claim those angles are normal source spread.

Reproduce on a fresh isolated copy of exact candidate07 with the three overlays: run the command in RUN01, changing only its --path to that copy. Original run_once.py is one-use and refuses an existing stage. Do not point it at production. Scripts/tests/log/receipt are compact; stage is a disposable dependency snapshot, not proposed Git content.

Limits: fixture disables vehicle collisions, normal population and automatic player/effect processing; it drives the real native producer and original hosts explicitly. Already-medical ACTIVE head finish, actual player input/export, native visual wound placement and full-scene CPU/GPU/memory are separate. First-hit path timings include the merged marks/blood work and are not comparable to Artist's old head-only timing. Existing floor minima are not floor-clear acceptance. No further engine run was made.
