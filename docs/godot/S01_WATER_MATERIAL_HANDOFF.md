# S01 water material handoff вЂ” Artist21, 26 September 2026

## Admission

READY for Coordinator21 integration review. Actual Godot4.7.2 headless **47 checks PASS**, exit0, no errors; source oracle and independent shader-text review PASS. **Not hooked in main; LIVE shader compile, visual parity and full-scene GPU/frame cost OPEN.** No game/GPU/browser created. Current shared HEAD observed `0c08e01e844ca3ae88f9dacd02e49cad45104170`; no Git staging/publish by Artist21.

Exclusive implementation:

| Path | SHA256 |
| --- | --- |
| `godot/mafiozi_walk/scripts/preview_water_material.gd` | `51f3d2d5f6c744cc98b0131a62d2acb1e97b8327f2235702b9b1896615952d88` |
| `godot/mafiozi_walk/scripts/tests/test_preview_water_material.gd` | `b5151b419a96dae3fb3d923c4f182ce850e7e97a2f8ee4cfa2a3e19ee06f9246` |

## Exact active source

`assets/maps/city_rebuild_v1/environment_surface_materials.mjs` SHA256 `6598e763455f568902d678b24954e9f659fcd8dc804d41fc769270befe6be334`, revision6. Actual Walk `createEnvironmentVisuals` replaces native/landscape initial blue base materials; final white/.23roughness/.02metalness/.92opacity and shallow#428c82/deep#124d5e/shore#bbcbb7. Source_color uniforms supply the same sRGBв†’linear conversion (CPU oracle checked).

Fresh baseline check: material source SHA6598e763… and environment_visuals SHA0e2b59bf… are byte-identical to current HEAD0c08e01. `landscape_terrain.mjs` working SHA `cab1803f3dbd4dc8160bff451d596af321c5fd2230351f4f60d7c6ff54313ae2` differs from current HEAD: landscape geometry activation evidence is **working-source**, not proof of published geometry. No landscape changes made by this task. Root must preserve/lock intended geometry during integration.

Full source activation/geometry/depth/time/coefficient audit: `outputs/astra21_water_source_audit/REPORT.md`. Oracle `oracle.mjs` and `fixtures.json` include actual patched Three180 formulas, five source-world samples and Jacobian finite difference maxerror4.71e-10. This is zero-ripple/filter1 CPU reference, not full GPU lighting parity. Independent implementation review `IMPLEMENTATION_REVIEW.md` compares six shader functions + full active color block after explicit language conversions.

Port preserves four analytic domain warps + six derivative-filtered normal waves, chain-rule Jacobian, eight fixed ripple slots and annulus early cull, absorption, shoreline zero-depth coverage, wet sediment, foam, anti-aliased shallow caustics and roughness. Source-normal mapped to Godot view NORMAL, source-world camera restored through origin. Lambert diffuse matches local Three180 BRDF; normal physically lit specular retained. No vertex displacement, textures, extra passes or screen-space reflection added.

## Root integration contract

1. Instantiate one `preload("res://scripts/preview_water_material.gd").new()` per environment generation. All origins/depth variants share a static Shader. Repeated `material_for(source_origin_m, vertex_depth)` returns cached ShaderMaterial. Use a shared original-source origin per terrain generation; per-object arbitrary origins grow the factory cache. Dispose at generation replacement.
2. During mesh assembly once, call `prepare_depth_arrays(arrays, source_world_transform, depth_at)`; sampler Callable takes **x,z,y** in original world metres. Result `{ok,arrays,flags}` reserves CUSTOM0 Float32 R_FLOAT; reject existing CUSTOM0 rather than overwrite owner. Add supplied flags alongside any existing appropriate ArrayMesh flags. Prepared vertices/normals/UVs remain unchanged; never add collision from this helper. A root adapter may cache prepared arrays once per actual geometry, equivalent to source WeakSet; helper itself intentionally pure and does not attach nodes.
3. For prepared Float32 depth call `material_for(origin,true)`. Use true only when CUSTOM0 depth is certified present. False fallback2.5 matches source absent-attribute default; **fallback is not active coastline acceptance**. Actual source caller is `waterAt(x,z)?.depth??0`; include native source bathymetry/protected-water rules and terrain clipping, not guessed uniform depths. Depth numeric/dictionary.depth finiteв†’clamp0..50, invalidв†’0. Invalid vertices/transforms/overflow fail explicitly.
4. `update(time_seconds)` accepts absolute wallclock seconds, first finite call defines epoch; uniform=max(0,time-epoch). Call with monotonic wallclock equivalent to performance.now*.001; no Godot TIME (rollover/time_scale differ). Invalid times ignored. New variants inherit current relative time.
5. `set_water_ripples(events)` processes exactly first8 array slots, never compacts invalid slots or reads the ninth. Dictionary fields x/z/age/strength must numeric finite; age0..4.5, strength>0в†’cap2; otherwise sentinel(0,0,-1,0). Coordinates already source-world metres, age supplied by FX owner. Reused packed8array; update loops cached typed material list (no Dictionary.values temporary or mesh scans). New materials inherit current ripples.
6. Root sets water mesh cast_shadow OFF, receive shadows ON and material.render_priority analogue1. Shader blend_mix/depth_draw_never/cull_back reflects transparent/frontside/no depth write. No floor/collision/physics changes authorized here. Source envMapIntensity0.7 is **not independently per-material represented** by this spatial shader: coordinate environmental lighting/reflection mapping with existing Godot scene. Renderer lighting, transparency sorting, specular and source_color backend differences need sole-root LIVE comparison; do not declare exact rendered appearance from CPU coefficients.

`dispose()` clears factory-owned references and prevents new updates/materials. External material references remain valid resources; scene lifecycle owner releases them. Static shader remains shared. No material/Shader creation in update, no per-frame I/O.

## Validation and cost

Run actual bundled console (no new GPU):

```powershell
& 'C:/Users/РЎР»Р°РІР°/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_water_material.gd
```

47 PASS: reuse/shared shader, origin rejection, palette+linear oracle, epoch/backwards/NaN/Inf time, all-material updates, eight-slot/noncompact ripple semantics/strength cap/age/type rejection, Float32 preparation/source-world sampler/no geometry mutation, actual ArrayMesh custom format, invalid owned channel/empty arrays/nonfinite transforms/vertices/overflow, exact active hash/noise/fullfragment/ripple/coverage/roughness expressions and normal/Lambert/render contract, inert disposal.

CPU10000update batch mean with two reused materials **0.5031Вµs/call** in current run; an earlier allocation-producing `.values()` loop measured1.1758Вµs then typed-list loop. These are synthetic CPU batch averages, not comparable full-scene before/after framep50/p95 or GPU overhead. Whole-scene before/after under matching root camera/settings/population/warmup remains OPEN. Headless RenderingServer does not prove shader GPU compilation; test never calls this LIVE PASS.

## Remaining acceptance

Root hook + actual sampled water mesh/depth, sole game shader compile, native/landscape shoreline contact and ripple visual comparison, opaque floor absence/swim physics preserved, source lighting/environment intensity mapping, scene frame-time p50/p95 + draw calls/triangles and logic update before/after. No blanket S01/full migration acceptance.
