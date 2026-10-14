# Mercenary187: dry shore, then no_route — 23 September 2026

## Result

The water exit worked. The remaining stationary follower is a separate limitation
of the new five-candidate monotone long-follow helper, reproducible with the
current source host and native geometry. Production was not changed in this audit.

LIVE evidence supplied by Coordinator20:

- Before: `.git/ai-pipeline-local/live23/npc-inspection-water-before23.json`,
  captured 2026-09-22T21:57:23.591Z; merc187 at
  r27.799313847727056/c41.644286187278674, presentation y -1.2677957700059308m.
- After: `C:/Users/Слава/Downloads/npc-inspection-1790116199540.json`,
  captured 2026-09-22T22:29:59.531Z; merc187 at
  r27.799313847727056/c45.138444723859244, presentation y0, hp60, alive.
- Coordinator's movement QA gives goal r40.31707317073171/c39.390243902439025,
  stop0.6m, scale4.1. Thus source x185.0676233678229/z113.97718677568092;
  goal x161.5/z165.3. This is an east-bank start and west-bank destination.

## Reproduction

Run `node outputs/merc187_native_geometry23.mjs` for the checked static fixture;
add `--current` to regenerate decor, road and parking plans from the current
production planning functions and JSON. Results are recorded in
`outputs/merc187_native_geometry23_snapshot.txt` and
`outputs/merc187_native_geometry23_current.txt`.

The fixture executes current world `_npcBodyPassable`, `_npcPathPassable`,
`npcPassableForSnitch`, the current native query including continuous footprint
sweep, current mercenary route/staged helpers, and complete mercenary_world host.
Only the host's browser import boundary is supplied from Node. The nearest
woodland_crosswing_house_v1 GLB is loaded through actual building entry/window
creation, providing its current floor and door/wall collision bodies. Walk's
actual `canWalk`, `pedestrianAllowed`, and sampled `canMove` adapter are also
executed against this fixture.

All 78 current building transforms/collision records match the checked snapshot.
Regeneration gives exactly equal collider arrays: decor2296, road545, parking57.
Authored decor has164 records in both. Thus the finding is not an obsolete
generated tree/parking layout.

## Exact failure

The start is dry and body+sweep pass. First 0.65m steps east and north pass.
West and south are rejected correctly: footprint corners enter water although
the centre can still be dry.

| Stage offset from heading | Source endpoint r/c | Result |
|---|---|---|
| 0 degrees | 33.11891394 / 42.69566492 | Centre dry; northern body corners depth0.04540757m, rejected |
| +30 degrees | 31.18483276 / 40.36313532 | Dry body; on opposite bank; no route within unchanged local constraints |
| -30 degrees | 33.62761256 / 45.68273541 | Water depth2.22m |
| +60 degrees | 28.34360453 / 39.31014601 | Water depth2.22m |
| -60 degrees | 32.57462325 / 48.52396364 | Water depth1.5766m at centre, deeper at corners |

The full source host, with two recruited members to reproduce formation slot1,
uses the exact LIVE goal and returns `search_pending` then `no_route` without
moving187. Four endpoint gates fail before search. The sole dry search exhausts
its reachable set after118 expanded nodes/198 total staged checks. It does not
reach the2400-node cap. The static-only hospital fixture gave121 expanded; using
the actual nearest house entry correctly changes that number to118.

Therefore raising CPU/node budgets cannot make these five targets suitable.
The helper's endpoint angles and `d-distance(candidate,goal)>=1` requirement
exclude an initially retreating route around the bank.

## Physical exit witness, not an integrated fix

With the unchanged local route planner (step0.65m, maxNodes2400, maxDistance48m,
8 expanded per slice, budget0.75ms), start→x203.0676233678229/z125.97718677568092
has a physical dry route after147 expanded/285 checks. It starts east then turns
south around the house/bank. This endpoint is0.744857m farther from the leader.
It proves that the dry start is not physically sealed; it does not by itself
prove a complete route to the opposite shore.

## Next isolated candidate scope

Keep production unchanged until the next checkpoint. Investigate a bounded
detour/corridor fallback in the staged helper, retaining local48m routes,
8 expansions/0.75ms and host shared1.5ms deadline. Temporary separation from the
leader must be allowed, with bounded visited-stage memory to prevent cycling.
Validate actual187 geometry, five crew, moving leader, retarget/cancel, and
enclosed/U-shaped negative cases before any integration. Do not change water
depth, footprints, collision predicates, authority, or actor positions by snap.

## Limits

This is CPU/source evidence, not LIVE/FPS acceptance. Full runtime dynamic world
is not in the inspection export: other streamed cars, train, mutable fences,
all buildings' live doors/ceilings and live actor ownership are not reconstructed.
The fixture contains current static city bodies, one actual nearest house entry,
and the fixture's irrelevant parked sedan at origin. Other buildings retain
their authored outer collision bodies. Hero support uses available native floor;
unreconstructed interior ceilings are explicitly absent. Additional dynamic
obstacles can only add failures; this fixture proves a sufficient existing
source failure before those conditions, not universal future route success.
