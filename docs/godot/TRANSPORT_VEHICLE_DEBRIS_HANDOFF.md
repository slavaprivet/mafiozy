# Native vehicle physical debris — frozen component

Direct user request authorizes native physically flying/falling source assemblies.
Frozen scripts/transport/transport_vehicle_debris.gd SHA1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f. Own test SHA9e91db5ae49adf2080f954ed395f315508db8f9a3f14f59f51a0b094a6747aa6.

API configure(vehicle_root,debris_parent,ordered,owner=null). Each ordered row requires source Node3D, mass_kg, collision_layer/mask, linear_damp/angular_damp, friction/bounce. Caller supplies native physical settings; no silent tuning for sleep. Sources are actual lid/door/wheel assemblies, never control hinges or generic replacements. Ten-source maximum is blast pool, not twelve structural-pool cap. Use actual source indices from damage_assemblies.json for launch helper. Hidden/already-detached roots consume zero RNG and cannot be copied again.

prewarm_step(budget=1) registers bounded one body/hull operation per physics frame and reports WARMING/READY. launch(motions) requires READY, validates all current source bindings before mutation and reuses prepared bodies. No hull cook/clone allocation on launch. Motions require actual native linear/angular velocities; blast launch helper consumes seven owner-issued shared draws per eligible part. Actual owner body can be collision-excepted to avoid initial overlapping hull launch. reset/dispose restore originals and deactivate/free own copies. Bodies remain rendered/physical and naturally sleep; no TTL or FPS-driven content removal.

Geometry ownership: private meshes/materials/collision resources. Descendant hierarchy/visibility/resource/transforms and source scale changes reject stale prepared copies. In-place mesh/material changes require invalidate_geometry before edit then a NEW provider, prepared/prewarmed outside impact. This is a material integration limitation for deformation followed immediately by explosion: Root must manage dirty preparation readiness; this component alone does not promise instant arbitrary deformed-part detachment. Single ownership across structural/trunk/blast events must be supplied by the damage host, not three competing copies. Caller never builds full cache during explosion.

Source numeric full-wreck trajectory was analytic1.8sec with forced landing. NativeRigidBody3D uses actual gravity/collision/settling by explicit new user instruction: physical behavior change, not trajectory parity. Part selection/order and initial launch remain source-bound. Vehicle HP/fire/wreck/event and main remain outside this module.

Actual Godot4.7.2 bounded runner264checks PASS. Two actual hatch GLBs, ten parts/76convex hulls each,20total. Current-world roll/pose, caller mass/velocities/layers, atomic bad/stale launch, reset/relaunch, geometry invalidation, owner exception and natural settling covered. First ten sleep after228frames, second after131, all persist.

Isolated CPU: configure115.888ms OUTSIDE EVENT (load/preparation only); prewarm step p9562us/max71us. Prewarm frame-wait p9520.674ms/max20.720 versus baseline20.704ms, pacing measurements not CPU. Launch0.508ms vs earlier39–47ms; earlier415ms first hull activation was rejected and prewarmed. Physics monitor awake10 p50/p951.639/2.044ms, settled10 p951.451ms, awake20stress1.556/1.759ms. Low-cadence headless CPU, no full loaded-scene FPS claim. Configure still unsuitable for a live damage frame; Root must preload or bound preparation.

Tests run through tools/godot/run_transport_test.ps1 native hidden/headless executable, unique logs and verified PID timeout<=60sec. No leftover Godot test process. No GPU/main/Git mutation by author. Loaded-scene frame-time and visual acceptance remain Root's next integration check.

Parent repeated frozen264PASS independently usingboundedrunner; launch523us/config113665us; prewarmstep p9556us/max113us; 20partstressphysics p951.750ms; sleeping10p951.226ms. No leftoverprocess. This repeat confirms isolatedbehavior only, notloadedsceneFPS.

