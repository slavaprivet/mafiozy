# Walk entry controls: removal of legacy proximity entry

Applied by root after Coordinator18 released the snapshot freeze. Applied-source tests pass; reload and visual acceptance of this version remain pending. Earlier staged-only notes below describe the preparation phase.

User clarification: buildings are entered physically through their doors; old entry buttons must be removed, not remapped to new coordinates.

## Cause and exact surfaces

The screenshot's gold job-office button came from `updateGtaInteractions`: old source distance r36/c16 ≤3.5, independent of any rendered Walk building. Gym r26/c26, hospital r26/c46 and the old police r76/c76 had analogous branches. `activateCurrentBuildingEntry` accepted the old MAP tile/guessed entrance and could then enter the old interior. The actual Walk map currently contains no job-office/gym asset; its hospital is at entry r9.902439/c164.

Relevant existing entry surfaces:

- `updateGtaInteractions`: black market, manual special/apartment selection, job/gym/hospital/old police, generic MAP houses. This contiguous block is skipped only in Walk exterior; subsequent NPC/car actions still run.
- `updateZoneBtn`: exterior bank/business/POI zone buttons and their stale click handler. Existing bank-interior actions stay active.
- `_currentBuildingEntryTarget`: old entry marker.
- `_nearbyBuildingInteractionFor3D` and `toggleNearbyBuildingActionsFrom3D`: old generic E/bridge query and activation.
- `_activateSelectedBuildingIfNear`, `activateCurrentBuildingEntry`, `_activateApartmentGuestEntry`, `_activateBankEntryFrom3D`: stale/programmatic ordinary entry bypasses.
- `_gtaBtn` click: direct major-enter branch and stale building/apartment actions.
- `_syncBusinessActionCard`: remove only `building`, `zone` entry actions and GTA entry kinds; retain finance, property guards, ownership and server raid actions. An entry-only empty card stays hidden.
- `_prepareSelectedEstablishmentActions`: do not regenerate the gold major-enter button in Walk. Other major actions remain.

`selectBuildingFrom3D` can still select a property dossier/other actions. Its bank activation and ordinary entry calls hit the protected functions. The native Walk `nearestInteraction → entry.proximity → entry.interact(hero.object.position)` is unchanged. No native door, collision, key-E, car, NPC, mercenary, finance, mission or server-response mechanism is replaced. Battle/raid transitions remain outside this ordinary-entry cleanup by explicit root scope decision.

## Status and verification

Candidate lives in `outputs/artist18_physical_entry_patch.mjs`, a string-to-string transformation that makes no filesystem writes. `test_walk_physical_entry18.mjs` runs it against current world in memory during the coordinated source freeze. Production world is not changed by that test.

The obsolete mapped-native-gold-button candidate was deleted after the user's clarification; it must not be applied.

Candidate test passes all inline world syntax; seven entry/marker/bridge gates reject Walk exterior; old screenshot r36/c16 no longer generates the job prompt; 2D still generates canonical `36,16,job`; stale GTA/zone clicks are inert; car entry still calls its normal handler; existing bank-interior action still executes.

The actual `test_building_entry.mjs` tests the unchanged physical door implementation: opening, physical walk-through, collision and occupied-door rejection. No new GPU scene was opened. LIVE screenshot acceptance and whole-scene performance remain for the coordinator after transfer. Added work is a constant renderer/interior guard; no new per-NPC or per-building scan.
