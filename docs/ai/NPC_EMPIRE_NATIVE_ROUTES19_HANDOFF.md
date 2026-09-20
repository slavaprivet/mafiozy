# Empire native routes — 20 September 2026

Approved scoped change: `empire_action` and `empire_escort` use the existing native directed helper when the native resolver and helper are present. The body-clearance callback is passed directly; it is not expanded again. Each published edge is body-sampled and swept. Existing shared queue admission, pending jobs, cancellation/generation and four-millisecond work budget are unchanged.

For these two native kinds only, `_npcAdvanceRoute` reaches each intermediate waypoint within `.001` cells before turning. Previously it turned `.34` cells early, cutting obstacle corners even when the planner published valid edges. Final `.34` arrival tolerance, all legacy movement and unrelated route kinds remain unchanged. Missing optional helper retains coarse fallback.

## Files

- `world.html`: route-kind opt-in and scoped intermediate reach.
- `assets/maps/city_rebuild_v1/test_empire_native_routes19.mjs`: actual source planning and movement comparison, protected contracts.
- `assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs`: optional supplied snapshot, old default unchanged.
- `assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz`: 516,417-byte compact static geometry fixture. Contains exact buildings and static colliders from the existing map snapshot; road-render and lane-graph data omitted. This file must accompany the new test. The new test does not read an unpublished `outputs/` fixture.

The shared geometry fixture still requires the project's existing external Three vendor and GLB asset setup. The compressed fixture is pedestrian-only, not a replacement for vehicle-traffic test input.

## Reproduction and results

Eight safe starting regions including both reported Leila vicinity and Marat, four destinations at 4.33 cells and four at 24 cells for each start: 64 actual-geometry pairs. Alternate action/escort kinds. Published paths are checked for full-body clearance and continuous collision sweeps, then passed through actual `_npcAdvanceRoute`; every resulting movement step also receives a sweep check.

| Result | Old coarse + early turns | Native helper + exact intermediate turns |
|---|---:|---:|
| Published paths with invalid edges | 24 / 64 | 0 / 64 |
| Blocked during actual movement | 24 / 64 | 0 / 64 |
| Reached destination | 40 / 64 | 64 / 64 |
| Expanded nodes | 54,690 | 5,244 |
| Planning median, summed slices per route | 8.14 ms | 5.75 ms |
| Planning p95, summed slices per route | 22.04 ms | 18.18 ms |
| Total planning CPU for 64 routes | 643.95 ms | 679.53 ms |
| Individual slice p95 | 4.02 ms | 4.23 ms |

Total CPU increased 5.5% in this run while the new planner completes 24 additional traversable paths. Timings vary with JIT/host load; the slice target is cooperative and a running body/edge query can finish slightly past its deadline. These numbers are CPU fixture measurements, not whole-scene frame time or FPS. Whole-scene performance remains unverified here.

The helper alone initially left four movement blocks despite zero invalid published edges. All four disappeared when intermediate turns stopped cutting corners. No blocked swept movement steps remain in the 64-case final test.

New test also verifies actual native A* pending jobs cannot resume after generation/action changes, cancellation, death, hidden state or HP zero; optional-helper fallback; unchanged legacy/unrelated movement and final arrival. Cancellation tests charge a deterministic 0.12 ms per actual-geometry body query to guarantee suspension; performance measurements above use the real CPU clock.

Passed: new 64-pair test; `test_empire_pending_slices19.mjs`; empire stall recovery 12/12, route generation 12/12 and admission; unique body placement; six executable inline scripts compile. No browser/GPU test was run by this subagent. Root owns LIVE reload and observation of Leila/Marcello. Existing invalid-start recovery is a separate patch; this route change does not make invalid starts passable.
