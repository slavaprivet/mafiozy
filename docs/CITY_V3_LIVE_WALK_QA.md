# City V3 — live walk QA and art gap gate

Date: 2026-09-05

Scope: local Stage A preview, `previewcityv3=stage-a`, Three.js renderer. This is a release gate for promoting the new city to `main`; it is not a planning illustration.

## Current verdict

**FAIL — do not enable City V3 by default yet.**

The City V3 contract is rendered as an extra geography layer while the legacy ground, buildings, NPCs, traffic, spawns, collision map and props remain authoritative. This is why the preview badge says City V3 while the player still sees and traverses the old city.

Accepted planning inputs are now stricter than the current preview: `city_street_infrastructure_v2` contains 320 map-wide lights with a measured maximum of 19 in the gameplay camera, while `city_environment_diversity_v1` defines the rural greenbelt, five forest clusters, routed trails, three beaches, seven small crossings, three fountain classes, eight district decor zones, the single existing dump upgrade and addressed-demolition rules. These are input contracts, not proof that the live renderer consumes them.

Observed runtime evidence:

- City V3: 4 landmasses, 8 districts, 8 water bodies, 54 rendered arterial segments, 102 shoreline segments, 5 parks.
- City V3 artist building instances: **0 by default**; the explicit local triple gate
  `preview=1&previewcityv3=stage-a&cityv3buildings=1` now loads exactly **2** accepted
  facade replacements (pawnshop and print shop).
- Legacy scene: 63–68 streamed buildings, only 12 initially synchronized.
- Legacy street furniture: about 389–393 street lamps and 55–56 signal locations selected from 221–224 legacy grid candidates.
- Collision telemetry: 6 visual/collision footprint mismatches in the sampled scene.
- Train/rail runtime: absent from the playable Stage A scene.
- Train diagnostics: no train object, station state, dwell timer or train-related runtime telemetry is exposed in the live Stage A scene. This is a confirmed missing runtime layer, not a camera-placement issue.
- Browser console: no JavaScript warning/error was emitted during the sampled route; the failures are world ownership, placement and art-quality failures.
- The first authored-building attempt failed closed because dynamic imports resolved under
  `/preview/assets/...`. The contained `/assets/buildings/city_v3/` route and no-store module
  response now fix that preview-only resolver. A fresh live walk validates both pinned assets
  with `loadedBuildings:2,replacedPlaceholder:2,overlap:0`, no load rejection, exact authored
  entrance markers (`7.76,66.90` and `97.86,46.08`), and no sampled police/ambulance body
  overlap. This is evidence for the opt-in facade slice only, not permission to enable City V3
  or these assets in production.

### Independent placement-overlap audit

The placement-v2 package's aggregate `0 overlaps` result is not sufficient for live promotion because it did not reject all authored road and station-platform layers. Independent oriented-footprint checks found:

- Only the pawnshop and print shop candidates currently clear every tested building, water, road, rail and platform layer.
- HQ, poker club, gun shop, bookmaker and chop shop footprints cross authored road centerlines.
- The strip-club candidate crosses the Southside night-station platform (`ST-SS-NIGHT`): about `0.210 m²` at the body and `10.801 m²` at the pad.
- Existing placement rows also contain building-body conflicts `OL0050 ↔ CE0005` (about `0.036 m²`) and `EA0076 ↔ C-SCHOOL-01` (about `7.524 m²`).
- The current civic-hall vertical slice must reject any adjacent legacy footprint; suppressing its addressed placeholder alone is not enough when the corrected model footprint extends outside that old shell.

Therefore the six conflicting accepted-building placements remain blocked until their transforms are corrected and re-audited. A successful replacement must be atomic: validate all layers, install the new root, then suppress exactly the addressed legacy visual/collision/door; any failure leaves the old building unchanged.

The two current accepted assets are facade-preview slices, not completed businesses. Their
authored `E` entrances route to the correct replacement shells, but the interior remains the
generic purchasable-building flow. The package also carries 279 visible meshes and has not yet
passed a production LOD/streaming/mesh-merge budget, so production activation remains blocked.

## Live route findings

### Spawn / industrial center

- Spawn starts beside a building interaction volume and movement can immediately press into a building footprint.
- Old buildings, old traffic and old property markers dominate the frame; City V3 is not visually legible as a new map.
- Repeated box buildings and floating labels create clutter while large parcels remain empty.

### Preserved red bridge / jail

