# Melee triangle hierarchy: exact candidate search, gameplay performance HOLD

The new `godot/mafiozi_walk/scripts/combat/melee_triangle_index.gd` is a pure
current-pose candidate index. It does not install combat, collect meshes,
choose eligible actors, issue hit receipts, change HP, test walls or apply J.
The original source and root-owned triangle kernel are unchanged.

Frozen index SHA-256: `b39dead1b1880236d49983db70841fac7402e052801d98a94eb6d3a550c85b9b`.
Kernel dependency SHA-256: `b8e651faa13affa83436bb59fe169c1b23d6dc0344126f78dbb6deca5586ac9b`.
Source `assets/maps/city_rebuild_v1/npc_melee_contact.mjs` SHA-256:
`7897c26dbfd541e0170bea6cacb7924d6ac20675782103be8da532d31f6e001c`.

## Source ordering and boundary

Source lines 28-35 cache topology and refresh all current skinned vertices and
triangle bounds per pose revision. Lines 48-58 filter actors, visible meshes,
nearby eligible limb sweeps, then visit actor / mesh traversal / triangle /
limb order. Lines 60-66 select only strictly smaller score after both wall
occlusion tests. Lines 72-73 capture the final winner's anchor only.

This index takes ONE eligible actor's source-ordered flattened visible mesh
triangle stream, with the already admitted source `nearAttacks` in their
original order. The caller preserves a triangle-to-original mesh/face lookup.
One tree may contain several meshes only when that source traversal order is
preserved. For several actors, the caller retains source actor ordering and
compares exact scores using strict `<`. Eligibility, visibility, topology
changes, source identities, mesh/skin/life/pose versions, zone classification,
anchor capture and damage authority remain outside this component. No nearest
proxy shape or straight-through-wall fallback is supplied.

Best-first traversal is internal only. Equal exact scores select the lower
`triangle_index`, then `contact_index`, preserving source winner semantics.
The precise kernel uses unchanged source closest-point formulas; native
Vector3 positions are the boundary, float64 intermediates are retained.

## API and lifetime

- `configure(indices: PackedInt32Array, vertices: PackedVector3Array,
  pose_revision: int)`: once, during loading. Validates/copies topology and
  vertices, constructs a centroid median tree, returns `READY`. Index stream
  length must be divisible by three. At most 65,536 vertices / 131,072 triangles.
  Finite world coordinates are bounded to absolute 10,000,000, matching kernel.
- `begin_refit(vertices, pose_revision)`: copies a current pose snapshot,
  immediately invalidates previous query/skin readiness, returns `PENDING` with
  `refit_id`. Revision must exceed the last committed revision; vertex count
  and topology must match. A new refit supersedes unfinished work.
- `advance_refit(refit_id, max_vertices=256, max_nodes=128,
  budget_usec=1000)`: validates bounded vertices, then refits bounds bottom-up.
  Returns `PENDING`, `READY`, or explicit `ERROR`. Nothing can query half-updated
  bounds. `cancel_refit(refit_id)` leaves the index unavailable until a fresh
  complete refit. Invalid input also keeps old geometry unavailable.
- `refit(vertices, pose_revision)`: synchronous convenience for loading/tests;
  live schedulers should use the two-stage interface.
- `begin_query(contacts, pose_revision, accept_candidate=Callable())`:
  1-4 copied `{from: Vector3, to: Vector3, radius: number}` entries; radius must
  be finite, positive, at most .5m. Returns `PENDING` and a new `query_id`.
- `advance_query(query_id, max_nodes=64, max_kernel_calls=16,
  budget_usec=1000)`: returns `PENDING` or `COMPLETE`, never a fabricated miss
  when a budget expires. COMPLETE includes hit, source triangle/contact index,
  unchanged kernel candidate, pose revision, work counters, and filter_applied.
- `cancel_query(query_id)` and terminal `dispose()` invalidate work and release
  callback references. Invalid or stale tokens fail explicitly.

Main thread only. Reentry rejects and invalidates an in-flight callback result.
All geometry/query arrays are private copies and bounded by the above maxima;
no Node/Skeleton/actor is retained. A filter callable exists only until query
completion, cancellation, replacement or disposal. Freed/queued filter owners
are rejected. A filter must return an explicit bool; a null/fault reply is an
error, never permission. These local guards are not a network trust boundary.

The optional filter is a synchronous **pure geometric snapshot predicate**:
`accept_candidate({triangle_index, contact_index, candidate, pose_revision})`.
The candidate is a deep copy. Rejecting the current geometric winner continues
searching, so a nearer blocked face cannot hide a farther unblocked candidate.
Best-first evaluation changes callback invocation order/count; callbacks may
not mutate gameplay or rely on source traversal side effects. To preserve full
source contact, the caller must perform both actual source wall tests against
a frozen matching obstacle snapshot. Omitted filter yields
`filter_applied: false`, a geometry candidate only, never a hit receipt.

Caller owns the revision clock. Every pose/world-transform/visibility/topology
change must invalidate or replace work before gameplay consumption. An index
cannot discover external skeleton mutation. A multi-frame result may only be
used if the caller verifies the same current pose, actor life and obstacle
revision; otherwise cancel/refit. Repeated invalidation of an animated target
can starve search: retaining stale skin to avoid this is prohibited.

Clock checks are cooperative, not a hard realtime guarantee. Refit checks at
most every 16 vertex validations / 8 nodes; hard requested work counts remain
exact. Query checks before each node/triangle operation. A single kernel call,
filter call, allocation or OS preemption can overrun elapsed-time budget.
Filter cost and total number of advances per frame are caller-budgeted.

## Conservative pruning argument

