# Astra 15: /walk traversal, fall and ladder presentation — 23 September 2026

Scope is presentation only. No production host, physics, collision, input,
`walk_preview.mjs`, `hero_walk.mjs`, `hero_jump.mjs` or existing
`hero_traversal*.mjs` was changed. The modules preserve root position and yaw;
the host remains authoritative for collision, height and action admission.

## New modules

- `hero_airborne_motion_pose.mjs`: deterministic `ascent`, `apex`, `fall`,
  `long-fall`, and `landing` samples. Long fall braces before contact; landing
  compresses asymmetrically and then recovers. The actual skinned floor is
  solved only during landing.
- `hero_obstacle_motion_pose.mjs`: distinguishes a compact `auto-step` over a
  kerb from `vault` over a low barrier/car body and `mantle` onto a bonnet or
  roof. Vault/mantle delegate ledge contact to the already proven
  `applyTraversalPose`; auto-step raises one real leg without changing root.
- `hero_ladder_motion_pose.mjs`: climb up, ordinary descent and Ctrl slide.
  Opposite hands/feet alternate by rung, release before changing rungs, and use
  actual hand/foot IK. Slide keeps both hands on rails and feet together.
  Mount/dismount blends are explicit.
- `hero_slope_motion_pose.mjs`: additive steep-terrain `scramble-up` and
  `scramble-down`. It shortens the existing gait using the same gait phase,
  leans into the measured grade, brakes downhill, solves independent foot
  supports and optionally blends to physics-validated hand contacts.
- `hero_motion_pose_orchestrator.mjs`: one reusable state/pose owner for walk,
  slope, auto-step, vault/mantle, explicit airborne, ordinary surface fall and
  ladder. It cross-fades solved bone rotations without taking root motion,
  collision or yaw. It also exports the current building-navigation adapter,
  the ordinary `surfaceMotion` fall observer and a pooled pose applicator.

Every sample returns `weaponPolicy`. Ladder, vault, mantle and free fall use
`holster`; armed auto-step uses `carry-safe` and does not disturb the existing
arm/grip solve. The host should use its existing weapon visibility/holster path;
the pose modules do not change inventory or weapon state.

## Exact host contract

Create these once per hero, then update after the authoritative physics frame
and after the ordinary `hero.update` base pose:

```js
const poses=createHeroMotionPoseOrchestrator();
const applyPoses=createHeroMotionPoseApplicator(THREE,hero.artistContext());
const observeSurfaceFall=createSurfaceMotionAirbornePoseAdapter();
const adaptLadder=createBuildingVerticalNavigationPoseAdapter();

const freeEdge=observeSurfaceFall.update(dt,surfaceMotion.state,{
  armed:currentWeapon.id!=='none',
});
const ladderPose=adaptLadder(verticalNavigation.state,{
  contactsVerified:true,
});
hero.update(dt,moving,running,weapon,aim,presentation);
const poseFrame=poses.update(dt,{
  weapon:{armed:currentWeapon.id!=='none',visible:weaponModel?.visible!==false},
  traversal:traversalFrame,
  ladder:ladderPose,
  airborne:jumpPoseActive?explicitJumpAirborne:freeEdge,
  autoStep:autoStepFrame,
  slope:slopeFrame,
  jump:{active:!!jump},
  blocked:{death,blast,vehicle,custody,interaction,water,cover},
});
applyPoses.apply(poseFrame);
```

The exact arbitration is: death → blast → vehicle → custody → interaction →
explicit jump → traversal → explicit airborne → ladder → water → cover →
ordinary surface fall/landing → auto-step → slope → walk. A `dt=0` update
cancels immediately for a new hard owner/jump and can change the selected
owner, while leaving ages, contacts and blend weights unchanged.

`createBuildingVerticalNavigationPoseAdapter()` accepts the current production
shape `{active, sliding, pose}`. It reuses its output. The host must disable the
old internal `applyRoofLadderPose` on any frame sent to the orchestrator; calling
the old pose and `applyPoses.apply` together double-applies the ladder. The
adapter does not require new physics fields.

Free edge falls should have lower priority than vehicle, blast, water, cover,
custody, explicit jump/dive and active ladder states. Track the source surface
state only while all those states are absent:

