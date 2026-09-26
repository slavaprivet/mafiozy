# S00 — фактическая исходная точка Walk перед переносом

26 сентября 2026. Владелец интеграции — Координатор20. Это ограниченный
снимок исходников и карта ответственности, **не приёмка Godot и не полная
резервная копия игры или пользовательского прогресса**. Runtime не изменён,
Git index не изменён, публикации не было. S00 пока не закрыт: живой снимок
host и сопоставимый тяжёлый игровой маршрут ещё нужны.

## Две версии, которые нельзя смешивать

| Версия | Фактическое состояние |
| --- | --- |
| Git HEAD | `3612fa62f8d3bcb6888c7028ed0791fe0c928085` |
| Текущий `world.html` | SHA256 `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5` |
| Текущий `assets/maps/city_rebuild_v1/walk_preview.mjs` | SHA256 `e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47` |

Рабочее дерево содержит ранее согласованный service pilot и чужие изменения.
Перенос от одного HEAD потеряет этот WIP; перенос всего dirty tree без разбора
захватит непроверенные предложения. Архив сохраняет `base/` с байтами HEAD
и `working/` с текущими байтами только отобранных файлов. Для каждого есть
SHA256 исходных байтов и отдельно SHA256 после нормализации CRLF→LF.
Разница переводов строк не объявляется игровой правкой.

В захваченном статическом графе содержательные отличия от HEAD есть у World,
Walk, `npc_resident_commerce_source.js`, `hero_traversal_world.mjs` и
`vehicle_fleet_body.mjs`. Последние два сохраняются как существующий WIP,
а не автоматически одобренные изменения. `mercenary_vehicle_fire.mjs`
содержательного отличия от HEAD не имеет; новый gun candidate не применён.

## Архив и повторная проверка

Канонический каталог — `outputs/godot_s00_20260926_final/`:

- `source_snapshot.zip`: 6 339 500 байт; SHA256
  `509a6a4ffca16abe8b4dc0e309de775244f5865800c2e121e44ab0c4b2668daa`.
- `manifest.json`: 369 текущих файлов, 342 соответствующих файла HEAD,
  статусы пакетов, аппаратная исходная точка и ограничения.
- `static_dependencies.json`: 336 файлов статического source-графа,
  рёбра literal import/export/dynamic import и HTML script src.
- `source_symbols.json`: имена и найденные строки ключевых точек кода;
  это указатель, не вызов функций и не выгрузка игрового состояния.

Все **711 элементов ZIP** перечитаны, набор имён и SHA каждого совпали
с manifest. 17 внешних или неразрешённых статических ссылок оставлены явно:
Three 0.180/addons, CDN и некоторые относительные ссылки legacy renderer.
Граф является лексическим надмножеством (условные legacy/editor ветки тоже
встречаются), а не доказательством фактически исполненной Walk-зависимости.
Вычисляемые URL, загрузки через каталоги, модели, текстуры и текущий runtime
этим обходом не исчерпываются.

```powershell
python tools/godot/capture_s00.py --verify
# Новый снимок, только после проверки неизменного исходного контракта:
python tools/godot/capture_s00.py --out outputs/godot_s00_new_label
```

Скрипт использует только стандартную библиотеку Python и Git. Он не меняет
исходники/index, не применяет патчи, не перезаписывает существующий каталог,
проверяет известные SHA и повторно читает исходники перед записью архива.
Защита ограничивает обход 500 source-файлами/64 MiB и 8 MiB на файл.
Он не запускает игру, сервер, браузер или GPU. Старый
`outputs/godot_s00_20260926/` — промежуточный архив, не канонический результат.

Не включены секреты/окружение, БД, содержимое localStorage/sessionStorage,
профили/авторизация, пользовательские сохранения и полные GLB/текстуры.
`mafiozi_bot.py` и `npc_empire.py` представлены SHA и указателями символов;
их содержимое в ZIP не копируется. Архив сам по себе **не runnable build**:
даже сохранённые тесты требуют текущих ресурсов репозитория и Three vendor.

