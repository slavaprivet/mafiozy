# Gameplay migration stage: integration contract

This module is executable but **not installed in the running game**. It creates detached records from the real old registries, preserving IDs, names, prices, interior links and arbitrary non-world metadata. It does not mutate MAP, storage, server state or input records. No new generated building boxes are created.

## API

```js
import {prepareGameplayMigration, resolveMigrationIdentity} from './gameplay_migration.mjs';
const migration = prepareGameplayMigration(ledger, {
  mode: 'isolated-preview',
  persistence: 'disabled',
  serverSession: 'isolated-preview',
  registries: {banks: BANKS, businesses: BUSINESS_POIS, pois: POI},
  dynamicProperties: null // or serializable exported snapshot, suspended unchanged
});
if (!migration.ok) throw new Error(JSON.stringify(migration.errors));
const stage = migration.stage;
// stage.registries.banks / businesses / pois: 3 / 10 / 17 detached definitions
// stage.services: recursively translated declared world anchors
// stage.serverAnchors: business XY, major RC, bank RC, service XY manifests
// resolveMigrationIdentity(stage, 'major:casino') === lookup 'poi:casino'
```

`ok` proves the identity transform only. `readyForWorldPlacement` and `readyForMain` remain false. The host must satisfy all `requiredHostGates` before publishing. Main mode, persistence enabled, or a non-isolated server session are rejected. A caller-provided label does not itself implement network/storage isolation; the host must actually enforce those boundaries.

The ledger's missing placements for 22 non-primary records are not invented: they remain `deferred`, explicitly **not instantiated** by this adapter. Rail, buses, gas, hydro homes, special HQ and candidate civic assets require their owning adapters. This is an incomplete isolated scene, not proof that the full city's facilities were migrated.

`business:port` and `poi:port` currently share planned (145,43); both survive and produce `DISTINCT_IDENTITIES_SHARE_DESTINATION`. Separate placement/footprint checks must resolve this before activation. `major:*` are aliases for five `poi:*`, not five additional meshes. `business:casino` remains distinct from `poi:casino`.

## Exact client hook points and initialization order

Line references are from the inspected source; locate by the stated symbol after concurrent edits.

1. **Choose native mode before the first `buildMap()`** (`world.html:7990`, function at `6242`). The rebuild branch must use the new topology compiler's grid and return without running the old generator. Do not append it at the end of `buildMap()` or add another Stage-A surface overlay. Gate both this call and the server-size rebuild at `world.html:27152`; a hello must never restore the old city over the new grid.
2. The old build call precedes `BUSINESS_POIS` (`42801`) by a large distance. Do not reference that lexical constant from an early hook: it is in TDZ. Safe bootstrap has two phases: early native terrain only, then migration after all three definitions exist but **before spawning actors or the renderer's first snapshot**. Alternatively move only a serializable authoritative registry bootstrap earlier in a coordinated change. Module import alone cannot fix this ordering.
3. Run the detached transform against the actual `BANKS` (`6024`), `POI` (`6872`) and `BUSINESS_POIS` (`42801`). Stage source anchors must match. Attach explicit geometry/door/vehicle approach receipts, test full footprints against topology and protected envelopes. Do not write tile1 at all old bank/business coordinates first.
4. Preserve `JAIL_CENTER_R/C` (`5804`), `policeComplex` (`5903`), `policeAdmin` (`5935`), custody/intake and original red bridge. Topology compiler takes the exact old protected cells; use the ledger's immutable envelopes, not just one center cell. This module checks planned primary anchors against envelopes; it does **not** certify full GLB footprint or paths.
5. Commit registries as one bootstrap step, preserving IDs and each record's other properties. If retaining const arrays, replace their contents (not lexical bindings); better, initialize from the accepted stage before consumers. Rebuild `POI_BY_RC` (`6915`) and `BUSINESS_BY_RC` (`43303`) only after placement. Coordinate-key maps cannot distinguish coincident entries, so conflict resolution is a prerequisite; never deduplicate the canonical ID registry.
6. Rebuild `_bankTileSet`/`_gasTileSet` (`6030`), `MAJOR_CASINO_WORLD_TILES` (`6919`) and actual footprint/door indexes from accepted sites, rather than translating old boxes blindly. Bank entry uses `_bankDoorCoord` (`63300`) and `enterBankInterior` (`63467`); fixed business entry uses `_businessInteractionAnchor` (`43319`) and `enterBuildingInterior` (`62212`). Preserve interior-local coordinates and cooldown/owner IDs.
7. Service constants must consume migrated anchors: `FIRE_STATION_R/C`, `JUNKYARD_R/C` (`11057`), plus hospital respawn/transfer; keep police unchanged. Recompute `_fireTruckBaysCache`, `_towTruckBaysCache`, `_policeResponseBaysCache` (`11682`) from the accepted road graph. Do not let the new service buildings use old depot coordinates.
8. **Do not run old scatter:** `buildMap`'s modulo-10 building fill, east-neighborhood fill, hardcoded beach/race/pier/ship rewrite (`6500`), `_installTrafficEdgeRoads` and `generateBeachDecor` (`6519–6520`); standalone `generateLairDecor` (`7999`, call `8086`). Also gate authored legacy-coordinate replacements, campus overlays and old map-bound scenery installers in native mode. Only explicitly migrated/placed assets may activate; do not borrow a suppression receipt for a removed legacy ID.
9. Reset `_threeBuildingBlockCache` before any `getWorldSnapshot` (`67574`, cached building parts at `67599`). Use a fresh startup for this first adapter, not a hot reset while gameplay is running. Actor initialization at `world.html:23229` (`initNpcs/initCars/initCityCops/initPets/_ensureSpawnSafe`) must wait for migrated anchors plus validated walk/drive spawn points. Existing `initCars` (`17321`) road assumptions require a road-graph adapter; do not spawn them on the new map merely because registry migration passed.
10. **Renderer barrier:** before `three_preview.js:398` first `getWorldSnapshot`, install native MAP, footprint/collision receipts, services and placeable assets. `defsFromSnapshot` (`1551`) and `buildingDefs` (`1575`) must not create new random boxes/fallback city when native terrain has no building parts. Gate `addNeighborhoodSurfaces` (`2374`) and `addMapCollisionVisuals` (`2396`) against native mode/actual topology. `loadedBuildingKeys`, `neighborhoodSurfaceKeys`, `mapObstacleKeys`, pending sector builds and old static mesh groups require a fresh renderer startup; an appended snapshot does not delete stale meshes. `scheduleSectorLoad` (`5167`) must use only the same native source.
11. Publish a bootstrap generation/version after all gates pass, then start actors and rendering once. A failed stage leaves the old bootstrap intact; it must not half-move three registries and leave server anchors behind.

