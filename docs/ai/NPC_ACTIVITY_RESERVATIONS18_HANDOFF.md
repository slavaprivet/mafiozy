# Building activity slots — 20 September 2026

Production helper: `assets/maps/city_rebuild_v1/npc_activity_reservations_source.js`.
Root owns all `world.html` hooks. This helper does not manage existing bench or car reservations and does not create NPCs, buildings, purchases or source IDs.

## API

- `_npcActivityReserveBuilding(owner, key, {now, leaseMs=30000}={})`: boolean. Pending claim, idempotent for the same source object and canonical building key. A full alternative returns false while preserving an existing reservation; caller explicitly cancels an abandoned destination. Already-inside actors cannot reserve a second place until exit/release.
- `_npcActivityEnterBuilding(owner, key, {now}={})`: boolean. Uses the same slot; pending plus inside together never exceed 15. Can atomically admit a previously unreserved actor only if capacity is still available.
- `_npcActivityReleaseBuilding(owner, key=null, reason='released')`: boolean. Explicit exit/death/cancel, with optional key guard; capacity immediately reusable.
- `_npcActivityBuildingCount(key, options={})`: pending plus inside count. Expired/dead entries of this building are pruned first. Optional lifecycle options trigger global authoritative pruning.
- `_npcActivityBuildingReservation(owner)`: copied `{key, phase, since, until, enteredAt}` or null.
- `_npcActivityPruneBuildingReservations({now, owners, isPresent, isPending, isInside, buildings}={})`: released count. `owners` and `buildings` are Sets. Optional predicates receive `(owner, key)`; `isPresent` also receives phase. Explicit false invalidates ownership. `isPresent` takes priority over `owners`.
- `_npcActivityBuildingReservationSummary()`: counters and current building/owner/pending/inside counts.

The caller chooses a **nonempty string identifying the physical building**. Resolve native aliases before calling; do not key only by a shared prototype/source ID when several physical instances exist. The helper performs no lossy alias merging. NPC owner identity is the actual stable source object, so reused string IDs cannot steal another object's slot.

## Required integration

Reserve before committing the destination/route. A refused claim means choose another available activity/building. Refresh a still-active pending reservation before its 30-second lease expires. Enter at actual physical entry and release only once physical departure is complete. Panic does not itself mean an inside actor has left; include entering/exiting occupants in the authoritative inside predicate.

Call explicit release at death/cancel, and call global prune with the union of exterior and interior source actors on a bounded lifecycle tick. Leaving `NPCS` for an interior is **not removal**. Conversely a deleted source object/building must disappear from the supplied authoritative sets. No helper can infer this from an isolated object reference; omission of the authoritative context would leave an inside record indefinitely, because active inside records intentionally have no time expiry.

Global prune is linear in current reservations. Repeat-owner refresh is constant time; new admission/count examines at most the target building's 15 slots. No timers, polling, per-frame object allocation for active records or quadratic global sweep on each resident claim.

## World adapters

Added to the same helper, without editing `world.html`:

- `_npcActivityDoorKey(door)`: native `instanceId`, fallback `id`; normalizes the existing `native:` prefix. Legacy doors use a separate `legacy:` namespace. Never merges by prototype `sourceId` or unproven `objectId`.
- `_npcActivityDoorAvailable(owner,door,now)` and `_npcActivityClaimDoor(owner,door,now)`: canonical identity plus admission and temporary stalled-door exclusion.
- `_npcActivityEnterDoor(owner,door,now)`: physical entry, boolean; keeps the same reservation.
- `_npcActivityCancelPending(owner,reason)`: releases only pending, preserving physical occupancy.
- `_npcActivitySlotsTick(now)`: throttled to 250 ms, uses the union of `NPCS` and `RESIDENTS_INDOORS`. Reads current doorway registry for aliases but does not infer deletion from an empty/streamed registry.

Tick promotes/preserves native entering/browsing/exiting or legacy `_residentIndoors` occupancy. An inside death/removal or completed physical exit releases the slot. Pending claims must still match a selected doorway and active `building_entry` route/search or committed walk-to-shop plan. Non-purposeful actors use their retained `_residentDoor` while following a building-entry route. Newly made claims have a one-second setup grace period before abandoned-target pruning.

Pending leases refresh while the goal is committed. Actual position changes, advancing indices on the same route, or expanding the same A* search count as progress. No progress for 45 seconds releases the claim; search progress alone without any physical movement cannot retain a place longer than 120 seconds. A stalled door is then excluded for that actor for 15 seconds, so repeated per-frame claim calls cannot immediately recreate the same indefinite hold. Long physically moving trips are unaffected.

`node assets/maps/city_rebuild_v1/test_npc_activity_reservation_adapters.mjs`

PASS: physical alias canonicalization, independent same-prototype instances, moving pending claims, timeouts/cooldown, non-plan actor route, abandoned goal, native entering/exiting, empty streamed registry, legacy indoor actor absent from exterior array, death and removal. Adapter CPU workload for 288 actors / 300 lifecycle ticks: p50 0.342 ms, p95 0.631 ms, max 0.886 ms. Controlled source-field fixture; full `world.html` hook integration and LIVE remain separate checks.

## Verification

`node assets/maps/city_rebuild_v1/test_npc_activity_reservations_source.mjs`

PASS: 16th claim refused, pending plus inside total 15, idempotence, atomic transfer refusal, immediate reuse after exit/death/hp-zero/removal/cancellation, inside non-expiry, pending expiry, building deletion, object identity and separate physical instance keys. Performance fixture: 288 residents in 24 buildings, 300 refresh/prune frames, every third resident inside: p50 0.327 ms, p95 0.463 ms, maximum 2.136 ms. Initial quadratic version measured ~29 ms and was replaced before handoff. These are isolated source-helper CPU measurements; production lifecycle hooks, full-scene FPS and LIVE behavior remain root's integration check.
