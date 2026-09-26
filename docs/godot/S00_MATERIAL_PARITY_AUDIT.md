# S00 material audit, 26 September 2026

**Later source tracing supersedes the intermediate-asphalt recommendation below.**
`environment_visuals.mjs` replaces the initial native terrain materials after
`terrain()` builds them. The final canonical dry materials are now ported in
`preview_surface_materials.gd`; see the implementation contract at the end.
Root's subsequent LIVE reported that white point 6 did **not** fix clipping.
That initial lighting hypothesis is therefore not an accepted fix, and source
materials must not be darkened to hide the lighting issue.

Read-only review of `outputs/godot_preview_20260926.png`, current imported
resources, source GLBs and Walk's material setup. No game script, source asset
or GPU process was changed/launched by this audit. A short Godot 4.7.2
`--headless` resource inspection was used; it is not a rendered acceptance test.

## Findings

The white terrain in the captured image is real clipping, rather than a missing
export palette. In the rectangle `(280,430)..(520,595)`, all 39,600 pixels are
RGB `(255,255,255)`. A road-region sample `(780,380)..(1030,570)` averages
`(189.07,212.80,214.47)`; it is very pale but not fully clipped. These image
regions exclude the HUD and sky. Exact image hash and measurements are in
`outputs/godot_material_audit26_pixels.json`.

The exact source-import evidence distinguishes three cases:

| Asset/material family | Source evidence | Actual Godot import | Consequence |
|---|---|---|---|
| Four building GLBs and Bellini lamp | All 499 source primitives lack `COLOR_0`; colours are `baseColorFactor` | No imported surface has `ARRAY_COLOR`; 53 named materials retain coloured albedo | Do not force vertex colours on these assets |
| Existing male hero | Seven source primitives have `COLOR_0`, 8,338 colour entries, 29 distinct rounded colours | Seven surfaces retain colour arrays, but all four imported materials have `vertex_color_use_as_albedo=false` and white albedo | Confirmed hero-only import consumption defect; assigned player owner fixes it |
| Generated terrain | JSON palette holds the original Walk sRGB hex values | `Color("#525a5a")` remains `(0.3216,0.3529,0.3529)` as the material property | No missing palette or reason to re-encode the hex colour |

Building base factors are imported with the correct linear-to-sRGB conversion
for Godot's material colour property. For example, print-shop `Warm concrete`
has glTF factor `(0.4,0.39,0.35)` and imported albedo
`(0.6652,0.6576,0.6262)`. Its brick factor `(0.58,0.22,0.08)` becomes
`(0.7858,0.5064,0.3133)`. This is not missing colour. Roughness, metallic and
material names are retained. The imported hero source colours include dark
fabric `(0.031,0.024,0.020)` and burgundy `(0.168,0.026,0.040)`; the white
appearance is not authored white clothing.

## Root parameters to inspect first

At review time `scripts/main.gd:56` selects `TONE_MAPPER_FILMIC` but never sets
`tonemap_white`. Actual default readback is **white 1, exposure 1**, while
`main.gd:63` sets sun energy 1.5 and line 55 ambient energy 0.65. Filmic in
Godot also applies a factor of 2 before its curve; a low white point can clip
bright colours. The primary documentation recommends a white reference of at
least 6 for less blown-out lighting. This makes an explicit white point of 6
the first bounded, root-owned live experiment; it is a diagnosis/hypothesis
until the same-camera image is checked. [Godot Environment reference](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-tonemap-white)

Walk's actual renderer uses `THREE.ACESFilmicToneMapping`, exposure 1, a
hemisphere light intensity 0.8 and directional light 1.7
(`walk_preview.mjs:244`, 256, 259). These numbers are not interchangeable with
Godot sky ambient and directional-light energy. After correcting clipping,
compare explicit ACES/white-point and light settings using the unchanged
camera and actual scene, instead of compensating by permanently darkening
source building materials.

The initial source asphalt descriptor was identified as an intermediate discrepancy:
Walk's `terrain()` overrides tile 0 with `MAT_CLAY_ASPHALT_CLEAN`, linear factor
`(0.105,0.115,0.12)`, roughness approximately 0.8. Current Godot line 84 always
uses palette `#525a5a`, whose linear value is `(0.0844,0.1022,0.1022)`, and line
85 uses roughness 0.9. `block.json` already carries the actual descriptor.
To reproduce only this intermediate layer, a material can assign
`Color(0.105,0.115,0.12).linear_to_srgb()` to `albedo_color` and use descriptor
roughness. The existing fallback hex must remain direct `Color(hex)`. This
small difference cannot explain the all-white pavement by itself. Further
source tracing found that the final environment layer replaces this material;
using the descriptor alone is therefore not final Walk visual parity.

## Safe colour-array recipe for later imported assets

Check each actual surface for a non-empty `Mesh.ARRAY_COLOR`; duplicate its
effective `StandardMaterial3D` for that consumer, preserve all other fields,
then set `vertex_color_use_as_albedo=true`. Preserve the glTF linear colour
encoding (`vertex_color_is_srgb=false`); never multiply the array by a second
sRGB conversion. Leave surfaces with no colour arrays unchanged. Do not
replace all building/decor materials with a generic shader. Godot documents
the vertex colour encoding flag and notes that its conversion switch only
affects Forward+/Mobile, so changing that flag is not a substitute for
consuming vertex colours in Compatibility. [BaseMaterial3D reference](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb)

