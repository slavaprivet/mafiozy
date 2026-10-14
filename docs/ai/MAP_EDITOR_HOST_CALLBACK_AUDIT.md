# Редактор карты: аудит настоящих игровых владельцев

27 сентября 2026. Получатель: Координатор21. Только чтение исходников; main/player/res не изменены, игра не запускалась и не закрывалась. Это практическая карта интеграции, не LIVE/production acceptance. Ruflo/ToolSearch отсутствуют в доступном inventory; использована файловая память.

## Вывод

Подключать K одной заменой input нельзя: текущая игра не имеет общего pause/resume lease, вода не имеет transactional replacement, а навигация принимает только неизменённую source-сцену малого квартала. Готовые editor_host_adapter + Atomic + Workspace решают редакторскую транзакцию, но не реализуют владение этими игровыми зависимостями. Их обязательные callbacks нельзя заполнить `{ok:true}`.

Текущий main revision в прочитанном source — `s01-20260927-physics18`. `_block.surface` имеет startRow=0, startCol=76, rows=31, cols=31, cellSize=4.1. Успешная output-сборка с 242 объектами и землёй 200×180 НЕ доказывает, что полная карта уже существует в этой main-сцене. Превью имеет отдельную физическую границу `PreviewBoundary`.

## Кто владеет подключением

По `docs/ai/AGENT_HUB.md`: Координатор21 — main/player/project/LIVE; его navigation-субагенты — scripts/navigation; Художник21 — NPC visuals/source bridge; Автомобили — продолжение3 — transport/seat/session lifecycle; ФизикаАвтомобилей12–13 — native body; traversal — владелец прыжка/перелезания. Вода сейчас вызывается непосредственно из root main, поэтому до явного назначения её callback owner — Координатор21, не автоматически Художник21. Чужие задачи этим аудитом не уведомлялись.

## Точная таблица host callbacks

Все пути ниже относительно `godot/mafiozi_walk/scripts`, если не указано иное. Номера строк — снимок аудита; файлы параллельно развиваются.

| Callback редактора | Настоящая существующая точка | Что действительно делает | Недостающий контракт / владелец |
| --- | --- | --- | --- |
| `pause_gameplay(request)` | `main.gd:454 _unhandled_input`, `:476 _physics_process`, `:753 _process`; `preview_player.gd:262 _physics_process`, `:563 _unhandled_input` | Main двигает двери/NPC; player читает `Input.get_vector` и выполняет move_and_slide независимо от обработки событий | Общего метода остановки нет. Root должен capture точных process/input/physics состояний и времени, остановить **всех** владельцев, вернуть receipt с owner_id/request_id/token только после барьера. Перехват событий сам по себе не останавливает опрос Input |
| `cancel_pause(request)` | Готового игрового метода нет | Host adapter вызывает отмену даже после частично выполненной остановки | Восстановить только захваченное владельцем состояние; идемпотентность и отказ с retained pause. Нельзя hardcode `set_physics_process(true)` всем |
| `verify_pause(receipt)` | Готового игрового метода нет | Adapter проверяет owner_id и результат этого callback, но сам физику не контролирует | Root-owned token+generation/session+живые WeakRef; доказательство, что actor/door/NPC/vehicle/debris остановлены и topology owner не заменён. Проверять каждый фазовый переход, не только вход |
| `transaction_ready(receipt)` | `preview_population.gd:59 step`; `navigation/preview_navigation_host.gd:277 state`; `preview_transport.gd:213 _physics_process`; Atomic.busy_status/renderer pending из candidate | Навигация имеет состояния, transport — phases, Atomic — explicit pending | Совместный gate: paused receipt valid, Atomic не busy, renderer не pending, нет owner repair/fault, проверенная навигация/вода/коллизии готовы. Для UI retry normal readiness намеренно обходится, но lease не обходится |
| `ground_patch()` | `tools/godot/map_editor_ground_candidate/ground_document.gd export_patch()` | GroundDoc экспортирует проверенный patch относительно baseline | Main GroundDoc пока не владеет. Root должен держать единственный admitted crop-document и возвращать его patch; не выдавать `_block.surface` за редакторский patch |
| `resume_gameplay(receipt, objects, ground)` | Готового метода нет; `preview_player.gd:648 get_preview_camera()` существует | EditorCamera восстанавливает исходную camera, но это не physics/nav resume | Root сначала проверяет current identities, обоих документов, native physics/nav/water receipts и actor support; затем exact restore captured flags/timing/input. Return `{ok,owner_id,request_id}` только при полном успехе. При отказе всё остаётся paused |

