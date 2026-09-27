# Local joint hit reaction — agreed implementation scope

Root21 accepted this API after requesting a new `scripts/character_physics/local_hit_reaction.gd` pure presentation sampler. Only that new helper, its scoped tests and own docs/outputs belong to Artist21. Body/driver/pose/player/main/recovery remain their current owners. Phone IK remains deferred.

This is a local presentation extension with explicitly tuned joint springs. It is not a source physical-force provider, an authoritative hit validator, a conservation-of-momentum solver or an HP/death command. The same incoming impulse must not also be applied to physical rigid bodies through this helper. Root's combat/physics bridge decides which reaction owner consumes an admitted hit and switches to full ragdoll separately.

## Units and inputs

- `bind(actor_id, epoch_id, rig)` binds one actor to the actual 28-bone local rest hierarchy. Epoch is a nonnegative integer or nonempty bounded string; types must match exactly. `rig` supplies names, topologically ordered parents, rest_local transforms and explicit `inertia_kg_m2` for seven selected joints. Positive scalar inertia is isotropic; positive finite Vector3 is a diagonal tuning profile in the joint axes. These are supplied game tuning values, not mass inferred from HP or source appearance.
- `add_hit(event, world_frames)` requires bound actor/epoch and a bounded stable event ID, `world_point:Vector3` in actual native world metres and `impulse_ns:Vector3` in N·s. Caller supplies current admitted bone world transforms, source-event/life validation, collision/contact proof, global replay protection and external force policy. Surface normal cannot substitute for incident impulse direction.
- Nearest selected upper-body bone segment chooses the local response. Moment `r × J` is projected into the current joint basis and divided by its explicit tuning inertia. Selected ancestry applies bounded attenuation; distributing these angular presentation kicks does not claim to preserve one physical whole-body impulse.
- `sample(delta, base_local)` returns `poses:Array[Transform3D]` in the supplied 28-bone order, selected_pose, active and residual_energy_j. `apply_to_selected(delta, base_selected)` accepts the existing valid pose dictionary and preserves visual_offset, visual_rotation and authority_epoch exactly. It generates no authority epoch.

Selected joints: spine_01, chest, head, upperarm_l/r and forearm_l/r. Root, pelvis and all legs/feet keep their original base poses. All original bone origins/scales remain exact. The base pose must match the bound rest translations/scales; root translation and visual heading belong to the existing writer. Inputs and nodes are never mutated.

## Bounded response profile

Analytic critically damped spring per axis: `x(t)=(x0+(v0+ωx0)t)e^(-ωt)`, `v(t)=(v0-ω(v0+ωx0)t)e^(-ωt)`. Angular frequencies are14rad/s for spine/chest,18 for head and16 for arms. There is no random motion, timer, scene callback or catch-up integration loop. Finite nonnegative delta is capped at0.1s.

Presentation angular velocity vector magnitude is capped at8rad/s and additive rotation-vector magnitude at0.25rad. The vector composes around the current joint axes as `q_base * exp(rotation_vector)`. Canonical-rest YXZ Euler coordinates are used only to check an additional head/torso/forearm envelope, not to apply the torque. If the existing locomotion/aim base is already outside any envelope axis, that entire bone's original basis is preserved exactly. Otherwise, if the candidate exceeds the envelope, six fixed bisection steps along quaternion interpolation select an admissible fraction; a final envelope check protects the boundary. Existing locomotion is never forced back inside the profile.

Incoming impulse magnitude is bounded at300N·s and contact must be within0.75m of a selected actual segment. Explicit inertia components must be within1e-6..1e6kg·m². These are local game-profile bounds, not a universal force or skin contact proof. The full28 canonical name-parent relationships, world frame lengths/scales and finite orthogonal transforms must be coherent with the bound rig. A128-event local defensive replay window does not replace caller-owned global deduplication. New epoch resets local springs/replay state; resetting the same epoch clears motion while retaining its defensive replay window.

Residual energy is the authored spring-state quantity `Σ 0.5 I(v²+ω²x²)`. It is not measured whole-character kinetic energy. Small settled states become exact zero, leaving idle poses unchanged. Weak local response never starts ragdoll, applies Rigidbody impulses, changes HP or moves the actor root.

## Acceptance required

Actual male/female/three genuine session rigs; finite/singular/malformed/wrong actor/epoch/replay/changed-length inputs; exact idle and metadata; different contact points and directions; bounded repeated hits; settling and residual state; base walking/aim retention, rest lengths/scales and fixed foot/root heading; CPU hot-path measurement and independent review. Headless/CPU acceptance does not replace Root21's one-game LIVE, visual contact, full-scene FPS or physical force tuning.

Separate cached-NPC/body compatibility audit remains snapshot-bound: earlier root body1f180deb rejected three cached rigs with skin_fit because it required named skin binds; these actual source-verified skins use explicit bone indices. Root fixed that in1adde5ca; independent actual Godot468 checks PASS at that exact snapshot. All three configure16bodies/15joints without resource/pose mutation; invalid names/indices reject atomically. `outputs/astra21_npc_ragdoll_compatibility/FIX_HANDOFF.md` records startup-only costs and original failures. No start, physics stepping, recovery, source physical admission or LIVE was tested. This does not bypass admission in this sampler.
