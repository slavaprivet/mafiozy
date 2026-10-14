# Independent printshop placement review — CPU only

Reviewed candidate `tools/godot/map_editor_printshop_placement_candidate/printshop_placement.gd` without modifying it or the original native interior. The isolated reproduction copies the current candidate to `outputs/map_editor_printshop_review`; it creates a minimal node fixture to exercise the actual transaction methods. It does **not** admit the original GLB or replace the root's separate original-asset tests.

## Reproduced findings

1. **P1: rejected rollback can mutate retained transaction state.** `rollback_placement()` line 196 combines busy, invalid handle, and participant failure into one branch that sets `_retained = true`. Calling it with an unrelated `RefCounted` before editing changes retained false → true. A `held` callback reentering this method while `_busy` is true can set retention during `end_editor_placement()`: the outer call subsequently returns `{ok:true}` with `{editing:false, retained:true}`. Invalid/busy handles must reject without side effects. Only a known owned transaction whose actual participants cannot roll back should retain. Recheck the transaction epoch, issued handle, editing, and retention after callbacks, before resume/commit.

2. **P1: shader uniforms are not protected by resource changed signals.** On Godot 4.7.2, `ShaderMaterial.set_shader_parameter()` emits zero `changed` signals. Watching the material and its Shader therefore misses uniform changes. The actual finish class uses `source_origin_m`, `source_albedo_linear`, and `source_roughness`; these affect accepted source visuals. Capture and compare exact uniform values (including resource-valued parameters) alongside shader identity, or require an actual owner-controlled immutable uniform contract. Test each source finish parameter during editor placement and require rejection before owner commit. Do not change the original shader or invent a different world/source projection recipe.

3. **P1: newly attached geometry/collider children bypass the captured inventory.** Adding a `CollisionShape3D` with `BoxShape3D` beneath the placement root leaves `_live()` true. Existing entries have lifetime/parent guards, but child membership is not guarded. Capture the relevant topology or explicitly admit owner-managed dynamic children with equivalent validation; unexplained added mesh/body/shape participants must fail preflight before moving a potentially incomplete ownership set.

4. **P2: MultiMesh watch is insufficient.** `_capture()` line 71 watches the MultiMesh resource only. `set_instance_transform()` emits zero MultiMesh changed signals; mutating its nested BoxMesh emits mesh changed but does not forward MultiMesh changed. Either reject MultiMesh admission until an exact CPU shadow is available, or capture nested mesh/material resources and exact instance count/format/colors/custom data/instance state. Do not assume headless GPU readback proves buffer identity. This is a supported-type hole, not a claim that the current original printshop contains a MultiMesh.

## Other reviewed boundaries

- Immutable descriptor adoption is opt-in, actual-owner bound, exact-source compared before adopting the recursively frozen deep copy. The borrowed main descriptor is not frozen; no aliasing defect reproduced in that path.
- Unknown partial prepare and refused external rollback must remain retained; an invalid-handle fix must not clear these states.
- Current source-ID metadata and surface material replacement guards added by root are present; those are not reported as unresolved findings here.
- Actual owner callbacks still own external authority/service/navigation atomicity. This review does not authorize moving other nine special buildings, unlocking police, or declaring a visual-only move complete.
- Inherited public `restore_original`/`attach_existing`, `request_door`, and `advance` should be included in callback-reentry tests. A trusted callback accidentally invoking mutation while the editor is busy must not let the outer operation report success against altered participants. Existing `_live` catches some later lifetime changes; prevention/resume state needs explicit testing.

## Reproduction

Run `node tools/godot/map_editor_printshop_review/stage.mjs`, then Godot 4.7.2 console with `--headless --path <absolute outputs/map_editor_printshop_review> --script test_review.gd`. No GPU, production resources, main, or Git changes.

Observed: forged rollback retained true; reentrant end returned ok with retained true; added collider accepted live; instance-transform changed 0; nested mesh changed 1 but forwarded MultiMesh changed 0; shader-parameter changed 0. This is a diagnostic reproduction, not an acceptance suite or full-scene performance result.

## Follow-up on the root's revised candidate

Re-staging after root changes shows forged/busy rollback rejects without modifying retention, reentrant end no longer leaves retained state, and the added collider causes `_live() == false`. Findings 1 and 3 above describe the initial reviewed revision and are **fixed in this follow-up reproduction**; the original asset suite remains root-owned.

The resource probe now uses the actual `preview_interior_finish.gd` shared brick shader. Exact CPU `get_shader_parameter()` snapshots detect each of its three known numeric parameters changing, and their restoration. All six change/restore calls still emit zero material `changed` signals. Capturing those explicit Vector3/float values at admission and comparing in `_live` is feasible without shader reflection or GPU. Unknown resource-valued parameters need independently admitted resource identities/lifetimes, not generic `Variant` equality assumed sufficient.

For MultiMesh, default admission refusal is safer than claiming source storage parity from headless readback; future support needs an owner-provided exact CPU shadow and nested resource guards.

**Source lifecycle HOLD:** same Script resource identity plus a restored source-file SHA do not prove which compiled implementation remains attached after reload/restore. Admit only a trusted fresh instance/scene generation under a no-reload editor lease, or require an explicit actual owner lifecycle protocol. Source hash is provenance, not compiled-code attestation; do not bypass the HOLD by re-reading a restored file.
