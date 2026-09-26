# Независимый review standing locomotion — 26 сентября 2026

Автор: ограниченный subagent Artist21; runtime и существующие tests не изменялись.
Вердикт: source review не нашёл блокирующего дефекта в текущем **unarmed standing / flat-ground / 60 Hz preview**. Это не PASS полного переноса, не визуальная приёмка походки и не подтверждение пользовательского ввода.

## Проверенный срез

| Файл | SHA256 |
| --- | --- |
| `scripts/preview_locomotion.gd` | `395df02c3bfeaf3f701375c85d0d3ee0dd32a222b2300e45c658e35ff1ec9ddb` |
| `scripts/preview_player.gd` | `ea2f15d0fbf4d9c961d28383d94daa307ea377a3519a4fc7d5e2925e4dee4861` |
| `scripts/test_preview_locomotion.gd` | `c7c0e1c72474ee88dbad938d956ed8e85e3321ff6a05c5ffed1fe587900e11e5` |
| source `assets/maps/city_rebuild_v1/hero_walk.mjs` | `60ad2135010926f9fe1f18c62a89a877eb2547c708b723d7926f513043cc28c3` |

Прочитаны также `PREVIEW_LOCOMOTION_CONTRACT.md`, `test_preview_player.gd`, `project.godot`.

## Подтверждено по коду

- `preview_player.gd:233–235`: pose вызывается после `move_and_slide`, из `get_real_velocity` и `is_on_floor`. Удерживаемое направление при стене не становится самостоятельно источником gait. Существующий controller test проверяет это на реальной стене (`test_preview_player.gd:67–69`).
- `preview_locomotion.gd:43–53,108–118`: сохраняются исходные poses/quaternions; rotation записывается как rest × delta, а не накапливается. Bone translations/scales не меняются. Коэффициенты и противоположные стороны соответствуют source `hero_walk.mjs:47–67`. TAU wrap сохраняет непрерывность синуса.
- `preview_locomotion.gd:129–178`: extraction, inverse binds и convex hull выполняются только при bind. Update использует две cached foot transforms и 210 hull points, не заново читает surfaces. Linear support minimum convex hull математически сохраняет extrema исходных rigid foot points.
- `preview_locomotion.gd:95–105,181–189`: correction меняет только visual child; минимум считается в системе его parent, с текущим skeleton transform и foot global poses. Controller нормализует модель ниже этого child (`preview_player.gd:102–128`). Physics capsule/heading/body не записываются helper.
- `test_preview_locomotion.gd:108–138` независимо пересчитывает skin всех 734 rigid foot vertices, а не сравнивает cached hull с самим собой. Основной цикл также проверяет continuity, finite poses и неизменность translations/scales/root. Это полезная проверка flat-floor bounds, но не temporal foot planting/IK.
- Gait decay, точный zero threshold и reset возвращают исходную стойку. Horizontal speed в воздухе не начинает новый gait. При уже активном gait воздух плавно ослабляет его; scope честно исключает jump/dive pose.

## Конкретные ограничения / следующие проверки

1. **Distance claim ограничен dt ≤ 0.1 s.** `preview_locomotion.gd:72,79` умножает скорость на обрезанный dt. При внешнем вызове `delta=0.2`, speed=3.2 phase растёт на 0.736 rad вместо 1.472 rad реального перемещения. Source тоже clamp-ит smoothing dt, но имеет независимый `gaitDistance` путь (`hero_walk.mjs:52–54`). Текущие 60 Hz physics не нарушают это условие. Для пакета stalls/time-step назвать предел в контракте или использовать фактическое перемещение отдельно от smoothing; проверить 0.2 s sample. Это не текущий blocker preview и не разрешение писать альтернативный helper.
2. **Action authority ещё отсутствует.** `preview_player.gd:235` безусловно вызывает standing helper; его `_rotate` заменяет 11 bone rotations, `_restore_rest` восстанавливает все bones (`preview_locomotion.gd:108–118`). Сейчас combat/vehicle pose нет, поэтому конфликта нет. Перед добавлением этих действий требуется один владелец pose/явный режим; простое последовательное подключение второго helper будет перетирать позы. Это обязательный integration gate, а не утверждение о текущем боевом баге.
3. **Reset visual offset и transitional air/landing ещё не проверены независимо.** `test_preview_locomotion.gd:89,94,140–144` проверяет только bone poses через `_matches_rest`. Воздух начинается после reset, поэтому уход в воздух из активной gait и возврат к contact не проверены. Reset motion offset в source выглядит правильным, но текущие assertions не доказывают заявленное «offset exactly». Следующий bounded test должен проверить node position/contact offset, walk → air → land, большой delta и невалидный dt; существующий controller jump проверяет capsule arc, не boot presentation на переходе.

## Исполнение и стоимость

**NOT_RUN:** независимый subagent не запускал headless и не открывал GPU окно, чтобы не дублировать активную проверку root. Запрошено свободное headless окно через Artist21. Числа 23/17 PASS, support error <0.019 mm и CPU 17/44 µs в исходном контракте — результаты владельца, не повторный результат этого review.

По исходникам нет mesh extraction/hull creation в tick. Однако source review не измеряет затраты, whole-scene FPS, реальные визуальные движения, slopes/stairs/car seats/water или action blends. LIVE и полнота переноса остаются OPEN; только координатор интегрирует runtime и запускает общую игру.
