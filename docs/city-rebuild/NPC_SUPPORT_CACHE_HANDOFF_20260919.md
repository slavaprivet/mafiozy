# NPC support cache — implemented

Implemented after the read-only audit in `NPC_NATIVE_POINT_CACHE_AUDIT_20260919.md`. Scope is only native NPC navigation ground sampling; hero support, perception, vehicle navigation and actor rendering retain their original floor callbacks.

`npc_support_cache.mjs` retains finite support heights at exact numeric x/z coordinates using nested maps. FIFO storage is bounded to30,000 points; typed arrays hold eviction keys. No coordinate rounding, terrain admission, water depth, static collision result, vehicle collision or train collision is cached here.

The walk host checks support dependencies before every NPC navigation frame: scene, building sample index, railway instance/plan, landscape and topology identities, plus ordered entry identities and each `floorHeight` function. Changed dependencies clear the cache. Future in-place floor changes must increment `entry.npcSupportRevision` or call cache.invalidate; a whole-host provider can also supply an environment revision. Current entry/rail/water/landscape floor implementations are static between those scene changes. Door animation does not change floor support and remains checked by the live collision query. Non-finite/unready floor results are not retained.

Host edits are limited to import/cache creation, passing `groundHeight:npcSupportCache.sample` into `createNpcNativeNavigation`, cache beginFrame and existing navigation diagnostics. LIVE statistics are `document.body.dataset.npcWorld → navigation.support`: hits, misses, invalidations, evictions, size and maxPoints. Do not infer a real route-cache hit rate from the warm CPU benchmark.

## Verification

`test_npc_support_cache.mjs` passes exact-coordinate distinction, bounded eviction, every provider identity invalidation, floor function replacement, ordered entry changes, explicit floor revisions and unready support. Production navigation tests in the same test keep door mutation, water, terrain, cars and trains current. The actual hospital GLB fixture changes its physical door leaves, then verifies cached ramp/platform samples equal raw support for256 points.

Warmed comparison uses the actual rail plan and landscape with the same1,600 coordinates. Each cached batch also scans640 entry floor identities. Latest CPU p50/p95:

| Region | Before | After |
| --- | ---: | ---: |
| Hospital | .303/.839ms | .194/.420ms |
| West rail | 8.122/9.380ms | .143/.233ms |
| West forest | 7.511/10.171ms | .159/.242ms |

Report: `outputs/npc_support_cache_20260919.json`. This measures support callbacks with repeat queries, not full AI, loaded-city FPS or queue completion time. Actual LIVE hit rates and overall benefit remain for the coordinated reload.

Existing native navigation and exact sweep suites pass; walk module syntax passes. `test_walk_rail_hooks.mjs` fails its pre-existing adjacency regex because a `roofNavigation` diagnostic assignment appears between vertical navigation and railway update. The actual railway update remains in the unconditional frame sequence; this unrelated test/source scope was not edited.
