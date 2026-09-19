# NPC route admission clock — short patch, September 19

## Verified defect and scoped fix

`pickNpcWaypoint` records `now` before civilian goal selection; police also passes a caller update timestamp. `_npcReserveRouteWork` previously used that supplied timestamp to create the first `now + 4` deadline. If preceding work lasted at least 4 ms, the first newly admitted slice was already expired. It counted as an admission and moved the owner to the back of the queue without expanding a node.

The sole production change is refreshing `now = performance.now()` inside `_npcReserveRouteWork` after the native-mode guard. Existing 2 jobs / 4 ms window, FIFO, cancellation, frame identity and collisions are unchanged. Legacy mode returns as before. This also prevents a stale timestamp from admitting a second job after the actual shared deadline.

Actual-source VM reproduction: goal preparation consumes 6 ms; old first wander slice expands 0 nodes, current expands 74. Admission timestamp now records 1006 rather than 1000; total work is 6 ms existing preparation plus 4.04 ms search including its existing atomic-edge overrun. No new population scans or allocations.

## Remaining measured bottleneck — not fixed by this small patch

The shared deadline is an absolute wall-clock window, not accumulated pathfinding CPU. A first job using 0.25 ms followed by 5 ms of unrelated work prevents the second admission. Confirmed against actual queue code. Changing this needs explicit begin/end accounting across every route caller; it was intentionally not included here.

The queue also has a fundamental throughput limit at low source-frame frequency. With 233 simultaneous 20-cell native A* requests, open synthetic land and deterministic 0.02 ms predicate cost, actual current source requires 2316 frames to finish all paths. Completion p95 is 38.5 s at 60 frames/s, 115.5 s at 20, 462 s at 5. The same total 490698 predicate checks are made in each case. These are controlled scheduler/planner results, NOT measured game FPS or actual-map timings. Progress is retained; this scenario demonstrates genuine queue contention, not lost frontiers.

## Checks and limitations

- `test_npc_queue_clock_audit18.mjs`: stale-clock reproduction/current fix, wall-gap behavior, equal completed endpoints and frame throughput.
- `test_npc_route_fairness.mjs`: mixed police/resident FIFO and existing quota.
- `test_npc_route_wait_lifecycle.mjs`: pending/cancel lifecycle.
- `test_npc_wander_first_slice_starvation.mjs`: distant initial wander marker remains effective.

All PASS. No GPU tab, reload or LIVE acceptance performed. Performance of the complete scene is unverified. This patch does not claim to solve all long waits or make the city ready.
