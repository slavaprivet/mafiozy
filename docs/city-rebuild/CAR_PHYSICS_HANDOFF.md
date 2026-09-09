# Car control and tire marks — 2026-09-08

Scoped to the `/walk` third-person inspection scene. No gameplay/server vehicle
ownership, damage or economy changes. Model +Z forward / +X driver-left remains.

`stepCar` preserves 120 Hz substeps, W/S acceleration/brake/reverse, 22 m/s forward,
6 m/s reverse, speed-dependent steering, full-body collision and flat-grass access.
Steering now has smooth yaw-rate response and a lateral acceleration limit of
10 m/s². Space still brakes/locks the rear axle, relaxes rear grip and permits a
short controllable slide; releasing it restores grip. This is flat-map arcade
physics, not suspension, vertical terrain or a full rigid-body solver.

New returned car-state fields: `yawRate` (rad/s, retain between steps), `braking`
(foot or handbrake), `slipAngle` (rad), `frontSlip` / `rearSlip` (0..1 visual grip
loss). Existing `speed`, `travelYaw`, `distance`, `handbrake` remain compatible
with moving-exit prediction, hero launch and wheel updates.

Integrate `createTireTracks(THREE, options)` from `tire_tracks.mjs`. Add its
`object` to the scene; call `update(carState, dt)` every frame, including coasting
and parked frames so old marks fade. `clear()` resets after teleports/world reload.
`dispose()` releases GPU resources. Optional `surfaceAt(x,z)` returns whether
rubber marks are appropriate (use road/paving masks to avoid black marks on lawn).
Default pool: 1200 segments, 10 seconds lifespan, .28 m sampling and .19 m width.
The bounded single mesh has per-segment fade, depth testing and no depth writes.
`pool.active` and `pool.count` support live verification. No marks are emitted for
normal straight rolling, stationary handbrake, across a release gap or teleport.

Automated checks: `test_car_drive.mjs`, `test_car_exit.mjs`,
`test_tire_tracks.mjs`. Drive additions verify 30/60/120 Hz agreement, high-speed
lateral grip, handbrake slip/recovery and braking telemetry. Exit tests preserve
24 moving-exit combinations. Track tests exercise bounded memory, fade/expiry,
axle selection, surface masking and reset gaps. Live integration and visual
verification belong to the coordinating task; do not interpret these unit tests
as a completed browser pass.
