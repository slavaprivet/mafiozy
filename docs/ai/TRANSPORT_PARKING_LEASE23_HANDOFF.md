# Transport3 — expired route parking reservation, 23 September 2026

Status: IMPLEMENTED / CPU TESTED. LIVE and loaded-scene performance are NOT verified.

## Confirmed defect and fix

`_civilianTripMaintainLane` discards `car._civilianNativePlan` after a worker
route lease expires during approach or drive. Previously it kept that plan's
destination bay reservation. If replanning selected another bay, the old bay
was no longer reachable through the new job or trip goal. Finishing/releasing
the trip cleared only the new bay. Other NPCs then saw an empty bay as reserved.
The admission cleanup does not repair this when its queue is empty.

The expiry branch now releases its bay only when its reservation still belongs
to this exact source car, before discarding the plan. Actual vehicle overlap
still prevents using a physically occupied bay. Source NPC/car identity,
seated state, destination intent and braking/replanning behavior are retained.
No collision, route, speed, door or ownership rules are relaxed.

Runtime scope:

- `assets/maps/city_rebuild_v1/civilian_parking_trip_source.js`, only `_civilianTripMaintainLane`.
- Identical change within `world.html`'s `CIVILIAN_PARKING_TRIP` block.
- `assets/maps/city_rebuild_v1/test_civilian_parking_lease23.mjs` is the new regression.

Coordinator20 was notified of the exact shared block before editing. Checker2
confirmed Astra6 is limited to presentation-only work and does not overlap.
Other existing world hunks were retained. No commit/push, no new GPU tab.

## Regression evidence and cost

New regression executes actual source lease, reservation, attachment, admission
and release functions. Worker replies and clearance are controlled boundaries;
this test is not a geometry or rendering acceptance test.

Before patch, both approach and drive cases retained one abandoned reservation
even after selecting another bay and releasing the trip; the test FAILED.
After patch, both free the old bay and finish with zero reservations: PASS.
Additional checks cover a valid lease, board/exit/parked phase guards, another
reservation owner, and a physically occupied bay after expiry.

The rare expiry handler was measured in 30 batches of 1,000 invocations:
CPU p50/p95 before **0.000470/0.000751 ms**, after **0.000539/0.000805 ms**.
These small timings are noisy local CPU measurements, not a full-frame A/B.
Added work is one map lookup and deletion only on actual route expiry.

Actual geometry/source lifecycle passed before and after:

- Short trip **248.413 m**, approach → board → drive → parked → exit →
  walk_to_shop → entering → browsing → exiting → walk_to_bench.
  After: 12 boarding frames, 12 exiting frames; same actor/source identities.
- Long async-worker trip **901.275 m**: same full lifecycle; a real vehicle
  obstacle blocks the route for six seconds, then the same driver resumes.
  All moved car edges are swept against actual geometry. No GPU renderer.
- Short harness CPU p50/p95 before **0.0615/0.1323 ms**, after
  **0.0660/0.1419 ms**. Long after **0.0607/0.1135 ms**. Separate test runs,
  not a controlled loaded-scene performance comparison.

Other PASS: `test_civilian_native_trip_contract.mjs`,
`test_civilian_route_progress_controls.mjs`, helper syntax, all seven world
scripts through `check_world.py`, world/helper exact block parity, diff whitespace.

Before helper snapshot retained locally at
`.git/ai-pipeline-local/live23/civilian-parking-before23.js`.
Reproduce former failure with:

```
node assets/maps/city_rebuild_v1/test_civilian_parking_lease23.mjs --source=.git/ai-pipeline-local/live23/civilian-parking-before23.js
node assets/maps/city_rebuild_v1/test_civilian_parking_lease23.mjs
node assets/maps/city_rebuild_v1/test_native_parking_lifecycle.mjs
node assets/maps/city_rebuild_v1/test_native_parking_lifecycle.mjs --long --async
```

## LIVE and off-road follow-up — not resolved by this patch

The referenced `npc-inspection-checkpoint23.json` has actors/routeReplay and
npcWorld but does not include native vehicle route jobs or civilian trip
history. It does show resident/car bindings, including local_vehicle_4 planning.
The `startBlocked: off-road` report alone does not identify the root cause:
native routing explicitly permits a short departure apron even when the start
is off-road. Do not claim this reservation fix resolves those routing failures.

Requested bounded additional evidence from coordinator20:
native vehicle route `from/to/shape`, civilianTrip history/job.trace and the
preceding lane worker failure reason, saved as
`.git/ai-pipeline-local/live23/transport-before23.json` if available.

Only coordinator20 owns the LIVE game18538. Requested scenario: reload when
the shared build is ready; observe one resident from approach through parking,
exit and next activity; retain NPC/car IDs and phase/time/distance evidence.
For an actual expired-route event, check the abandoned bay can subsequently be
reserved by another car while the original driver replans safely. If no expiry
occurs, record this as a normal-cycle check, not proof of the rare branch.

**Производительность общей сцены не проверена.** LIVE/FPS and off-road diagnosis
remain open with coordinator20; no claim that the whole living city is complete.
