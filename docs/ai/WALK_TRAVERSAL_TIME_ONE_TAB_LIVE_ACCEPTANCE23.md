# One-tab LIVE acceptance: traversal and time of day

Run this only after the Coordinator integration slot and all source/unit gates
are green. Use the single existing game tab. Do not open a second visible or
hidden GPU tab. Reload that same tab once with `perfqa=1`, then keep the same
document for the entire functional route and performance comparison.

## Evidence required from the integration slot

The exact route result cannot be accepted from appearance alone. In `perfqa=1`
the host must publish, at no more than 4 Hz, a read-only
`document.body.dataset.pedestrianMotion` JSON snapshot with:

`sequence`, `owner`, `from`, `requested`, `accepted`, `moved`, `mode`, `reason`,
`nextSpeedScale`, `traversalKind`, `traversalPlanCount`, `verticalTransition`,
and the latched animation fields `maxRise`, `stepRise`, `descentStep`,
`autoStep`, `slope`, `ascentMode`. It must also include `capsuleClear`,
`supportKind`, `supportId`, and `supportStable` from the query actually used by
that move. A sequence change must represent an input move, not a render-only
refresh. `traversalPlanCount` is always zero or one.

Publish `document.body.dataset.heroMotionPose` with `owner`, active layer,
airborne state, grounded state, fall distance, vertical speed, landing age and
landing count. Publish `document.body.dataset.walkTimeOfDay` with the reusable
controller output (`hour`, `phase`, `daylight`, `dawn`, `dusk`, `night`,
`lampPower`), controller stats (`samples`, accepted/rejected samples,
`nextSampleAt`, QA offset, disposed), and `applied:outdoor|interior-skip`.
These are opt-in diagnostics, not new per-frame production serialization.

Also retain the existing evidence:

- body datasets `heroTraversal`, `roofNavigation`, `surfaceMotion`,
  `waterInteractions`, `vehicleFleet`, `npcWorld`, and `walkPerformance`;
- renderer datasets `playerR`, `playerC`, `playerInterior`, `playerGait`,
  `playerAnimationLayer`, `palette`, `paletteSource`, `visualDPhase`,
  `streetLampSchedule`, `streetLampPower`, `fps`, `drawCalls`, `triangles`,
  `liveNpcs`, `liveCars`, `renderPixelRatio`, and `performanceTier`.

If either new snapshot is absent, stale for more than 500 ms while its system
is active, contains a non-finite position, or disagrees with the visible actor,
the corresponding LIVE result is **NO-GO**, not “visually acceptable”. Save one
JSON evidence bundle and one screenshot at every numbered checkpoint.

## Fixed run conditions and global failures

Record the build SHA, URL, viewport, pixel ratio, quality, shadows, weather,
camera transform, hero feet position, `liveNpcs`, `liveCars`, and all fleet IDs
before starting. Start at the entrance to the chosen continuous QA route and
reach every fixture using ordinary movement or ordinary driving. Never assign
player/car coordinates, invoke a focus/placement preview, use a map teleport,
or replace collision geometry. Do not reload between checkpoints.

Before the run, measure the physical fixtures through the integrated query:
curb rise `0.34 ± 0.02 m`, continuous hill grade `1.55 ± 0.03`, ledge drop
`10.0 ± 0.25 m`, and low obstacle height `0.35–1.10 m`. If the current world
has no fixture in one range, mark that row **NOT RUN / NO-GO**; do not change
the threshold or manufacture the result by moving the hero.

Every functional row also has these invariant thresholds:

- horizontal accepted distance is at most requested distance plus `0.01 m`;
- every grounded accepted position reports `capsuleClear:true`;
- no frame moves farther than commanded speed × elapsed time plus `0.05 m`;
- root Y follows support within `0.03 m`, except while an explicit traversal or
  airborne owner is active;
- no wall/car volume overlap, no second traversal plan, no `pending` treated as
  clear, and no `runtimeFrameError` or new console error;
- after another owner takes control, stale step/scramble/traversal metadata is
  gone within two rendered frames.

## Continuous traversal route

Perform these in order without a coordinate reset.

