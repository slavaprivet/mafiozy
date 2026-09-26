# print_shop001: настоящий интерьер и две физические двери

26 сентября 2026. Пакет подготовил subagent `godot_city_import`; финальный получатель — **чистый Координатор21 `01a0df60-f834-7e23-a846-00b47c48e0cc`**. Координатора20 не будить. После этой передачи автор освобождает scope; новый scope только от21.

**Статус: source-generated geometry + headless Godot physics PASS, интеграции в main и LIVE ещё нет.** Пользовательскую release игру43332 и session9305 не трогал. GPU/новые приложения не запускал, Git не использовал. Main, project, player, старый block exporter и исходный Walk не изменены. Старый release сам не содержит новый интерьер: нужен отдельный согласованный экспорт после интеграции и LIVE.

## Файлы

- `tools/godot/export_preview_interior.py` — запускает настоящие Walk JS-генераторы на проверенном GLB, экспортирует их результат; `--check` сравнивает байты без перезаписи.
- `godot/mafiozi_walk/data/printshop_interior.json` — 1,922,988 bytes; SHA256 **`958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b`**.
- `godot/mafiozi_walk/scripts/preview_printshop_interior.gd` — самостоятельный Node3D adapter, без собственного input/UI/автоматического update.
- `godot/mafiozi_walk/scripts/test_preview_printshop_interior.gd` — реальный imported GLB + Godot physics + 100 циклов обеих дверей.
- `outputs/godot_printshop_interior_headless.json` и `.log` — свежие результаты, **843 checks PASS**; в логе нет SCRIPT/SHADER ERROR.

## Откуда взята геометрия

Не воссозданная generic room: exporter импортирует реальный `print_shop.ad7b8ef7e7e4.glb`, проверяет length и SHA256 **до записи**, и исполняет ту же цепочку, что actual Walk fixture:

1. `building_doors_glass.mjs::applyBuildingDoorsGlass`;
2. `building_window_integration.mjs::createWindowedBuildingEntry`;
3. оттуда `building_entry_profiles.mjs` (публичная дверь, CSG комнаты/проёма/подъёмного подхода), `building_room_profiles.mjs`, `building_storeys.mjs`, `building_storey_profiles.mjs`, `interior_spacious_layout.mjs`, `building_interior_design.mjs` и его мебель/двери/сейф;
4. `native_print_shop_service_station.mjs::createPrintShopServiceStation`: настоящая стойка, непрозрачная дверь склада и service anchors. Callback проверяет полный радиус0.738m у anchors и SAT пересечение стойки с исходными телами.

Всего 40 загруженных источников с bytes/SHA256 записаны в JSON `sources`. Node `v26.1.0`, Three `180`; путь Three по умолчанию `D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor`, меняется через `--three-vendor`. Это явная зависимость генератора, не runtime Godot. В JSON нет случайных UUID/времени создания.

Исходный профиль подтверждает **один высокий этаж**, отдельного второго этажа нет. Сохранены `print_hall`, `stockroom`, `manager_office`, IDs комнат, мебель, шкафы/печатные станки, существующий закрытый сейф и source-generated лестница на крышу. Склад имеет реальную стену, проём1.8m, непрозрачное полотно и ручки.

## Системы координат и геометрия

Сохраняются ID `REBUILD-VISUAL-print_shop-001`, GLB SHA `ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97`, source origin `[395.65,0,45.1]`, metresPerCell4.1, yaw90°, horizontalScale1.02, localOffsetX−0.13867319894612695. Godot не отражает Z.

