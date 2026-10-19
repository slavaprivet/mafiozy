# Mixed combat smoke and G routing handoff

Source pinned for these component checks: `60001a6dedf1880eb0bbd2e2237d24362dd4ac8e`; frozen stage `D:/MafioziCastle31/main60001_candidate31`. Later map commits were not part of this check. All native invocations used `tools/godot/test_scheduler.py`. No 120–180 s soak was run. No FPS acceptance is claimed.

## Two 36 s mixed smoke attempts

- `D:/MafioziCastle31/main60001_candidate31_soak_smoke01/MIXED_COMBAT_SOAK31.json` and `SCHEDULER_RUN.json`: fixture FAIL, not a claim that combat failed. Ordinary sword and bow acquisition worked, one real bow shot occurred, NPC attacked eight times and hit eight times, sword wounds/bleeding occurred. Spear throw 0 because G did not free bow carrying capacity. Player died near 35 s.
- `D:/MafioziCastle31/main60001_candidate31_soak_smoke02/MIXED_COMBAT_SOAK31.json` and `SCHEDULER_RUN.json`: same fixture FAIL, one shot, ten NPC attacks/hits, real forearm/head part HP loss and bleeding, spear throw 0. Before and after G: RMB false, storage usable, revision 2 and carried `{sword,bow}` unchanged. Player death still limits late coverage.

## Isolated G regression

Exact baseline native receipt `D:/MafioziCastle31/bow_storage_g_baseline31/BOW_STORAGE_G31.json` (scheduler exit 1 because expected regression): ordinary Q sword/Q bow, G sets the prototype bow `_grounded=true` and logs `DSH_BOW_PROTO_DROPPED`, while storage revision stays 2, `carried` retains bow, `fallen` stays empty, no rigid floor bow exists, and ordinary KEY5 cannot claim spear. This is a real input/ownership inconsistency, not a same-tick RMB condition.

Patch `BOW_STORAGE_G31.patch` changes only `bow_prototype.gd::_input` KEY_G. When castle storage carries bow, G calls its `drop_held(false)` transaction; its existing routine removes the equipped bow, updates capacity/revision and creates the rigid dropped model. The legacy prototype drop remains for a bow outside castle storage. Base Git blob `cffeed8ea4268cda73477c4046494cc7b56bf492` from commit 60001; candidate blob `8f02d0692c7d62e5ce5e2f5ce5e35690fd655e8f`. Patch applies cleanly to current shared file by `git apply --check`; shared was not edited.

Candidate stage `D:/MafioziCastle31/bow_storage_routing31`, scheduler import PASS `D:/MafioziCastle31/bow_storage_routing31_import/SCHEDULER_RUN.json`. Same ordinary graphical fixture PASS `D:/MafioziCastle31/bow_storage_g_candidate31/BOW_STORAGE_G31.json` and scheduler receipt: revision 2→3, carried bow removed, fallen bow present as `RigidBody3D` with collision, then KEY5 claims/selects spear, revision 4. No combat actions were injected by this short probe.

`sword_prototype.gd::_input` has an analogous early KEY_G handler that directly calls `drop_sword_to_ground()`/`drop_shield_to_ground31()` before storage shortcut in `preview_weapons.gd`. That is a source-level risk of the same stale inventory for sword/shield; this patch intentionally does not alter sword. It needs its own ordinary input proof and scoped owner decision.