- Legacy bridge access telemetry reports `ped0` and `car0` blocked samples, so the old bridge path is traversable.
- In the live camera, the bridge is not convincingly tied to the new river banks; large flat ground areas visually continue around it.
- Bridge approaches need authored road joins, sidewalks, guard rails, shoreline transitions, signals and lighting sockets from the City V3 graph.
- Preserve the current police-station gameplay location beside the jail; improve its 3D exterior, vehicle bays, signs and entrance clearance in place rather than relocating the POI.
- The live `Полицейский участок` interaction currently reads against the much larger prison complex, so the station needs a distinct civic silhouette and an unmistakable public door without changing its coordinates.

### Port / coast

- Street lamps are visibly spawned in water and along arbitrary empty points.
- The main port structure is a large plain white rectangular placeholder.
- Piers are flat slabs without a complete edge, bollard, ladder, crane or service-road language.
- Containers are simple colored blocks without enough shape/detail variation.
- Water layers show different colors and hard polygon seams; shoreline has no consistent wet edge, foam, rock, sand or quay transition.
- The beach/port road is oversized and lacks a complete lane, curb, sidewalk and crossing treatment.

### Residence / southern residential coast

- The residence interaction points at a cluster of generic blocks rather than a readable mansion/residence landmark.
- Very large flat parcels have almost no driveways, fences, hedges, retaining walls, gardens or elevation changes.
- Dark and light water layers meet with visibly different material language.
- Lamps repeat across empty parcels and close to water with no pedestrian-route justification.

### North-side market

- The market is too small to read as a district anchor and is surrounded by repeated generic buildings.
- Roads lack continuous sidewalks, curb corners, crosswalks, stop lines and service/loading pockets.
- Empty colored district polygons read as debug surfaces rather than finished neighborhoods.
- The tallest tower overwhelms nearby low blocks without a graduated skyline.

### East-side hospital

- The hospital exterior is still a generic compact block.
- Ambulances and civilian cars appear in loose stacks without authored bays, markings, drive aisles or a protected emergency entrance.
- A fresh 1280×800 live walk at `previewmajor=hospital_east` shows four emergency vehicles queued bumper-to-bumper in a normal through lane while more cars occupy the unmarked hospital parcel. Give ambulances a one-way service loop, separated arrival/departure bays and a no-parking throat before promoting this district.
- The surrounding skyline repeats the same black-roof rectangular tower at nearly identical height and facade rhythm. Break the block into a hospital campus, one medium mixed-use edge, smaller residential/service buildings and planted setbacks instead of another dense tower cluster.
- A large uninterrupted grass rectangle sits between towers without paths, curb access, planting beds or furniture; it reads as an unfinished debug parcel rather than useful green space.
- Several traffic signal groups sit in open paved areas without corresponding lane geometry, stop lines or crosswalks.
- Street lamps occupy road interiors and empty plots instead of a sidewalk edge graph.

### Existing city dump / jail edge

- Keep the existing `Городская свалка` gameplay destination; do not create a duplicate dump.
- The live dump currently reads as a few repeated rubble/campfire islands inside an oversized paved grid, not as a complete municipal facility.
- Give it one controlled truck entrance, weighbridge/guard booth, sorting shed, compacted waste berms, recycling piles, fenced hazardous corner, service loop and planted visual buffer toward housing.
- Repeated residential blocks crowd its identity, while the nearby jail/water edge and loose vehicle stacks make the route hard to read.
- Lamps and signals around this edge must follow the actual service road; standard road poles are forbidden in water and inside dumping/vehicle operating areas.

### Demolition and replacement rule

- Legacy placeholder houses may be removed where an approved landmark, road approach, station, park, forest trail, beach facility, service yard or required sightline needs the parcel.
- Clear only the authored parcel plus access/visibility envelope; never erase a whole district as a shortcut.
- Every removal must have an explicit replacement or public-space purpose and preserve a usable pedestrian/vehicle connection.
- The matching legacy renderer, collision footprint, marker and interaction anchor must be suppressed together so no invisible or doubled building remains.

### Night lighting

- The night profile enables only a bounded subset of point lights, but the visible pole placement remains the main problem.
- Submerged and off-route lamps still glow, amplifying the placement error.
- District-specific lighting hierarchy is missing: arterial, residential, historic, port, beach and station lighting currently read as one repeated system.

## P0 runtime gates before City V3 can become the default map

