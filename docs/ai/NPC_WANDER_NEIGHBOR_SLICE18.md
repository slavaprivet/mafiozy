# Wander neighbor slicing — applied by root, 20 September 2026

No production files were changed by this subtask. `npc_wander_neighbor_slice_candidate18.mjs` transforms only the extracted `pickNpcWaypoint` function. The staged function is `outputs/pickNpcWaypoint_neighbor_slice_staged18.js`.

Root has now applied the scoped transform to production. The test detects applied mode, reconstructs the previous whole-node baseline only in memory, and asserts that exactly one transform reproduces current production source. No double transformation. Root also confirmed the original queue-clock regression test now passes without loosening its assertion.

Problem reproduced by existing `test_npc_queue_clock_audit18.mjs`: the deadline was checked before a whole four-neighbor node. The actual five-point swept footprint can therefore continue well past the 4 ms slice. With deterministic 0.02 ms point cost, the first wander slice costs 5.74 ms; with its separate 6 ms preparation the unchanged `< 10.3 ms` assertion fails.

Candidate checks the deadline before each neighbor. Search state retains `expandingNodeKey` and `nextDirection`; the current node is added to candidates only once. If a neighbor yields, `qi` stays on that node. Completed neighbors are not replayed, and insertion order, visited parents, DFS frontier, swept footprints and long-walk thresholds remain unchanged.

`node test_npc_wander_neighbor_slice18.mjs` passes:
- First slice 5.74 → 4.10 ms, total preparation + slice 11.74 → 10.10 ms. The old `< 10.3 ms` bound is preserved, not relaxed.
- Open and blocked-strip scenarios produce exactly the same full route as the existing unlimited-cost DFS reference, with no repeated path nodes or duplicate candidates.
- Artificial deadline after each neighbor forces 16 same-node resumptions per scenario. Routes and all parent/direction outcomes remain identical; at most 0.82 ms is charged in each such forced slice.
- Normal time slicing peaks at 4.10 / 4.30 ms for the two deterministic cases and allows at most one complete edge of overrun (41 point probes at 0.02 ms = 0.82 ms), instead of a whole four-neighbor expansion.

Limit: this is source-level deterministic CPU verification, not real-scene FPS or a new whole-city movement benchmark. `npc_native_directed_route_source.js`, vehicle/player bridge, and production cache are untouched.
