# GALLERIA first live replacement

User-approved canonical glass pavilion. This slice contains the original immutable GLB and a host-injected Three.js runtime, not a catalogue render. Coordinator subsequently delegated the glass-only edits to `world.html` and `three_preview.js`; full host wiring is now implemented and tested, not just handed off.

Status: **FEATURE_READY_FOR_LIVE_GATE**, not live PASS. Existing Stage A `cityv3buildings=1` automatically loads GALLERIA, with no additional enable flag. `cityv3focus=glass_pavilion_small@1` places the player on the front road. Runtime preflight refuses unsafe sites without suppressing the legacy building. Browser not opened by this agent.

## Current frozen revision: baked AO v1

Default runtime now uses `glass_pavilion_small_ao.ecae5f97bd53.glb` (3,773,048 bytes; SHA256`ecae5f97bd53e9466bea3a520ec95a58ecacd7a232fbde902de0a1a7d4672873`). Original approved2,108,880-byte GLB remains intact and is selected by explicit rollback query `cityv3glassrevision=original`; world and loader pin the matching hash together. No silent unverified asset fallback.

Source manifest/validation read fully and copied as `ao.source.manifest.json` / `ao.source.validation.json`. One embedded2048² PNG, standard linear aoMap on8 opaque materials /122 meshes, UV channel1; glass and emissive excluded. Equivalent image/sampler references deduplicated to one texture. Estimated RGBA8 full mip storage22,369,620 bytes (21.33MiB), no added geometry/draws. Disposal releases textures and closes decoded embedded image. Existing FrontSide and env.35 correction retained.

Actual THREE0.180+GLTFLoader test uses a real PNG decoder through the CPU ImageBitmap adapter; AO is not removed or replaced with a dummy image. Tests verify decoded pixel dimensions, aoMap/UV presence,8 materials/122 meshes/one texture, all palette factors and31772 world triangles match original at validated0.1mm quantization, bounds/normals/anchors/LOD/rollback/disposal. Host contract tests and13 existing building tests PASS. `threePreview.dataset.cityV3GlassAO` reports revision/hash/imageLoaded/materialCount/meshCount/textureCount/UV/budget. **Frozen for root's single-tab live reload; no GPU or visual PASS claimed.**

## Wire before the first building snapshot

Import `installCityV3GlassBuilding` from `runtime.v1.js`, then await it **before** the first `bridge.getWorldSnapshot()` used for legacy building construction. Pass the already loaded host `{THREE, GLTFLoader, scene, bridge, renderer, originR, originC, worldScale, signal}`. The caller owns a bounded load timeout/AbortController. No second Three copy is imported. Cancellation prevents late installation and disposes parsed meshes.

The host must implement synchronous `activateCityV3GlassBuilding(receipt)` -> `{ok:true,rollbackToken}` and `rollbackCityV3GlassBuilding(token)` -> `{ok:true}`. Activation must preflight the exact existing target and protected objects, set ground collision and public/service access, suppress only the exact legacy instance, and rollback atomically on failure. Installer registers the authored visual root before requesting activation and removes/disposes it on rejection. Do not claim visibility before a live scene check.

`glassRuntimeContract()` exposes the same exact binding without a fetch. The candidate is center **r47,c67**, full asset scale **1** (not the prior tiny .68 scale), yaw0, world authority **4.1 m/tile**. Legacy `legacy:procedural:40:60:45:65:48:68`; 4x4 tiles r45..48/c65..68. Source map: block4,6 is not a park or NPC headquarters. Coordinator must confirm current generated MAP/protected POIs/roads before activation, since mutable runtime state is authoritative. Rejected candidate17,67 (gas station clearance and sabotage anchor); rejected37,67 (arena).

Public road r50.5/c66.9390243902439; service road r43.5/c68. The narrow service corridor intersects the body to the authored recessed service socket; the public corridor ends just inside the authored double-door threshold. Ground collision stays independent of LOD and is never inferred from a canopy AABB.

## Proven source contract correction

