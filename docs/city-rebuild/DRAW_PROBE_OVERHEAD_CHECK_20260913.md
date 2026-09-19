# Per-draw instrumentation overhead diagnostic

Status: CPU/tests and controlled LIVE complete. Default detailed
profiling remains ON inside explicit perfqa only. This is not a gameplay fix.

`walk_performance_probe.mjs` provides getDrawProfilingEnabled and
setDrawProfilingEnabled. OFF retains the installed six-argument delegate (so a
later shadow culler is never bypassed), but immediately calls the original method
without per-draw clocks, rest-array allocation, statistics or census. Whole
renderer, matrix, shadow and GPU timers remain. Draw totals are sampled at outer
pass boundaries in BOTH modes, respecting renderer.info.autoReset and the normal
Three shadow→reset→transmission/main order. Multiple root render calls sum within
a frame. OFF omits submit timings and census/renderGroups/materialGroups; it does
not present stale detailed data or zero CPU cost. Switching resets sample windows
without changing GPU timer mode. Both modes retain one direct wrapper call hop.

The hold-only `draw-probe-qa` button is at 312px (274px belongs to native-pick-qa).
Its label distinguishes detailed draw measurement from frame-only measurement.
All hold exit and error paths restore detailed ON. Native-pick, static-matrix,
vehicle-wheel, detail and GPU QA controls are preserved.

Tests: probe/GPU mocks PASS, covering zero injected clock calls in OFF, culler
ordering, autoReset true/false, prior counters, shadow/transmission/main,
multiple frames/calls, independent GPU mode and reset isolation. Freeze suite
30/30 PASS, including twenty draw-UI exit/error cases and existing source hooks.

Detailed capture additionally reports `materialGroups`, keyed by main/shadow,
material.type and opaque/transparent. It is a sampled census, not a rolling
per-material percentile. Temporary material.side changes during transparent
rendering are intentionally not treated as authored double-sided flags.

Coordinator17 received FINAL READY for a single combined reload and same-held
OFF/ON comparison. Do not infer profiler overhead from the earlier GPU-query-only
experiment; that experiment excluded only query overhead, not direct timers.

## Controlled LIVE — detailed OFF to ON

Coordinator17 reported 120/120 samples in one held scene, viewport 911x920,
55 residents seen / 14 visible and 19 traffic vehicles. Render p50/p95 was
70.7/76.2 to 73.3/78.5 ms; interval 82.4/88.4 to 85.1/90.5 ms. GPU elapsed
was 51.27/55.92 to 53.63/59.15 ms, matrices 7.2/8.6 to 7.1/8.4 ms and
shadow pass 18.8/21.6 to 19.5/22 ms.

Both modes had exactly 3463 calls (2166 main / 1297 shadow), 3,539,017 total
triangles and 1,151,171 shadow triangles. Hold was released after measurement.
The detailed diagnostic therefore imposed a measured 2.6 ms median render
difference in this pair. It does not explain the remaining 70.7 ms render cost
with detailed profiling OFF, and disabling it is not a gameplay lag fix.

The sampled material census reported 1902 opaque Standard calls / 29.1 ms
submission versus 81 transparent Standard calls / 2.3 ms; 120 opaque Physical
calls / 4.3 ms and 32 transparent Physical calls. These are sampled submission
costs, not GPU shader timings or per-material rolling percentiles. Do not infer
that transparent glass is the primary bottleneck from this capture.
