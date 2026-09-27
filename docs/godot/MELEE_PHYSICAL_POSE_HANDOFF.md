# Canonical melee presentation — 27 September 2026

Status: component frozen and headless acceptance passed. Visual acceptance and full-scene FPS remain with Coordinator21. No GPU process or Git operation was started for this work.

## Files and fixed scope

- `godot/mafiozi_walk/scripts/combat/melee_physical_pose.gd`: `7bea3a765b7f505314db2f8c914d6c68d604ea6d984dcd5760ab3d1775b439a4`.
- `godot/mafiozi_walk/scripts/tests/test_melee_physical_pose.gd`: actual hero, exact source sampler, production pose writer, unchanged physical driver and weak-reaction recipient test.
- Evidence: `outputs/coordinator21_melee_physical_pose/report.json` and `run.log`.

This module deliberately changes melee presentation to fixed canonical bone lengths before display. It does not change the committed exact Walk sampler, gameplay action selection, root motion, physical admission, damage, targets, ownership, momentum, or physics constraints. The original source sampler remains the source parity oracle.

## Host API

`configure(skeleton: Skeleton3D, canonical_rest: Array[Transform3D]) -> bool` binds once to the actual 28-bone rest hierarchy. Rebinding, changed skeleton version, freed or queued ancestor, invalid rest, or unsupported scale fail closed.

`sample(source: Dictionary, ordinary_base: Dictionary, epoch: int = 0, delta: float = 1.0/60.0) -> Dictionary` returns a selected-pose dictionary. Pass the exact authored source selection and the ordinary selection sampled for the same frame. `delta` must be finite and within 0..0.1 seconds. Always call for ordinary frames too: `sample(ordinary, ordinary, epoch, delta)` lets a released guard converge to gait. A fresh adapter and a fully settled adapter return ordinary input exactly without limiting gait. A new epoch discards old presentation history.

`reset() -> void` clears presentation history only. Use before handing the pose to an external owner. Same-owner cancellation can instead send ordinary samples to decay the current pose; the root host chooses its explicit cancellation policy. No history should leak into transport, airborne or physical authority. The adapter never writes the skeleton itself.

The result retains source metadata and source visual offset/rotation, owns its returned pose array and copied melee metadata, and adds `melee_physical`. A result already carrying that marker cannot be retargeted twice. Histories are bounded arrays of 28 transforms/quaternions; there is no frame queue, timer, worker, IO or resource creation in sampling.

## Presentation and continuity

Each local offset and scale is reconstructed from actual rig rest. Four arm/leg two-link chains use source hand/foot targets with a transported rest pole and shared hinge axis. Reach approaches full extension softly rather than crossing the straight-joint singularity. A quintic entry/recovery blend and persistent quaternion hemisphere choice avoid per-frame shortest-arc branch changes.

A final angular-rate guard limits local motion toward the target to 20 rad/s. A shrinking 8 rad/s reachable envelope around the ordinary endpoint ensures no last-frame attack snap. Because the ordinary gait itself moves, 20 rad/s is not claimed as an unconditional total bound: the tested worst was 21.5323 rad/s. No global bone linear-speed bound is claimed. Starting an attack at age zero uses the exact previously displayed canonical pose, including a raised guard. From an idle start, attack first and last poses are exactly the ordinary base. Guard and charge have source `melee.active=false` but still retain their raised-arm pose and receive the same bounded transition.

This is a fixed-length visual retarget, not anatomical joint-limit simulation, active balance, foot planting or exact source choreography. Root/visual source lift and spin remain unchanged; ground practice can therefore still have a grounded capsule while the authored visual lifts. Actual ragdoll constraints begin only after physical authority accepts the displayed canonical pose. No physical guard was weakened.

## Actual engine evidence

Godot `4.7.2.stable.official.ed1daf0bf`, headless:

`--headless --path godot/mafiozi_walk --script res://scripts/tests/test_melee_physical_pose.gd`

85,298 checks PASS with clean log and all dependency bytes unchanged during the run. The 2,424 phase samples cover punch, kick, heavy and dropkick, both sides, actual locomotion idle/walk/run bases, 101 phases per case. Every displayed result passes unchanged physical-driver preflight and actual weak-recipient preflight, commit and sample (including dropkick 0.40). The weak test uses explicitly TEST_ONLY inertias; this does not establish source force calibration or dispatch a physical impact.

Further checks cover input/output mutation isolation using identical reset histories, canonical offsets, first/end continuity, guard/charge on/off, exact guard-to-heavy entry, ordinary gait after settling, abrupt unrelated ordinary motion remaining untouched, epoch changes, invalid rest, double retarget, and queued rig rejection. Guard/charge transition maximum was 20.00005 rad/s. Independent reviewer ran 35 actual-main host checks against the frozen bytes, including 210 ordinary idle/walk/run/strafe/stop frames with maximum basis difference exactly zero.

| Action | Maximum local angular speed (rad/s) | Maximum source joint-origin deviation (m) |
| --- | ---: | ---: |
| Punch | 21.2218 | 0.523668 |
| Kick | 20.0008 | 0.421818 |
| Heavy | 21.5323 | 1.000846 |
| Dropkick | 20.0001 | 0.651681 |

The large deviations are intentional and visible review is still necessary. Heavy's largest difference is at source time zero: the source starts pre-wound, while the new presentation must begin at the current ordinary pose. Other deviations include limited source reach, the continuous hinge choice and angular-rate limiting. These figures must not be described as exact source parity or a negligible visual change.

Measured adapter CPU over the 2,424 actual-rig samples: p50 226 microseconds, p95 340 microseconds. This isolated headless measurement is not whole-scene FPS, GPU cost, a stable benchmark or a hard wall-clock cap. No comparable loaded-scene before/after test was performed by this author; root owns that acceptance.

Validated dependency SHA256:

- Exact sampler: `33b0780f7482602ccfc28e1433c702657742df124e0c201d8aa5232a84161be1`.
- Player/writer: `1c8660b3988ae06767f66a16ae69f9343fc6022799272c5f10c2edfb8cd87019`.
- Physical driver: `434b2b9175c1533329b897a6812d284c77e79503f1ff94c2adc1aa4af8674bbb`.
- Local weak reaction: `c5cb4afd51127a26b3a60d37b7e13ed8572c267bd207b8f9a20d307ee8ba9b36`.
