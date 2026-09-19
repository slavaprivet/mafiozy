# Actual lane worker and client proof — 19 September 2026

`node assets/maps/city_rebuild_v1/test_city_lane_route_worker.mjs` passes against the actual final worker snapshot created at `2026-09-19T17:05:49.189Z`: 78 building records and 3,271 static collider records from authored buildings/decor, generated decor, road dressing and parking.

The test runs the production browser worker entry in a real Node worker thread, and then the production `createLaneRouteJobs` client through `createCityRoadNavigation.query`. No mock path search, busy loop, new rendering scene or GPU tab is used.

The final fixture matches the host's minimized instance fields and shared `trafficPlan === preparedLaneGraph.plan` reference. The synchronous comparison retains the original complete road plan and instance records, so equivalence also checks that minimization does not change these route results.

## Behaviors checked

- Exact synchronous-wrapper parity for source-coordinate points, headings, gear changes, controls, destination identity, stop points and distances. CPU `*Ms` fields are excluded; the client comparison additionally removes its expected `routeJob` control annotation.
- Real hospital bay → hospital: 1,567 points / 241.004 m.
- Real north-hills cottage bay → eastside hospital: 2,898 points / 891.516 m.
- Same north-hills origin → gold-coast coastal orchard house: 3,208 points / 926.038 m.
- Production worker's full-body static route sweep runs before the response.
- Every edge control on these routes has a transported canonical record. An occupied actual pedestrian crossing denies passage both in independent `evaluateRoadEdgeControl` and through the host `road-rules` query. Forged control IDs fail closed.
- Old-generation requests are ignored, with a subsequent valid request as a queue barrier.
- Actual `pending → ready` polling keeps the main event loop responsive; completed polls return the same immutable result object.
- An actual solid collider inserted at the hospital origin bay causes the new-generation query to return `blocked: parking_exit_unavailable`. Removing that collider and rebuilding returns `ready` with exactly the previous route points and distance. Generations advance on both replacements.

## CPU measurements

Report: `outputs/city_lane_route_worker_20260919.json`.

| Measurement | Observed |
|---|---:|
| Synchronous comparison queries | 58.25 / 55.40 / 29.46 ms |
| Actual worker route computation | 50.02 / 61.99 / 31.56 ms |
| Raw main-thread route post | 0.021–0.026 ms |
| 43 production-client polls p50 / p95 / max | 0.0560 / 0.1019 / 0.4837 ms |
| Largest client result callback (clone/freeze included) | 5.7013 ms |
| Client far-route elapsed times | 72.85 / 50.02 ms |
| Main-loop ticks during those far routes | 6 / 4 |
| Initial minimized snapshot `postMessage` / total initialization | 153.54 / 540.50 ms |
| Production-client initialization call | 157.84 ms |
| World replacement post (add / remove obstacle) | 6.67 / 6.80 ms |
| World replacement background rebuild + route (add / remove) | 675.03 / 762.53 ms |

The previous full duplicated snapshot measured 364.61 ms raw posting / 384.96 ms client initialization and 1,184.63 ms total initialization in the immediately preceding run. Sharing the prepared plan reference and minimizing records reduced that startup cost while preserving results. This is a local before/after observation, not a controlled browser FPS benchmark.

Initial structured cloning of the city snapshot remains a substantial startup cost. It must happen during loading, rather than inside a gameplay route request. Result delivery and collider replacement have measured main-thread costs too; this proof does not claim zero-cost completion.

These are CPU integration measurements, not browser frame times. **Производительность общей сцены не проверена.** No GPU window was taken. Dynamic actor occupancy and each driven segment still require the live source collision checks; the worker snapshot only proves static scene clearance. Mock lifecycle/cancellation/expiry tests are owned by the client author and run separately.
