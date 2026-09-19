# Vehicle shadow-volume rejection — 12 September 2026

Status: accepted default on 19 September 2026 after a same-pose held LIVE A/B.
Ordinary walk enables it; `vehicleshadowcull=0` is the explicit rollback.

## Why this work

Interior owner supplied a current populated baseline: 75 buildings + 164 decor,
72 NPC / 20 visible, 26 traffic actors, GTX980, DPR1, multi-draw supported.
Frame p50/p95 104.2/116.2ms; render 93.8/104.2; main submit 43/47.8;
shadow 28.9/32.5; shadow submit 16/18.5; matrix 9/10.7; NPC 6.2/9.2;
GPU 61.25/69.79; 3376 calls / 3.141M triangles. These are another owner's
current baseline, NOT this candidate's before/after. They prioritize renderer
work over more small NPC update optimizations.

## Conservative rule

For a vehicle caster bounded by a world sphere, the entire directional shadow
is contained in that sphere swept away from the light through the existing
shadow camera's far plane. A normalized view-frustum plane can reject that swept
volume only if both its start and end have maximum signed distance below zero,
including the sphere radius and filtering/bias margin. This is sufficient, not
necessary: ambiguous volumes always render. A car outside the camera is not
automatically rejected; its shadow can enter the visible view.

The margin includes four shadow-map texels (including hardware map-size clamp),
normal bias and depth bias in world units, including shadow camera zoom. All
matrix transforms use the square root of the largest absolute row sum of A^T A,
a conservative spectral-norm bound even for tiny shears / enormous local meshes.
No terrain height, shadow distance reduction or camera movement approximation.

## Implementation boundaries

- `vehicle_shadow_culling.mjs` wraps only the existing sun's PCFSoft shadow
  submissions. Main rendering, other lights, VSM, array/reversed/WebGPU cameras
  bypass it. Actual camera after recoil/impact is used during the shadow pass.
- Vehicle ancestry only (`vehicleFleetId` / `sourceVehicleId`). No removal,
  population throttling, changes to geometry/materials, source visibility,
  castShadow flags, collisions, NPC logic or sun map resolution.
- Skinned meshes, morphs, arbitrary shader/displacement/custom depth materials,
  custom shadow callbacks and unsupported position buffers are not optimized.
  Generic instanced meshes are excluded; authored vehicle-manager batches require
  a sphere derived from their maintained aggregate bounding box (Three's aggregate
  sphere can underbound sheared instance transforms). Regular
  geometry bounds are refreshed when position attribute identity/version/array/
  count changes. Authored source and damage ownership are untouched.
- `render_freeze_qa.mjs` adds hold-end cleanup and admits the local shadow A/B
  button. `walk_preview.mjs` initializes the accepted default, diagnostics dataset,
  held-scene button and teardown in the correct profiler-wrapper order.
- Local QA hold automatically returns this option to enabled on release.
  `vehicleshadowcull=0` bypasses initialization for immediate comparison/rollback.
- Cached/manual shadow maps bypass the filter. A previously pruned map is marked
  dirty for a full redraw on switching to manual mode, disabling or disposing
  the helper, so a later camera cannot reuse incomplete cached shadows.

## CPU/structural checks

`test_vehicle_shadow_culling.mjs`: 76,320 sampled points from rejected swept
volumes remained outside the camera; visible casters and offscreen casters whose
shadows enter the view are retained. Tests cover main-pass isolation, custom
shader/depth/callback fallback, VSM fallback, mutable geometry, enabled switch,
throw cleanup and disposal. This supplements, not replaces, the geometric rule.

`benchmark_vehicle_shadow_culling.mjs`: twelve real car models with existing
body/door/detail batches, synthetic 3x4 grid, four camera directions. No WebGL.
1299 eligible shadow calls became 548 / 385 / 413 / 382, saving 751–917.
Additional CPU guard cost about 0.29–0.32ms p50 across all twelve models. This
counts candidate submissions, NOT measured GPU time or a full-game FPS gain.

`test_render_freeze_qa.mjs`: 20/20 PASS; existing profiler test PASS.

## LIVE

One temporary populated QA scene observed 1669–1787 rejected vehicle shadow
submissions, but its A/B is INVALID: the 15-second placement refresh made `busy`
true and cancelled the hold. `refresh()` now skips only an explicit active QA
hold; normal gameplay polling is unchanged. Hold diagnostics include stop reason.
The temporary QA tab was closed, not merely hidden: hidden IAB tabs were observed
to continue rendering with document.hidden=false. Another owner's old background
QA also contaminated GPU isolation, so neither timing window establishes a gain.
That earlier run is superseded by the clean paired run below. The feature remains
opt-in only; additional viewing angles still need visual acceptance.

## Clean held LIVE — 13 September, Coordinator 17 relay

Only one active game remained after the approved duplicate-tab closure. Scene:
242 placed objects / 78 buildings, traffic 18 (loading/fallback 0), held NPC 61
seen / 15 visible, DPR 1, viewport 845x920, camera [167,2.74,168]. Same hold,
120 frames OFF then 120 ON; main submissions and triangles were unchanged.

| Metric | OFF | ON |
| --- | ---: | ---: |
| Render p50 / p95 ms | 83.1 / 100.1 | 79.2 / 86.5 |
| Frame interval p50 / p95 ms | 98.3 / 117.7 | 94.1 / 105.8 |
| Shadow p50 / p95 ms | 23.1 / 30.9 | 21.0 / 23.6 |
| Shadow submit p50 / p95 ms | 12.7 / 16.1 | 10.3 / 11.8 |
| Main submit p50 / p95 ms | 42.1 / 51.3 | 40.9 / 44.2 |
| Full main + shadow calls | 4571 | 4241 |
| Main calls | 2527 | 2527 |
| Shadow calls | 2044 | 1714 |
| Main triangles | 2455766 | 2455766 |
| Shadow triangles | 1621839 | 1301488 |
| GPU timer p50 / p95 ms | 60.51 / 74.83 | 62.27 / 67.3 |

330 / 1266 eligible submissions rejected. Coordinator compared screenshots and
reported matching visible content/shadows. Source update continued, errors 0;
this is a held rendering comparison, not full gameplay FPS. GPU median did NOT
improve. Render median saving is about 4 ms and does NOT solve the severe lag.
Hold released manually after 1074 frames, option left ON in the opted-in game.
Normal unheld baseline still had interval p50/p95 105.7/126.5 ms and render
82.2/97.7 ms. Duplicate closure alone did not solve it. Full source-owned report:
`COORDINATOR_17_PERF_20260913.md`. New profiler `frameDraws` counts both passes;
the old renderer.info count was reset after shadows and omitted their calls.

## Default acceptance — 19 September, checker-owned QA

The checker repeated a fixed-pose 120-frame A/B in the current populated local
scene: hero `[164,0,164]`, 72 NPC seen / 23 visible, 13 traffic actors, DPR 1,
viewport 911x920. Visible content remained intact and main-pass submissions were
identical. OFF versus ON: frame p50 65.8 → 61.2 ms, GPU p50 35.47 → 31.77 ms,
total passes 3519 → 2823. Main passes stayed 1752; vehicle shadow passes fell
993 → 297, exactly the 696 conservatively rejected submissions reported by the
helper. This establishes the default gate, not full backend/network acceptance.
