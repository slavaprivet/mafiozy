# Printshop physical source roster — isolated proposal

Status: CPU checked, not applied, not activated. No World/Walk production edit or GPU run. Owner: Artist21 body-host subtask.

## Entry point

`servicePhysicalRosterWorldCandidate(source)` in root `npc_service_physical_roster23_patch_candidate.mjs` returns modified World text, preserving its newline convention. It adds a private helper and exactly one bridge method:

```js
bridge.getWalkServicePhysicalBodies23({r, c, radius})
// r/c/radius are finite source cells, 0 < radius <= 16.
// radius is a CENTER query: caller must expand for its maximum body reach.
// Result:
{
  complete, reason, now, sourceFrame, space: 'native-world',
  rows: [{id, aliasIds, ref, r, c, ang, dead, downed, prone, crouching,
    carried, seated, vehicleId, vehiclePhase, generation, authored,
    footY: null, elevation: null, poseKnown, lifeState, deathAt}]
}
```

`reason` exists on failure; rows is then empty and MUST NOT be interpreted as clear. Success is complete source roster membership within the requested center radius, not complete physical pose geometry. No Y/storey/animation envelope is invented. `poseKnown` only says this is an ordinary source foot-root projection rather than a carried/vehicle/unknown crew posture; even true still requires Walk floor and body dimensions, and dead/downed needs the correct horizontal envelope. `ref` is original source object, not a copied rendering wrapper. `ref:null, authored:true` identifies the game's existing authored stand-ins without pretending they are source actors. Regular resident generation is null; employee generation comes from `_stationaryService.generation`. Movement exclusion must bind exact object plus its generation, never just display ID.

## How membership is obtained

The transformer extracts the current actual `getDynamicEntities` source assembly from `let npcSource=_buildingInt?...` up to `const npcLifePool=x=>{`, before radius/72-person/priority filtering. The original renderer method and all subsequent World code stay byte-identical. This avoids a second independently maintained list of NPC families. The independent helper projection adds `_actionRef` to existing wrapper families that lacked it and strips rendering's `||0` fallback for r/c. It includes foot-visible junkyard workers independently of player proximity and carries the beach carried-state forward instead of omitting that body.

The same source predicates inside assembly still define families that exist on foot: for example, parked owners with `state:'sitting'` are absent from `_threeParkingNpcView`; their car belongs to the separate physical traffic inventory. Dead aggro/nest actors removed by their own source family predicates are not resurrected by this bridge. Persistent corpse objects in NPCS and other included collections remain separate source objects until explicit expiry/removal. `getWalkNpcVehicleTraffic`, local fleet and hero must be composed separately by the Walk host.

Death position uses finite `_deathR/_deathC` before r/c. A 60-second replacement does not remove its old body's row; source's existing 300-second corpse predicate remains independent. Downing is distinguished from HP-zero death where source medical/mercenary status supplies that fact. Mercenary vehicle IDs, seat phases and current posture come from existing source fields and read-only `MafioziMercenaries.getMember`; hospital members are absent. No mercenary roster adoption/decorator method is called.

Same source reference aliases collapse, exposing `aliasIds`; conflicting coordinates or distinct references with the same physical ID fail closed. Invalid source positions fail closed even if locality cannot be established. Pending source placement inside the requested radius, legacy `_buildingInt`/`_bankInt` coordinate space, collection exceptions and missing NPCS also fail closed. There is no population cap or renderer model requirement.

The query does not initialize Michael's fallback guards: while that authored group is uninitialized, a nearby query fails closed; once the existing game initialized it, original guard refs are preserved. Canonical existing identity helpers may intern a missing stable ID in their WeakMaps (bus/local NPC), just as the first rendering query would. No gameplay actor is spawned, moved, healed, damaged, removed or assigned a replacement ID.

## Checks

`node assets/maps/city_rebuild_v1/test_npc_service_physical_roster23_candidate.mjs`

14 checks pass using the actual extracted World assembly and actual ID/bus/parking/death/beach helper functions: 120 admitted source bodies; distance filtering independent of player; fresh source mutations; old corpse plus generation-2 employee; exact original refs across side collections; carried/downed/seated flags; stable bus identity; junkyard inclusion; alias deduplication and ID conflict; malformed coordinates; invalid request and legacy room; authored stand-ins; no lazy guard spawn; source exceptions; current mercenary pose and transport binding.

Bounded CPU observation: 384 source residents, 50 warm reads then 200 measured reads, p50 **0.363 ms**, p95 **0.487 ms** on this host. This scans source assembly per call; do not invoke once per unrelated map object. The one pilot can acquire a fresh bounded inventory per physical decision and share it inside that synchronous decision. Recheck before committing spawn/step/door changes after external callbacks. This is not a baseline/full-scene benchmark. **Производительность общей сцены не проверена.** Root owns LIVE and activation.

## Renderer admission anchor (read-only finding)

In `getDynamicEntities`, `const npcLifePool=x=>{` is the narrow place to classify a valid `_stationaryService` body as mission. That alone is NOT a guarantee: `stableNpcSort` prioritizes drivers then sticky IDs, and `criticalBudget=NPC_LIFE_NPC_CAP-civilianReserve` usually allows 48 critical bodies. A valid-service priority before `driverOrder`, or an explicitly reserved source slot, is needed if root guarantees admission. `npcPopulation.getActor(id)` can still lag because of creationBudget=1; source controller must wait on the actual current model before nearby visible movement. No priority/admission edit is included here.
