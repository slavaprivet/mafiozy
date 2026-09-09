# GALLERIA static batching — 10 September 2026

The GLB model root is named `MAFIOZI_GLASS_PAVILION_SMALL_V1`.
`static_render_batches.mjs` previously rejected every ancestor name containing
`Glass`, so all opaque meshes in all four pavilions stayed outside the static
batching system. The root describes the building, rather than a glass pane.

The guard now recognizes only that exact non-mesh root. The existing visibility,
glass, window, door, hinge, lighting, runtime and material guards still apply to
every descendant. No geometry, material appearance, collision body, source
object, ID, interaction or culling threshold is changed. No API changes.

## Validation

`test_static_pavilion_batches.mjs` loads all four actual placed GALLERIA GLBs,
applies the production door/glass and building-entry integrations, then batches
the resulting scene. Browser image upload is replaced by a texture placeholder
in Node; the actual GLB geometry and material settings are retained.

- 436 opaque source meshes enter 11 shared BatchedMeshes.
- 72 breakable pane meshes and 96 door descendants retain their source material
  and runtime hierarchy. Source collision/raycast geometry and all static
  transforms are unchanged.
- Near/far visibility retains the 220 m rule, and disposal restores exact source
  materials. These are scene submission counts, not measured game FPS; actual
  per-camera draws depend on visibility and shadow passes.

Also passed unchanged:

- `test_static_render_batches.mjs`: real decor GLBs, 15 hidden collision proxies,
  original raycasts, transparent exclusions, interior instances and disposal.
- `test_static_render_culling.mjs`: exact visibility/matrices across 240 updates,
  BatchedMesh and InstancedMesh fallback, boundary/movement/reset cases.
- `test_building_window_integration.mjs`: 43 complete rooms, 675 panes, 133 doors,
  7,769 furnishing parts, individual pane breakage and resource lifetime.

## Audit findings / limits

The residential fixture produces 8,479 static members in 80 batches. A Node
CPU-only sample of BatchedMesh.onBeforeRender at x611/z83 over 100 frames took
approximately 0.50 ms/frame with existing sorting, versus 0.35 ms without it.
That small difference does not explain the reported 250 ms game frames, so
sorting and visual ordering were left unchanged.

Three 0.180 falls back to individual draw calls for BatchedMesh when
WEBGL_multi_draw is unavailable. Root's current LIVE device profile reports
`multiDraw:true`, so a new fallback strategy is not needed for this device and
was not added. Root owns full CPU/GPU profiling and the real post-change LIVE
verification. This scoped task did not open browsers or restart ports, and did
not edit walk_preview, world, NPC, lighting, source geometry or other owners'
files. The GALLERIA correction is one bounded contribution, not a claim that
overall scene performance is solved.
