# Retained depth-first wander — CPU candidate ready

**APPLIED by Artist18/root in `physical-grid-v4`.** Root applied the fresh scoped frontier transform and separately added the guarded road-egress hook. This agent only updated tests/documentation afterward; production was not edited by this subagent. The CPU comparison substantially increases actual walking at both tested frame rates, preserving collision, minimum qualifying outing length and the shared work budget. It does not finish the living-city task or prove loaded-scene FPS.

## Scope

Only change the native neighbour insertion in `pickNpcWaypoint`:

```js
if(resolver)queue.splice(search.qi+1,0,node);else queue.push(node);
```

This retains the same queue, visited-node map, parent links, per-actor shuffled directions and cross-frame `search.qi`. Native searches explore the newly discovered branch before older siblings. Legacy non-native searches remain breadth-first. The existing qualifying goal remains depth >= 8 and net displacement >= 6 source cells (24.6 m), respecting prior-origin direction and goal reservations. Maximum depth 18, existing 520-node guard, full body/sweep, surface restrictions, fine-grid exit, interruption rules, two admissions and four-millisecond CPU budget remain unchanged.

The algorithm is intentionally not a shortest-path search. Its paths can be longer; accepted parent paths never repeat a waypoint. Unlike the rejected direct-ray experiment, this uses the full retained frontier and backtracking alternatives already discovered by the search.

## Final comparisons

Actual 288 valid origins spread across the map, 60 simulated seconds per run, 1.8 m/s, current .001 intermediate/.4 final arrival handling, full execution footprint/sweep for every physical step. Reverse-order 10 Hz and 20 Hz runs report the final 20 seconds separately from startup.

| Metric | 10 Hz: current -> candidate | 20 Hz: current -> candidate |
|---|---:|---:|
| Issued routes / completed outings | 496/376 -> 675/478 | 984/734 -> 1228/947 |
| Moving samples, all 60 s | 35.06 -> 58.78% | 66.33 -> 86.00% |
| Moving samples, final 20 s | 45.27 -> 68.72% | 75.64 -> 96.27% |
| Pending samples, final 20 s | 54.11 -> 30.46% | 23.32 -> 1.41% |
| Planner CPU total | 2401 -> 2192 ms | 4550 -> 3279 ms |
| Planner CPU per issued route | 4.84 -> 3.25 ms | 4.62 -> 2.67 ms |
| Planner update CPU p95 | 4.72 -> 4.77 ms | 4.67 -> 4.56 ms |
| Request latency p50 / p95 | 13.1/44.5 -> 7.0/22.1 s | 3.2/17.55 -> .25/9.45 s |
| Expanded nodes p50 / p95 | 24/72 -> 13/37 | 24/87 -> 10/37 |
| Full long outings | 256 -> 363 | 462 -> 477 |
| Long-outing median / p95 length | 32.8/47.6 -> 36.9/69.7 m | 33.1/55.8 -> 36.9/72.2 m |
| Distinct goal cells | 465 -> 617 | 779 -> 792 |
| Blocked physical steps / waypoint loops | 0/0 -> 0/0 | 0/0 -> 0/0 |

The earlier 10 Hz AB was also positive: moving31.73 ->49.66%, latency p9545.6 ->26.2 s, planner CPU2564 ->2371 ms. Thus the result is not limited to the reverse-order run.

## Short-fallback caveat

The existing fallback for constrained geometry remains and becomes more frequent once requests finish faster. At 20 Hz, routes under four metres increase from 102/984 to 311/1228. Overall route median remains31.22 m and qualifying long routes still satisfy their unchanged minimum. This is a real remaining limitation for some confined actors, not grounds to call all residents fully solved. At10 Hz, the fraction under8 m decreases9.88 ->9.19%, under16 m18.55 ->13.33%.

More physical walking also costs more movement CPU: at20 Hz, movement CPU4272 ->6039 ms while planner CPU4550 ->3279 ms. Do not convert route-planning improvements into an unsupported FPS claim.

## Files and validation

- `npc_wander_depth_first_candidate18.mjs`: guarded, single-line transform for fresh scoped application.
- `outputs/pickNpcWaypoint_depth_first_staged18.js`: staged function, syntax PASS.
- `test_npc_wander_depth_first_candidate18.mjs`: actual moving A/B; `--reverse` for reverse10 Hz, `--20hz` for20 Hz. Reports `outputs/npc_wander_depth_first_candidate18_10hz*.json` and `_20hz.json`.
- `test_npc_wander_depth_first_contracts18.mjs`: PASS.256 deterministic repeat actors, directions N56/S60/E66/W74; minimum outing length, depth18 cap, no parent-path loops, retained order/surface invalidation, panic/death and reserved-goal exclusivity.
- `test_npc_wander_grid_exit_candidate18.mjs --depth-first`: PASS. Both actual trapped origins physically exit and receive a normal long outing; fine-grid retained state, exact-origin shift, resolver/surface replacement, cancellation/panic/death, closed cage/water and occupied destinations still work. Report `_depth_first.json` explicitly marks the candidate override.

The fixture excludes full-world AI/combat/commerce, runtime railway and streamed vehicles, GPU and LIVE. No coordinator request or additional game tab was used.

After root's integration, contracts and grid-exit regressions use the real applied function without double transformation. The benchmark reconstructs only the previous FIFO frontier for its baseline; `--source-only` validates both implementations without repeating heavy runs. Quick applied-source validation PASS: 256 deterministic direction/depth/loop contracts, retained state and occupied goals, plus both actual grid-exit movements, exact-origin shift, interruption/invalidation and true cage/water failure. The grid-exit report states `appliedProduction:true`, `depthFirstApplied:true`, `depthFirstCandidate:false`. The guarded road-egress hook remains in the tested source; the separate road author owns its fixture hookup and acceptance.