## Сохранённые пакеты и их реальная степень готовности

| Пакет | Зафиксировано | Статус переноса |
| --- | --- | --- |
| Service pilot | Checkpoint JSON/MD/patch, все 13 runtime-файлов и 3 applied-теста, общий native fixture | Runtime совпал с checkpoint. Применён локально; продавец/покупатель визуально и общий FPS ещё не приняты |
| Hospital return26 | Patch, builder, actual test, 22-case result, proposal | CPU-предложение; не применено. Нужен service physical roster и реальный native выход; LIVE не пройден |
| Window READY26 | Patch, отдельный candidate, manifest, endpoint/transition reports, handoff | **HOLD. Не применять**: переход головы через окно и Kingswell sill остаются дефектными |

Точные SHA256 патчей:

- Service checkpoint:
  `3647647744f851cf1f1b2c949fa867202164dfa13d160b311ff64857508423f6`.
  Это delta от HEAD, уже применённая к текущему Walk; повторно не накладывать.
- Hospital:
  `9382243e83fa9b28ca7466ebbb5b2ea718701d6d2a7bf925c92711c35b471002`.
- Gun HOLD:
  `193a2c42d53345e1945817f7d6a3fb5eced98a0755f5cfdd4c3261ea97112b5b`.

Обнаружено одно расхождение теста с service manifest:
`test_npc_service_applied23.mjs` сейчас
`3e4a06b8d8f09c620475b4bd6c5aedff687e0f3292395dd7604d4e4e11ba7d84`,
тогда как checkpoint ожидает
`91afc887175a2ff3566989a4bc243e97231541b1755a3dedbc83a2d84bd7e670`.
Это не только переводы строк. Текущий тест сохранён отдельно от исходного
checkpoint.patch; его новый PASS данным архивированием не подтверждался.
Все 13 runtime SHA и два остальных applied-теста совпали.

## Владельцы состояния: что переносится кроме renderer

| Система | Действующий источник/ключевые точки | Граница, которую нужно сохранить в Godot |
| --- | --- | --- |
| Запуск и режимы | `world.html`, `world_walk_host.mjs::mountWorldWalkHost` | Один world simulation/WS; host монтирует renderer, не создаёт второй AI |
| Карта исходного world | `world.html::buildMap` (6290), массивы/ID world | Итог после buildMap отличается от одной входной сетки; нужен host snapshot |
| Source simulation | `world.html::update` (40206), NPCS, полицейские/банды/боссы/questCars и отдельные коллекции | Полная membership/ID/lifecycle; visible presentation roster не заменяет source roster |
| Межслойный контракт | `world.html::Mafiozi3DBridge` (70652), `syncWalkPlayer` (70677), `getPlayerState`, `getWorldClock` | Координаты, locks, версии/receipts и разные часы; renderer не назначает себе серверные полномочия |
| Renderer и геометрия | `walk_preview.mjs::refresh/start`, `building_entry.mjs::createBuildingEntry`, floor/door/window/interior modules | Построенные интерьеры, двери, лестницы, коллизии и физические anchor должны переноситься вместе с внешними GLB |
| Герой | `hero_walk.mjs::createHeroWalker/loadHeroWalker`, posture/traversal/artist pose, world health adapter | Движение допускает геометрия Walk и source locks; HP/death/custody не выводятся из одной позы |
| NPC | `npc_population.mjs::createNpcPopulation`, native navigation/perception, source agenda/visit в World | Создание/cull визуальных тел не должно менять живое население или ownership; маршруты и занятия имеют source владельца |
| Машины | `vehicle_fleet.mjs::createVehicleFleet`, source questCars, world traffic presentation, logical vehicle binding | Локальный fleet и source транспорт различны; поза/renderer не второй владелец HP, водителя, места или маршрута |
| Личная банда | `mercenary_world.js::effect/MafioziMercenaries`, `mercenary_core`, catchup, vehicle bridge | ID, профессия, инвентарь, госпитализация, занятые места и безопасные точки; snapshot визуальных NPC неполон |
| HP/бой/инвентарь | Local preview: `_hurtLocal` (24890), world receipts. Authenticated: Python `get_authoritative_combat_state` (2922), `claim_authoritative_weapon_fire` (3919), `get_inventory` (2909) | Не подменять authenticated HP/расход патронов локальным счётчиком Godot; подтверждения/dedupe/life epoch нужны явно |
| Мировые банды/имущество | `mafiozi_bot.py::WorldSim` (16215), `_transfer_business_property` (27034), `create_custom_gang_db` (15767); `npc_empire.py` | Сохранение боссов/собственности/войн/доходов зависит от серверного state, не от сцены. Штаб — захваченное существующее здание |
| Сохранения | Browser local/session storage adapters + серверная persistence | Ключи и схемы можно изучать в source; реальные значения здесь не читались. Экспорт прогресса — отдельный этап с backup/restore и версией схемы |

