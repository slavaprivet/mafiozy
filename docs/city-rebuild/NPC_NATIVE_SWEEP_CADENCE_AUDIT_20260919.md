# NPC native movement: cadence regression and continuous solid check

Status: CPU verified on 19 September 2026. Integrated into shared `/walk` navigation and source world. No GPU tab opened; loaded-game FPS and live visual acceptance are not verified.

## Defect and correction

The new distant civilian cadence exposed a real existing sampling weakness. On the loaded authored city path `(r3.5,c7.5) → (r3.5,c4.5)`, a thin solid blocked 60 Hz movement but a 250 ms step crossed it. The forbidden centre interval is `c6.844–6.857` (about 5.3 cm). Reducing the point spacing to .04 tile still missed it; .025 happened to catch it, while .02 missed again. Smaller sampling is not a collision guarantee.

`npc_swept_footprint.mjs` now forms the exact planar hull of the NPC's existing .18-tile square translated over the requested segment. Polygon vertices, containment and edge intersections handle concave authored bodies without filling their empty notches. Touching edges count as contact. The source's terrain, water, dynamic vehicle, custom callback and original point gates still run first.

`npc_native_navigation.mjs` accepts `mode:'sweep',from,to,radius` and returns `{swept:true,blocked}`. Hosts without a bounds query return `{swept:false}` for compatibility. Static/incremental collision indexes expose deterministic row-major `queryBounds`, preserving per-bucket ordering and duplicates. The navigation narrowphase deduplicates object identities; there is no whole-scene solid scan. Cache invalidation follows the existing per-frame navigation contract.

Vertical support uses the actual ground callback at intersecting polygon/footprint vertices and edge contacts, matching original footprint-corner probes. Using centre ground height falsely blocked the hospital's sloping approach: the front of the footprint was already on the higher platform. Ramp/platform and real-wall regressions are covered. This is continuous planar geometry with the existing terrain support model, not a new analytic swept terrain or dynamic-car solver.

Source `_npcPathPassable` invokes the new gate only for ordinary `npcPassable` / `npcPassableForSnitch`; custom passage callbacks retain their semantics. Native `building_entry` pathfinder edges use the same solid gate so planned entry routes agree with movement. FIFO search, visited caps and deferred route budgets are unchanged. `walk_preview.mjs` supplies the existing incremental index's bounds query and preserves the logical-vehicle callback owned by traffic work.

## Actual fixture regression and bounded CPU comparison

`test_npc_native_cadence_movement.mjs` loads 3,674 real city/static/door/car/water fixture bodies and executes the actual generic source foot branch and `_npcRoutineStep`. It runs the same 288 persistent residents on dry city segments for 120 frames, discarding the first 20 measurement frames. IDs, HP, elapsed travel including cadence carry, and body-clear destinations are asserted.

| Mode | Update p50 | Update p95 | Movement calls | Max actors updated/frame |
| --- | ---: | ---: | ---: | ---: |
| Previous point checks, every frame | 5.795 ms | 10.914 ms | 34,560 | 288 |
| Continuous solids, every frame | 6.551 ms | 9.777 ms | 34,560 | 288 |
| Continuous solids, distant cadence | 0.683 ms | 0.975 ms | 2,282 | 25 |

These are one comparable CPU run, not an FPS claim; timings fluctuate. The benchmark excludes full `updateNpcs` event scheduling, live traffic, rendering/skinning and GPU. The new exact gate raises median movement cost at full cadence; the bounded distant cadence reduces the sampled ordinary movement work substantially. Source report: `outputs/npc_native_cadence_movement_20260919.json`.

The actual thin obstacle blocks both cadences after the fix: 60 Hz stops at c6.89333 and 250 ms at c6.90. Different last safe positions are expected; neither crosses the solid.

## Verification

- New sweep test: thin/concave/contained/touching solids, bounds versus linear AABB coverage, static/incremental order and duplicates, moved/removed door buckets, support height, overhead clearance, hospital-style ramp, custom callback guards.
- Existing collision index test: 25,000 actual placement/edge/moved-door queries. Incremental index: all eight tests pass, including refcounts, old/new invalidation and native cache contract.
- Existing native navigation, source route edges, source water routing/egress, native surface authority, civilian trip contract and simulation cadence tests pass.
- Actual hospital civilian lifecycle passes after 757 frames: 39.10 m driven, 34.34 m walked, physical boarding/drive/exit, approach/entry, browse, exit and next bench plan. Existing identity and HP assertions remain enabled. Its routine-only CPU p50/p95 was .081/.218 ms; max63.66 ms includes one-off loaded route work, not a frame-time acceptance result.
- Module syntax checks pass. No broad repository test run and no fake full-AI benchmark.

## Files in this scope

Production: `npc_swept_footprint.mjs`, `npc_native_navigation.mjs`, `walk_collision_index.mjs`, `incremental_walk_collision_index.mjs`; exact scoped gates in `world.html`; one `bodiesInBounds` constructor argument in `walk_preview.mjs`.

Tests: `test_npc_swept_navigation.mjs`, `test_npc_native_cadence_movement.mjs`, actual navigation bounds injection and extraction of `_cancelNpcDirectedSearch` in `test_civilian_native_fixture.mjs`. The latter is a real source function needed when native routes now correctly refuse blocked edges.

Earlier police/animation findings and changes are separately recorded in `NPC_POLICE_ANIMATION_AUDIT_20260919.md`. No civilian density, role ownership, economy or commerce settings were changed by this audit.