- `overrides`: **22** реально изменённых CSG/материальных original meshes. Adapter заменяет их mesh resources внутри существующего импортированного здания. Исходные ресурсы не мутирует.
- `hideOriginalNames`: только `Burgundy_entry_door`. Её точная исходная геометрия перенесена под подвижный hinge; двойного видимого полотна нет.
- `meshes`: **41** generated mesh/MultiMesh group, 13,642 видимых generated triangles. Не создаёт второе здание.
- `geometry`:55 source geometry buffers, включая attrs/indices/groups. CCW Three/glTF индексы разворачиваются под Godot ArrayMesh CW, исходные normals сохраняются. Single-material BoxGeometry groups объединяются в одну surface, как их рисует Three.
- `materials`:30 исходных описаний. `colorLinear` и emissive переводятся в Godot sRGB property ровно один раз. Instance colors мебели/служебной двери остаются **linear**; MultiMesh.use_colors + vertex_color_use_as_albedo=true, vertex_color_is_srgb=false. Не возвращать белую мебель.
- Mesh `transform`, anchors и `staticBodies.polygonXZ/minY/maxY` в preview-root metres. У dynamic meshes transform относительно метрического hinge без масштаба; масштаб уже внесён в относительный mesh/collider transform.
- `rooms`/`floors` остаются в source storeys frame. Для преобразования использовать `frames.storeysToPreview`; есть также `entryToPreview`.

## Ровно какие коллизии заменить

Только `block.buildings[id == SOURCE_ID].collisionBodiesM` с **sourceIndex0,1,2**. Их conservative solid volumes заполняют будущую комнату. Остальные24 квартальных тела остаются.

Взамен модуль добавляет103 точных source static polygon extrusions,3 динамических тела (публичное полотно + полотно/ручки служебного),4 набора source floor/ramp/ceiling triangle faces. Сохраняются внешние остатки envelope, стены, перегородки, мебель и граница прохода. Удалять все тела по одному `source_id` **после attach нельзя**: у новых тел тот же ID. Различие новых — meta `interior_kind`.

Самый безопасный hook в `_add_asset`: после добавления существующего visual, **до создания трёх старых тел**, создать adapter и вызвать attach; при успехе пропустить только их цикл. При ошибке освободить adapter и оставить все старые тела. Adapter не удаляет чужую физику сам.

```gdscript
const PrintshopInterior = preload("res://scripts/preview_printshop_interior.gd")
# Один раз загрузить JSON и проверить, что parsed is Dictionary.
# В _add_asset после add_child(parent), _hide_helpers:
if str(record.id) == PrintshopInterior.SOURCE_ID:
    var interior := PrintshopInterior.new()
    add_child(interior) # identity transform; sibling здания на preview root
    if interior.attach_existing(visual, record, printshop_data):
        _printshop = interior
        return # не создавать только три старых envelope тела этого record
    push_warning("Printshop interior rejected: " + str(interior.errors))
    interior.queue_free()
# существующий цикл record.collisionBodiesM остаётся fallback
```

`attach_existing` проверяет sourceID/hash/исходный transform/origin, **фактический** global_transform visual, ровно3 envelope indices, уникальные имена мешей, наличие source meshes, геометрию/индексы/материалы/instances, повторное подключение. Подготовка ресурсов идёт перед мутацией original visual. На отказе перед source edits нет созданных узлов.

## API дверей и интеграция действия

- `nearest_action(actor_position)` → ближайшая **публичная** дверь или `{}`; label «Открыть дверь»/«Закрыть дверь», `opening` — текущий desired target, в том числе во время анимации. Root вводит её в общий приоритет E; модуль input не перехватывает.
- `request_door("public", open, actor_position, occupants)` → `{accepted, reason/open}`. Root передаёт фактического игрока и всех relevant occupants.
- `request_door("service", open, staff_position, occupants)` — **отдельный staff API**. Как в source, открытие только когда актёр пришёл к `anchor("doorInside")` в пределах0.25m. Это не разрешение на обслуживание/покупку. Публичная E-подсказка эту дверь не предлагает.
- `advance(delta, occupants)` вызывается root из physics tick. Source durations public0.65s/service0.6s, easing smoothstep, углы +90°/−90°. На простое ничего не создаёт.
- `occupants`: `[{"position": feet_Vector3, "radius": 0.36, "height": 1.9}, ...]`. NPC использовать его настоящий радиус. Максимум64; malformed/non-finite/missing body size => отказ движения. Root не должен исключать стоящего в створке игрока/NPC.
- Полный swept leaf + handles проверяются перед стартом и каждым шагом. Новое препятствие останавливает створку. Closed physics остаётся solid, open physics поворачивается вместе с видимым полотном; освобождения всего проёма отключением collider нет.
- `door_fraction(key)` для QA; `anchor(key)` в preview world; `restore_original()` перед отключением adapter возвращает original resources/visibility и удаляет только свои узлы. Root при выключении также должен вернуть три оригинальных envelope тела.

