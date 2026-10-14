# NPC native navigation — resumable source search, geometry and spatial index

27 сентября 2026. Локальный модуль готов к root review: actual Godot 4.7.2 headless **10 977 checks PASS, exit 0, без SCRIPT ERROR**. Порт выполняет настоящий source A* через уже переданные очередь и swept footprint. В `main`, player, NPC roster/appearance, water/dive и исходный Walk изменений нет. Видимые NPC и полный игровой маршрут ещё не интегрированы. Lead14 подтвердил root: этот native runtime принадлежит нашему scope; A8 выполняет независимый review, не параллельный port.

## Файлы и воспроизведение

- `godot/mafiozi_walk/scripts/navigation/npc_native_navigation.gd` и его generated `.uid`.
- `godot/mafiozi_walk/scripts/tests/test_npc_native_navigation.gd` и его generated `.uid`.
- `godot/mafiozi_walk/scripts/tests/fixtures/npc_navigation_oracle.json`, 939 685 bytes: immutable exact-source oracle для Git.
- `tools/godot/build_npc_navigation_oracle.mjs`: reproducible generator для Git; корень определяется от `import.meta.url`. Проверен запуск из постороннего `C:/Users/Слава`.
- `outputs/coordinator21_npc_port/navigation_headless_result.txt`: финальный actual CPU/headless отчёт.

PowerShell из корня репозитория:

```powershell
node tools/godot/build_npc_navigation_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_npc_native_navigation.gd
```

Generator исполняет неизменённые `npc_native_navigation.mjs`, `npc_native_directed_route_source.js`, `walk_collision_index.mjs`, `npc_swept_footprint.mjs`, а scheduler и `_setNpcRoute` извлекает из актуальных байтов `world.html`. Source не переписывается. Fixture хранит входные и ожидаемые числа как IEEE754 little-endian hex: десятичный JSON reader Godot не меняет последние биты координат.

## Source dependency / call graph

`world._planNpcRouteTo` резервирует `_npcReserveRouteWork` и в `finally` завершает `_npcFinishRouteWork`. Для `building_entry`, `civilian_road_exit`, `civilian_bench`, `empire_action`, `empire_escort` он вызывает внешний `_npcPlanNativeVisitRoute`. Этот helper сохраняет frontier в `_npcDirectedSearch`, вызывает переданный **тот же** `passFn` и `_walkNpcNavigationResolver({mode:'sweep',...})`. Resolver берёт height/terrain/water/vehicle/surface providers и реальные polygons; swept footprint не заменяет water/custom passage predicate. При успехе helper передаёт путь в `_setNpcRoute`.

Прямые зависимости native: `path_job_queue.gd` и `npc_swept_footprint.gd`. Source `npcPassable`, `npcPassableForSnitch`, `_npcBodyPassable`, `_npcRouteWalkBlocked`, restricted zones, source resident access, текущие двери/машины/ground/water/surface providers остаются задачей host. Модуль не подставляет вместо них правило «везде можно». Fixture point predicate и прямоугольные искусственные преграды — только тестовые входы, не реализация NPC поведения.

Source SHA256:

| Source | SHA256 |
|---|---|
| `npc_native_navigation.mjs` | `fe466a75277ce60267d46c4fe4e9b26e9d16b68d5ad6a8640f89dc9b5e3f2efb` |
| `npc_native_directed_route_source.js` | `825d7ad7f17d3aa764474feb844ee6893cf6c86b9cb9478cf1bfb781a2982db6` |
| `walk_collision_index.mjs` | `134fc2ec377885eb1a4c4a1c224cd662b083a50bca3fa5d1854fb7e0f43c9de9` |
| `npc_swept_footprint.mjs` | `918467e987c06cbdc88af5772113d8492f1d58e9198d0e86e7050b2c1c617258` |
| `world.html` | `9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5` |
| current `printshop_interior.json` | `958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b` |

## Public API / ownership

