# Native topology compiler v1 — separate from the running city

`topology.mjs` is a pure deterministic compiler producing a new **200-row,
180-column** grid. It never accepts an old grid, imports gameplay code, mutates
the source or starts a browser/server. It has no buildings, NPCs or vehicles.

Tile IDs: water16, grass8, sand14, sidewalk9, road0, bridge19. Exact police
preservation cells may carry their existing host tile values. Base terrain is
grass, water is polygon union minus islets, sand/plaza are explicit polygons,
roads are finite-width polyline rasters. Roads never overwrite water without
an explicit car crossing. Sidewalks never overwrite water or existing roads.

Red bridge is exactly **rows47–56 and columns80–100 inclusive**: 210 cells.
Its source centerline and immutable police anchor76,76 are verified. No security
radius is inferred from `security_envelope_grid:6`.

## Input extensions required for an executable source

```js
road.width_grid = 3; // full drivable width; no default is invented
road.sidewalk_width_grid = 1; // optional width on EACH side; absence means none
crossing.envelope_polygon_grid = [[79,130],[102,130],[102,134],[79,134]];
crossing.road_ids = ['A-SOUTH']; // other roads cannot borrow this permission
green_public.big_beach.polygon_grid = /* explicit sand boundary */;
```

Line-based pedestrian boardwalks also need a polygon. Police is a separate
host argument `{policeProtectedCells:[{r:76,c:76,tile:...}, ...]}` containing the
actual protected footprint, including the anchor. Above is a schema example,
not permission to preserve only one cell. The host owns the exact ledger.

**Submerged car tunnels are rejected**: paving them with bridge19 would replace
water with a fake surface bridge. They require a later multilayer routing
representation and cannot be silently flattened into this surface grid. Rail
crossings are not car permissions and are not instantiated by this compiler.

## Validation and output

- Polygon bounds, area, self-intersection, inclusive boundary point-in-polygon.
- Road endpoint bounds, explicit widths, source ID uniqueness.
- Actual finite-width road footprint versus water and bound bridge envelopes.
- Additional source centerline water diagnostic at0.2-grid sampling pitch
  (diagnostic, not a proof of exact continuous geometry or vehicle clearance).
- Exact police cells and red bridge, road conflicts with police footprint.
- Four-neighbor connectivity of the produced road/bridge grid; cell counts.
- Same-input same-output and frozen input immutability tested.

Any finding gives `status:REJECTED, grid:null`. Analysis counts remain available
but do not constitute a playable or approved candidate. Valid synthetic fixtures
give `CANDIDATE_TOPOLOGY_ONLY`, which still requires host migration/live testing.
This compiler does not certify vehicle turning radii, district gameplay,
water navigation, bridge visual models, elevation or emergency response times.

## Actual agreed v3 source: REJECTED, not PASS

The source handoff explicitly says `PLANNING_CONTRACT_NOT_LIVE`, staging-only
fingerprint and requires current-main reconciliation. Reading its reported
planning audit PASS does not waive executable topology checks.

The current unmodified source yields:

- 207 roads without physical widths.
- 55 road centerlines with water crossings outside supported explicit envelopes.
- Missing south-bridge envelope, beach polygon and boardwalk polygon.
- Northern submerged car tunnel cannot be represented as surface bridge.
- Exact host police ledger is not supplied yet.

An example is `L-NO-V-008`: consecutive points `[31.91,8] → [32.06,32]` span
Pine Crown Reservoir. Filtering intermediate water points in a drawing does
not break the polyline into disconnected segments; the connecting segment
still crosses the reservoir. Planner must reroute or explicitly bridge it.

## Commands

```powershell
node assets/maps/city_rebuild_v1/test_topology.mjs <source-contract.json>
node assets/maps/city_rebuild_v1/build_candidate.mjs <source-contract.json> <police-ledger.json-or-dash> <new-output.json>
```

The CLI pins the exact source SHA256 and creates output exclusively (`wx`);
it refuses overwrites. Exit2 means the artifact is a rejection report, not a
runtime map. `source_v3_rejection.json` records the current missing-host audit
and detailed road coordinates. No existing city files are changed.
