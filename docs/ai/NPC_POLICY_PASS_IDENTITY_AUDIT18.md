# Read-only native NPC / legacy policy audit

19 сентября 2026, после v2. Production не менялся. Проверка: `node test_npc_native_fast_path18_policy_audit.mjs`; данные `outputs/npc_policy_gate_audit18.json`.

## Конкретная новая ошибка: non-plan visit перезапускает поиск

`world.html::_maybePlanResidentBuildingVisit` использует два пути. Для `_civilianPlanEligible` есть `_civilianRouteTo`, сохраняющий stable callback в `npc._civilianRoutePass`. Для остальных разрешённых посетителей каждый вызов передаёт новый `(r,c)=>npcWaypointOk(npc,r,c)` в `_planNpcRouteTo(...,'building_entry')`. В `npc_native_directed_route_source.js` смена `search.pass!==passFn` правильно инвалидирует поиск. Вместе эти два контракта означают restart каждого продолжения non-plan маршрута. Кроме того, без `_civilianPlan.doorId` не сохраняется выбранная дверь между попытками.

Actual print-shop fixture, настоящий `_maybePlanResidentBuildingVisit`, неизменный старт/одна и та же дверь, 12 кадров. RNG фиксирован на допустимый вызов посещения, budget заменён на два checks для воспроизводимой приостановки (не performance benchmark):

| NPC | canVisit | planEligible | restarts | frontier expanded / nodes |
|---|---|---|---|---|
| resident_worker, arc worker | true | true | 0 | 22 / 42 |
| resident_bandit, arc bandit | true | false | 11 | 0 / 1 |
| world_person, arc worker | true | false | 11 | 0 / 1 |

Все остаются route-pending, но normal planned worker накапливает прогресс. Non-plan снова и снова начинает с нуля. Это не объясняет всех 288 обычных жителей: для масштаба проблемы нужен LIVE census `canVisit && !planEligible`, pending ages и restarts. Исправление должно сохранять выбранную дверь и стабильный callback для допустимой native non-plan поездки либо согласованно направлять такую ветку в общий native route adapter. Не отключать инвалидацию search.pass во всём A*.

## Legacy policy не даёт массового неизвестного veto в данном fixture

На native topology 200×180 проверены центры клеток внутри границ с полным физическим footprint .18source и exact self-sweep. Истинные исходные функции arena/lair/prison/pit извлечены из world; обычный fixture раньше заменял их false.

Из 22939 физически свободных dry centres 10699 имеют surface=land. Ordinary npcWaypointOk/body пропускает9295; 1404 отклонены существующей policy:

- arena24, r31..41/c61..71 вокруг исходного POI36,66;
- lair535, круг radius20 вокруг120,40;
- prison729, остров/intake/causeways;
- sand116 без `_allowBeach`; building visit их пропускает;
- необъяснённые другие land veto:0.

Все9295 доступных ordinary centres имеют tile8/9 (5193/4102); дополнительного spawn restriction по tile8/9/14 в этой выборке не найдено. Ни один центр из78 authored building instances не находится в arena/lair/prison policy области.

Часть policy gate выполняется перед native surface (`npcWaypointOk`, `npcPassable`, `npcPassableForSnitch`). Однако это сохранённые ограничения PVP/логова/тюрьмы, а не автоматически ошибка миграции. Убирать их без проверки игрового назначения нельзя. Native road запрещён обычной прогулке, но разрешён building-entry через npcPassableForSnitch — это действующий контракт.

## Ограничения

Counts относятся к текущему topology/static snapshot + одному живому GLB типографии, не к загруженному состоянию всей игры. Fixture не содержит всех runtime prison/railway/cars/doors, поэтому физически свободная область тюрьмы здесь особенно завышена. Координаторский LIVE не менялся; GPU вкладки не открывались. Source MAP здесь взят из native topology fixture — соответствие фактическому динамическому MAP в открытой игре дополнительно проверяет root. Изолированные coarse starts из v2 повторно не считались новой причиной.
