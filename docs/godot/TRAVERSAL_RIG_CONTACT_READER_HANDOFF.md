# Read-only actual rig contact measurement — 27 September 2026

Traversal owner, NEW opt-in `scripts/traversal/traversal_rig_contact_reader.gd`.
No existing traversal/ladder/controller/player/main/runtime writer was changed.
Frozen source/receipts: `outputs/traversal_rig_contact_reader27/manifest.json`.

## Acceptance role

Implements a measurable SUBSET of the two mandatory animation-quality audits:
`outputs/GODOT_LADDER_ANIMATION_QUALITY_AUDIT27.md` and
`outputs/godot_traversal_animation_quality_audit_20260927/REPORT.md`.
Reads registered joint-local anchor world positions from the ACTUAL Skeleton3D
after its sole writer. Compares loaded hand/foot targets to these measured points.
A returned pose proposal alone cannot establish that the model reached the target.

It measures JOINT ANCHORS, not skin geometry. All successful/failed readings state
`joint_anchor_only:true`, `displayed_root_checked:false`,
`skin_clearance_checked:false`, `visual_acceptance_complete:false`.
The physical-root error is actor.global_position versus the expected committed
root, not the displayed mesh root or pelvis. Those remain distinct host gates.

## API / real binding

- `configure(actual_actor, actual_skeleton, anchors)`: actor is a CharacterBody3D,
  skeleton is its real in-tree Skeleton3D descendant in the same World3D. Exactly
  four keys: hand_l/r and foot_l/r. Each registration explicitly supplies current
  bone name (String/StringName) and a finite joint-local Vector3 point. All four
  indices must be unique. Do not substitute a different model or copied points.
- Registered point choice belongs to the rig owner. A bone origin/offset is not
  automatically a palm skin surface or sole contact. Author tests use real hero
  hand_l/r and foot_l/r bones with explicit local offsets, not fabricated meshes.
- `capture()`: reads actor position and four bone-global full affine matrices,
  multiplies Skeleton3D.global_transform * bone_global * local_point. Preserves
  nonuniform scale/shear, including persistent global overrides. Never decomposes
  to quaternion/scale, writes bones or changes actor/model transforms.
- `measure(expected_pose)`: supports current ladder contacts and traversal
  palms/feet formats. Every target/weight/availability field is required; no silent
  zero/default targets. Nonfinite/missing/invalid weights outside0..1 fail closed.
- Loaded weight>=.80: target must be available and distance<=.05m. Actor physical
  root difference must be<=.001m. Returned errors include actual/target/weight and
  loaded/available flags for all four contacts. Zero loaded contacts reports
  `contact_gate_applicable:false` and cannot yield a green joint_anchor_gate.
- `dispose()` clears binding only. Bone count/name/parent identity, actor/skeleton
  lifetime, current tree ancestry/world and finite matrices are checked each read.
  Public configure accepts Variant node arguments so previously freed references
  fail closed before any typed-parameter dispatch can throw a GDScript error.

Root calls the reader AFTER the actual sole skeleton write for the same accepted
physics/pose frame. No independent process/timer or pose owner is installed.
Do not measure an old proposal against a later animation frame and call it a
physics regression. Keep optional QA sampling to the selected player/episode;
do not add this read/Dictionary allocation work to every NPC every frame.

## Verification / limits

Independent current-byte50 PASS x3 +parent50, including invalid public bindings,
freed actor/skeleton, duplicate limb identity, topology/reparent, both contact
schemas, complete affine matrices, unavailable/zero-loaded/error thresholds and
read-only state. Report outputs/GODOT_TRAVERSAL_RIG_CONTACT_READER_INDEPENDENT27.md.
Current reader pin6cabb998 replaces the earlier EC95 review; use final manifest.

Author actual imported hero701 PASS. Tests use the accepted source melee sampler
and existing TEST_ONLY player writer to supply the three contact-phase matrices
that exposed centimetre-scale shear losses during the earlier root audit. An
independent parent-first reconstruction of source pose frames predicts all four
registered world anchors with EXACT zero error in this headless run. Native frame
retention, read-only actor/bone/global overrides, 1mm/5cm thresholds and unavailable
loaded contacts pass. Measuring an UNAPPLIED ladder proposal against that actual
hero fails the joint gate as expected; the reader does not apply it automatically.

These tests do NOT implement/accept vault/mantle/shore/ladder animation playback.
Reader CPU cost is logged over384 measurements after64 warm samples per source
pose, excluding render and pose writer. Consult final actual_hero.log for measured
p50/p95; separate process samples vary and are not full-scene FPS acceptance.

Still required from the mandatory audits: actual male/female traversal IK writer,
palm/sole skin geometry contact, pelvis/head/weapon/ladder/rail clearance, source
admission/root-yaw/depth fidelity, displayed root error, plant slip<=2cm, effector
handoff step<=8cm, zero-weight terminal release and holster/restoration, input and
physical interruption arbitration, single-window LIVE playthrough and loaded
scene A-B-A frame/render/allocation measurement. This partial measurement must
not be used to mark those gates passed. Main/player/export/GPU/LIVE remain root-owned.
