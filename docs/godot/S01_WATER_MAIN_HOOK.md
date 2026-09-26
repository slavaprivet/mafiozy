# S01 water main hook — 27 September 2026

READY for coordinator's native shader/scene review. Actual main headless
integration is verified; **GPU compilation, water appearance and comparable
rendered-frame performance remain OPEN**. Existing GPU PID12540/session49876
was not touched. No export, player, data, core water factory/host or source Walk
file was edited by this task. Existing main camera notes/update panel, perf
hook and printshop integration were preserved.

## Main admission and atomic selection

`main.gd` now loads the reviewed native water package at build time.
`preview_water_detail_enabled` defaults to true; `--preview-water-off` or an
explicit false export selects the original baseline without reading water data.
There is no hot scene toggle.

`water_status` is `detail_ready`, `baseline_disabled` or `baseline_fallback`.
Fallback errors live in `water_errors`, independently of main's admission
errors. Main remains READY with original water if optional detail is rejected.
Successful counts are retained in `water_summary`; perf metadata records the
selected water status.

Admission order:

1. Read once, normalize CRLF to LF, pin SHA-256
   `ac70f924e1beef0f8501c48d09535a89d47effff014bf0f32b8abc72b3e3b824` and parse
   those same bytes. Missing, malformed or merely structurally valid but
   unreviewed data cannot enter the scene.
2. Run the host's structural validation.
3. Compare origin, metre scale, row/column crop bounds and water palette height
   against the current admitted block. Validate protected-mask dimensions and
   binary values. Require precisely the same **303 unprotected tile16 cells**;
   moved cells with an unchanged count are rejected. Protected water in this
   excerpt is unsupported and fails to baseline rather than silently vanishing.
4. Build the host under the actual main parent. Host rejection disposes the
   candidate before baseline assembly. Only complete success skips the old
   `Surface_water` MultiMesh group.

The result contains exactly one `SourceNativeWater` ArrayMesh, 1818 original
source vertex/depth pairs and 606 triangles. It replaces all303 old water boxes
without a second transparent surface. The dry-strip loop is unchanged; no new
water collision/floor, swimming or water interaction mechanics are introduced.

Main alone calls `advance(Time.get_ticks_usec()/1000000.0)` once per process
callback, using its existing timestamp. This is absolute monotonic wall time,
not delta accumulation or shader TIME. The host has no automatic callbacks.
No mesh scan, I/O or resource allocation was added to this update path. Main
disposes its host on scene exit while the parent still exists and before its
own error path queues child removal. Failed builds retain no candidate node.

## Coordinated source-contains jump seam

Root additionally authorized wiring the dive owner's
`player.set_preview_jump_surface_guard(Callable(main,
"preview_jump_surface_allowed"))`. The callable accepts **world feet Vector3,
radius float**; the player supplies the source radius **0.36 m**.

Source inspection corrected the proposed dry-only rule: actual
`walk_preview.mjs::traversalMapContains` permits native pedestrian land **or
waterAt**. `hero_traversal_world.mjs::pointFits` does not categorically forbid
water. Therefore no dry-only restriction or invisible shoreline wall was added.

The cached per-cell permission is exactly the native crop portion:

```text
walkableMask
OR (tile == 9 AND policeMask == 1)
OR (tile == 16 AND NOT protectedMask)
```

`native_pedestrian_surface.mjs` is the authority for the first two terms.
Protected dry police paths remain passable; palette-solid alone does not grant
permission. Main caches the three masks into bytes once, with twelve perimeter
directions. Each call checks the centre plus12 source-style circle samples,
never scans the grid, and rejects invalid coordinates/radius or an out-of-crop
sample. Signed coordinates are checked before floor/index conversion.

This is **only source native-crop containment**, not a port of full traversal,
landscape, swimming, bridges, dynamic blockers, height/ceiling or collision
authority. The player owns its physical sweep and other occupancy checks.
Water is admitted by this callback while swim/afloat behavior remains OPEN;
no fake floor is introduced to conceal that missing migration.

