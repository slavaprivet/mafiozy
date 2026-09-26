# Moving vehicle exit: source tumble pose

27 сентября 2026. Новый `scripts/vehicle_visual/vehicle_exit_pose.gd` исполняет фактическую позу `hero_walk.mjs:tumblePose`, включая группировку и контакт **всей деформированной модели** с поверхностью. Не standing-spin, не capsule approximation. Тело/скорость/occupancy не меняет; main/player/transport остаются у root/Transport3.

## API для немедленной интеграции

```gdscript
var pose = VehicleExitPose.new()
pose.configure(player._pose_skeleton, player._pose_motion,
    player._locomotion._rest_poses, player._model_scale,
    player._pose_motion)
var sampled: Dictionary = pose.sample(actual_exit_progress, actual_rolls,
    current_floor_world_y, null, player._pose_epoch)
if sampled.get("valid", false):
    player._apply_selected_pose(sampled)
```

Последний configure argument — existing subtree с импортированными MeshInstance3D/skin. Передача `_pose_motion` охватывает существующую модель и не создаёт новых nodes. Configure вызывается один раз после model bind, вне активного кувырка. Он сохраняет canonical rest/parents, actual skin binds/vertices и source normalization frame. Это тот же hero GLB с 8338 vertices; unsupported rig/asset fail closed.

`sample(progress, rolls=1, floor=Callable(), root_frame=null, epoch=0)` возвращает привычные `valid`, `poses`, `visual_offset`, `visual_rotation`, плюс progress/rolls/authority_epoch/skin_height/floor_lift/floor_calls. Sample не пишет скелет. Root применяет результат существующим single pose writer. Default root frame — current `_pose_motion.get_parent().global_transform`, то есть source +Z visual root. После физического отделения source body root upright, yaw направлен по exit trajectory; sampler не добавляет yaw сам.

**Не сдвигать UniformModelScale дополнительно.** Source `scaled.position.y=-.65` уже свёрнут в возвращаемую `visual_offset`: `pivot_offset + rotation * (0,-.65,0)`. Благодаря этому один native motion transform даёт ту же геометрию, не изменяя root/model scale или bone translations. На progress=1 tuck→0 и целое число оборотов возвращает upright rest с полным skin grounding.

`floor(x_world,z_world) -> float` должен вернуть текущий world support Y. Root может передать physics ray provider с повторно используемым query, исключающим actor/vehicle RID и использующим фактические walking layers. Provider должен быть синхронным, finite и non-reentrant. **NaN/no hit → valid:false**, reason `floor-unavailable-or-outside-source-grid`; не подставляется выдуманный пол. Root сохраняет последнюю безопасную presentation и свою authority/physical handling до разрешения ground state. Отсутствующий Callable воспроизводит source `groundPose` только относительно plane body root; это не подтверждение контакта с неоднородной землёй.

## Source timeline и механика

`walk_preview.updateMovingExit`: сначала source door/release phase, затем `launchExitBody`, смена heading и `hero.tumblePose(0,rolls,{floorHeight})`. Далее каждый `stepExitBody` передаёт **свой** progress/rolls/trajectory root. `car_exit.mjs` задаёт release .55 с, tumble recovery 1.7 с, walk recovery .6 с. Tumble при |speed|>15/3.6 м/с; два оборота при |speed|>14 м/с, иначе один. Sampler не назначает скорость, время или число оборотов вместо provider и не тормозит машину.

Точная поза: tuck `1-smooth((p-.72)/.28)`, chest .95, thighs −1.9, shins 1.35, upperarms −1.3, forearms −1.1 радиан × tuck. Roll `TAU*rolls*smooth((p-.06)/.64)`. Original rest quaternion/scale/origin сохраняются. Source groundPose решает нижнюю точку actual skin; floor solve дополнительно поднимает presentation в мировом UP и переводит поправку в local root. Промежуточная поза низкая и сгруппированная, затем разгибается.

Повторён `vehicle_exit_surface.createExitPoseFloorSampler`: grid spacing .25 м, extent8, 17×17 lazy nodes /16×16 cells, floor каждого cell — максимум четырёх углов. Все current skin vertices учитываются. В отличие от convex-hull-only решения, внутренняя вершина над нелинейной ступенью не теряется. Выход skin за grid fail closed; source делал clamp и считал outside, native host не объявляет такой результат безопасным.

## Проверки

- `tools/godot/build_vehicle_exit_pose_oracle.mjs` напрямую исполняет неизменённые `hero.tumblePose`, `createExitPoseFloorSampler`, `launchExitBody/stepExitBody` на настоящем hero GLB.
- Immutable `scripts/tests/fixtures/vehicle_exit_pose_oracle.json`: 72 кадра — no-floor/flat/slope/step, 1/2 rolls, p=0/.06/.16/.3/.46/.64/.72/.85/1; source timeline speed8/22 м/с.
- `scripts/tests/test_vehicle_exit_pose.gd`: реальный импортированный player, actual skin bind data, native pose application, сохранение физического root, bone origins, nonfinite/bounded inputs и unavailable floor.
- Generated `outputs/coordinator21_npc_port/vehicle_exit_pose_result.txt`.

```powershell
node tools/godot/build_vehicle_exit_pose_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_vehicle_exit_pose.gd
```

Actual Godot 4.7.2 headless: **4409 checks PASS**, exit0, без SCRIPT ERROR. Max quaternion error 1.931e-7; combined pivot/ground offset error **0.00002134 м**, skin-height error **0.00002126 м**. Это float32 native skin vs JS double; допуск 0.00015 м. Source-floor scenarios требуют не более **36** actual provider calls за sample, общий предел289. Позиция CharacterBody остаётся неизменной.

## Оптимизация и оставшаяся стоимость

8338 imported vertices → 6673 exact unique bind/weight vertices, без simplification. 13 rigid bone groups трансформируются native PackedVector3Array операциями; 1682 weighted vertices вычисляются по настоящим весам. Floor aggregation exact: поскольку source floor constant внутри cell, достаточно минимального world Y всех actual vertices этого cell. Это устраняет тысячи повторных callback/cache вызовов; progress/поза не квантуются и не заменяются cached approximate animation.

Одинаковые 72 source scenarios до/после оптимизации:

| CPU work | Исходный exact per-vertex floor | Final exact cell minimum + native rigid batches |
|---|---:|---:|
| Full floor sample p50 | 6.129 мс | 2.986 мс |
| p95 | 9.512 мс | 3.457 мс |
| max | 11.905 мс | 3.830 мс |

Root-plane-only final p50 1.051 мс; configure 19.513 мс однократно. Cold/OS contention видны в хвостах; это headless CPU с дешёвыми математическими floor callbacks, **не 144 FPS/общая сцена**. Реальные physics rays root добавляют свою стоимость. Этот короткий 1.7-секундный full-skin burst может быть заметен при узком frame budget; root должен измерить живую интеграцию. Безопасный дальнейший путь — native implementation или отдельно доказанный planar-floor fast path. Упрощение до boot/capsule support, пропуск vertices на ступенях и округление progress здесь не применялись.

Dispose освобождает cached skin/rest arrays; не удаляет actor/model/shared resources. Публичные вызовы main-thread only, sample non-reentrant, ≤128 bones/20000 source vertices, rolls0…4. Root-owned физический swept exit, water/fall handoff и автомобильная инерция проверяются отдельно от этой presentation.
