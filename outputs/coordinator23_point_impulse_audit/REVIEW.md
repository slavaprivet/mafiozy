# Point-torque834 review and minimal merge

30 September 2026. Outputs-only; no NPC/production/GPU/Git edits. One new bounded native parallax test; no834 rerun.

## Exact closure and disposition

Verified frozen owner **a1946b00be3a2f2ba9d22d035a785277eac1060800aa9f171af1067c9b574b6a**, helper **fe4ddd5272e6ea0f0b746b003c8254022a561120a867b54088355ffddb53abe2**, owner.patch,834 report and comparison against ready_point_impulse/RECEIPT.json. Mutable point_impulse_candidate currently equals the frozen owner. Raw834 output has834 checks/no errors and comparison has no errors. These are verified author evidence, not an independent repeat.

`closure/MANIFEST.json` pins and copies the exact owner/evidence/scripts and critical host/body/lifecycle/projectile inputs. It deliberately calls itself an audit closure, not a standalone full-scene build; the candidate05 scene/resource receipt is copied separately. Important: the author's native_point.gd -> point_native_base.gd -> point_base.gd actually loads mutable point_impulse_candidate. Its present equality to the frozen SHA was checked; future reruns must bind frozen paths or assert this SHA first.

Candidate05 owner remains cd0f09b (old slide); shared production owner is **aff6e378a23804f55886a86de53e4e59db1439f5a9471d276da0eeec91149e07** (no slide and extra _current guard). Full-copying a194 over shared would drop that guard. Author integration_aff6 owner **9e019898f91073fe51bb1076c17f8ef73b6c7289fdd4eb2372054f1bb9fbcdfd** preserves it. That merge is sensible but inherits the shotgun direction bug below.

**Review outcome:** point share genuinely adds torque without extra total J. HOLD the uncorrected shotgun direction for integration; use the narrow correction proposal if accepted. Even corrected packet is not the completed headshot/medical/LIVE release.

## Newly reproduced defect: real shotgun direction differs by43.152 degrees

Same issue as earlier review remains in both a194 and9e019:

- Actual host preview_weapons aims from camera to target, emits native projectiles from muzzle toward that target plus spread, and publishes camera_direction separately.
- Owner stores flattened camera_direction as shot.base_direction. For shotgun it stores first native terminal point/normal but discards terminal.direction; final grouped damage passes camera direction into physical impulse.
- Source/native point proof therefore validates the point, but not the direction applied there. Cardinal834 fixture sets camera origin=muzzle origin, so it cannot expose parallax.

New `test_parallax.gd`: actual candidate05 main, original3rigs, native projectile producer/collision and completed ordinary HP lifecycle; source Fire verifies ammo decrement. Fixture separates camera and muzzle laterally.75m, both aim at the same chest target at.8m from muzzle. Existing isolated vehicle corridor is retained, explicitly not player-input/LIVE acceptance.

| Case across3original rigs | Frozen-aff6 merge9e019 | Minimal corrected owner |
| --- | --- | --- |
| Native first owned terminal direction | (-1,0,0) | Same |
| Physical impulse direction | (-.729537,0,-.683941) | (-1,0,0) |
| Error from terminal direction |43.152418 degrees |0.0 degrees |
| Total / point share |225 /2.5 N·s |Same within float precision |
| Actual selected segment |chest |chest |
| Completed HP / replay |final_death / one point |Same |

**110 checks PASS**, six paired native cases, exit0, no engine errors,3.989s. `parallax.json/log` contains evidence. Diagnostic checks explicitly require the old mismatch and the corrected alignment; they do not falsely label the old behaviour good. This run validates the exact9e019 merge and proposed corrected hash on candidate05 dependencies for this scenario. It does not relabel either hash as the834-tested hash.

## Minimal proposed correction and merge

`shotgun_direction.patch` is four small edits against9e019:

1. Save first accepted target terminal.direction with its existing point/normal.
2. Add an optional physical_direction argument to _apply_hit.
3. Use that only for HitImpulse.bullet; keep existing source HP dir_r/dir_c and grouped damage semantics untouched.
4. Pass group.physical_direction when committing the one per-target shotgun transaction after all7 terminals settle.

This preserves first-contact semantics, not a new weighted pellet vector or fictitious midpoint. Single bullets still use their actual impact.direction; blood, HP, UID, ammo, terminal cancellation, one-time receipt and current-life checks remain unchanged. First-contact selection can depend on accepted terminal order, just as the preexisting point did; deterministic permutation-independent selection would be a separate declared policy change.