```gdscript
# Root physics tick; actual_player_position — feet position в preview world.
var occupants: Array = [{"position": actual_player_position,
                        "radius": actual_player_radius, "height": actual_player_height}]
_printshop.advance(delta, occupants)
# При одиночном E, после выбора action:
var action: Dictionary = _printshop.nearest_action(actual_player_position)
if not action.is_empty():
    _printshop.request_door(action.door,
        not bool(action.opening),
        actual_player_position, occupants)
```

Toggle использует desired target, не промежуточную fraction: быстрое повторное нажатие меняет направление ожидаемого действия. У NPC/магазина authority остаётся у будущего source bridge.

Основные anchors в preview metres:

| Anchor | X | Y | Z |
|---|---:|---:|---:|
| publicApproach | 7.4052 | 0 | 5.64945 |
| publicInside | 2.8152 | 0.39 | 5.64945 |
| spawn в складе | -3.86835 | 0.39 | 5.55510 |
| doorInside | -3.22570 | 0.39 | 5.47510 |
| doorOutside | 0.47430 | 0.39 | 5.47510 |
| work | 0.58430 | 0.39 | 3.75045 |
| customer | 3.06430 | 0.39 | 3.75045 |

## Проверки и границы

Команды:

```powershell
python tools/godot/export_preview_interior.py --check
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/test_preview_printshop_interior.gd
```

**843 checks PASS, 100 open/close cycles** обоих leafs: closed blocks capsule0.36m/1.9m, opened реально пропускает, closing возвращает коллизию, counter solid, четыре стены вне проёма solid, actual source floor под spawn/work/customer/inside; malformed data/другое здание/hash/placement/origin/повторный attach отклоняются; новый blocker останавливает закрытие; node count не растёт; restore работает; instance colors включены; rapid toggle корректно учитывает desired target.

Локальный headless CPU `advance` двух створок с одним actual-size occupant: p50 **0.025ms**, p95 **0.045ms**. Это диагностическая стоимость метода, **не игровой FPS и не GPU**. Циклы ждут Godot physics sync, их длительность нельзя выдавать за производительность игры. Общая сцена с новым интерьером LIVE ещё не измерена.

Остаётся UNKNOWN/вне пакета:

- Визуальная приёмка реального проёма, камеры, половой рампы, материалов и свет/экспозиция. В JSON `sourceLights` сохранены **две реальные source PointLight** позиции/colorLinear/intensity8/distance15.1/decay2. Модуль их не подменяет произвольным Godot energy: root должен решить physical-light unit mapping и проверить LIVE. Сейчас только внешнее освещение сцены.
- Два procedural interior finish shaders пока переданы с точными base linear material factors, **формулы фактуры ещё не перенесены**. Это явно отмечено sourceProceduralShader=true.
- Коммерция, покупка, зарплата/касса, seller spawn/death/60sec replacement/невидимость/route/authority — **не активированы**. Requirements из `astra21_SERVICE_STOCKROOM_REQUIREMENTS.md` не объявляются выполненными геометрией.
- Закрытая дверь кабинета/сейф сохранили исходную позу и коллизию; их actions/locks не придуманы. Source-generated roof ladder видима, её climbing action не включён.
- Нужны root LIVE прогулка с улицы через открытую дверь, return, obstruction, storeys/floor/камера и сопоставимый FPS. Не закрывать/не перезапускать пользовательскую release43332 ради каждого изменения.

S01 preset уже включает `data/*.json` и исключает `scripts/test_*`. Экспорт этого нового пакета автор **не запускал**: main пока его не подключает.
