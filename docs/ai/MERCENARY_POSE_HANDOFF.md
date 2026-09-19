# Mercenary work pose — 12 September 2026

Owner scope: new `mercenary_pose.mjs` and `test_mercenary_pose.mjs` only. No changes to Artist16 actor/walker files.

Create lazily for hired NPCs: `createMercenaryPose({THREE,walker})`. After each normal walker update, call `pose.apply(life.mercenaryAction, timeSeconds)`; suppress the action when dead, stunned, swimming, seated, or in a vehicle transition. Call `apply(null,time)` when blocked to hide tools. Hit/death animation has final priority. Dispose alongside actor.

Source action kinds: `revive`, `intimidate`, `unlock_safe`, `unlock_door`, `cut_fence`, `plant_bomb`. Short aliases heal/unlock/cut/plant accepted. Only `working`/`acting` applies work posture. Other phases preserve host gait. Source owns AI movement, target alignment, authority, effect commit, bomb placement/countdown and return movement.

Five procedural presentations: medic asymmetric crouch with compressions/bandaging; bruiser broad stance and raised fist; lock specialist crouch with rotating pick; engineer animated cutting jaws and squeezing arms; demolition specialist kneeling attachment motion holding charge. A single reused box geometry and three opaque PBR materials build tiny hand props. No texture assets, character resets, source root writes or per-frame skinned-vertex scans. Ground reference uses two ankle transforms on actor hierarchy only.

Validation: `node assets/maps/city_rebuild_v1/test_mercenary_pose.mjs` PASS with actual male and female GLBs. Distinct profession bone matrices, animated work phases, root unchanged, no accumulation across normal host updates, phase pass-through, 600-frame stable node/resource count and idempotent disposal. One geometry/three materials/four hand props per hired actor; lazy creation recommended.

Isolated Node CPU timing, 100 warmup + 500 samples, cutter work pose only excluding host walker update: male p50 0.023 ms / p95 0.030 ms; female p50 0.020 ms / p95 0.021 ms. Baseline without this presentation has no additional pose call. These figures are not a loaded-scene before/after FPS result.

Limits: performance of the complete scene and visual acceptance are not checked here (GPU belongs to coordinator/Artist16). Ankle reference is approximate floor grounding, not final full-body contact IK; target height/contact alignment and bandaging contact require live review. This module alone does not implement healing, lock opening, cutting, intimidation outcome, or bomb explosion.
