# Future public-port acceptance — saved OFF

Files are outputs-only. No NPC production, GPU, masks, forces or body transforms were modified. The new harness parses against frozen23e-check; its actual execution currently produces **SKIP**, `pass:false`, `root_player_binding_not_integrated`, before loading main. This is not a force acceptance result.

## Portable Git test closure

Commit the exact additional shared parent `outputs/artist23_combat_next/test_combined_eyes_input.gd` alongside this harness. It is standalone `extends SceneTree`, with no inherited local scripts and no preloads. SHA256: `949c94a1028fe27d81ba9d7704f373a8c95a0e7ef736077d89d9adffbfde96e4`. It was read only, not modified. This ONE parent also closes the already-committed `outputs/coordinator23_visual_harness/capture_npc_actual_input.gd` dependency. Keeping its original path preserves both existing extends declarations and receipt paths. No duplicate pinned copy is needed.

`TEST_CLOSURE.json` records the complete local extends/preload graph, byte counts and hashes for both NPC capture entrypoints plus the native-query sampler test. The remaining `res://` resources come from the root-approved frozen PCK (or properly imported Godot project), not this output directory. The parent dynamically loads `res://scenes/main.tscn`; the new gate additionally reads production player/population scripts. The 198 committed runtime inputs do not mean a checkout already contains imported binaries: use the approved complete PCK or explicitly import/build the project. A later optional `--contact-port` is a separate future owner delivery whose own script closure must be committed then.

## Exact root connection

`root_main_binding_OFF_PROPOSAL.patch` adds an export defaulting tofalse and one optional call after `preview_population.setup`, before `preview_ready=true`. It binds the already-proposed player hook to these **public population methods** only:

```
preview_population.player_final_dead_contact_ready() -> Dictionary
preview_population.admit_player_final_dead_contact(request: Dictionary) -> Dictionary
```

`CONTRACT_PENDING.md` defines those dictionaries. The population/Artist23 owner must supply the real public methods, or root may later forward them to an explicitly owned public contact port. No private `_ragdolls/_body.apply_impulse` fallback is provided. `bound_waiting_owner_ready` means only wiring, never physical feature readiness. Keep export false until the actual owner limits and tests pass.

An external delivered Artist23 port can instead be tested with `--contact-port=ABS_PORT.gd`. It must provide `bind_to_preview(scene) -> {ok:bool}`, ready/admit methods and public `dispose()`. Method names can be changed with `--contact-ready-method=...` and `--contact-admit-method=...`. The script does not invent a port or accept a spy in place of the real owner. If the delivered dictionary schema differs, adapt the harness/root adapter after reviewing the actual public API.

## Harness

`test_actual_main_public_port.gd` inherits the author's existing actual-main weapon-input test, preserving original equip, native ray, fresh muzzle, inventory ammo, medical survival, physical fall, blood revision, final death and final-eye checks. It requires the real integrated player sampler setter before main loads; missing player/public port is explicitly SKIP.

Headless future command:

```
GodotConsole --headless --main-pack ABS_FROZEN_PCK --script ABS/test_actual_main_public_port.gd -- --qa-out=ABS_NEW_DIR
```

Optional root-only GPU command uses the same script without`--headless`, offscreen`--position -32000,-32000`, resolution1280x720. NO_FOCUS is set. The script fixes its own process limit to60FPS so wall-clock owner rate limits and medical clocks remain comparable; it is not a performance benchmark. Original45s deadline retained. Do not run concurrently with performance measurements.

## What it actually exercises once a port exists

- Actual weapon inputs first produce the original alive→medical→final-dead progression. Alive and medical player approaches must yield zero accepted contact forces.
- The original final-dead16-segment body must **naturally** reach sleeping state within8seconds. No `sleeping`, `freeze`, velocity, transform, capsule/mask or private force writes to NPC bodies exist. Failure to sleep is a test failure, not an excuse to force it.
- Player fixture placements alone are explicitly logged and validated against original floor/capsule collision. Normal InputMap directions then drive the actual production `_physics_process` and `move_and_slide` hook. The sampler calls the real public owner. Actual low limb positions are read-only target references.
- Stationary, away and wall-separated approaches must produce no accepted forces. The wall negative is an explicitly temporary layer1 QA obstruction in the test instance, removed before the positive case. The approach starts clear of world/corpse capsules, and its away path is checked against corpse layer256.
- A real accepted walking contact must wake at least one sleeping segment and produce >1cm native segment displacement.16 bodies,15 joints, mass and bounded joint-anchor error must remain valid; HP, medical/final-death fields, death time, blood revision and accepted damage revision remain unchanged.
- Replaying the captured actual request and changing its owner epoch must be rejected. These are black-box nonacceptance checks; receipts preserve the actual owner reason and do not claim to isolate epoch admission from frame/rate rejection. Public disposal followed by the request must also reject.
- GPU mode adds before/after photographs from one unchanged observer transform and requires >1logical pixel displacement. These are appearance observations, not native player-camera parity. The inherited weapon test uses its declared QA aim camera and deterministic source survival seed.

Read-only accesses to existing body/status snapshots are for measurement only. The public owner is the only writer of force or death state. `RESULT.json` preserves structured request/result evidence plus exact native body/RID data. No direct unfreezing, damage injection or synthetic contact is permitted.

## Current verification and remaining work

Parser PASS; actual frozen23e-check run exited in0.44s with the expected SKIP before main. The main OFF patch applies cleanly. Actual public-owner force/wake/visual acceptance remains pending its delivery and a future integrated candidate. Earlier54PASS native-query tests used a rejecting spy and do not substitute for this acceptance.

Vehicle/jump/stale-pose/frame and same-frame replay query guards remain covered by `test_native_contacts.gd`; this actual-main harness adds the NPC final-death/public-owner lifecycle checks. It does not claim to retest every query guard through gameplay or test full-scene performance.
