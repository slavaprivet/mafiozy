# Native resident visit recovery — APPLIED, 20 September 2026

Owner: Artist18 subagent idle_route_audit. Root applied the reviewed candidate
to `world.html`. Subagent owns these tests/fixture/documentation only.

Read-only source audit found no generic cadence freeze: pending wander and
directed searches run every accepted source frame. The actual inline cadence
preserves elapsed time at 5/10/20/30 Hz. A separate unbounded ownership problem
exists in `_residentNativeVisitTick`: unavailable door access returns `true`
forever, invalid inside target has no exit transition, and blocked exiting has
no alternative route.

Staging transform: `test_npc_visit_recovery_candidate18.mjs`.
Verification: `node test_npc_visit_recovery18.mjs`.

Applied behavior:

- After 3 seconds of missing door access, a resident at the saved physical
  outside point abandons the visit with an 18-second retry cooldown. The actor
  identity and actual coordinates remain unchanged; ordinary life resumes.
- A resident already inside walks back to the same saved outside point, even
  if the access adapter is temporarily absent. Every segment still checks the
  normal body footprint, terrain, water and continuous authored-solid sweep.
- A blocked exit switches after 3 seconds to the existing native directed
  planner, with a 768-node bound and the existing global FIFO/4 ms budget.
  The root separately raised admissions from 2 to 8; the time budget is unchanged.
  Recovery consumes exact path corners, with a one-second retry after failure.
  A genuinely sealed room remains physically blocked until a route exists;
  no teleportation, deletion, obstacle bypass or invented exit is allowed.
- Death/downed state releases recovery; stun preserves its original ownership.
  Invalid indoor targets trigger exit using the saved outside position.

Evidence: baseline keeps unavailable outside visit owned after 6 seconds;
candidate releases it. Analytical blocked direct exit uses a 6.39-source-unit
detour, maximum movement 0.02 source units per 50 ms tick. Full obstruction
causes zero displacement, then removing it allows completion. Unloaded inside
adapter, death, stun and invalid indoor coordinates are covered. Invalid outside
return coordinates do not fabricate a position or move the actor. The baseline
unavailable-door branch is restored only inside the VM; applied verification
loads the actual production recovery helpers through the shared fixture.

Limits: timeout case uses the real hospital fixture. The detour cases use the
actual production planner with an analytical obstacle field. This is not a
whole-city LIVE result or a frame-rate measurement, and this smaller trap is
not established as the principal cause of mass resident idling.

Applied acceptance: `test_npc_visit_recovery18.mjs`,
`test_npc_native_visit_stall_audit18.mjs` (six actual building GLBs, including
hospital), and `test_npc_postexit_audit18.mjs` pass. Normal and initially pending
post-vehicle hospital visits complete their physical entry/browse/exit; recovery
car exits reach the sidewalk and continue walking. Legacy source visit test
now verifies a normal 2-second door wait; indefinite unavailability belongs to
the recovery regression instead of being assumed mandatory behavior.
