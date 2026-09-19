# Ambulance source transport — 12 September 2026

Owner: Artist16 / npc_damage. Shared native vehicle navigation, hospital resolver,
snapshot seat binding and LIVE acceptance belong to root. No GPU scene was opened
by this subagent.

## What changed

- `assets/maps/city_rebuild_v1/ambulance_transport.js` is loaded before the main
  world script. Existing public ambulance functions delegate to this scoped helper.
- Each ambulance has three persistent source `NPCS` entities: `_ambulanceDriver`
  and two `_medicalCrew` references. HP, wounds and death use the ordinary source
  NPC combat pipeline. Reusing a fleet vehicle never recreates or heals its crew.
- `_medicalCrewVehicleId` and `_vehicleId` hold the raw service ID. Navigation and
  presentation use `service_${id}`. Seats: `front_left` driver, `front_right` senior
  medic, `rear_left` second medic. `_inVehicle` denotes actual boarding; exit/enter
  transitions expose `_medicalBoardPhase` and `_medicalBoardProgress`.
- Deployed medics are excluded from civilian planners, replacement spawning and
  population trimming. The usual death and medically downed lifecycle still runs.
  Snapshot no longer substitutes synthetic HP100 bodies (root's scoped integration).
- A dead, medically downed, absent or unboarded driver cannot move the vehicle.
  Both assigned medics must be alive and boarded before departure. Losing a bearer
  interrupts pickup; the carried patient is put down at the actual stretcher point
  with unchanged HP/death. A disabled crew is not invisibly replaced.
- Approach and return use actual pedestrian movement with body clearance, dry land,
  the existing bounded pathfinder and true arrival gates. Elapsed time alone cannot
  finish travel through an obstacle. Timers remain only for stationary medical and
  door gestures after the actors have reached their positions.
- The ambulance uses the shared native swept vehicle checker and bounded native
  road routes, including other vehicles and water. It does not use the old emergency
  traffic-collision bypass. Legacy checks remain only without a native bridge.
- Native scene parking has at most 64 radial candidates, with a shared limit of
  four parking body queries per source frame across fleet/deployment searches.
  The rear door must have pedestrian clearance. A stale obstructed parking point
  is discarded. Routes still need to reach both parking and casualty physically.
- Hospital identity, door and initial bay come from root's `mode:'hospital'`
  resolver of the loaded physical hospital. Missing/unready destinations wait;
  no legacy POI or unvalidated door is substituted. Additional fleet spaces are
  checked and separated; assigned spaces are retained on subsequent returns.
- Watchdog recovery only replans. It never moves the ambulance to a scene or
  hospital and never heals cargo. Hospital completion requires actual proximity,
  available boarded crew and observed return movement for a carried patient.
  HP1 remains a living casualty; a dead NPC stays dead after delivery.

## Tests and costs

Passed:

- `node assets/maps/city_rebuild_v1/test_ambulance_transport.mjs`: actual source
  functions, stable crew identities, full pickup phases, 60 seconds of blocked
  approach without fake loading, killed bearer, dead/downed driver, native parking
  frame budget, distinct fleet spaces, real hospital ID, arrival-only recovery,
  corpse preservation and no watchdog healing/position snap.
- `node assets/maps/city_rebuild_v1/test_ambulance_native_cost.mjs`: production
  native navigation blocks source ambulance against a thin solid, water and
  another vehicle. Same source step is measured before/after in a fixed 357-polygon
  CPU fixture (10 warmup batches, 35 measured batches, 40 updates each): legacy mover
  p50/p95 **0.0020 / 0.0077 ms**, native ambulance mover **0.0811 / 0.0940 ms**.
  This extra work adds swept collision previously absent from the legacy mover.
  The fixture deliberately scans all polygons; the real host uses a spatial index.
- `node assets/maps/city_rebuild_v1/test_npc_vehicle_navigation.mjs`: physical
  detour, water/solid/car contact and newly blocked route segments.
- `node test_world_walk_physical_shot_admission.mjs`: actual `fire` → `hitNpc` →
  confirmed receipt now also exercises source medics for pistol/rifle/sniper/shotgun.
- `node test_world_walk_shots.mjs`: current source syntax and shot contracts.
- Six existing client medical/overlay tests pass via
  `python -m unittest test_wounded_medical_ui test_player_ambulance_transport.PlayerAmbulanceClientTests`.

The two older Python `PlayerAmbulanceServerTests` fail before their assertions:
current authoritative-body persistence requires the `characters` table, absent
from that old fixture. No server/database code was changed or bypassed.

## Acceptance limits and remaining checks

**Производительность общей сцены не проверена.** CPU fixtures are not loaded-game
frame time or authenticated acceptance. Root owns the serial LIVE/GPU pass.

Verify in the populated `/walk` scene: actual hospital/depot placement, forward
road turns, occupied roads, off-road casualties, door transition readability,
both male/female medics, HP/wounds/death on deployed crew, interrupted driver and
delivery of a living casualty versus a corpse. An unreachable patient or blocked
hospital remains pending instead of being completed by a teleport. Replacement
dispatch for a destroyed/disabled crew and hospital unloading through an animated
admission-room doorway are not introduced here.

This preserves the existing client source medical HP behavior and existing server
emergency transport/revive calls. It does not add server-owned ambulance or medic
entities, nor prove authenticated backend recovery. Static monitor18538 is not
that backend.
