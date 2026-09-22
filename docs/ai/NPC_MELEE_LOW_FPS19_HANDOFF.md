# Hero → NPC physical contact, 20 September 2026

CPU READY; parent owns LIVE reload and full-scene frame-time validation. No browser, GPU, reload, push or Git operations by this author. Performance of the combined game scene is **not verified**.

## Reproduction

Actual male/female GLBs, stationary target 0.7 m ahead, four admitted attacks and actual source `beginWalkMelee` / `resolveWalkMelee` / confirmed damage receipt: at 5 FPS the previous endpoint-only host missed every punch, high kick, backfist and dropkick. Punch's complete 35–190 ms window fell between render frames. Other limbs crossed the target during the skipped interval, then left it. No synthetic damage admission was used.

## Scoped production changes

- `world_walk_melee_host.mjs`: sample the existing authored limb pose across the interval intersecting the accepted strike window, at ≤32 ms spacing, capped at 13 points. Sweep adjacent hand/foot samples; include both feet for dropkick. Interpolate root position/yaw between render samples. Preserve one resolution per sequence. Delivery grace is 250 ms; no arbitrary stalled-frame catch-up.
- `hero_walk.mjs`: contact-only sampler saves/restores bone matrices and root/pivot/scaled transforms, never advances gait/phase or the visible action result. It invokes existing Artist14 melee poses, not a second animation definition.
- `hero_contact_ground_bound.mjs`: sampler-only exact conservative floor fast path. Bone influence boxes enclose every contributing bind-space vertex. Affine Y projection bounds each contribution; nonnegative skin weights preserve the bound, with correction for weight-sum error and post-transform translation. A strictly nonnegative bound proves that dropkick's original `max(before, groundPose())` cannot raise the model. Unknown/negative inputs or inconclusive bounds retain original groundPose. Other animation ground correction is unchanged. Bounds are built lazily once for the attacking hero's geometry.
- `npc_melee_contact.mjs`: skin target vertices once per host sample batch; cache posed triangle bounds and defer contact-anchor capture until the actual winning surface. Optional body-origin LOS prevents a sampled limb already beyond a wall from hitting through it. Existing exact triangle/contact radii remain unchanged.
- `world.html::resolveWalkMelee`: bounded delivery grace plus explicit sampled `contactAge` validation inside the original attack window and no later than now. Sequence, dead/armed/action locks, target identity, range, server authority and ACK/replay contracts remain in force.

## Checks

`test_melee_lowfps_contact19.mjs`: 32 positives (both GLBs × four attacks × 5/8/15/60 FPS), actual source receipts; out-of-reach, prone, wall for all attacks, armed cancellation, long stall, block preventing dropkick knockdown; exact restored bones/root/phase/result; target skin work at most one vertex pass + winning anchor per batch. An elevated high kick hits a standing target and passes above the same crouched target. Ground-level high kick may legitimately contact the crouched head; crouching is not unconditional invulnerability.

`test_melee_ground_bound19.mjs`: 948 full-timeline poses, both models, both sides, uniform/nonuniform/mirrored scale; every vertex checked against the conservative bound. 824 fast-path /124 fallback poses; sampled foot positions match the normal full-ground authored pose with **maximum error 0**. Below-floor and invalid negative-weight inputs fall back.

`test_world_walk_melee.mjs`: grace boundary accepted at end+250, rejected at end+251; old/out-of-window/future/nonfinite/missing late contact time rejected; sequence consumed and replay rejected; remote HP/blood remains ACK-only.

Existing `test_npc_melee_contact.mjs`, `test_world_walk_melee_host.mjs`, `test_world_walk_melee_input.mjs`, `test_npc_contact_anchor.mjs` PASS.

## CPU cost and limits

`test_melee_cost19.mjs`, same target/GLBs/attacks, three repetitions per model; warm module/JIT, fresh hero per attack (includes first-use bound cache). Old endpoint-only path and new path share the optimized contact helper, so this isolates pose-sampling overhead, not an exact historical whole-file benchmark. Host-update p95 in ms:

| FPS | endpoint-only | sampled | hits old/new |
| --- | ---: | ---: | --- |
| 5 | 5.47 | 8.14 | 0/24 →24/24 |
| 8 | 5.45 | 6.41 | 24/24 →24/24 |
| 15 | 4.57 | 5.66 | 24/24 →24/24 |
| 60 | 4.13 | 4.77 | 24/24 →24/24 |

The first implementation's dropkick miss could cost ~60 ms due to repeated full-ground skinning; conservative rejection reduced it to ~7–10 ms in the same isolated probe. Broad negative regression suite p95 ~6.18 ms, single cold maximum ~20.6 ms. These are CPU probes, not full-scene FPS acceptance. Target skinning itself is still a several-ms pass; crowds, moving targets and source/render stalls require parent LIVE review. Target geometry is the currently displayed pose, not a historical rewind; hero pose/root alone is subsampled.

## Separate unresolved NPC → hero audit (not changed)

Ordinary NPC pending damage in `world.html::updateNpcs` still uses source-plane distance plus `_meleeLineClear`: punch 1.24, kick 1.48, heavy 1.68 source cells (~5.08/6.07/6.89 m at scale4.1). Actual extracted predicate admits the player 4.92 m away, behind the attacker, standing/crouched/prone. It does not consume the visible limb sweep, facing or posed player triangles. NPC impact timers are punch175/kick165/heavy330 ms and are not the same as hero authored contact peaks. This is a demonstrated separate defect; do not describe melee as completely solved. Boss attack admissions and server authority need their own scoped follow-up. No NPC death/phone animation or boss behavior changed here.