```js
const sample=sampleHeroAirborneMotion({
  verticalVelocity:surfaceFrame.velocityY,
  airborneAge:freeFall.age,
  fallDistance:Math.max(0,freeFall.peakY-hero.object.position.y),
  landingAge:freeFall.landingAge, // null until first grounded frame
  impactSpeed:freeFall.impactSpeed,
  armed:currentWeapon.id!=='none',
});
hero.reset();
applyHeroAirborneMotionPose(THREE,hero.artistContext(),sample);
if(weaponModel) weaponModel.visible=sample.weaponPolicy!=='holster';
```

Keep landing active for `sample.landingDuration` (default `.34 s`), then return
to the ordinary posture layer. A dt=0 host tick must not advance `age` or
`landingAge`. Cancel the presentation immediately when entering a vehicle,
water, ladder, blast/death, cover, crouch/prone transition or a new explicit
jump. This preserves the existing state owners.

For Astra 14's traversal physics frame:

```js
const pose=sampleHeroObstacleMotion({
  kind:frame.kind,                 // auto-step | vault | mantle
  progress:frame.progress,
  obstacleHeight:frame.obstacleHeight,
  leadSide:frame.leadSide,
  direction:frame.direction,
  edge:frame.edge,
  start:frame.start,
  handL:frame.handL,
  handR:frame.handR,
  armed:currentWeapon.id!=='none',
});
hero.reset();
applyHeroObstacleMotionPose(THREE,hero.artistContext(),pose);
if(weaponModel) weaponModel.visible=pose.weaponPolicy!=='holster';
```

Suggested selection boundaries are owned by physics: ordinary walk/slope below
the accepted step; `auto-step` for a short admitted rise such as a kerb;
`vault` when the destination stays near the starting floor; `mantle` when the
destination is the supported top of a bonnet/roof/obstacle. Presentation does
not infer collision from visual meshes.

The reviewed Astra 14 `hero_surface_motion.route()` candidate currently returns
only `moved`, `position` and `reason`. Its accepted result needs one additive
`stepRise` (maximum positive curb rise; zero for slope/plain walk) so the host
can start a short auto-step presentation. Keep that field diagnostic/additive;
do not rerun or weaken admission in presentation code.

For the existing roof controller, `sampleHeroLadderMotion` consumes its
descriptor, current root, accumulated `travelled`, `direction`, `sliding`, and
mount/dismount progress. `applyHeroLadderMotionPose` replaces only the current
`applyRoofLadderPose` call. Keep the current E admission and Ctrl-only active
slide behavior, root/yaw update, camera shift and weapon restore:

```js
const pose=sampleHeroLadderMotion(descriptor,frame.position,{
  travelled:frame.travelled,
  direction:frame.direction,
  sliding:frame.sliding,
  mountProgress:frame.mountProgress,
  dismountProgress:frame.dismountProgress,
});
hero.reset();
applyHeroLadderMotionPose(THREE,hero.artistContext(),pose);
weaponModel.visible=false;
```

The current controller does not expose all six presentation fields outside its
internal state. The narrow integration should add them to its returned frame;
do not duplicate a controller or derive root motion from the pose.

For a physically admitted terrain move, use the signed rise/run measured along
the actual travel direction. Preserve one blend value in the host; it is the
only state owned by presentation:

```js
const slopeTarget=sampleHeroSlopeMotion({slopeGrade}).targetBlend;
slopePoseBlend=stepHeroSlopeBlend(slopePoseBlend,slopeTarget,dt);
const slopePose=sampleHeroSlopeMotion({
  slopeGrade,
  blend:slopePoseBlend,
  gaitPhase:gaitOutput.phase,
  gaitWeight:gaitOutput.gait,
  moving:moved,
  armed:currentWeapon.id!=='none',
  footL:terrainContacts.footL,
  footR:terrainContacts.footR,
  handL:terrainContacts.handL,
  handR:terrainContacts.handR,
});
// Call after the ordinary hero.update base pose and weapon grip solve.
applyHeroSlopeMotionPose(THREE,hero.artistContext(),slopePose);
if(weaponModel&&slopePose.weaponPolicy==='holster') weaponModel.visible=false;
```

