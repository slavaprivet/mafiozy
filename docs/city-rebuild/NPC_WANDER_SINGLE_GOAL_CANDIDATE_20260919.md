# One complete wander goal — staged candidate

**APPLIED by Artist18/root using the fresh scoped transform.** Follow-up contracts test the real production function; whole-scene LIVE/FPS acceptance remains unverified. This subagent made only test/document compatibility edits after root's integration. No contact with the coordinator or GPU tab was made.

Changes: stop BFS after one eligible long target instead of eight. The existing long-target contract remains `depth >= 8`, net displacement at least six source cells (24.6 m), previous-origin direction restriction, and unoccupied destination. Collision, full footprint, continuous sweep, retained frontier, fine-grid escape, true-courtyard fallback, FIFO, two admissions/four-millisecond budget, movement and speed are unchanged.

To avoid every actor choosing the same cardinal direction, the four BFS directions are deterministically shuffled using actor ID, current coarse origin and previous route start. The order is stored on the search and retained across slices. FNV seeding plus xorshift Fisher–Yates is used; an initially tested low-bit LCG permutation was biased and was rejected before staging the final version.

## Files and checks

- `npc_wander_single_goal_candidate18.mjs`: narrow transform of the current function; replaces only the threshold and direction declaration. Use this against fresh source when integrating, instead of overwriting unrelated concurrent function edits.
- `outputs/pickNpcWaypoint_single_goal_staged18.js`: complete staged function; `node --check` PASS.
- `test_npc_wander_single_goal_contracts18.mjs`: PASS. 256 actors in open space, every route retains depth >= 8 and distance >= 6; same actor/origin produces identical route on repeat. Cardinal distribution N63/S60/E68/W65. Retained direction order, surface invalidation and panic/death checks pass.
- `test_npc_wander_single_goal_candidate18.mjs` and `--reverse`: PASS. Actual 288 valid origins spread over the entire map, 60 simulated seconds at both 20 Hz and 10 Hz, current arrival radii, speed 1.8 m/s, real execution footprint/sweep every step. AB and BA order. All eight actual runs report zero blocked movement segments.

## Final version results

| Metric | 20 Hz AB | 20 Hz BA | 10 Hz AB | 10 Hz BA |
|---|---:|---:|---:|---:|
| Issued routes | 771 -> 804 | 849 -> 962 | 352 -> 406 | 412 -> 438 |
| Completed outings | 604 -> 636 | 665 -> 707 | 276 -> 295 | 299 -> 352 |
| Moving samples | 54.68 -> 56.79% | 58.59 -> 63.76% | 25.16 -> 28.05% | 29.58 -> 31.41% |
| Pending samples | 44.46 -> 42.41% | 40.50 -> 35.29% | 74.48 -> 71.55% | 70.01 -> 68.14% |
| Planner CPU total | 5,034 -> 4,991 ms | 4,682 -> 4,490 ms | 2,705 -> 2,608 ms | 2,628 -> 2,593 ms |
| Planner CPU per route | 6.53 -> 6.21 ms | 5.52 -> 4.67 ms | 7.68 -> 6.42 ms | 6.38 -> 5.92 ms |
| Request latency p95 | 25.90 -> 20.45 s | 20.65 -> 18.80 s | 49.80 -> 49.10 s | 47.10 -> 45.00 s |
| Route update CPU p95 | 4.86 -> 4.88 ms | 4.73 -> 4.77 ms | 5.18 -> 5.16 ms | 5.19 -> 5.08 ms |
| Full long outings | 299 -> 374 | 327 -> 454 | 123 -> 202 | 161 -> 220 |
| Distinct goal cells | 635 -> 657 | 678 -> 776 | 335 -> 386 | 390 -> 418 |

Long-outing median changes from 36.9 m to approximately 32.8–33.1 m. This is still a full eight-cell walk; minimum qualifying depth/distance are unchanged. The existing shorter fallback in confined geometry is reported separately, never counted as a successful full-length outing. Short fallback count decreases in all four comparisons. The fine-grid escape helper remains present but was not invoked by this particular origin distribution.

Reports: `outputs/npc_wander_single_goal_candidate18.json` and `outputs/npc_wander_single_goal_candidate18_reverse.json`.

## Limits and integration note

Waiting is still long at 10 Hz: this is a modest throughput improvement, not completion of the living-city task. More movement can increase movement CPU; no whole-scene FPS or LIVE result is claimed. Actual CPU slice timing and goal reservation order vary with machine load, so use all comparisons rather than a single timing number.

After integration, `test_npc_wander_single_goal_contracts18.mjs` reads the actual applied function. The benchmark reconstructs its eight-target/original-direction baseline and uses the real one-target function directly, avoiding double transformation; `--source-only` validates this reconstruction without repeating four heavy runs. Historical early-finish/continuation baseline extraction now accepts threshold 1 or 8 while preserving the full-horizon/endpoint-only assertions. Applied contract, continuation and first-admission-starvation regressions pass; continuation finishes both owners in 56 synthetic frames under the original two-admission/four-millisecond budget.
