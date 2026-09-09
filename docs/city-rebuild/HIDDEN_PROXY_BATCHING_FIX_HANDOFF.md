# Hidden collision proxies and idle weapon effects — 2026-09-09

User screenshot showed a bright magenta bin cylinder and fountain/platform.
GLB inspection found `COLLISION_PROXY_MATERIAL` with base color
`[0.8, 0.1, 0.8, 1]`, assigned to `COLLISION_BIN_CIVIC` and similar proxy nodes.
The walk template loader already hides these nodes. Static batching ignored
mesh/ancestor visibility and copied their geometry into visible batch objects.

Fixed `batchableMesh()` in `static_render_batches.mjs`: any invisible node
in the source ancestor chain excludes the mesh from batching. Collision meshes
and all collision APIs are preserved. This also respects authored hide lists.
Tests verify hidden meshes and hidden ancestors sharing a visible art material,
plus 15 actual proxy meshes in bin/fountain/plaza GLBs. Real art still batches.
HTTP 18538 confirmed serving the fix. User tab was not refreshed; visual
confirmation after reload remains pending (known browser policy discovery error).

Earlier work in the same turn: weapon effects now track pool occupancy at
activation/hide, avoid inactive frame scans and provide constant-time counts.
Counts handle occupied-slot recycling, explosions and dispose. Original pool
iteration order, dt clamping, delayed casings and all visual calculations remain.
Existing weapon suite passes. 440 paired simulation frames match the reference
unconditional update and scan-based stats, with exact transforms, material
properties, visibility and ordered impact callbacks. No whole-game FPS claim.
