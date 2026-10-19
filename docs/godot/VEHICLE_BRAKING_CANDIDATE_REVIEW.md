# Vehicle braking candidate — frozen for Root21 review

Production remains `scripts/vehicle_physics/vehicle_native_body.gd` SHA
`a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401`.
No automatic adoption, main edit, GPU launch or Git mutation is authorized.

## Frozen artifacts

Paths are repository-relative, except tests below are inside godot/mafiozi_walk/scripts/tests.

| Artifact | SHA-256 |
| --- | --- |
| outputs/vehicle_native_body_candidate_braking.gd | ae4d67e7f931e33e3cf65404af665579498986cb307418a45989dba5e0dfe5d5 |
| test_vehicle_physics_braking_candidate.gd | cf33cf78c3a25224e5920bce3d37aaf8901eaf9fa2900093a8246f7367273ab0 |
| test_candidate_vehicle_admission.gd | da10c7cade5f370f002538aa464b8cfb23aa7565f501ee2c3a211bd192d4275d |
| godot/mafiozi_walk/scripts/vehicle_physics/vehicle_tyre_tracks.gd | d8a8cc7cfc5d4b412d9afcbbea3cd48ab2db459b485d0147a3e01909ff97b4ae |
| test_vehicle_tyre_tracks.gd | d7c5c2b69ab00e48382ccd50558303b35c7ea89aed59234c3c70ad5b5d890676 |

Descriptor dependency is unchanged SHA99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a.
Source dynamics receipt105cce8bf2cac63136e1c5e48f38465c4bf8e448a271702136b7c014e3396faf.

## Body changes and API

Existing body/control/state API is unchanged. Candidate replaces accidental
all-axis engine damping with supported-wheel planar source coast; rejects
vertical-wall suspension support and projects tyre axes onto the contact plane.
Opposite pedal suppresses propulsion and requests service braking until speed
crosses zero. Explicit brake/handbrake also suppress propulsion. Rear handbrake
requests source12m/s² distributed over supported rear wheels. Its reduced
lateral grip0.2 is separated from ordinary longitudinal tyre grip, with an
anisotropic friction ellipse. No axis locks, velocity teleport or fake ground.
This is native3D tyre-limited physics, NOT numeric source2D trajectory parity.

## Actual verification

Godot4.7.2 --headless --path godot/mafiozi_walk --fixed-fps60 -s
res://scripts/tests/test_vehicle_physics_braking_candidate.gd:30/30PASS.
Opposite pedal and explicit service stop1.2333s/6.3142m; trajectory difference
4.77e-7. Reverse engages at1.3833s. Handbrake stops2.6167s/13.419m from10m/s;
throttle/no-throttle speed delta0.0122m/s and position delta0.00675m.

Independent test_candidate_vehicle_admission.gd:107/107PASS. Exact no-floor
impulse conservation, lifetime reset/stale rejection,120Hz partitions, signed
steering,10-degree tangent forces, rejected vertical wall and12-profile stable
equilibrium. Parent reran both suites successfully after independent review.
Tests verify candidate SHA and remove ONLY duplicate class_name declaration
in memory before compiling; production global class remains registered.

## Tyre presentation component (separate, unwired)

configure(vehicle_id,life_generation); step(delta,physics_tick,speed,contacts);
clear/dispose/stats. Single world-space MultiMesh1200 slots, source10s lifetime,
0.28m spacing,0.19m width, alpha/fade thresholds and authored#343732 color.
Actual38/38PASS; parent's warmed synthetic1200-active step p50/p95345/433us,
240samples. This is isolated headlessCPU, NOT FPS/GPU/fullcity acceptance.

Root integration requires SAME-TICK wheel contact point/normal, identity/life,
grounded/slip and trusted actual road/sidewalk/bridge surface metadata.
No second raycasts or invented visual-wheel contacts. Current body does not
publish these points, so emitter remains unwired. Main/provider wiring belongs
to Root21; no visible tyre marks claimed from resource tests.

## Open gates

Root independent actual-main review, cost and singleLIVE release remain required.
Current production suites must be rerun on any adopted bytes. Existing candidate
tests stay marked candidate-only. Surface coefficient mapping, authoritative
engine-disabled/crash state, visible dents/debris and server damage remain OPEN.
Contact identity/manifold components are proposal-only and not body-wired.
No mechanical authority is added to client controls. Camera boarding jerk is a
separate Root-owned regression, not corrected by this physics package.
