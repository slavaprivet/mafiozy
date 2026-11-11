Review a Godot 4.7 castle masonry fix for correctness and regressions. Be concise and list only concrete issues.

Goal: close accidental large gaps in circular tower masonry and upper crowns without adding instances or reducing FPS. Intentional crenel openings must remain.

Changes in castle_site.gd:
- Circular tower tangential size is computed at the outer face: `2 * (radius + radial_depth/2) * tan(PI/around) * 1.025`.
- Tower visual transform uses `Basis.scaled_local(scale)` for every group beginning with `tower`; other groups keep `Basis.scaled(scale)`.
- Tower vertical visual size is multiplied by 1.005 and radial size by 0.995.
- Two crown courses use radial depths 0.72/0.62, tangential outer-face coverage *1.03, heights 0.40/0.36, centers 26.90/27.26.
- Crown random rotation jitter is disabled.
- Tower merlons keep their exact bottom support edge at y=27.0, but dimensions change from radial/tangential 0.92..0.98/0.66 to 0.76/0.994..1.058.
- Keep merlons widen along the wall from 1.75 to 2.35 while their center spacing remains 4m.
- Brick count remains 61,886; tower/crown/merlon counts remain 7056/288/72; chunks remain 343.

Validation already passed: new geometric/local-axis regression; visual pass2, pass2 support cascade, pass3, single-brick support, gate breach. Three graphical perf runs on GTX 980: courtyard 186.9-187.9 FPS, gate 157.5-158.2, whole 151.1-152.3, draw calls 1776, objects 2207. Close screenshots show continuous tower courses and intentional crenels.

Check specifically: local/world Basis scaling logic, outer chord formula, crown overlap, support/collision mismatch, excessive overlap/z-fighting, and whether any listed result is insufficient evidence.
