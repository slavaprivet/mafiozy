# Native authored melee pose — 27 September 2026

Pure sampler source parity passes. Production writer integration is BLOCKED:
independent review found loss of inverse-parent shear through ordinary
`set_bone_pose` decomposition. Gameplay combat and LIVE acceptance remain OPEN.
No main, player, input, physical body, damage, contact provider or authority code was changed.

## Files and frozen API

- `godot/mafiozi_walk/scripts/combat/melee_pose.gd`
  SHA256 `33b0780f7482602ccfc28e1433c702657742df124e0c201d8aa5232a84161be1`.
- `godot/mafiozi_walk/scripts/tests/test_melee_pose.gd`.
- `tools/godot/build_melee_pose_oracle.mjs`.
- `scripts/tests/fixtures/melee_pose_oracle.json`, `melee_pose_skin.json`,
  `melee_pose_skin.bin` beneath the Godot project.
- Evidence: `outputs/coordinator21_melee_pose/report.json`, `final.log`,
  `before_ground_projection.json`.

One sampler per actual canonical 28-bone hero. Call
`configure(skeleton, motion, canonical_rest28, source_scale, hero_root)` once
after the imported rig is ready, with the same canonical rest poses used by
locomotion. Configure returns false on unsupported binding/rebind. It prepares
the actual skin once, using the existing `vehicle_exit_pose.gd` skin cache;
it never invokes that module's vehicle pose sampler.

`sample(base_selected, action, posture, phase, gait, epoch)` returns a selected
pose dictionary. `base_selected` contains `valid`, all 28 full `Transform3D`
local `poses`, `visual_offset`, and `visual_rotation` (identity default).
Caller-specific metadata is retained. Input dictionaries and rig nodes remain
unchanged. The return contains `poses`, `visual_offset`, `visual_rotation`,
`authority_epoch`, and `melee` metadata; the existing host remains the only bone
writer. Full matrices, authored stretch and inverse-parent shear must survive
that writer. Applying just rotations would lose the source pose.

Optional `base_selected.scaled_offset` is the source inner `scaled.position`
in metres, before visual rotation. Its default is zero. `visual_offset` must
already include the folded `visual_rotation * scaled_offset`. This preserves
the source inner gait bob when heavy/dropkick subsequently rotate the outer
pivot. Current native locomotion has no separately declared inner offset, so
zero is the appropriate default; do not guess it from a world body position.

The host supplies the admitted source action: `type`, normalized `progress`,
numeric `side`, optional `charge`, `blocking`, `armed`, and `weaponId`.
Posture is a dictionary of finite numeric `crouch`/`prone` values; phase/gait
are the actual locomotion presentation inputs. Invalid binding/base transforms,
unknown actions, negative epochs and malformed numeric posture are rejected.
This is a typed native input contract, not a general JavaScript coercion API.
No clocks, RNG, attack admission, cooldown, recoil, HP or network IDs are owned
by this sampler. A new epoch has no hidden previous-pose state to clear.

## Source behavior preserved

Actual `assets/maps/city_rebuild_v1/hero_artist14_melee.mjs` is executed by the
oracle, not reimplemented as a second expected-value function. Source SHA256
`eeb7ca0d7d58df796c436a13e92c1ca93b601d7af2c0cc7f6616bfe600ed1835`
(13,210 bytes). Fixture records this plus `hero_walk.mjs`,
`hero_contact_ground_bound.mjs`, and the original GLB hash.

| Action | Duration | Source contact interval, seconds |
|---|---:|---:|
| punch | 0.34 | 0.035–0.19 |
| kick | 0.62 | 0.18–0.34 |
| heavy / backfist | 0.50 | 0.07–0.36 |
| dropkick | 1.25 | 0.16–0.38 |

Backfist aliases the returned heavy type. Armed/non-`none` weapon routes,
inactive actions without charge/block, crouch or prone above 0.01 are exact
no-ops returning the original dictionary. The immediate punch/kick opener does
not receive the concurrent hold wind-up. Source two-link arm IK, backfist hand
turn, kick leg stretch, both dropkick feet, hip-centred bank/tilt, heavy full
turn, guard and charge branches remain intact. The measured maximum authored
local scale is 1.200898; it is not silently normalized to one.

`melee` preserves `type`, `active`, `side`, `age`, `duration`, `contactActive`,
`contactSides`, `contactKind`, `desiredForwardDistance`, `locksMovement`, and
`visualLift`. Contact windows use scalar double constants, avoiding float32
Vector2 threshold errors at exactly 0.035/0.07 seconds.

`desiredForwardDistance` is cumulative source movement *proposal*, not a
teleport or impulse. The host must collision-sweep its accepted delta, retain
its own action/lifetime fences, and decide animation/physical authority.
`contactActive` is only a presentation window, not proof of a hit. Damage and
the authored impulse calibration remain separate. Source dropkick grounding
uses the full actual deformed skin against the actor-root Y=0 plane. It does
not query terrain, ceilings or another actor; those remain host physics work.