`corrected_owner.gd` SHA **e4ecf5b39a9d06244d51c01f9e1c4d2c8268ee90639600c690b09572d4096f04** is outputs-only. `from_shared_aff6.patch` is the full minimal owner merge against current sharedaff6, including point feature+direction correction while preserving its no-slide/current guard. Also add the unchanged helperfe4ddd52 at scripts/npc_visual/npc_hit_impulse.gd and export it. Recheck sharedaff6 SHA before applying; do not overwrite newer headshot/wound changes. Root should run merged native and export checks on this new hash before any live rollout.

## Point impulse semantics: what is now correct

Ready owner _publish_physical selects total J only for same-event completed applied HP and IDLE medical/final activation. Medical total<=75N·s, final weapon table<=225N·s. Horizontal point share is normalized(J)*min(2.5,.10*|J|), and uniform share is J-point. Existing host starts all16segments with uniform/75kg; after successful activation and before another physics step, owner rechecks:

- exact adapter.receipt(id)==last_result;
- current owner lifetime;
- same physical host object;
- modeACTIVE;
- point event not already consumed.

It marks consumed BEFORE the native point call, then calls existing body.apply_impulse(point,pointJ,id+':point'). That body chooses the closest capsule surface among16segments, rejects nearest distance>.75m and applies at offset point-bodyOrigin. This now produces actual lever-cross-J torque. Existing generic body code does not dedup, so preserving the owner's consumed guard matters. If the point call rejects, the uniform share stays and point share is lost; last_impulse records rejection and smaller actual total. It neither reapplies full J nor retries: safe under-budget failure, not full requested response success. Metadata requested_total_ns versus actual impulse_ns must remain distinct.

The point is actual standing-capsule native contact, NOT an exact skinned-triangle/anatomical hit. Nearest ragdoll capsule selection is a separate geometric mapping, not proof that the struck anatomical segment was identified. The .75m generic tolerance is a fail-closed ceiling, not measured perfect body-part fidelity.834's1.7m contacts all select head; the new parallax cases select chest. Hand/foot/arm edge contacts and adjacent overlapping capsules are not covered by these results.

The fixed2.5N·s share is much safer than applying225 to one limb, but limb masses differ: weights sum72, default total75kg makes a hand about.521kg, head5.208kg. Same2.5N·s implies free linear velocity increments4.8m/s versus.48m/s before constraints. Hence head/chest success does not prove hand/foot joint safety. Test segment identity, lever and limb contact bounds rather than blindly increase2.5 or relax joints.

## Honest remaining acceptance limits

- Original834: all3rigs×4cardinal×medical/final×uniform/split =48 cases;24 point cases give positive delta-angular-dot-torque, angular delta.752–.869rad/s and6.198–7.302deg at tick10. Genuine torque evidence; contact height1.7m, not all body parts. Earlier398 included chest but a different pre-diagnostic SHA.
- Joint max.114666m remains under unchanged.20m. Max increase versus uniform approximately10.3µm. Floor minima match uniform exactly but remain the pre-existing roughly13–14cm capsule intrusion; equality is not a floor-clear PASS. No body/mass/collision/reserve/tolerance change is in this overlay.
- First point application is synchronous after activation, outside query flush in the tested producer path; no delayed kick or additional solver step. Real ordinary Fire/input plus runtime callback ordering still belongs in root combined test.
- Medical75 now includes local torque. Prior translation-only75 cardinal getup fixtures do NOT validate this new point split's getup. New834 stops at fall/ACTIVE; actual medical release remains absent. Do not fabricate medical release or infer all diagonal/obstacle poses recover.
- No point impulse on already ACTIVE finishing hits, corpse hits, survivor torso hits, RPG or player-foot contact. Survivors keep250ms idle pause; source visible .48s flinch still separate.
- **Always-lethal anatomical headshot policy excluded.** High834 contacts may remain medical; this is deliberately old ordinary HP survival in a physical fixture, incompatible with calling the combined user headshot request complete. Integrate separately tested anatomical admission + final-death branch and rerun combined response; cosmetic closest-capsule choice is not a headshot proof.
- Author per-hit paired cost p50/p95 uniform2565/2885us vs split2644/2972us (+79/+87us), not whole engine physics/render cost. No current full-scene FPS/memory/LIVE acceptance. User input and export acceptance still required after merge.

No production edits applied. Deliver only the scoped owner/helper proposal through Root; no NPC shared changes by this auditor.
