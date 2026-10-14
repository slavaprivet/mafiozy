# Existing-world navigation host — integration handoff

27 сентября 2026. `preview_navigation_host.gd` подключает уже проверенный Godot NavigationServer backend к **существующим** main/PrintshopInterior и ведёт переданный CharacterBody по допущенному server path. Код не создаёт NPC/физические тела, не импортирует test fixture, не читает render meshes и не создаёт NavigationAgent. Main, player, двери и source population provider не изменены.

## Файлы и фактическая проверка

- `godot/mafiozi_walk/scripts/navigation/preview_navigation_host.gd` (+ `.uid`).
- `godot/mafiozi_walk/scripts/tests/test_preview_navigation_host.gd` (+ `.uid`).
- Этот handoff; generated отчёт `outputs/coordinator21_npc_port/host_headless_result.txt`.

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path godot/mafiozi_walk --script res://scripts/tests/test_preview_navigation_host.gd
```

Actual installed Godot **4.7.2**, actual `res://scenes/main.tscn`: **66 checks PASS**, exit 0, без SCRIPT ERROR. Main построил собственные 8 buildings/8 decor, источник типографии и detail water. Test не вызывает geometry fixture из предыдущего пакета. Он на время теста отключает physics process существующего player и передаёт этого же player адаптеру; production этого не делает и не назначает player NPC-личность.

## Источник geometry

`attach_existing(scene, interior, block, printshop_data, shared_queue, authority, generation, access_version)` требует current dictionaries, равные данным уже построенных main/interior, ready PrintshopInterior и исходные scene-root координаты. Source IDs/indexes main colliders сверяются с block records. У interior сверяются exact source convex points, door leaf points и ordered source floor/ceiling triangles. Неизвестный/пропущенный/повторный source collider, сменённый frame, неподдержанная shape, nonfinite source или чужой shape fail closed до создания backend.

Выбор узлов узкий: direct main StaticBody, direct PrintshopInterior StaticBody и его два явно именованных source door pivot. Нет обхода GLB/render descendants, Player, Area3D sensors, debug geometry. Безымянные floor BoxShape допускаются только при точном совпадении с полосами solid клеток, которые строит main. Никакой дополнительный пол на воде не создаётся. Admission по walkable/dry/access маскам остаётся обязательным: physics solidity сама не означает permission.

Фактический capture: **300 static shapes + 4 existing door leaf shapes**, **3758 triangles**, без добавления хотя бы одного Node. Число отличается от предыдущего fixture, поскольку здесь берутся настоящие объединённые floor strips целиком, включая грани коробок, и actual Concave floor soup. Convex shapes поддерживаются только как проверенные двухуровневые экструзии: вычисляется их фактическая convex XZ outline, один набор верхних/нижних/боковых triangles. Никаких дублирующих hull bodies не создаётся. Неэкструдированный convex отвергается.

Floor faces сохраняются из **реальной ConcavePolygonShape3D** без изменения. При membership validation допустимо 10 микрометров на ordered source vertex: actual ArrayMesh→Concave float32 transform дал 1-ULP расхождение с direct source calculation. Оно наблюдалось в Entry_Interior_Floor; порядок и число triangles проверяются. Это не округление bake geometry — в bake идут исходные physical faces узла.

Static CPU triangles хранятся один раз. У четырёх leaf хранятся local triangles и weak node reference; только при stable door publication прикладываются новые global transforms. Изменение static topology/shape/transform после attach требует dispose и новой attach: на каждом кадре статические меши не сканируются. Root обязан соблюдать этот lease, как у static batching.

## Узкие root hooks — только предложение для интеграции

1. После успешного построения geometry/PrintshopInterior создать shared queue и host, передать существующие `self`, `_printshop`, `_block`, `_printshop_data`, настоящие authority/generation/access version. Ошибка attach означает запрет NPC navigation, не fallback на прямое движение.
2. После **accepted** `PrintshopInterior.request_door(...)`, до первого `advance`/поворота, вызвать `host.door_transition_started(key, 1.0 if open else 0.0)`. Этот host не разрешает door action и не заменяет `_current_door_occupants()`/service access: root передаёт реальные occupants в существующий door runtime.
3. После `PrintshopInterior.advance(delta, occupants)` вызвать `host.pump(Engine.get_physics_frames())`. Host через существующий `door_fraction(key)` замечает достижение объявленного target. За всё движение двери выполняется **одна** новая публикация после settle, не каждый кадр. Пока хотя бы одна дверь движется, новые requests запрещены, старые receipts STALE и скорость их тел обнулена. Если sweep occupants остановил дверь посередине, переход остаётся pending; навигация не объявляет его завершённым.
4. После authority/access изменения вызвать `update_access_version(new_version)` до movement. Оно инвалидирует старые receipts, но **не перестраивает** неизменную geometry. Новый запрос проверяет новый trusted provider; stale version отвергается. Обнаруженный не объявленный поворот leaf также блокирует host; recovery требует корректного transition/settle hook, а не молчаливого использования старого mesh.
5. Владелец trusted source population передаёт `request(existing_owner, existing_body, target_metres, trusted_admit)`. Owner — `PathJobQueue.Owner` с настоящими source ID/life generation. Callback обязателен, синхронный и проверяет текущие terrain/water/floor/headroom/door/role/occupant rules. Нет implicit allow, resident generator или service roster. Дублирующая owner instance на тот же source ID и несколько owners на одно body отвергаются.
6. После `poll(id).status == "READY"` существующий controller вызывает `step(id, delta, speed, gravity)` в своём единственном physics tick. На retirement/life change — `cancel(id)`; при остановке world — `dispose()`. Main `tree_exiting` также автоматически выполняет dispose до исчезновения physics world. Shared queue освобождает её владелец.

