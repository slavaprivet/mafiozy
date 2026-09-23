# Safe recovery of the player's followers — 23 September 2026

User explicitly replaced the previous no-teleport rule for stuck/far-behind hired
bandits. Parent authorized production after published main `272d12c`. This change
does not integrate the earlier isolated shore-detour candidate.

## Production scope

- `assets/maps/city_rebuild_v1/mercenary_catchup.mjs`: new bounded helper; native
  placement validator, shared incremental search, on-foot recovery controller.
- `mercenary_core.mjs`: one re-export line only.
- `mercenary_world.js`: catchup locals; `squadDropOccupied`,
  `checkSquadDropPoint`, `validateSquadSafeDrop`, `findSquadSafeDrop`,
  `bindCatchupModule`, `recoverFollowers`; initialization, reset once/tick and
  one call after the transport tick; two read-only movement QA fields.
- `test_mercenary_catchup23.mjs`: actual production source/module regressions.

Transport3 separately owns `squadVehicle*`, seated/chase guards,
`decorateEntities`, `mercenary_vehicle_bridge`, `mercenary_walk`, and Walk native
validator wiring. Those shared-file edits are not part of this agent's scope.
No `world.html`, DB, backend, Git staging/commit/push or browser operation here.

## Behaviour and safety

Only source-owned active, alive, idle followers qualify. Recovery observes
distance >65m for 6 seconds, or no physical progress of 1.25m for 10 seconds at
distance >12m. Cooldown after placement is 20 seconds. Work/queue, rally, combat,
hospital/downed/returning, carried/carrying, occupied seats/vehicle chase,
interior, specialist safe-exit and conversation reset observation. Hidden scene
and >1 second update interruption also reset it. Source local-authority gate is
preserved. An eligible actor still walks normally while being observed.

Search tests at most 32 deterministic positions on 3.6/5/6.4/8m rings, never
falls back to the player's coordinates, waits 2 seconds before retry when no
point is safe. There is one common maximum of **4 geometry checks per source
tick**, shared by vehicle drop and on-foot recovery; at most one on-foot
relocation per update. A destination must pass twice at least 60ms apart,
including ground-height stability <=0.08m. Hero drift >2m restarts the bounded
search. This new recovery allowance does not modify existing pathfinding's
shared 1.5ms, 48m local range, 8 expansions or 0.75ms per call.

Each native validation preserves actual source full-body clearance, nine native
surface/ground checks across the square .18-source-cell body, water depth
<=0.025m, no sampled building interior, ground spread <=0.28m, and actual
vehicle/rail clearance with the circumscribed body radius (~1.044m), height1.9m.
Missing mandatory resolver fails closed. Current player, other crew and alive
source citizens must be >=1.6m away. Source lacks a shared NPC proximity index:
the crowd snapshot is created lazily once per tick only during a real recovery
attempt; population >1024 refuses the drop rather than omitting occupants.

## Shared transport API

`findSquadSafeDrop(m,index,origin,yaw,state)` takes a world `{x,z}` origin,
radian yaw and caller-owned state. Returns checked world `{x,y,z}` or null.
The search state exposes pending/blocked/ready, attempt and retryAt.

`validateSquadSafeDrop(m,point)` repeats fresh occupied/native checks on an
existing world destination and consumes one of the same four checks; returns
checked `{x,y,z}` or null. Transport should use this immediately before final
placement after an animated exit. Null means remain pending/keep seat ownership.

Walk supplies `targets.safeCatchupPoint(point,memberId)` returning
`{ok,point:{x,y,z},reason?}`. It uses the production `createMercenarySafePlacement`
factory with actual `npcNativeNavigation`, source `canMoveMember`, groundHeight,
sampledBuildingEntries.containsInterior and railway/fleet/logical/traffic hulls.

The on-foot hero-in-car gate covers source `myDrivingCarId`, bridge
`isPlayerInVehicle()` (raw occupancy including entering/exiting), and a
`getPlayerVehicle()` fallback. Reviewer caught the local-fleet full-seats case
and transition readiness mismatch; both fixed. Actual production bridge plus
full source host regressions prove no on-foot recovery/checks during entering,
driving/full seats or exiting without a source `myDrivingCarId`.

## Validation and observed cost

`node --test assets/maps/city_rebuild_v1/test_mercenary_catchup23.mjs`: **12/12
PASS**, including the final production bridge transition occupancy callback.

- 5 distant followers, 7/15/60Hz, cooldown, task/authority/hospital/carry/seat
  exclusions, moving origin, no-free-point wait/retry and unstable support.
- Actual native static-city scene187, source start
  r27.799313847727056/c45.13844472385925, player40/40: at ~10.15s transfers to
  r40/c39.1219512195122, then physically moves another1.103m toward formation.
  Actual source host and core execute unchanged; cash, id, HP and weapon remain.
- Five actual source members initially overlap at original lake position
  r27.799313847727056/c41.644286187278674: all5 recover while hero moves;
  checked dry positions and member spacing, maximum4 checks in a tick.
- Actual authored house room can be native-passable yet rejected as interior;
  actual compact sedan entering the accepted destination makes it forbidden;
  original lake destination is forbidden.
- Actual host player/citizen occupancy and population overflow guards, shared
  four-check allowance. No native resolver => no recovery.

Dry five-member helper update, 6000 samples after600 warmup: added helper cost
p50 ~0.0032ms / p95 ~0.0059ms, **zero geometry checks**. Old path had no catchup
helper; this is incremental CPU cost, not whole-host before/after FPS. Actual187
placement performed only2 native checks (~0.10–0.14ms/check in these runs); too
few samples for a meaningful percentile comparison.

Existing water, long-follow, rally/actions, routes, chatter and new transport
suites at first combined run: 87/88PASS. Only failure was the old long-follow passenger fixture at
`test_mercenary_long_follow23_host.mjs:103`, which assumes immediate legacy
quest-car seating without the new physical bridge. Parent informed; transport
owner is updating the fixture to the current contract. New transport's own
source/bridge suite PASS; final combined rerun remains with parent/transport.

Geometry fixture contains current static-city collision snapshot, actual
woodland house and actual compact sedan. Full LIVE dynamic trains, every moving
vehicle/door, graphics/frame time and loaded-scene FPS are **not tested here**.
Parent owns the only LIVE game; CPU PASS is not LIVE approval.

## LIVE diagnostics

Existing localhost `npcqa=1`, max1Hz `dataset.mercenaryMovement.crew` now includes
`catchup` (last at/reason/fromR/fromC/r/c) and `catchupStatus`
(reason/attempt/pending/cooldownUntil/nextTry). Observing/ineligible/no_safe_point/
confirm_ground/cooldown/placed explain waiting without modifying actors.
Actual shared-site187 is the primary parent acceptance scene; repeat vehicle
exit with the fresh validator and do not open extra game tabs.