Load `npc_native_navigation.gd` as `Nav`. Все API работают синхронно на main thread; callback не делает await, не меняет source actor/authority/геометрию и не запускает второй search. Reentry через другой экземпляр Nav тоже отказывается и инвалидирует внешний результат. `plan` не удерживает actor/queue/provider references после возвращения; pending continuation живёт только у переданного `Queue.Owner`.

`plan(frame_id, queue, owner, start, goal, pass_fn, resolver, goal_radius=.8, max_visited=18000, kind='building_entry', map_cols=180) -> Dictionary`.

- `start`, `goal`: `{r: scalar64, c: scalar64}` в **исходных клетках**, не Godot local metres. `map_cols` — реальный source MAP_COLS; provider обязан проверять source map bounds. Промежуточных Vector2/Vector3 float32 нет.
- `owner`: существующий `Queue.Owner(source_id, life_generation)`. Смерть или новая жизнь — отмена старого Owner, новый объект для новой жизни, даже если stable employment ID тот же. Нельзя переносить continuation на другого Owner. Dead проверяется до admission и после callbacks.
- `pass_fn(r,c)->bool`: уже точный source passage/body predicate выбранного gameplay route. Не нужно слепо добавлять второй body inflation к empire custom predicate. Callable должен быть стабильным между порциями. Native сравнивает функцию, bound arguments и unbound argument count: обычное Godot Callable equality оказалось недостаточным для bound arguments.
- `resolver(request)->Dictionary/null`: source sweep capability. Отсутствие capability сохраняет source поведение ниже. Wrong-type responses fail closed. Stable Callable и его bound identity должны соответствовать жизненному циклу provider; изменение таблиц внутри того же provider публикуется frame/version контрактом, а не скрытой заменой функции.
- `PENDING` с `admitted=false` означает очередь/когорту; `PENDING` с `admitted=true` — сохранённый frontier. `READY` возвращает `path:[{r,c},...]`, `kind`, `source_id`, `life_generation`, `frame_id`. `NO_PATH` — законченный неуспешный поиск. `INVALID` — нарушение host API. `CANCELLED` — мёртвая жизнь. Ни один из этих исходов не подменяется прямой линией до цели.
- `expanded`, `visited`, `restarts`, `retained_nodes` — detached diagnostic receipt. Expansion/visited публикуются по завершении; pending выдаёт нули для незавершённых итоговых метрик. Owner продолжает хранить CPU/queue метрики самого scheduler.
- `cancel(queue, owner)` освобождает continuation/provider и очередь по object identity. Host вызывает это при смерти, снятии задания и перед удалением provider/actor. `Queue.dispose()` освобождает оставшиеся served/cohort references. Native тест проверяет освобождение последней Owner reference.

`READY` — ещё не запись в gameplay NPC. При интеграции host должен в том же синхронном жизненном контексте применить исходный `_setNpcRoute`: снять wander search, присвоить route, index=0, kind, goalR/C, blockedAt=0, tr/tc первого узла. Проверить source_id/life_generation и отсутствие смерти. Модуль намеренно не выдумывает NPC для применения этих полей.

## Geometry and actual spatial broadphase

`Nav.Body.new(polygon_cr, min_y=NAN, max_y=NAN)`: реальные concave polygons `[c,r]`; vertical bounds в world metres. Нельзя заменять их bbox/convex obstacle hull. `Geometry.new(callbacks, world_scale=4.1, height=1.9)` требует `contains_body`. Остальные callbacks: `ground_height(x,z)`, `water_at(x,z)`, `bodies_at(c,r)`, `bodies_in_bounds(minC,minR,maxC,maxR)`, `terrain_allows(x,z)`, `surface_at(x,z,r,c)`, `blocks_dynamic(x,z,{y,height,ignoreId})`. Dynamic context переиспользуется, как в source; callback его не сохраняет. `query` возвращает detached result, чтобы caller не испортил cached response. Production vehicle ignore IDs — только String/null, произвольные JS string/number coercions исключены host контрактом.

