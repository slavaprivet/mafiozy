# Peaceful activity elapsed time — Artist19

2026-09-20. Root-approved bounded patch; READY for the root's shared LIVE check.

## Problem and result

The source frame caps physics `dt` at 0.1 seconds. Ordinary calm foot movement already uses compensated elapsed time, but native building entry/exit, jogging and approaching a conversation did not. Their real-time deadlines continued normally while movement slowed below 10 FPS.

Actual source function tests over 20 seconds, with near and distant actors:

| Movement | Before 5 / 8 / 15 FPS | After 5 / 8 / 15 FPS |
|---|---|---|
| Native entry/exit and social approach | 0.90 / 1.44 / 1.80 m/s | 1.80 / 1.80 / 1.80 m/s |
| Jogging | 1.30 / 2.08 / 2.60 m/s | 2.60 / 2.60 / 2.60 m/s |

These are controlled source checks, not an explanation of every stationary NPC. Ordinary walking already retains correct wall-time speed. Archetype speed, path wait and physical obstruction remain separate concerns.

## Scoped changes

- `assets/maps/city_rebuild_v1/npc_civilian_elapsed_source.js`: independent activity elapsed debt, restricted to peaceful ordinary residents in native visit entering/exiting (excluding recovery), active jogging or conversation approach. Captures the exact activity object and phase. Debt shares the existing accepted-frame epoch and pause/reset guards.
- `world.html`: accumulate before spatial cadence; consume after admission; call existing visit/activity functions through `_npcRunActivityElapsed`. No boss, transport, authority, coordinate-selection or navigation-planner edits.
- Existing activity/visit functions are unchanged. Each compensated update invokes them in at most five steps of at most 0.1 seconds. Every existing terrain/body/sweep check remains active. A blocked step, phase change, action replacement or new threat discards remaining movement time.
- Combat/medical/vehicle/special-role actors and stationary leisure retain existing clocks. No deferred movement is replayed after a hidden tab, pause, hit-stop, resume or rejected long frame.

## Verification

- `node test_npc_activity_elapsed19.mjs`: PASS; actual source functions and source frame hook, 5/8/15 FPS near/far, exact thin-obstacle interruption, threat between substeps, identity/phase change, pause/reset/long-gap guards. Tests use deterministic collision boundaries, not a GPU scene.
- `node test_npc_civilian_elapsed.mjs`: PASS, previous ordinary walking/reset behavior retained.
- `node test_npc_civilian_activities.mjs`: PASS.
- `node test_npc_outdoor_activities.mjs`: PASS.
- `node test_resident_native_visit.mjs`: PASS.
- `node test_npc_activity_ownership19.mjs`: PASS.
- `python check_world.py`: PASS, seven scripts.

CPU-only equal-distance comparison for 1,000 updates: two legacy 0.1-second calls 10.46 ms total, one compensated 0.2-second wrapper call 11.53 ms total in the observed run. More collision work per low-FPS frame is intentional to restore distance safely; bounded five-step limit prevents an unbounded catch-up. This microbenchmark is not full-scene acceptance. **Performance of the shared loaded game remains for root LIVE measurement.** No browser, reload or push performed by this agent.

## Unchanged findings

`_npcLifeTick` scans 18 residents per accepted >=250-ms tick. For 288 NPCs its rotation is about 6.4 seconds at 5 FPS versus 4 seconds at 8 FPS; bench-release housekeeping can lag by that amount. This patch does not alter that scheduler and does not claim to fix multi-minute route waits.
