# Populated game optimization — 12 September 2026

Owner: architect shops / current user game-performance request. Shared dirty
workspace; changes by other owners are not included in this handoff's claims.

## Implemented scope

- NPC clone skeleton sharing: `npc_skeleton_sharing.mjs` and Artist16-approved
  narrow `npc_actor.mjs` integration. A configured male/female NPC's four
  SkinnedMesh parts now share one identical bone palette within that actor.
  Different NPCs and template bones remain isolated; mesh bindings/geometry/
  materials are unchanged. Exact inverse-array ownership and ordered bone
  identity are required; uploaded/custom/external skeletons opt out.
  21 tests PASS, 108008 exact world-vertex comparisons across eight poses,
  28672 matrix values; independent texture disposal checked. Renderer-style CPU
  p50 in main's run: male .1315→.0335ms, female .1305→.0332ms. Bone textures
  4→1 per configured NPC; this is not a 75% reduction of total GPU memory.
  Existing actor/appearance-resource/pose-clock/pose-continuity tests PASS.
  Applies to newly created actors; no live actor migration. Full-scene FPS is
  unmeasured: coordinator reports concurrent user-owned demo tabs, which must
  not be closed for exclusive profiling. Shadow candidate remains opt-in.

- Water/car matrix work: see `VEHICLE_WATER_MATRIX_PERF_HANDOFF_20260912.md`.
  Exact authored engine geometry, flooding, sinking and exits remain unchanged.
- Vehicle detail batching: identical-material pairs and precisely owned fixed
  wheel arch lips, separately switchable from the existing body/door batches.
  No wheel simplification, material deduplication, population reduction or NPC
  simulation cadence change. Agent's dedicated detail handoff contains tests
  and CPU/structural measurements (`VEHICLE_DETAIL_BATCHES_HANDOFF.md`). Main
  passed renderer `WEBGL_multi_draw` capability through fleet and traffic
  creation; unsupported devices allocate no new detail batches. Tests verify
  both caller paths. Measured savings: 108 main + 96 shadow calls per 12 models;
  extra helper CPU p50 about 0.25ms for all 12, pending driver/GPU acceptance.
- `render_freeze_qa.mjs` and narrow `walk_preview.mjs` integration: local-only,
  explicit `perfqa=1`, no identity/auth query keys. Fixes a loaded 3D view for
  render-only A/B; the source world continues. It is NOT a gameplay pause and
  NOT a full-game FPS measurement. Pending actor models prevent starting a hold.
  Escape, 120-second timeout, projection change, startup loss and page unload
  release the hold. Vehicle detail optimization is restored on release.
  Held input cannot queue gameplay movement, firing or weapon selection.

## Measurement controls

Use one populated integrated world preview and one GPU workload at a time.
Wait for zero model loads, then hold the actual camera. The local vehicle button
switches only the new detail groups; the older body/door batching stays enabled.
Each switch resets timing samples. Record at least one filled 120-frame window
per representation, exact camera, resolution/pixel ratio, model counts, draws,
triangles and renderer timing. Preserve identical scene and shadow state.
Report these windows as render-only, separately from normal gameplay timing.
Return to optimized mode and release the hold before handing back the game.

## Current verification boundary

CPU/geometry and lifecycle tests pass; controlled LIVE renderer A/B remains open.
Browser access recovered. A temporary populated scene exposed traffic paint
invalidating render batches; this is now fixed and coordinator's fresh user demo
confirmed 2583 active / 2583 total members with zero fallback. See
`TRAFFIC_PAINT_BATCHING_HANDOFF_20260912.md`. The attempted shadow A/B was invalid
because the 15-second placement refresh cancelled its hold; the explicit-hold
refresh guard is fixed and tested. This owner's temporary QA was actually closed.
Hidden IAB tabs continue rendering, so hiding is not sufficient GPU isolation.
The next controlled shadow A/B requires the coordinated serial GPU slot.
No claim that all lag is fixed. Prior populated LIVE from another owner still
showed high renderer cost, and is not a controlled before/after for these edits.

With the coordinator's explicit handoff, the NPC slow-frame restore issue was
also fixed: `poseElapsed` caps at 0.25 seconds, while old restore detection
compared it with a wall-clock gap. A continuously visible actor on a >250ms
frame was therefore mistaken for an offscreen restore. An explicit interruption
flag now distinguishes hidden poses from continuous slow frames. Source reentry
does not restore twice. Hidden-page and local QA holds mark interruptions through
`population.markPoseInterrupted()`; returning actors restore exactly once.
Actor integration caps, source clocks, wounds/death and simulation cadence are
unchanged. See `NPC_POSE_CONTINUITY_HANDOFF_20260912.md` for red/green evidence
and a six-actor CPU-only comparison (roughly 30ms to 7ms in the reproduced
slow-frame scenario, NOT full-game FPS).

## Rejected optimizations

Full wheel rebuilding/material equivalence, hidden-source traversal suppression,
and static leaf matrix freezing were investigated but not shipped: respectively
too broad, roughly 1ms CPU benefit with callback/restoration risk, and roughly
0.1ms CPU benefit with stale-transform risk. Content and visual quality preserved.

Further read-only CPU audits after user requested more optimization:
- Vehicle batching update: 12 real models / 1195 members / 231 batches,
  about 1.11ms p50 / 1.34ms p95. Direct material comparison was slower than the
  current stamp comparison. Fused ancestry walks passed 9560 matrix/visibility
  comparisons but produced only noise-scale savings and slightly worse p95.
  Neither candidate was applied.
- Static batches: 31 actual buildings with generated entries / 78 batches /
  6573 members; actual Three callbacks, 320 interleaved CPU samples after warmup.
  Center shadow + two main callbacks cost 1.379/1.719ms p50/p95. Disabling sorting
  cost .994/1.283ms but changed order in 28/43 visible batches; coplanar and
  overdraw parity was not established. Removing a duplicate callback altogether
  has only a .407ms theoretical ceiling before cache invalidation cost.
  Both approaches rejected. These are CPU audits, not full-game FPS results.
