# Наёмники: аудит CPU до LIVE baseline

13 сентября 2026. Исполнитель: subagent mercenary_input_audit по поручению Координатора 17.

Первоначальный статус: только чтение кода до baseline. Позднее root разрешил две доказанные оптимизации — результат ниже. Тяжёлые CPU-прогоны, браузер и GPU не запускались. Числа экономии миллисекунд/FPS не заявлены.

## Внесено после разрешения root, готово к согласованному reload

- В mercenary_badges.mjs удалена первая неиспользуемая пара headPosition/project из refreshScreen. Реальный bone и камера читаются в том же вызове как раньше; частоты/окклюзия/дальность/маски/геометрия не менялись.
- В mercenary_targets.mjs добавлен optional reuseRegistry для get; mercenary_walk передаёт true **только** немедленно после успешного pick. Обычные get/команды/effects пересобирают реестр как раньше. Live describe сохраняется при каждом get, source host precedence и NPC merge прежние.
- Почему не передавался сам picked descriptor: pick содержит distance/hitPoint/instanceId от ray hit, а прежний get возвращает describe с возможными авторскими meta-полями этих имён. Прямое reuse descriptor поменяло бы результат. Текущая правка сохраняет точную форму и значения meta.

Лёгкие тесты воспроизвели обе лишние операции до patch: registry reads 2 вместо 1; head sample в aimOnly=false 2 вместо 1. После patch PASS:

- test_mercenary_badges.mjs — **14/14** (добавлен head read counter для aimOnly=false/true, текущая изменённая bone поза и точное положение на экране). После patch head reads 1 при aimOnly=false и 2 при aimOnly=true.
- test_mercenary_pick_registry_reuse.mjs — **4/4** (один registry refresh, exact authored metadata/descriptor shape, host precedence, NPC merge, fresh default get после движения/замены/удаления).
- test_mercenary_targets.mjs — PASS integration script (ray hits, actual locks, pending/idempotent effects, removal, numeric IDs, rally).
- test_mercenary_walk.mjs — PASS integration script (V/E/X/member, owner effects, moving car commands, death interrupt, 6 classic world scripts compiled).

Всего **4 файла тестов PASS**, node:test показывает 20 успешных результатов (18 именованных тестов + 2 integration scripts). Прогоны занимали менее секунды каждый и не были benchmark. Производительность общей сцены не проверена; before/after FPS остаётся за координатором.

Broadphase для badge occlusion **не вводился**; его консервативность для поздней геометрии ещё не доказана. walk_preview/world/render/vehicle в этом этапе не менялись. Перезагрузка игровой вкладки не выполнялась.

## Найденные повторные вычисления

### 1. Повторная позиция головы и проекция

`mercenary_badges.mjs`, `refreshScreen()`:

```js
headPosition(o,src); projected.copy(world).project(camera);
const aimed=!aimOnly||Number.isFinite(aimScore(o,src));
headPosition(o,src); projected.copy(world).project(camera);
```

Первая пара headPosition/project не используется: `aimScore` её результаты не читает, а последняя пара перезаписывает их. При aimOnly=true и валидном близком актёре внутри aimScore есть ещё headPosition: всего **3 вызова** headPosition и 2 проекции badge crown за refreshScreen. При aimOnly=false — 2 headPosition и 2 crown projections. Это числа вызовов из кода, не измеренная стоимость.

Первый безопасный patch: убрать только первую пару. Семантика текущей камеры, дистанции, положения bone, aimOnly и окклюзии сохраняется. Lazy инициализация headCache выполнится внутри aimScore или последующим headPosition.

Второй возможный patch: reuse результата headPosition **только внутри одного синхронного update**, включая выбор aimScore и размещение выбранной карточки. Нужен собственный call epoch, а не время/TTL; позиция должна вычисляться заново в каждом updatePresentation после обновления камеры. Нельзя просто читать matrixWorld без обновления: текущий getWorldPosition обновляет цепочку родителей, и контракт готовности matrixWorld всех actors не установлен.

### 2. Badge raycast обходит весь content

`mercenary_badges.mjs`, update: раз в >=.1 секунды выбирается одна карточка и ray.intersectObjects(getRoots-filtered,true) идёт рекурсивно по всему content и машинам. Прямые NPC roots исключаются через actorObjects, но static content всё ещё полный.

