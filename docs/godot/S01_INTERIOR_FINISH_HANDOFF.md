# S01 interior finish factory — final standalone handoff

The standalone factory preserves actual Walk interior-finish-v2 patterns for opaque, double-sided, untextured source descriptors. Root Artist21 owns the production factory and adapter integration. This handoff is the independent source reviewer’s file; adapter integration is separate and was not reviewed at this freeze.

## Frozen files

| File | SHA256 |
|---|---|
| `godot/mafiozi_walk/scripts/preview_interior_finish.gd` | f2137740ac1b31669454f18c258db3560bf3c9eb9ff35b0a00875db0ee6bb497 |
| `godot/mafiozi_walk/scripts/tests/test_preview_interior_finish.gd` | dcb2610c32544fe6d87d9671c97c1f69066bb49c5b336bc12c64c97fa5182d4a |
| `assets/maps/city_rebuild_v1/interior_finishes.mjs` | 95f5d850ba2414194d0e2982224dfe6ce9fba0b1c9f713d415dd1b74e51320dd |
| `assets/maps/city_rebuild_v1/building_interior_design.mjs` | a0881b7b05800c2ee7fe16d3dd3a2f58d983fb0f92fb6582edc4f5e7a25a4b76 |
| `godot/mafiozi_walk/data/printshop_interior.json` | 958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b |

## API and integration contract

Create one factory instance, then call `material_for(source_descriptor, proven_floor_surface, source_origin_m) -> ShaderMaterial`. Null means preserve the existing material fallback. The required boolean represents the source factory’s projection role, not collision classification. Origin is the original city offset removed from the exported transforms; for the current package it is `Vector3(395.65,0,45.099999999999994)`.

The shader computes preview world position with MODEL_MATRIX then adds this origin, restoring the absolute source world-metre pattern phase. Current static preview integration assumes identity parent world transform. Any later preview relocation requires an explicit source-space transform decision. It must not rotate or scale the pattern coordinates a second time.

The actual generated materials are index15 `InteriorFinish_concrete`, source program `interior-finish-v2-4-true`, assigned to `Entry_Interior_Floor`; index16 `InteriorFinish_brick`, program `interior-finish-v2-1-false`, assigned to the Entry interior walls and `Storey_Walls_And_Ceilings`. The latter has exported floorCollision=true but shader floor=false. Its horizontal faces get tone1. Generic floorCollision must not select floor projection. Material names of original GLB surfaces do not identify these generated shaders.

The factory accepts source-fixed opaque/DoubleSide/nonvertex-colored, metalness0, opacity1, emissiveRGB0 and emissiveIntensity1 descriptors. Roughness=.48 only for literal tile, otherwise .82. Malformed or unsupported factors return null; the final guard rejects NaN/unsupported emissiveIntensity even when emissiveRGB is zero. Unknown source finish follows source mode0. Already-linear RGB is supplied as a numeric vec3 without source_color annotation.

There are at most twelve shared shader variants (six modes × two floor roles), and128 cached materials per factory. Identical accepted descriptors/role/origin reuse the material. Returned resources must remain immutable by caller convention. `dispose()` clears factory material references and prevents new acquisitions. Shader resources are shared statically within the script. The factory has no process callback, time uniform, frame update, texture, geometry/UV mutation, collision or light creation.

Backface handling is independently confirmed from tagged Godot4.7.2 primary source: cull_disabled enables DO_SIDE_CHECK at [scene_shader_forward_clustered.cpp:785–786](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.cpp#L785); the engine flips the interpolated normal on backfaces before custom fragment execution at [scene_forward_clustered.glsl:1170–1173](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1170). The factory leaves NORMAL unchanged, avoiding a second flip. This proves source behavior for Forward+, not visual GPU execution in this review.

## Validation and limits

Owner Artist21 reports **179 actual Godot4.7.2 headless checks PASS**, including actual source callback formulas, metadata/cache keys, invalid descriptor fallback and the mixed wall/floorCollision case. The reviewer did not rerun that Godot suite or launch GPU.

Independent reviewer CPU checks executed the real export generator with read-only instrumentation: both procedural descriptors and both exported PointLights match the existing JSON; all40 imported source receipts match disk. Additional oracle executed20 actual factory callback variants, matched all16 nonzero-mode formula bodies exactly against the Godot source, generated300 numeric fixtures and verified source material lease identity/idempotent release/cleanup. Numeric results are CPU formula transcriptions, not compiled shader pixels. Full patches, coordinates, negative-position/tie cases and provenance are in `outputs/astra21_interior_finish_source/actual_patch_fixtures.json` and `numeric_fixtures.json`; detailed audit in `REPORT.md`.

No actionable formula defect remains in the frozen standalone factory. GPU shader appearance, environment/specular/tonemapping correspondence and comparable loaded-scene FPS remain **OPEN / NOT_RUN by reviewer**. Root’s headless checks do not establish these. Adapter wiring and final export dependency inclusion require their own review.

PointLight unitmapping is not implemented or claimed. Receipted Three180 defines intensity in candela, isotropic power=4π×intensity and its precise inverse-power/cutoff falloff; this proves8cd=100.53096491487338lm, not a Godot energy multiplier. Source point-light parity is separate from finish modulation. This package changes no lights, main, exported data or export configuration.
