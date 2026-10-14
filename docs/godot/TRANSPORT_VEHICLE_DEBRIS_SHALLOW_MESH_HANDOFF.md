# Transport vehicle debris shallow-mesh candidate

Status: **FUNCTIONALLY VERIFIED / PERFORMANCE REJECTED FOR NO-LAG GATE / DO NOT ADOPT**.

Frozen `transport_vehicle_debris.gd` SHA-256
`1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`
deep-duplicates each Mesh, including nested surface materials, and then replaces
every surface with another explicit deep material copy. This isolated candidate
changes only the Mesh shell to `duplicate(false)`; the existing explicit
per-surface `material.duplicate(true)` remains.

After surface replacement the candidate checks cached storage Resource property
names and rejects any other nested Mesh Resource that shallow duplication would
still share. Unknown imported shadow/nested Resource layouts therefore fail
closed instead of weakening private ownership.

## Correctness

Final actual city-hatch suite on Godot `4.7.2.stable.official.ed1daf0bf`:

- **83/83 PASS**, exit 0, process joined;
- 10 assemblies, 76 hulls, 142,948 vertices;
- 76 private Mesh Resources and 76 private StandardMaterial3D Resources from 29
  source material identities;
- every hull point byte array and tested convex support extremum equals frozen;
- collision nodes retain the same shapes, layers, masks and launch velocities;
- in-place source Mesh mutation does not change the private Mesh;
- in-place private Mesh mutation does not change the source Mesh;
- source/private material mutations are independent in both directions;
- cached collision points remain unchanged by later Mesh edits;
- inherited prewarm and launch reach READY and run through actual physics.

The inherited full physical suite also passed **264/264** on this shallow design,
including natural flight, ground collision, sleep and two-car/20-body stress.
That run preceded only the final caching of the fail-closed nested-Resource
property-name lookup; final candidate behavior and the guard itself are covered
by the 83-check suite.

## Whole configure performance

Final 20 alternating frozen/candidate pairs, isolated hidden headless CPU:

| Path | min | p50 | p95 | max |
|---|---:|---:|---:|---:|
| frozen configure | 101.913 ms | 107.5985 ms | 112.672 ms | 116.927 ms |
| shallow candidate | 97.875 ms | 100.745 ms | 107.220 ms | 111.784 ms |

Median improved by about 6.4% and p95 by about 4.8%. Prior qualified samples
showed the same modest median direction, but the complete configure still blocks
for about 101 ms. This does not meet the user no-lag requirement or a frame
budget.

Final isolated prewarm call p50/p95/max was 52/132/132 us candidate. Single
candidate launch was 583 us. These are not loaded-scene FPS measurements.

## Decision

- Do not replace the frozen provider with this candidate.
- Retain the package as evidence that redundant deep material traversal is only
  a minor part of the configure spike.
- Next experiment: transactional incremental configure across complete
  mesh/hull units, with no partial READY or launch and a target step p95 below
  8 ms. All 10 bodies, 76 meshes/materials/hulls and collision fidelity remain.
- No production runtime, content, physics rules, Git, GPU window or LIVE scene
  changed.
