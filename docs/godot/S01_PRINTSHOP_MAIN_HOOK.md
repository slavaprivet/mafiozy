# S01 printshop: atomic main integration

26 September 2026, Coordinator21 subagent. **Main/source + actual Godot headless PASS; LIVE/rendering/FPS/export OPEN.** Existing release PID43332 and session9305 were not touched. No GPU window or export was started.

## Owned changes

- `godot/mafiozi_walk/scripts/main.gd`: source printshop attach, atomic exterior fallback, single-press public E action/hint, physics advance with actual player occupant; also requested preview out-of-world teleport pose-lifetime reset.
- `godot/mafiozi_walk/scripts/tests/test_preview_printshop_hook.gd`: actual main and real player/input/physics regression plus optional CPU hook microbenchmark.
- `godot/mafiozi_walk/scripts/test_preview_admission.gd`: retain all five fail-closed scene rejection scenarios; valid scene now requires 16 original visual instances, 24 unchanged exterior source bodies, and exact new printshop body kinds.
- This document. Logs are in `outputs/coordinator21_perf_acceptance/printshop_hook.log` and `printshop_admission.log`.

Adapter, JSON, exporter, player and unrelated production files were not edited. Airborne owner confirmed player capsule radius **0.30**, height from `model_target_height` (**1.9** here), collider origin half-height above feet. Main reads actual `PlayerCapsule.shape` and global transform, not conservative 0.36 from the adapter's independent tests. There are no NPCs in this quarter; adding NPCs later requires adding their real occupants to this call site.

## Atomic admission

Main loads and verifies the reviewed package once. Expected SHA256 `958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b` is checked on LF-normalized text; parsing uses that same string. Only CRLF/LF checkout conversion is tolerated. Other content changes require deliberate review and digest update; missing/corrupt content uses the original building and all original colliders. This also prevents malformed nested data from reaching the adapter's narrower structural validator.

Attach runs after the one existing visual is added, **before** its three original envelope bodies are built. Success skips exactly that record's three validated bodies (indices 0/1/2). Failure invokes restore, frees the adapter immediately, and continues the original collider loop. No partial generated adapter remains. `printshop_status` is `ready` or `exterior_fallback`; failed optional interiors never claim interior readiness. The exterior quarter can remain usable and explicitly reports the fallback in the HUD.

Correction to `PRINTSHOP_INTERIOR_HANDOFF.md`: actual JSON has **four**, not three, dynamic bodies: public2 + service2. The exact replacement is **111 bodies: 103 source-static + 4 source-floor-ceiling + 2 door:public + 2 door:service**. The other24 bodies retain exact point arrays, transforms, collision layers and masks. This correction is from the canonical JSON and observed scene, not invented geometry.

## Runtime action

Only the adapter's public action is offered. A pressed, non-echo physical/keycode E toggles desired target; key release and repeat do nothing. Focused text input suppresses the action. Service staff anchors have no public E shortcut. Successful rapid input reverses the target before the first motion step; an occupied sweep refuses the action and shows a readable 0.9s message. Physics advances the adapter with the current actual capsule bounds/feet every tick. Missing collider bounds become zero-size invalid occupancy, making motion fail closed rather than omitting the player.

The occupant array/dictionary are reused; no world/scene scan is performed per frame, and unchanged hint text is not reset. Root's existing opt-in recorder default-OFF and PNG/perf rejection are preserved. The `y < -12` preview safety teleport now calls `set_preview_pose_authority(&"on_foot", true)` after moving to spawn, so the old jump pose cannot cross that preview lifetime. It does not implement gameplay resurrection.

## Actual verification

Godot4.7.2 stable official ed1daf0bf, headless, actual `main.tscn`:

- **42 hook checks PASS, exit0**, no script errors. Missing package, corrupt package, valid package/rejected placement all keep27 exterior bodies and leave no generated node or visual attachment marker. LF-equivalent CRLF data is admitted. Normal scene has exactly24 unchanged old bodies and the admitted interior.
- Actual E events use `Viewport.push_input`, including repeat/release, rapid target toggle, focus suppression, public hint, occupied request, new occupant during close, resume, and no service shortcut.
- Real `PreviewPlayer` walks from `publicApproach` through the open doorway using normal input/controller `move_and_slide`, settles on the interior floor, then returns to the street. Closed/open capsule motion casts confirm collider behavior. This is headless physics, not visual camera acceptance.
- Pose teleport epoch increments once; existing recorder is OFF and rejects a PNG-active request.
- Existing actual-main admission suite **PASS, exit0** with all5 expected rejection diagnostics and valid recovery. No rejection checks were removed or suppressed. New exact interior body-kind check confirms111 bodies with the source building ID.

Commands:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_printshop_hook.gd -- --benchmark
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/test_preview_admission.gd
```

## Performance boundaries

Same loaded headless main, same camera/player settings, no NPC/vehicle population, player physics disabled during the microbenchmark. Warmup200 calls per mode,64 batches×100 calls. CPU batch-mean microseconds p50/p95: hook OFF **0.22/0.23**, idle **7.49/9.40**, moving **14.76/17.14**. Moving uses a small delta to keep the door in motion across each batch; these are method costs, not frame percentiles, GPU cost or a gameplay route. JSON loading and mesh creation are startup costs outside these timings.

**Производительность общей сцены не проверена.** Coordinated LIVE remains with Coordinator21: visuals, exposure/interior lighting, source material shaders, camera through the doorway, normal-speed walking and collision appearance, comparable full-scene frame p50/p95, draw calls/primitives and export. Headless physics does not close these gates. The two source interior lights still lack a reviewed Godot unit mapping; source procedural finish shaders remain pending as in the adapter handoff.

No economy, shop service authority, NPC seller, cash, safe action, lock action or ladder climbing was invented or enabled.

## Exact tested SHA256

- main.gd: `29a2046276042e4bd6b3de1a348eafa385a119e4d8870cae82135e08837af601`
- tests/test_preview_printshop_hook.gd: `a7492391308ed89b47e55111e1e6450356fbae8f3944ffaa68a52ceb12ee8e46`
- test_preview_admission.gd: `5c3d5e115858b35c47ab9d1092ea58630e15137a0951ade63a728a9a3809cb0c`
- unchanged preview_printshop_interior.gd: `7dbe44a2130676469412883e2781fb60a6ac6d61f76b9a499bbdb9a3ab1ec2b6`
- unchanged printshop_interior.json: `958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b`

Hashes above identify actual tested working-copy bytes; Git newline conversion may change raw script hashes without changing script semantics.