## Server synchronization points

The module emits a manifest, not a live server patch. Production writes remain blocked by unknown ownership/crosswalk coverage.

- `mafiozi_bot.py:7087` BUSINESS_WORLD_POS and `_preview_ws_server.py:78` PREVIEW_BUSINESS_POS use **(x=c,y=r)**. `stage.serverAnchors.businessWorldPosXY` has that order. `npc_empire.py:262` BUSINESS_COORDS uses **(r,c)**; derive from `stage.registries.businesses` explicitly, never assign the XY tuples there.
- `mafiozi_bot.py:16638` World.MAJOR_OBJECTS_DEF and preview major definitions use **r,c**; patch coordinate fields only from `majorObjectsRC`, preserving names, bosses, guards, income, capture state and five original IDs. Armed-assault range checks must see the same coordinates as the client.
- `mafiozi_bot.py:16350` HOSPITAL_X/Y and `_preview_ws_server.py:104` PREVIEW_HOSPITAL_X/Y use service `respawn:central-hospital`; the module preserves the old (-3,-3) offset relative to hospital. East hospital transfer at `mafiozi_bot.py:19432` needs the new service anchor as well. Validate the resulting spawn/vehicle surface before acknowledging the manifest.
- `mafiozi_bot.py:16435` NPC_CUSTODY_JAIL_X/Y and police administration/gate/intake remain unchanged. This includes nested handoff/inside/preferred stop, not only POI police (76,76).
- Banks retain `small/medium/large`: `bank_robs[bank_id]`, cooldown/guards, `_BINT[size]`, existing heist history do not acquire new IDs. World spawn anchors may move; interior-local plans must not be translated.
- Unknown `apartments_owned`, `npc_empire_holdings`, custom player HQs/doors and active NPC ownership cannot be remapped from the 101 eligible candidate keys. The preview stage preserves any supplied snapshot as suspended data and does not rekey it. Main requires a complete authoritative snapshot and reviewed one-to-one identity/site crosswalk, including server anti-cheat/interior ownership relations, before enabling any production adapter.

## Verification

`node assets/maps/city_rebuild_v1/test_gameplay_migration.mjs` reads the actual host literal arrays without executing world code. It covers IDs/interiors/economics, five aliases, nested anchors versus interior-local coordinates, XY ordering, unchanged police/custody/envelopes, dynamic snapshot preservation, missing/stale/duplicate records, protected destinations, main/save/server rejection and deferred facilities. No browser, game runtime, server, database or common source files are modified by this package.