The blend ranges are fixed and exported as `HERO_SLOPE_BLEND`: scramble begins
at signed-grade magnitude `.42` and is full at `.78`; optional hand contact
begins at `.72` and is full at `.92`; downhill braking begins at `.30` and is
full at `.72`. Exact exponential transitions reach 90% in `.18 s` entering and
`.22 s` leaving. `stepHeroSlopeBlend` is frame-rate invariant for a constant
target and leaves the value unchanged at dt=0. The host must derive the signed
grade from the accepted root delta (`deltaY / horizontalDistance`): the current
shared passability metadata records the maximum positive terrain slope for
admission, not downhill sign.

Foot and hand points must come from the existing physical surface/collider
queries. Pass `null` when a contact is absent. The pose never raycasts visual
meshes or changes root height. Armed movement keeps the current grip through
moderate blend; above `.55` it requests `holster` so steep hand support can be
used without weapon/body intersection.

## CPU and regression verification

`test_hero_airborne_ladder_pose.mjs` passes against the real male and female
GLBs: 1,274 skinned snapshots per model, both armed/unarmed, all five airborne
phases, three obstacle motions, climb/descent/slide, planted contacts,
mount/dismount, landing floor, fixed root/yaw, unchanged bone length/scale,
dt=0 repeat and 10/30/60/144 Hz sampling. The last run sampled 200,000 airborne
states in 37.10 ms and 200,000 ladder states in 77.62 ms on the final run
(sampler-only microbench, not full-scene FPS).

Existing suites passed unchanged: `test_hero_traversal_pose`, `test_hero_walk`,
`test_hero_jump`, root `test_roof_slide`, and root
`test_ladder_discoverability` (all actual authored building types). No browser
or GPU tab was opened. LIVE behavior and full-scene frame time remain unverified
until the root host hook is reviewed and loaded in the coordinator's one game.

`test_hero_slope_motion_pose.mjs` adds 417 actual-skin snapshots per GLB. It
covers uphill/downhill, armed/unarmed, independent feet, optional hands,
walk-to-scramble continuity, dt=0 and 10/30/60/144 Hz. The largest skin change
per `.01` grade was `.0499 m` male / `.0527 m` female; the largest 10 Hz
transition frame was `.0974 m` / `.1029 m`. All rates ended at the same blend
within `7e-19`. Final sampler microbench: 200,000 samples in 31.85 ms
(`~0.159 microseconds/sample`; sampler only, not scene FPS).

No GPU renderer was opened. Instead the test writes deterministic joint pose
snapshots for both authored GLBs to
`outputs/hero_pose_astra15/slope_pose_snapshots.json` (`walk-edge`,
`scramble-up`, `scramble-down`). These are review data, not a LIVE visual claim.

## Orchestrator acceptance and cost

`test_hero_motion_pose_orchestrator.mjs` passes the actual male and female GLBs
at 3/5/7/10/15/30/60/144 Hz. It covers mixed ladder+water+cover, jump+ladder,
custody, hard-owner cancellation at dt=0, free-edge fall without a jump object,
short/long fall and landing, abort traversal, ladder exit onto a slope, weapon
restore, verified hands only, root/yaw/bone invariants and elapsed-time terminal
parity. Maximum one-frame skin delta is below `.75 m` in every tested cadence;
the final run maxima were `.7274 m` male and `.7404 m` female.

The state machine took `78.72 ms / 100,000` updates in the final recorded run.
After 250 warm-up frames, an actual `hero.update + orchestrator.update +
applicator.apply` loop took `104.59 ms / 1,000` male frames and `105.47 ms /
1,000` female frames. Heap deltas were `+27.2 MB` and `-11.8 MB`; their
variation exposes host allocation and GC, and is not evidence of zero allocation.

The Astra15 orchestrator, applicator output, layer arrays and slope/ladder IK
scratch are pooled and reused. Full actual application is **not claimed
allocation-free**: the existing production `hero.artistContext()` methods still
allocate in `hero_walk.mjs` at `rotateAdd` line 76, `reachFoot` lines 138-144,
and `pointBone`/`reachPalm` lines 338-368. Removing those requires a separately
owned production patch which introduces per-walker Vector3/Quaternion scratch
pools without changing those method signatures or visual math. This handoff did
not edit `hero_walk.mjs`.