`main.preview_ready=false` не является lease: оно остановит часть main callbacks, но player, transport, NativeBody и внешние async nav jobs продолжают жить. `set_preview_pose_authority()` — authority/pose API, а не пауза; не подменять им transport ownership. `SceneTree.paused` host adapter намеренно не меняет: глобальная пауза также может остановить редактор/UI и не заменяет receipt/rollback.

## Input, камера, transport: реальные опасные места

1. Root должен добавить единую раннюю маршрутизацию событий **до** трёх `_unhandled_input`: main:454, player:563, transport:189. На `_input` уровне сначала `host.handle_input(event)`, затем `host.gameplay_blocked()`; даже если editor GUI возвращает false ради native LineEdit, gameplay event не должен попасть дальше. Опрашиваемые `Input` действия требуют отдельного pause gate в physics.
2. `preview_player.gd:642 set_mouse_captured(bool)` меняет собственное `_free_mouse_look`, `_right_mouse_down` и глобальный Input.mouse_mode. `:648 get_preview_camera()` — точный accessor для EditorCamera. Player focus callback:614 тоже меняет mouse state; owner должен согласовать blur с editor camera, а не дать player перезаписать курсор активного редактора.
3. `preview_transport.gd:213` увеличивает `_clock`, `_sequence`, синхронизирует native vehicle pose, управляет посадкой/выходом, seat attach и body controls. `:624 _process` обновляет presentation/hint. Нет editor-pause checkpoint/resume API. Seat/interaction lease `transport_logical_host.gd:159 lease(token)` относится к посадке, **не** к общей паузе игры.
4. `vehicle_physics/vehicle_native_body.gd:104 clear_control(sequence)` отправляет нулевые controls, но через submit_control будит body; это не стоп-физика. `:107 snapshot_state()` — опубликованные diagnostics, не полноценный restore capsule; `:214 _integrate_forces` продолжает gravity/contacts/wheel steps. Native body pause должен сохранить velocity, angular velocity, freeze/sleep/custom integration/control sequence и lifetime через owner API. Просто выключить transport process недостаточно.
5. Практическая первая admission политика, пока нет transport-safe pause: отказать K во всех transition/occupied/falling/fault phases; разрешать только owner-подтверждённый устойчивый ON_FOOT. Это **предлагаемое** ограничение, не уже реализованный gate. Даже ON_FOOT машина катится, поэтому vehicle freeze всё равно нужен. Debris/ragdoll bodies также должны попасть в owner inventory.

## Коллизии, земля и специальные здания

