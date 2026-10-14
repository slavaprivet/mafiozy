# Source pedestrian retry23 — ownership-preserving proposal, not implementation

Artist21 read current actual source after service customer ACCEPT and return
proposal handoff. No World/Walk/navigation edits. Traversal owns classifier,
motion/edge probe; root owns common Walk host and GPU. Coordinate additions with
Traversal before writing another motion/probe implementation.

Current verified: Walk lines529–530 still register npcNativeNavigation.query
straight into source, with no pedestrian-edge branch. Native directed A* is in
npc_native_directed_route_source.js, loaded as the matching World implementation.
Four-ms/eight-actor route admission already exists. It does not preserve an
incomplete physical edge. Existing boolean helpers cannot receive pending safely.

## Minimal independent source boundary

Add a DISTINCT tri-state helper only for migrated callers. Never change the
response type of existing mode:sweep or reinterpret pending as clear/blocked.
The helper owns ONE active retry per search/execution cursor, keyed by actor
object+source ID, search object+epoch, exact endpoints/referenceY, height,
swimming/ignored vehicle, current movement owner, resolver identity and site/support
revision. Keep retry tokens private on that context. Pending pauses without
publishing path or consuming an expansion, goal candidate, movement delta or
failure backoff. Source death/body replacement/cancel/goal drift/movement owner
change/resolver replacement discard context; later requests start from scratch.

Use existing route admission before probe call. A single Walk probe per frame
shares the hard cap; never create one per NPC (that would multiply the cap).
beginFrame belongs beside native support/collision cache resets, before source
updates. Two budgets remain: wall-clock source A* slices and counted motion work.
A pending caller must remain eligible for the existing fair cohort on next frame.

## Required resumable program counters in CURRENT directed A*

1. Short-direct preliminary sweep: retain direct phase on pending, not null it.
2. Short-direct final connector: terminal motion certificate and live native body
   sweep are distinct; do not endlessly restart the long physical edge here.
3. Goal-anchor discovery: advance discovery.index only after a terminal edge.
4. Isolated-start probe: advance probe.index only after a terminal edge.
5. Popped-node terminal connector: preserve current node without closing/discarding
   it when connector is pending; only a terminal block may delete a goal anchor.
6. Neighbour expansion: preserve current node + next direction index. Current
   code marks cur.closed=true before the loop, so a simple early return would
   permanently lose unexplored neighbours. Close/charge expansion exactly once.

The fine-grid fallback must discard old edge context with its old startKey and
start a new epoch. Cancellation and _setNpcRoute/_clearNpcRoute must not leave an
execution token that can be reused by another movement owner.

Wander, panic/snitch, empire final connectors, and native visit/service movement
are later separate callers. Do not claim citywide physical integration after
only directed A*. _npcPathPassable keeps its boolean contract until each caller
has a pending branch. Native movement must retain actual waypoint corner precision
(.34cell early switch remains for non-empire today) and supported reference Y.

## Endpoint guard repaired by Traversal (23 September update)

The defect described below is historical and fixed by its owner. Current frozen
passability SHA B2A5CEC94D28B9F358F564D28A2E53D5C695C1B3998144A26D08C4255A4AD10C;
integration contract 61F4742CF649A81FF55774064B16ACE1BD7CB26B11311C19D1EA619CB8601505;
edge probe 08EA42D7208E13F1F02CF00F275B7BE2737504673EFDC3A041927D6347F45523.
Owner reports21suites PASS: endpoint_storey_mismatch and actual zero-edge support/
capsule check, max376/512 work for long32.8m edge. Do not duplicate this repair.
Source resumable integration remains output-only work, not applied.

Owner clarification after the service pilot review: current Walk has NO
authoritative NPC storey/foot-support resolver. npcSupportCache is opt-in only
referenceY=0 and calls two-argument groundHeight; npcNativeNavigation does too.
First admissible scope is certified exterior ground, plus explicitly certified
building floor with source footY/referenceY and matching site/support revision.
Unknown upstairs/storey/footY must holdunknown; never turn a ground-only sample
into evidence for an actor's upstairs support. The actual renderer's current
foot position alone cannot certify unseen source bodies or search anchors.
Keep a separate pedestrian-edge mode; current boolean hook remains unchanged.

Additional owner repair CONFIRMED: outputs/npc_edge_zero_budget23_readonly.mjs
uses current motion/probe with distinct zero-length edges in one shared frame.
36 edges consume504 units; the37th still invokes motion.route and reaches518,
then reported terminal work_contract_exceeded. Guard owner now reserves14 before
the call, yields pending when remaining<14, and rechecks next frame. Edge probe
new SHA42a7bab538d54e6cda341fd4e6291835ea3432b923bee6e73e143120307803cd,
test0dfad24d1dd9c6c9bb83fc97eabdc2989554c2ecebe3c9fc46349ed424fc2fc0.
Readonly reproduction confirms504pending/no additionalwork, then14clear nextframe.
Owner reports12suitesPASS; long32.8m60chunks/30frames max376/512 unchanged. This does not
affect service pilot: it does not use this new edge helper.

Current exact read-only source boundary: world SHA272a22667e1c075962b9a9164e408595e94b1d1edc659fae6b441cb07ec99a79,
Walk6b2420671578c67235ee2ba364eca84bdbcca7f80da9fb0c19161f0e27411479,
directed A*825d7ad7f17d3aa764474feb844ee6893cf6c86b9cb9478cf1bfb781a2982db6.
NPC directed A* lines41/52 are direct preliminary/final sweep;
78-81 goal discovery advances index before edge;93-94 start-isolation probe
also advances first;105-116 pop/close/terminal;120-124 neighbour expansion.
Pending-safe rewrite needs one retained current node, terminal phase and next
direction index. Close/charge once only after terminal/required neighbours reach
terminal results; no heap re-pop, skipped neighbour or duplicate expansion.
All body/door checks still run fresh on final connector and real movement.

### Historical reproduction

Read-only actual shared-motion repro outputs/npc_edge_target_height23_readonly.mjs
shows current frozen edge probe signs to.y but does not pass it into motion.route
or check it at terminal return. From y0 -> requested y3 is reported clear with
accepted.y0, for both coincident XZ and .41m horizontal displacement. Coincident
XZ also performs zero support/occupancy work. Traversal has been notified. Until
its API is clarified/revised, source must not interpret terminal moved:true as a
requested-storey arrival. Require accepted endpoint height/storey consistency and
current full-body occupancy; reference height must come from actual source support,
not ground-only fallback for upstairs actors. Do not silently snap source Y.

Partial edge certificates also span frames. Dynamic door/car/body movement after
a previously accepted chunk requires current connector/body validation and normal
movement-time sweeps. A geometry revision that changes every vehicle frame would
instead starve all long probes; keep immutable support/site revision separate
from dynamic current occupancy. Traversal/root must agree that division.

## Acceptance before production

Use actual shared motion/probe for <=512work/frame, long32.8m continuations,
multiple actor fairness, every cancellation identity, reversed direction, changed
storey/referenceY, body replacement, moved door/body, invalid/missing resolver,
no fallback after pending, and no skipped A* neighbour after resume. Re-run actual
source native visit/resident service routes and source parking foot legs. Vehicle
road/access semantics stay separate. LIVE and loaded-scene p50/p95/calls remain
root acceptance; pure fixture PASS is not citywide readiness.
