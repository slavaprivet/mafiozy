# Local hit reaction — frozen implementation handoff

READY for Root21 integration, not runtime/LIVE acceptance. The earlier f886 checkpoint/HOLD is superseded by the corrected helper b8b9d6fae7aef0109c17cc27a2b8802154c395c8f51b9d107f9cdd40c1582519. Historical failures remain intact.

## Files and interface

Implementation: godot/mafiozi_walk/scripts/character_physics/local_hit_reaction.gd.
Author test: godot/mafiozi_walk/scripts/tests/test_local_hit_reaction.gd.
Full API, bounds and ownership: docs/godot/LOCAL_HIT_REACTION_CONTRACT.md.
Frozen byte hashes and evidence inventory: outputs/astra21_local_hit_reaction_delivery/DELIVERY_RECEIPT.json.

bind(actor_id, typed_epoch, rig) accepts the genuine canonical28 name-parent/rest hierarchy and explicit positive scalar/diagonal inertia_kg_m2 for seven upper-body joints. add_hit(event, current_world_frames) accepts actor/epoch/event identity, actual world_point and caller-supplied impulse_ns. sample(delta, ordered28_base_local) returns poses, selected_pose, active and residual_energy_j. apply_to_selected preserves the existing visual_offset, visual_rotation and authority_epoch. reset clears springs; same epoch retains the bounded replay history.

Root provides source admission, current contact/world frames, alive/session state, global event deduplication and explicitly tuned inertia/impulse policy. Damage, surface normal and visual speed are not measured impulse. This helper generates no source births, HP or authority. Its seven local springs redistribute authored presentation kicks; they do not conserve a whole-body physical impulse.

## Pose integration and cost

Use the existing single pose writer: valid locomotion/aim base -> apply_to_selected -> one skeleton commit. Do not run a second skeleton callback. Correct response composes q_base * exp(local_rotation_vector), retaining current joint axes. Original origins/scales and all unselected root/pelvis/leg/foot transforms remain exact. An already-outside-envelope base bone is preserved completely. Fixed six-step bounded interpolation checks anatomical envelopes, without snapping the locomotion pose.

Caller may retain the last active flag and an accepted-hit dirty flag. When both are false, forward the already-admitted original base pose and bypass this sampler. On an accepted hit, sample once and then continue until active becomes false. This is an integration recommendation, not an implemented main hook; caller must continue its normal pose/authority validation. Avoid snapshot diagnostic deep copies in the frame loop.

Route an admitted event to the selected local presentation or rigid-body owner through Root's impact policy. Do not duplicate the same physical impulse into both consumers. Ragdoll transitions, death, recovery, feet placement and combat producers are separate owner gates.

## Completed evidence

Actual Godot4.7.2 author: 15,249 checks PASS, exit0, empty stderr, three genuine cached source NPCs resident72/169/252 (male/female/male), prepared manifest3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0. Independently reconstructed actual Skeleton frames include native normalization, heading and translation. Golden torque/current basis/inertia, analytical damping, bounds, metadata/input immutability, world feet/root invariance, replay/typed epoch/invalid frames and composed aim canaries pass. See outputs/astra21_local_hit_reaction_tests/HANDOFF.md and RESULT.json.

Independent actual Godot: 241 checks PASS, exit0, clean final log, helper hash stable. Independent synthetic analytical/negative fixtures verify quaternion composition, complete canonical parents, envelope boundaries, mutation-free rejection and local replay window. See outputs/astra21_local_hit_reaction_review/REVIEW.md and RESULT.json. These review fixtures do not replace the author's genuine model tests.

Historical f886 had an incorrect rest-Euler addition under composed aim and admitted a wrong canonical thigh parent. The old independent217/2-failure run and actual-rig direction witness are preserved. Final b8b9 corrects both. No assertion was weakened to accept the old defect.

Active sample-only CPU: resident72 p50/p95/max66/106/259us;16966/102/198us;25268/100/216us, 50warmup/2000calls each. Intake refresh excluded. Comparable previous medians65/67/66us; no speedup claim. Independent synthetic three-sampler batches: idle169/231/489us, active200/326/659us (p50/p95/max), with three intakes each32 iterations. Allocations remain fresh28-pose array/small dictionaries; projection, validation and snapshot costs are not eliminated. This is not fullsceneFPS/GPU or body-physics acceptance.

## Reproduce and limits

Godot console --headless --path C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk --script res://scripts/tests/test_local_hit_reaction.gd
Independent: same executable/path with --script C:/Users/Слава/Desktop/Мафиози/outputs/astra21_local_hit_reaction_review/test.gd.

No main/player/project/body/driver/recovery/source HP/Git/GPU edits were made for this package. Phone IK remains deferred. Root integrates and measures ON/OFF in the sole loaded game. Visible NPCs, authenticated combat producers, contact appearance, biological realism and full-scene performance remain unaccepted here.

Related root-owned cached skin fix has independent468 configure/capture/inactive/dispose checks at root body1adde5ca00cdf7165edd307f3b0d2ee59b3ff9f694b989995ba8964100b748be. Exact separate packet outputs/astra21_npc_ragdoll_compatibility/FIX_HANDOFF.md; no current body snapshot/start/recovery claim is added by this handoff.
