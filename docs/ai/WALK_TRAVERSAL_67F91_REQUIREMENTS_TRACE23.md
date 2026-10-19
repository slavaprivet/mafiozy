# `/walk` traversal candidate 67F91 — requirements trace and one-tab LIVE gate

This trace is for the output-only candidate
`outputs/walk_traversal_candidate23/walk_preview.mjs` SHA-256
`67F91FC1AB31BD03F428539EA21572D8605A652B38DB8A70861B5B925D490299`
and vertical-navigation candidate
`07735B39D6151EE659F4174124FDE7401ACAEEAAF068D0DFDC05A9A443FB946B`.
Its manifest is `0B85789F9965E4EB1396C3252AFB8457E1A4DED83D5C5BD8CAE349B14C77415C`.
The candidate is not applied to production. Its frozen source and vertical hosts
remain `6B242067...11479` and `6020B709...A1ED`.

## Gate status and observability boundary

The candidate is **source/test GO**: the traversal semantic gate, pose-owner
gate, 30-dependency acceptance manifest, syntax checks and all focused suites
pass. This does not make LIVE accepted.

The current candidate publishes partial evidence through `heroWalk`,
`surfaceMotion`, `heroTraversal`, `heroJump`, `roofNavigation`, `artist14`,
`vehicleFleet`, `carDrive`, `waterInteractions` and renderer performance
datasets. It does **not** publish `document.body.dataset.pedestrianMotion` or
`document.body.dataset.heroMotionPose`. Those two opt-in snapshots are required
by `WALK_TRAVERSAL_TIME_ONE_TAB_LIVE_ACCEPTANCE23.md` to prove route admission,
support identity and pose ownership. Therefore rows needing `ascentMode`,
`nextSpeedScale`, `autoStep`, `capsuleClear`, vehicle support identity, airborne
phase or landing count remain **LIVE HOLD** until the integrated host exposes
those snapshots. Appearance alone must not promote them to PASS.

Use one existing game tab only. Reload that tab once with `perfqa=1`; add
`traversalqa=1` only to show the existing QA panel, but do not press a placement
button because it moves the hero. Reach every fixture by ordinary walking or
driving. Keep the same document, camera settings, population and quality. A
DevTools/dataset read from this tab is not another GPU scene.

At every checkpoint save this read-only bundle:

```js
Object.fromEntries([
  'pedestrianMotion','heroMotionPose','heroWalk','surfaceMotion','heroTraversal',
  'heroJump','roofNavigation','artist14','vehicleFleet','carDrive',
  'waterInteractions','walkPerformance','runtimeFrameError'
].map(k => [k, document.body.dataset[k] ? JSON.parse(document.body.dataset[k]) : null]))
```

The two required new snapshots may update at no more than 4 Hz. During active
movement they fail if absent, older than 500 ms, non-finite, or visibly
inconsistent. Existing once-per-second `heroWalk`/`surfaceMotion` are supporting
evidence only.

## Requirements matrix

