# Original wall support — 30 September

Inspected all four `marks04pack` PNG and JSON receipts. Close mark is hidden by the lower window geometry; the far mark reads as a tiny bright ring on a dark facade detail. Neither is a fair plain-surface art comparison.

Read-only native GLB triangle diagnostic (`probe_wall_mesh.gd`, 0.72 seconds against 23d-final, no main/world actors) confirms:

| Actual contact | Rendered surface offset from physical envelope | Mark consequence with unchanged +4mm source offset |
|---|---:|---|
| Close `(24.855936,1.545862,-29.92659)` | +16.57mm toward camera | Mark behind actual trim by 12.57mm |
| Far `(24.85594,1.199827,-29.92659)` | −16.69mm | Mark floats about 20.69mm ahead of the actual mesh |

The authored collision method is explicitly `conservative_visual_envelope_minus_public_approach_exterior_only`. Collision and damage were NOT changed. This diagnostic does not authorize projecting damage contacts to decorative meshes.

## Better original fixture

Run `capture_open_wall_marks.gd` instead of `capture_wall_marks.gd`, with both sibling base harnesses and `wall_mesh_support.gd` present. Same command line, 4PNG/2 real AK shots. No fake hits, scale, geometry, mark position or lifetime changes.

Original building013 facade: physical point `(22.47031,2.2,-2.85625)`, outward normal `+X`. Mesh and collider planes coincide at the selected original surface. Native viewport mouse input compensates actual shoulder offset; the actual ray may land within25cm of the nominal anchor, but its OWN surrounding26cm patch is validated separately. This tolerance does not bypass mesh support.

Nine original mesh triangle rays validate a26cm clear patch before the real shot and again around the actual impact. Any decorative geometry more than3mm ahead of the physical plane, or support recessed more than2cm, fails. After the5° reticle offset the camera-to-mark ray is also checked against original building triangles. Tests do not hide the hero or alter geometry. GPU still must judge the surface's material and appearance.

Actual full-scene headless input preflight: **18PASS in2.91s**, source floor/capsule supported; camera distances4.49257/9.99288m, player2.56952/7.33739m. Receipt `open_wall_fixture_preflight/RESULT.json`. No GPU or real-shot acceptance claimed by this preflight. Both original23c and current23d default orbit lengths are compatible because the fixture uses production wheel input to3m and never asserts the initial distance.

Other effects harness metadata/assertions updated from obsolete4.8m to current source5.119570294468082m (`Vector3(3,1.1,4).length()`). Old baseline runs of the generic effects harness need their original initial-distance contract; the new open-wall harness avoids this assertion entirely.

## Why current art can still look like a ring

The current procedural rim has outer radius35mm and inner radius approximately17mm before the unchanged0.72 scale. Thus the bevel occupies roughly76% of the disk area; removing2–3 of18 angular segments still leaves a mostly continuous annulus. The outer contour only varies14%, which is below one pixel in the distant6.56px view. Those parameters can explain the button silhouette, but the close PNG was occluded, so no new art patch has been made. Judge the unobstructed close image first; if the ring persists, reduce continuous rim coverage and increase angular asymmetry within the SAME maximum radius rather than enlarge the mark.