Указатели строк относятся к текущим зафиксированным исходникам. SourceSymbols
может перечислять также вызовы символа; для изменения нужен просмотр самой
реализации. Часть правил зависит от preview/authenticated режима — один
общий «Godot владеет всем» контракт на этом этапе был бы неверным.

## Почему placement JSON не являются полной живой картой

Текущий `topology_for_placement.json` сам сообщает:

- `status: ISOLATED_WALK_TOPOLOGY_PENDING_HOST`;
- `pendingHostSnapshot: true`, `vehicleReady/gameplayReady/productionReady: false`;
- 200 строк × 180 столбцов; 4.1 мировых единицы на клетку;
- grid/masks используют `[row][column]`, полигоны/точки — `[column,row]`.

В `validation.notValidated` явно перечислены настоящие police tiles после
buildMap, размещённые коллизии зданий/декора, контроллер, радиусы поворота,
ID migration, server authority и live rendering. Это описание входного
топологического артефакта; последующие интеграции могут добавлять возможности,
но такой JSON сам по себе не доказывает их полноту.

Walk читает четыре revision-входа: topology, buildings placement, decor placement
и detention native sites. Затем модули добавляют/выводят terrain, railway,
procedural interiors, floor/door/window surfaces, native entry metadata,
collision bodies и source actors. Нужна инвентаризация результата построения
с ID, transform, ресурсом, provenance, collider/surface/entry и поколением
контента. Одни три placement-файла и визуальное сходство квартала недостаточны.

## Открытые проверки S00

1. Получить полный план Астра10: локально прочитана только переданная сводка,
   не все 16 этапов/36 групп тестов из исходного ZIP.
2. Согласовать полный разрешённый host snapshot после buildMap/Walk сборки;
   нельзя маркировать его `complete` по distance-capped NPC/traffic представлению.
3. Зафиксировать тяжёлый маршрут: камера, разрешение, настройки, население,
   транспорт, прогрев, сохранённый seed/сценарий и критерий повторения.
4. Измерить текущую игру и затем собранный Godot в одинаковом сценарии:
   frame p50/p95/p99, повторяемые stalls, CPU/GPU и память. CPU fixture PASS
   и render-only замер не заменяют игровой FPS.
5. Согласовать migration schema/authority и контракт переноса настоящего
   прогресса без открытия реальных профилей или БД в этом инвентаризационном шаге.

Сообщённая координатором аппаратура: i9-10900F, GTX 980 примерно 4 GiB VRAM,
RAM 17 113 399 296 байт (~15.94 GiB). Этим скриптом аппаратные характеристики
не перепроверялись. 1080p/60 FPS и p95≤16.7 мс — целевые требования плана,
**не результат замера**. Здесь выполнено только сохранение и проверка
целостности исходной точки; живой Godot/Walk прогон и GPU не запускались.
