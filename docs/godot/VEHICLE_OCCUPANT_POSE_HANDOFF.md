# Source vehicle occupant pose — native Skeleton3D handoff

27 сентября 2026. Реализованы `createHeroWalker.vehiclePose` и фактический `createArtistVehicle.poseOccupant`, включая руки на руле/двери и recline. Новый sampler возвращает формат существующего `_apply_selected_pose`; main/player/exporter не менялись. Это pose presentation, не разрешение посадки, spawn или физическое перемещение тела.

## Файлы и проверка

- `godot/mafiozi_walk/scripts/vehicle_visual/vehicle_occupant_pose.gd` (+ `.uid`).
- `godot/mafiozi_walk/scripts/tests/test_vehicle_occupant_pose.gd` (+ `.uid`).
- `tools/godot/build_vehicle_pose_oracle.mjs` — запускает **неизменённые** исходные JS factories на настоящих hero/compact_sedan GLB.
- `godot/mafiozi_walk/scripts/tests/fixtures/vehicle_occupant_pose_oracle.json` — 56 последовательных source кадров для четырёх actual seats.
- `outputs/coordinator21_npc_port/vehicle_pose_headless_result.txt` — generated CPU report.

```powershell
node tools/godot/build_vehicle_pose_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_vehicle_occupant_pose.gd
```

Generator определяет repo root от `import.meta.url`; Three vendor — `MAFIOZI_THREE_VENDOR` или существующий `D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor`. Он импортирует actual RoundedBoxGeometry из существующего QA helper и actual `car_entry.entryPose`, без переписывания production JS. Oracle записывает input transitions, actual seats/recline, local bone rotations/positions/scales, pivot/head state и SHA исходников.

**Actual Godot 4.7.2 headless: 3371 checks PASS**, exit 0, без SCRIPT ERROR. Используется реально импортированный player skeleton и canonical rest из существующего locomotion bind. Max quaternion component-distance до JS **3.083e-6**, hip pivot **4.215e-8 м**, head-yaw difference **0**. Origin/scale всех костей сохраняются. Source numerical tolerance — quaternion 0.0003, pivot 0.00005 м, фактические ошибки существенно ниже.

## Подключение root

Один раз, после имеющегося player model/locomotion bind:

```gdscript
var pose = VehicleOccupantPose.new()
var ready: bool = pose.configure(
    player._pose_skeleton, player._pose_motion,
    player._locomotion._rest_poses, player._model_scale)
```

`canonical_rest` должен быть сохранённым bind/rest массивом, **не позой предыдущего кадра**. Configure запоминает parent-first skeleton (до 128 bones), source scale, skeleton-to-motion frame и относительные rest ориентации кистей. Требуются фактические chest/neck/head, thighs/shins/feet, upperarms/forearms/hands и hand sockets. Никаких guessed bone names/standing fallback при ошибке.

На каждом кадре уже разрешённой source посадки/поездки:

```gdscript
var seat := {"id": actual_seat_id, "can_drive": source_can_drive,
             "side": source_side, "recline": actual_profile_recline}
var selected: Dictionary = pose.sample(seat, options, null, occupant_binding_epoch)
if selected.get("valid", false):
    player._apply_selected_pose(selected)
```

Root заранее выбирает существующий `set_preview_pose_authority(...)`. Только **один** владелец применяет pose в кадре. Можно вместо player writer использовать `pose.apply(selected)`, но не оба. `apply` валидирует весь output до записи; старый epoch или умерший rig/motion отвергается.

`options` соответствует source `poseOccupant`:

| Поле | Контракт |
|---|---|
| `fold`, `reach` | 0…1, defaults 1/0 |
| `pose` | Настоящий `transition.pose`: innerLeg/outerLeg/duck/handReach/closeReach и phase |
| `side` | Сторона входа из transition, +1 left / −1 right |
| `dt`, `steer` | Native seconds / source steering; dt ограничен .1 с |
| `recline`, `reclineBlend` | Override/доля наклона; default actual seat profile / fold |
| `gripBlend` | Source continuous blend; отсутствующее поле сохраняет source threshold fold>.88 |
| `steering_left`, `steering_right` | **Мировые Vector3** настоящих точек вращающегося руля |
| `doorGrip`, `doorGripBlend` | Мировая точка реальной door handle и её source blend |
| `steeringGripAssignment` | Source explicit `direct`/`crossed`, если нужен до cached assignment |