Точно сохранены floor+.05 support threshold, floor+1.9 headroom, высота **каждой actual corner/contact** на уклоне, water level minus actual support, динамические тела после static point gates, `land/road` surface. Geometry сообщает depth, а source passage predicate решает допустимость воды (`_npcRouteWalkBlocked` использует >.025 при отсутствии своего bypass). Geometry не разрешает автоматически плавание.

`Nav.SpatialIndex.new(cell_size=4.0)` — прямой static `createWalkCollisionIndex`: floor bucket coordinates, collection/body order, повторные ссылки, row-major queryBounds, exact narrowphase после кандидатов. Для current printshop выбран допустимый source parameter **cell_size=.5 клетки = 2.05 m**: 107 тел →396 bucket references. Нет удаления препятствий/контента или упрощения полигонов.

`index.publish(collections, authority:String, generation:int, version:int) -> bool`: полная атомарная публикация свежего authoritative snapshot. Обе двери/все текущие body groups включаются caller в source порядке. Источник каждого Body клонируется, polygons становятся read-only, повторный source object остаётся одним duplicate identity внутри snapshot. Старые caller Arrays после публикации не определяют index. Прежняя authority не заменяется другой; для другой authority нужен новый index. В той же generation принимается только возрастающая version; новая generation допускает новый отсчёт. Stale/foreign версия отклоняется, malformed fresh snapshot переводит consumers в fail closed до валидной перепубликации. Нельзя продвинуть игровую позу при отклонённой публикации.

`geometry.attach_index(index)` подключает реальные `query`/`query_bounds`. Geometry перед каждым запросом проверяет revision; новая pose/version очищает и point, и sweep cache **в том же кадре**. Даже после cached blocked результата перемещённая дверь сразу освобождает старый проход и блокирует новый. Изменение index во время callback инвалидирует результат.

Host публикует полный snapshot **до движения** при каждом изменении collision pose. Здесь не добавлен таймер, не пропускаются промежуточные door poses и не читается будущий door runtime. Это scoped static index с полноценным versioned rebuild. Инкрементальные source groups для всего города — отдельный следующий порт; пока не объявлять этот rebuild ценой всей городской сцены. `begin_frame()` остаётся обязательным для moving vehicles, water/support/surface/custom provider changes даже при неизменном static index. Mutable provider snapshot внутри порции запрещён.

## Сохранённые алгоритм и source edge cases

- Shared cap8/actual 4ms/cohort fairness/persistent owner/expiry/cancel остаются у уже проверенного Queue. Search заканчивает каждую принятую порцию `finish`. Deadline source **мягкий**: проверяется между discovery anchors/expansions, а весь connector/четыре соседних ребра завершаются атомарно. Поэтому реальный slice может немного превышать 4ms; алгоритм не заменён другой промежуточной остановкой.
- Binary heap ordering f→h→numeric coarse key / string fine key; cardinal expansion order; invocation-only successful pass cache8192; coarse goal-anchor discovery radius2.25; direct approach <=8 только при положительном sweep capability; fine fallback .25 только после изолированного coarse старта; финальный connector до точной цели всегда проверяется. Goal/provider/start/key change перезапускает frontier.
- Native `Math.hypot` equivalent вычисляет scalar64 sqrt(a²+b²) в ограниченном world domain. Все fixture route coordinates/order, decisions, counts, restarts, queue admission и injected work совпадают **точно**. Геометрическая сумма длины пути сравнивается с source Math.hypot с относительным пределом `2e-15` из-за libm rounding; blanket bit identity всех потенциальных near-tie world routes этим тестом не заявляется.
- Source `nodes.size < limit` проверяется перед expansion, поэтому четырьмя соседями возможен overshoot до3. Oracle `limit=2` возвращает `visited=5`; порт не скрывает это как строгий cap2.
- Source short-direct search сохраняет уже проверенные point samples между кадрами и в конце снова проверяет static sweep. Oracle `direct_water_changes_source_edge` меняет воду под уже проверенной первой частью и source всё равно возвращает READY. Динамические point gates ранних частей обычного пути тоже не перепроверяются целиком перед READY. **Host movement обязан выполнять исходный `_npcPathPassable`/эквивалент текущего ребра на каждом движении, ждать/replan при препятствии. READY не разрешает телепорт или движение сквозь изменившуюся дверь/воду/машину.**
- Отсутствие `swept:true` запрещает source short-direct shortcut, но общие A* connectors допускают passage-only fallback. Host физической игры обязан подключить Geometry+SpatialIndex и полный source predicate; отсутствие provider не объявляется доказанной clearance.
- Истинные source JS thrown callbacks пробрасываются наружу; Godot не имеет того же catch/finally механизма для runtime script errors. Native callback обязан быть total/synchronous: неправильные типы дают INVALID/fail closed, но намеренные script errors нельзя использовать как control flow. Финальная headless проверка не содержит script errors.