## Actual rig oracle and precision

Final Godot 4.7.2 headless execution: **33,411 checks PASS, exit 0** across 597
original-JS poses, both sides, five action identifiers, boundary times, idle
and moving bases, rotated visual pivots, charge/block and no-op branches.
The real hero has **8,338** source vertices (not 8,388) and 28 bones.

All matrices normally have a 0.00005 component/vector error bound. Ten
near-straight leg IK cases amplify float32 arithmetic into a maximum local
basis discrepancy of 0.000353567 (~0.0203 degrees). Only identified leg bones
in the 12 independently skinned canary cases receive a 0.0005 local bound;
each additionally must pass the much more meaningful all-vertex bounds below.
No bends, times, scale or choreography were changed to hide this discrepancy.

The original imported local rest translation is effectively exact (maximum
scalar discrepancy 1.11e-16 source units). The measurable precision difference
appears when composing actor-relative rest frames in float32: 6.108e-7 source
units; derived segment lengths differ by 1.951e-7. Near the straight two-link
singularity the square-root bend calculation amplifies this. Native skin
weights also have importer quantization up to 1.52513e-5. Therefore this is a
qualified native arithmetic/import precision tolerance, not an assertion that
all original local rest translations were rounded differently.

Independent actual skin reconstruction uses native mesh positions, skin bind
matrices and weights, without the sampler's grounding calculation. Imported
vertex order differs: correspondence uses original position, sorted bone
names and the quantified weight quantization tolerance, across all seven
meshes. It does not compare unrelated same-index vertices.

- 12 × 8,338 actual deformed vertices: maximum error **0.081303 mm**;
  maximum per-case RMS **0.014898 mm**. Required bounds are 0.1/0.02 mm.
- All 597 cases' feet and hand socket positions: max **0.000515 mm**.
- Authored arm/leg segment lengths: max **0.000358 mm**.
- Final dropkick contact minimum Y differs from source by approximately
  1.49e-8 m; the source near-ground correction is retained.
- Actual player sole-writer round-trip on three original canaries: full local
  matrix error at most 4.771e-7. **This is not general writer acceptance.**
  Independent review subsequently tested kick progress 0.5 and punch progress
  0.29032258, finding skin errors of 5.274 cm and 2.620 cm from decomposing
  inverse-parent shear in `set_bone_pose`. Root owns the full-matrix/global
  override integration fix. Evidence:
  `outputs/coordinator21_melee_pose_review/skin_writer.json`. Sampler outputs
  preserve those matrices, but a rotation/scale-only writer does not.
- Sampling leaves all node transforms, bones, velocity and pose-owner fields
  unchanged; malformed-input rejection does not poison later valid sampling.

## CPU work and reproduction

Final local headless sampler measurements on the actual hero, excluding oracle
reads, independent skin verification and all file writes:

| Work | Samples | p50 / p95 |
|---|---:|---:|
| Ordinary/guard pose | 428 | 96 / 168 µs |
| Dropkick pose | 161 | 727 / 1,109 µs |
| No-op | 8 | 10 / 13 µs |
| One-time skin setup | 1 | 14.814 ms |

Before the exact projection optimization, the same dropkick case sweep cost
2,291 / 2,979 µs. Cached packed influence arrays and per-bone Y projections
remove repeated dynamic transform/property operations; all mixed influences
and all rigid support points are retained. No mesh allocation/upload occurs
per sample. Residual dropkick cost is full actual skin minimum-Y evaluation;
ordinary cases skip it. These are local CPU samples, with possible shared
machine contention, **not loaded-scene performance or FPS acceptance**. Root
must measure actual integrated gameplay under the same scene/camera/settings.

From the repository root, regenerate the actual JS fixtures with a Node
version supporting `node:module.registerHooks`:

```powershell
$env:MAFIOZI_THREE_VENDOR = 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor'
node tools/godot/build_melee_pose_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_melee_pose.gd
```

The vendor variable points to the existing source Three distribution containing
`build/three.module.js` and `addons/loaders/GLTFLoader.js`; the shown value is
also the generator default. The committed fixtures permit Godot checks without
Node/vendor availability. Generator/test do not launch GPU windows. Integration
must still validate actual input, moving attack sweeps, walls/ceilings,
physical reactions, ownership transitions, source contact provider and LIVE.

Further physical transition dependency: the current character physics driver
deliberately rejects non-rest scale and segments more than 0.01 m from canonical
length. Source melee stretches reach approximately 1.2×; therefore an accurate
melee pose cannot simply be passed into that physical start gate. A separately
reviewed transition must preserve canonical physical lengths and visual
continuity. Do not remove the driver's guards or claim impact-during-melee
ready from this sampler's source parity. Queued rig/player ancestors now retire
the sampler binding immediately, before end-frame deletion; that negative is
included in the final 33,411 checks.
