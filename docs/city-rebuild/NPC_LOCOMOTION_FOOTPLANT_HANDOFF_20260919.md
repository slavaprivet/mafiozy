# NPC gait and foot support — bounded patch

Ready for coordinated LIVE reload. No GPU tab opened by this audit.

Actual male/female rigs at1.9m have combined thigh/shin lengths .438/.463m. Previous standing animation moved a foot only .357/.377m fore/aft while the root travelled2.732m per full cycle (2.3rad/metre). This explains the slow-looking legs and visible skating. Speed classification and source/render interpolation fixes belong to root in `npc_population.mjs`; this patch consumes its actual `gaitDistance` and measured speed.

`npc_locomotion_pose.mjs` adds NPC-only standing leg IK. Full walk stride is2.32×leg length:1.017m male,1.074m female. Linear support occupies52% of a cycle; swing lifts the foot6.5cm at nominal height. A quarter-cycle offset aligns the existing opposite arm motion. Pelvis presentation lowers roughly9cm so both physical leg segments reach without stretching. This changes only the visual scaled pivot, never the actor's authoritative root.

Running uses a longer stride (at least2.85×leg length, then speed×.52 seconds) and shorter support fraction, keeping ankle reach bounded. At2.6 and7.8m/s the measured cadence is3.846 steps/second instead of accelerating to implausible very rapid footsteps. This is a stylized sprint presentation; LIVE appearance remains to be assessed.

`hero_walk.mjs` gains optional `presentation.gaitRadiansPerMetre` and a caller-owned `gaitOutput` buffer. The default hero coefficient stays2.3 and original hero controls, melee and postures remain unchanged. `npc_actor.mjs` passes the opt-in values and applies the foot pose only for standing locomotion. Profession/mercenary actions, gestures, crouch/prone, combat actions, injury/death/fall, swimming and vehicle states reset/block it. Weapon upper-body poses are preserved. Actor diagnostics now include locomotion stride, stance, blend weight and measured leg length.

## Verification and cost

`test_npc_locomotion_pose.mjs` uses actual male/female GLBs on straight constant-speed trajectories at1.5,2.6 and7.8m/s. Support-foot world drift drops from about1.48/1.45m/s while walking to numerical noise. Bone-length error stays below4e-15m and root positions remain exactly those supplied by the host. Profession interruption resets the pelvis overlay.

Fifty real rig contexts, same warmed pose workload: added foot-support CPU p50 .230ms/p95 .383ms per batch. No warmed THREE Vector3/Quaternion/Euler constructions, no new meshes/materials. The implementation updates leg matrices directly rather than traversing the full model twice per leg. Report: `outputs/npc_locomotion_pose_20260919.json`.

Existing NPC actor, social/activity pose, hero walk and posture suites pass. Module syntax checks pass. These are CPU bone/pose tests, not loaded-game FPS or visual acceptance. Turning foot anchors, uneven-ground per-foot sampling and stop/run transition appearance are not claimed fully LIVE verified. Root performs the single shared reload and evaluates the combined interpolation/gait result.
