# Road-egress retry livelock — Artist19, 20 September 2026

## Applied change

`assets/maps/city_rebuild_v1/npc_road_egress_source.js`: retain the landing-candidate index between batches of four failed route attempts. Reset it only after all finite candidates have been checked. The existing one-second retry delay, four-attempt batch, shared 4 ms planning allowance, native body/water/sweep validation and activity interruption guards remain unchanged.

There is no inline copy: `world.html` loads this helper with a script tag. No world, transport, police, boss or activity source was changed for this patch.

## Reproduction and checks

Read-only sampling of 473 safe road positions in the existing actual-geometry fixture found four locations where the nearest four safe landing points were unreachable but later ones were reachable:

| Row | Column | Repeated exhausted index |
|---:|---:|---:|
| 5.5 | 110.5 | 99 |
| 15.5 | 55.5 | 298 |
| 50.5 | 115.5 | 97 |
| 60.5 | 20.5 | 300 |

`test_npc_road_egress_livelock19.mjs` reconstructs only the previous retry line and compares the same source planner and physical geometry. At each location the old code failed to publish a route over 25 simulated seconds, repeating the same batch 19 times. The applied change published a collision-checked route in 1.45 simulated seconds, including the retained one-second retry pause. Planning does not move the resident or replace the civilian intent.

The new test also verifies interruption/owner priority, retained shop journeys, and full-list exhaustion followed by newly unblocked land. All published segments and destination footprints are checked against the actual native collision and surface authority.

Passing checks:

- `node test_npc_road_egress_livelock19.mjs`
- `node test_npc_road_egress_safety18.mjs`
- `node --check assets/maps/city_rebuild_v1/npc_road_egress_source.js`

Isolated planning-call CPU p95 before/after at the four points: 2.76/2.55, 1.99/1.92, 2.24/2.58, 1.91/1.74 ms. These are different-length runs including deliberate backoff calls, not a controlled full-scene FPS comparison. They should not be presented as a general performance gain.

Limits: the fixture includes the saved authored/generated city colliders, native water, one actual building GLB and a compact sedan. It excludes live railway and other streamed vehicles and does not instantiate the whole NPC update/render loop. The root task owns reload and browser observation. No link to the previously observed `resident12` stall is asserted without its live coordinates.
