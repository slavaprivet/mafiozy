# Authored melee impulse calibration

2026-09-27. Pure new module `scripts/character_physics/melee_impulse_profile.gd`; numerical tests `scripts/tests/test_melee_impulse_profile.gd`. No integration, main, driver, body or impact sink changes.

## Scope and source boundary

This is an **authored game-force proposal**, not source-authoritative force telemetry, measured human biomechanics or approved combat balance. It does not produce contacts, receipts, IDs, HP, stun/death, knockdown decisions, locomotion changes or physical writes.

The current source audit is `outputs/astra21_character_impact_melee/CONTRACT.md` (frozen world SHA `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5`). Source confirmed melee contains HP/presentation power and retained contact geometry, **not SI J, actor masses or complete incoming striking-limb velocities**. Earlier `docs/city-rebuild/WALK_MELEE_CONTACT_HANDOFF.md` documents the accepted sequence/contact window, but its old unavailable-server-handler limitation is superseded by the later source authority audit.

The host must retain the original attack/target IDs, contact window, life/session checks, source admission and HP owner. It selects a calibration only after an actual admitted contact and supplies missing physical measurements explicitly. `admitted:true` is a required caller assertion, not an authentication proof minted by this module. Source damage must never become J. Existing role-specific source position writes (.09/.07 source cells) must not be applied again by an independent physics relocation path. Source milliseconds and native seconds remain distinct.

Inputs already use native world metres and m/s; do not multiply them by source scale4.1 again. The outward surface normal points from the defender towards the striking limb. The module converts it to inward compressive force direction. Point/normal must come from actual contact, not from HP, an angle or an invented bone location.

## API

`authored_profile("punch" | "shove" | "kick")` returns one of three transparent initial tuning profiles:

| Calibration | Effective striking mass | Restitution | Closing-speed limit | J limit |
|---|---:|---:|---:|---:|
| punch |3 kg|.05|6 m/s|45 N·s|
| shove |20 kg|0|3 m/s|80 N·s|
| kick |8 kg|.10|8 m/s|100 N·s|

These names are calibration choices, **not automatic mappings from source attack types**. Source heavy/backfist, airborne/dropkick, block and RNG selection stay with source. Unsupported names return an empty profile. An owner may explicitly tune the six profile fields; the complete supplied coefficients appear in output provenance. Profile IDs `authored_melee_*_v1` identify this formula/profile family, not source hit IDs.

`propose(contact, calibration)` requires:

- `admitted: bool` true;
- `world_point: Vector3` and unit `outward_normal`, unit `attack_direction`;
- `attacker_point_velocity_mps`, `defender_point_velocity_mps`: **complete actual world velocities at contact**, including the striking limb and applicable angular point velocity;
- `attacker_mass_kg`, `defender_mass_kg`, explicit positive masses;
- `stance`: standing/crouched/prone/airborne/seated.

Missing measured limb velocity rejects. The helper never synthesizes limb velocity from profile speed, body speed, damage or animation timing. It never adds strike speed to measured motion.

Result includes bounded `impulse_ns: Vector3`, scalar magnitude, unchanged `world_point` and stance, `force_profile_id`, separate `measured`, `model` and `authored` sections, `proposal_only:true`, `balance_approved:false`. Unknown HP/identity envelope fields are not used or mutated. The host keeps those in its original authoritative envelope.

## Formula and limitations

Let inward direction `n = -normal`, measured closing speed `v = (v_attacker_point - v_defender_point) dot n`, and reduced mass `μ = 1 / (1/m_striking_effective + 1/m_defender)`. An admitted approaching contact proposes:

`J = min(J_limit, (1 + restitution) * μ * min(v, speed_limit))`

The vector is `n * J`. Back-facing attack directions, tangential/zero closing speed and separating contact return a valid **zero** proposal with an explicit reason. There is no RNG or lower impulse floor. Both caps are authored gameplay limits and are exposed in output; the speed cap does not claim the original measured speed was smaller.

This is a bounded translational reduced-mass approximation. It does **not** solve the full rotational effective-mass/inertia denominator or friction impulse. It does not assert that applying the defender-only proposal conserves momentum for the complete two-body scene. The numerical uncapped two-mass model has the expected equal/opposite momentum/restitution identity; applying reactions remains the host's explicit physical policy.

The contact world point is forwarded unchanged. The sole native body application computes off-centre torque through `apply_impulse(J, point-COM)`; do not additionally apply `r cross J` as a second torque impulse. Do not overwrite velocity or teleport the actor.

Stance is forwarded to the existing impact/reaction policy. This module introduces no second stance multiplier, knockdown threshold or gait owner. Small profile J does not authorize overriding source death/knockdown; authenticated flags retain their existing owner. Stable gait and realistic reactions still require the contact, policy, sink, rig and native integration tests/LIVE observation.

## Validation and cost

**169/169 numerical checks pass**: analytic J, signed normal, restitution/scalar momentum identities, monotone capped profiles, separating/tangent/backface suppression, moving defender, shared-velocity invariance, world rotation covariance, off-centre point preservation, stance pass-through, HP/ID independence, missing/admission/mass/normal/velocity/tuning negatives. Invalid/nonfinite/oversized values fail closed; effective striking mass cannot exceed explicit attacker mass.

Example punch: attacker75 kg, defender80 kg, effective3 kg, actual closing5 m/s, e=.05 → **15.18072289 N·s**. This is the authored formula's result, not a claim about real punch measurement.

10,000 pure calls in100 batches: **15.99/19.42 µs p50/p95 per call**, headless CPU only. No loaded-scene FPS/physical integration claim. Evidence: `outputs/coordinator21_vehicle_liveqa/melee_impulse_profile_test.json/.log`.

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk' --script res://scripts/tests/test_melee_impulse_profile.gd
```

Production readiness is bounded to this pure calibration API. Actual source contact/velocity provider, single-consume authority delivery, HP behavior, all stance reactions and LIVE stable gait remain outside this package.
