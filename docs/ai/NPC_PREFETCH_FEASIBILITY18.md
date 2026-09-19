# Resident continuation feasibility — not part of applied v5

20 September 2026. Read-only production analysis. No production integration.

The user comparison with police has a concrete code basis:
`world.html::_movePoliceFootCop` attempts one collision-checked direct step
toward an existing goal before requesting BFS. It can start moving immediately
on an open segment. Ordinary `pickNpcWaypoint` instead needs to discover a
complete outing (minimum depth 8/net distance 6 source units where available),
then publishes that full path. These are different task/goal contracts; copying
police direct pursuit into free resident wander is not an equivalent fix.
Previously rejected direct-ray/turning-probe approaches are not proposed again.

Preparing a future wander path while walking is possible using separate search
state anchored at the current path's final endpoint. Calling `pickNpcWaypoint`
on the live resident is unsafe because pending search writes `tr/tc=current`
and `walking=false`, and route preparation clears/replaces path state.

Constraints for any future implementation:

- Preserve the current physical path until arrival, along with stable future
  origin, actor policy, plan version, resolver generation and previous origin.
- Shops, benches, threats, vehicle boarding and other owners take priority.
  Do not replace their endpoint decision with a prepared random outing.
- Current final arrival tolerance is 0.4 source units (1.64 m). Exact-endpoint
  adoption needs a scoped arrival rule or an independently checked connector
  from the actual reached point; it cannot silently assume endpoint equality.
- A shadow search driven only by distant resident cadence loses the two-frame
  FIFO lease. Making hundreds of shadows full-rate work increases contention.
- A low-priority spare-budget pump using `_npcReserveRouteWork(now,null)`
  respects the same CPU limit and existing urgent FIFO. However, if urgent FIFO
  stays continuously nonempty, prefetch does no work. It therefore does not
  resolve the main measured mass-wait bottleneck by itself.
- Revalidate the first physical body/sweep connection and goal reservation at
  adoption. Discard on changed task, death, panic, route replacement or obstacle.

An isolated contract prototype was completed before the root requested scope
closure: `npc_wander_prefetch_prototype18.mjs` and
`test_npc_wander_prefetch_prototype18.mjs`. It is unreferenced by production.
Its one-actor actual-pavement test verifies unchanged live route/pose while
preparing, urgent FIFO priority, endpoint-only adoption and task cancellation.
It does not demonstrate population throughput or a useful gain under load and
is explicitly excluded from v5 acceptance. No further benchmark is scheduled.

Next useful step is runtime classification in the existing full game: source
frame cadence, pending route age/expansion, current owner/early-return reason,
actors actually moving over a sampling window, and live native collision cost.
Do not add population or shadow jobs before that evidence identifies the
remaining dominant cause. Whole-scene performance has not been measured here.
