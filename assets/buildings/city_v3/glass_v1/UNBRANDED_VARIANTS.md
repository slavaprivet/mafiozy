# Unbranded pavilion: live candidate and reusable size presets

The current AO revision hides the separate `Small_Galleria_Sign` text mesh.
There is no backing board. Source GLB bytes, AO, materials, geometry, entrance
sockets, placed scale 1 and collision contract remain unchanged. LOD0 has 149
visible meshes; LOD1/2 have 2/1 and no lettering. Explicit `original` rollback
retains the authored sign and 150 LOD0 meshes. Gameplay label is now
«Стеклянный павильон».

`GLASS_VISUAL_PRESETS` exports frozen candidate data, not map instances.
No compact copies have been placed. Every future instance needs its own safe
parcel, door approaches and collision contract. Uniform shrinking is not a
substitute for that preflight.

| Preset | Scale | Overall W×H×D, m | Clear public lane*, m | Public height, m | Service leaf W×H, m |
|---|---:|---|---:|---:|---|
| standard | 1 | 13.5×12.2×11.24 | 1.375 | 3.25 | 1.55×2.8 |
| compact | .85 | 11.475×10.37×9.554 | 1.16875 | 2.7625 | 1.3175×2.38 |
| small | .72 | 9.72×8.784×8.0928 | .99 | 2.34 | 1.116×2.016 |

*Each of the two lanes, between the outer and middle frame posts. The actual
Three mesh bounds independently verify the 1.375m lane, 1.405m public glass
leaf and 1.55m service leaf at scale 1. These are geometric measurements, not
a claim of live navigation acceptance for unplaced variants.

Tests pass with the embedded 2048px AO texture genuinely decoded, including
sign absence under all three active LODs and return to LOD0, original rollback,
149-mesh exact receipt, Russian interaction label and unchanged map contract.
Root must still check the actual rendered frame after reload.