## Explicit bounded host domain

Search: finite numeric coordinates/radius abs<=1e6, radius>=0, maxVisited1..65536 (реальные source caller1200/768/18000 поддержаны), map_cols1..65536. Frontier <=limit+3, heap <=4*(limit+3)+1 по cardinal incoming edges; <=8192 успешных point entries за slice. Owner на всю жизнь хранит только свой pending frontier. Host ограничивает количество одновременно живых gameplay actors; module не создаёт и не хранит roster.

Geometry: 30000 point-cache entries и 4000 sweep-cache entries до frame/version reset; <=65536 входных candidates на запрос; вся некорректная shape/provider информация fail closed. Index: <=65536 input body references, <=4096 polygon vertices/body, <=262144 bucket references, cell_size1e-6..1e6. Oversized broadphase queries сообщают `last_error`; Geometry трактует их как blocked, не как пустой свободный мир. Index direct consumers также обязаны проверять valid/error. Invalid inputs не заменяются приблизительным маршрутом.

## Actual validation and performance

28 route scenarios /1 584 действий, включая 12-owner cohort, 30 READY outcomes; 6 geometry sequences; два exact source index suites (.5/4), identity duplicates/boundary order, обе cache caps, headroom/walkable top/ramp contact, water/dry bridge, terrain/vehicles, moving door on resume, source fine corridor, NO_PATH, node limit, provider/goal restarts, cancellation/death/thread/reentry/bad inputs. Actual printshop107 current bodies: exterior approach READY; closed-door counter approach NO_PATH, visited35. **Закрытая типография не объявлена достижимой через стены.** Source layout door poses реальные, ground/support fixture uniform; это не proof полного source runtime интерьера.

Финальный сопоставимый CPU workload: тот же native алгоритм,107 current polygons, start/goal/support/passage, закрытый printshop запрос. Пять прогревов,15 измерений для каждого варианта. Ни одна collision shape или проверка не удалена. CPU microseconds:

| Workload | p50 | p95 | max |
|---|---:|---:|---:|
| До: linear provider, полный поиск, injected oracle clock |135294|147732|147732|
| После: actual source SpatialIndex .5, полный поиск, тот же oracle clock |13876|17608|17608|
| После: index + **реальные часы Queue**, одна порция |4277|4678|4989|
| После: index + реальные часы, полный поиск |14025|19781|19781|
| Полный atomic index rebuild107 bodies (real-clock серия) |1257|2151|2151|

Полный indexed поиск в финальном real-clock замере: p50=4 порции, max5; ранее в менее нагруженном desktop получалось3. Максимальный удержанный fixture frontier126 nodes; current index396 bucket references. Общая сводка admitted_slice в логе включает намеренно оставленный **linear baseline** и не является стоимостью production indexed режима. Поиск стал примерно в9.8 раза дешевле по median полного запроса, без изменения исхода/пути. Native compiled JS быстрее GDScript; это не скрывается обещанием полного FPS.

**Производительность общей сцены не проверена**. Не запускались GPU, renderer или новый preview; существующие игровые PID/sessions/editor не закрывались. Нужна отдельная root интеграция body/door/controller providers и единственное согласованное LIVE окно с frame p50/p95 до объявления первого живого NPC slice готовым.
