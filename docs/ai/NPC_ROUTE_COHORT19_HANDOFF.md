# NPC route admission cohort — Artist19, 20 September 2026

Root LIVE inspection found 181 queued searches, roughly 1.69 admissions per frame despite the eight-admission allowance, and only 1.7 ms used in a sampled frame. Many residents had not been admitted for 19–34 seconds. This is observation from the root task, not this helper's own browser run.

## Cause and applied scope

`world.html`, `_npcReserveRouteWork` and `_cancelNpcDirectedSearch` only. Previously only the exact FIFO head could start. When queue order differs from update order (ordinary NPCs, activities, police), actors preceding the head have already been rejected by the time it runs; the remaining CPU allowance can then go unused.

The oldest eight requests now form a cohort and can run in actual update order. The cohort persists across frames until its members are admitted, abandoned, cancelled or die. Persistence matters: rebuilding an eight-wide window each frame lets early, expensive actors repeatedly overtake older actors and starve them. An existing mixed police/civilian regression caught that rejected intermediate approach.

Preserved: 4 ms actual search CPU allowance, maximum eight admissions per frame, one admission per owner per frame, pending frontiers, abandonment expiry, legacy non-native behavior and all collision rules. There are no transport, scene-rendering, population, activity-selection or collision edits in this patch.

## Verification

- New `test_npc_route_batch19.mjs` uses the actual production scheduler with deterministic job costs. With 180 owners in reverse queue/update order for 120 frames: strict-head baseline 120 admissions, 0.20 ms/frame, some owners unserved; cohort 960 admissions, 1.60 ms/frame, every owner 5–6 grants, maximum wait 23 frames. Permuted update order yields the same distribution.
- Mixed 0.25/1 ms costs over 600 frames: every owner 19–20 grants, maximum wait 35 frames, mean search CPU 2.93 ms/frame. Maximum 4.75 ms includes one indivisible job crossing the 4 ms threshold; no new atomic-overrun behavior was introduced.
- PASS: `test_npc_route_cpu_budget18.mjs`, `test_npc_route_fairness.mjs`, `test_npc_route_work_budget.mjs`. CPU budget test's former strict head-order assertion now verifies allowed reverse order within the oldest cohort. No fairness assertion was weakened.
- PASS `python check_world.py`: seven inline scripts compile.

This proves the scheduler defect and regression behavior, not that city activity, animation or loaded-scene FPS is fixed. Root should reload the existing game and compare actual movement, request wait age and scene timings after warmup. No browser/GPU was opened by this helper.