For every possible source hit, let L be the selected limb-line point and P the
selected triangle point. The source score is |from-L|² + |L-P|². A node's min/max
coordinates contain every posed vertex and triangle. Its radius-expanded slabs
conservatively bound eligible L; expansion includes the kernel distance epsilon.
The ray endpoint interval additionally includes source length² + 1e-10.

Within that interval, the index minimizes the piecewise quadratic
|from-L(t)|² + distance(L(t), nodeBox)². Since P belongs to the box, this is a
lower bound without assuming pair orthogonality, regular triangles or a
nonparallel edge. Roundoff slack scales conservatively with world coordinates.
Pruning uses strict `bound > current_score`, so equal-score earlier source
indices remain eligible. Separate stored min/max avoid float32 AABB size
subtraction making a bound smaller than its actual extreme.

At a leaf, the unchanged source triangle/sweep AABB filter runs first. A cheap
additional bound uses s = distance(from, triangleBox), r = sqrt(radius²+1e-10):
score >= s²/2 when s <= 2r, otherwise score >= (s-r)²+r². This follows from
|from-P| <= |from-L|+|L-P| and hit distance <= r. Only the remaining triangles
invoke the already validated kernel `_sample`; contacts are cached float64 and
current vertices have completed validation. Neither kernel formulas nor source
hit epsilon were altered.

## Verification and measured limit

Godot 4.7.2 headless, no GPU: 2191 checks PASS. Includes all unchanged 288
original full JS/Three180/SkinnedMesh oracle rows, maximum source surface error
1.012 micrometres; randomized multi-triangle/four-limb exhaustive source-order
comparison; skinny, parallel, stationary and very short ray cases; exact ties;
blocked-first candidate; pending cancellation/refit, malformed geometry,
nonfinite pose, work caps, stale/negative tokens, reentry and callback lifetime.
The oracle fixture/exporter are the existing root-owned files; no source oracle
or tolerance was rewritten for this hierarchy.

`test_melee_triangle_index_cost.gd` loads the actual native hero, skins 8,338
vertices and uses all 13,034 source-order mesh triangles (8,191 tree nodes).
Eight scripted current-pose sweeps, 16 warmups plus 48 measured samples each.
Every iteration alternates the cheapest cached AABB scan plus source-order
kernel baseline with indexed query on exactly the same geometry, radius and
frozen kernel. Every winner and entire candidate dictionary must match exactly.
Baseline column below excludes the cached AABB scan (roughly .4ms p50);
indexed column includes begin/advance until completion, including heap/bounds.

| Sweep / radius m | Baseline / indexed kernel calls | Baseline p50 / p95 / max ms | Index p50 / p95 / max ms |
| --- | ---: | ---: | ---: |
| head / 0.10 | 770 / 215 | 14.047 / 16.631 / 18.291 | 6.766 / 8.270 / 9.942 |
| head / 0.14 | 1483 / 375 | 26.727 / 36.996 / 42.458 | 11.661 / 13.692 / 13.845 |
| chest / 0.10 | 431 / 74 | 7.739 / 8.419 / 9.412 | 2.540 / 2.911 / 3.802 |
| chest / 0.14 | 632 / 131 | 11.684 / 17.263 / 18.349 | 4.318 / 4.946 / 7.324 |
| forearm_l / 0.10 | 228 / 114 | 4.402 / 5.506 / 8.080 | 3.989 / 6.526 / 6.754 |
| forearm_l / 0.14 | 347 / 210 | 6.495 / 7.855 / 12.506 | 6.568 / 8.336 / 10.037 |
| shin_r / 0.10 | 72 / 24 | 1.447 / 1.527 / 1.648 | 0.957 / 1.080 / 1.142 |
| shin_r / 0.14 | 132 / 67 | 2.548 / 4.102 / 4.854 | 2.589 / 4.285 / 5.476 |

One-time topology build: 380.144ms. Fixture skin/extraction plus test linear
bounds setup: 13.174ms (not a standalone production skin measurement).
Full refit alone p50/p95/max: 6.717 / 9.605 / 12.425ms, excluding upstream skin deformation.
Bounded refit total p50/p95/max: 6.877 / 11.836 / 13.112ms; 1ms-requested slice p50/p95/max:
1.007 / 1.019 / 1.700ms. Query slices max: 1.055ms. The observed occasional scheduler
outlier is retained; no strict 1ms wall-time promise is made.

**HOLD for current-frame production melee.** Head query improves materially,
but small forearm/shin cases break even and complete current-pose processing
still exceeds a 144FPS frame before upstream skin/occlusion/authority work.
PENDING prevents a frame spike only if work is actually spread; that does not
make the latency or stale-pose problem disappear. This exact bounded index is
reference infrastructure, not approval to wire an animated full-mesh scan into
every combat frame. A native compiled implementation of the same skin/refit /
query math or a proved source-compatible cheaper posed geometry path is still
required. Do not substitute capsules, drop faces, stretch time windows, or use
old skin to claim success. Overall loaded scene FPS is not tested here.

Evidence: `outputs/melee_triangle_index/report.json`, `cost.json`, logs.
`cost_initial.json` retains the first hierarchy run before local optimizations;
final paired baseline/index numbers above isolate current-kernel behavior.

From repository root, using the installed Godot console executable:

```powershell
& $Godot --headless --path godot/mafiozi_walk --script res://scripts/tests/test_melee_triangle_index.gd
& $Godot --headless --path godot/mafiozi_walk --script res://scripts/tests/test_melee_triangle_index_cost.gd
```

No main/player/NPC/source/kernel files, running preview or Git state were edited
by this component task. Root remains the integration owner.
