# Transport vehicle debris exact duplicate-point experiment

Status: **PHYSICS/PERFORMANCE REJECTED / DO NOT ADOPT**.

This isolated candidate is a copy of frozen
`transport_vehicle_debris.gd` with one collision-path change: after collecting
all original transformed source vertices for one hull, it preserves the first
occurrence of each numerically exact `Vector3` and assigns that shorter array to
`ConvexPolygonShape3D.points`. It does not use epsilon merging, quantization,
clustering, simplification or vertex motion. Visual Mesh resources retain all
source vertices and the same private Mesh/material duplication.

## Actual Godot result

Godot `4.7.2.stable.official.ed1daf0bf`, actual city hatch:

- 10 bodies, 76 hulls, 76 private Mesh resources, 76 private materials and 29
  source material identities remained;
- all 142,948 visual/source vertices remained;
- collision input points fell from 142,948 to 27,298; 115,650 numerically exact
  duplicates were removed;
- retained `Shape3D.points` payload fell from 1,715,376 to 327,576 bytes
  (`count * 12`). This is a resource-array payload measure, not attributable
  process/Jolt memory: allocator and cooked-shape memory cannot be isolated by
  the shared headless process;
- every candidate point array exactly equaled first-occurrence deduplication of
  the corresponding frozen array, and tested support extrema matched frozen;
- launch, layers, masks and input velocities validated.

The suite ended **75/76 PASS, one intentional acceptance failure**: all ten
candidate bodies did not reach native sleep within 900 physics frames. The
frozen/no-dedup path previously settles this scenario. Equal mathematical
support is therefore insufficient to claim equal Jolt cooking/contact behavior;
the collision-fidelity gate fails.

## Whole configure cost

One 20-pair alternating isolated headless comparison:

| Path | min | p50 | p95 | max |
|---|---:|---:|---:|---:|
| frozen | 100.002 ms | 110.511 ms | 117.202 ms | 119.553 ms |
| unique-points candidate | 99.451 ms | 106.534 ms | 118.055 ms | 130.816 ms |

Median improved only about 3.6%, while p95 and maximum became worse. Configure
still blocks for roughly 107 ms. Candidate prewarm p50/p95/max was
45.5/59/59 microseconds and launch was 471 microseconds, but these do not repair
configure or collision fidelity.

## Decision and limits

- Reject the candidate. Do not replace frozen collision point arrays.
- The raw point-array memory reduction does not justify changed physical
  settlement or the unchanged ~100 ms event/load spike.
- This was isolated headless CPU/physics, not loaded-scene FPS, GPU or LIVE.
- No frozen runtime, production integration, source visual, damage pipeline,
  Git, GPU window or LIVE scene changed.

