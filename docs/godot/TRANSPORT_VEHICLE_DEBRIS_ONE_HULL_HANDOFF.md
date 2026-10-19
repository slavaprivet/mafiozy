# Transport vehicle debris one-hull-per-assembly experiment

Status: **COLLISION FIDELITY REJECTED / DO NOT ADOPT**.

The isolated candidate keeps every private visual Mesh, material and all 142,948
source vertices. It changes only collision construction: instead of 76
per-mesh convex shapes in ten compound bodies, each assembly receives one
`ConvexPolygonShape3D` containing the exact concatenation of all its original
mesh vertices. This produces ten convex shapes.

## Geometry and contact fidelity

Actual Godot `4.7.2.stable.official.ed1daf0bf`, city hatch:

- all ten candidate point arrays exactly equal the ordered concatenation of the
  corresponding frozen compound point arrays;
- support values match frozen for the 26 nonzero directions of a 3×3×3
  direction cube;
- 76 private Mesh resources and 76 private materials remain unchanged;
- bodies launch, collide with the ground, remain finite and naturally sleep.

Support equality is not contact equality. For each assembly the test obtains
Godot's cooked debug triangles, builds consistently oriented hull planes, and
samples a 9×9×9 grid in the single hull's AABB. Of 136 sample centers inside a
single cooked convex hull, **64 (47.06%) are outside every corresponding
original component hull**. These are gaps/cavities filled by the outer convex
envelope. Doors and other multi-piece assemblies therefore become solid across
empty space. The acceptance check correctly fails despite equal extrema.

One-pair fall behavior also changes: the candidate settles after 330 frames.
At ten simultaneous providers, frozen settles after 293 frames and the one-hull
candidate after 384 frames. This further confirms different contact behavior.

## Isolated 1/3/10-provider measurements

Each row is one fresh headless process after actual hatch visuals are loaded.
These are bounded experiment samples, not a statistical loaded-scene gate.

| Providers | Path | Bodies / hulls | Configure total | Static-memory delta | Awake physics p50 / p95 | Settled physics p50 / p95 | Settle frame |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | frozen | 10 / 76 | 103.019 ms | 6,002,136 B | 276.812 / 276.812 ms* | 1.252 / 1.703 ms | 279 |
| 1 | one hull | 10 / 10 | 87.928 ms | 3,308,716 B | 133.8505 / 264.805 ms* | 0.105 / 1.497 ms | 266 |
| 3 | frozen | 30 / 228 | 324.189 ms | 17,936,312 B | 2.823 / 546.828 ms* | 0.0835 / 1.920 ms | 287 |
| 3 | one hull | 30 / 30 | 287.456 ms | 9,855,904 B | 2.424 / 601.122 ms* | 1.625 / 1.948 ms | 270 |
| 10 | frozen | 100 / 760 | 1,034.082 ms | 59,947,176 B | 7.397 / 7.700 ms | 1.999 / 4.327 ms | 293 |
| 10 | one hull | 100 / 100 | 875.893 ms | 33,012,184 B | 5.980 / 7.356 ms | 0.969 / 1.310 ms | 384 |

`*` The 1/3-provider awake samples contain large process/monitor spikes and are
not useful performance acceptance evidence. The stable 10-provider sample shows
the expected shape-count benefit, but it cannot override failed collision
fidelity. `Performance.MEMORY_STATIC` is Godot heap, not process RSS/GPU memory.

## Decision

- Reject the candidate. One convex hull per assembly fills real cavities and
  changes contacts and settlement.
- Do not describe equal bounds/support as exact collision parity.
- Retain the compound 76-shape design unless a future reduction proves the
  actual union/contact surface, not only its convex envelope.
- No frozen runtime, production integration, source visuals, Git, GPU window or
  LIVE scene changed.

