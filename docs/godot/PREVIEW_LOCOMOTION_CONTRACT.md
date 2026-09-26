# Canonical standing locomotion in the Godot preview

Implementation: `godot/mafiozi_walk/scripts/preview_locomotion.gd`, called after
`move_and_slide()` by `preview_player.gd`. Source is the unarmed standing
`update`/`rotate` path in `assets/maps/city_rebuild_v1/hero_walk.mjs`.

## API and authority

`PreviewLocomotion` extends `RefCounted`:

- `bind(hero_root: Node3D, visual_motion: Node3D) -> bool` validates the actual
  imported skeleton and caches rest poses and boot support geometry.
- `update_pose(delta, horizontal_velocity, grounded)` consumes physical motion.
- `reset_pose()` restores original poses and the visual offset exactly.
- `get_status()` reports readiness, errors, phase, gait, speed and support counts.

The controller supplies `get_real_velocity()` and `is_on_floor()` after physical
movement. Held input cannot animate walking against a blocking wall. The helper
does not write body position, collider, velocity, heading, HP or saved state.
`LocomotionOffset` belongs to the visual subtree above model normalization.
Missing canonical bones or boot geometry fail to a reported static pose.

Scope is unarmed idle/walk/run. Airborne movement blends toward rest; this is
not a migrated jump/dive pose. Combat, weapons, seated poses, foot-lock IK,
stairs, slopes, swimming and saved appearance remain separate tasks.

## Source coefficients and rest-relative poses

Bone names are chest plus thigh/shin/foot/upperarm/forearm on both sides. Each
rotation starts from the imported rest quaternion. Translations/scales remain
unchanged, with no accumulated rotations or permanent idle crouch.

| Term | Canonical coefficient |
| --- | ---: |
| Moving phase | actual horizontal metres × 2.3 radians |
| Gait approach/release | `1 - exp(-10 × dt)` |
| Chest roll | `sin(phase) × gait × 0.018` |
| Opposing thigh swing | `step × 0.56` |
| Shin flexion | `max(0, -step) × 0.52` |
| Foot pitch | `-step × 0.22` |
| Arm counter-swing | `-step × 0.38` |
| Forearm flexion | `-max(0, step) × 0.12` |
| Source bob | `abs(sin(phase)) × gait × 0.026 m` |

`step` has opposite signs for left/right. As in the source, idle phase advances
at 3 rad/s while gait decays, and gait below 0.0001 becomes exact zero. Phase
wraps at TAU continuously. Reset/settled idle restores every original bone pose.

## Flat-ground contact adaptation

The actual boot skin has 734 vertices rigidly weighted to the two foot bones.
Binding transforms them through their actual skin inverse binds and builds two
native convex hulls with 210 support vertices. The linear support minimum is
the same as the complete rigid boot surface; this is not a guessed ankle box
or sampled subset. No hull generation or mesh extraction occurs during update.

After posing, two real foot transforms and cached points locate the lowest sole
in metre space. When physically grounded, the visual child is shifted to put
that sole on the body's foot plane, replacing unsupported bob or sinking in the
current flat preview. In the air the contact offset releases smoothly and the
remaining source bob decays. The capsule remains authoritative and unchanged.
This is an explicit flat-ground Godot presentation adaptation, not full source
IK parity or certification for arbitrary slopes, stairs, cars or water.

## Verified headless results, 26 September 2026

Godot `4.7.2.stable.official.ed1daf0bf`, after actual GLB import:

```text
--headless --path godot/mafiozi_walk --script res://scripts/test_preview_locomotion.gd
--headless --path godot/mafiozi_walk --fixed-fps 60 --script res://scripts/test_preview_player.gd
--headless --path godot/mafiozi_walk --script res://scripts/test_preview_player_materials.gd
```

23 locomotion assertions PASS over 720 actual walk/run poses. All 734 original
boot vertices are independently skinned for the ground comparison: minimum
floor Y ranges from -0.00001874 to -0.00001777 m (under 0.019 mm). Maximum boot
movement per 60 Hz frame is 0.06324 m and contact-offset change is 0.00988 m.
Tests cover 30/60/120 Hz phase, preserved root, finite bones, unchanged bone
lengths/scales, restored idle head height, exact reset, invalid motion samples
and no ground gait from airborne horizontal speed.

The controller's original 16 tests plus actual held-input-against-wall gait
recovery PASS. All seven material surfaces/8338 authored colours remain intact.
Helper update CPU p50/p95 was 17/44 microseconds while the headless controller
test also ran. These are diagnostic CPU timings, not render time, game FPS or a
before/after full-scene benchmark.

The coordinator accepted materials and rear orientation in the earlier native
frame `outputs/godot_preview_materials_20260926.png`. Animation needs a new native
LIVE run in the same single application window and independent Astra 11 review.
Programmatic `Input.action_press` QA must be labelled accordingly; it does not
prove physical keyboard input was observed.
