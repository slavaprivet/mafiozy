# Building activity slots — lifecycle audit, 20 September 2026

Read-only production audit for Artist18/root. No production or transport edits.
Building capacity is a shared admission resource; it must not change physical
entry, shopping authority, actor identity or committed trip destinations.

## Resource identity

`npc_resident_building_access.mjs` returns native door IDs as
`native:${entry.instance.id}`, plus `instanceId`, `sourceKind`, `sourceId` and
`sourceAliases` such as `business:coffee`. `assetId` describes a model/type and
must never be used as the capacity key: separate print shops remain separate
buildings. Display names and bare numeric source IDs are also unsafe.

Use physical `instanceId` as the native building key so multiple entrances of
one building share the same capacity. A corresponding legacy entrance can map
through an explicit unique source alias. Keep the source kind namespace
(`bank:42` differs from `business:42`). If an alias has multiple physical
instances, do not silently merge all buildings or use last-writer selection.

Important existing limitation: native `records` may contain repeated same-ID
entries if `getEntries()` supplies multiple entrances for one instance, while
`byId.set(id,...)` retains only the last entry. `_residentDoorBySource` likewise
is a single-value alias map. These are unsuitable as a general many-entrance
identity registry. This audit does not claim current runtime has such duplicates.
The available 78-building snapshot has no duplicate nonempty gameplay bindings;
runtime bindings and streamed replacements still need explicit coverage.

## Exact lifecycle hooks

| Hook | Slot action / condition |
|---|---|
| `_maybePlanResidentBuildingVisit` after choosing `door`, before `_clearNpcRoute` and `_civilianRouteTo` | Reserve once. Repeated pending slices reuse the same claim and door. Capacity failure is not geometry failure: do not write `_failedDoors` merely because full. Try another eligible destination/activity without destroying a valid current walk. |
| Same function, no candidates / missing retained door / definitive route failure | Release planned claim for the abandoned target; retain while `_routeSearchPending`. A changed chosen target must release the old key before reserving the new key. |
| `_residentEnterBuilding(npc,now,door,respawn=false)` | Final admission/claim before native `_residentNativeVisit` creation and before legacy entry animation. Existing own claim is idempotent. `respawn=true` is population emergence, not a customer visit; bypass customer capacity. |
| Native `entering → browsing` in `_residentNativeVisitTick` | Promote reservation to active visit / renew ownership. This transition precedes `_residentCommerceArrive`; do not charge money on reservation. |
| `_residentCommerceArrive` / `_residentCommerceTick` | No new slot allocation. Shopping uses the already admitted physical visit. Payment/receipt remains exactly once and only while browsing. Cancelled/interrupted purchase must not debit. |
| Native `browsing → exiting`, panic/interruption | Keep physical occupancy until outside. A cancelled plan does not mean the actor has left the room. |
| `_residentNativeVisitTick` dead/alive=false/downed branch | Release activity claim before clearing visit; never move or revive the actor. Corpse collision/medical ownership remain separate. |
| `_residentNativeVisitReleaseUnavailable` | Release claim before discarding unavailable visit and resuming ordinary life. |
| Native physical exit completion | Release before choosing bench/next activity. New recovery also completes through this branch; invalid exit target must not invent a position or pretend it exited. |
| `_civilianPlanCancel` | Release a planned, unoccupied claim before its `seek_shop` early return. Keep occupied native/legacy visits pending physical exit, except dead/removed owner. Existing bench release remains independent. |
| Legacy `_residentEnterBuilding` adds `RESIDENTS_INDOORS` | Preserve claim across the array transfer. Final `NPCS.splice` in `updateNpcs` is not actor removal. |
| `_updateResidentsIndoors` completes legacy exit | Release when the actor physically/source-exits and returns to `NPCS`; respawn actors never hold customer claims. Door re-selection for legacy safe respawn does not transfer shopping reservations. |
| `maintainNpcPopulation` removal / `initNpcs` reset | Release owner claim on actual removal; clear registry on population reset. Reconciliation must consider both `NPCS` and `RESIDENTS_INDOORS`, not just the visible array. |

For bounded cleanup, retain active occupancy while an owner is legitimately
inside, even if a long exit obstruction exceeds a nominal lease. Planned leases
can expire on inactivity, but queue waiting/valid progress renewals must be
defined; otherwise new slots can be oversold while the original 15 still arrive.
Use owner object/generation as well as ID to avoid a removed actor releasing a
replacement actor's claim.

## Trip destination handoff — transport owner boundary

Transport implementation is in `civilian_parking_trip_source.js` and mirrored
in `world.html`; the transport owner must coordinate changes there.

- `_civilianTripNativePlan` chooses `job.doors[job.doorIndex]` and writes
  `trip.destinationDoor`, journey goal ID, and lane `to.buildingId`.
  Reserve capacity when committing that destination, not only after driving.
- Lane expiry/replanning can preserve the same destination. It must reuse the
  same reservation rather than reserve again or silently choose another shop.
- `_civilianTripRelease(trip,'arrived')` first replaces the civilian plan with
  `seek_shop`. Its caller immediately assigns `walk_to_shop`, the exact
  `t.plan.goal.door`, and `tripDestination:true`. An arrival release must
  transfer the building claim through this brief plan replacement, not release
  and race to reacquire a full slot.
- Release on terminal cancellation, death, loss of ownership, abandoned
  destination or failed journey. Do not release for temporary lane pending.
- `_maybePlanResidentBuildingVisit` currently protects `tripDestination` and
  returns `destination-pending` if the retained door is absent. A capacity
  fallback must explicitly end/defer this commitment after safe car exit;
  merely filtering the full door from candidates risks permanent waiting.

## Suggested bounded tests

1. Reserve 15 slots at shop A, including duplicate calls by existing owners.
   The 16th resident selects shop B, a free bench or a real walk; no standing
   route-pending flag or extra claim is fabricated. Release one A slot and
   confirm a later retry can choose A without a stale geometry blacklist.
2. Two entrance IDs sharing `instanceId` jointly admit at most 15. Two physical
   shops with the same `assetId` admit independently. Native/legacy aliases of
   one actual building share occupancy; ambiguous aliases fail explicit mapping.
3. Pending directed route across many frames owns one reservation. Definitive
   failure releases it; full-capacity rejection causes zero planner calls.
4. Full shop → bench unavailable → walk → capacity retry: actor keeps moving,
   bench reservation is not leaked and shop reservation stays zero until accepted.
5. Native real print-shop entry/browse/payment/exit: one claim, one debit/receipt,
   release after outside; recovery and unavailable adapter release correctly.
6. Death, downed, panic, cancelled plan, unloaded doorway and actual removal:
   no stale planned claims. Panic while physically inside retains occupancy
   until exit; death cancels activity without deleting its corpse.
7. Legacy NPCS → RESIDENTS_INDOORS → NPCS transfer preserves one claim throughout;
   respawn=true does not consume customer slots or require an empty shop.
8. Native car trip reserves destination A, survives lane-replan and arrives:
   `destinationDoor`, lane building ID, `plan.goal.door`, `_residentDoor`, civilian
   `doorId`, and capacity key all refer to A; one claim survives arrival handoff.
   Interruption/death releases it; temporary pending never switches silently to B.

No GPU, browser or full-scene performance run was performed for this audit.
