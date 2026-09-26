# Ordinary airborne pose — ready for coordinator integration

26 September 2026. Scoped files only:

- `godot/mafiozi_walk/scripts/preview_airborne.gd` — pure pose sampler.
- `godot/mafiozi_walk/scripts/test_preview_airborne.gd` — real-rig/full-skin test.
- This contract.

**Not hooked into the running game.** No changes to `preview_player.gd`,
`preview_locomotion.gd`, main scene, input, physics, camera, HP or persistence.
No commit/push and no native GPU window launch. Existing user game remains alone.
The root accepted the sample-only/single-owner API before this handoff.

## Exact source and distinction from adaptation

The transferred amplitudes are specifically
`hero_walk.mjs::jumpPose(progress, directional=false, weapon=null, aim={})`.
This excludes Max Payne dive, aim, weapon IK, vehicle and tumble code.

Source receipts at implementation time:

| Source | SHA-256 |
| --- | --- |
| `assets/maps/city_rebuild_v1/hero_walk.mjs` | `60ad2135010926f9fe1f18c62a89a877eb2547c708b723d7926f513043cc28c3` |
| `assets/maps/city_rebuild_v1/hero_jump.mjs` | `6315992afff118c63facd12c2957437ed46bd126642f49fc6619bd845df0d680` |
| `assets/maps/city_rebuild_v1/hero_pose_transition.mjs` | `674fcfce49b4cbe3048ff829e784595b680625f901d73b95a4976128e4a0b8e2` |

For progress `p` and clamped cubic smoothstep `S`:

```text
launch = S(p / .14)
recover = S((p - .64) / .36)
landing = S((p - .5) / .14) * (1 - S((p - .72) / .28))
air = launch * (1 - recover)
chest.x = landing * .35
thigh.x = -air * .65 - landing * .8
shin.x = air * .8 + landing * .85
foot.x = -air * .14 - landing * .15
upperarm.x = -air * .65
upperarm.z = left/right sign * air * .15
forearm.x = -air * .8
```

The original rest quaternion multiplies the same XYZ rotation as Three.js;
Godot's default YXZ Euler conversion is deliberately not used. Other bones keep
rest rotations. Bone translations/scales and the imported hierarchy are intact.

**New Godot adaptation:** the old source used a fixed .8-second trajectory plus
.45-second recovery. This sampler does not alter Godot's trajectory to imitate
that time. Positive launch velocity is observed; `(1 - current_vy / launch_vy)/2`
maps actual ascent/descent to source progress 0–.64. The pose remains airborne
until the host reports actual ground support. Confirmed contact starts .45 s
recovery toward progress 1. Full elapsed time is consumed, including dt > .1 s.

To avoid a walk-to-air pop, takeoff carries the last approved grounded output
and blends to the source pose over .175 s (`.14 * (.8 + .45)`). First landing
frame reproduces the previous air pose exactly. The landing curve then blends
back to the host's fresh locomotion target over the final .28 s, using the
existing source posture transition duration. These blends/time mapping are
explicit integration adaptations, not a claim of bit-identical source timing.

A ledge drop without observed upward launch enters the middle of the ordinary
jump pose gradually. That fallback is not the separate source long-fall,
ragdoll, climbing or water behaviour; those systems remain outside scope.

## Single-owner API — required integration order

```gdscript
var airborne = preload("res://scripts/preview_airborne.gd").new()
airborne.bind(hero_root, visual_motion) # Once, before any animated pose.

var result: Dictionary = airborne.sample(
    physical_delta, player.is_on_floor(), player.get_real_velocity().y,
    fresh_base_local_poses, fresh_base_visual_offset,
    &"on_foot", authority_epoch
)
```

`sample()` returns `valid`, `active`, local `poses: Array[Transform3D]`,
`visual_offset: Vector3`, phase/progress/ages and authority epoch. It never calls
Skeleton setters or moves any node. `bind()` is also read-only; it captures the
actual imported rest/skin. `reset()` resets internal transition state only.

The host must own final pose application:

1. Resolve action authority first. Death/custody/vehicle/traversal/water owners
   take precedence. The helper handles only `pose_authority == &"on_foot"`;
   other owners clear pending air/landing state and are passed through.
2. Create a **fresh base locomotion target from cached rest**, not from last
   frame's already blended air pose. Current locomotion is a direct writer;
   either refactor it into a sampler, or evaluate it only inside this one host
   owner after restoring its canonical base, then capture its target.
3. Call airborne every owned frame, including grounded idle/walk frames, so
   takeoff can carry the last approved grounded pose. Feed actual post-physics
   grounded/vertical velocity and full elapsed dt, not input intent or a second
   jump timer. On a new actor/action ownership lifetime, increment the epoch.
4. Apply exactly one selected final pose/visual offset. Never run independent
   locomotion and airborne writers after one another on the rendered skeleton.
   For `valid=false`, keep the host's valid target; never apply missing output.

The helper validates finite motion, pose count and unchanged canonical bone
translations/scales. Invalid input resets its state without touching the live
rig. External systems that deform the base beyond this contract should call
`reset()` and retain their own pose rather than ask this helper to validate it.

Bind again if the rig, rest hierarchy, normalization or static visual-parent
transform changes. Root translation/yaw/physics continue to belong to the host.

## Contact and performance boundaries

The sampler builds exact convex support hulls from 734 actual rigid boot
vertices via the imported skin inverse binds. The two cached hulls contain 210
points. Candidate local poses are composed through the real bone hierarchy;
the visual-only offset preserves the original foot plane, including an authored
nonzero rest offset. The body/capsule/gravity/velocity are never changed.

Full-skin testing below checks all 8338 vertices, including weighted cloth, for
this ordinary unarmed pose range. It does not establish contact for weapons,
other avatars, arbitrary slopes, ladders, vehicles or future animations.

## Verified checks

Godot `4.7.2.stable.official.ed1daf0bf`:

```text
--headless --path godot/mafiozi_walk --script res://scripts/preview_airborne.gd --check-only
--headless --path godot/mafiozi_walk --script res://scripts/test_preview_airborne.gd
```

Both exit 0. Actual male GLB test: **20 walk/run → air → landing → idle cycles,
4000 complete skin samples × 8338 vertices**, with original body position/yaw
unchanged. Results:

- Lowest full-skin Y: -0.000018779 m to +0.000000570 m (under 0.019 mm error).
- First supported landing-frame skin change: exactly 0 m.
- Maximum adjacent 60 Hz full-skin displacement across all phases: 0.11561 m.
- Every cycle returns to the original bones/visual offset: no permanent crouch,
  accumulated rotation, stretched bones or lost head height.
- Bind/sample/reset do not write the live rig; nonzero rest offset recovers.
- Source apex thigh/XYZ arm coefficients and rest endpoints match.
- External owner/epoch changes clear old landing state; invalid samples fail
  closed; zero-delta repeats are deterministic; .25/.6 s steps are not clamped.
- Sampler CPU p50/p95: 16/60 microseconds in this headless test. This excludes
  rendering and the deliberately expensive independent full-skin verifier.

The initial test exposed a takeoff-floor mismatch when the sampler accepted a
newly released airborne locomotion base. It was corrected by carrying the last
approved grounded output; all 20 cycles above passed after that change.

**Remaining:** root/successor integration under one pose owner, independent
review, native walk/run/jump/landing observation and actual frame-time comparison.
No LIVE animation or game-FPS claim is made from these CPU results.
