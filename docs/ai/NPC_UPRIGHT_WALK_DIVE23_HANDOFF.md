# Upright civilian walk and compact real-time dive — 23 September 2026

**IMPLEMENTED / CPU PASS / LIVE visual acceptance pending.** Художник21,
explicit root assignment and file-scope authorization. No new GPU tab, commit
or push. Root owns the only game and all vehicle/fire sections.

## Ordinary walking

Root's observed `npc_resident_111`: civilian, 1.206–1.82 m/s, moving/walking,
not running/cowering/downed/prone, `activity:null`, `gesture:'work'`,
`routine:'work'`, `routinePlan.phase:'seek_shop'`, no seat or vehicle.
That combination does NOT activate a work/sitting pose. The actual NPC locomotion
overlay lowered the pelvis by its worst-case stride requirement on every frame.

`npc_locomotion_pose.mjs` now uses a shorter ordinary walk cycle (leg length ×1.9,
slow walk ×1.65) and derives the required pelvis lowering from the current two
foot targets. The body rises over the planted leg instead of remaining in a
constant squat. Root displacement, distance-driven phase, stance duration, foot
orientation and limb lengths stay under the existing contracts. Running/sprint
retain their separate original stride and pelvis rule. Hero ordinary walk uses
the base hero animation, not this NPC overlay; its posture file was not changed.

Actual male/female rigs with observed111 life flags:

| Metric, ordinary walk | Before | After |
| --- | --- | --- |
| Male pelvis drop | Constant 9.37 cm | 0.40–6.17 cm |
| Female pelvis drop | Constant 9.87 cm | 0.40–6.45 cm |
| Maximum knee flexion over full cycle | 100.8° / 99.5° | 65.2° / 63.4° |
| Intentional crouch | 21.4–24.0 cm | Same |
| Run/sprint pelvis drop | 9.26 / 9.76 cm | Same |

The shorter cycle increases cadence at the same walking speed; root must assess
the visual result in the actual moving scene. Do not claim a visual PASS from
numeric bone/foot tests alone.

## Dive range, height and elapsed time

`hero_jump.mjs`: dive speed 6→4.2 m/s, full immediate dive range4.8→3.36m,
dive arc .8→.42m. Flight .8s/recovery .45s, ordinary jump height1.05m/speed3.5,
radius .36 and double-tap trajectory continuity remain intact.

**.42m is the immediate-upgrade apex.** The second press cannot erase already
gained normal-jump height. At120Hz, second press50/100/200ms gives peaks
.496/.618/.843m; at400–500ms the normal1.05m apex has already been reached.
No instantaneous downward snap was introduced.

Root then explicitly authorized a separate low-FPS timing fix in precisely
`walk_preview.mjs:updateJump(dt)` and its single frame call. The call now passes
`rawDt`; only jump/dive consumes it. A visible frame up to1s consumes at most.25s,
split into at most7 steps of ≤.04s, each running movement permission, support height, ceiling and surface
resolution. Only the final pose/diagnostic snapshot is published once per frame.
Queued crouch/prone still applies on actual contact. Global `dt`, other physics,
NPCs, vehicle movement and fire remain untouched. Traversal retains the old .04s
cap. Excess over.25s is discarded without debt, so .26–.33s city frames continue
advancing. Hidden, invalid or >1s-gap updates freeze without an impulse. Root's
review rejected the earlier >.25s full-freeze threshold; it is fixed, not retained.

Actual source keyboard + updateJump replay:

| FPS | Before full jump wall time | After |
| --- | ---: | ---: |
| 3 | Previously would stall with the rejected .25s gap threshold | 1.667 s |
| 5 | 6.4 s | 1.4 s |
| 10 | 3.2 s | 1.3 s |
| 60 | 1.25 s | 1.25 s |

The last visible completion is quantized to the next frame. Normal range2.8m and
immediate dive3.36m remain equal across those frame rates. A late keypress handled
on the next low-FPS frame may shorten the dive portion of the existing flight.

## Checks and cost

- New `test_npc_upright_walk23.mjs`:16 actual male/female pose cases; neutral,
  crouch, slow, observed111 walking, fast walking, running and sprint.
- `test_npc_locomotion_pose.mjs`: planted stance, no stretch/root movement,
  profession priority, zero warmed THREE scratch allocations. Its reported stride
  now reads actual configured locomotion settings rather than stale duplicated constants.
- `test_npc_population.mjs`:23 lifecycle/motion/cache/source-clock checks PASS.
- `test_hero_jump.mjs`: trajectory/directions, normal-vs-dive, four timesteps,
  walls/water and no second impulse; compact distance/height envelope assertions.
- `test_jump_keyboard.mjs`: actual source input/frame excerpts;3/5/10/30/60FPS,
  held/third press, diagonal equality, queuedC/Z and40 normal/dive collision cases.
  Per-step ceiling/floor, wall clearance, thin forbidden strip centre refusal,
  hidden/2s-gap no-impulse, .26s jitter progress/no-debt and traversal cap checked.
- `test_jump_transition_pose.mjs`:14 weapons/1348 real GLB poses, continuity,
  skin floor clearance, gaze/grips, no bone stretch/root teleport.
- `test_landing_posture.mjs`:60 actual dive→crouch/prone cases, contact, grips and
  continuous280ms landing transition.
- `test_hero_posture.mjs`, `test_surface_motion.mjs`, syntax/scoped diff check PASS.

Collision limit retained: `movePedestrian/circleFits` samples a footprint, not
an exact swept disk. For a synthetic3cm forbidden strip,60FPS dive stops its
centre at .70m before the .75m strip, while a sampled perimeter can straddle it.
The test does not falsely claim .36m full-radius clearance for that thin strip;
solid half-plane clearance and no centre crossing are separately asserted. This
existing movement helper was not weakened or replaced in this timing change.

Matched CPU footplant overlay,50 actual male/female rigs at1.5m/s,40 warm frames
and200 alternating measured frames: p50/p95 .289/.454ms → .282/.432ms.
This is a narrow CPU measurement, not a claimed FPS gain.
Jump performs up to7 existing geometry integrations in one accepted slow frame;
the complete loaded-scene cost still needs root measurement.
**Производительность общей сцены не проверена.**

Reports: `outputs/npc_upright_walk23_baseline.json`,
`outputs/npc_upright_walk23_production.json`, `outputs/npc_upright_walk23_cost.json`,
`outputs/hero_jump_elapsed23.json`.

## Exact production files / root acceptance

1. `assets/maps/city_rebuild_v1/npc_locomotion_pose.mjs`: configure + foot-target
   and walk-pelvis calculation only.
2. `assets/maps/city_rebuild_v1/hero_jump.mjs`: dive constants/comment only.
3. `assets/maps/city_rebuild_v1/walk_preview.mjs`: updateJump and one rawDt call only.

Root should reload together with its current package, follow a calm ordinary
civilian at1.2–1.8m/s, compare intentional crouch/run, then test real double-tap
dive at5–7FPS, including collision and landing. No vehicle/fire section edits
belong to this patch. Runtime scope released after these checks.

Guard candidates are again deferred by the newer user request. Latest isolated
follow-up is still4/6 completed, one no-safe-two-leg rejection and one safe staging
move then `second-leg-blocked`; no guard runtime import or fake post arrival.
