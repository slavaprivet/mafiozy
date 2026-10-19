# Transport vehicle debris incremental prepare candidate

Status: **FUNCTIONALLY VERIFIED LOAD-TIME CANDIDATE / STEP GATE PASS / NOT PRODUCTION ADOPTED**.

This isolated candidate extends frozen `transport_vehicle_debris.gd` without
changing it. It replaces the monolithic configure call with a transaction that
prepares exactly one complete private Mesh, private surface materials, exact
convex point set and collision shape per `prepare_step()` call. The inherited
provider is published only after all 10 ordered assemblies and all 76 meshes
validate and commit together.

## API and state boundary

- `begin_configure(vehicle_root, debris_parent, ordered, owner = null,
  damage_revision = 0)` validates the complete ordered input, captures source
  hierarchy/pose/Mesh identity and starts a private transaction.
- `prepare_step(expected_damage_revision, max_meshes = 1)` accepts only a
  budget of one mesh. A wrong revision is non-mutating. Hierarchy, visibility,
  relative pose and Mesh identity are revalidated before every step and again
  at commit.
- Each mesh uses the source-relative transform captured at transaction start.
  Rigid motion of the whole vehicle between steps therefore cannot mix hulls
  from different world frames. A changed scale/shear bake basis fails closed.
- `preparation_receipt()` reports progress and always reports
  `partial_provider_exposed: false`.
- `cancel_preparation()` and `dispose()` free every partial template, collision
  node, shape, private Mesh and material. A failed boundary check atomically
  discards the whole transaction.
- `prewarm_step(budget, expected_damage_revision)` and
  `launch(motions, expected_damage_revision)` fail with
  `PREPARATION_PENDING` until commit, then require the exact committed revision.
  The ordinary `configure()` entry point fails with
  `incremental_begin_required` so callers cannot accidentally use the
  monolithic path through this candidate.

The transaction does not hide source assemblies, add bodies to the tree or
expose `_entries` while preparing. An explosion/crash request before READY must
remain pending in the future authoritative host; this proof component does not
queue, delay, authenticate or replay an event itself.

## Correctness

Actual Godot `4.7.2.stable.official.ed1daf0bf` city-hatch final runs passed
**200/200** and **201/201** with joined processes and clean shutdown:

- actual 10 assemblies, 76 hulls, 142,948 source vertices;
- 76 private Mesh resources and 76 private material resources from 29 source
  material identities;
- every convex point byte array and tested support extremum equals the frozen
  monolithic provider;
- identical body mass, collision layers/masks, material, hull count, prewarm
  and launch behavior;
- no partial provider publication before final commit;
- stale damage revision is non-mutating;
- a post-commit stale revision cannot prewarm or launch;
- two rigid vehicle translations/rotations during the 76-step transaction
  preserve every frozen hull byte and support value;
- a source relative-pose change aborts and frees all partial work;
- hidden-descendant rejection matches the frozen subtree behavior;
- explicit cancellation and disposal free partial work without RID/ObjectDB
  leak diagnostics;
- all ten launched bodies undergo actual gravity/ground collision and reach
  native sleep after 378 physics frames while remaining present.

## Isolated CPU measurements

Two final samples were taken only after process inventory showed no other
headless Godot process. The user's interactive Godot remained open, so these
are isolated helper measurements rather than fully idle-machine or loaded-game
frame-time evidence.

| Sample | frozen configure | begin | step p50 | step p95 | step max | candidate CPU sum | wall to configured |
|---|---:|---:|---:|---:|---:|---:|---:|
| final sample 1 | 107.536 ms | 0.724 ms | 1.9005 ms | 3.979 ms | 4.765 ms | 149.546 ms | 506.809 ms |
| final sample 2 | 115.437 ms | 0.558 ms | 1.941 ms | 3.791 ms | 4.990 ms | 153.417 ms | 506.764 ms |

The worst final-code step p95/max was 3.979/4.990 ms, under the requested 8 ms
experiment gate. Earlier code-equivalent scheduling samples reached
7.213/7.775 ms while no other headless Godot was detected. Total final-code CPU
increased by roughly 33–39% against the paired monolithic calls. Readiness takes
76 process frames and about 507 ms wall time. This trades one roughly
108–115 ms spike for bounded steps; it does not reduce total work.

The last isolated candidate prewarm p50/p95/max was 47.5/65/65 microseconds and
launch was 648 microseconds. No full-scene FPS, GPU, LIVE or frame-budget
acceptance was measured.

## Required integration work and limits

- `damage_revision` is supplied by the caller. The candidate cannot
  authenticate it. The future host must bind it to the actual vehicle lifetime
  and deformation revision, and prevent concurrent damage mutation during the
  load transaction. In-place Mesh edits that keep identity and reuse a forged
  revision are outside this proof.
- The authoritative event host must keep a crash/explosion pending until READY,
  then revalidate the same vehicle lifetime, event and current source state.
  This candidate grants no event, HP, fire, seat, vehicle or source authority.
- Loaded-scene scheduling must be measured with the actual city workload. A
  nominal one-mesh step may still exceed the available frame budget when other
  systems run; the observed 7.775 ms maximum leaves little room.
- The 507 ms load latency must occur during controlled vehicle preparation,
  never by delaying an already-authorized source explosion or removing debris.
- Frozen production runtime, content, collision fidelity, Git, GPU and LIVE
  scene were not changed.

Decision: retain as an isolated load-time candidate for parent replay and
loaded-scene scheduling evaluation. Do not adopt into production on these
headless measurements alone.
