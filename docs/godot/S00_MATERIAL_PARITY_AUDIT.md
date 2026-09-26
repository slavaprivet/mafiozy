# S00 material audit, 26 September 2026

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

The source asphalt descriptor is also a small, separate parity discrepancy:
Walk's `terrain()` overrides tile 0 with `MAT_CLAY_ASPHALT_CLEAN`, linear factor
`(0.105,0.115,0.12)`, roughness approximately 0.8. Current Godot line 84 always
uses palette `#525a5a`, whose linear value is `(0.0844,0.1022,0.1022)`, and line
85 uses roughness 0.9. `block.json` already carries the actual descriptor.
For parity, a future root patch can assign
`Color(0.105,0.115,0.12).linear_to_srgb()` to `albedo_color` and use descriptor
roughness. The existing fallback hex must remain direct `Color(hex)`. This
small difference cannot explain the all-white pavement by itself.

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
