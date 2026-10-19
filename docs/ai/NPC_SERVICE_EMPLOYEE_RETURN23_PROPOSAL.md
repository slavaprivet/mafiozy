# Employee return23 — isolated addon, NOT APPLIED

Applies after accepted employee source/world proposal and revised customer addon.
Accepted source controller files remain byte-for-byte unchanged; adjacent patch
proposes optional return delegation plus source-owned public access/planner hooks.
Four exact artifact hashes are in NPC_SERVICE_EMPLOYEE_RETURN23_PROPOSAL.json.
No import, registration, activation or Walk change is applied by this package.

createServiceEmployeeReturn23 returns a bounded executor. Calm staff already on
the shop floor follow swept station anchors. A remote staff body first returns to
its ORIGINAL public entrance using the current source planner, kind building_entry
and shared route budget. PENDING holds and resumes; partial route is never arrival.
Paths are copied out of the source planner and its completed route is released.
Movement uses exact waypoints, .005m arrival, full .18cell capsule and <=.35s
consumed delta in <=.05s substeps. No generic .34cell early-corner arrival.

At the public outside waypoint the source opens the real door, waits for ready,
selects the actual entry lane, preserves its offset until beyond the open leaf,
then follows entrance -> customerVia -> technical doorOutside -> work. Every step
checks native geometry/support and rechecks source authority after queries. Ground
outside printshop is .0177m and inside .39m; native terrain/entry support owns this
transition. No body Y write, teleports or changing a shared door's coordinates.

Existing panic/combat/police/reporting/medical/conversation/trip control takes
priority. An interruption invalidates private return state; when calm resumes the
source cancels stale route and selects a new valid return from actual position.
Dead, removed, generation-mismatched or site-stale bodies cannot move. Large gaps
(dt>1) and freshness tick0 do not move. Dispose releases source route only while
its body is still controlled, then permanently disables executor.

Source host hooks are constructed inside proposed World installer AFTER geometry
spread: actual entrance registry, actual public access, _residentNativeEntryLane,
_planNpcRouteTo/_cancelNpcDirectedSearch/_clearNpcRoute. Root must supply
createEmployeeReturn plus employeeReturnGeometry {validateLayout,isCurrentSite,
canSweep,isWorkFloor,groundHeight,hasGround}. hasGround must prove CURRENT source
support and canSweep must preserve full body/terrain/water collision authority;
finite visual height alone is not the live host contract. Controller provides the
current owned/NPCS/role/generation/control guard; host cannot replace that guard.

CPU actual-source/GLB test PASS:
- direct street approach and native planned obstacle detour at15/3Hz (4cycles);
- real source budget pending continuations and ready paths;
- actual temporary collider across entrance stops movement until removal;
- repeated panic halts and then resumes; original entrance crossed, work reached;
- 7 negative gates: dt gap, tick0, site, support, source removal, generation,
  ownership changed inside geometry callback; no denied source movement;
- initial storeroom exit remains physically valid under optional addon.

Comparable idle tick0 CPU, one working source employee, alternating hook off/on,
50 warm +250 samples: p50/p95 .0018/.0024ms -> .0025/.0035ms. Small bounded
measurement only; no full scene FPS claim. Actual loops use GLB/source movement,
but externally controlled panic endpoints are staged by fixture: the complete
world escape/report-police simulation, camera-hidden birth, streamed body coverage,
source binding integration and renderer remain separate root acceptance gates.
Performance of the shared loaded scene is not checked here. Root owns GPU window.

Review-only patch checked with git apply --check against customer-world proposal
and accepted source controller copies. Current runtime remains inactive.
