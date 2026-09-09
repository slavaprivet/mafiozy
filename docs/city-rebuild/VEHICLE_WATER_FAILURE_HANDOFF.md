# Vehicle flooding, brief steam and shoreline v6 — 2026-09-10

User request: drive deeper into water; engine failure when water covers the actual engine; coast, sink and retain a safe exit; brief fading smoke/steam; soften the straight shore boundary.

## Implementation

- `vehicle_water_state.mjs` runs after actual terrain/roll posing for active and passive fleet records. Highest rendered engine-detail vertices, not the open hood lid or a generic chassis centre, determine flooding. Fallback is the actual Engine_core mesh. All twelve authored GLBs are tested.
- Flooding latches per vehicle. Existing damage is preserved; torque becomes zero and depth-dependent water drag slows inertia. Vertical movement descends toward actual support with acceleration 2.2 m/s² and terminal speed 1.05 m/s. No ground reshaping or instant stop. Bridges retain support. Explicit fixture/full-fleet reset clears flooding; switching cars or leaving water does not repair it.
- `water_vehicle_access.mjs` admits actual deep lake/native-water surfaces while retaining police/protected masks and original collisions. The earlier shallow-bank connector remains the dry transition, no longer the depth ceiling.
- `vehicle_water_exit.mjs` uses the actual posed vehicle and occupant's own door. Submerged departure retains seat height rather than lowering feet into the sloping bed. Capsule checks exclude only the occupied car during doorway crossing. Other cars, walls and overhead obstacles remain blocking. Ascent is limited to 0.9 m/s, then handed to existing swimming. Flooded wrecks cannot be entered through ordinary entry prompts.
- `vehicle_water_vapor.mjs`: one instanced batch, maximum 96 particles, no new textures/lights. New flooding releases grey steam for 2.6 seconds with decreasing emission and fading particles. Emission tracks the actual engine horizontally and vents just above water when submerged. Broken cars do not emit forever or replay on switching. Teardown disposes the batch.
- Water-only shader v6 fades alpha to zero at all 434 outer lake edges, using physical shallow depth and a small irregular coverage threshold. Thin darker wet sediment and sparse foam replace the uniform bright border. Terrain geometry, topology and other materials remain unchanged.

## Verification

PASS: vehicle_water_state (all twelve GLBs and actual deep drive), vehicle_water_exit, vehicle_water_vapor, vehicle_water_admission, environment_surface_materials (14 variants / 9768 vertices / 434 edges), water_inspection, walk_water_hooks, vehicle_fleet, vehicle_walk_integration, vehicle_seats, vehicle_exit_surface, exploration_vehicle_support and walk syntax.

`test_walk_vehicle_water_hooks.mjs` extracts production pose/exit/finish helpers and tests real GLBs against 3231 native/decor/road/parking collision bodies in this shared-tree snapshot. All four sedan and both fire-engine seats pass, including the initially failing LIVE fire-engine pose. Walls, ceilings and another actual car reject exit. At 60 Hz ascent/finish moves at most 0.015 m per frame. DOM/camera/character presentation are stubbed in this CPU test; it is not browser acceptance by itself.

LIVE in the existing task tab: heavy fire engine drove beyond the old shallow limit, flooded at the engine, coasted to zero and sank to real support. Forward input again did not move it. One steam trigger produced 24 particles in the observed run; particles/emitters later reached zero. After the slope-exit correction, the real E-hold inspection control changed occupiedSeat from front_left to null and state to on_foot. Screenshot shows the character afloat beside the still-disabled submerged truck. No teleport to shore. Earlier versions failed this exit; the exact-pose regression covers the correction.

## Repeat locally / ownership

Final LIVE front-engine capture inspected after increasing steam puff size, rise speed and opacity: short grey cloud is visible above the submerged front, distinct from the wheel droplets. The current reload's browser error list is empty with both effects visible. Continued simulation again reached zero steam particles/emitters (one trigger, 24 total), zero speed and bottom support. This is qualitative GPU/visual verification, not an FPS benchmark.

The current router redirects ordinary `/walk` to the main world. Use `/walk?standalone=1&waterqa=1` for isolated inspection. The opt-in panel is prohibited when Mafiozi3DBridge exists and absent from normal gameplay. Buttons prepare local actors, drive through normal input/solvers and hold E through the existing interaction path. Failure capture pauses a real flood event and provides a front-engine inspection camera; Continue resumes simulation.

This is local walk verification, not authoritative multiplayer persistence, cross-client replication, save/reload repair rules or full-scene FPS acceptance. No server restart, deployment, account mutation or commit. Concurrent coordinator15 environment/grass/roads and vehicle-owner damage/impact/door changes were preserved. Never replace shared walk/fleet files wholesale with an older copy.
