# GPU timing diagnostic overhead — 13 September 2026

The performance probe now supports GPU timer OFF/ON while retaining CPU stages
and per-frame main/shadow counts. OFF deletes pending queries and performs no
per-frame timer getQuery/getParameter/poll calls; report gpuTiming is explicit,
gpuMs is null (not zero). A hold-only gpu-timer-qa button restores ON on every
exit. Mock tests cover query cleanup, errors, nonoverlap and CPU/count parity;
freeze lifecycle tests pass. This is diagnostic tooling, not a gameplay speedup.

Coordinator 17 measured one game, held camera [167,2.74,168], DPR1, viewport
911x920, NPC52 seen/18 visible, pending0, traffic19/loading0. 120 samples in each
mode, OFF then ON. Hold remained active at 330/660 frames; final Escape released
it and restored ON. An earlier timeout-invalidated pair was discarded.

| Metric | GPU timer OFF | GPU timer ON |
| --- | ---: | ---: |
| Render p50 / p95 ms | 99.9 / 110.7 | 100.3 / 113 |
| Interval p50 / p95 ms | 116.6 / 129.1 | 116.7 / 132.2 |
| Main submit p50 / p95 ms | 49.7 / 54.9 | 49.7 / 54.2 |
| Shadow p50 / p95 ms | 27.6 / 31.3 | 27.7 / 30.8 |
| Matrix p50 / p95 ms | 9.6 / 11.3 | 9.4 / 11.4 |
| Source p50 / p95 ms | 14.4 / 20.6 | 14.2 / 20.2 |
| GPU timer p50 / p95 ms | unavailable by choice | 70.43 / 78.76 |

Both modes exactly 4638 submissions (2744 main +1894 shadow), 4,322,877
triangles (2,753,644 main +1,569,233 shadow), source errors0. Only 0.4ms median
render difference: GPU timer queries are NOT the primary lag source in this
scene. This does not measure all CPU instrumentation overhead. No driver or
power settings changed. Other earlier scenes used different viewport/camera
and must not be used as causal before/after for this test.