| Зависимость | Существующие методы | Точный риск и следующий шаг |
| --- | --- | --- |
| Обычные здания и декор | main:603 `_add_asset(record)`; `tools/godot/map_editor_candidate/.../preview_host_bridge.gd:9 attach(...)` | Visual root — прямой child с source_id, а обычные StaticBody3D коллизии — отдельные siblings main:632–646 с source_id/source_index. Bridge уже передаёт эти siblings в Registry. Двигать только visual root нельзя. Bridge не должен повторно вызывать `_add_asset` поверх мира: будут дубли |
| Static render batches | main:219 `restore_preview_static_batches(reason)`; main:186 `apply_preview_static_batches()`; preview_static_batch:369 `restore()` | Restore **до регистрации baseline** и до первой transform/visibility/material mutation. Иначе registry запомнит скрытые batch-originals, а видимые batches останутся в старом месте. При выходе новую batching declaration admit заново; old lease нельзя resurrect после удаления/добавления объектов. CPU restore exists, joint owner receipt ещё нет |
| Source terrain | main:553 `_build_surface()` создаёт MultiMeshes и direct-child floor strips | Нет возвращаемого terrain-owner capsule, node registry или swap API; повтор вызова создаёт дубли. GroundRenderer candidate создаёт **свою** отдельную root, не принимает старые main nodes. Root должен выделить/adopt точный source terrain inventory и atomically swap с receipts; нельзя оставить старые floors под водой или 2 одинаковых surface batch |
| Jump/traversal land-water gate | main:321 `_cache_jump_surface_contains()`, :355 `preview_jump_surface_allowed(...)` | Кеш построен от original `_block.surface`; перекраска без обновления даст старые разрешения. Owner должен подготовить новый кеш от validated edited crop, сохранить old capsule и включить его только вместе с physics/nav/water. Нельзя для удобства изменить pinned `_block` в обход source admission |
| Preview boundary | main:110–113 создаёт PreviewBoundary по boundsLocalM; preview_boundary:17 `configure(...)` | Crop31×31 имеет реальные стены. Полная земля200×180 не должна стать скрытой второй картой за прежними стенами. Expansion требует отдельного source/fullworld migration admission; сначала crop editor с сохранением исходных координат |
| Printshop | preview_printshop_interior:24 `attach_existing(...)`, :192 `restore_original()`; bridge PRINTSHOP_ID locked | Interior — отдельный root main, world-space physics/doors/anchors и exactsource placement checks, не children обычного buildingroot. Уже правильно locked в Bridge; fullmove/clone/delete разрешать только после special-owner transactional capsule. Это не снятие требования пользователя «все дома», а конкретная оставшаяся зависимость |

## Вода: существующая визуализация не является transactional adapter

`main.gd:228 _build_water_surface()` читает только pinned water_data_path и WATER_DATA_SHA256, проверяет crop. `_validate_water_crop:259` требует именно исходные 303 water cells и matching footprint; edited tile16 или удаление воды этим методом не допускается. `_dispose_water_surface:316` уничтожает текущего владельца. Их последовательный вызов не является rollback-safe заменой.

`preview_water_surface.gd:80 build(data,parent)` строит один source ArrayMesh с per-vertex depths и исходным материалом; `:139 advance(time,ripples)` меняет только анимацию; `:146 dispose()` освобождает mesh owner и material factory. Нет prepare_delta/apply/rollback/finalize/checkpoint APIs. Default fallback на плоский tile box нельзя выдавать за сохранение визуального качества.

Нужен root-owned adapter фаз `prepare/apply/rollback/finalize` для GroundRenderer: готовить new water resources в detached identity-parent, сохранять old instance/material/time/ripple owner до подтверждения; apply swap; rollback exact old resources; finalize освобождать старое только после обоих model commits. Для новой tile16 ячейки требуется доверенный source depth/shore policy, а не выдуманная глубина. Пока этого нет, water painting admission должен явно отказывать, сохраняя старую воду; callbacks `{ok:true}` недопустимы. Dry-ground edit тоже должен доказать, что water topology не изменилась.

## Навигация и NPC: нельзя переподключить publish_source как готовый Atomic callback

`preview_population.gd:40–46` создаёт единственный navigation и resident host. `step:59` вызывает navigation.pump и residents.step; отсутствие main.step останавливает resident движение, но async server bake не обязательно остановлен. `snapshot:75` — diagnostics, не checkpoint; `dispose:80` уничтожает actors/queue/owner state, поэтому dispose/recreate нельзя использовать как «пауза» с сохранением людей/прогресса.

`navigation/preview_navigation_host.gd:112 attach_existing(scene,interior,block,data,queue,authority,generation,access_version)`:

- Одноразовый attach; exact `block == scene._block` и `data == interior._data`, identity-root/interior; source world geometry expected from those original records.
- Сканирует только direct-child static bodies main и особые children interior; candidate GroundRenderer floor strips вложены глубже, поэтому слепо новый renderer этот attach не увидит.
- Лимит capture512 shapes, source exact transforms/shape sizes. Edited здания и strips не совпадут expected. Static triangles затем cached в `_static`; перемещение здания после attach автоматически не пересчитывается.
- `door_transition_started:244`, `update_access_version:251`, `pump:256` обслуживают объявленные source двери/access, не произвольную editor geometry. Access-only update явно НЕ rebake геометрии.