Original `COLLISION_BODY` is an empty metadata node with `size_xyz_gltf:[13,10,12]` but it was authored from Blender XYZ without permuting those **custom property values**. The actual node translation is `[0,6,0]` and the actual `Small_Base_Pad` ground mesh bounds are X[-6.5,6.5], Z[-5,5], Y[0,.44]. Therefore the physical body is width13/depth10/height12, not width13/depth12/height10. Adapter explicitly validates this known source defect against actual parsed mesh bounds. Original GLB is unchanged. Full render bounds are 13.5x12.2x11.24; recenter[-.25,0,-.325].

## Runtime LOD

Exactly one authored LOD group visible: 150/2/1 meshes. All three roots share identity transform; no catalogue offsets. Initial LOD0. Call `instance.update({distanceM})` with player-to-building planar distance in world metres: <=70 LOD0, <=170 LOD1, farther LOD2. Avoid camera elevation as distance for an orthographic camera. Telemetry is `renderer.domElement.dataset.cityV3Glass` and `cityV3GlassReceipt`. `instance.dispose()` restores the legacy transaction before removing the visual.

## Verification performed

`node assets/buildings/city_v3/glass_v1/test_runtime.mjs` PASS using actual THREE0.180/GLTFLoader: SHA and bytes; 150/2/1 real meshes; actual LOD0/recenter/ground bounds; source axis defect; full scale; exact one-LOD visibility and swaps; rejected hash; cancelled load; activation refusal cleanup; successful rollback/idempotent dispose. Test dependency path is `$TEMP/mafiozi-glass-three180/node_modules/three` or `THREE_MODULE_ROOT`. Runtime itself does not use that test installation.

Remaining release gate: host activation map preflight, collision/door live walk and screenshot in the single existing game tab. No push/commit or live PASS is asserted by this package.

## Host implementation and executable coverage

`world.html`: glass state initialized immediately after `_UP` (before early map collision calls), exact receipt contract, protected-site checks plus business exterior overlap, body/corridor collision, shell/resident-door suppression, GALLERIA generic building E interaction, focus and diagnostics, token-based rollback. Maps and gameplay IDs are not rewritten. All 42 samples on the front/service routes must pass real `isBlockedPed` during activation.

`three_preview.js`: host-injected bounded import/load/install before first world snapshot, 20-second AbortController cancellation, legacy fallback, full-size placement, player-distance LOD, occlusion participation and contact shadow. Outer renderer startup failure rolls back the activation.

`node assets/buildings/city_v3/glass_v1/test_host.mjs` PASS: actual source function extraction, all classic scripts compile, adapter-host exact equality, 16-tile deterministic fixture preflight, actual collision helper paths, corridor access, exact suppression, interaction, rollback and negative protected-site/receipt cases. The fixture deliberately does not pretend to be a live generated-map or visual proof.

`py -3.11 -m unittest -q test_city_v3_building_asset_runtime.py test_city_building_overlap_contract.py`: **13/13 PASS**. `node --check three_preview.js`: PASS.

## P0 live-door correction

User's actual GALLERIA screenshot exposed a floating black generic doorway beside its right wall. The original suppression incorrectly tested the **wall tile** against an exclusive legacy rectangle. Running the actual `_residentBuildingDoors()` source on the deterministic host fixture reproduces `door_45_65_0`, buildingR47/buildingC68, pavement anchor47.5/69.5, wall47.5/69. The wall lies exactly on excluded maxC69, although its building belongs to the replaced plot.

Correction: `_cityV3GlassOwnsLegacyDoor` uses exact door identity or generic source buildingR/C ownership before the wall test; neighboring/authored unrelated doors are retained. `getBuildingDoors()` reports exact suppressed IDs/source coordinates in `document.documentElement.dataset.cityV3GlassDoors`; `legacyVisibleCount` must be0. Renderer reports actual pooled legacy actor IDs/count and authored public leaf existence/visibility in `threePreview.dataset.cityV3GlassRenderedDoors`. The two source-authored public leaves remain untouched.

Interaction correction: GALLERIA accepts reasonable frontal approach within3.05 tiles rather than only the narrow physical corridor centerline. The old sixteen MAP building tiles are excluded from generic proximity scanning, preventing a second generic «Здание» marker from resurrecting the removed box. Source-generator door regression, wider frontal interaction, neighboring-door preservation and13 existing building tests PASS. **Reload and actual screenshot confirmation remain root-owned; this correction is not yet claimed visually closed.**
