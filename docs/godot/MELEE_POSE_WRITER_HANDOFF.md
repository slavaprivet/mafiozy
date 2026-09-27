# Preserve authored melee matrices in Godot's actual skeleton

The source pose sampler was correct, but Godot4.7.2 `Skeleton3D.set_bone_pose`
decomposes a local transform into rotation and scale. Melee IK has inverse-parent
shear: the previous sole writer displaced actual kick skin by **5.274cm** and
punch skin by **2.620cm**. Three earlier canaries did not cover this defect.

`preview_player.gd` now retains full hierarchy matrices through final global
pose overrides only for selected melee poses. The existing local writer still
runs, and it remains the sole selected-pose writer. Every ordinary selected pose
and every pose-owner/new-life transition clears the old overrides, so walking,
vehicle occupancy and physical ownership cannot be hidden by a stale attack.
No combat input or source damage owner is enabled by this change.

Actual imported8,338-vertex skin was checked in15 attack cases before/after.
Full-matrix override error is below0.5µm; ordinary restoration global error
below0.25µm. `test_melee_pose_writer.gd` has346 checks PASS, including engine-frame
persistence, ordinary restoration and external-local-writer visibility after
vehicle/physical/new-life transitions. Existing physical endpoint253 checks PASS.
Independent evidence remains in `outputs/coordinator21_melee_pose_review`;
original failures are preserved as `skin_writer_before.json` and `report_before.json`.
These are actual engine/skin CPU checks; new loaded-scene GPU/FPS acceptance is open.

Independent final writer121 + sampler lifetime/threshold95 checks PASS on
player `63e9560f7f463d24f7844feb109fb701ee419a04f44e34d6aaf2c78c9a3b9ba2`
and sampler `33b0780f7482602ccfc28e1433c702657742df124e0c201d8aa5232a84161be1`.
Actual physical-body capture matches displayed globals within0.123µm; all15
skin cases are within2µm. Alternating1,200 samples per mode with forced engine
global updates: writer p50/p95 18/26µs before,22/43µs after. This small shared-host
CPU fixture is not a full-scene FPS result.

## Physical handoff remains a separate gate

`exit_ragdoll_body.capture_world_frames` already reads actual bone globals,
including the displayed overrides. However, authored melee may stretch limbs
by about20%, while the physical driver requires canonical scales and segment
lengths. Its checks must remain intact. A continuous transition from the
displayed attack to the constrained physical body is still required; this
writer fix alone does not make melee-to-ragdoll admission work. Do not silently
drop a hit, teleport a hand, or remove those checks to claim completion.
