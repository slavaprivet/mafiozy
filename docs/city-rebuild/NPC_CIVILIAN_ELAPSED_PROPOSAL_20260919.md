# Civilian routine elapsed — connected source patch, pending LIVE reload

`npc_civilian_elapsed_source.js` is connected to `world.html` as the next independent source patch. The existing cadence function, hero, vehicles and global physics dt are unchanged. Targeted tests and world syntax pass. No browser reload or GPU test was performed; the currently open game still requires a later coordinated reload to receive this patch.

## Evidence and policy

The accepted-frame global clamp `if (dt > 0.1) dt = 0.1` discards simulation time below 10 FPS. Actual source timing/cadence/speed/movement tests give 0.90 m/s at 5 FPS and 1.80 m/s at 10/20 FPS. The reported LIVE `sourceDt=.2049` is a snapshot interval, not an actual simulation-frame duration. The numerical coincidence `1.8 × .1 / .2049 = .878477` does not prove the cause of that LIVE speed. The low-FPS source defect is independently demonstrated by the controlled actual-source test.

The candidate records accepted-frame elapsed before this clamp. It maintains a separate debt only for calm ordinary native `resident_` actors. Source physics cadence is unchanged. On a cadence admission, consume and clear that debt even if another branch then handles the resident. Only the final ordinary `_npcRoutineStep` receives the extended budget; all combat, police, emergency, indoor, vehicle, activity and special-character branches retain original dt. Recheck eligibility at that final call in case a threat starts inside the update.

Limits: at most .35 seconds added per accepted frame, at most .5 seconds held per resident. A frame gap above .5 seconds disables recovery and uses existing capped physics dt. Hidden tab, battle iframe, hit stop, staged interior resume or nonnative renderer invalidate the epoch. A visibility/pageshow reset invalidates it explicitly. No timer based on `now - lastNpcUpdate` is used, so time inside a building or skipped update branches is not mistaken for walking. Only previous helper participants have old shared cadence carry discarded on invalidation; police and other nonparticipants retain their original state.

The normal early FPS limiter occurs before capture, so a frame rejected by that limiter does not add time. Capture belongs before the `_battleOpen`/`hitStopUntil` branch so those skipped updates invalidate rather than accumulate. Interior staged resume is explicitly blocked. The global physics clamp remains intact.

## Applied integration

Load after the existing population helper script:

```diff
 <script src="assets/maps/city_rebuild_v1/npc_city_population_source.js"></script>
+<script src="assets/maps/city_rebuild_v1/npc_civilian_elapsed_source.js"></script>
```

At the accepted-frame dt block, after the FPS early-return:

```diff
   let dt = (t - prevT) / 1000;
+  const civilianFrameElapsed = dt;
   prevT = t;
   if (dt > 0.1) dt = 0.1;
+  _npcBeginCivilianElapsedFrame(civilianFrameElapsed, {
+    native: typeof _walkRendererActive === 'function' && _walkRendererActive(),
+    hidden: document.hidden, battle: !!_battleOpen,
+    hitStop: t < hitStopUntil, resuming: _worldResumeFrames > 0
+  });
```

At the existing NPC cadence admission (keep its dt unchanged):

```diff
   const simulationFrameDt=dt;
   for (const n of NPCS) {
+    _npcAccumulateCivilianElapsed(n,now);
     const dt=_npcSimulationDelta(n,simulationFrameDt,now);
     if(!dt)continue;
+    const civilianRoutineDt=_npcConsumeCivilianElapsed(n,dt,now);
```

Only the final ordinary movement invocation:

```diff
-    if(!_npcRoutineStep(n,dt,n._residentDoor?.native&&n._routeKind==='building_entry'?npcPassableForSnitch:npcPassable)){
+    if(!_npcRoutineStep(n,_npcCivilianElapsedEligible(n,now)?civilianRoutineDt:dt,n._residentDoor?.native&&n._routeKind==='building_entry'?npcPassableForSnitch:npcPassable)){
```

At existing `_resetSticksAndTime` (visibility restore and pageshow already invoke this):

```diff
 function _resetSticksAndTime() {
+  _npcResetCivilianElapsed();
   prevT = performance.now();
```

Also invalidate on hidden transition even if no accepted frame occurs while hidden:

```diff
 document.addEventListener('visibilitychange', () => {
+  _npcResetCivilianElapsed();
   if (!document.hidden) _resetSticksAndTime();
 });
```

The duplicate reset on visible transition is harmless and constant-time. No loop over residents is needed; each participant clears its old debt lazily at the next source update.

## Verification and cost

PASS `test_npc_civilian_elapsed.mjs`: actual production cadence, effective speed, body/path sweep and routine step, both near/far at 5/10/20 FPS. Candidate returns approximately 1.80 m/s for all six cases. Existing input reproduces .90 at 5 FPS. Tests cover hidden/battle/hitStop/resume, 30-second gap, explicit reset, death/new threats/activity/vehicle/interior/special transitions, threat after admission, repeated same-frame call, nonparticipant state preservation, legacy mode and collision blocking of a longer step.

Warm alternating source CPU test on the same 288 calm near residents with the same movement/sweep: baseline p50/p95 1.135/2.186 ms; helper candidate 1.338/2.415 ms (about +0.20/+0.23 ms per 288-resident batch on this run). The helper allocates no arrays, vectors or result objects per NPC; the proposed frame context is one small object per accepted world frame. These are isolated source CPU measurements; complete scene FPS and LIVE integration remain untested. No GPU was opened.

No new animation, global clock, route search or deployment package is included. The hooks shown above are now applied in world.html. Extracted-foot fixtures load the real helper and provide the consumed routine budget. Tests: test_npc_civilian_elapsed.mjs, test_resident_pending_origin.mjs, test_npc_routine_corner_following.mjs, actual print_shop full purchase cycle and check_world.py all pass. Actual accepted-frame hooks are executed by the elapsed test. LIVE appearance and loaded-city performance remain unverified for this patch.
