# Living city transport admission — 2026-09-19

## User criterion

The city must look naturally alive. There is no fixed requirement for 90 moving
cars. Existing residents must walk, visit places and physically board real cars;
traffic must be distributed across districts without sacrificing collisions or
frame rate.

## Applied production changes

- `ambient_traffic_driver_source.js` and its exact `world.html` copy admit at
  most two existing residents every 350 ms, with stable NPC/vehicle identity.
- A driver is considered only within six source tiles of the physical vehicle
  door. This prevents long driver approaches from flooding the shared pedestrian
  planner.
- A nearby `traffic_driver` uses a direct route only when the complete body path
  passes the existing native collision/water sweep. Otherwise the normal bounded
  planner remains authoritative.
- Native traffic spawn requests road points near residents already distributed
  across the city instead of concentrating all cars around the player. Off-screen
  respawn and full vehicle sweep checks remain required.
- `dataset.ambientTrafficDrivers` reports total and approach/board/drive phases.

## Verification

- `test_ambient_traffic_batch_admission.mjs`: two distinct real residents per
  bounded pass, no teleport, telemetry and interval guard.
- `test_ambient_driver_direct_approach.mjs`: clear nearby door approach bypasses
  the shared BFS while retaining the production path sweep.
- `test_ambient_traffic_drivers.mjs`: real walk/board/drive identity, death and
  readiness guards, bus, fire/tow, distributed spawn and collision contracts.
- `check_world.py`: all inline scripts parse.

The second combined LIVE reload (before the final distance/direct/spawn change)
improved driving from 3 to 9 and pending residents from 250 to 232, but exposed
45 ambient drivers all stuck in `approach`. The final change above is READY on
disk and must be included in the next combined reload. Do not claim final LIVE
acceptance until `approach` visibly transitions to `board/drive`, resident pending
falls without a CPU regression, and the user sees movement in multiple districts.
