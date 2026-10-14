# NPC FLOAT32 vertex-color seam

2026-09-27. Root21 explicitly approved NPC-only CUSTOM0_RGBA_FLOAT transport and an opt-in material candidate. Source/player/main are unchanged. New shader is **OFF by default** until root GPU admission; this is not StandardMaterial/KHR BRDF parity.

Confirmed source values require float storage: SofiaFABRIC120used red values1.0515706539154053 and RustamFABRIC8negative red values(min-.00021768599981442094). Existing native ARRAY_COLOR storage clamps to RGBA8 even when mesh compression is disabled. Do not widen1/255 ordinary quantization tolerance to call this preserved.

## Mapper

npc_float_color_bridge.gd prepare(visual, verified_glb_bytes, independently_admitted_asset_SHA) maps exact source_mesh_key/primitive/source indexed CCW triangles to native compacted CW indices. It validates source positions, normals/UV/bone palette/IBMs/weights and existing clamped palette; ambiguous or altered inputs return explicit HOLD. Only original COLOR_0 core surfaces participate; colorless accessories remain untouched.

Source Float32 RGBA is appended as native CUSTOM0_RGBA_FLOAT. Preserve existing packed vertex/normal/index/skin/attribute content, topology, material bindings, AABB and shadow resources. Reconstructing with add_surface_from_arrays re-quantizes normals and is not accepted as exact preservation; the actual4.7.2 packed surface route must be independently verified. Every replacement mesh remains actor-private.

prepare does not change live meshes. apply checks all original/replacement payload identities and signatures before assigning any replacement; stale preparation must not partially commit. Preparation is loading work, not an automatic per-frame callback. No shader assignment occurs in either mapper operation.

## Candidate material

npc_float_color_material.gd make_candidate(imported_StandardMaterial3D) creates a private ShaderMaterial without installation. Input is a prepared CUSTOM0_RGBA_FLOAT mesh with finite source alpha1. CUSTOM0 is already linear; shader does not decode it again or clamp it. Native imported albedo factor uses source_color uniform, and roughness/metallic/specular/cull/render-priority parameters are retained as an explicit native candidate.

Policy requires opaque per-pixel Burley/Schlick material, linear vertex-color metadata, opaque depth draw, disabled distance fade, no textures/features/next pass/grow/billboard/fixed-size/trails/depth/shadow-opacity/FOV flags. Unsupported branches HOLD; no fallback that silently loses properties. Source material is not mutated. Candidate result always reports shader_active=false, material_fidelity=HOLD and root GPU requirement.

Before binding, caller verifies the corresponding prepared float channel and opaque alpha contract. Candidate helper alone does not turn an arbitrary mesh into a source-faithful model. Current CPU41author and10independent policy/ownership checks passed; Shader GPU compilation, rendered HDR/negative response, shadows, environment behavior and comparable single-game ON/OFF cost remain root acceptance work.

## Stage acceptance

CPU transport admission requires exact Float32 custom-channel readback including >1/<0, unchanged all original arrays/packed buffers/material/Skin/bind/indices/bounds, all-or-nothing stale rejection and A/B mutation/free isolation. Compare source oracle separately from native default clamping. Keep original4411all19 geometry/rig receipt and original4075failure; a new color transport PASS does not retroactively make the default renderer faithful.

Root activation requires the one existing game/editor, explicit shader enable step, actual compile/image/performance check and rejection handling. Do not publish model readiness as full rendered parity or source actor birth merely because float bytes are present.
