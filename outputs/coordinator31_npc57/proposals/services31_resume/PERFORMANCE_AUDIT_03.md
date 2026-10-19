# Passage/avoidance performance audit — first matched pair

Read-only review of the final merged source and `baseline56_perf1080_03` / `merged57_perf1080_03`. No production, patch or harness file changed; no engine or Git command ran. `PERFORMANCE_AUDIT_03.json` pins the reviewed source and native receipts.

**No production optimization is recommended from this pair alone.** There is measurable extra overall NPC work, but the receipts do not attribute it to passage code and the ordinary activities differ substantially. The requested reverse-order pair is the useful next evidence.

| Observed quantity | Baseline56 | Candidate57 |
| --- | ---: | ---: |
| Mean rendered FPS | 114.358 | 105.196 |
| Mean rendered frame | 8.744 ms | 9.506 ms |
| Required-motion actor samples out of900 | 655 (72.78%) | 784 (87.11%) |
| INBOUND/ready actor samples | 374 | 594 |
| RESTING + AMBIENT actor samples | 236 | 104 |
| Mean daily bucket per physics step | 2784.8 µs | 3314.0 µs |
| Mean sum of NPC timing buckets | 3701.1 µs | 4149.2 µs |
| Wait-cohort support queries | 910 | 1452 |

The required-motion sample count increased19.7%, while mean daily work increased19.0%. This similarity is descriptive, not a causal proof or a way to discount the FPS observation. Rendering timings cover the90-second measurement. Population timing buckets cover roughly6606 physics samples including warmup; the exported `logic_cost` quantiles are a last2048-sample ring, not the whole90-second interval. The separate passage Node normally refreshes before main's population step, so its proactive refresh is outside those population buckets.

## Additional work in the source

- `npc_passage31.refresh()` has a physics-frame guard. The proactive callback and all later route/avoidance calls do not perform repeated full refreshes within that frame. It still rebuilds the live actor dictionary and membership each physics step: ten active residents plus12 staff in this batch. `active_records30()` returns a cached active view; this change does not rescan all287 catalogue entries. Door geometry/cell indexing is rebuilt at most once per second unless the entry count changes.
- Native exception pairing examines every pair within each occupied zone, builds pair string keys and a wanted dictionary each frame, and only calls native add/remove when membership changes. Complexity is bounded by the live actor count and32 members per zone. There are no final-city occupancy/pair-count samples to identify how often that path was costly.
- Every physical `floor_at`, `standing` and `sweep` query now calls `query_exclusions()`. Even far from a portal, this adds the refresh-frame check, live/actor-membership checks and a spatial-cell zone lookup. Near a portal it also dereferences live door/clone owners, tests the zone geometry and scans current members to append peer RIDs. The original code already allocated the query object and the one-element self-exclusion array; those baseline allocations should not be counted as newly introduced overhead.
- Avoidance refresh adds one scene-service lookup, one frame-guarded refresh and one `body_zone` call per active resident, plus a passage string copy into each frame row/agent. Neighbor collection adds a string comparison, then skips same-zone peers before the more expensive conflict calculation. That can save work in a busy doorway, so its net cost cannot be inferred solely by counting the added line.

## What the existing evidence can and cannot attribute

`npc_passage31.diagnostics()` already exposes actors/zones/in_passage/pairs and lifetime `max_refresh_us`. The scene's `npc_avoidance_world29` service has `core.diagnostics()`, exposing current-frame snapshot/solve microseconds, scans, decisions and pair evaluations. Neither is exported in these final MASS30/SOAK31 receipts. The existing population snapshot exports broader daily/health/resident/navigation buckets only. `SLOW_PLANNER31` captures route diagnostics only after a slow interval; it is not a continuous passage-cost profiler.

Earlier native fixture receipts contain passage maxima108 µs with two actors and323 µs with six actors/15 pairs. Those are small isolated scenes, include lifetime/setup maxima and exclude query-exclusion costs. They do not establish the city's mean passage overhead or explain the measured9.16 FPS difference.

If the reverse-order pair confirms a stable deficit, the smallest useful next diagnostic would export the existing passage and avoidance counters during a separately pinned paired run, along with required-motion workload. A mean or percentile for passage refresh and query-exclusion cost would need explicit bounded instrumentation; the existing lifetime maximum alone is insufficient. No proposed fast path is justified yet: for example, an empty-members early return would only help if empty membership were actually common, which these receipts do not show. Preserve the current exact source while resolving that uncertainty.