## Actual validation

Godot `4.7.2.stable.official.ed1daf0bf`, all runs headless:

```text
--path godot/mafiozi_walk --script res://scripts/tests/test_preview_water_hook.gd
--path godot/mafiozi_walk --script res://scripts/tests/test_preview_water_hook.gd -- --preview-water-off
--path godot/mafiozi_walk --script res://scripts/tests/test_preview_water_hook.gd -- --benchmark
```

- Default/fixture integration: **60 checks PASS, exit0**. CLI override:
  **3 checks PASS, exit0**. Benchmark mode repeats the60checks, also exit0.
- One detail batch, no original-water duplicate; all1818 depth values exactly
  match trusted source, including231 zero-depth shoreline vertices.
- Exactly **169 dry-strip bodies**, identical transforms, shape sizes,
  collision layers/masks to baseline. All303 actual water-cell-centre rays
  through the water surface encounter **zero physical floors**.
- Default detail, forced baseline, CRLF data, missing/malformed/unreviewed data,
  valid-but-stale block bounds and same-count shifted footprint; atomic fallback
  also exercised through the actual host's nonidentity-parent rejection.
- Origin/scale/protected-mask admission, resource reuse, wall-time advancement,
  scene disposal, main perf defaultOFF, printshop and update-panel preservation.
- Guard wiring; actual water with negative preview-local coordinates; shoreline
  straddling land/water; protected dry police corner; exclusive crop boundaries;
  negative source coordinates; twelve-point diagonal coverage; cache behavior;
  rejection of a nonwalkable dry tile without the source police exception.
- Core water host **44checks PASS**, core material **47checks PASS**, main perf
  hook **18checks PASS**, all exit0; core files unchanged.
- Existing printshop regression initially showed40/42pass: two UTF-8 mojibake
  labels in its untouched adapter. Root repaired those two labels in its own
  scope and independently confirmed **42/42PASS**. This was reported separately
  from water and not hidden as a passing initial run.
- Scoped `git diff --check`: no whitespace errors.

## CPU evidence and limits

Optional benchmark uses the same actual loaded headless main, idle player,
delta0 and warmed600-entry HUD sample ring. It calls main directly in64batches
of100, comparing separately built baseline/detail scenes:

| Operation | CPU result |
| --- | --- |
| Baseline main callback, batch-mean p50/p95 | 0.90 / 1.38 µs |
| Detail main callback, batch-mean p50/p95 | 1.81 / 2.55 µs |
| Cached centre+12 contains guard,10000-call mean | 8.5547 µs |

These are CPU batch statistics, **not frame percentiles, rendered FPS or a
release benchmark**. The separate unchanged host test measured0.6834µs mean
advance and2400µs one-time303-cell build in this session. The geometry changes
from water boxes to source planes, but rendered gain has not been inferred
from triangle counts. Производительность общей сцены не проверена; coordinator
owns first GPU compile, shoreline/lighting review and matched OFF/ON native
comparison with unchanged camera/settings/population/warmup.

## Exact file receipts

| File | SHA-256 |
| --- | --- |
| `godot/mafiozi_walk/scripts/main.gd` | `f9526260ef1b0efcff9bcec96b93bcf0732c57325f0c675c3af64606b8bf709d` |
| `godot/mafiozi_walk/scripts/tests/test_preview_water_hook.gd` | `91783c98a55699ef7940b2a7664373aede8679994bd2e6da8491c674c0c00ccc` |
| Unchanged `scripts/preview_water_surface.gd` | `7d89235d93f31dd565aadf37f549a05074bec5534acfb120543228f1dba2655c` |
| Unchanged `scripts/preview_water_material.gd` | `51f3d2d5f6c744cc98b0131a62d2acb1e97b8327f2235702b9b1896615952d88` |
