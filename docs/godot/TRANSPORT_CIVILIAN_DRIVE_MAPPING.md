# Civilian drive intention: read-only source mapping

Source: assets/maps/city_rebuild_v1/civilian_parking_trip_source.js,
SHA256 460b197ee52c2facf2b63cdc8d4877aaa6314257ebaccda30459b50bcde2fabc.
This is an integration contract audit, not native drive acceptance.

## Admission and atomic reservation

Lines 232–266 select existing CARS only. Eligibility requires current membership,
parked state and no pending parking, ambient driver, civilian trip, gang, convoy,
static, wreck, tow/dispatched tow, hijack, driver/owner identity, player driving,
police or emergency model. Parking NPC-owned cars are excluded separately.
Grid rebuilds after 500 ms or changed CARS length; candidates recheck current
eligibility and retry time. Radius is strictly below 12 source tiles (49.2 m),
maximum eight candidates, stable source traversal order on equal distances.
At most four intention attempts per source frame; at most sixteen native trips.
These limits are distinct from two planning jobs / four ms per frame.

Real current access is queried before reservation, then the outside door is
checked against resident body policy. Registration (lines 10–11) atomically
excludes another trip for either exact car object or exact resident object.
Only successful registration permits civilian-plan cancellation/route clearing.
The new phase is planning, not seated and not driving.

## Required owner providers

* NPC owner: admitted mutable logic identity, life generation, exact agenda
  wants-drive result and health/activity interruptions; pending initial placement
  cannot be treated as admission.
* Vehicle owner: ordered complete same-session CARS view, current source flags,
  source identity mapped to admitted native ID/life generation, model and
  positions; generations are native guards, not source JS fields. No new IDs.
* Parking owner: actual parking NPC bindings, slot reservations, destination
  access lots/anchors, full current overlap view and cancellation lifetimes.
* Access/navigation owners: actual outside/seat coordinates, front_left identity,
  resident body-pass and directed door corridor checks, water/restricted zones,
  retained approach search, lane request/touch/cancel and authorized sweeps.
* Clock/scheduler: shared source frame and monotonic now; attempt and planning
  budgets remain separate. Missing provider means migration PENDING, not no candidates.

The actual agenda source lines 83–87 treats a definitive false TryDrive result
as unavailable when no retained route/owner is pending, and advances its queue.
This includes source attempt-budget rejection. Preserve that actual behavior
once all providers execute; the migration PENDING barrier above applies only to
missing authority/providers and must not be confused with a source false result.

## Existing transport seam

transport_logical_host already binds session/life generations, current vehicle
roster, approach_world_pose, seat_world_pose, begin_board, advance_hold,
complete_transition, cancel and driver. Its boarding claim represents physical
boarding; it must not be used as the early planning reservation above. A separate
trip reservation must retain exact NPC/car lifetime and be reconciled on owner
replacement, interruption, removal and session disposal. Driver control can be
granted only after actual seat occupation and current source binding readiness
(source lines 66–76), not merely an agenda reservation.

Source door corridor ignores only its own vehicle, retaining all other solids,
water and restricted-zone gates. The source fallback approximate seat coordinates
are not a valid native authority substitute. Host must use actual descriptors and
current transforms. Planning failure/retry preserves source agenda completion
semantics; no generic wander fallback is authorized by absent native drive AI.

No runtime, common Git or GPU changes were made by this mapping. Source execution
oracle and native reservation component remain the next bounded implementation.