| # | Action | Required dataset result and pass threshold |
| --- | --- | --- |
| 1 | Stand on flat ground for two seconds. Walk forward, stop, turn around. | `mode:walk`, `ascentMode:walk`, speed scale `1`, no traversal/vertical transition. Idle metadata clears in ≤2 frames. |
| 2 | Walk diagonally up the measured 34 cm curb. | `moved:true`, `mode:step`, `autoStep:true`, `stepRise` and Y rise `0.34 ± 0.02`, `traversalPlanCount:0`; one planted-foot step pose, no wall penetration. |
| 3 | Walk down the same curb. | `moved:true`, `reason:clear`, `descentStep:0.34 ± 0.02`; no `free-fall`, no root snap below support, no stale uphill pose after two frames. |
| 4 | Walk continuously up the measured grade 1.55 hill. | `mode:scramble`, `ascentMode:scramble`, reported slope `1.55 ± 0.03`, `nextSpeedScale:0.48 ± 0.01`, no traversal. Across each sample, Y gain equals horizontal travel × grade within `0.03 m`. |
| 5 | Turn around on the same surface and descend it. | Still `scramble` with speed scale `0.48 ± 0.01`; signed observed grade is `-1.55 ± 0.03`. No `verticalTransition`, no Y snap. Flat ground clears scramble within two frames. |
| 6 | Walk normally over the measured 10 m edge. Do not jump. | Admission reports `mode:free-fall`, `reason:free_fall`, `verticalTransition.kind:free-fall`, fall distance `10.0 ± 0.25`, traversal null/count zero. The admission position keeps pre-edge Y within `0.01 m`; the first gravity frame drops less than `0.50 m`. |
| 7 | Let the fall finish without input. | Airborne Y is monotonic until contact. Landing support error ≤`0.03 m`, capsule clear, landing count increases exactly once, landing layer lasts `0.34 ± 0.05 s`, then returns to walk/idle. No one-frame snap from edge Y to ground Y. |
| 8 | Approach the measured low obstacle straight, then diagonally. | Rise ≤0.34 m uses step. A higher reachable ledge returns exactly one `vault` or `mantle` plan and the shared traversal owner. It completes on the far clear side; it never passes through the obstacle. A face higher than supported traversal blocks with accepted distance short of contact. |
| 9 | Repeat the low obstacle while armed. | Same physical result; traversal/landing may holster only for the owned phase and restores the prior weapon once. No duplicate legacy pose in the same frame. |

## Parked and moving vehicles

Walk to each parked vehicle in this exact fleet list:

1. `city_hatchback`
2. `compact_sedan`
3. `family_wagon`
4. `executive_sedan`
5. `sport_coupe`
6. `city_suv`
7. `delivery_van`
8. `utility_pickup`
9. `city_bus`
10. `police_interceptor`
11. `city_ambulance`
12. `fire_engine`

For every profile, make three ordinary approaches: side body, front/lowest
authored surface, and a diagonal corner. Side and corner bodies must stop the
capsule with no overlap. A parked surface may support a step/vault/mantle only
when `supportStable:true` and the measured rise falls inside the same curb or
traversal limits; support must identify that vehicle. Low hoods must be usable,
and any roof reached through continuous legal geometry must hold root Y within
`0.03 m`. High bus/van/emergency body sections with no reachable ledge must
block. The test fails if any profile is made passable by a generic bounding-box
top, if the hero walks through it, or if the result depends on approach angle.

Then approach an actual moving vehicle whose measured speed stays above
`0.20 m/s` for at least two samples. It must report unstable vehicle support,
zero traversal plans, no step/scramble admission, and a blocking body. The hero
must not ride or snap to it. `ignoreVehicleId` may exempt only the currently
occupied source car during a real exit; it must not exempt this unrelated car.

## Water, ladder, and cover/input ownership

| # | Action | Required result |
| --- | --- | --- |
| 10 | Enter water normally, swim to a measured walkable bank, and hold forward until ashore. | Owner changes water → surface once. Exit support is finite/capsule-clear, root/support error ≤`0.05 m`, no unsupported/free-fall frame, and swimming clears within two frames after dry support. |
| 11 | At a ladder bottom, press Ctrl before E. Repeat at its roof entry. | `roofNavigation` remains inactive; no ladder pose or slide. Ctrl never admits a ladder. |
| 12 | Press E at the bottom, climb, then press Ctrl while active. | E activates within one input/frame boundary. Active state and rung contacts persist; Ctrl changes only the already-active ladder to slide/down. It never activates cover/crouch. |
| 13 | Release Ctrl and press E for ordinary ladder completion/exit. Repeat from the roof. | One exit, grounded on the correct floor/roof within `0.03 m`, state clears within two frames, no duplicate pose/root jump. Upper and lower admission both require E. |
| 14 | Walk to low cover and press Ctrl. | Cover becomes the owner within two frames. The visible prompt says `CTRL · В укрытие`; pressing Ctrl does not show or execute `C · Присесть`. Cover collision holds and tangent movement does not enter the object. |
| 15 | Leave cover, then press C once on clear ground and once near the same cover. | C controls crouch only and never enters cover or ladder. Ctrl remains cover admission. When ladder is already active, its Ctrl slide has priority over cover. |

