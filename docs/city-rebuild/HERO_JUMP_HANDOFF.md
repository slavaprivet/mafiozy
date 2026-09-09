# Directional hero jump — 2026-09-08

Scope: the isolated `http://127.0.0.1:18538/walk` preview. This adds a verified
third-person movement slice; it does not replace the production gameplay
controller or claim that the full game migration is complete.

## Player behavior

- Space while on foot launches immediately. With no movement key the hero jumps
  vertically; Space with W, A, S or D performs an upright camera-relative jump.
  Diagonal input is normalized, so it does not increase distance.
- A second real Space press within 500 ms upgrades the current jump to the
  existing Max Payne dive. Timing uses KeyboardEvent.timeStamp, so render/handler
  delays do not count as a slower key press. The initial 300 ms window was too
  narrow in user testing and was replaced. Holding Space never activates dive.
  The second press keeps height, elapsed flight and position; no second impulse.
  WASD at the second press chooses direction, otherwise preserve initial travel;
  if initially vertical, dive camera-forward. Third/late taps do not restart it.
- Normal jumps use the existing upright jumpPose branch. The committed dive
  uses the existing directional skeleton pose, weapon aiming and landing.
- The action lasts 1.25 seconds: 0.8 seconds of ballistic flight and 0.45 seconds
  of landing recovery. Peak root height is 1.05 m and directional speed is
  3.5 m/s for normal jumps and 10.5 m/s after entering dive (user requested more
  distance; formerly 6.5). These values are
  preview tuning choices, not a production-game rule.
- The existing pedestrian footprint performs swept collision checks throughout
  flight. Buildings, props, water, the car body and map limits remain blocking;
  a dive cannot tunnel through a thin wall. A blocked dive still completes its
  landing animation safely.
- A new jump cannot begin during another jump (only the above upgrade), a vehicle transition, driving,
  loading or while the scene menu is open. E interaction is disabled during the
  action. Space while driving remains the handbrake.

## Implementation and validation

Pure jump state and collision stepping live in `hero_jump.mjs`; the actual
Artist 13 skeleton pose lives in `hero_walk.mjs`; `walk_preview.mjs` binds the
state to controls, camera tracking and interaction guards. The footer now shows
the distinct on-foot and in-car meanings of Space.

Validation commands:

```
node assets/maps/city_rebuild_v1/test_hero_jump.mjs
node assets/maps/city_rebuild_v1/test_jump_keyboard.mjs
node assets/maps/city_rebuild_v1/test_hero_walk.mjs
node assets/maps/city_rebuild_v1/test_car_drive.mjs
node assets/maps/city_rebuild_v1/test_car_exit.mjs
node assets/maps/city_rebuild_v1/test_walk_motion.mjs
node --check assets/maps/city_rebuild_v1/walk_preview.mjs
```

The tests cover all eight camera-relative directions, vertical apex, normalized
diagonals, timestep consistency, thin barriers, boundary/water rejection,
completion and landing. The real GLB test samples deformed skinned vertices over
both jump types, verifies the directional silhouette, preserves root position
and yaw, and verifies exact bone restoration. Existing vehicle, moving-exit and
pedestrian suites remain green.

Coordinator14 latest validation: pure jump/surface tests, actual extracted
walk keyboard handler (four WASD directions, key release/repeat, delayed handler
clock, vertical-to-forward dive, late/third presses and vehicle handbrake),
test_hero_walk and test_hero_presentation_glb PASS. Hero pose source was not edited
for this split; artist14 owns ongoing weapon clearance edits.
Actual HTTP CUA keyboard run: two Space presses produced mode=dive, directional
true, count=1, then completed safely against a nearby car, browser errors empty.
Single Space produced normal mode immediately. Airborne LMB dropkick cancellation
and vehicle handbrake code remain unchanged.

## Latest user refinement: side contact, aim and distance

Normal-to-dive skeleton pose blends over .24 seconds. At the second press the
old full tilt/grounding snap is removed: diveBlend=0 is exactly the current
normal pose. Physics root trajectory remains continuous.
Facing and head follow the camera/crosshair throughout, including unarmed flight.
Travel yaw is separate: A/D lower the shoulder on the actual movement side;
forward/backward use that same world-direction tilt axis. Do not infer A/D from
the model's mirrored bone l/r names. The body does not turn to face travel.

The dive reaches ~88 degrees at touchdown (.8 seconds from original launch),
holds ground contact ~.1 seconds, and stands over .35 seconds. Both normal and
dive finish at 1.25 seconds. Final skin floor solve runs after aim/weapon IK to
prevent the low elbow/head clipping the ground; grips translate with the pose.

Speed now 10.5 m/s in dive (about 62% more than before), normal remains 3.5.
Latest user asked slightly lower flight: target dive root apex .80 m instead of
1.05 m. Blend toward the lower curve using the same .24s transition, so a
midair second press does not snap the root down. Normal apex stays1.05m; late
second presses may already have passed the higher initial normal-jump apex.
Full instantaneous dive can cover 8.4 m on free ground; actual distance depends
on second-press time and collision. Walls/props still stop movement.

`test_jump_transition_pose.mjs`: PASS actual GLB, 1348 skin snapshots, blend
continuity, independent aim, leading shoulder A/D, ground contact all four
directions and upright recovery, all14 weapons and grips, no bone stretch/root
teleport. Actual CUA D+Space then Space: mode=dive, count1, blend1, y0 at end,
collision with nearby obstacle handled, errors[]. Keyboard/physics/surface and
the existing two hero suites also pass. No slow-motion or server mechanics added.

## Immediate posture after landing

Ctrl/Z during flight or recovery buffers crouch/prone. Repeated same posture
key toggles/cancels the buffered request; a different posture replaces it.
On actual ground contact after flight, the buffer bypasses the remaining get-up
animation. It never applies in the air or carries into a vehicle/blast state.
Presentation changes over .28s using `hero_pose_transition.mjs`: captured local
bone rotations and body transform blend into the target before weapon IK;
the combined pelvis orientation avoids an intermediate upright turn.
Final skin-floor solve preserves contact. Camera eye height uses the same .28s
transition. No forced standing frame and no repeated keypress needed.
Without a queued posture, the ordinary quick get-up behavior remains.

Weapon origin and upright chest turn fade from the landing pose. The free
pistol hand blends solved joint rotations into ground support, avoiding an
elbow pole flip on the first nonzero frame. Normal weapon presentation defaults
remain unchanged (360 torso-clearance/grip cases pass).

Validation: test_landing_posture PASS 60 actual-GLB cases (unarmed/all14 weapons,
both sides, crouch/prone), exact start/end, 96 intermediate samples per case,
floor, fixed world root, bone lengths and weapon grips. Existing jump skin
1348 snapshots, keyboard, jump physics, posture, surface and hero suites PASS.
LIVE refreshed /walk?animationqa=1: A+Space, Space, Z queued prone and landed
at y0/height.62; D+Space, Space, Ctrl queued crouch and landed at y0/height1.25.
Browser errors []. Latest smoothness changes are in shared files, not the
earlier GitHub backup snapshot.
