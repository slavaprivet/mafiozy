# S01 printshop procedural finish hook — final receipt

Coordinator21 assigned exclusive adapter and new hook test scope after standalone finish acceptance. The adapter is now **FROZEN for root release07**; no main/project/export/data/player/physics changes by Artist21. Root reported independent rerun35 hook checks PASS and adding export dependency. Visible game release06/PID12540/session49876 remains owned by root; these new finishes are not claimed visible until root release.

## Exact delivered bytes

| File | SHA256 |
|---|---|
| `godot/mafiozi_walk/scripts/preview_printshop_interior.gd` | `d107b21891585ff806d7a3c880c965b3b61ccb8b449ddafa0557e657f1c59fa8` |
| `godot/mafiozi_walk/scripts/tests/test_preview_interior_finish_hook.gd` | `c458ac2ddaf57fff0a75b3c43838b6d37635d49912036824f174c3abeb91c046` |

Standalone factory `preview_interior_finish.gd` SHA f2137740ac1b31669454f18c258db3560bf3c9eb9ff35b0a00875db0ee6bb497; factory test dcb2610c32544fe6d87d9671c97c1f69066bb49c5b336bc12c64c97fa5182d4a. Source factors/roles/oracle receipts/API in `S01_INTERIOR_FINISH_HANDOFF.md`; independent reviews in `outputs/astra21_interior_finish_source/REPORT.md` and `ADAPTER_REVIEW.md`.

## Change

Adapter `_material` returns generic Material so it can supply ShaderMaterial or the unchanged StandardMaterial3D fallback. Only proven source index15/nameInteriorFinish_concrete uses floor=true; index16/nameInteriorFinish_brick uses floor=false. This role comes from actual source customProgramCacheKey and immutable exported source identity, never from floorCollision. Storey_Walls_And_Ceilings has floorCollision=true but must stay wall projection; source shader suppresses its horizontal pattern.

Only uncolored, recognized descriptors use the factory; unsupported/altered names or factors, all instance/vertex color variants and ordinary materials continue through the original StandardMaterial path. Original sRGB property conversion, linear instance colors, transparency, emissive and cull handling remain there. Accepted source palette is already linear and feeds numeric shader vec3 without extra conversion. Original city origin restored by factory MODEL_MATRIX+origin, preserving scaled/instanced world-metre pattern.

No geometry buffers, UVs, material slot selection, collision shapes, action/door IDs, obstruction rules or server authority change. Resource preparation still precedes any source visual mutation. Factory material references clear on prebuild rejection and restore; adapter cache and original geometry restoration remain intact. Each valid attach creates at most the actual two finish materials; shared shader variants are static/bounded, no per-frame material/shader creation and no new frame update.

## Actual checks

- Factory author Godot4.7.2 headless179 checks PASS; independent actual source instrumentation40 receipts/two descriptors and two source lights match,20 callback variants/16 exact formula bodies/300 numeric fixtures PASS. GPU shader execution not covered.
- New `scripts/tests/test_preview_interior_finish_hook.gd`: author35 checks PASS on real imported GLB. Actual source floor/wall assignment, color/origin/cache/ordinary and unsupported fallback, instance colors, no partial resource creation on early origin rejection, repeated attach, original mesh identities restore and fresh reattach. Root independently reran35 PASS.
- ORIGINAL `scripts/test_preview_printshop_interior.gd` rerun after hook: **843 checks /100 door cycles PASS**, no SCRIPT errors. Actual door/capsule collision, obstruction, floor support, colored furnishing and restore invariants retained. This is headless actual physics, not visual acceptance or complete NPC/economy.
- Author door advance CPU p50 .025ms/p95 .035ms; attach60875µs includes full source geometry/colliders/GLB adapter, not isolated shader cost or comparable before/after FPS. Material lookup synthetic10000calls mean10.8805µs, construction only and not used each frame. Same-scene before/after GPU/framep50/p95 remain OPEN.

Initial new hook test assumed source finish nodes were MeshInstance3D; actual source uses MultiMeshInstance3D. The test helper was corrected and both exact material assignments now pass. Only the failed own headless test processes52836/25492 were stopped by verified PID+script+headless command; live game untouched. This test issue was not a runtime adapter defect.

Reproduce with bundled engine --headless --path godot/mafiozi_walk and scripts above. Root export must contain literal dependency `res://scripts/preview_interior_finish.gd` in selected PCK. Root reports entry added; final exported payload validation still belongs to root.

## Limits / remaining gates

GPU compile/visual color, mortar projection, backface lighting, reflection/tonemapping, same loaded-scene frame-time and updated visible release not proven by CPU/physics. Independent review confirms no actionable adapter defect for current trusted export; early invalid-origin check does not exercise hypothetical post-factory resource failure and mesh-identity test does not separately assert every original visibility flag. Restore visibility code remained unchanged and source-reviewed.

The two exported source PointLights are still not created here. Three8cd=100.5309649lm and actual decay/cutoff were independently extracted; Godot energy mapping/current render profile not yet demonstrated. Coordinator assigned this as next separate research/factory scope; no arbitrary light-energy or global exposure changes.
