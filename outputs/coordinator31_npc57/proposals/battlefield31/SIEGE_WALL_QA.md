# Active siege layers: acceptance, 18 October 2026

Base: exact `origin/main` `4d5d2507ea46b30afd1899bd6b6930af91129fe6` in the isolated `D:\MafioziCombat31\siege_wall_publish` worktree. Only `main.gd`, `catapult_prototype.gd`, two new city scripts and five battlefield QA fixtures are intended for this checkpoint. The Godot import also touched generated `.import` files; exclude all of them from the commit.

## Scope and fixed source

- `siege_wall_dressing.gd` SHA-256 `437DD398D65EEC217099F6206194B8E4A52BE8C84002FDFB0379EE0923BA7125`: four ladders at x ±21/±38 on the outer wall, 66 arrows, four spears, six dropped shields, six impact marks; three shadowless MultiMesh batches, 361 instances and no permanent collision bodies. A damaged ladder disappears and releases four temporary rigid planks. The catapult forwards a real stone impact before returning from its castle-damage branch.
- `castle_wall_defense24.gd` SHA-256 `341EE5B538F3628AA3E99074950CCBEDA72CCE89FA4FEECC8A432D1C1E177C5C`: ten shields on live south-wall merlons, five shadowless batches, 2040 triangles, no collision bodies. A shield is hidden when its own merlon is destroyed.
- The central gate and old stone approach remain free of permanent new colliders. Battlefield terrain, props, and player controls are unchanged.

## Native results

All runs used `tools/godot/test_scheduler.py`, Godot 4.7.2 from `LOCALAPPDATA/MafioziTools`, D: project/output paths, and preserved other Godot processes. Each listed clean run exited 0 with empty stderr.

| Check | Result | Evidence on D: |
| --- | --- | --- |
| Exact-main editor import | PASS | `D:\MafioziCombat31\battlefield_qa\run_wall_exact4d5d_import01` |
| Three capsule routes, center and both flanks | PASS, 1136 queries per route | `D:\MafioziCombat31\battlefield_qa\run_combined_routes01` |
| Geometry and road vegetation | PASS, 344 grass instances checked, none on road; 77 colliders, 68 covers | `D:\MafioziCombat31\battlefield_qa\run_combined_geometry01` |
| Actual catapult impact on an outer ladder | PASS, one group broke and four rigid splinters spawned | `D:\MafioziCombat31\battlefield_qa\run_combined_impact01` |
| Exact-main graphical castle blast + ladder damage | PASS, target merlon dies, its shield transform becomes hidden, ladder breaks and four splinters spawn | `D:\MafioziCombat31\battlefield_qa\run_wall_exact4d5d_combined_graphical01` |
| Exact-main early movement/spawn guard | PASS, player ran 32.08 m without being reset; no-input boot correction still worked | `D:\MafioziCombat31\battlefield_qa\run_wall_exact4d5d_guard01` |
| Integrated wall/decor images | PASS, ladders and parapet shields visible; central gate and road clear | `D:\MafioziCombat31\battlefield_qa\visual_wall_combined` |

The graphical damage fixture **must run with the graphical scheduler lane**. In headless Godot, `MultiMesh.get_instance_transform()` returned identity/origin zero even immediately after the fixture forced a nonidentity transform; therefore its headless readback produced a false FAIL. The raw receipts are retained at `run_wall_exact4d5d_combined01`, `02`, `03_epsilon`, `04_forced`, and `05_origin`. No production source change resulted. The exact source passed the graphical readback and damage assertion.

## Paired performance

Fixed cameras, three-second windows, exclusive clean perf lane, no other Godot processes. The wall-facing ABBA test uses local camera `(0,3,115)` looking at `(0,8,68)`; A hides both new layers and the battlefield, B shows all. The gate is loss ≤15% and field FPS ≥90.

| Resolution and case | A FPS | B FPS | Loss | Result | Evidence on D: |
| --- | ---: | ---: | ---: | --- | --- |
| 1280×720, published baseline | 155.617 | 153.197 | 1.555% | PASS | `run_wallface_perf_base1280` |
| 1280×720, both new layers | 155.438 | 152.501 | 1.890% | PASS | `run_wallface_perf_combined1280` |
| 1920×1080, both new layers | 100.475 | 98.898 | 1.569% | PASS | `run_wallface_perf_combined1920` |

The all-visible new scene is 0.455% slower than the published all-visible scene on the 1280 wall-facing view. Combined wall-facing draw calls rise from 1321 to 1335 when all visual layers show. The older three away-facing paired views also passed: gate 12.350%, field 8.376%, flank 10.073% loss at 1280×720, receipt `run_wall_perf_combined1280`.

These checks establish the exact latest-main import and functional behavior plus the candidate's clean visual performance. They do not constitute a long-duration combat soak.
