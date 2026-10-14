# Native NPC visual — rig/geometry package, renderer HOLD

2026-09-27. Artist21 implementation, Coordinator21 integration owner. Initial source-native package is concrete and independently tested; the approved FLOAT32 color repair is the next bounded stage and stays off by default until root GPU admission. This package does not migrate NPC births, gameplay authority or the full actor/controller.

## Files and fixed checkpoint hashes

The hashes below identify the initial reviewed checkpoint. Subsequent approved FLOAT32 seam uses loader6e8f9c0c5e55ed0b18cdd590ad4e30141108fd73b96a93a078a70b16763bac54: actual runtime GLTF importer left vertex_color_use_as_albedo=false on all76core materials. Loader now explicitly enables it iff native COLOR exists and retains linear metadata; source asset SHA is also stamped on visual. Native geometry arrays are unchanged. Actual all19core-material candidate admission231checks PASS; independent float stage validates current snapshot separately. Do not confuse initial checkpoint SHA with current file.

- godot/mafiozi_walk/scripts/npc_visual/npc_visual_loader.gd — b7f6cbcd0e4d617e95a91c5953093607f1629855b53b74f565eae3831afdccf8
- godot/mafiozi_walk/scripts/tests/test_npc_visual_loader.gd — 8b7976d39a57e7689c6dfd2e3b6492d381042f1737dffa1f962719f5bb88bc12
- tools/godot/export_npc_visual.mjs — d9a4925db4eda34c40dcd48d2efc15cf3ac3afc7b08f8e24d7fff94a761c8dc9
- godot/mafiozi_walk/assets/npc_visual/catalogue_manifest.json — 843303e12bf6bc3a65159186410915025c4659688040f2544e06cb12f443a40a
- Same directory contains19hash-named verified GLBs,11,878,632bytes total. Per-file hashes and exact bridgeId/descriptor/canonical-source bindings are in the immutable manifest. Catalogue and first-sample source artifacts remain unchanged.
- Independent outputs/astra21_npc_visual_native_review/REVIEW.md — 1a6940e7e092543f8b0ecb60b40ad8d36fda73b611974cda749f006f4be2f0d8

