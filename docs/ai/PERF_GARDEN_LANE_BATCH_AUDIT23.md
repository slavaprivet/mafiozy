# Garden lane house batching audit — 23 September 2026

Base: `1d0fc45f3c38d37ec9eb88f8dc793ff987962f93`.

The current dynamic LIVE census attributed 414 submissions to `native:garden_lane_house_v1` (212 main and 202 shadow). Reconstructing all three placements from the actual LOD0 GLB with the production door, window, entry, storey and furnishing builders produced 419 potential visible submissions after the existing multi-draw batches (217 main and 202 shadow). The five-call main difference is consistent with the LIVE camera/frustum; the exact shadow count matches.

The remaining cost came primarily from generated immutable entry/storey/stair/window-surround architecture. Those sources already carry `staticRenderMaterialImmutable`, but `garden_lane_house_v1` was absent from the audited architecture allow-list used by the global static batcher.

The candidate adds only this asset ID to that allow-list. With the current `WEBGL_multi_draw` path, the actual-source census changes from 419 to 197 potential submissions: main 217 to 105 and shadow 202 to 92. This is 222 fewer submissions, or 53.0% for this owner. Fourteen new batches replace 126 generated source meshes / 339 copied members. Authored materials, geometry, transforms, hierarchy, doors, panes, collision and raycast sources remain in place.

Without `WEBGL_multi_draw`, the current fallback deliberately preserves authored `InstancedMesh` pools; the garden-specific candidate is neutral (601 potential submissions before and after the allow-list change). It does not expand those pools. Full-scene FPS/GPU and screenshot parity still require the single coordinated LIVE game tab after integration.

Reproducible checks:

- `node assets/maps/city_rebuild_v1/audit_garden_lane_batches.mjs --multi-draw`
- `node assets/maps/city_rebuild_v1/audit_garden_lane_batches.mjs`
- `node assets/maps/city_rebuild_v1/test_static_houses_batches.mjs`
