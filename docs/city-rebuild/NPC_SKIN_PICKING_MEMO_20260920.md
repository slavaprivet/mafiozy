# Opt-in exact NPC skin picking candidate

## Measured reason

Artist19 v2 LIVE normal camera: one assisted LOS takes 12.4 ms, resolve12.6,
centre11.4. Sorting candidate targets cannot remove this single necessary ray.
Following NPC_npc_unique_marat: centre18.5, resolve0.1; NPC category7.6,
Marat root47 callbacks6.7 ms. These are different cameras, not an A/B.

Current vehicle APIs do not provide a dynamic conservative render envelope.
profile.bounds is initial closed geometry, not safe for doors/damage/debris.
Fresh exact broadphase prototype on32cars regressed p50 1.32→1.80 ms.
Do not integrate it or infer bounds from collisionHalfWidth/length.

## Candidate and boundaries

Native Three180 computes shared indexed skinned vertices repeatedly per
triangle. npc_skin_pick_memo reuses each transformed vertex only inside one
native narrowphase invocation. Float64 values preserve native precision.
No cross-ray/frame/pose reuse. No geometry, animation, population, shader,
weapon or actor-owner edits. Native triangle tests, visibility filtering,
occluders and hit sorting remain authoritative. Custom unsupported methods
fall back; descriptors restore on exception/removal/disposal.

Both actual source GLBs passed rest/articulated parity, including hit data:
male8338 vertices/39102 indices, female8107/37710. Prototype CPU whole-ray
examples: male12.03→5.64 ms, female11.07→5.28. These are NOT LIVE FPS or a
measurement of the full final synchronization/hover workflow.

## Integration and test window

- npc_skin_pick_memo.mjs: helper owned by QA lifetime, default OFF.
- npc_skin_picking_qa.mjs: explicit local perfqa=1&npcskinpick=1 only;
  refuses mercenarypickqa=1 (detailed wrappers bias the timing) and identity
  query parameters. No new scheduled/synthetic rays.
- mercenary_walk.mjs: create/dispose QA, natural whole-hover timing.
- mercenary_targets.mjs: synchronize NPC roots, delegate existing centre,
  assisted, ground and LOS queries; all non-NPC occluders still queried.
- walk_debug_panels.mjs: recognize the dedicated test button.

Use the same existing game through Artist19. Remove mercenarypickqa, add
npcskinpick=1 with perfqa=1. Button "Точный поиск NPC" starts OFF. Keep
camera/scenario matched, collect warmed OFF→ON→OFF natural samples, preferably
120 per mode. Read documentElement.dataset.npcSkinPicking: mode, revision,
windowSamples, p50Ms, p95Ms, lastTargetId, source counters. Check actual NPC
selection plus blocking by walls/glass. Do NOT use render-freeze: its held
frame path does not execute normal hover. Do not compare profiler-on to OFF
as acceleration, or attribute unrelated render/NPC-author changes to this.

Main integration tests PASS: target/LOS parity with an animated skin, glass
material.visible=false versus object.visible=false, wall blockers, disposal;
QA defaultOFF/local gating/rolling120/noextraqueries/mode reset; existing
mercenary walk, target and profiler suites. Helper full workflow verification
and final READY are reported separately by its author. No LIVE acceptance yet.

## Final disk READY

Six suites PASS in main: helper, QA, target integration, existing targets,
walk and detailed profiler. Runtime-helper actual male/female parity12+12
cases, zero guard fallbacks; eight lifecycle/fallback/nesting tests PASS.
OFF sync does not traverse roots/install hooks; disabling releases hooks.
Full sync+intersect on10 actual clones (main rerun, CPU): hit native p50
10.044 ms, OFF9.702, ON5.423; miss native0.026, OFF0.027, ON0.064.
Concurrent test timings are supporting evidence, not LIVE acceptance. ON has
extra scan cost on misses; allocation/GC impact must be checked in the game.

Ready manifest: helper + QA + their two tests + integration target test;
mercenary_targets.mjs, mercenary_walk.mjs, walk_debug_panels.mjs, this handoff.
Prototype-only visibility/dynamic-broadphase/skin experiments are not imports
and need not ship. No commit/push or new GPU game performed by this task.
