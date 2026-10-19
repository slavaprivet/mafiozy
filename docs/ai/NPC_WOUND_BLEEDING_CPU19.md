# Wound bleeding CPU comparison — 20 September 2026

Run: `node assets/maps/city_rebuild_v1/test_wound_bleeding_cpu19.mjs`.

This task adds only the benchmark and this document. It does not modify production code. The parent confirmed the existing-tab LIVE scenario separately: pistol damage 60 → 36, one attached wound, drops increasing 1 → 11 → 16 then expiring, visible ground marks.

## Comparable setup

32 actual GLB actors, alternating male/female: 16 moving wounded actors, each with four actual chest contacts, and 16 unwounded idle actors. Same positions, deterministic motion, dt 1/60 and inputs. Four fresh processes in baseline/current/current/baseline order; 120 warmup frames and 240 measured frames per process. Time covers all 32 `actor.update` calls, including skeleton poses, persistent wound geometry and particle-instance updates. Asset loading, cloning and initial hit reception are outside measured frames. Peak particle count includes warmup and its initial impact bursts.

The old emitter is taken from immutable revision `7370157`, the last surface version preceding blood commit `527e9c0`. A test load hook removes only the new bleeding integration and restores its old 10/18 emitter/burst behavior in memory. All other actor/death code is current and identical.

HEAD advanced during setup, and a subsequent unpinned attempt detected concurrent production edits; both were rejected rather than treated as comparable measurements. The accepted run captures local module source once in a temporary test snapshot and serves those bytes to all four processes. It removes that temporary file afterward. All 32 common imported production modules had the same aggregate fingerprint in every accepted process:

`f744d116ae8e55b17330462b7a992202f9d126ef3c3877a4fd83a06962553756`

## Results

| Run | CPU frame p50 | CPU frame p95 |
|---|---:|---:|
| Baseline A1 | 6.861 ms | 10.204 ms |
| Current B1 | 6.757 ms | 7.567 ms |
| Current B2 | 7.046 ms | 9.312 ms |
| Baseline A2 | 6.906 ms | 10.494 ms |
| Average of baseline run quantiles | 6.883 ms | 10.349 ms |
| Average of current run quantiles | 6.902 ms | 8.440 ms |

Median update cost differs by +0.019 ms (+0.27%) for the whole 32-actor batch. The lower current p95 is an observation, not evidence that adding blood speeds up the actors: host scheduling and GC tails vary between processes.

Peak active particles: 640 → 1,312 across the batch, or 40 → 82 on the most active actor. Per-actor capacity remains 112. Both current runs emitted exactly 832 wound drops during six simulated seconds; all 16 wounded actors retained four active wounds at the end. The baseline emits no continuing drops.

This is CPU-only. There is no renderer, camera, GPU draw, city AI, traffic or whole-game frame-time/FPS measurement. More active particles can still affect visible GPU cost even though pool capacity and draw count are unchanged. No claim about total game FPS is made.
