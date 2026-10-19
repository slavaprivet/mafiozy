# Actual-K water owner lifetime guard — isolated candidate

The current pause workspace reads `_main._water_host._factory._time` after only
checking `_water_host != null`. `WaterSurface.dispose()` leaves its RefCounted
host object valid while clearing `_factory` and `_instance`. A host disposed or
replaced during K verification can therefore trigger an invalid access. An old
ground `water_id` does not validate the current water owner.

`build_candidate.mjs` composes over the pinned clock-atomic + resident/nav +
vehicle-lease + teardown actual-K workspace. Its result is tools-only. It
replaces all direct water reads with `WaterOwnerGuard.snapshot(_main)`. The
receipt includes host, factory, mesh instance, mesh, material identities and
water phase. A genuinely absent fallback is accepted; a detail-ready missing
host, disposed/foreign host or factory, missing mesh, or displaced material is
refused. Admission checks health before acquiring other owners; leave and
teardown compare the receipt with the entry snapshot while the SceneTree is
still paused. A failed check retains the existing paused HOLD behavior.

For a future isolated combined stage, use `buildWaterCandidate().workspace` as
`diagnostic/pause_workspace.gd` and copy `buildWaterCandidate().guard` to
`diagnostic/water_owner_guard.gd` in that same stage. This is the exact overlay
seam after the existing vehicle + teardown composition. Do not alter the
earlier builders or their pinned checkpoint. The composed workspace SHA is
`e47486b298697f103d562bbfdf04025a45f5df636ebd66ad2f0b0459aef8e73a`.

Checks run:

```
node tools/godot/map_editor_water_owner_candidate/test_source.mjs
node tools/godot/map_editor_water_owner_candidate/stage_native.mjs --stage
Godot_v4.7.2-stable_win64_console.exe --headless --path <printed-stage> --script res://test_water_owner_native.gd
```

Godot 4.7.2 native water-owner negative fixture: **9/9 PASS**, exit 0. This
fixture checks source water classes and the guard only. It does not run K,
residents, navigation, vehicle, teardown, map editing, GPU or LIVE. The prior
combined K results remain separate evidence. **HOLD** on production adoption
until a new combined native K fixture injects disposal/replacement during an
active pause and confirms refusal without an unpause or engine error, followed
by root-owned LIVE/performance acceptance.