Required ownership order throughout is:
`death > blast > vehicle > custody > interaction > explicit jump > traversal > ladder > water > cover > surface fall/landing > step > slope > walk`.

## Time-of-day sequence in the same tab

After traversal, stand outdoors with the camera fixed on one lamp, one facade,
the horizon and an enterable interior. Use only the integrated explicit QA
offset control (`setOffset(number)`) to reach checkpoints; never send `-1`,
`24`, strings or fractions through the production bridge clock. Allow 500 ms
for the new clock sample and four seconds for palette settling. Do not reload or
move the camera.

| Clock | Required evidence |
| --- | --- |
| 06:21 | Strict sample accepted; `visualDPhase=dawn`, dawn approximately `1`, daylight strictly between 0 and 1, lamps scheduled on and power >0. |
| 06:59 → 07:00 | Schedule changes exactly from `on-17-07` to `off-07-17`; power becomes exactly `0.000` at 07:00. No clock rejection or midnight substitution. |
| 12:00 | `visualDPhase=day`; palette daylight `1.000`, dawn/dusk `0.000`; lamps off/power `0.000`. This is also the performance A/B phase. |
| 16:59 → 17:00 | Lamps change exactly off → on; 17:00 power is at least `0.480`. The sky curve remains continuous even though the authored lamp schedule is discrete. |
| 18:39 | `visualDPhase=dusk`, dusk approximately `1`, lamps on; warm fog/sun/background agree with the dataset and do not jump between different clock values. |
| 22:00 | `visualDPhase=night`, daylight/dawn/dusk `0.000`, night and lamp power `1.000`. |

At every checkpoint `paletteSource`, renderer clock text and
`walkTimeOfDay.hour` must name the same minute. Accepted samples increase no
faster than once per 250 ms; a late frame causes one sample, never a burst.
Rejected samples remain zero in this valid sequence.

At 22:00 enter the interior normally with E. Capture background RGB, fog type,
fog RGB/density or linear `near/far`, ambient/sun intensities, exposure and
environment intensity at `playerInterior=1`. Change the QA offset to 12:00 and
wait four seconds inside. `walkTimeOfDay.applied` must remain `interior-skip`
and every captured interior render value must remain bit-identical (numeric
tolerance `1e-6`); the controller clock may continue changing. Exit normally:
the outdoor palette may resume, with no one-frame interior flash. Reset QA
offset to zero before the performance run.

## Same-camera/population A/B

Run A–B–A in the same tab at 12:00, clear weather, hero idle on flat ground,
lamps off, no active traversal/cover/ladder/water state. A is the approved
diagnostic switch with the new traversal/time consumers disabled and the legacy
path active; B enables the integrated consumers. If the Coordinator slot does
not provide a reversible, read-only A/B switch, performance acceptance is
**NOT RUN / NO-GO** rather than a comparison across different builds/tabs.

For each window:

1. Restore the recorded camera and feet position within `0.01 m` and yaw/pitch
   within `0.1°`; keep viewport, pixel ratio, quality and shadows exact.
2. Require identical `liveNpcs`, `liveCars`, draw calls, triangles, geometries,
   textures and shader-program counts. Any mismatch invalidates the pair.
3. Reset the performance probe, warm for five seconds, then capture at least
   120 consecutive `walkPerformance` samples. Save the complete JSON, not only
   the FPS label.

Use the mean of A1 and A2 as baseline. B passes only when all are true:

- frame-time p50 ≤ baseline × `1.03` and p95 ≤ baseline × `1.05`;
- interval p50 ≤ baseline × `1.03` and p95 ≤ baseline × `1.05`;
- integrated player surface-route p95 ≤ `0.10 ms` per frame;
- integrated time sample/apply p95 ≤ `0.10 ms` per frame;
- `heroSurface` stage p95 increases by no more than `0.15 ms`, and the lighting
  stage p95 increases by no more than `0.10 ms`;
- draw calls, triangles and GPU memory counters are exactly unchanged at noon;
- no frame error/recovery, non-finite timing, new console error, or persistent
  heap growth across A1–B–A.

Report traversal, clock/interior, and performance as three separate results.
The combined result is GO only if all three pass. CPU/unit results, screenshots
without datasets, or a second GPU tab cannot substitute for this LIVE gate.
