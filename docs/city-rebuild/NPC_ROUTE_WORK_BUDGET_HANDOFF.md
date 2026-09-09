# Native route search CPU budget — 2026-09-10

Root observed multi-second world frames after installing detailed native object/water queries. Source amplification was confirmed: directed routes visit up to 18,000 nodes, routine routes 520, escape routes 620; police routes visit up to 5,200 and check body corners plus sampled edges. A police edge can invoke approximately 45 native point queries. The old police one-search-per-16.667-ms limiter used current wall-clock buckets, so a long search itself advanced the bucket and admitted another officer within the same world frame.

Applied native-only shared search admission in `world.html`: `_npcReserveRouteWork` permits at most two searches within a four-millisecond window per stable `prevT` world-frame token. Directed, routine, escape and police BFS loops stop when that window expires; their existing best partial path behavior is retained. A new world frame permits work again. Normal source-only mode without a native navigation resolver keeps its former search behavior. Police's own one-search limit also uses the stable frame token.

`getWalkNpcNavigationDiagnostics().routeWork` exposes admitted, deferred and expired counts. This is not another point cache: root owns exact-point caching and native broad-phase optimization in its module. Wet owner owns initial placement and physical water-egress search, which are outside this route budget and were separately flagged as possible amplification sources.

Validation: `test_npc_route_work_budget.mjs` executes actual source search functions with a deterministic simulated 0.02-ms native query cost. Two hundred resident requests in one frame perform fewer than 220 queries and use about four simulated milliseconds; later wall time in the same frame cannot reopen the budget, and the next frame resumes progress. Legacy routing still reaches its exact target. This is a controlled cost model, not a live browser profile.

Also PASS: `test_police_foot_navigation.py` (12 arrivals, no overlaps), `test_police_backup_navigation.mjs` (actual wall/car detours), `test_empire_route_generation_dom.js` (12 route generation/isolation/idempotency checks). Isolated police harnesses now import the new helpers.

Limit: one individual native query or one edge's body sampling can overrun the deadline before the next loop guard. Expensive query internals must remain bounded by the root's spatial index/cache work. Live responsiveness is parent-owned and not yet certified by these CPU tests.
