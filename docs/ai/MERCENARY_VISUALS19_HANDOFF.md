# Specialist visuals — 19 September 2026

Scope: `mercenary_pose.mjs`, `mercenary_fences.mjs`, new `mercenary_power_panel.mjs`, one guard in `mercenary_charge_view.mjs`; source outcomes remain owned by the core and host.

Implemented:
- Medic work progresses through assessment, compressions, dressing and offering support. Safecracker listens/works the lock, then turns the mechanism. Cutter grips and squeezes bolt cutters at changing heights. Demolition specialist places and wires the charge; retreat adds upper-body urgency to actual source locomotion. Electrician inspects and lowers the isolator standing up.
- Existing service yard is now a wire cage with an instanced roof and fixed overhead collision at 2.14–2.23 m. Cutting still removes only the front collider and folds both mesh leaves clear, leaving a passage over 2 m wide. Stable target and persistence IDs unchanged. Target approach is 1 m outside its north face.
- Physical electrical panel outside the cage, with insulated lever, warning plate and two real lamps. Successful source receipt changes lever, extinguishes emissive bulbs and both lights; missing/rejected receipts change nothing. Duplicate and pending calls are idempotent; completion after disposal remains inert.
- Charge prop remains attached past fuse time while core reports `waitingForSafety`; visualization does not determine explosion timing.

Root integration:
`createMercenaryPowerPanel({THREE,groundHeight,powered,onPowerChange,persistPower})`; add `object` to content, `colliders` to static/vehicle lists, `getTargets()` to target registry. `onPowerChange({id,powered:false,context})` must return true or `{ok:true}` (can be a promise). `persistPower(id,false)` follows confirmed success only. `meta.kind='power_panel'`, `meta.disablePower(context)`, `meta.getApproachPosition()` returns world position 1.1 m before front. Call `updateVisibility(hero.object.position,60)` in existing bounded cull loop. It never relights an off circuit. No module update timer needed.

Validation: 10 tests pass across `test_mercenary_visuals19.mjs`, `test_mercenary_pose.mjs`, `test_mercenary_fences.mjs`, `test_mercenary_charge_view.mjs`. Actual male/female GLBs preserve actor root position, fresh host poses and stable node count. CPU-only pose sample p50 0.025–0.028 ms, p95 0.035–0.038 ms. Full scene FPS and visual LIVE acceptance remain unverified by this subtask.

Safe audit only: existing `interior_interactive_safe.mjs` already animates a real hinged door and holds banknote bundles. Current source pays on opening and returns `collected:true`; a new bag must not award those funds again. Root owns any safe presentation/source changes.
