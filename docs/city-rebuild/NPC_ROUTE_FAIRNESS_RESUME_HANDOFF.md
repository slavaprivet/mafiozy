# Route admission fairness and directed continuation — 2026-09-10

Root live inspection found residents stationary in `seek_shop`. Two source defects were confirmed: fixed-order actors could repeatedly consume the shared quota, and native time-limited searches returned partial paths which the exact-door planner discarded with a five-second cooldown.

## Changes

- FIFO admission is keyed by actual actor objects, shared by residents, police and the water owner's updated search call. The four-ms/two-search window is unchanged; one actor gets at most one admission per frame. Police retain their own one-search limit while refreshing the queue entry even when that separate limit defers them.
- Waiting entries disappear after one missed simulation frame or death, rather than holding the queue for seconds after the actor abandons its request. Pending door searches retry each frame without a cooldown or fallback wander.
- `_planNpcRouteTo` retains its BFS frontier on the actor when the native budget expires. The key includes source cell, goal, radius, search bound and route kind. It resumes that frontier instead of restarting. An unfinished search returns pending; it does not claim a completed route or arrival. Existing complete/exhausted search behavior and movement collision checks remain.
- The older one-building-search-per-frame limiter is retained in legacy mode; native mode uses the common fair scheduler so an earlier deferred resident cannot consume a separate preliminary quota.
- Candidate doors are checked against native body collision. A completed failed door is excluded for 15 seconds, and its selection is cleared; a merely pending search retains its door and cycle. Genuine completed failure retains the five-second backoff.
- `_npcRouteWorkExpired` with no active deadline does not claim expiration. The water owner independently updated its call to reserve with the actor identity before searching.

## Validation

`test_npc_route_fairness.mjs`: 12 fixed-order mixed police/resident requesters each receive at least eight grants over 100 frames under the unchanged quota; eight actual directed searches complete the exact door across slices without restarting their frontier. An abandoned queue head cannot block later frames.

`test_npc_route_work_budget.mjs`: 200 requests remain below the synthetic 220-query/four-ms bound; pending frontier retained; no unfinished route published as arrival. `test_civilian_purposeful_plan.mjs` also verifies a blocked native door is replaced, completed unreachable door excluded, and cycle remains unchanged.

Native water, purposeful plans/source syntax, police foot navigation and backup wall/car navigation pass. No server, renderer, ownership, gang capture, water geometry or NPC identity changes. Root owns live confirmation that previously stationary residents now progress.
