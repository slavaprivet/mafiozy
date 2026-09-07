# Rail correction handoff — 2026-09-07

Status: **development-only, not live approved, do not include in civic release**.
No browser session, commit or push was performed by the rail correction agent.

## Implemented within owned scope

- Registry uses a tested platform pose helper: L and R centers are respectively
  +5.25 m and -5.25 m from route center, in both travel directions. The warning
  edge and active doors now agree with the actual side.
- State machine consumes elapsed time using substeps rather than discarding
  everything beyond 0.1 seconds. Normal unobstructed dwell is exactly 4 seconds;
  residual elapsed time after departure is applied to movement. An occupied door
  or withheld crossing authority extends the stop for safety.
- Exported LOD0 car roots receive separate route positions and two-bogie tangent
  headings. World collision and door positions use the same per-car poses in
  `snapshot.position.cars`, avoiding the old rigid 55.2 m rectangle around turns.
- Crossing occupancy ignores hidden/towed/removed entities, uses finite actual
  coordinates (including valid zero), and projected body extents. A parked or
  wrecked car genuinely ON the rail remains an obstruction, correctly. Adjacent
  parking outside the track envelope no longer blocks merely for being nearby.
- Occupied crossings reopen to let trapped cars leave. Closure begins only after
  0.6 seconds clear, with warning lead distance 72 m versus authority hold 48 m.
- Passenger anchoring is factored into `_cityV3RailSyncPassenger` for a separate
  post-update hook.
- 14 executable Python/Node tests PASS; registry `node --check` PASS. These prove
  math/state/contracts only, **not a rendered train or successful live journey**.

## Required root-owned hooks — NOT applied here

The only current `_cityV3RailTick(dt)` call remains at the end of `update(dt)`.
Car passenger/driving/bus/building/bank returns skip it. Root must:

1. Remove that old end-of-update call to avoid double stepping.
2. In `_timedWorldUpdate(dt)`, call `_cityV3RailTick(dt)` before `update(dt)` and
   `_cityV3RailSyncPassenger()` after it, ideally in `finally`. This encloses all
   existing early returns without copying the entire world update function.
3. While aboard, suppress walking input and exclude the player's train anchor
   from `_ensureSpawnSafe` rescue and ordinary pedestrian collision correction.
   Preserve camera, NPC/traffic, projectiles, world events and networking updates.
4. Disallow boarding while driving/riding another vehicle, dead or in interiors;
   prevent regular vehicle/building actions from stealing an active train ride.
5. Verify train progresses while driving, sitting as car passenger and inside
   buildings; verify no duplicate ticks at normal walking; verify WASD cannot
   detach the passenger. Then test safe exit at both L and R platforms.

## Remaining blockers / geometry and assets

- The contract route still has 90-degree corners and very short 15.12 m legs.
  Per-car poses reduce the old whole-consist swing but do NOT make those corners
  physically or visually acceptable: bogie chords cut the corner and couplings
  cannot maintain their 1.2 m gap. Requires new swept-radius route with refreshed
  lengths/station progress/crossing positions and binding hashes, not a silent
  renderer-only curve over the old authoritative collision path.
- Rigid inter-car couplers are temporarily hidden during articulated rendering;
  flexible couplers/connection geometry are still needed before visual approval.
- LOD1 and LOD2 car roots AND many child meshes contain translation [0,0,128]
  rather than normalized car-local transforms. Do not enable distance LOD merely
  by toggling root.visible. Artist/exporter must normalize and revalidate bounds
  and side-by-side game camera. `activeLOD=0` and `lodReason` now disclose this.
- Live geometry audit still checks route center, not all swept car/platform
  extents or scenery. ST07/ST08 palm overlaps remain unverified and must be
  resolved before enabling this across the map.
- Body extents for road occupancy use declared lengthM/widthM when present and
  conservative fallback 6 x 2.5 m; bind actual vehicle model dimensions next.
- Crossing clears safely but continuous incoming traffic could starve departure.
  A direction-aware upstream entry hold plus outbound escape lane is still
  needed for reliable queueing; current point-only gate API cannot identify
  inbound versus outbound vehicles. Do not solve this by ignoring real bodies.
- `trainVisible` in the world/probe is not a frustum/render measurement. The
  renderer must report real scene attachment, loaded visible mesh count, camera
  visibility and a live screenshot instead of using that boolean as acceptance.
- Loader is still blocking renderer startup and has no cancellation/timeout.
  Root must fix the asynchronous startup transaction before broad release.
- Eight stops are coastal candidates, not proven service to all eight districts.
  Central hub/depot intentionally remain null and must not be advertised as done.
