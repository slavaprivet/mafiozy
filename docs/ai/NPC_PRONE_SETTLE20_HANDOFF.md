# NPC prone death settle20 — production READY

2026-09-20. Coordinator20 approved the combined helper/actor scope. Actor and helper are released. Only `npc_death_entry20.mjs` and the actor's final capture-origin selection changed. Root/source clocks, health, IDs, weapon ownership, death profile and blast replacement APIs are unchanged.

## Behavior

An actual full medical prone pose now enters death belly-down without standing or flipping. The current crawl phase freezes immediately, with small head/neck/arm relaxation over0.45s, then remains as that death epoch's corpse pose. Raw age remains0 at the fatal event; no fake source age or moving state. Partial prone is deliberately not inferred.

Combined entry metadata explicitly records `origin:'vehicle'|'prone'`. Missing origin is legacy vehicle. Vehicle keeps the previous0.28s blend/expiry. Prone persists until respawn/new epoch. Stale observation gaps1/5s cannot revive old poses. Existing source key/profile validation still controls fatal causes and visual replacement by blast fragments.

Validation remains strict and atomic. Vehicle bone positions match actual rest within1e-5. Prone changes only pelvis to authored x=rest.x,y=.86-rest.z,z=rest.y-1.46; all other bone positions stay rest. Both origins require positive scales matching actual rest, finite normalized quaternions and bounded pivot/scaled offsets. Relabeling either origin's payload as the other fails rather than changing the pose meaning.

## Verification

- `test_npc_prone_settle_prototype20.mjs` is now a production regression (historical filename). Its baseline disables only prone capture in memory while retaining every other handler, vehicle behavior and helper validation.28 actual male/female cases (stationary/crawl ×6causes+unknown): former1.64–1.75m initial jump →<5.6e-8m; pivot change0rad; max60Hzstep1.255mm; head rise<1cm; actual skinned floor error<2e-10m. JSON recreation and5s cull retain the terminal pose.
- Original medical source audit `test_npc_prone_death_entry_audit20.mjs`:4/4 PASS, now marked integrated regression. State dead immediately; raw age0.
- Original vehicle fixture `--require-fixed`:6/6 PASS, worst6.43e-8m. Extended vehicle regression PASS; baseline now disables only vehicle capture while preserving prone.
- New `test_npc_death_entry_origins20.mjs`:62 checks PASS, covering cross-origin relabeling, invalid/absent origin, authored position/scale corruption with atomic rollback, legacy vehicle payloads, origin reuse across epochs, partial prone fallback, blast `visualReplaced` save/recreate/5s cull/reset for both origins.
- External sync/save before first pose, stale1/5s gaps, fatal receipts over custody/phone, ordinary standing death/nonfatal stun/knockdown unchanged, respawn/new epoch clearing: PASS.
- Clock persistence, surface serialization, current lifecycle, death integration26, recovery audit8/8: PASS.
- Actual ground memo integration6 cases:89hits/1miss each and exact pose comparison PASS. Prone settled rendering also checks memo reuse directly.

## Cost and acceptance limit

Pose buffer and bone entries are reused; no new meshes. Cause strengths are allocated once per helper. Settled prone uses the existing ground memo. Last prototype steady-pose run male p50/p950.726/0.840→0.727/0.821ms; female0.690/0.883→0.653/0.685ms. Integrated female steady-pose run0.667/0.728→0.622/0.686ms. These are CPU actor fixtures, not total-scene FPS.

No GPU/browser run was performed. Small relaxation angles were approved for LIVE review, not accepted as final art. Visual review, common-scene performance and corpse/world contacts remain with Artist19. Partial/transitioning prone and the separately documented mixed expired-stun/fresh-death case are outside this patch.