`preview_engine_navigation.gd:64 publish_source(faces,authority,generation,version)` принимает только collision triangles и trusted monotonic version, но сразу помечает jobs STALE и `_free_map()`. Затем async bake: state BAKING→SYNCING→READY. Accepted publish ≠ ready navigation. Ограничения: vertices≤180000, AABB x/z≤256m, y≤64m, area≤20000m², mesh polygons≤4096. Полная земля200×180 при4.1m (=738×820m) этим одним backend не принимается; требуется owner-authorized chunk/region migration, не поднятие лимитов наугад.

Atomic joint-nav callback имеет фазы `prepare/rollback/finalize`. Безопасный binding требует **новый staged navigation owner**, не разрушение active old backend через publish_source. Prepare получает actual staged collision snapshot+candidate document+ground delta, validates lineage и начинает staged bake; сохраняет old owner/job capsule. Если bake async, prepare может вернуть owned receipt, а finalize должен возвращать false до staged READY, удерживая committed:true и паузу через retry_pending. Rollback до commit уничтожает только staged backend и восстанавливает old receipts. Finalize атомарно переключает resident/navigation pointers, инвалидирует old jobs по версии и освобождает old map. У текущего host таких swap/restore APIs нет.

NPC source policy тоже необходимо обновить owner-side: `npc_visual/preview_resident_world_policy.gd:24 configure` сверяет exact packet/block SHA и `_block`, поддерживает лишь source crop31×31; кеширует floors и проверяет их exact parent/frame/shape в support_height. Замена strips без re-admission сделает support stale. `update_access:169` не обновляет землю. Source authority не равна editor геометрии: новый navmesh не выдаёт право прохода в запрещённые зоны. Требуется validated edited-layout policy поверх immutable source identities/access, не снятие hash guards.

## Минимальный согласованный план подключения

1. Root принимает lease-owner protocol с transport/native-body/traversal/NPC inventory. Actual-main headless тест: удержанные W/E/мышь, car coasting, door transition, NPC pending query; после K ни один игровой clock/pose/velocity не меняется без явного permitted owner, editor UI работает. Partial-pause отказ восстанавливает exact flags; повтор callback/reentry/blur проверены.
2. Restore static batches; register существующий crop через PreviewHostBridge, сохранив locked special adapters. Ground baseline должен точно представлять admitted source31×31 с startCol76/origin, не unrelated full200×180. Ввести owner terrain inventory/adoption, shared SurfaceMaterials, source strip proofs/no water floors.
3. Реальные nav+water owners готовят transactional stage/rollback/finalize, source policy/jump caches и generation receipts. Failure-injection на каждый настоящий owner phase; не fake validators. Существующие source/shapes/materials не ослаблять.
4. Mount Host; wire Workspace→Persistence→Atomic и initial K input ownership. Main normal gameplay gates включать независимо от GUI consumed flag. При pending UI показывает recovery, K не выпускает; owner repair/reset не делает половинный resume.
5. Actual-main save→fresh source scene→load: ids/siblingcolliders/floors/water/materials/actor support/nav access exact, hidden batches отсутствуют. Затем один согласованный LIVE instance и сопоставимый loaded-scene p50/p95. Поставить в «Что нового» K только после реального принятия; не до callbacks.

## Снимок проверенных исходников (SHA256)

```text
main.gd                                 05876d13f1423534f605eeb7e9395f1b7c7240421c0044ee8aa81ef82c0dabfc
preview_player.gd                       a719a6903cfc5cd77c346df2a02db0b92ee3234cb4aaaf7c45d84e555d8e53f5
preview_transport.gd                    b08cb5d55f08b6c7f6f33a17a8f79b838de9c038c67053894c9dae50788cacd4
preview_water_surface.gd                7d89235d93f31dd565aadf37f549a05074bec5534acfb120543228f1dba2655c
navigation/preview_navigation_host.gd   0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4
navigation/preview_engine_navigation.gd aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab
preview_population.gd                   91815fd8851151fe8443a85b84b268a95a04c07ff39f0a136c60c631f58fe37c
vehicle_physics/vehicle_native_body.gd   a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401
```

Source мог измениться после снимка: перед внедрением повторить comparison и не перетирать чужие файлы. Этот аудит не создаёт новую runtime authority и не объявляет editor production-ready.
