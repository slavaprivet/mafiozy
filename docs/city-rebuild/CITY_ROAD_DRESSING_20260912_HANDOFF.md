# Road signs, paint, crossings and renderer — 12 September 2026

Owner: subagent `interior_furnishing`; graph/routes belong to `interior_layout`, parking/runtime integration to root. No GPU scenes were opened.

## Implemented

- `city_road_dressing.mjs`: idempotent teardown disposes BatchedMesh geometry and all three data textures per batch; lenses follow the same 360 m spatial bucket visibility as their housing, including the older InstancedMesh fallback. Actual world-time phases continue while hidden. All original source attributes, indices, material colours and near matrices are byte-equivalent for the same plan.
- `city_road_dressing_plan.mjs`: priority diamonds only suppress another sign facing the same stream (dot > .95, same road). `prioritySignPlacement` distinguishes a real same-direction reference from a failed physical verge search. Yield triangle strokes remain on their incoming road half, before their stop, within the authored path, and outside other junction-complex circles. A bounded corner-pole fallback uses the actual wider crossing-road curb while retaining approach facing.
- Crosswalks are selected by real door access and continuous sidewalk landings, replacing source-order selection of the first 34 major junctions. The cap is now 96; current geometry/demand selects 48. Each has two dry walkable landings, a continuing sidewalk corridor of at least 6 m, and a route to a real door approach. If the far side has no local door, its route crosses this zebra to the connected side. Buildings/rail/water/road lanes are excluded from the dry pedestrian field. Arrival is 0.65 m outside the authored door anchor, along its authored entrance corridor; it is not a test of the internal door mechanism.
- `city_pedestrian_access_plan.mjs`: one multi-source dry-ground field during worker construction, spatial body buckets and cached sampled cells. A final field updates saved paths after all signs exist. No per-frame BFS or extra lights.
- Each signalised crossing has `signalControl={junctionId,axis,offset,clearanceSeconds}`. Export `roadPedestrianPhase(crossing,time)` gives a start window only during the appropriate vehicle red, with enough remaining red for a 1.2 m/s crossing plus 2 s clearance. Unsignalised crossings return `uncontrolled`; turning vehicles must yield to actual occupied crossings. The graph owner links geometric turn/crosswalk conflicts in its cached control index.
- The environment-worker owner has added `pedestrianBodies` containing procedural and parking colliders. The road planner still preserves all 39 parking access keepouts.

## Initial checks and cost (before final control placement)

Artifacts: `outputs/roads_logical_20260912/`.

- `renderer_cpu_comparison.json`: identical original shared78 plan, 67 structural draws / 140,252 triangles both versions; far-visible draws 3 → 0. Twenty BatchedMesh allocations now dispose exactly once. No GPU submission/frame-time claim.
- `dressing_plan_comparison.json`: both planners use the same current graph and original 78-building/164-authored-decor/2,296-procedural-collider/39-parking snapshot. Stable source hashes. 3,292 turns, 1,279 active approaches and all 54 real signal controllers/axes/offsets are preserved. Two signal poles move 4.4 m and 2 m to leave walking clear; facing and controller identity remain unchanged.
- Plan before/after: signs 312 → 380; crossings 34 → 48; structural draws 67 → 67; triangles 141,946 → 160,250. Added sign detail remains in five shared equipment batches.
- Alternating CPU constructor runs, first pair warmup, five measured pairs: p50/p95 1,176.7/1,305.1 ms → 1,922.2/1,986.7 ms. The increase is one-time worker construction of actual pedestrian connectivity. Renderer moving-focus update is approximately 0.006 ms per CPU call; idle approximately 0.002 ms. These are not loaded-scene FPS measurements.
- `crosswalk_candidate_audit.json`: 48/48 connected crossings, 96/96 clear landings/sidewalks, 62 directly connected door-side endpoints; the remaining endpoints reach a door via their own crossing. Zero stored-route collision segments after final signs. Every stop line is at least 1.42 m before the near zebra edge.
- `dressing_candidate_audit.json`: no paint/building, sign/entrance, parking-access/longitudinal-paint, arrow direction or unavailable-turn errors. Opposite-direction priority suppression 133 → 0. Triangles inside another junction complex 19 → 0.
- Nine focused tests pass in `test_city_road_dressing_render_lifecycle.mjs`, `test_city_road_dressing_control_placement.mjs`, `test_city_pedestrian_access_plan.mjs`. Existing `test_city_road_dressing.mjs` passes 90,626 paint samples, pole/rail/doorway checks, coordinated phases and structural geometry limits.