`pose` flatten происходит сначала, верхние options затем перекрывают его, как в source spread. `can_drive` всегда берётся из actual seat, не из произвольного input.driver. Actual compact_sedan factory задаёт **recline=0.8**, не старый guessed fallback .55. Если exporter ещё не содержит recline/steering grips, root должен добавить фактические данные factory в своём scope. Модуль не выдумывает wheel/door anchors. При отсутствии steering points используется **исходная** driver fallback arm pose; это не доказательство рук на руле.

По умолчанию world points переводятся относительно `player._pose_motion.get_parent().global_transform`: это source **+Z visual root**, с реальным текущим yaw/placement. Godot vehicle forward −Z уже конвертируется владельцем vehicle visual; не применяйте вторую произвольную ось/знак внутри pose. Можно явно передать третий аргумент `root_frame: Transform3D`; oracle использует identity и переводит actual factory grips в тот же hero-root frame.

Epoch обозначает жизнь привязки actor↔vehicle. Он сбрасывает head smoothing и cache grip assignment; нельзя менять его каждый кадр. Чтобы воспроизвести source cache между переходами в той же машине, сохраняйте epoch и экземпляр sampler; новая машина/новая actor life требует нового epoch или configure. Source factory хранит occupant cache per vehicle/hero; этот sampler принадлежит одной такой binding. `reset(epoch)`/`dispose()` не меняют положение тела и не удаляют чужие resources.

## Перенесённое поведение

Hero stage: отдельные inner/outer legs по стороне входа, chest duck/door reach, counter-pitch neck/head, steering head-yaw smoothing, разные driver и passenger arm/finger-parent chain poses. Quaternion composition сохраняет исходный Three XYZ порядок, local rest orientation, translation и scale.

Vehicle stage: tilt вокруг source cached midpoint thighs; world ориентации thighs/head сохраняются после поворота visual pivot. Passenger shoulders дополнительно разводятся после fold .7. Driver grips преобразуются через inverse recline до IK; nearest direct/cross mapping кешируется для continuous blend. Дверная кисть тянется к настоящей ручке после arm pose. Двухкостный IK повторяет source reachPalm/pointBone/worldRotation, использует actual segment lengths и scaled wrist socket offset; не растягивает кости или skin.

Source нюанс сохранён: при continuous `gripBlend` factory вызывает vehiclePose сначала для fallback palms, затем для final IK, поэтому head smoothing тоже выполняется дважды. Oracle проверяет именно фактический порядок, а не идеализированный один update. Neutral/full seated и entry p=0/.12/.3/.42/.6/.78/.9/1 взяты из actual `entryPose`; для всех четырёх seats дополнительно проверены gripBlend .25/.5/1, steer .8 и door reach.

## Стоимость и границы

56 разных source poses: sample p50/p95/max **0.068 / 0.133 / 0.204 мс**. Actual fully seated driver с IK, 100 прогревочных +500 measured sample+apply: **0.140 / 0.205 / 0.334 мс**. Нет per-frame mesh/skin vertex сканирования, GLB чтения, NavigationAgent или поиска по сцене; FK работает на bounded cached bone arrays. Sample не пишет живой rig; apply — только poses и visual pivot. Это headless CPU, не FPS полной сцены и не LIVE проверка посадки в root машине.

Fail-closed проверены missing seat, NaN inputs, malformed transition/root frame, nonfinite grips, oversized recline, invalid output, stale epoch и disposed instance. Numeric API намеренно typed/finite: source JS coercion строк/null не является native host contract. Providers здесь отсутствуют; все точки передаёт root. Нужны source authority удержания E/door/seat occupancy, правильная motion phase/root placement, physical capsule policy и единый pose owner — эти механики остаются у владельца integration.

Source SHA256:

- `hero_walk.mjs`: `60ad2135010926f9fe1f18c62a89a877eb2547c708b723d7926f513043cc28c3`.
- `vehicle_fleet_models.mjs`: `5dcec7102fc425c7828239ad5de10d4feb29ff7216610fc842333894f811545c`.
- `car_entry.mjs`: `342a3f959cd7d82bfa5759f1706d6471bc32998fdb49be79361a2556ab3245b6`.
- Hero GLB: `8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00`.
- Compact sedan GLB: `08cf5677dec9ebdbbca329610be9e210e91185f976d3cdc307f87ff7345233f5`.
