# Decorative junkyard worker movement — 2026-09-10

The three `junkyard_worker_*` rows were generated from fixed time-derived loops inside snapshot collection. They are decorative source actors, not server-owned NPC combat entities. That existing distinction remains: no damage, rewards or new authoritative simulation was invented.

Their stable identities, looks and routes now belong to `_junkyardFootWorkers`. `_tickJunkyardWorkerFootMotion` runs in the existing `_tickWorldLife`, moving at the peaceful NPC speed with dt capped at 0.1. Each step uses existing source/native body and segment checks. At an obstruction the worker waits without changing position or catching up to an absolute clock. Authored positions initially inside a solid/water are withheld until safe; they are not teleported to another point. Snapshot collection only reads visible stored actors and never invokes BFS or advances their movement.

`test_junkyard_worker_collision.mjs` passes: stable object/ID, body-safe wall/car stop, 60-second interruption without catch-up teleport, clear-path resumption, source tick ownership and read-only snapshot. `test_civilian_purposeful_plan.mjs` passes including syntax validation of all ordinary inline scripts.

Related police test correction: its old contention fixture stood far enough from the wall that the new 1.8 m/s peaceful step remained clear and correctly needed no route. The fixture now starts just outside the expanded wall and asserts that the start is clear; the next real step requires navigation, preserving the deferral assertion. `test_police_foot_navigation.py` passes: 12 arrivals, 0 overlaps, 18 route plans.
