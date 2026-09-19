# NPC static navigation query cache — isolated audit, 20 September 2026

Status: **candidate only; no production change**. Requested by Artist18 while investigating residents waiting for paths. No GPU/browser session was opened; player/source vehicle ownership was not touched.

Root decision after review: **do not integrate this static-cache candidate** in the present patch. The applied queue change is independently max 8 admissions under the existing 4 ms CPU budget; lifecycle fixes take priority. The candidate files remain isolated audit artifacts.

## Existing behavior and safe boundary

`npc_native_navigation.mjs` clears both point and swept-solid query caches every `beginFrame`. Static floor support already has its own opt-in persistent cache in `npc_support_cache.mjs`; water, terrain admission, vehicles, railway, and logical source cars must remain live.

The isolated transform retains only floor + static point-solid result and swept authored-body result across frames. It still samples water, terrain admission, surface classification, vehicles and train through the existing per-frame query path. Public behavior without an explicit `getStaticRevision` callback remains unchanged. Storage is bounded (30,000 points / 12,000 sweeps, FIFO eviction).

Files:
- `test_npc_static_navigation_candidate18.mjs`: isolated source transformer/data-module loader; not imported by the game.
- `test_npc_static_navigation_audit18.mjs`: safety checks and actual static snapshot CPU microbenchmark.

Run: `node test_npc_static_navigation_audit18.mjs`

## Measurement

3,271 authored snapshot static bodies; 3,481 half-cell point queries and 1,161 short swept footprints per frame, 24 repeated frames over the same central grid, three alternating baseline/candidate runs. Warm frames 5–24:

| Measure | Existing | Candidate |
| --- | ---: | ---: |
| CPU frame p50, run 1 | 3.859 ms | 3.174 ms |
| CPU frame p50, run 2 | 3.654 ms | 2.702 ms |
| CPU frame p50, run 3 | 3.618 ms | 2.859 ms |
| CPU frame p95, run 1 | 4.538 ms | 4.192 ms |
| CPU frame p95, run 2 | 4.559 ms | 3.547 ms |
| CPU frame p95, run 3 | 7.139 ms | 3.377 ms |
| Static point broadphase calls | 83,544 | 3,481 |
| Static sweep broadphase calls | 27,864 | 1,161 |
| Dynamic obstruction calls | 82,440 | 82,440 |

Every frame's blocked-query checksum matched. Dynamic obstruction call count matched. Safety assertions passed for explicit revision invalidation, wall removal, raised floor/overhead clearance, same-token manual invalidation, moving obstruction, changing water, terrain and surface, and non-opt-in freshness.

This is deliberately a repeated-query microbenchmark, not the actual whole planner trace. Fresh unique path points, frequent doors, or dynamic collisions may reduce the benefit. No claim about moving resident share or full-scene FPS follows from this measurement. **Производительность общей сцены не проверена.**

## Integration prerequisites — do not omit

1. `incremental_walk_collision_index.mjs` needs a real monotonically increasing mutation revision covering successful replacement, removal and clear. `stats.replacements` alone is unsafe: `removeGroup` only increments removals, `clear` increments neither, and `resetCounters` can reuse previous values. An index identity plus genuine revision is necessary.
2. Revision must also cover floor/environment changes: scene, building sample index, railway/rail plan, landscape, topology, entry identity/order, `floorHeight` replacement, and explicit `npcSupportRevision`. Existing support-cache invalidation machinery already tracks these; expose its generation or reuse a separately tracked environment generation. In-place edits must publish an explicit revision.
3. Revision must be refreshed after entry collision groups and support cache update, before this frame's navigation consumers. If any collision mutator runs between navigation consumers, invalidate at that mutator too; frame-only invalidation assumes the existing update ordering.
4. Any moving door invalidates a global solid-cache generation. This is correct but may remove most benefit during busy building access. A per-bucket revision is the next option only if a real trace demonstrates this loss; do not introduce that complexity speculatively.
5. Preserve existing per-frame dynamic checks. Do not persist the public `{blocked,depth,surface}` result or cache `waterAt`, train positions, `fleet`/logical traffic obstacles.

Recommendation: hold candidate until the root's path-queue and idle-state fixes are evaluated. This small CPU benefit alone cannot explain or solve residents permanently standing. It is a scoped optimization option, not an alternative to finding failed lifecycle transitions.
