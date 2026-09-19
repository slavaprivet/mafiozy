# Controlled renderer subsystem isolation — 20 September 2026

Status: diagnostic implementation and CPU lifecycle tests ready. **LIVE pending**
the sole game owner Coordinator18. Not an FPS optimization or a lag-resolution claim.

Add `isolationqa=1` to the existing local `perfqa=1` URL. Auth/identity query
parameters reject this diagnostic. Open debug controls with Ctrl+Shift+F9, hold
the loaded scene using the existing render-freeze button, choose a subsystem,
then press `Проверить выбранную подсистему`. One experiment per hold is recommended.
Do not change other QA switches, viewport or camera during a run.

Each experiment automatically takes baseline-before, variant, baseline-after.
Each phase discards 45 warm-up frames then captures 121 frames (120 interval
samples in the actual probe). Detailed per-draw profiling is disabled equally in
all three phases and restored afterwards. GPU timer mode is unchanged. Source
world simulation CONTINUES; this identifies rendering costs, not AI CPU cost or
gameplay FPS. Outer renderer/matrix/shadow/GPU timing remains active.

DOM `body.dataset.renderIsolation` contains phase progress, last result and up to
14 completed results. Each phase includes the actual probe snapshot, canvas size,
render timings, GPU samples and full `frameDraws` counts (main plus shadow).
Do not use legacy `draws` as a total: Three resets those counters after shadows.

## Experiments and exact scope

- `shadows`: temporary shadowMap.enabled=false; removes drawing AND sampling.
- `residents`: all rendered NPC actor roots, including police and bosses. Their
  source AI continues; standalone shot effects are not included.
- `vehicles`: fleet plus source traffic actor roots and their owned batches.
  Separate showcase cars/crash debris are not included.
- `interiors`: furnishing pools only, including their global static render
  batches. Explicit batch metadata identifies the dedicated interior-instance
  lane. Exterior and architectural floors/walls/doors are not hidden. This must
  NOT be described as disabling all interiors.
- `pointlights`: hide actual PointLight nodes during rendering, removing shader
  light slots rather than only setting intensity to zero. Other light types stay.
- `water`: water-surface meshes with actual native/landscape/surface markers;
  particles and engine steam are not included.
- `resolution`: half the original pixel ratio (one quarter framebuffer pixels),
  unchanged camera projection and shadow texture dimensions.

Visibility/shadow state changes last only for the synchronous draw and restore
in finally. Resolution restores on completion/cancel/error/pagehide/dispose/hold
exit. Original false visibility and prior profiling state are preserved. Camera,
canvas dimensions, profiler mode, GPU timer mode and target membership changes
invalidate a run; baseline-before/after full draw totals must match. The existing
hold has a 120s limit; the experiment additionally aborts at 110s. Incomplete runs
are not retained as completed measurements.

The frame and GPU effects of groups overlap; never add all savings. Compare
variant against BOTH baselines and repeat any pair with substantial baseline
timing drift. New shader variants are compiled during warm-up; inspect errors
and sample counts before accepting a run. Measurements do not alter saved quality,
simulation counts, collisions, materials, geometry or server ownership.

## Verification

- `test_walk_performance_probe.mjs`: existing actual-counter/multi-pass/GPU/probe
  mode tests PASS after adding immediate snapshot() access.
- `test_render_freeze_qa.mjs`: 30/30 PASS, existing gameplay source/health/NPC
  early-hold hooks preserved.
- `test_render_isolation_qa.mjs`: 24/24 lifecycle/mode/error/restoration tests PASS,
  including scene membership/resize/profiler guards and blocking other QA controls.
- `test_render_isolation_targets.mjs`: 3 actual Three/factory cases PASS,
  furniture/global batches vs exterior/floor separation, threshold fallback and
  no-BatchedMesh fallback. No browser/GPU was used in these tests.

Coordinator18 owns the single running game and schedules the reload and CPU/GPU
quiet window. This task has zero game tabs. No LIVE numbers are invented here.