Можно использовать такой узкий порядок без автозапросов:

```gdscript
# После уже существующего door.advance и до движения NPC:
navigation_host.pump(Engine.get_physics_frames())
# id появился только из request с trusted owner/body/admit.
var result: Dictionary = navigation_host.step(id, delta, movement_speed, gravity)
# BLOCKED/PENDING/STALE передаются существующему source controller/FSM.
```

Host не создаёт второго scheduler clock или queue. Все engine queries и route admission проходят прежний cap/cohort/actual-spent backend. Нет NavigationAgent и его неучтённых автоматических repaths. `BLOCKED` не создаёт 60 новых поисков в секунду: retry/backoff/agenda остаются у controller.

## Movement и lifetime

`step` не присваивает position waypoint, не меняет capsule, safe margin, floor snap или floor max angle. Он задаёт текущую velocity и вызывает штатный `move_and_slide`. Caller должен иметь exclusive movement ownership; нельзя одновременно вызывать player/NPC controller physics process и host step для одного body.

Поддерживается одна вертикальная CapsuleShape3D, без масштабирования/наклона root, допускается yaw; radius ≤0.36 м, height ≤1.9 м, foot-origin, collision mask 1. Более крупные/другие тела fail closed. У actual main player radius 0.30 м; backend проверяет консервативные 0.36 м, существующая shape не менялась. Физические gravity/snap разрешают контакт пола. На grounded шаге continuous capsule admission проверяет lateral motion; отрицательная floor-bias velocity разрешается самим CharacterBody об пол, иначе такая проверка ошибочно блокировала гребень пандуса. Airborne proposal включает Y и тоже ограничен backend segment cap.

Каждый шаг снова проходит trusted source predicate и реальный capsule physics cast. Максимальные входы: delta 0.05 с, speed 5 м/с, gravity 30 м/с²; суммарный предложенный segment ещё ограничен 0.25 м backend. `ARRIVED` требует ≤0.15 м XZ и ≤0.30 м Y до заданного source target. Terminal receipts сохраняют source ID, life generation, исходные access/geometry версии и отдельно текущие версии; никаких новых IDs при перепланировании.

Все публичные методы main-thread only, mutation reentry во время backend pump/step запрещён. Providers не должны yield, вызывать повторный step или менять authority внутри callback. Host содержит максимум 128 records, до 512 source shapes и bounded backend geometry/jobs/worker limits. Weak body/owner refs не заменяют явный cancel: cancel освобождает provider/queue record и обнуляет скорость. При owner death receipt отменяется; при tree exit backend maps/RIDs и callback resources освобождаются штатным dispose contract.

## Поведение и измерения

На actual main проверены closed door NO_PATH, PENDING до map readiness, transition invalidation **до** первого поворота, отсутствие промежуточных rebuilds, один settle bake, open door/ramp route и физическое прибытие. Существующий body дошёл за **150 physics frames**, максимальный фактический шаг **0.033775 м**, отказов movement 0. Capsule/floor snap/safe margin и source identity сохранены. Смена access version дала отказ следующему запросу, не вызвав bake. Проверены duplicate identity, unsupported shape, изменённый source frame, nonfinite source, игнорирование Area3D sensor, отсутствующий provider, thread, stale access, oversized/NaN step, owner death, автоматический tree-exit dispose.

Последний actual-main CPU run:

| Работа | Измерение |
|---|---:|
| Static capture + source verification, один раз | 7.881 мс |
| Последующие static captures во время 150 steps | 0 |
| `step` вместе с existing CharacterBody physics, p50/p95/max | 0.208 / 0.315 / 0.419 мс |
| Initial/settled background bake wall latency | 329.204 / 314.540 мс |
| Initial/settled main-thread publication | 1.098 / 0.892 мс |
| Engine queries, три вызова | 0.106 / 0.070 / 0.065 мс |
| Bake count initial → opening animation → access change | 1 → 2 → 2 |

Это actual-main headless CPU с существующей геометрией и одним существующим consumer; не full FPS и не приёмка сотен NPC. Штатный Recast voxel before/after уже измерен в `PREVIEW_ENGINE_NAVIGATION_HANDOFF.md`; этот пакет дополнительно устраняет повторный capture и per-fraction door rebuild. Не подменять измерение single-body step обещанием общего population budget. Motion admission/physics стоимость всех персонажей потребует отдельного LIVE замера после подключения trusted roster.

Оставшаяся игровая интеграция — root hooks и реальные source owners/role rules от владельца population. До их передачи этот модуль готов к подключению, но не является живым городом. Дверные события пока консервативно останавливают маршруты всего crop; локальные door regions/routes — возможная следующая оптимизация с отдельной проверкой semantics.
