# Source crouch/prone weapon bases — Coordinator22

Frozen 2026-09-30. New owned files only; player/main, existing locomotion/dive,
weapon presentation and transport were not edited. Root owns integration and LIVE.

`scripts/weapons/weapon_posture_base.gd` supplies original hero_posture state,
original grounded gait + hero_walk posturePose/reachFoot, and final full-skin
floor correction. It extends the frozen pure weapon_pose math utilities, without
writing any skeleton. `scripts/tests/test_weapon_posture_base.gd` and
`tools/godot/build_weapon_posture_oracle.mjs` provide independent source evidence.
Evidence resides in `outputs/coordinator22_weapon_posture`.

## Ready root integration API

1. `configure_player(actual_player)` once after the actual hero exists. Cache
   actual canonical rest frames, source dimensions and original skin support.
2. Root C toggles target crouch/stand; Z toggles prone/stand. Use
   `request_posture(target, can_occupy_height)`; callback receives `(height,target)`.
   C is ignored in source cover; Z leaves cover. Do not enable cover via this API.
3. `step_posture(delta, can_occupy_height, running=false, slow_walking=false)` gives
   target/value/crouch/prone/height/eyeHeight/maxSpeed/speedMultiplier/crawl/blocked.
   `posture_state()` reads it; reset_posture(target) resets explicitly. Source
   posture value advances at 2.1/s, with smooth crouch/prone blends, and no dt cap
   in the posture controller. It checks FULL requested height before rising and
   checks the next height again on EVERY rising step. Query rejection preserves
   actual value and marks blocked. Root must pass real geometry admission.
4. Call `sample_ground(selected_locomotion, motion, aim_yaw, epoch)` every grounded
   on-foot frame. `motion` has `delta,moving,speed,distance,actor_world,actor_yaw,
   standing_phase,standing_gait`; optional `running,slow_walking`. Supply actual
   travelled horizontal distance; NAN explicitly selects source time/speed fallback.
   Standing returns the existing selected base unchanged and synchronizes the
   component clock from native standing phase/gait. Crouch/prone rebuild the full
   source gait from canonical rest at their own correct phase, then apply posture.
   This is NOT a standing pose carrying a crouch/prone flag. If attaching mid-motion,
   seed_gait(current_phase,current_gait) once; reset starts at the source zero state.
5. For a decorated result, use `selected.weapon_posture.phase/gait` and its
   crouch/prone for PlayerWeaponPresentation.decorate. Existing standing bases do
   not get this extra key; keep native phase/gait for that path.
6. Apply weapon then hit decorators; call `finish_ground(selected)` BEFORE the
   sole writer. This is a no-op for ordinary stand/crouch, matching original source;
   prone or source landing flags run full-skin groundPose. All presentation tokens
   and weapon-local transform survive. Write once, then presentation.after_pose_applied.
7. Dispose/reconfigure when canonical rig, mesh, skin, bind hierarchy or lifecycle
   changes. The floor cache rejects changed resources, replacements, queued ancestry
   and altered bind frame. Root keeps stance controls disabled under non-on-foot
   authority and owns collision, health, speed and jump/landing state.

The lower-level sample_posture/sampler tests accept supplied source frames. Root
should use sample_ground, which corrects the native standing-only gait dependency.
Source moving phase uses distance × (prone>.5 ? 3.8/maxSpeed : 2.3); full prone
therefore uses4.75 rad/m, not the existing standing2.3. Gait damping is original
exp(-10*min(delta,.1)). Idle advances phase at3/s. Crouch/prone visual bob and aim
pivot are original, replacing native standing's special boot-contact offset.
No arbitrary boot/body lift is inserted.

## Pure height predicate; physical query still required

Source stand/crouch/prone heights1.90/1.69/.62m; eyes1.64/1.40/.43m; crouch/prone
speeds1.55/.80m/s. Source standing speeds are4.60/7.80/1.65 (walk/run/slow), while
the current game's standing movement tuning remains root-owned and unchanged.

