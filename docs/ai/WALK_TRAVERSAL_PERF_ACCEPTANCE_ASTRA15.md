# Traversal candidate CPU/allocation acceptance — 23 September 2026

Pinned output candidate: `walk_preview.mjs`
`67F91FC1AB31BD03F428539EA21572D8605A652B38DB8A70861B5B925D490299`.
No production file, browser tab or GPU workload was changed for this review.

Run the isolated acceptance with exposed GC:

```powershell
node --expose-gc outputs/benchmark_walk_traversal_perf_acceptance23.mjs
```

The helper optimization was rerun in three clean Node processes with identical
inputs. Median results:

| CPU path | Before p50 / p95 | Candidate p50 / p95 | Scope |
|---|---:|---:|---|
| Flat clear player step | 0.818 / 1.087 µs | 0.418 / 0.673 µs | 80,000 calls; old footprint path versus pooled `playerRoute.routeInto` |
| Stable vehicle surface | 37.0 / 44.4 µs | 29.85 / 32.63 µs | 10,000 updates of the same 40 indexed parked vehicles; before is the frozen pre-pooling run |
| Male full ladder pose | base about 13–25 µs p50 | 180 µs p50 | Actual male GLB, `hero.update + orchestrator + applicator`; inherited reach math retained |
| Female full ladder pose | base about 15–25 µs p50 | 175 µs p50 | Actual female GLB; inherited reach math retained |

The pooled route cut both median and p95. The vehicle update also improved.
These CPU numbers do not prove full-city FPS.

## Allocation verdict

**Helper package: GO. Integrated 67F91 candidate: HOLD until rebuilt.**

`pedestrian_surface_passability` and `pedestrian_player_route_adapter` now
offer explicit caller-owned workspace/output APIs. The compatibility `route`
methods still return independent results; the host hot path must use
`routeInto`. The metadata latch has corresponding `updateInto/sampleInto`
methods. Separate route workspaces were interleaved in the tests to guard
reentrancy.

- Player route retained heap was 464–472 bytes after 80,000 pooled calls in
  each clean run. `Object.entries`, `Object.fromEntries`, hot spreads and
  per-route query closures are absent.
- Vehicle-surface peak heap signal fell from about 18.7 MB to 4.14–4.68 MB
  over 10,000 updates. Retained heap was 13–23 KB. The update reuses its
  active/record arrays, generation marks, state/water fallbacks and direct
  hood/trunk checks.
- The old 67F91 host still creates its vehicle spread and pose envelope. A14's
  rebuild must use a stable vehicle actor array, stable pose input and the new
  `routeInto` API before the integrated verdict can become GO.
- The applicator scratch is pooled. Existing `hero_walk` reach/rotation
  helpers still allocate and need a separate owner slot; their actual male and
  female GLB cost remains reported above.

V8 may eliminate some short-lived objects, so these are source-level findings
and heap churn signals, not an exact allocation counter. They are enough to
reject a zero-allocation claim.

Required output-only host wiring:

1. Create one player adapter workspace and output, then call
   `playerRoute.routeInto(result,input,workspace)` for each frame.
2. Replace the host vehicle spread with a reusable array cleared and filled by
   indexed pushes.
3. Preallocate one host pose input with stable nested `blocked`, `jump`,
   `slope`, `weapon`, traversal and direction records. Mutate fields before
   `orchestrator.update`.
4. A separate `hero_walk.mjs` owner slot is still required to pool
   `rotateAdd/worldPosition/reachFoot/pointBone/reachPalm` scratch objects.

Behavior and visual tests must be rerun after pooling. Do not weaken the
current endpoint/storey/zero-distance or skin continuity gates.

## One-tab LIVE A-B-A readout

Use the existing game tab only. Add `perfqa=1&traversalqa=1` to its URL, keep
the same resolution/settings/population, and use **QA: центральный проход**.
For each A1/B/A2 build, reload that same tab, wait for the city to settle, then
run this in its console immediately before **QA: пройти 3 с**:

```js
const state = window.MafioziBuildingCameraIndex.stats();
window.MafioziBuildingCameraIndex.setEnabled(state.enabled); // resets samples without changing the mode
setTimeout(() => {
  const p = JSON.parse(document.body.dataset.walkPerformance || '{}');
  const rows = JSON.parse(sessionStorage.getItem('traversal-aba') || '[]');
  rows.push({
    label: prompt('A1, B or A2'),
    samples: p.timings?.frame?.samples,
    frameP50: p.timings?.frame?.p50,
    frameP95: p.timings?.frame?.p95,
    intervalP50: p.timings?.interval?.p50,
    intervalP95: p.timings?.interval?.p95,
    calls: p.draws,
    triangles: p.triangles,
    frameDraws: p.frameDraws,
    playerStage: p.timings?.heroCombat,
    surfaceStage: p.timings?.heroSurface
  });
  sessionStorage.setItem('traversal-aba', JSON.stringify(rows));
  console.table(rows);
}, 3300);
```

Click **QA: пройти 3 с** immediately after starting the snippet. Save A1 on
the current baseline, B after candidate integration, and A2 after the exact
authorized baseline restoration. `sessionStorage` preserves the rows across
reloads in the same tab. Accept only if B has no material frame p50/p95
regression outside A1↔A2 variance, calls/triangles remain unchanged for the
same view, and movement/poses remain correct. This readout intentionally does
not open another GPU tab.
