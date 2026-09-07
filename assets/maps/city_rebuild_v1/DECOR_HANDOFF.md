# Rebuild decor candidate — not live, not main

`decor_catalog.v1.json` has 63 types / 163 individual GLBs verified against the
artist's latest manifest by bytes, SHA256 and actual glTF contract nodes.
18 civic types / 54 GLBs reuse existing `/assets/decor/civic_park_v2/models/`.
45 types / 109 GLBs are staged byte-for-byte under this candidate's `models/`.
The original 18 civic types remain approved; all other types remain
`needs_visual_review`. The user's rebuild request authorizes testing these
technical candidates in the isolated preview; technical PASS is not art approval.
No Artist12 character/tree package or rejected water v1 is included.

## Real availability

- 5 building types: cataloged, but this decor planner does not place buildings.
- 18 civic types: fountains, planters, benches, shelters, signs and pedestrian lights.
- 32 rural/waterfront types: paths, transitions, beach furniture, two mini bridges,
  boardwalk, fishing pier, marina connector, fences, picnic/lookout pieces.
- 8 street types: four lamps, three signal components and one furniture collection.
- Direct generic decor binding: **28 types**. Another **20 walkable surface/deck
  types**, **4 street lights**, **2 bridges**, **5 buildings**, **3 signal types**
  and **1 furniture collection** need their explicit semantic adapters. Their
  163 total GLBs are staged/verified; this is not a claim that all are live.
- **No tree or asphalt GLB exists in this manifest.** Do not invent filenames.
  Asphalt is a single host-material surface batch with merged rectangles, zero GLB
  instances per cell. Trees need a separate accepted source catalog.

**Corrected after actual mesh inspection:** street helper sockets contain stale
catalog offsets (Pine `[20,0,14]`) but the actual meshes are already at the origin.
`infrastructure_catalog.v1.json` provides evidence-backed origin `[0,0,0]` overrides
for all four street lamps and collision bounds from the actual `Lamp_Base_*` mesh.
Do not subtract the stale helper socket from these four GLBs. The original
catalog preserves the source finding; final placement consumes the adapter.

## Pure executable planner

```js
import {planDecor} from './decor_placement.mjs';
const plan = planDecor({
  topology, // successful compileTopology output, grid must exist
  catalog, // parsed decor_catalog.v1.json
  host: {
    metresPerCell: 4.1, ledgerComplete: true,
    policeProtectedCells, // actual complete preserved cells, not just POI anchor
    doorCorridors, buildingFootprints, railKeepouts, // RC rectangles below
    assetAdapters: {}
  },
  anchors: [{id:'FOUNTAIN-PARK-A',assetId:'fountain_park',r:30,c:30,
             yawDegrees:0,uniformScale:1.3}], // illustrative, NOT accepted placement
  crossings: [],
  lampPolicy: {enabled:true,assetId:'ped_light_double',maxCount:80,
               spacingCells:8,setbackCells:0.3,maxRoadDistanceCells:2}
});
```

Rectangles are `{minR,maxR,minC,maxC}`, half-open. Cell `(r,c)` occupies
`[r,r+1] × [c,c+1]`; road, water and unknown-surface checks cover the **entire
rotated/scaled clearance**, not just the center. The complete host ledger is a
required host assertion, not something this module can infer from a POI point.
Protected police, red bridge/approaches, doors, buildings and rail envelopes are
excluded. Explicit anchor failures reject the full transaction. Generated lamps
skip illegal candidates, stand on sidewalks near roads, and enforce spacing.
Automatic lights are emissive only: no dynamic-light multiplication.

Instances include exact runtime URL/hash/bytes/LOD, socket-recentered transforms,
world clearance polygon, authored ground proxy bodies and **scaled world collider
polygons/heights**. The plan itself never loads GLBs, attaches objects or changes
navigation. Host renderer must recheck hashes/masks and attach atomically, with
rollback on failure. Hide collision/clearance/helper meshes. Do not replace
authored proxies with a full-model canopy/facade AABB.

## Explicit technical adapter gates

- Street lights have no authored collision proxy. Supply an evidence-backed
  `assetAdapters[id]` with `clearanceM`, `collisionEvidence` and
  `groundBodiesGltfM:[{min:[x,y,z],max:[x,y,z]}]` relative to the placement socket.
  These must describe actual ground obstacles, not the overhead lamp arms.
