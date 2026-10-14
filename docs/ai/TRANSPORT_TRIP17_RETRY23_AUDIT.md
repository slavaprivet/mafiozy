# Transport3 — read-only trip17 retry audit after shared reload

23 September 2026. No additional runtime changes. Both preceding transport
patches were reloaded by coordinator20; this is not their LIVE acceptance.

## Selected actual trip and evidence boundary

Official export `C:/Users/Слава/Downloads/npc-inspection-1790116199540.json`,
captured 2026-09-22T22:29:59.531Z, contains 72 cached actors and pedestrian
routeReplay. It does **not** contain civilianTrip history or vehicle route jobs.

Selected `npc_resident_2` / source `resident_2` / `local_vehicle_17`:
alive HP60, not riding, vehicle phase `planning`, agenda `drive`, NPC
r32.85541513915751 / c38.5. `inspectionActivity.visitStatus=route-blocked`
belongs to the retained visit state, not a vehicle route failure receipt.
Its pedestrian replay has pending=false, kind=walk, expanded=0, search=null;
those values cannot explain a pending vehicle search.

The same export contains `resident_64` / car5 in drive. Coordinator's later
DOM observation reports car5 travelled20.71m, so its static source `moving=false`
must not be presented as proof that its car never moved.

Coordinator20 supplied the detailed current car17 DOM observation at source
time125260ms. Car from r35.34146341463414 / c42.109756097560975 /
angle−1.5707963267948966. Goal `native:REBUILD-VISUAL-pine_ridge_cottage_v1-001`.
Planning: doorIndex4 of12 (fifth door), attempt2 (third candidate),
laneRejected=true, pending, trace expanded7, points0. Request ID:
`local_vehicle_17:civilian:native:REBUILD-VISUAL-pine_ridge_cottage_v1-001:2:123087.29999995232`.
Target r17.44293524101895 / c53.140165315629986 / angle5.890486225480862.

Trip/no-progress age **52.007s** is distinct from this request's age
**2.1727s**. Pending7-expanded is not a terminal failure. This turn has no
before/after counter delta for the same source clock; it does not invent a
measured failure growth rate.

## What the failure counters count

`audit_transport_retry_counts23.mjs` executes actual native navigation and
the actual civilian planning producer with controlled lane rejection/geometry.
It establishes units, not live failure quantities:

- 100 polls of one retained blocked native job produce failed=1.
- One NPC + one car + one complete 12-door planning pass can produce
  12 directed lane attempts and 48 distinct native fallback requests/failures.
- `npcTransport.failed` counts failed native jobs, not unique NPCs, trips,
  destinations or failed directed-worker jobs.
- The native cache's jobs count is retained jobs (capped64), not total people.
- A new source requestId includes car, door, attempt and timestamp; it creates
  a distinct job. A reset or a previously evicted request can also be computed
  again. Same ID polls while its job is retained do not increment failed again.
- Up to four fallback targets are attempted after a local lane rejection;
  this repeats across up to12 destinations. Final release normally delays the
  next car attempt30s, or120s for physical-progress recovery.

Results: `outputs/transport_retry_counts23.json`. Do not reinterpret the earlier
global266failed as266failed residents, or as the selected trip's count.

## Current geometry audit and unresolved cause

Recorded car17 origin is **exactly bay1** of
`parking:REBUILD-VISUAL-woodland_crosswing_house_v1-001` (perpendicular parking).
It is unrelated to car18's mid-parallel-exit suffix fix.

`audit_transport_trip17_23.mjs` replays exact reported coordinates against
static actual-city fixture geometry, using two explicitly labelled profiles:
actual fixture compact sedan half-length2.4542 / half-width1.188 and existing
default CAR2.24 /1.28. Neither is claimed to be the LIVE car17 profile.
Vehicle profile reaches all parking hull checks in this audit.

Both cases: start physically clear; verified parking exit **645points**;
directed route to the actual named building **1763points READY**. The exact
fallback target instead fails after11expanded with no-native-road-route.
The parked car needs a reverse manoeuvre, while generic fallback search only
generates forward directional steps near its start. This supports a specific
explanation for these unsuccessful fallback candidates on static geometry.

It does **not** establish why the earlier LIVE directed lane request was
rejected: the original reason/allowed parking lot subset, actual shape,
other vehicle positions and full current collision snapshot are absent.
The planning trace is overwritten by the fallback stage, and the current
cancelled lane request is not recoverable from the official snapshot.
Do not relax collisions, enlarge budgets, change fallback to allow arbitrary
off-road driving or remove the contents of the city based on this audit.

Results: `outputs/transport_trip17_23_audit.json`. Runtime stays unchanged.

## Exact next capture scenario for the current blocker

In coordinator20's existing single game, retain car17/resident2 IDs and do not
restart the world merely to collect a second counter sample.

1. Capture the current civilianTrip record when selected carId=local_vehicle_17:
   source time, npcId/carId, car pose, noProgressMs, planning.requestId,
   doorIndex/attempt, planning.trace status/reason/expanded and target.
   Capture the matching npcTransport route's from/to/shape/frontier/status.
2. Repeat after the same request changes or finishes. Compare **the same**
   requestId (or matching car/from/to if the route diagnostic omits ID).
   Record pending→blocked or pending→ready, rather than treating every poll
   or increasing trip age as another failure.
3. If it moves to the next door/attempt, retain both IDs and reason; collect
   the preceding directed lane result before the fallback overwrites trace.
   Required discriminator: lane failure reason and its permitted destination
   lotIds, plus exact car profile. The current export cannot supply these
   retrospectively. No new diagnostic runtime patch is authorized this turn.
4. On trip release near the existing60s non-riding no-progress limit, record
   its actual release reason and whether resident2 returns to an activity.
   That is one ended trip, regardless of how many fallback jobs were tried.

Until those fields arrive, the confirmed current LIVE state is **planning
after an earlier lane rejection**, with a static reproducible ineffective
fallback from an inward-facing bay. No new specific dynamic blocker ID is
proven. **Производительность общей сцены не проверена.**
