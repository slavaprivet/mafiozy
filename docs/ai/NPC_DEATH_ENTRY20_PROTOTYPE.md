# Vehicle / prone death entry20 — isolated proposal, NOT integrated

**Historical proposal, superseded for vehicle only by `NPC_VEHICLE_DEATH_ENTRY20_HANDOFF.md`. Vehicle is now integrated; prone is still unresolved. The test with the historical prototype name is now the vehicle production regression.**

2026-09-20. Actor remains released. Only new `test_npc_death_entry_prototype20.mjs` changes actor source in memory. Production source health, lifecycle, vehicle and death profiles are untouched.

## Vehicle result

Actual male/female compact sedan at board0.55, seated1 and exit0.4: largest first-frame hand/head/foot discontinuity0.4974326m → less than0.000000067m. Raw death age remains0 and state dead immediately. Root/yaw/weapon identity unchanged. No fake continuation of a dead transport trip.

Latest rerun after concurrent shared vehicle changes also passes: board baseline0.5944/0.5978m, exit0.8000/0.8119m, seated0.4705/0.4974m; candidate remains below0.000000065m. The earlier numbers describe the earlier shared vehicle revision, not a fixed baseline.

Over the next30 samples at60Hz, largest step is0.07536m male /0.07960m female, identical to the existing canonical fall's largest step. Actual skinned minimum ground clearance stays above numerical -6e-15m; new meshes are not created.

Capture must store decomposed local bone P/Q/S, visualPivot position/quaternion and scaled.position. Bone quaternions alone fail for prone because authored posture also changes bone translations. Bone.matrixAutoUpdate is false, so direct bone.quaternion capture is incorrect.

## Exact proposed integration anchors

Review the test's ten checked `once()` substitutions and `createEntry20` helper. The proposed actor owns one helper:

1. Capture the final displayed pose only when applyNpcVehicleBinding actually ran. Reuse the allocated pose buffer and bone-entry list. Clear eligibility on every other displayed frame.
2. On an accepted transition into dead, freeze the eligible pose only if its timestamp is within0.25s of event presentation time. Duplicate receipts do not reset it. Source sync uses external atTime.
3. Wrap only death presentation: blend local matrices and visual pivot to the existing death renderer over raw age0–0.28s. State/clocks remain authoritative.
4. During blend, render target using a cached context with deferred groundPose. Ground the final blend once, plus fading original positive ground clearance. This avoids a second full skinned-ground scan and its measured2x CPU regression. Initial exact pose is untouched. One extra ground scan occurs only when the event captures initial clearance.
5. Optional entry-pose metadata saves the frozen pose and clearance. Validate before surface mutation; reset on respawn/new epoch. Old saves without metadata retain exact previous behavior.

Vehicle-only integration must omit the prototype's prone eligibility branch. Full helper validation should additionally enforce authored scale bounds before production approval; current prototype verifies shape, finite components and unit quaternions.

## Additional checks

Both actual GLBs pass external source sync/save before first death update, JSON restore/recreate, long cull skip, observation gaps1/5s, standing death unchanged, nonfatal stun/knockdown unchanged, respawn/new epoch clearing and atomic invalid quaternion rejection. All six fatal causes preserve the first vehicle pose. No current source trip is required after death.

CPU, same fixed pose raw age0.13,15 warmups+30 samples per variant: male before p50/p951.305/1.515ms, candidate1.475/1.514ms; female1.186/1.226ms →1.214/1.290ms. This is isolated actor cost, not LIVE scene FPS. Last cleanup reuses the bone-entry list; no corresponding rerun numbers claimed.

Final cleanup rerun: male1.445/1.565ms →1.548/1.769ms, female1.320/1.335ms →1.370/2.537ms. Samples are small and the shared workspace is active; that p95 variance is not an FPS acceptance. Event-time clearance capture adds one skinned-ground scan once per eligible death; per-frame rendering retains one such scan.

## Prone result is NOT READY

The separate prone/crawl fixture preserves the first frame (1.26–1.33m jump removed), raw age0, and serialization. However blending to an upright-origin canonical death still raises/rolls the prone body during the next0.28s, with up to0.1703m step at60Hz. Correct initial continuity alone is not acceptable. A prone-specific settled final pose that preserves belly-down orientation is required; do not integrate the current prone branch or use fake raw age to hide it.

No browser/GPU work was run. LIVE, vehicle/body collision acceptance and whole-scene FPS remain pending with Artist19.
