# Artist14 game presentation v14 — 2026-09-08

Current coordinator: 01a08279-8066-7563-83fd-2d3fc4cbca41 (coordinator14).
Latest user explicitly authorized publishing our version over the bad prone integration and adding our work into game. This supersedes the former D-only handoff restriction for these scoped modules. No server restart, Git commit, push or unrelated whole-file replacement performed.

## Applied to shared /walk, served on localhost18538

- hero_walk: correct prone orbit around authored virtual hip1.46 (bone rest .20), removed arbitrary .58m floating lift; final real skinned grounding. Weapon origin uses accepted source-space mounts; both hands stay in reach, reload transform precedes IK. Unarmed prone now uses two forward palm support targets, legs extend relative to actual hips, downward/outward knee pole and prone ankle pitch. Old pose had push-up arms and folded legs. Bone lengths preserved.
- hero_arsenal: rebuilt details across all14 weapons, open bores, beveled receiver surfaces, distinctive magazines/handles/drums/scopes and Nagan chambers. IDs and all mount/muzzle/ejection/support metadata preserved.
- weapon_effects: narrow moving bullet streaks, layered impact recesses/chipped edges, bounded material-sensitive debris/sparks. Accepted casings and gameplay balance preserved.
- hero_artist14_melee/input: accepted single-hand opener,20% highkick, held1.2s backfist, guaranteed unarmed airborne click dropkick. Armed gate retained. Latest user found two-hand opener: hold charge visual is now suppressed during punch/kick, without changing the hold timer. Tested actual input press/step, not artificial charge0 only.
- hero_artist14_surface/pose plus artist14 modules: exact-point blood, eye bruises, persistent model-session bullet wounds/tears, hit/death/fall animations, depth wetness,5s walking droplets after water, chest-depth normal/fast swimming.
- walk_preview: scoped input/presentation bridge, collision-respecting directed dropkick, continuous shore bed, no manual movement during hit/fall/dead. Existing heroBlast and vehicle systems take priority; no competing swim/reaction transforms. Opt-in animationqa front camera/reload/ordinary-click inspection buttons.

## Important actual integration boundary

/walk is the existing isolated game inspection scene, not a completed replacement for server-backed world gameplay. No NPC/server damage system is present here. Reactions/wounds accept confirmed events only:

`document.dispatchEvent(new CustomEvent('artist14:hit',{detail:{confirmed:true,id:'unique receipt',target:'hero',kind:'bullet',point:{x,y,z},normal:{x,y,z},zone:'torso',clothing:true}}))`

Heavy/knockdown/blocked/fatal/dead flags are supported. Restore uses confirmed artist14:restore. No invented HP, range-only damage or fake server acceptance. A real authoritative hit producer/NPC binding and save persistence remain separate unfinished integration. Wounds currently persist for model lifetime until reset, not across reload/save. Melee presentation exposes active contact window/sides/kind; production contact damage must use actual swept contact, as accepted demo does. Do not claim hooks mean completed server migration.

## Evidence

Shared tests PASS: test_hero_walk; test_hero_presentation_glb (all14 grips crouch/prone/reload/jump); test_hero_arsenal; test_weapon_effects; test_hero_weapon_fire. Latest prone changes reran both actual GLB suites successfully.
OwnD melee input ten groups; melee poses1616 samples and80 full skins; one-hand held regression160 frames both sexes/sides, expected FAIL old module; surface real male/female transforms; all14 weapon anchor invariance and effect compatibility.
Independent shore-exit test runs actual water sampler and production surface motion at .015/.08/.20m strides; movement/death/dropkick/blast guard audit PASS.
Live18538: reproduced/prior screenshots inspected; updated M16 prone, unarmed one-hand punch, revised unarmed prone and TT prone visually inspected, pistol fire/ammo and reload control exercised. Not all14 weapons have individual final live screenshot coverage; CPU grip/fire checks cover all14. No claim of final artistic acceptance or live NPC/water combat coverage.

Recovery snapshot: D:/codex_release/artist14_GAME_v14_20260908/FILES.json. walk_preview snapshot is evidence/recovery ONLY: it includes other owners' concurrent work; NEVER wholesale copy it over newer shared source. Apply targeted artist patches. Original immutable checkpoints12/13 remain unchanged.

Final prone geometry audit PASS: both sexes,3yaw,720crawlframes; natural leg extension98.735%, limb lengths unchanged<1e-7; palm heights .067/.071m, actual skin min>=-7.2e-10. Regression old folded-leg target fails as expected. Evidence D:/codex_release/artist14_melee_port_20260908/PRONE_EXTENSION_VALIDATION.json.
