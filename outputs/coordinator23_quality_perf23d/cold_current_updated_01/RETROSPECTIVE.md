# First-mark stall reproduced and addressed in instrumented GPU run

Root ran exact baseline/current/updated once sequentially. All3valid,10actual cold shots and10warm shots each. This is a diagnostic per-frame-instrumented run, not the previous light loaded-performance fixture.

Current23d first shot emitted6.171ms into cold phase. Frame6 ended64.722ms with42.095ms wall duration, marks0->1, SURFACE pipeline compilations50->54 and specialization36->39 on that same observed frame. Viewport GPU timestamp2.695ms. The long CPU-side wall stall is temporally linked to first mark surface-pipeline compilation, rather than an unexplained later shot.

Updatedpreassign first shot emitted11.433ms into cold phase. First mark observed frame8 ending32.626ms, wall5.716ms. SURFACE count already52before shots and remains52; specialization36->39 still happens. Max cold frame6.798ms; no42ms event. Warm maxima current9.102/updated8.305ms with no newSURFACE compilations. This A/B and counter evidence strongly supports removal of the observed first-mark pipeline stall by preassigning real pool features during configure. It does not prove all future drivers/material transitions stall-free. Glass/explosive transitions remain separate workloads.

Baseline23c CPU wall costs were larger in cold/warm phases while viewportGPU remained~2.9ms p95. This is independent variability/CPU workload evidence, not a reason to claim global speedup from this one diagnostic. Performance.TIME_PROCESS/PHYSICS monitors update coarsely and must not be treated as exact CPU duration of each listed frame.

| Side | Phase | Actual shots | Wall p50ms | Wall p95ms | Maxms | GPU p95ms | SURFACE compilations |
|---|---|---:|---:|---:|---:|---:|---|
| baseline | cold_first10_ak | 10 | 5.185 | 10.085 | 14.014 | 2.934 | 50 -> 50 |
| baseline | warm_next10_ak | 10 | 7.054 | 12.031 | 16.025 | 2.982 | 50 -> 50 |
| current | cold_first10_ak | 10 | 3.055 | 5.408 | 42.095 | 2.855 | 50 -> 54 |
| current | warm_next10_ak | 10 | 3.129 | 6.059 | 9.102 | 3.031 | 54 -> 54 |
| candidate | cold_first10_ak | 10 | 3.046 | 5.059 | 6.798 | 2.852 | 52 -> 52 |
| candidate | warm_next10_ak | 10 | 3.112 | 5.801 | 8.305 | 2.995 | 52 -> 52 |

Raw evidence remains baseline.json/current.json/candidate.json; no files rewritten. Production and current user game were not touched by this auditing subagent.
