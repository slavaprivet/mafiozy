# Artist18: physical road exit after interrupted car trip

Status: APPLIED by root in world.html (`physical-grid-v4`): helper script, guarded pick hook, native planner dispatch, exact arrival and ordinary pass. Shared actual-native fixture loads the helper; post-exit audit automatically uses applied mode. No browser reload or GPU acceptance performed here.

## Cause and correction

Actual hospital car outside anchor `(5.9891819668772195, 162.0104224872629)` is dry native road. After recovery, ordinary `npcWaypointOk` rejects the first road sample, so both coarse wander and its fine fallback leave the actor stationary: 0 m in 60 seconds. Road exit is a physical, temporary connection to a completely clear land footprint, followed by the existing walk/visit plan.

`assets/maps/city_rebuild_v1/npc_road_egress_source.js` contains the bounded helper. `test_npc_road_egress_candidate18.mjs` exports the pure `stageNpcRoadEgress(world)` transform for five narrow integration changes:

- Include the helper script alongside the native planner.
- Admit `civilian_road_exit` to the existing native A* dispatch, retaining the same shared 4 ms / two-owner FIFO.
- Give this route an exact `.001` arrival tolerance so it cannot stop before reaching land.
- Invoke the helper from `pickNpcWaypoint` after threat guards, before ordinary planning.
- Use `npcPassableForSnitch` in ordinary foot movement only for this temporary route (existing native building entry remains unchanged).

Nearest sampled land search: stable .25-cell offsets within four cells, inspected incrementally under the existing queue/deadline. A route retains its goal and origin across slices; native planning has a 384-node limit. Four failed land routes cause a one-second retry. Search never changes actor position, HP, identity, plan or shop goal. Actual movement retains full-body and continuous collision sweeps. Existing ready/pending building visits have priority. Center-land/body-corner-road straddles are eligible; the final goal requires all five footprint samples to be clear land. Existing respawnable civilian eligibility is used without requiring the `resident_` ID prefix; special guards/bosses/police/medical/vehicle/activity owners remain excluded.

## Verification

`node test_npc_postexit_audit18.mjs` (applied mode; staging flags remain supported)

Actual native car outside, authored hospital GLB, static city/car/water geometry, real trip release, ordinary foot and waypoint functions. No manual per-frame visit retry: this avoids the old lifecycle fixture masking ordinary-foot defects.

- Normal and initially deferred building routes complete physical entry, service visit and exit in approximately 34–36 s.
- Recovery and unrelated stale pending start moving at 200 ms, reach land by 850 ms, then walk over five metres.
- Every moved step remains swept/body-clear and at most .083 m; no actor teleport.
- Recovery helper cost across three calls: roughly 0.46–0.74 ms total; worst individual call roughly 0.26–0.45 ms on the tested anchor. These are CPU helper measurements, not city FPS.

`node test_npc_road_egress_safety18.mjs`

Actual shared queue/native planner with controlled dynamic/surface responses: water-only/blocked land returns no route; a new obstacle inserted after planner completion rejects the landing before publication; stable discovery resumes; ready/pending building journeys are untouched. Footprint straddle and civilian IDs `merc_resident_dismissed` / `world_person_42` pass; special ownership exclusions pass. Synthetic clock advances .03 ms per query: slices peak at 4.35–4.38 ms (one atomic probe may finish past the 4 ms boundary, as in the existing planner).

## Limits

This addresses road egress after an interrupted trip, not the whole-city pending-route population. A moving obstacle on a previously searched intermediate edge can still cause safe stopping and replanning; ordinary swept movement remains authoritative. Search can wait when no dry land within the bounded radius is reachable. Performance of the loaded overall scene is not verified.

The separate exact-door duplicate correction has already been applied by root to `_civilianRouteTo`; it is required for the ordinary foot branch to begin a completed visit rather than replan at duplicated final points.