`mercenary_walk.mjs` уже получает `getPickRoots` и отдаёт его targets, но badges получает только getRoots. В `walk_preview.mjs:603` getPickRoots использует existing shotObstacles(origin,direction,distance) плюс NPC roots. shotObstacles (`:541`) берёт static candidates из shotRaycastIndex и **все текущие** машины, поэтому двигающиеся машины не получают устаревшие spatial bounds.

Предлагаемый patch после baseline: optional getOcclusionRoots (или одинаково именованный getPickRoots) у badges, передать существующую функцию из mercenary_walk. Вызвать после ray.set и ray.far=distance-.15. Затем оставить текущие map/filter/actorObjects и итоговый hit predicate без изменений. При отсутствии callback оставить полный getRoots. Не менять 10 Hz, 30 Hz selection, per-render projection, порог 12 м, расстояние .15 до головы, material opacity .8, прозрачность, hidden ancestors, hero и mercenaryPickIgnore.

**Условие exactness:** кандидатный callback обязан быть консервативным superset реальных пересечений. Существующий raycast_root_index хранит bounding boxes при создании, padding=4, пересоздаётся в refresh и сбрасывается clearContent. Пустые roots всегда остаются в candidates; движущиеся авто добавляются отдельно. Однако из одного интерфейса нельзя доказать, что поздно добавленная/сдвинутая геометрия непустого статического root никогда не выйдет за initial padded bounds. Перед подключением проверить двери/изменяемые building children/late additions или сохранить такие roots без culling. Не создавать второй индекс и не менять чужие renderer/vehicle/shadow файлы.

Существующий test_raycast_root_index.mjs сравнивает exact mesh/instance/distance в статической сцене и hidden-parent case. Его успешность не доказывает корректность позднего расширения непустого root. В этом аудите тест не запускался.

### 3. Двойная registry refresh после каждого успешного target pick

`mercenary_walk.mjs`, pick:

```js
const value=targets.pick();
if(!value)return null;
return target(value.id)||value;
```

targets.pick синхронно выполняет refresh() registry и describe результата. Затем target(value.id), если host не возвращает direct member/target, снова вызывает targets.get(id), который снова refresh() и describe. На успешном авто/сейфе/заборе это два прохода fleet/traffic/NPC/buildings и повторные world-position/quaternion расчёты в одном call stack. Неуспешный pick не удваивается.

Предложение отдельного небольшого patch: target(id,alreadyPicked=null) использовать alreadyPicked вместо targets.get только для немедленной ветки pick; host getMember/getTarget precedence и NPC source merge сохранять. Остальные вызовы target/get для текущих команд/charges/effects оставить свежими. Это не кеш между кадрами и не ослабляет актуальность команд. Нужно убедиться regression-тестом, что source normalization и возврат owner host target не изменились. Не менять эффектный/transaction path.

## Что не предлагается

- Уменьшать NPC count/дальность/частоту обновлений или quality.
- Кешировать окклюзию/aimScore на дополнительные кадры.
- Удалять прозрачную геометрию или скрытые meshes из picking с другой семантикой.
- Заменять triangle raycast приблизительным box hit.
- Параллельно править оптимизацию renderer/vehicles/shadows или NPC population.

## Проверка после разрешения baseline

1. Сохранить baseline общей populated сцены при одной игровой вкладке; выбранный кадр/камера/отряд/прогрев/настройки неизменны.
2. Лёгкие регрессии badges: текущая head bone поза, aimOnly, поворот камеры на первом sub-throttle кадре, 12 м, скрытый actor, больница/death, HUD mask и один неизменённый ring.
3. Добавить сравнение full vs indexed badge occlusion при непрозрачной стене, прозрачности ниже/выше .8, hidden ancestor, nested actor/hero/ignored mesh, движущейся машине, instanced blocker и finite ray cutoff. Проверить exact badge hidden/position/ray frequency; никаких новых визуальных упрощений.
4. Для registry reuse проверить source target precedence, NPC merge, живой авто approach, id и distance/hitPoint прежней формы, свежий get/effect после перемещения/удаления. Счётчиком подтвердить отсутствие второго refresh только внутри одного pick.
5. Снять comparable LIVE после изменений: общий frame time p50/p95 и update составляющая badges/picking, draw calls/triangles должны остаться прежними. Доказательство CPU вызовов отдельно от FPS.

Исходный план ожидания baseline соблюдён до отдельного разрешения root на две описанные правки. Производительность общей сцены этим аудитом не проверена.
