# NPC pose continuity gap — 12 September 2026

Coordinator-authorized narrow fix in `npc_population.mjs`; new
`test_npc_pose_continuity.mjs`. Actor/Artist animation files, simulation/LOD
cadence, culling distances, source ownership and population size are unchanged.

## Reproduced cause

The prior real-clock cadence fix correctly handled 160 ms frames. However,
`poseElapsed` is bounded to 250 ms and `gap > stepDt + .001 && gap > .25` treated
every continuously visible 300–600 ms frame as an offscreen absence. That called
`saveSurfaceState`/`restoreSurfaceState`, rebuilding persistent surface state for
every visible actor on every frame.

The red actual-GLB regression observed 12 saves and restores for EACH near/mid/far
actor during 12 continuous updates at both 300 ms and 600 ms. At 160 ms it correctly
observed zero. A return from true culling then kept restoring on subsequent slow
visible frames; source-omission reentry could restore twice in one tick.

## Change and host contract

- Each record has `poseInterrupted`, initially false. Actual hidden/carried/
  evacuated poses mark it. Successful full pose clears it. The former gap/elapsed
  test now additionally requires this marker; a long continuously visible frame
  alone does not justify serializing persistent state.
- Source-omission reentry retains its existing explicit restoration and clears
  the marker afterward, avoiding a second redundant pose restoration.
- New public `population.markPoseInterrupted()` lets the host mark a REAL pause
  when no `update()` calls occur (page hidden or explicit render-only QA hold).
  It marks existing records only, with no serialization, pose, visibility, source
  or clock mutation. Calls are idempotent; after disposal it does nothing.
- Root owns the corresponding `walk_preview` visibility-change / QA-start hooks.
  Call on actual `document.hidden`, and on a validated loaded QA hold start, not
  on an arbitrary elapsed-time threshold or every release-controls call.

Absolute presentation/source clocks, death/reaction ages and confirmed receipts
remain intact. Existing actor and surface integration limits of 0.25 seconds are
NOT changed. In particular `wet_clothing` drying consumes this bounded integration
dt, while true offscreen restoration fast-forwards saved wetness by elapsed time.
Removing false restore/quantization is not a claim that every surface effect now
integrates full wall time at very low FPS. No Artist-owned time-policy rewrite.

## Verification

`node assets/maps/city_rebuild_v1/test_npc_pose_continuity.mjs`: **8/8 PASS**.

- Near/mid/far at 160/300/600 ms: zero saves/restores and unchanged 12 pose updates
  over 12 observed frames. Small ordinary LOD skip followed by 600 ms also has no
  false restore.
- True offscreen return restores exactly once, then remains continuous.
- Source omission/reentry preserves one explicit restore, not two.
- Explicit host interruption, five seconds with no population updates, then
  resume: exactly one restore per actor; later 600 ms frames add none. Marking
  alone changes neither coordinates, visibility, time nor save/restore counts.
- Real clothing gets wet and dries; confirmed bruise/death receipts, bruises,
  death kind and exact absolute reaction age survive slow frames and true culling.

Existing `test_npc_pose_clock.mjs` PASS. Existing `test_npc_population.mjs` **21/21
PASS**, including actual bullet wound persistence, source clock mapping, source
death/respawn, cache eviction/reentry, gait, interpolation and disposal.

## Short CPU A/B profile

Reproduce with `node assets/maps/city_rebuild_v1/test_npc_pose_continuity.mjs --benchmark`.
Node v26.1.0; six actual wet-clothed GLB actors continuously visible at near/mid/far
distances. Eight warm-up updates and 24 measured updates per row; alternating
before/after order. Timed `population.update` includes opt-in CPU instrumentation,
but excludes model loading and source `sync`. Baseline is the current production
module loaded in memory with only the old gap condition restored, preserving all
other concurrent changes. No production files are swapped for the measurement.

| Frame interval | Before CPU p50 / p95 | After CPU p50 / p95 | Restore CPU p50 before → after | Restore calls across 24 updates |
| --- | ---: | ---: | ---: | ---: |
| 300 ms | 29.7737 / 31.0248 ms | 7.0219 / 7.1750 ms | 22.6366 → 0 ms | 144 → 0 |
| 600 ms | 29.6446 / 30.6533 ms | 6.7935 / 6.9297 ms | 22.7594 → 0 ms | 144 → 0 |

This is a short scoped CPU workload, not full-game frame timing or a percentage
FPS claim. Wet/dry content and other host activity can change timings.
**Производительность общей сцены не проверена.** No browser, GPU scene, GPU timing,
draw-call or triangle measurement was run by this subtask. Root reports browser
access currently blocked; final LIVE acceptance remains separate.
