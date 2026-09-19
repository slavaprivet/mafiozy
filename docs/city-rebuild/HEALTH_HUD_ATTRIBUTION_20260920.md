# healthHud attribution — pending LIVE proof

Artist19 (`01a0bbea-e50a-71f1-b148-e12196d0c102`) reported a warmed, moving
937x920 GTX980 scene following resident131: healthHud mean19.11/p5021.8/p9525.7ms,
renderer mean67.4/p5064.7/p9584.9ms, population update mean5.96ms. NPC pending190/288.
This was NOT a controlled A/B. Figures were relayed by the owner, not measured
independently by this task; they do not prove HUD, picking or NPCs alone cause lag.

## Confirmed source facts

In `assets/maps/city_rebuild_v1/walk_preview.mjs`, the `healthHud` stage includes:
1. `updateWorldWalkHealth()` — also source vehicle refresh and impact presentation.
2. `walkPlayerHud.update()` — its controller throttles normal updates to 200ms.
3. `updateMercenaries()` — showcase/UI plus `mercenaryWalk.update()`.
4. HUD input guard and possible `releaseControls()`.

In `mercenary_walk.mjs`, aim selection uses a 120ms wall-clock deadline. At the
reported 124–134ms frame interval, this can run every frame. `mercenary_targets.mjs`
pick refreshes its registry and recursively intersects candidate roots, followed
by roster/action/selection/task-marker work. This is a concrete candidate, NOT a
confirmed attribution of the 21.8ms median.

Existing `document.documentElement.dataset.mercenaryPicking` reports lastMs,
maxMs and samples. Its lastMs covers guard+pick BEFORE the remaining action and
selection work; maxMs is lifetime/sticky, not p95. Compare fresh lastMs and sample
count deltas with healthHud; do not enable costly `mercenarypickqa` for baseline.

## Next verification

Owner-coordinated narrow timers inside the existing healthHud stage:
`healthSync`, `playerHud`, `mercenaryUpdate`, preserving the aggregate timer.
Use existing probe.measure, unchanged call order/count and no production overhead
when perfqa is absent. Then subdivide ONLY the confirmed expensive component.
Do not blindly lower aim frequency, remove collision/LOS checks or rewrite NPC AI.

Renderer isolation is separately ready: `RENDER_ISOLATION_20260920.md`, local
`perfqa=1&isolationqa=1`, 24 lifecycle tests +3 real target factory cases +30 freeze
tests PASS. It holds 3D presentation only; source AI CONTINUES. Therefore it cannot
exclude source simulation as a lag cause. No controlled subsystem LIVE results yet.

Coordinator18 is handing the measurement window to Coordinator19 at the user's
request. Reconfirm single-game ownership with Artist19 before measurements. This
optimizer task has zero GPU tabs and idle CPU; no health/HUD/mercenary production
changes were made during this read-only attribution audit.

## Follow-up: attribution timers ready, not yet LIVE

Artist19 subsequently reported mercenaryPicking samples3344 / lastMs10.4 /
sticky maxMs46.4 near healthHud~22ms, and requested scoped stage diagnostics.
This single sample supports further investigation, not a rolling attribution of
half the total or proof of the main lag cause.

The existing walk frame now uses probe.measure for healthSync, playerHud and
mercenaryUpdate while retaining aggregate healthHud. Without a probe the original
direct calls run, in the same order with the same arguments; no NPC, picking,
HUD frequency or simulation logic was changed. Measure during normal gameplay,
NOT render-only hold, which intentionally skips these updates. Nested stage
times must not be added to their enclosing healthHud total.

test_health_hud_attribution.mjs: 11 extracted-actual-line cases PASS (order/count,
dt, optional HUD/probe, original exceptions). Existing freeze suite:30/30 PASS;
walk syntax PASS. Await the owner's combined reload and fresh 120-sample windows.

## Candidate audit while awaiting stage data — no runtime patch

`npcPopulation.getActors()` returns latest loaded actors, including invisible
roots (distance/carried/evacuated), up to72 by default, not the entire144 cache.
Three Raycaster does not check Object3D.visible; current picking rejects invisible
hits afterwards. A narrow prefilter of audited NPC roots may save traversal.

`test_mercenary_visible_roots_prototype.mjs`: eight parity fixtures PASS; synthetic
72 roots/12 visible/two meshes each reduce raycast calls144 to24. This is an
operation count, not measured game milliseconds. Far hidden actors are commonly
beyond ray.far80 already, so triangle-cost savings may be small.

Generic filtering is NOT approved: two tests demonstrate hidden custom raycasts
emitting external visible hits or mutating visibility. Preserve hidden canonical
source materials, hit-only ignore semantics, layers, root order/duplicates and
existing matrices. No branch flattening. Wait for actual stage timings before
implementing; do not present this prototype as a completed optimization.

HUD read-only follow-up: controller already throttles200ms; hero portraits check
at750ms and cache signatures, roster loads are queued. Safe binding has a1Hz
guard. These facts do not exclude costs on refresh frames, but are not grounds
for a blind caching rewrite without the new playerHud/mercenaryUpdate measurements.