Full source receipts/oracles/dependency modules are in outputs/astra21_npc_visual_source, including EXPORT_HANDOFF.md, SOURCE_INPUT_HANDOFF.md, SOURCE_INPUT_TEST_RESULT.json, COLOR_RANGE_AUDIT.json and exports/*.json. Oracles46,725,188bytes are offline proof, not copied to runtime assets or required by the structural loader. Pinned missing Three180 addons are under that output's deps directory with official URLs/SHA; no npm/vendor/source upgrade.

## Source and native behavior

Exporter applies the actual npcAppearanceFromWorld/applyNpcAppearance/createHeroWalker rest-normalization path, preserves exact bridge ID RNG, male/female geometry, vertex deformation and all13hairstyles/accessories. It supports actual source rows or complete resolved descriptors through --source-input with exact IDs/source-module/canonical/descriptor hashes and bounded provenance schema. Resolved descriptors retain unknown fields and bypass regeneration. Test-only inputs have separate manifests and cannot be selected for production.

Native loader uses built-in GLTFDocument/GLTFState with IMPORT_FLAG_FORCE_DISABLE_MESH_COMPRESSION64. Every actor has private Skeleton3D, ArrayMesh, Skin, surface materials and bone-following accessory nodes. Model import has no _process, scene insertion, collision/body creation, AI, HP or ID allocation. Zero source clips remain zero; no invented walking AnimationPlayer. Full source actor wet/phone/cash/pose/action/death runtime remains outside this neutral appearance bridge.

Production host calls select_entry(manifest_bytes, independently_admitted_manifest_SHA, exact_bridge_id, expected_source_descriptor_SHA), then load_file(entry, bridge_id, asset_directory). The returned dictionary contains ok, visual, skeleton, meshes, attachments, bone_indices, descriptor, timing phases and explicit material/normal fidelity HOLD. Caller owns insertion/lifecycle. Self-declared hashes/provenance do not authenticate a source session; host must supply trusted descriptor expectations. Reject stale appearance, unavailable descriptor, duplicate manifest IDs and test-only synthetic inputs. No implicit ID prefix rewriting or fabricated population.

## Actual verification

- Author Godot4.7.2:95checks PASS/exit0 with all19 copied runtime assets; complete output outputs/astra21_npc_visual_cost/project_assets_native.log.
- Source full19export and separate-process --check: exact GLB/oracle/manifest repeatability,336meshes/158594vertices, all13hair styles,7female12male; original templates unchanged. Source→Three roundtrip max world component error6.4983355e-8m, complete normal arrays exact after recorded corrections.
- Generic source-input:32checks/25cases PASS,18negative cases reject. Actual catalogue Leila row and resolved-descriptor replay emit the same source GLB; separate process byte-repeat PASS. Native generic selection/import integration49actualchecks PASS/exit0, unknown nested fields retained, stale descriptor/package/provenance and synthetic production selection rejected. outputs/astra21_npc_visual_source/input_native_tests/HANDOFF.md; test8c43b02e5f377fb8cea71f9550a88e1e9ac077bf4d5b6636f3d801e7bf4be9ea/fixture d894d54a30eac2fbc2698fd0dc42f3cacdf0d2170f09f9f986b2fd69a3c0db09.
- Independent61negative/base-ownership/selector checks PASS; intentional failing selector canary10checks exits1.
- Independent all19source-native oracle:4411checks,zero unexpected failures,2explicit source-color HOLDs,exit2.702696used triangle corners; source local positions maxdelta0, packed-skin CPU neutral world maxdelta.00006556510925m within explicit.0001m budget. All28canonical bones/rest/world/IBMs/semantic weighted palettes and source accessory offsets/bone following were checked per fixture. Pose/material/Skin mutation and disposal of actorA leaveB intact.

Import winding reversal/unused-vertex compaction is accounted for; raw array length equality is not the test. Native COLOR_RGBA8 ordinary-channel budget remains1/255 and packed weight budget1/65535+1e-6. No widening to hide source HDR. Independent original4075checks/one Sofia failure/exit1 is retained in ORIGINAL_FULL19_FAILURE.txt.

## Confirmed renderer/data limitations

- Sofia FABRIC:120used red values1.0515706539154053; native RGBA8 clamps them, observed delta.05157065391541. SOURCE_HDR_HOLD.
- Rustam FABRIC:8used negative red values, min-.00021768599981442094. Same storage clamp, SOURCE_COLOR_RANGE_HOLD even though within ordinary quantization budget.
- Canonical IOR/specular full BRDF remains HOLD. No scalar F0 substitute or StandardMaterial setter is claimed equivalent to source lighting.
- Source zero normal values, including a zero-area cap pole, were restored after pinned exporter normalization with an explicit1043correction ledger. Unit-normal glTF conformance, native degenerate normal behavior and pixels remain HOLD.
- Root approved the next NPC-only CUSTOM0_RGBA_FLOAT preservation seam; no candidate shader activation by default before GPU verification. These limitations mean **not full appearance acceptance**.

## Cost and integration dependencies

Fixed Leila20samples/5warmups: typed packedarray audit reduces same-default importer creation p50/p9523.648/24.905→18.535/20.366ms. Finalflag64 p50/p9518.473/21.084ms. See outputs/astra21_npc_visual_cost/RESULT.md and rawreceipts; pre-optimization code SHA was not captured. This is observed headless loading CPU, not guaranteed FPS. Fresh imports should be prewarmed during loading and ready visuals reused; per-frame import/streaming is not accepted. Flag64 firstsample surface storage+8,912bytes/+2.22% preserves source Float32 positions.

Outstanding integration dependency: trusted live resident/service source descriptor/roster provider, source clocks/epochs/lifecycle and native controller/navigation host. Existing catalogue inputs are real source appearance records but **not live inhabitants or authenticated births**. Root owns main/project/export filters, single-game renderer/culling/shadows/shader QA and comparable fullscene FPS. None of these are closed by headless tests. No source/player/main/export-presets/Git/process edits by Artist21.
