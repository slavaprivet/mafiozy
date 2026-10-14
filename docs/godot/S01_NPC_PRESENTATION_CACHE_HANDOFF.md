# NPC presentation transport and cache — current handoff

27 September 2026. Native presentation package is implemented; actual source-session residents and host placement are the next gate. No main, project, physics, source-world, game process or Git publication changed by this author.

## Current files and receipts

| File under godot/mafiozi_walk/scripts/npc_visual | SHA256 |
|---|---|
| npc_visual_loader.gd | 6e8f9c0c5e55ed0b18cdd590ad4e30141108fd73b96a93a078a70b16763bac54 |
| npc_float_color_bridge.gd | bb4932772bfaae737b1e5d4d1485711060055c7de9c685918b3bd2f35b375662 |
| npc_float_color_material.gd | 684856bc29f73911792be8e9613aeb3d42b8d8556a564f1e5546725e1f150259 |
| npc_visual_cache.gd | 16a29e700dc78d5006461d1ee509dc1894830ced1e67fd006e3a4207382bd4a7 |

Prepared manifest: `godot/mafiozi_walk/assets/npc_visual/prepared/manifest.json`, SHA256 `5a62f9f9f691c661996dfd82ab2d156b427dcc84b8591aa10f069b529c4b467a`. Only its 19 referenced content-hashed scenes are runtime assets. Complete list, tool/test SHA and CPU samples are in `outputs/astra21_npc_visual_cache/RECEIPT.json`, `HANDOFF.md` and `test_results.json`.

## What is fixed

Loader enables vertex color only on source meshes with COLOR0 and uses linear color input. Original Float32 source positions remain preserved. The optional bridge carries all source Float32 colors in CUSTOM0, including source HDR and negative values previously clamped by native RGBA8. It copies native packed surfaces without re-quantizing original normals, indices or skin data. Prepare is read-only; apply rejects stale/ambiguous/tampered plans before any commit. Colorless accessories remain unchanged.

The material factory creates a private shader candidate; it never installs it. Unsupported source material states reject. Shader remains OFF by default, including all 19 prepared catalogue scenes. StandardMaterial/KHR BRDF equivalence, rendered normals and actual GPU shader/pixel acceptance are still HOLD.

## Actual headless evidence

- Loader: 95 checks PASS on the current runtime loader and project assets.
- Float transport author: 411852 checks PASS, including 80472 exact source color components in three source fixtures. Independent final review: 7775 checks PASS, full 19 catalogue models, 509180 Float32 values exact. Receipt: `outputs/astra21_npc_float_color_review/REVIEW.md`, SHA256 `865fc9e561e62231f15eaed4add89f0f3656610891f0ee45bf016eb11230889d`.
- Candidate material policy: 231 checks PASS, including all 76 source core materials; actual GPU acceptance not run.
- Cache current author: 291 checks PASS after typed malformed-field fixes; independent final: 2915 checks PASS. `outputs/astra21_npc_visual_cache_review/REVIEW.md`, SHA256 `29f869f4c5d1dceef080ac818c8bd66a4d48a73f236bfdc48c70bbec68f201d6`. Original218-check evidence and failed typed-negative evidence remain separate. `outputs/astra21_npc_visual_cache/TYPED_RECEIPT.json` pins the current code/tests; original mutable test_results receipt is historical.

Counts describe their individual suites and are not a deduplicated total of scenarios.

## Cost and host use

Cache warm private instantiation p50/p95: **4.735/5.955 ms** in 20 CPU samples. Cold verified cache load: 16.145/16.814 ms; cold GLB: 19.670/22.848 ms in the same harness. Optional source Float32 validation still costs about 69.343/79.522 ms per GLB in its separate matched harness and should be prepared offline. These are loading costs, not frame time or full-scene FPS. Host must budget actual population admission.

Cache API and ownership are fully documented in its own HANDOFF. It creates presentation nodes without scene insertion, birth authority, AI or physics. Catalogue examples are not an actual resident roster.

Export prerequisite: dependency verification reads exact Loader/Bridge `.gd` bytes. A compiled PCK that strips these bytes will reject safely. Root export owner must preserve the exact bytes or explicitly approve a separate trusted dependency receipt mechanism. Standalone cache use remains NOT_RUN; do not weaken the SHA checks.

## Current next gate

Root selected explicit NEW_SESSION_BOOTSTRAP / BEFORE_NATIVE_RESOLVER, with exact source factory generation across the full 200×180 actual map and crop only afterward. Corrected source phase now passed independent151 checks and separate exact replay; three actual cropped residents have verified project assets and final prepared manifest3c07e729. See `S01_ACTUAL_RESIDENT_RUNTIME_HANDOFF.md` for the exact current package and370 independent runtime checks. Pending rows remain hidden until root's real native placement admits them. No old progress or server authority is inferred. Source session is before async overlays, not a hydrated saved world.

The preparation tool uses full-precision JSON to preserve randomized ordinary resident height/descriptor binding, SHA `40abe34b3d9187c7166cd22bf3496cfaa29fbafed9a959e1efae80e9db89ff71`. Default serialization rounding was caught on the real three-resident package and fixed without loosening Loader identity/hash checks. Source catalogue assets remain examples; actual residents are only the separately accepted session package.
