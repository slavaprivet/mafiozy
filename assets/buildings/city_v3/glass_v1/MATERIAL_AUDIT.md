# GALLERIA reference-versus-game material audit

2026-09-07. Independent read of the approved contact sheet, original generator, GLB JSON, actual Three0.180 parsed materials/geometry, and shared renderer. Root owns live camera and final comparison; no screenshot equivalence is claimed here.

Update: architect's hash-pinned AO revision is now the default live candidate. It adds one standard embedded AO texture to8 opaque materials, preserving geometry/palette/glass settings. Thus the missing **baked local occlusion** part of the original audit is addressed by the candidate, while different tone mapping, world lighting and camera framing still require live comparison. Original remains available via `cityv3glassrevision=original`. See HANDOFF's frozen AO evidence.

## Confirmed mismatch and narrow repair

Generator `build_glass_buildings_smooth_clay_v1.py`, material helper: `blend_method="BLEND"`, `use_screen_refraction=True`, **`show_transparent_back=False`**. Exported smoky glass instead declares `doubleSided:true`. GLTFLoader consequently creates a DoubleSide alpha-blend material, which Three normally draws in back/front transparent passes. That is not the source's front-only transparent surface policy. Runtime now restores **FrontSide + forceSinglePass**, only on `Smoky teal architectural glass`. Opaque materials remain authored. GLB unchanged.

The game's environment is a bright blue/cream procedural cubemap, scene intensity roughly0.82 by day; imported glass previously inherited material envMapIntensity1. This pushes sky reflections strongly into small teal panes. A glass-only **envMapIntensity0.35** calibration candidate is applied. Unlike the sidedness correction, the exact0.35 is a visual calibration choice and must be judged in the live reference comparison, not called a mathematical proof of equivalence.

## Things that were not broken

- Authored baseColor linear[.025,.15,.17], opacity.42, roughness.17 and metalness.08 survive parsing exactly and are unchanged by the narrow repair.
- Source never assigns Principled transmission. GLB correctly contains no KHR transmission extension. Adding arbitrary transmission is not restoration of a lost source setting.
- Actual parsed normals exist and are normalized across every mesh. No runtime recomputeVertexNormals/flatShading replacement is applied to GALLERIA.
- All LOD roots share identity transforms and only one is visible. LOD0 has150 mesh nodes; default full-scale dimensions13.5×12.2×11.24m. No .68 shrink or catalogue offset.
- Shared facade daytime material arrays do not include GALLERIA's imported materials. They are not recolored by the generic facade grading loop. The occlusion system can temporarily adjust opacity while the building blocks the player, as with other buildings; this must be checked with player in front for reference comparison.

## Larger rendering differences still present

Approved proof uses Blender EEVEE GTAO factor1.35/distance5, soft shadows, SSR, Filmic / Medium High Contrast / exposure1. The game uses ACES exposure≈1.32 at noon, HemisphereLight≈2.5 plus DirectionalLight≈3.5, blue cubemap and distance fog; there is contact shadow but no corresponding building GTAO pass or baked AO map. Therefore recesses/cornices/interior backgrounds cannot yet have identical local contrast even with identical asset bytes. Its low screen-pixel height versus the studio proof also reduces visible microdetail. These are distinct from missing geometry and should not be solved by painting material colors arbitrarily or enlarging only this building without site/scale review.

## Evidence and next live check

`test_runtime.mjs` tests actual GLTFLoader materials, authored normals, original hash, bounds, LOD and repaired transparent policy. `test_host.mjs` covers host safety and door correction. Both pass. New `threePreview.dataset.cityV3GlassMaterialAudit` reports actual current material properties, activeLOD, scale, exposure and environment intensity during the game telemetry update. Root should compare front view with no occlusion, LOD0, known noon/night, and similar on-screen building height. Do not mark reference parity PASS until those rendered frames have been reviewed.
