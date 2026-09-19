# Actual civilian lifecycle CPU QA — 13 September 2026

Files: `assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs` and `test_civilian_native_lifecycle.mjs`. Run `node assets/maps/city_rebuild_v1/test_civilian_native_lifecycle.mjs --frames=1500` in a coordinator-approved CPU window. JSON: `outputs/npc_civilian_actual_lifecycle_20260913.json`.

The fixture loads the actual compact sedan GLB and hospital GLB through production building-entry/door/floor code. The existing `integration_candidate_snapshot.json` remains unchanged: authored buildings/decor plus generated decor, parking and road colliders feed the native geometry. It executes the real source pedestrian planner, route advancement, ordinary foot movement branch, trip scheduler/car/boarding ticks and visible visit state machine. No `_civilianRouteTo` or `_npcAdvanceRoute` success substitution. Native road targets, vehicle route/sweep and lane service are real helpers. Starting positions are initial fixture placement on physically checked dry ground, never a mid-trip relocation.

## Reproduction and correction

The first 500-frame run reached approach, 12 boarding frames, a 39.10 m drive, 12 exit frames and walking toward the hospital. At 1500 frames it stayed near `r9.438435,c163.500000` with `route-blocked`, instead of reaching the actual entrance `r9.3569846,c164`.

The source `_civilianRouteTo` applied the body radius twice: it passed `_npcBodyPassable` into `_npcPathPassable`, which expands the body again. Failure also left a coarse partial route. The civilian-visits owner separated point/body predicates and cleared a failed partial route; geometry was unchanged.

After that production fix, the complete chain passed in 784 frames (39.2 simulated seconds): planning → approach → board → drive → parked → exit → walk to shop → entering → browsing → exiting → next task. The unchanged source NPC remained present and damageable. Door opening consumed 13 frames; visible browsing consumed 82 frames. The car travelled 39.0957 m, foot/transition movement 34.5843 m. No position jump, duplicate/removal or vehicle movement without its seated living source driver occurred.

Measured source tick p50/p95 in this successful CPU run: 0.0935/0.3015 ms. These are subsystem figures, not FPS. Cold maximum 181.86 ms came from the first lane service request. A separate trace measured cold lane request 117.83 ms including prepared-graph reconstruction 49.31 ms; identical warmed requests took 2.59/1.50/1.02 ms. **The actual walk host already calls `cityRoadNavigation.prepare()` before NPC work, whereas this cold fixture did not. These maxima do not prove a first-NPC gameplay hitch.** A like-for-like prepared fixture measurement remains pending after the shared performance profile.

## Additional closed-door diagnostic and current check status

A negative test querying the entire outside-to-inside segment at once unexpectedly returned clear. Geometry inspection confirmed the target is really behind the door: entry-local outside z=2.1, inside z=-0.8333; leaves occupy source r=10.0288249–10.0820400. Their halves end at c=163.9767184 and begin at c=164.0232816, leaving a small centre seam. The supporting floor is 1.5 m; the leaf vertical range is 1.45–4.295 m. The target or support height is not the issue.

The long `_npcPathPassable` query uses .14-tile spacing with centre/diagonal body probes, which can straddle this thin leaf and seam. Actual low-speed per-frame motion uses much shorter steps; the state machine also waits for actual open fraction. The additional negative test now probes successive actual .02-tile walking steps, not one coarse long query. **This final extra assertion has not yet been rerun:** the coordinator requested CPU idle for the central scene profile. The positive 784-frame result above predates this extra assertion. No collision bodies were removed or modified by QA. A general long-route thin-door sampling review is a separate remaining concern.

## Limits

No GPU scene was opened and no overall FPS/LIVE acceptance is claimed. One actual hospital entrance is covered, not all shops or routes. Runtime railway objects, streamed moving traffic and full-world update are not instantiated. Driver presentation readiness is an adapter boundary input; NPC skinned pose fidelity is covered by separate actor tests. The final next-waypoint callback is intentionally outside this bounded visit cycle. Driver/death interruption regressions are owned and already tested by the trips agent; this QA did not duplicate that suite. The fixture does not exercise authenticated police custody, ambulance delivery or multiplayer rescue.
