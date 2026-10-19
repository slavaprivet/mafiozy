# Transport vehicle debris bulk-points candidate

Status: **FUNCTIONALLY VERIFIED / PERFORMANCE REJECTED / DO NOT ADOPT**.

The existing `transport_vehicle_debris_exact_points.gd` candidate does not
optimize initial configuration: its `configure()` calls the frozen scalar
implementation and uses packed bulk transforms only during later geometry
refresh. This new isolated sibling copies frozen
`transport_vehicle_debris.gd` SHA-256
`1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`
and changes only initial hull point transformation.

The frozen expression `bake_basis * (relative * vertex)` is preserved as two
native bulk stages per surface: `relative * PackedVector3Array`, then
`Transform3D(bake_basis) * PackedVector3Array`. Point validation, hull cooking,
private mesh/material duplication, bodies, collision nodes, physical values,
prewarm, launch, reset and disposal remain unchanged.

## Correctness

Godot `4.7.2.stable.official.ed1daf0bf`, actual city hatchback:

- 10 ordered physical assemblies;
- 76 hulls and collision shapes;
- 142,948 input vertices;
- 76 private meshes and 76 private material Resources from 29 source material
  identities;
- every hull `PackedVector3Array.to_byte_array()` equals the frozen scalar
  result;
- convex support extrema match in five directions;
- every collision node retains its corresponding hull shape;
- private Resources remain independent from source Resources;
- inherited prewarm reaches READY and launch preserves 10 bodies, 76 hulls,
  caller layers/masks, and exact linear/angular velocities;
- five actual physics frames remain finite.

Final author safe-runner result: **74/74 PASS**, exit 0, process joined.

## Whole-configure cost

Twenty alternating frozen/candidate pairs, isolated hidden headless CPU:

| Path | min | p50 | p95 | max |
|---|---:|---:|---:|---:|
| frozen configure | 106.685 ms | 112.293 ms | 126.451 ms | 136.447 ms |
| bulk candidate configure | 102.625 ms | 112.684 ms | 121.160 ms | 122.291 ms |

The candidate is **0.35% slower at the median**. Its lower p95/max is not a
robust whole-path gain: an earlier unqualified run with an incorrect source
material census showed a different median direction, while all geometry checks
already passed. Deep mesh/material duplication and convex cooking dominate the
path, so the isolated transform-kernel improvement is lost in full configure.

Prewarm call p50/p95/max was 51.5/98/98 us frozen and 57.5/71/71 us candidate.
Single launch cost was 729 us frozen and 754 us candidate. These are isolated
CPU calls, not FPS measurements.

## Decision and limits

- Do not replace the frozen provider with this candidate.
- No production runtime, damage rules, geometry, collision fidelity, content,
  source authority, Git, GPU window or LIVE scene was changed.
- No loaded-scene FPS claim exists.
- The remaining configure spike is roughly 112 ms. The next safe experiment is
  transactional incremental preparation of complete mesh/hull units before the
  event; it must expose no partially ready provider and must retain all content.