`height_query(height,floor_y,ceiling_y,horizontal_body_intervals,radius=.30)`
returns `source_vertical_clear`, `query_required=true`, height/radius and
`center_from_feet=(0,height/2,0)`. Intervals are already horizontally overlapping
body [minY,maxY]. Exact source ceiling condition is ceiling >= floor+height-.03;
bodies wholly below floor+.05 or above floor+height are ignored. This function
does NOT claim an actual capsule sweep or admit posture by itself. Root should
query real Godot collision shapes, maintain the capsule's foot plane and exclude
only the actor's own RID. Source blocks posture requests during seat/transition,
blast/vertical traversal/busy/death; requests during jump are queued, not applied.
This component deliberately leaves those host gates with root.

## Floor correctness and optimization

The existing dive's reconstructed convex support hulls were measured to differ
from full actual skin by25.7µm for prone. They remain unchanged. This module packs
original vertices and weights once, deduplicating only identical complete skin
contributions:8338 original vertices →6673 exact supports (1682 weighted),
182072 bytes of packed support. No reconstructed hull or proxy boot box is used.
Each changed pose projects only Y with cached bind-local terms; unchanged full
poses and visual rotation reuse the exact minimum. A resource change invalidates
cache permanently until rebind. Final actor-local lowest point is moved to zero,
as original groundPose; body/world floor collision remains with root.

## Evidence and limits

16446 PASS,168 source scenarios =14 guns × values .5/1/1.5/2 × idle/move/reload.
Read-only callbacks capture stages of the real original hero.update; no pose
statement is replaced. It runs true posture, weapon, reload, look and full-skin
ground. Tests compare every bone, full source body/gait, floor, then exercise
actual PlayerWeaponPresentation/actual imported hero/sole writer/current muzzle.
Additional14 source controller steps compare clearance calls and all interpolated
values. Source files are pinned after CRLF→LF only. Actual GLB is hash pinned.

Max posture matrix error6.97e-6; final weapon+posture matrix2.17e-5; final source
floor0.818µm. Independent full8338 native scalar skin scan differs from packed
support by at most54nm across all168 cases. This is float-tolerant source parity,
not bit-exact equality or a physical terrain-clearance claim.

Final shared-host headless timings: bind15.008ms once; changed-pose floor
p50/p95 823/941µs; cached unchanged floor20/30µs (201 cache hits); full source
gait/posture→weapon→floor→actual writer→receipt p50/p95 1257/1715µs. Compared with
uncached floor, idle support cost drops about40×. Full-scene frame time/GPU still
requires root's coordinated LIVE run; this bundle alone does not prove FPS.

Passenger regression uses the EXISTING original vehicle_occupant_pose and
existing passenger seat fixture, with visibly folded thigh pose. All14 guns
correctly reject the vehicle owner and cannot reuse an on-foot muzzle. Passenger
shooting is NOT implemented or claimed accepted.

Cover is a separate missing native dependency: source hero_cover_pose has hidden,
aimed, blind and blocked modes, opposite-hand pistols, two-hand reach, timed
transitions, adaptive actual head concealment and self-geometry clearance. Source
hero_cover_host then requires posture/transition/reach/selfClear plus actual
geometry segments mount→muzzle and muzzle→0.22m forward before canFire. No native
cover controller/pose/geometry gate exists in this bundle. No fake wall or
standing-base flag was used to label cover ready. Root must keep that migration
explicitly pending. Prior weapon_pose arbitrary affine display limits also remain.

SHA256:

- Module `8e2df7dddde7fe49b0dff95c9a13dfae12d8c86c3a0fb37859dbb7bf35db2a0e`
- Test `c7d0cfb692e514cb3ce45548c4083aa74dda6ed165bbb396ed61bea7afacda2e`
- Builder `31dbeefcbf9f8518f29d66a7593a21067e0d32efe5b01a545263ce26c22d5705`
- Oracle `1f729232a73729a427addf0efd7ffa068c260a833032c486bc074bdf7fb5b00f`
- Report `71e9f6856e3a57f3c504c61e24c99ff3e96d2f8f2fe668af440b6533ba749a59`
