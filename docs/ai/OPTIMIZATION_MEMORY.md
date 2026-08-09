# Mafiozi 3D optimization memory

Read this before adding or expanding a 3D feature in `world.html` or
`three_preview.js`. Performance work must preserve or improve visible quality.

## Non-negotiable quality contract

- Keep authored geometry, textures, lighting, day/night grading and real-time
  PCF soft shadows. Do not solve a slowdown by silently lowering resolution,
  texture size, anisotropy, model detail, view distance or effect quality.
- The server-backed player role, faction/family and business ownership remain
  authoritative. Preview flags must never replace live status in production.
- Prefer removing redundant CPU/GPU work. Any adaptive degradation requires an
  explicit product decision and a separate visual comparison.

## Checklist for every new feature

1. Run `git log -1` and compare `origin/main`; work on an isolated `codex/*`
   branch because the world is edited concurrently.
2. Record a representative baseline: FPS, `renderMs`, `renderMaxMs`,
   `maxFrameGapMs`, `maxFrameWorkMs`, draw calls, triangles, GPU geometries and
   textures. Keep idle/warmup work separate from animation-frame work.
3. Search for an existing pool, material, geometry, texture, bridge field or
   streaming queue before creating another system.
4. Implement the feature, then test the actual transition that makes it first
   visible. First-use shader compilation and GPU upload are common freeze causes.
5. Run `node --check three_preview.js`, `git diff --check`, a local browser
   preview, a visual shadow/light check and a Three.js error-log check.
6. Recheck `origin/main` immediately before committing or publishing.

## Resource rules

- Never create identical `Geometry`, immutable `Material`, `CanvasTexture` or
  high-resolution canvas assets per entity/slot. Cache by real construction
  parameters and share them. Keep only mutable state (paint, braking lamps,
  damage values, per-instance uniforms) private.
- Preserve texture repetition through geometry UVs instead of cloning a texture
  only to change `repeat`.
- Use bounded pools for bullets, decals, particles, vehicle damage, NPC labels
  and temporary effects. Reuse slots; remove unbounded arrays, intervals and DOM
  listeners. Disposal must not destroy a resource still shared by another mesh.
- Avoid allocations and scene traversal in per-frame paths. Cache vectors,
  matrices, signatures and spatial lookup results.

## Static world and shadows

- Spatially batch immutable opaque detail by material and chunk. Keep animated,
  selectable, transparent, skinned, morphing and gameplay-linked objects out of
  static batches.
- The colour pass must preserve all authored materials. A separate position-only
  spatial shadow proxy may combine opaque static casters because the directional
  depth pass only needs the exact silhouette.
- Keep chunks small enough for useful camera and shadow-frustum culling. Seal
  bounds after instancing or merging.
- Do not mark every decorative mesh as a shadow caster. Make the decision from
  visible contribution, but never remove an existing visible shadow without a
  before/after comparison.

## Streaming and warmup

- Build distant sectors incrementally and yield between bounded slices. Never
  compile or upload a whole authored district in one gameplay frame.
- Warm the exact final shader configuration: preserve nested visibility,
  material flags, light counts, layers and `castShadow`. A mismatched warmup
  merely moves compilation back into the first visible frame.
- Warm GPU buffers with a tiny offscreen target, one source per idle slice. Do
  not recompute full shadow maps inside each 2x2 upload slice.
- Reveal only after compile/upload work is ready; batch shadow invalidation so
  streamed roots do not trigger repeated full shadow passes.

## Stateful input and gameplay transitions

- Treat prison, death, arrest, vehicle/interior entry, overlays and app
  visibility changes as input-cancellation boundaries. Clear held fire, stale
  pointer/touch IDs and right-stick aim when controls become unavailable.
- Mobile WebViews may omit `pointerup`, `pointercancel` or `keyup` while an
  overlay or server teleport is taking control. Never let a hidden control keep
  an automatic-fire loop alive or resume a ghost burst after release.
- Add transition-focused preview checks. A steady-state FPS test will not catch
  a retained input flag, first-shot warmup or duplicate response spawned only
  on the first frame after a state change.
- Keep the number and kinds of visible Three.js lights stable across gameplay
  state changes. Switching a zero-intensity light's colour/intensity is cheap;
  adding a newly visible `PointLight` can recompile every affected material.
  Pre-create one light slot when only one alarm colour is emitted at a time.
- Prime `InstancedMesh.instanceColor` before shader warmup whenever live code
  later calls `setColorAt`. Creating that attribute on the first projectile or
  decal changes shader defines and moves compilation back into gameplay.

## Proximity prompts and DOM overlays

- Do not scan the complete NPC pool every render frame. Cache the nearest-NPC
  result for roughly 100 ms, compare squared distances inside the scan and run
  one forced fresh scan only when the player presses the interaction key.
- Never mix per-frame style writes with `getBoundingClientRect`, `offsetWidth`
  or `offsetHeight`. Cache stage/canvas bounds until resize and measure prompt
  dimensions only when its content or target changes.
- Keep 3D marker animation and projection at render cadence; throttling the
  search and caching layout must not make the visible ring or label judder.
- Preview fixtures must anchor actors to a fixed world position once. Rewriting
  an NPC position from the player's current coordinates on every bridge sample
  accidentally creates a follower and invalidates proximity/performance tests.

## Existing measured patterns (2026-08-10)

- Original junkyard streaming produced roughly a 2.7 second freeze.
- Spatial batching retained full geometry: prison `442 -> 52`, junkyard
  `97 -> 23` visual batches.
- Shared facade textures plus baked UV repetition removed per-building texture
  clones without changing the facade image.
- The fixed vehicle render pool reused 1,396 duplicate geometries and retained
  131 unique shapes across 18 slots.
- After those changes, a representative desktop preview produced steady render
  samples around p50 18.5 ms / p95 25.2 ms and 21-23 FPS at the existing native
  quality policy. Treat these as historical evidence, not universal thresholds.

## Diagnostics interpretation

- `renderMaxProgramGrowth` changing during a long frame usually means a shader
  variant escaped warmup.
- `gpuWarmupSliceMaxMs` measures idle upload stalls that `maxFrameWorkMs` misses.
- `maxFrameGapMs` is the player-visible pause and includes work outside rAF.
- A long render with no program growth points to actual draw, shadow-map, upload
  or synchronization cost; profile that path instead of changing shader warmup.

## Publishing

The project deploys through its GitHub API upload workflow, not direct
`git push`. Never publish over a newer `main`; reconcile the exact fresh commit,
validate again and publish only with explicit authorization.
