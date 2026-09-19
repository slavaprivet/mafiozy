# Инкрементальный индекс коллизий зданий

13 сентября 2026. По разрешению Координатора17 реализован вариант из `BUILDING_COLLISION_INCREMENTAL_INDEX_AUDIT_20260913.md`. Новый индекс подключён в `walk_preview.mjs` только в согласованных местах. Коллизии, анимационные кадры и существующие narrowphase-проверки не сокращались.

## Что изменилось

`incremental_walk_collision_index.mjs` хранит отдельные вклады внешних тел и каждой entry в пространственные ячейки. Новая версия массива одной двери/сейфа пересобирает только группу этого здания; старые и новые ячейки сразу инвалидируются. Кандидаты по-прежнему идут в порядке внешние тела → `buildingEntries` → исходный порядок тела, с сохранением повторяющихся ссылок. Высоты, source references, дверь/этаж/укрытие и другие поля тела не копируются и не переопределяются.

Все активные entry обновляются синхронно в каждом кадре до движения. `needsUpdate` и identity кешей остались контрактом версий; idle entry не пересчитываются. При удалении или перестановке entry используются объектные ключи, включая замену при прежней длине списка. Индекс остаётся вызываемой функцией `(c,r)`, поэтому NPC, sight, traversal и canWalk получили прежнюю форму API.

Scoped hooks в `walk_preview.mjs`:

- `updateBuildingEntries`: новая фабрика и `updateWalkEntryCollisionGroups`; глобального `.flat()` на анимационном кадре больше нет.
- Fence `onCollisionChange`: `force:true` после splice/push внешних тел. Отдельная автомобильная коллизия обновляется прежним кодом.
- `coverBodies.valid`: точный membership с подсчётом ссылок; удалённый collider больше не является действующим укрытием.
- `initCoverQa.sources`: общий список материализуется лениво при запросе QA.
- `clearContent`: очищаются группы, ячейки, membership и кеши. Статический `buildingSampleIndex` не изменён.

В helper доступны `stats` и `resetCounters()`: реальные visits/replacements, перестройки кешей ячеек, membership и размер групп. Они использованы CPU-аудитом; новых обходов scene graph или runtime renderer нет.

При `perfqa=1` `document.body.dataset.walkCollisionIndex` публикует эти счётчики максимум раз в секунду. `dirtyGroups` — число замен групп за интервал, а не число разных зданий; `verticesVisitedDelta`, `bodiesVisitedDelta` и `queryCacheBuildsDelta` сохраняют работу короткой анимации между замерами. `counterWindow='generation'` отличает первую выборку/перезагрузку. В обычной игре диагностический объект отсутствует: проверка 120 кадров дала 0 вызовов diagnostic timer, 0 чтений stats и 0 записей DOM. Два отдельных теста диагностического hook PASS.

## Фактическая проверка

Fixture создан из текущих GLB с проверкой SHA256, настоящим `createWindowedBuildingEntry`, `applyBuildingDoorsGlass`, актуальными размерами/этажами/мебелью. Текстуры заменены CPU placeholders; WebGLRenderer не создавался.

- 78 зданий: **17 086** entry bodies, из них 16 654 у 75 обычных зданий и 432 у трёх изоляторов.
- **3061** фактическое внешнее тело из final worker decor/road/parking. Итого **20 147** тел, **1883** пространственные ячейки.
- **256** шагов настоящих внешней двери, комнатной двери, сейфа и пяти одновременных анимаций в разных entry. Сейфы получили локальный confirmed-state fixture; никаких сетевых запросов или игровых экономических действий.
- **482 048** запросов ко всем занятым ячейкам, **5 685 808** сравнений ссылок/порядка кандидатов, **1518** запросов настоящего `createNpcNativePerception`: **0 расхождений** со старой полной перестройкой.
- После завершения анимации: **0** перебранных полигонов/замен групп. Замены исходных массивов по identity подтверждены на активных и неподвижных кадрах.
- 8 новых unit-тестов PASS: ordered duplicates/этажи/границы/вырожденные полигоны, перенос между ячейками, force/splice/revision, membership/удаление, переупорядочивание без геометрического обхода, многократные animation updates, смена entry/reload и фактические NPC adapters. Ещё 2 существующих теста native navigation/perception PASS. Синтаксис walk проверен.

## Сопоставимый CPU-замер

Один и тот же загруженный набор настоящих collider versions и запросов. До — старый цикл версии + общий `.flat()`/индекс; после — новый production entry updater с группами. Четыре чередующиеся пары, первая прогревочная; в таблице три измеряемые пары. Геометрия дверей и GLB construction общие для вариантов, подготовлены перед replay и в эти числа не включены.

| Сценарий | p50 до → после, мс | p95 до → после, мс |
|---|---:|---:|
| Одна внешняя дверь, башня002 | 3,313 → 0,215 | 5,369 → 0,669 |
| Одна комнатная дверь, башня002 | 3,220 → 0,179 | 5,019 → 0,266 |
| Один сейф, strip_club003 | 3,472 → 0,097 | 5,650 → 0,168 |
| Пять одновременных анимаций | 3,936 → 0,582 | 7,013 → 1,356 |

Для внешней двери за 64 шага старый путь посетил бы 785 733 тела; новый измеренный счётчик — 32 565. Для сейфа: 1 027 497 → 14 382. Для пяти одновременно: 1 027 497 → 104 571. В каждом replay `allBodiesBuilds=0`: debug flat-копия не вернулась в hot loop.

Дополнительная структура хранит ссылки на тела: 20 147 membership references и примерно 22 210 групповых bucket references плюс кешы затронутых ячеек. Дубликатов полигональной геометрии/mesh/material не создаётся. Это количественный учёт структуры, не замер heap bytes.

Артефакты: `outputs/entry_collision_index_20260913/actual_collision_index_report.json`, `actual_collision_fixture.json`. Fixture сохраняет таблицу идентичностей тел, версии групп и все кадры для воспроизведения. Source manifest и input SHA стабильны; вход — final integrated snapshot SHA256 `756f4fb564e2ff81bfbb2dd00139a6add95c1319a3e4ca61a42adcfbabd89a40`.

## Ограничение и очередь приёмки

**Производительность общей сцены не проверена.** Таблица — CPU update/index/query, не frame time всей игры. GPU/общий FPS p50/p95 и визуальный проход через двери остаются в очереди Координатора17 при одинаковых камере, настройках, населении и прогреве. Cuttable fences проверены точным force/splice unit-контрактом; их authored runtime geometry не включена в 3061 external worker body. Геометрические локальные расходы `building_storeys` и door matrix updates сохраняются.

Команды повторения:

```powershell
node --test assets/maps/city_rebuild_v1/test_incremental_walk_collision_index.mjs assets/maps/city_rebuild_v1/test_npc_native_perception.mjs assets/maps/city_rebuild_v1/test_npc_native_navigation.mjs
node tools/interior_rebuild/audit_incremental_collision.mjs
node --check assets/maps/city_rebuild_v1/walk_preview.mjs
```
