# NPC vehicle door/seat pass (20 September 2026)

Scope: actual `family_wagon`, `city_suv`, and `police_interceptor` GLBs; all four doors/seats; actual male/female NPC GLBs at 1.65 m and 2.05 m. Actor death, melee, source authority, driving physics, and player access were not edited.

## Fixes

- The traffic seat bridge now carries the real seat side and driver/passenger role. Right-side occupants therefore use the right-side door arm instead of inheriting the left-side pose.
- During board/exit, the door-side hand blends toward the moving authored door handle. The blend is deliberately partial and spread over the door motion so an extreme-height actor does not snap to an unreachable point.
- Passenger arm settling now ramps from fold 0.70 to 1.00. The old branch applied a large rotation in one frame at 0.70.
- Door-handle sampling uses one bridge scratch vector per vehicle binding; it does not allocate a new vector each frame.

## Actual-rig proof

`test_npc_vehicle_door_fleet20.mjs` runs 48 complete approach/board/drive/exit/release cases. It checks both sides and both rows, source-root ownership, wrist motion, a foot in the correct physical doorway at mid-transition, seated roof/floor clearance, and both driver hand sockets on the steering-wheel grips.

- worst watched-bone step: **0.1601 m before** (abrupt rear-passenger arm settle) -> **0.1167 m after** across the expanded 48-case matrix; compact sedan remains **0.0921 m** or lower and interrupted entry remains **0.0794 m** or lower;
- worst door-side socket to moving handle while reaching: **0.5260 m**. This is a visible reach, intentionally not a hard hand lock because the extreme-height rigs and wide SUV door can put the moving handle outside arm length;
- minimum seated head-to-roof clearance: **0.4193 m**;
- minimum seated foot-joint-to-floor clearance: **0.0925 m**;
- all 48 mid-transition threshold checks used the matching door opening;
- CPU actual actor update for the 1,968 board samples: p50 **0.1461 ms**, p95 **0.2560 ms**. This is pose CPU only; renderer/GPU/full-city FPS require LIVE.

Machine-readable result: `outputs/npc_vehicle_door_fleet20_after.json`.

## Passed regression

- `test_npc_vehicle_door_fleet20.mjs`
- `test_npc_vehicle_transition_continuity.mjs`
- `test_npc_traffic_binding.mjs`
- `test_vehicle_fleet.mjs`
- `test_vehicle_interiors.mjs`
- `test_vehicle_seats.mjs`
- `test_npc_vehicle_outside_yaw.mjs`
- `test_world_vehicle_player_pose.mjs`
- `test_mercenary_vehicle_follow18.mjs`
- `test_npc_seated_driver_contact.mjs`
- `py -3 check_world.py`
- scoped `git diff --check`

LIVE acceptance remains with Artist19 in the single existing game tab.
