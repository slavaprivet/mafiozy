# Character physical impact endpoints

Driver `godot/mafiozi_walk/scripts/character_physics/character_physics_driver.gd` SHA256 **eb575e3f45c40c7e285a31d59588eae40274d373abc807cbccee27fc6761d761**. Body is unchanged **822966ac0b03bbb0dbb37085fccf915fdbc11d07d8c6d05bd9035c66f26f58f8**. This adds synchronous endpoints to the existing 75 kg preview hero driver. Vehicle `start_fall`/`advance` APIs retain their behavior; the recovery check additionally respects the impact death latch.

## Host seam

* `bind_impact_session(binding) -> {ok,error}` binds once to exact actor/life metadata and a host-provided session ID/generation. A new confirmed life/session needs a new owner; events cannot rewrite binding.
* `preflight_impact(command) -> {ok,error,pose_epoch,pose_owner}` is read-only. It accepts the physical command from `character_impact_sink`; host wraps its `preflight(route,command)` port. Local reactions stay in the separate presentation sampler.
* `dispatch_impact(command)` recomputes preflight and validates `expected_pose_epoch/owner`, then returns `{ok,event_key,pose_epoch,applied_impulse_ns,irreversible,may_have_applied}`. Additional fields report selected bone and recovery suppression.
* `impact_owner_state()` supplies `driver_mode`, actual `dead`, `recovery_suppressed`, and ordered physical RIDs. IDLE/DONE lists the actor capsule; FALLING/GETTING_UP lists the owned articulated pool.
* `fault_impact_owner(reason)` faults only this bound life's exact current `physical_impact` lease in FALLING/GETTING_UP. It stops its simulation and retains disabled walking filters. Removal of a stale host cannot fault a replacement lease. Root decides restart UX.

The session binding is a trusted in-process host contract, not source authentication. Host must read current transport/session, geometry revision, source admission/contact and real lifecycle on every event. The endpoint verifies configured rig identity, actual pool, current pose lease, binding, physics tick, actual observed native state, source-resolved contact agreement, and response bounds before mutation. The root host remains the sole skeleton writer and advances this driver only while it owns the physical lease.

## Physical transactions

Begin captures all 28 displayed world bone frames and actor velocity before acquiring `physical_impact`. It preserves the displayed motion transform across the player's authority setter. It starts the prepared body with **zero uniform J**, then applies exactly one point impulse to the nearest physical capsule. Existing FALLING applies one point impulse without resetting elapsed time, body transforms, RID order or lease. GETTING_UP restarts from the currently displayed skin, not its older frozen physical pose; its frozen pool has zero inherited motion unless an admitted observation proves a different current native state.

Observed routes never apply the reported J. They require a currently owned RID and compare supplied post-velocity/omega against `PhysicsServer3D.body_get_direct_state`. Velocity at the supplied world reference uses world COM `state.transform * state.center_of_mass_local`, including translated and rotating actors. Begin/resume transfers that velocity field to each segment. Existing observation retains actual velocities unchanged.

Final death or already-dead owner state latches `_impact_dead`; subsequent new events cannot clear it and `advance` cannot enter recovery. This is recovery suppression, not an HP write or a fabricated death decision. Existing transport deferred/seated rules are enforced by sink/host; these driver endpoints are not a replacement transport admission system.

Preflight rejects missing/replaced rig, damaged pool, stale lease/life, invalid or distant contact, nonfinite/oversized forces, unsupported physics backend/topology, and responses exceeding 80 m/s or 30 rad/s. Contact distance is the existing body API's maximum 0.75 m from its nearest capsule; actual triangle/contact authority belongs to source resolver, never this broad physical envelope. J remains bounded at 10,000 N·s and the projected segment speed/spin limits can reject smaller impulses. No clipping/scaling of J or reassignment to chest is performed.

An irreversible start failure leaves an explicit FAULTED owner, disabled walking and zero applied J. An uncertain point-impulse failure returns `may_have_applied=true` and `applied_impulse_ns=null`; it does not reset already-applied momentum or retry. The sink consumes that result terminally. The driver deliberately has no second replay cache: direct calls are not replay-safe, and durable source replay remains upstream of the sink's bounded 64-entry history.

## First-activation torque correction

Actual 4.7.2 headless probing found zero native inverse inertia immediately after unfreezing, before the first physics step. A point impulse at that instant changed momentum but lost torque. The new endpoint initializes only the selected capsule's native inertia immediately before J, then restores automatic inertia (`Vector3.ZERO`). It does not directly set angular velocity to fake a rotation or warm up by invisibly simulating the ragdoll.

The formula is the exact engine capsule AABB approximation with half-extents `(radius,height/2,radius)`, not a textbook solid-capsule estimate. Source: [GodotPhysics 4.7.2 capsule moment of inertia](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/godot_physics_3d/godot_shape_3d.cpp), and [immediate positive-inertia setter / deferred automatic update](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/godot_physics_3d/godot_body_3d.cpp). Preflight requires exactly one centered, identity-transform, unscaled capsule per body, automatic COM/inertia, unchanged fitted shape dimensions and 75 kg total mass.

`DEFAULT` is admitted only for the verified official engine hash `ed1daf0bf001b61586d9930840f2f1394092c079`; explicit `GodotPhysics3D` is admitted. The official tag [registers GodotPhysics3D as default](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/godot_physics_3d/register_types.cpp); [Jolt registration](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/jolt_physics/register_types.cpp) does not replace it. No project physics setting was changed. Other engine-default hashes/backends need verification before widening this bounded adapter.

## Actual verification and limits

```
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script scripts/tests/test_character_impact_endpoints.gd --quit-after 500
```

**253 checks PASS**, clean `outputs/character_impact_endpoint/run.log` and `report.json`. Includes real configured hero/pool, first/second J conservation, nonzero first torque equal to warmed native auto-inertia and direct native impulse at identical translated/yawed pose, observed begin/resume/existing zero additional J, all 28 bone world-frame continuity during begin and GETUP interruption, exact ordered pool/lease preservation, same-life death suppression, invalid force/contact/tick/session/lease and freed rig rejection, and guarded host teardown. Failure tests use a real-body subclass injecting only failed start or an uncertain receipt after a real impulse; they verify no retry or false rollback.

The GETUP continuity fixture deliberately enters GETTING_UP with a real paused body and an independently changed displayed arm/motion pose to isolate the capture seam; it is not an end-to-end get-up/recovery test. Root owns actual-main E/exit/get-up acceptance. The unchanged older driver robustness suite was copied to an isolated output path and passed **39 checks**, including actual death falling and existing failure paths; source suite was not edited.

Historical `impact_self03` committed weak, strong 24 N·s and repeated 8 N·s but timed out in FALLING. Root diagnosed a body quietly supported through spine/limbs with zero pelvis/chest support. Final driver434b2b91 adds a bounded indirect-support route, actual support-point velocity guard and support-loss recovery from the displayed pose. Independent253 endpoint/39 legacy/70+665 support checks PASS; actual-main self06/self07 and native01 now recover successfully. See PLAYER_IMPACT_HOST_INTEGRATION.md for constraints and evidence. Gameplay contact generation remains unconnected.

Eight measured dispatch samples: **219–1,667 µs**, recorded individually in the report. Different routes are intentionally not pooled into a percentile claim. These are small headless fixture samples, not a frame budget or whole-scene FPS acceptance. No new idle loop, GPU window or always-active NPC simulation was added. No source melee/bullet/blast producer or production combat force calibration is claimed by these endpoints.
