# NPC appearance bridge — first checkpoint

2026-09-27. Assigned by Coordinator21 to Artist21. Scope: new scripts/npc_visual/*, tests, tools/godot/export_npc_visual.mjs and new NPC appearance assets/manifest under assets/npc_visual. No roster/birth, HP, authority, main/player/navigation/interior/project/export-presets edits. Staticbatch is frozen for root integration.

## Source dimensions and exact identity

Source pipeline is npc_population.npcAppearanceFromWorld(actual bridge appearance row), which applies sourceLookAppearance and bossArtDirectionForId then describeNpcAppearance. Stable RNG uses the exact bridge row ID including its existing prefix. Do not derive a different seed from raw resident ID or employment slot; do not add/remove npc_ inside the visual consumer. The descriptor ID must equal the requested existing bridge ID.

Preserve both canonical sexes, target height1.65..2.05m, build and torso/face deformations, vertex skin/outfit/shirt/trouser colors, all13source hairstyles and generated brows, hats/helmet/visor, facial hair, glasses/earrings/bowtie/scarf/chain, wardrobe/accent/medical marks/shield and their canonical bone attachments. Use the actual source applyNpcAppearance rather than reimplementing these formulae approximately. Look.face/hair/hat integers are not manually remapped into invented native traits: the original pipeline decides which source overrides it uses.

Male source SHA8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00; female298d50e6244a7f17cf9cb66530fc34645fec0f19b575fe99d1df514709e90c40. Both have one skin and zero animation clips. This scope supplies a native rigged visual, not a walk controller or invented AnimationPlayer clip. Source pose subsystem/controller integration remains separately owned.

## Reproducible offline export

Offline exporter accepts actual resolved source descriptors or actual bridge appearance rows with provenance. It calls the pinned local Three180/source factory on independently SkeletonUtils-cloned canonical templates, with cloneTextures=true matching population. Height/offset normalization must match createHeroWalker after appearance; do not renormalize the resulting native actor a second time. Export GLB with skin/bones/private changed vertex arrays/material colors/accessory nodes and a CPU geometry/rig/material/attachment oracle. Exact source inputs/module/vendor SHA and descriptor/hash are receipted.

Initial source catalogue fixtures can use the existing named NPC look records with their explicit bridgeIds and source art direction. These are appearance catalogue inputs, **not a captured live roster**, not seller/resident births or a new session. Synthetic override rows are marked tests only and cannot enter the production manifest. Missing trusted actual resident/service descriptors remains an integration input requirement rather than fabricated IDs.

New assets live in godot/mafiozi_walk/assets/npc_visual/<content-key>.glb plus an appearance manifest. Content keys are safe hashes; user bridge IDs do not become filesystem paths. Export limits/count/size and fail-closed canonical inputs will be specified in the executable exporter receipt. Existing source assets remain unchanged.

## Native consumer operations

Consumer validates schema, exact bridge ID/descriptor binding, asset hash/canonical source receipts, safe paths and bounded counts before import. GLTFDocument/GLTFState generate Skeleton3D, MeshInstance3D, Skin and bone-owned attachments. Every actor has independent skeleton/pose, geometry, material and skin ownership; actor mutation/disposal must not affect another actor or a cached template. Only explicitly verified immutable raw bytes may be cached. Actor exposes its source descriptor, native rig/bone mapping and visual readiness; it owns no position/HP/lifecycle/AI authority and does not add itself to a scene or allocate an NPC ID.

Production callers first use select_entry with an independently admitted manifest SHA and the source host's expected complete descriptor SHA. A self-declared canonical source SHA does not prove derivation; low-level load_bytes/load_file are importer operations for already admitted entries. Manifest selection rejects stale appearance and duplicate IDs. Before native import, bounded GLB JSON/BIN chunks, accessor spans/decoded budget, primitive and instantiated vertex budgets, typed scene roots, node cycles/duplicate parents, internal buffers and one28-joint skin are checked. Fresh imports are deliberate initial ownership baseline; measured creation cost and an explicit loading policy remain required before runtime integration.

Pinned Three exporter auto-normalizes NORMAL attributes. Actual source has zero normals on orphan eyebrow vertices and a zero-area hair-cap pole triangle. Exporter may restore exact source Float32 normal accessor values after export with a correction ledger and exact zero-area witness. Do not alter source topology or hide the correction. This preserves source data; it does **not** claim unit-normal glTF conformance or native degenerate-normal/pixel parity. Nondegenerate used triangle attributes still require their source→export→native comparison. Normal-degenerate fidelity is a separate HOLD until actual native observations exist.

Geometry/vertex colors, normals, skin weights/indices, bind/rest hierarchy, normalized height and head/chest/forearm attachments must be compared source→export→native on actual descriptors, including private ownership mutation tests. Main-thread actor creation cost and retained bytes are measured before root handoff. Source provider decides when a model-ready result permits publishing an existing body; visibility/birth/physics remain outside the consumer.

## Material fidelity and open acceptance

Preserve source material parameters/extensions in export and oracle. Current Godot importer has known KHR_materials_ior/specular mapping limits on canonical hero materials. A scalar specular/F0 adjustment is not a proved full BRDF match. Do not silently remove those fields, change source GLB or claim pixel parity from material setters. Report unsupported native fields with exact source values as a separate readiness limitation; any scoped material correction requires an explicit justified contract. Source geometry/ownership acceptance can proceed while root visual/material/GPU acceptance stays OPEN.

Root owns the only GPU game/editor (latest supplied editor6508/game32648), renderer/export wiring and actual actor visual/FPS acceptance. No second game launched. This checkpoint is a contract; implementation, source oracle and native headless validation are the next work.