| Requirement | Deterministic proof and exact fixture | One-tab LIVE action | Required readout and PASS condition |
| --- | --- | --- | --- |
| Curb / small step | `test_hero_surface_motion.mjs`: 0.32 m box, `moved`, `autoStep:true`, `stepRise=maxRise=.32`, capsule height 1.9 m clears. `test_hero_traversal_world.mjs`: real bridge fixture is exactly 0.34 m and remains support while a 0.50 m barrier does not become a step. | Approach a measured `0.34 ± 0.02 m` curb diagonally, cross it, stop, then walk down the same curb. | `pedestrianMotion`: up is `moved:true`, `mode:step`, `autoStep:true`, `stepRise:0.34±0.02`, plan count 0, `capsuleClear:true`; down is `reason:clear`, `descentStep:0.34±0.02`, no free-fall. `heroWalk.y` and `surfaceMotion.y` agree within 0.03 m. |
| Ordinary continuous slope | `test_hero_surface_motion.mjs`: grade 0.55 over 1 m returns `moved:true`, `ascentMode:walk`, `maxRise:.55` even when the legacy walk mask is false. | Walk up and back down a visibly continuous moderate hill without jumping. | `pedestrianMotion`: `mode:walk`, `ascentMode:walk`, `nextSpeedScale:1`, finite support, no traversal/vertical transition; accepted distance never exceeds request by more than 0.01 m. |
| Steep but physically supported mountain | `test_hero_surface_motion.mjs`: exact grade 1.55 returns `scramble`, speed scale below 1; player/NPC parity. Actual north-ridge fixture starts `(531, groundY, -271)`, direction `(-.1785296178,-.9839345382)`, 0.4 m segment, slope `>1.16`, rise `>.46`. `test_hero_mountain_surface_regression.mjs`: the authored `ridge-ascent` path reaches its summit across 148 segments / 450.504 m. | Reach the north ridge normally, then walk continuously uphill and turn around on the same surface. Coordinates are location evidence, not permission to set the hero position. | Uphill and downhill both report `ascentMode:scramble`; exact synthetic-grade acceptance is `slope:1.55±.03`, `nextSpeedScale:.48±.01`. Actual ridge must report its measured grade and never `collision` solely because the old mask rejects it. Root Y follows support within .03 m; no snap on turnaround. |
| Wall, terrain face, overhang and drop remain distinct | `test_hero_surface_motion.mjs`: 2.3 m wall has no traversal; grade 3.2 returns `terrain_face`; blocked grade 1.55 returns `collision`. `test_hero_traversal_world.mjs`: 3 m wall, unknown-height wall, canopy and 2.05 m ceiling all reject. The 10 m ledge returns player `free_fall` with entry Y still 10, while NPC returns `ledge_drop`. | Walk into a tall wall and an overhang, then approach the measured 10 m edge without Space. | Wall/overhang: `moved:false`, accepted point before contact, no plan, no overlap. Ledge: `mode:free-fall`, `reason:free_fall`, `verticalTransition.kind:free-fall`, fall distance `10±.25 m`, entry Y retained within .01 m and plan count 0. A wall must never become scramble; an edge must never snap Y to the bottom. |
| Vault a low obstacle | `test_hero_traversal_world.mjs`: thin body `(x .55-.75, z -3..3, y 0..1.1)` plans `vault`, completes in ≤160 frames and ends with a clear standing capsule. Generated-world fixture from the frozen test is `explore-bench-2`, start `(168.912563,0,679.512563)`, direction `(0.707107,0.707107)`, destination `(170.906604,0,681.506604)`. | Walk normally to that bench/another measured 0.35–1.10 m low obstacle and continue straight, then repeat diagonally. | Exactly one `heroTraversal` sequence: `kind:vault`, progress monotonic, `done:true`, `blocked:false`, count +1. `pedestrianMotion.traversalPlanCount` is 1 only at admission. Final `capsuleClear:true`; no root enters the body. |
| Mantle a broad ledge | `test_hero_traversal_world.mjs`: broad 1.2 m pedestal plans `mantle`; support remains stable for 180 frames. Generated fixture `explore-planter-35`: start `(116.536190,0,608.498035)`, direction `(-.707107,-.707107)`, destination `(116.069499,1.2,608.031344)`. | Reach the planter or equivalent broad ledge normally and hold forward. | One `heroTraversal.kind:mantle`; final Y equals authored top within .03 m, `surfaceMotion.grounded:true`, no second plan, no legacy-pose double application. |
| Parked-car hood / reachable roof | `test_hero_vehicle_traversal_actual.mjs`: actual `compact_sedan` GLB blocks the capsule, exposes a physical hood/roof plan with destination `.5 < y <= 2.05`, completes without crossing the body, and honours `ignoreVehicleId` only for the named source car. `test_hero_surface_motion.mjs`: a low vehicle is never auto-step; it is explicit vault/mantle. | With `vehicleFleet` speed at 0 for at least .3 s, approach side, front low surface and diagonal corner. Repeat for the 12 authored profiles: hatchback, compact sedan, wagon, executive sedan, coupe, SUV, van, pickup, bus, police, ambulance, fire engine. | Side/corner body blocks. A reachable hood yields `supportKind:vehicle`, exact `supportId`, `supportStable:true`, `autoStep:false`, and one vault/mantle. On a legally reached roof, Y/support error ≤.03 m. Bus/van/emergency sections without reachable geometry block. Current 67F91 lacks support ID telemetry, so this is LIVE HOLD until `pedestrianMotion` is present. |
| Moving-car rejection | Same actual-GLB test sets compact-sedan speed to 2 m/s; traversal becomes `null`. `hero_vehicle_surface.mjs` marks support unstable above .08 m/s and requires .3 s stable time. | Approach an unrelated car whose `vehicleFleet.vehicles[].state.speed` stays above .20 m/s for two samples. Do not use the currently occupied source car. | `pedestrianMotion`: no step/scramble/traversal, plan count 0, blocking reason identifies dynamic/vehicle and no support is stable. `heroWalk` never snaps onto/rides it. `ignoreVehicleId` must not name the unrelated car. |
| Water and shore exit | `test_hero_traversal_world.mjs`: both `lake-cedar` and `lake-east`, 16 rays × depths .06/1.25 m, all 32 routes per lake reach dry ground. Frozen QA points: cedar start `(355.151713,1.74,-137)` → `(356.171713,1.799869,-137)`; east start `(918.438086,1.14,425)` → `(919.278086,1.207273,425)`. | Enter either lake normally, swim toward the cited bank and hold forward until clearly dry. | `artist14.swim` changes true→false once; `pedestrianMotion.owner` changes water→surface once, final support finite and capsule-clear, no unsupported/free-fall frame. `surfaceMotion.grounded:true`; `heroWalk.y` is within .05 m of support. |
| Walk-off fall, long-fall and landing | `test_hero_surface_motion.mjs`: 10 m ledge starts explicit physics fall without a Y snap. `test_hero_airborne_ladder_pose.mjs`: actual male/female GLBs cover ascent/apex/fall/long-fall/landing at 10/30/60/144 Hz; landing skin remains above support and landing duration is .34 s. Orchestrator suite covers 3/5/7/10/15/30/60/144 Hz and free-edge fall without jump. | Walk off the measured 10 m ledge and give no further input until the landing pose fully clears. | `heroMotionPose`: airborne phase progresses fall→long-fall→landing; Y decreases monotonically until contact, landing count +1 exactly, landing age lasts `.34±.05 s`, then grounded walk. `surfaceMotion` ends grounded with support error ≤.03 m. This row is LIVE HOLD while `heroMotionPose` is absent. |
| Ladder E up/down and Ctrl active-only slide | `test_ladder_input_contract.mjs`: bottom and roof prompts use E; Ctrl/non-E cannot acquire; E admits both ends; Ctrl slides only after active; E cancel reaches a safe endpoint. `test_hero_airborne_ladder_pose.mjs`: climb-up, climb-down and slide contacts/pose pass on both actual GLBs at 10/30/60/144 Hz. `test_ladder_discoverability.mjs`: authored roofs remain discoverable. | At the bottom press Ctrl first, then E and climb; while active press Ctrl. Repeat from the roof. Use ordinary E to finish/cancel. | Before E, no root motion and no new `roofNavigation`. After E, `roofNavigation.active:true`; direction is +1 bottom / -1 roof. Ctrl changes `sliding:true` only while active and pose phase is `slide`. Completion reports `done:true`, ends on the correct support within .03 m, and the ladder owner clears within two frames. Because `roofNavigation` retains its last completed sample, use its `done/active/sliding` fields plus unchanged `heroWalk` position when testing Ctrl-before-E; dataset presence alone is not proof of activity. |

## Global one-tab failures

Every row fails on a console/runtime error, non-finite coordinate, body overlap,
more than one traversal plan, `pending` treated as clear, or a per-frame move
larger than commanded speed × elapsed time + 0.05 m. A grounded root must stay
within 0.03 m of support except during a declared traversal/airborne owner.
Stale step, scramble, traversal or landing metadata must clear within two
rendered frames after another owner takes control.

Do not open a second visible or hidden game tab. Do not use the traversal QA
placement buttons, direct coordinate assignment or a map teleport. If a named
fixture cannot be reached in the integrated world, record **NOT RUN / NO-GO**;
do not replace it with a synthetic LIVE result. Save one dataset bundle and one
screenshot at each row. The final LIVE result is GO only when every row has its
required telemetry and passes; unit/source GO cannot substitute for this run.
