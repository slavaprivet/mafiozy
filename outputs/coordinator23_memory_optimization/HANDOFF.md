# Cargo acceleration memory: candidate ready for integration

Only production target: `godot/mafiozi_walk/scripts/weapons/cargo_aim_picker.gd`.
Minimal patch `cargo_memory_minimal.patch`; full file `cargo_aim_picker_candidate.gd`.
Shared base SHA256: `1e2e95c1e08ceee1e68b7faede873b09f9903a996aababc6f3db29594496630d`.
Candidate SHA256: `262de033253e6d9b600622359ecd9d409cf0f434282a15013c25d470a35a6ad1`.
Original fixture file differs only in line endings from current shared base.
No production files or open game were changed. No GPU runs.

## Cause and change

`get_faces()` obtains native acceleration-backed faces; immediately creating another TriangleMesh from those faces retained two acceleration structures for every one of 268 vehicle parts. Repeated `generate_triangle_mesh()` returns the same cached instance in this engine; mutation invalidation is now tested explicitly, rather than assumed from API naming.

Candidate preserves all 268 parts, uses current mesh AABB first, and asks Mesh for its native shared acceleration only for parts intersecting the ray. Both triangle intersection and current lid transforms remain. Each query observes current mesh replacement/bounds/topology; freed references are skipped. Singular or non-finite transforms fail closed before inverse.

Same raw project before/after single-file change: READY 148.101 -> 106.311 MiB; full 14 cargo 160.780 -> 118.988 MiB. Saving 41.79 MiB in both scenarios. All 3 NPC, 377 collision shapes, 4099/4302 total nodes and 885/1012 unique mesh resources preserved. Marks 72, impacts 48, RPG 6, projectiles 112 and lifetimes unchanged.

## Behavioral proof

`test_picker_parity.gd`, `PICKER_PARITY.json`, `picker_mutations.log`: PASS 1770, zero errors, about 4 seconds headless. Actual main scene, 14 real stores, 102 attached camera yaw/pitch queries matched original item and exact hit point. All 268 parts tested from 3 outside-car axes with actual lid closed/open matched original obstruction results; stale generation rejected.

Additional mutation fixture: same ArrayMesh instance clear_surfaces/add_surface_from_arrays changes topology inside same bounds; changed bounds moved +10; node.mesh replacement -10; scaled instance; singular scale; freed instance. All 10 assertions passed. This directly proves cached native triangles are refreshed for these mutations on Godot 4.7.2.

Ordinary camera query batch lazily built 1/268 acceleration structures, static growth 701396 bytes, headless cold query p95 934 us / max 2266 us. These are diagnostics, not GPU frame time claims. Worst case eventually builds up to 268 native structures, still avoiding the duplicate set. Loaded rendered p50/p95 and visual QA remain root-owned acceptance work.

## Attribution and limits

Both official PCK memory probes confirm the original ~59 MiB READY difference is real, not merely raw script versus compiled PCK. Releasing car picker private triangles in the disposable loaded candidate freed 21.14 MiB, with native Mesh's other cache retained. Releasing surface pool freed about 3.79 MiB and RPG pool 1.20 MiB after queued frees. These releases are diagnostic only and are NOT proposed for production. The extra 792 MeshInstances exactly match 72*4 + 48*7 + 6*28 effect pool parts, not duplicated full scenery. Their unique extra geometry is only 1809 vertices.

Remaining memory includes UI textures, panels, effect pools and script/resource data; not all has been byte-attributed. Preserve content and effect lifetimes. JSON geometry and pools already share meshes; source hot paths return early while empty. Do not claim this fixes the measured +~1 ms active/cargo GPU p95 without a new comparable rendered test.

Secondary experiment `weapon_pickup_visuals_candidate.gd` is HOLD and excluded from the passing candidate. It attempts direct indexed-face extraction to avoid per-part native acceleration before merged weapon triangles, saving a further ~4 MiB after 14 stores in a diagnostic run. Its overly strict native face-order equality failed (native face order may be rearranged); additional roundtrip fixture failed without diagnosed reason. Do not integrate it. `SECONDARY_HOLD_PICKER_PARITY.json` preserves these failures; original pickup renderer is restored in the fixture for the 1770 PASS.

## Checkpoints

Static memory is engine allocation accounting, not total process RAM or VRAM. End-of-probe disposal is attribution only; loaded measurements retain all content.

| Run | Phase | Static MiB | Nodes |
|---|---|---:|---:|
| baseline | engine_before_main_load | 24.109 | 1 |
| baseline | main_resource_loaded_scripts_compiled_or_loaded | 30.476 | 1 |
| baseline | main_instantiated_before_ready | 30.484 | 1 |
| baseline | main_ready | 84.872 | 3185 |
| baseline | main_ready_after6frames | 84.837 | 3185 |
| baseline | full14_cargo_warm | 89.623 | 3388 |
| baseline | scene_disposed_cached_scripts_resources_may_remain | 41.578 | 1 |
| validated | engine_before_main_load | 24.129 | 1 |
| validated | main_resource_loaded_scripts_compiled_or_loaded | 30.508 | 1 |
| validated | main_instantiated_before_ready | 30.516 | 1 |
| validated | main_ready | 144.156 | 4099 |
| validated | main_ready_after6frames | 144.122 | 4099 |
| validated | full14_cargo_warm | 156.833 | 4302 |
| validated | diagnostic_release_only_car_triangle_cache | 135.691 | 4302 |
| validated | diagnostic_release_surface_pool_after_car_cache | 131.904 | 3677 |
| validated | diagnostic_release_rpg_pool_after_surface | 130.699 | 3502 |
| validated | scene_disposed_cached_scripts_resources_may_remain | 42.449 | 1 |
| raw_before | engine_before_main_load | 23.998 | 1 |
| raw_before | main_resource_loaded_scripts_compiled_or_loaded | 33.194 | 1 |
| raw_before | main_instantiated_before_ready | 33.203 | 1 |
| raw_before | main_ready | 148.101 | 4099 |
| raw_before | main_ready_after6frames | 148.067 | 4099 |
| raw_before | full14_cargo_warm | 160.780 | 4302 |
| raw_before | diagnostic_release_only_car_triangle_cache | 139.638 | 4302 |
| raw_before | diagnostic_release_surface_pool_after_car_cache | 135.850 | 3677 |
| raw_before | diagnostic_release_rpg_pool_after_surface | 134.645 | 3502 |
| raw_before | scene_disposed_cached_scripts_resources_may_remain | 46.396 | 1 |
| raw_after | engine_before_main_load | 23.998 | 1 |
| raw_after | main_resource_loaded_scripts_compiled_or_loaded | 33.194 | 1 |
| raw_after | main_instantiated_before_ready | 33.203 | 1 |
| raw_after | main_ready | 106.311 | 4099 |
| raw_after | main_ready_after6frames | 106.277 | 4099 |
| raw_after | full14_cargo_warm | 118.988 | 4302 |
| raw_after | diagnostic_release_only_car_triangle_cache | 118.742 | 4302 |
| raw_after | diagnostic_release_surface_pool_after_car_cache | 114.955 | 3677 |
| raw_after | diagnostic_release_rpg_pool_after_surface | 113.750 | 3502 |
| raw_after | scene_disposed_cached_scripts_resources_may_remain | 46.398 | 1 |
