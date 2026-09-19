# NPC: проверка гипотезы другой сетки world / Walk

19 сентября 2026. Только read-only аудит и диагностический тест. Production не менялся в этом этапе.

## Подтверждена ошибка дискретизации маршрутов

Текущий native A* в `npc_native_directed_route_source.js` делает шаги к центрам соседних целых source клеток: шаг 1 = 4.1 м. Начальная точка может быть произвольной. Все четыре соединения с такими центрами иногда заблокированы, хотя реальный физический путь существует.

`node test_npc_native_fast_path18_grid_audit.mjs --scan` воспроизводит два внешних старта на actual GLB/city geometry. Текущий production planner, включая новый direct probe, возвращает false и expanded=1:

| Здание | Source start r,c | Native door r,c | Диагностический шаг .25: expanded / nodes |
|---|---|---|---|
| print_shop | 4.990913843951179, 97.94314630350254 | 12.377913843951179, 98.30614630350254 | 72 / 109 |
| hospital | 6.469984627970292, 165.137 | 9.356984627970292, 164 | 19 / 31 |

Диагностический шаг .25 source (1.025 м) находит путь до настоящего входа. Используются те же `_npcPathPassable`, полный footprint .18 source, те же вода/callback/dynamic vehicle и continuous native sweep. Размер NPC НЕ уменьшен. Сегменты повторно проверены после нового `beginFrame`, NPC не перемещается тестом. Полные пути: `outputs/npc_grid_resolution_scan18.json`.

Это конкретный false-negative coarse lattice, а не просто предположение о масштабе. Он может оставлять часть жителей стоять, но частота таких стартов в LIVE ещё не измерена. Fine planner диагностический, не внедрён: глобально дробить всю сетку без bounded budget нельзя, число узлов растёт.

## Что не подтвердилось

1. Простая ошибка единиц / origin не найдена. `walk_preview.mjs:191` задаёт M=4.1; создание population `:473` передаёт M без origin override. `npc_population.mjs:27` переводит x=(c-originC)*worldScale, z=(r-originR)*worldScale; defaults origin=0. `npc_native_navigation.mjs:32` использует x=c*worldScale,z=r*worldScale. Обратный resident access `npc_resident_building_access.mjs:16` возвращает r=outside.z/M,c=outside.x/M. Регистрация navigation и traffic resolver идёт в `walk_preview.mjs:458` и `:466`.
2. `_residentBuildingDoors` в world для активного Walk возвращает только native resident-access list, не legacy door coordinates. Ссылка: `world.html` функция `_residentBuildingDoors` (около 9562).
3. CPU snapshot актуален по данным текущего кода на диске. `outputs/roads_logical_20260912/integration_candidate_snapshot.json` создан 2026-09-19T17:05:49.189Z. Все 78 building+detention instance records полностью равны текущим `buildings_placement.v1.json` + `detention_native_sites.v1.json`; authored decor также равен `decor_placement.v1.json`. Walk загружает именно эти файлы (`walk_preview.mjs:1320`). Свежий пересчёт `buildExplorationDecorPlan` + `buildEnvironmentVisualPlans` показал semantic equality decor/road/parking (исключены только *Ms timing fields): 2296 / 545 / 57 коллайдеров соответственно. Это не доказывает, что текущая открытая вкладка уже перезагружена с последними файлами.
4. Предыдущие 12 отказов из радиального набора print/hospital не были доказательством coarse lattice. Все starts находились внутри закрытого интерьера (containsInterior=true). Диагностическая .25 сетка тоже не нашла выход. Результат сохранён в `outputs/npc_grid_resolution_audit18.json`, обычный запуск теста без `--scan`.

## Важное различие размеров, без самостоятельной правки

World `_npcBodyPassable` и `npc_swept_footprint.mjs` используют квадрат с half-width .18 source = .738 м, ширина 1.476 м. Hero canWalk/rail/traversal работает с иным footprint около .36 м radius. Это ограничивает NPC в проходах, где герой помещается, но приведённые два repro решаются БЕЗ уменьшения размеров. Менять footprint отдельно без согласования сейчас не нужно.

## Пределы

GPU вкладки не открывались. Общая сцена/FPS и активная публикация не проверены. Fixture содержит статические записи остальных зданий, живой GLB одного выбранного здания и одну actual car; runtime railway, остальные stream cars, изменения игроком среды и прочие активные двери в нём не воспроизводятся. Доказательство относится к указанным физическим местам и текущим файлам, не ко всем NPC и не ко всему состоянию LIVE.