## Reproduction and limits

`outputs/godot_material_audit26.gd` reads imported scenes and prints effective
material and colour-array evidence. The clean run is retained as
`outputs/godot_material_audit26.log` and parsed JSON alongside it; script
errors **0**. No `main.tscn` was run during the audit. The initial diagnostic
needed a nil guard for surfaces without colour arrays; the retained script
and log contain that correction.

The source GLBs are unchanged and hash-verified by the exporter. This audit
does not prove final lighting, transparent-glass parity, dynamic night lights,
animation quality or full-city FPS. Only the root's single visible Godot run
can accept the proposed lighting changes.

## Implemented dry-surface helper contract

Owned files:

- `godot/mafiozi_walk/scripts/preview_surface_materials.gd`
- `godot/mafiozi_walk/scripts/test_preview_surface_materials.gd`

Integration is deliberately root-owned; `main.gd`, the exporter, assets, project
settings and player were not edited by this task.

```gdscript
const SurfaceMaterials = preload("res://scripts/preview_surface_materials.gd")
# The current excerpt has zero protected cells; false is correct for its groups.
mesh.material = SurfaceMaterials.create_material(surface, int(key), _origin)
```

API:
`create_material(surface: Dictionary, tile_id: int, source_origin: Vector3 =
Vector3.ZERO, protected_cell: bool = false, detail: bool = true) -> Material`.
Call once per material group, not once per frame or individual cell. Dry
materials share one shader resource but keep independent uniforms. The origin
must be the exported block's original world origin: procedural detail uses
source-world coordinates, so moving the preview origin does not move the
authored stone joints or asphalt patches.

Default `detail=true` returns the final dry `ShaderMaterial` port:

| Tile | Final Walk surface | sRGB base | Roughness | Original detail |
|---|---|---|---|---|
| 0 / 19 | asphalt | `#525b59` | 0.90 | filtered aggregate, wear, cracks, rotated repair patches |
| 8 | grass | `#748d68` | 0.95 | broad sod clumps, sparse soil, subtle relief |
| 9 | paving | `#c0bda7` | 0.89 | staggered 1.45 × 0.90 m limestone slabs and joints |
| 14 | sand | `#cfbd96` | 0.97 | filtered shallow ridges |

The source formulas, frequencies, antialiasing fades, roughness modulation and
derivative relief are preserved from `environment_surface_materials.mjs` dry
revision 4. The shader has no texture samplers, time update, extra pass,
geometry movement or collision effect. Colour uniforms use Godot's
`source_color` hint, with the original sRGB preset passed as `Color(hex)`;
internal soil/tint multipliers remain their original linear shader constants.

`create_base_material(surface, tile_id, protected_cell=false)` returns the
original native **intermediate** `StandardMaterial3D`. It consumes the actual
`MAT_CLAY_ASPHALT_CLEAN` descriptor for tile 0 only, preserving linear factors
with one `.linear_to_srgb()` conversion for the Godot colour property. It
retains source palette fallback, roughness, metallic and protected-key rules.
The final dry material keeps this intermediate resource as provenance metadata
`source_base_material`; it does not render an extra base pass.

`protected_cell=true` selects paving, matching `nativeTerrainKind` in the source
for the special protected key. The current 31 × 31 crop has **zero protected
cells**, so root does not need to split its MultiMeshes now. A future crop with
protected cells must group by both tile ID and protected status.

Water is explicitly outside this dry-surface task. Tile 16 returns the original
base water material, tagged with `migration_limit`: source depth absorption,
shore coverage and ripples are not migrated by this helper. It must not be
reported as finished water. Unknown tiles return null; unsupported asphalt
colour encodings are rejected rather than guessed.

Current source crop counts are 253 road, 114 sidewalk, 291 grass and 303 water
cells. These are exactly the source topology cells, including the canal and
the source's pending-host-snapshot status. This helper adds no lane markings,
kerbs, road-dressing geometry, grass blades or new roads. The coarse cell
outlines and incomplete surrounding map remain separate migration limitations.

## Helper validation

Run with the installed engine:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk --script res://scripts/test_preview_surface_materials.gd
```

**43 checks PASS**, including actual source preset/override lookup, source
asphalt linear roundtrip, actual roughness, palette fallback without double
conversion, distinct road/paving modes, source-origin preservation, independent
instance uniforms, protected/bridge semantics, unknown-tile rejection and
explicit incomplete-water metadata. Godot's headless shader parser exposes all
required uniforms with no shader/script errors in the final run. An initial
reserved shader-variable name was corrected before acceptance.

This is a parsed shader/resource contract test; the Compatibility GPU driver
has not compiled/rendered this shader in this task. Root still owns that live
check and the same-camera lighting comparison. Correct dry materials alone do
not prove the severe highlight clipping is fixed.

Source receipts used for the final port:

- `environment_surface_materials.mjs`: SHA-256
  `6598e763455f568902d678b24954e9f659fcd8dc804d41fc769270befe6be334`
- `environment_visuals.mjs`: SHA-256
  `0e2b59bfb8db2489383ac6177182139491bb1767fe9b460fabc65cc9930adfeb`