- Bridges require a named explicit crossing, dry endpoints, matching center/yaw,
  sufficient actual visual span and an envelope containing the full clearance.
  Crossing format: `{id,mode:'pedestrian'|'car',endpointsRC:[[r,c],[r,c]],envelope}`.
  Only `mini_vehicle_bridge` can fulfill car mode. Existing red bridge is never
  replaced. Host supplies `assetAdapters[id].deckNavigationEvidence`; the bridge
  collider metadata is **not** permission to block the entire deck with a box.
- Signal/collection/building entries cannot be sent through generic decor
  placement. Signals need the artist's separate per-approach phase adapter.
- Shoreline/path/transition/lookout modules require a specialized host terrain/
  walkability adapter even when they have a proxy. A traversable ground tile or
  a deck must not become a solid wall. No implicit terrain replacement occurs.

The source street kit's old 320-light layout is not copied into the rebuilt map.
The new candidate planner has an absolute 320 light ceiling and default 80; it
does not assert the old layout is a valid new-city placement. No source catalog
coordinates are interpreted as game-world coordinates.

## Verification and regeneration

```powershell
node assets/maps/city_rebuild_v1/test_decor_placement.mjs
node assets/maps/city_rebuild_v1/build_decor_catalog.mjs <latest_ready_asset_manifest_v1.json>
```

The builder never overwrites a staged GLB with different bytes. It regenerates
the catalog mechanically and checks all declared interfaces in every LOD.
Tests include all 163 hashes, deterministic/no-mutation output, actual scaled
colliders, water/road/unknown rejection, collision/door/police guards, sparse
lights, merged road coverage, explicit bridge fit and truthful approval states.

**Remaining live gates:** actual rebuilt topology plus complete migrated door/
building/rail ledger, foliage source, street/bridge adapters, art review for the
45 candidate types, LOD/material rendering, walking/vehicle traversal and FPS.
The original masterplan rejection is not waived by these synthetic tests.

## Actual repaired-topology candidate (2026-09-07)

`decor_placement.v1.json` is now generated against the **real repaired topology**
and the frozen **72-building** plan, not a synthetic map. Source SHA256 pins are
embedded and checked by `test_generated_decor.mjs`.

- 164 instances: 8 fountains, 28 benches/planters/bins, 128 street lights.
- 16 street lights in each of 8 actual district polygons; four matching families.
- Park candidates are district-centered and within 7 cells of a road, with
  complete rotated/scaled clearance checked against buildings, entrances,
  police, bridges, water and roads. 12 extra furniture proposals were omitted
  with explicit `NO_SAFE_NEAR_ROAD_PARK_SPACE` findings rather than crowded in.
- 1073 merged asphalt rectangles cover exactly 11962 road cells, without overlaps
  and without GLB-per-cell rendering. `asphaltRects` is a renderer convenience
  alias; `surfaces[0]` carries the same batch and the material descriptor.
- `infrastructure_catalog.v1.json` adds 8 genuine PBR descriptors extracted from
  the industrial artist's hash-checked road kit, including clean/worn/aged
  asphalt. Values are **linear sRGB**, not hex sRGB. No combined catalog GLB is
  instantiated. Four lamp adapters use real `Lamp_Base_*` ground bounds and fix
  stale socket origins, all with source hash evidence.
- Three new large crossing spans are 180.4m, 53.3m and 65.6m; the ready 9m mini
  vehicle bridge does not fit them as one safe-scale instance. No fake bridge
  installation is claimed. `bridgeFitReport` records these gaps and preserves
  the existing premium red bridge.

This output remains **isolated walk preview only**, `pendingHostSnapshot:true`,
`productionPhysicsAuthorized:false`. It does not authorize overwriting main or
assert that the vehicle/gameplay migration is finished.

```powershell
node assets/maps/city_rebuild_v1/build_infrastructure_bindings.mjs <industry-latest-manifest.json>
node assets/maps/city_rebuild_v1/build_decor_placement.mjs
node assets/maps/city_rebuild_v1/test_decor_placement.mjs
node assets/maps/city_rebuild_v1/test_generated_decor.mjs
```

19 module regressions pass; actual generated-plan regression additionally
checks all binding hashes, all 72 building clearances/doors, every touched native
cell, all 164 pairwise decor clearances, 8 district quotas and exact road coverage.
