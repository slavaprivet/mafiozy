# Ready GLB buildings: isolated walk-preview placement

Generated artifacts:

- `buildings_catalog.v1.json`: **21 asset types / 35 GLBs**, source SHA-256 and byte length checked before byte-preserving copy into `building_models/`. Existing different-hash destinations are never overwritten.
- `buildings_placement.v1.json`: **72 actual fitted instances / 19 distinct types / 43 residences**. No procedural meshes or fabricated 518-building completion count.
- `building_placement.mjs`: pure deterministic planner. `build_buildings_placement.mjs` regenerates the JSON from the exact topology and rich-world source hashes recorded in `inputs`.
- `test_building_placement.mjs`: 13 checks, including every full footprint and corridor against actual terrain/protection masks, pairwise overlap, hashes, renderer transform and unchanged inputs.

All ten latest residential/skyline assets are represented: three urban residences, six rural/suburban residences, one glass tower. All five accepted/next business facades plus GALLERIA are represented. Civic hall, hospital and nightclub each have a visual candidate. The very large fire station (46×38 m including its authored site) has no valid grass-only street frontage under the current topology and remains explicit `unresolved`. The new police model is catalogued but deliberately not placed: existing protected police is unchanged.

## Render each explicit instance

1. Fetch `instance.binding.url`, verify `bytes` and `sha256`, then parse the GLB. Use one model/template per asset with safe clones, not a network load per repeated house.
2. Parent transform: `positionM`, Y rotation `yawDegrees * Math.PI/180`, uniform `uniformScale` (currently 1).
3. Child glTF scene local position: `modelLocalOffsetM`, **before parent rotation**. This centers the measured visual X/Z envelope and grounds its measured minimum Y. Coordinates are glTF Y-up; world X=c×4.1, world Z=r×4.1. Do not re-center a second time with another Box3.
4. Hide exactly the `hideNodeNames` helpers/non-LOD0 groups. LOD0 visual bounds were measured from actual transformed POSITION vertices, not guessed dimensions or manifest axis labels. Preserve authored materials; no random procedural windows or box fallback.
5. `collision.worldBodies` has `polygonCR,minYM,maxYM` in the common renderer/controller format. These are conservative exterior envelopes split around the public approach strip, **not accepted playable interior colliders**.
6. Furniture/landscaping must reserve top-level `footprints` and `doorCorridors`, preferably each instance's `clearance` too. Corridors reach the native road using only grass/sidewalk/road and avoid protected police/bridge masks. Models occupy grass only, never road, beach water or protected bridge decks.

## Meaning and limitations

`artAcceptance: needs_visual_review` is retained for every entry. Source acceptance evidence is separate; technical verification and the user's permission to inspect candidates do not manufacture final approval.

Instances with `gameplayId:null` are visual infill, not newly purchased businesses, player residences or HQs. Stable visual IDs are explicit and deterministic. Existing persistent identity migration is a separate adapter and remains blocked for main. Fixed bank/business/POI sites are only bound to semantically correct types; all failed/missing fixed bindings are recorded in `unresolved`. Current fixed-site fit count is **0**: attractive generic hospital/nightclub visuals elsewhere do not mean those gameplay services moved.

The topology has `pendingHostSnapshot:true`; the scene is an isolated pedestrian walk preview, not proof of production/server/vehicle readiness. No game, server, common renderer or ownership data was edited here. Live rendering and camera/scale inspection belong to the coordinator.

Regenerate:

```powershell
node assets/maps/city_rebuild_v1/build_buildings_catalog.mjs '<latest residential manifest path>'
node assets/maps/city_rebuild_v1/build_buildings_placement.mjs assets/maps/city_rebuild_v1/topology_for_placement.json '<rich world contract path>'
node assets/maps/city_rebuild_v1/test_building_placement.mjs
```
