# Runtime lag profile — 2026-09-08

Actual shared /walk, 1100x800 headless Chrome, user tab untouched. Current stationary view renders 2887 draw calls and 990882 triangles; 42 shader programs. Scene has 342 PointLight nodes including layer-disabled originals (not 342 contributing lights). Initial profile was contaminated by shader warmup; warmed CPU profile identified floorHeight/ceilingHeight in building_entry_profiles and renderer material/matrix work as major sampled costs.

Applied precise helper-only edits:
- building_entry_profiles: cached world bounds covering room, corridor and ramp reject distant floor/ceiling samples before Vector3 allocation/inverse transformation. Existing placement is fixed per generation. Reject disabled for pitched transforms. No dimensions, doors, geometry, ID or ownership changes.
- point_light_loop: ordinary no-shadow point loop skips zero-color and finite-cutoff-excluded lights before PBR calculation. Original shadow branch remains unchanged. This alone did not materially improve median frame time in A/B; do not describe it as the main fix.

After excluding a concurrent coordinator browser run, repeated room A/B measured median 41.7 ms before / 34.7 ms after, p95 83.4 / 41.7 ms, same draw calls/triangles/programs, no browser errors. About 17% lower median frame time in this test, not a guaranteed user FPS. Scripts, before-source snapshots and profiles are in worktree51b3 .perf-crash/profile-current.cjs, lag-room-ab.cjs, lag-room-ab.json. Render batching and matrix/material overhead remain; no claim of all lag resolved or 60 FPS.

Validation passed: test_building_rooms, test_building_site_scale, test_indoor_camera, test_room_size_integration and point-light-loop source invariants. All own browsers closed; coordinator14 notified GPU free. walk and hero files untouched by this change.