1. **World ownership:** City V3 must replace, not overlay, the legacy ground/building/road-prop layer inside the feature flag.
2. **Authoritative navigation:** pedestrian, car, service, police, ambulance, fire and NPC routing must consume the City V3 land/water/road/bridge contract.
3. **Cars stay on roads:** no normal vehicle center or footprint may enter water, grass, beach, park, building parcel or rail-only space. Test all portals and a sustained traffic simulation.
4. **Connected bridges:** every separated landmass that is meant to be road-accessible needs a complete road graph path across a bridge, including approach grades and collision.
5. **Terrain traversal:** slopes, stairs, retaining walls and shoreline drops need explicit pedestrian/vehicle grade rules; visual height and collision height must match.
6. **Safe spawns:** player, NPC and service spawns must start on a validated walkable/drivable socket with clearance from buildings, water, tracks and props.
7. **Rail gameplay:** a visible train must follow connected rails, stop at the contracted stations for exactly 4 seconds, expose boarding/exiting, and never share an unprotected road tile.
8. **Artist buildings:** import the verified smooth-clay building instances with their entrance, pad, collision and service sockets; placeholder boxes must be suppressed at those parcels.
9. **No building overlap:** validate every active building OBB plus pad, entrance and service corridor against legacy footprints, other artist instances, roads, water and rail. A new GLB may suppress only its addressed placeholder, and only after the asset loads and passes eligibility; loader failure must leave exactly the old building, never two buildings or an invisible collision.

## Street-light and signal acceptance gate

- Reject the 1,648-lamp draft. Target **280–420 lamps for the whole map**, with no more than **55 visible** in a normal gameplay camera.
- Arterials: approximately 28–36 m spacing; local streets: 36–48 m; alternate sides unless a specific plaza, station or bridge needs symmetry.
- Standard road lamps are forbidden in water, beach sand, rail clearance, vehicle lanes, building entrances, driveways and undeveloped parcels.
- Parks and beaches use sparse low pedestrian fixtures, not standard road poles.
- Signals come only from semantic road-graph nodes. Current hash sampling (`junctionHash % 4`) is rejected.
- Every signalized approach needs a correctly oriented head, stop line, crossing geometry and compatible phase. No signals on alleys, dead ends or empty slabs.

## Required smooth-clay art kits

- Unified animated sea/river/canal water and shoreline transitions: sand, rock, quay, retaining wall, foam and wet edge.
- Port: authored terminal/warehouse, detailed containers, cranes, piers, bollards, ladders, service roads, boat and jet-ski ramps.
- Roads: modular asphalt, curbs, sidewalks, curb ramps, zebra crossings, stop lines, markings, drains, manholes and guarded rail crossings.
- Street furniture: district lamp variants, traffic/pedestrian signals, bollards, barriers, hydrants, bins, benches, shelters and signs.
- Terrain/parcels: smooth slopes, embankments, cliffs, retaining walls, grass verges, gardens, fences, hedges, driveways, parking bays, trees, shrubs and rocks.
- Forests: instancing-friendly dense and sparse tree clusters, undergrowth, clearings, stumps, fallen trunks and boulders; collision stays on trunks and large rocks while paths remain readable.
- Forest trails: curved walking paths with forks, boardwalk sections, small creek bridges, trail signs, overlooks and rest clearings; never generated as straight debug strips.
- Civic plazas: large central, neighborhood and park fountains with animated water sockets, seating rings, planters and pedestrian clearance.
- Zone-authored decoration: awnings, planters, café furniture, bins, bicycle stands, kiosks, street clocks, local signs and district-specific small props, all placed from sockets with a camera-density cap.
- District identity packs for North Hills, Old Town, Central, Chinatown, Southside, Eastside, Iron Harbor and Gold Coast.
- Rail: track, sleepers, switches, signals, crossings, platforms, shelters, station signs, depot and train exterior/interior.
- Services: readable police, hospital and fire variants with functional bays and route-clear entrances.

## Promotion sequence

1. Add City V3 loader/contracts behind an off-by-default feature flag.
2. Replace legacy map ownership and pass navigation/collision smoke tests.
3. Import verified building/parcel instances and suppress matching placeholders.
4. Add contract-driven street infrastructure at reduced density.
5. Add rail/train/stations and run the complete route.
6. Perform live day/night walks in all eight districts plus car, ambulance, police and train journeys.
7. Enable City V3 by default only after all gates pass; keep the previous renderer/map rollback available until the next stable checkpoint.