## Final control placement — 20:20 UTC

The earlier seven yield / ten priority findings are closed. `control_placement_candidate.json` was rebuilt from the original exact shared78 inputs and current code with stable source hashes. The final plan has 400 signs, 58 traffic heads / 16 controllers, 48 crossings, 5,975 paint pieces, 3,457 turns and 1,308 active approaches. `control_placement_candidate_audit.json`: **PASS, zero unresolved yield, zero priority gaps, zero semantic/physical errors or review findings**.

The independent late pass follows each real incoming authored path and searches only as far as the next upstream junction. It stops at the first dry verge, cannot jump water or a second carriageway, and retains the complete original .20 m pole radius and all building, pedestrian and parking reservations. Right-side sites are preferred; an explicit left-side alternative is used only after the bounded right search fails. The sign still faces its own approaching stream. Priority confirmation may stand up to 2.5 m closer than the nominal decision anchor while remaining at least 1 m before its physical junction; yield signs remain before the stop anchor. Three new tests exercise occupied verges, second carriageways/water, upstream control bounds and fixed search cost.

The graph owner fixed the four actual overlapping pairs `206/365`, `238/462`, `163/485`, `168/77` as bounded control complexes, after explicit overlap/continuous-road checks. Their short internal links become `junction_internal`; yield duty moves to the external entrance below the main-road class. Original node/approach IDs and geometry remain. No gantry was added and no transitive whole-city merge was made. The late dressing pass installs 13 ordinary shared-batch poles and reconciles same-direction priority references after all poles exist.

`control_placement_crosswalks.json`: **PASS**, all 48 crossings retain dry endpoints, continuous sidewalks and door connectivity; 62 endpoints have a direct door route and every far endpoint can use its own crossing. Zero stored-route collision segments after all final poles. All building/entrance and 39 parking-access reservations remain clear.

`control_placement_comparison.json`: independent placement before/after on the **same current graph**; all existing markings, signals, control rules/anchors, turn arrays and lane-connection arrays are deep-equal. Signs 387 → 400; equipment batches 5 → 5; total structural draws 67 → 67; triangles 165,462 → 168,270 (+2,808). Alternating four planner pairs, first warmup: CPU constructor p50 2,155.94 → 2,210.98 ms, p95 2,295.67 → 2,456.24 ms (three measured samples). This is one-time worker work; no new per-frame search, geometry/material class or light. Source hashes were stable during measurement.

Eleven current tests passed: seven control-placement/phase tests, three renderer lifecycle/range tests, and `test_city_road_traffic.mjs` (104,946 turn samples / 32,401 lane samples, structured-clone PASS). Source-graph north-hospital lane restoration is still being developed separately, so root should rebuild/audit the combined final graph after that patch. Commands:

```
node tools/road_dressing/rebuild_shared_roads.mjs outputs/roads_logical_20260912/shared_plan_snapshot.json outputs/roads_logical_20260912/control_placement_candidate.json
node tools/road_dressing/audit_shared_snapshot.mjs control_placement_candidate.json control_placement_candidate_audit.json
node tools/road_dressing/audit_crosswalk_access.mjs control_placement_candidate.json control_placement_crosswalks.json
node tools/road_dressing/compare_control_placement.mjs
```

## Remaining integration limits

The dry external-proxy field reaches 70 of 75 authored doorway approaches; two tower anchors and the three bank anchors need the true entry/approach API rather than their conservative car proxies. This is not evidence that their playable interior doors are blocked. The three detention buildings use their separate physical intake/release contract.

Do not declare whole-city navigation or loaded-scene performance accepted until root combines the final parking/graph changes and runs the coordinator's LIVE queue. These road files do not start authoritative NPC vehicle AI.
