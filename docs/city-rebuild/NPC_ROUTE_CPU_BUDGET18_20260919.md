# Actual route CPU accounting — Художник18

Status: source/CPU READY; LIVE and complete-scene performance unverified.

The old shared deadline started at the first admitted NPC and ran while unrelated
updates executed. A short successful route could therefore consume the entire
frame's routing opportunity before the next resident was called.

`world.html` now accounts only for admitted search work. All five reservation
owners (directed visits, wandering, panic, police and water egress) close their
slice in `finally`, including early returns and exceptions. The next search gets
the remainder of the same 4 ms. Two admissions, FIFO order, collision geometry,
route frontiers and ordinary frame cadence remain unchanged. An unclosed caller
is charged conservatively at the next reservation; a new frame resets the budget.
An atomic collision query can still overrun the threshold slightly, as before.

Actual-source deterministic comparison (`test_npc_route_cpu_budget18.mjs`):
first route 0.08 ms, unrelated work 5 ms. Before: second route expands 0 nodes.
After: second expands 160 nodes; total routing cost 4.02 ms. This restores unused
routing work; it does not make it free or establish an FPS improvement.

PASS: new CPU budget regression (exhaustion, frame reset, exceptions, five
completion scopes), route fairness, route work budget, route wait lifecycle,
wander first admission, wander continuation, admission-clock regression,
actual townhouse eight approach routes, world inline syntax and melee tests.

The remaining hundreds of queued multi-slice searches still require separate
work. Do not claim the city is accepted until movement is verified in the existing
game. Coordinator18 owns the single LIVE tab and combined reload.
