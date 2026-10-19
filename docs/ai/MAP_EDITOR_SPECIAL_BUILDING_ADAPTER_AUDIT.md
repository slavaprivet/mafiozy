# Редактор карты: аудит защищённых специальных зданий

Срез исходников: 27 сентября 2026. **Read-only**, без изменения production,
живой сцены, защиты, checksums, игровых полномочий или Git. Это не LIVE-проверка
и не подтверждение, что здания уже можно двигать.

Машинный срез с точными исходными координатами, IDs, resource SHA, дверными,
банковскими и дорожными anchors и 22 SHA исходных файлов:
`MAP_EDITOR_SPECIAL_BUILDING_ADAPTER_AUDIT.inventory.json` рядом с этим документом.
Срез надо перепроверять при изменении владельцами исходников.

## Результат

В фактическом catalog есть **10** рассматриваемых authored placements:
4 типографии, 3 банка, 3 районных изолятора. В текущем native `data/block.json`
из них присутствует только `REBUILD-VISUAL-print_shop-001`.
Это отличается от catalog всего города и от подготовленных изолированных сборок.

В текущем `scripts/main.gd` не найдено подключение MapEditor/Workspace или
готовых callbacks переноса специальных зданий. Candidate factory умеет
попросить владельца **создать** bank/detention interior, но не содержит законченного
контракта их move/delete/clone/load. Наличие GLB/статической модели не равно
наличию функционального перенесённого здания.

Главный полицейский комплекс и исходный красный мост **не являются placements
в `catalog.objects`**. Есть protectedRects/masks и browser minimap markers.
Нельзя зарегистрировать их под именем маркера и объявить перемещаемыми.

## Точные IDs → участники и связи

| Catalog key / source ID | Native визуальный root / коллизии | Интерьер, двери, service/authority, navigation | Необходимый владелец и текущий статус |
|---|---|---|---|
| `buildings:REBUILD-VISUAL-print_shop-001` / `REBUILD-VISUAL-print_shop-001` | В текущем main root с `source_id`; визуальная GLB внутри. **Отдельный sibling `PrintshopInterior`**, не дочерний root здания и не помечен `source_id`. Три внешних envelope bodies заменяются source static/floor/door bodies внутри sibling. | Оба pivot `SourceDoor_public/service`; absolute package anchors `spawn/doorInside/doorOutside/work/customer/customerVia/publicApproach/publicInside`; HUD `_door_hint_world`; preview spawn; residents/nav captured geometry. Browser service station `:news-counter`, stockroom-service-door, siteRevision/employee/customer/visit leases. | Main + PrintshopInterior + population/navigation + source stationary-service owner. Candidate bridge явно **locked**. Нужен транзакционный rebase/rebuild всех участников; API переноса отсутствует. |
| `buildings:REBUILD-VISUAL-print_shop-002` / `REBUILD-VISUAL-print_shop-002` | Catalog native static GLB; не в текущем block. Candidate static factory может вернуть root со своими дочерними exterior bodies, но это не полный interior. | Собственные source footprint/entry/roadProbe/roomSizing. Browser entry/storeys/window/collision lifecycle должен быть пересобран. Native pilot package содержит только ID001, не подходит002. | Generic authored static registration допустима только как geometry-only, не как готовая рабочая типография. Новый per-ID interior/nav owner admission; merchant001 нельзя копировать. |
| `buildings:REBUILD-VISUAL-print_shop-003` / `REBUILD-VISUAL-print_shop-003` | Аналог002; отдельная исходная placement/масштаб/anchors. | Те же категории зависимостей, **не общие координаты001/002**. | Аналог002; отдельный источник/пакет/receipt. |
| `buildings:REBUILD-VISUAL-print_shop-004` / `REBUILD-VISUAL-print_shop-004` | Аналог002; отдельная placement. | Собственные entry/footprint; source storeys/interior physical graph. | Аналог002. |
| `buildings:REBUILD-bank:large` / `REBUILD-bank:large` | Catalog pending-import source GLB SHA `8902684d…`; не текущий block. Candidate factory `special_building` не создаёт обычный solid envelope вместо комнат. | Canonical `gameplayId=bank:large`, `gameplayActive=false` в source placement; Bank_Door_L/R и handles; bankLayout wallRects/7 room labels/vault doorway; source entry/roadProbe/footprint; original bank/vault world authority **ещё не мигрирована этой placement**. | Bank physical-entry + vault/source game owner + main/nav/traffic. Callback factory только creation gate; move/delete/clone/load transaction отсутствует. |
| `buildings:REBUILD-bank:medium` / `REBUILD-bank:medium` | Pending-import SHA `97d92c7b…`; собственные root/yaw/dimensions. | Canonical `bank:medium`; собственные bankLayout/room labels/vault, Bank_Door_L/R. | Как large, но нельзя использовать large layout или canonical ID для новой копии. |
| `buildings:REBUILD-bank:small` / `REBUILD-bank:small` | Pending-import SHA `ba3580e4…`; собственные размеры/placement. | Canonical `bank:small`; собственный layout/door/vault/source authority. | Как large; источник inactive не даёт права self-activate. |
| `detention:REBUILD-DETENTION-chinatown` / `REBUILD-DETENTION-chinatown` | Police GLB SHA `fff0639b…`, pending-import; не текущий block. Source entry имеет выделенные root/contentRoot, hollow shell, floors/ramp/door/gate bodies. Native counterpart пока не реализован этим catalog factory. | `detentionId=detention:chinatown`; stopFootprint/stopLane/stopLocalZ; destination stop/handoff/intake/release; routePoints handoff→intake→cell/release; custodian access/open door authority. | Detention physical entry + road stop/lane + custody/server/booking + NPC/nav owner. Нужна пересборка destination/access/routes, не перенос police shell. |
| `detention:REBUILD-DETENTION-iron_harbor` / `REBUILD-DETENTION-iron_harbor` | Тот же shared GLB, **своя placement**. | `detention:iron_harbor`; собственные stop/corridor/destination anchors. | Как Chinatown; геометрический cache можно разделять, registry/booking ID нельзя. |
| `detention:REBUILD-DETENTION-southside` / `REBUILD-DETENTION-southside` | Тот же GLB; своя placement. | `detention:southside`; собственный stop/entry graph. | Как Chinatown. |
| **Не catalog placement:** `poi:police`, marker `preserved-police` | Native object/root с таким source ID не экспортирован в catalog/block. Browser сохранённый комплекс и immutable police envelope — отдельное source-владение. | Source anchorRC `[76,76]`; police/protectedMask, mainland/island/intake/causeways, immutable geometry; existing police gameplay/traffic/intake. | Отдельный явный source-police/main/custody/topology owner contract. Сначала semantic/root/body export. **Не movable, не cloneable**, не заменять `police_station` asset. |
| **Не catalog placement:** marker `preserved-red-bridge` | Native placement отсутствует. Это не `mini_vehicle_bridge`/`stream_footbridge` catalog asset. | Source anchorRC `[52,90]`; `original-red-bridge` rect `[r47..56,c80..100]` и open-surface `[r47.34..55.66,c78.25..101.75]`; deck/rail/road/water/topology links. | Source bridge geometry + terrain/water/road/nav owner. Сначала точный semantic export и graph. Не превращать мост в solid collider и не двигать один marker. |

Полные SHA/координаты см. JSON. `status` catalog — source-native inventory,
не новое обещание LIVE-ready. Все координаты в исходном масштабе4.1; native
preview origin `[395.65,0,45.1]` вычитается ровно один раз.

## Найденные реальные API (что можно переиспользовать)

### Native main и printshop

- `godot/mafiozi_walk/scripts/main.gd::_add_asset(record)` создаёт authored root,
  sibling external `StaticBody3D` с `source_id/source_index`. Для pilot001
  создаёт sibling PrintshopInterior и вызывает `attach_existing`; при успехе
  не создаёт три старых envelope тела.
- `preview_printshop_interior.gd::attach_existing(visual,building,data)` проверяет
  фиксированные source ID/GLB SHA, **точное совпадение placement**, source origin,
  три replaceCollisionSourceIndices и identity transform своего scene-root.
  `anchor`, `nearest_action`, `request_door`, `advance`, `door_fraction`,
  `restore_original` существуют. **rebase/move/snapshot/restore-door-state APIs нет**.
- `anchor` и public action distance используют absolute `_data` coordinates;
  `_sweep_clear` uses source `door.base` inverse, а не произвольное новое
  `global_transform`. Переместить sibling вместе с моделью всё ещё недостаточно.
- `main::_build_hud` сохраняет `_door_hint_world` из старого package; preview
  `_spawn` вычисляется один раз из publicApproach/publicInside. Эти derived
  позиции тоже принадлежат владельцу main, а не ObjectRegistry.
- `preview_interior_finish.gd::material_for` создаёт world-metre pattern с
  `MODEL_MATRIX*VERTEX + source_origin_m`; при том же map origin сохранять
  world-space материал. Не переписывать shader origin ради визуального обхода.
- `main::restore_preview_static_batches(reason)` / `apply_preview_static_batches`
  существуют для main-owned batches. Pilot001 сейчас не в STATIC_RENDER_OWNER_IDS;
  остальным меняемым объединённым зданиям всё равно требуется правильный владелец
  restore/rebatch, а не движение невидимого исходного root.

### Native жители и navigation

- `preview_population.gd::setup(scene)` привязывает `_block/_printshop_data` к
  `navigation.attach_existing(...)`; `step`, `door_started`, `occupants`,
  `request_walk`, `snapshot`, `dispose` существуют. Pause/resume/relocate
  transaction API в этом файле не найден.
- `preview_navigation_host.gd::attach_existing(scene,interior,block,data,queue,
  authority,generation,access_version)` требует identity scene/interior frame,
  именно действующие данные сцены и сверяет captured static/door/floor geometry.
  `door_transition_started`, `update_access_version`, `cancel`, `dispose`
  существуют. **update_access_version — только access-only**, не rebake
  перемещённых стен. Устаревшую geometry нужно отменить/переснять через владельца.
- `path_job_queue.gd::cancel(owner)` / `dispose()` есть; остановка действующих
  jobs/served receipts должна предшествовать physical mutation. Нельзя вызывать
  private `_invalidate/_publish` как универсальный публичный move API.

### Candidate editor: готовые общие gates, но не специальные владельцы

- `tools/godot/map_editor_candidate/.../preview_host_bridge.gd::attach(...)`
  сканирует только непосредственных children с `source_id`, собирает sibling
  CollisionObject3D и явно locks print001. PrintshopInterior без source_id
  эта регистрация не охватывает.
- `object_registry.gd::apply_record(id,record,dry_run)` preflights targeted
  participants/filters и запрещает изменение protected entry; `create_copy`
  умеет статические participants, не service/custody/source identity leases.
  Снять editable=false или подменить source/hash не является адаптером.
- `tools/godot/map_editor_assembly_candidate/catalog_factory.gd::configure`
  принимает trusted `special_building(root,visual,source)` callback для
  bank/detention. Ответ `{ok:true,handled:true}` — **spawn-only admission**;
  отдельные move/delete/clone/load/rollback/rebind callbacks не реализованы.
  Factory сохраняет `gameplayActive=false`, даже если визуал есть.
- `editor_host_adapter.gd::mount(main,callbacks)` требует настоящие owner
  `pause_gameplay/cancel_pause/verify_pause/resume_gameplay/transaction_ready/
  ground_patch`. `enter/leave` проверяют owner/request/token receipts. Это
  reusable lease gate, не уже подключённый service/printshop relocator.

### Browser/source APIs: механика, которую нельзя потерять при переносе

- `building_entry_profiles.mjs::createAdditionalBuildingEntry(...)` поддерживает
  bank shell physical doorway, room/vault/partition layout. Его API:
  `getCollisionBodies`, `containsInterior`, `floorHeight`, `ceilingHeight`,
  `approachPoint`, `roomPoint`, `roomCenterPoint`, `vaultPoint`, `interact/update`,
  `dispose`. Cached static bodies, sampleBounds и baseWorldY вычислены при attach;
  произвольное последующее движение визуала их автоматически не перестраивает.
- `detention_native_sites.mjs::createDetentionNativeEntry(...)` возвращает
  `getCollisionBodies`, floor/ceiling/containsInterior, routePoints,
  `setEntranceOpen/setGateOpen`, `approachPoint/roomPoint`, `update/dispose`.
  `detentionDestination(site,nativeReady=false)` и `detentionLocalToWorld`
  дают source stop/handoff/intake/release. `nativeReady` должен подтверждать
  физический владелец, не редактор.
- `npc_detention_access.mjs::createNpcDetentionAccess({getEntries,worldScale})`
  сопоставляет destinationId с detentionId/instance.id, сверяет расстояние
  custodian к **instance.transform.positionM**, управляет physical gate и
  сообщает фактическую clearance. Перенос без актуальной destination/instance
  bookkeeping ломает доступ даже при правильной визуальной позиции.
- `native_print_shop_service_station.mjs::createPrintShopServiceStation`
  фиксирован на pilot001; requires siteRevision + validateLayout. `layout`
  содержит world anchors, station/room/door IDs; counter collider cache и
  door sweep actor ranges зависят от attach placement. Есть requestDoor,
  update/getCollisionBodies/dispose, но не произвольный editor transform API.
- `service_pilot23_candidate/walk_host.mjs::createStationaryServiceWalk23`
  устанавливает source merchant через `bridge.installStationaryServiceMerchant23`;
  `dispose` вызывает registration.unregister, disposeServiceVisits,
  removeGroup(station), station.dispose и host.invalidateNavigation. Это реальный
  teardown lifecycle, **не** право клонировать employed actor или merchant ID.
- `walk_map_editor_scene_rebuild_bridge.mjs::createWalkMapEditorSceneRebuildBridge`
  требует compileArtifacts/buildGeneration/resolveBuildingIds/snapshotGeneration/
  installGeneration/verifyInstalled/restoreGeneration и release/dispose callbacks.
  `requestRebuild` проверяет digest/groups/collision-entry-minimap и visual proofs.
  Нельзя считать этот source bridge native implementation или использовать
  `walk_preview.refresh()` вместо его атомарного verify/rollback контракта.
- `police_snapshot.mjs::capturePoliceProtectedCells/policeShapesFromAddendum`
  читают immutable police union; здесь **нет** move/permission API.

## Exact owner callbacks ещё нужны (не существующие методы)

Следующий перечень — требования к новой реализации, **не найденные callable
названия**, которые можно уже сейчас вызвать. Общий владелец main/сцены должен
дать такой transaction contract вместе с owners interior/service/custody/nav:

| Операция | Обязательное подтверждение владельца перед document/history commit |
|---|---|
| Move/rotate/scale | Paused lease с остановленными door/service/actor/path jobs; source-ID/SHA и before-state snapshot; вычисление Δ к immutable source; stage всех visual/collider/floor/door anchors, sweeps, rooms, sample bounds, HUD/spawn, stop/route/minimap и nav generation; физический swap→owner nav/authority verify→commit либо точный rollback. Масштабирование требует отдельных ranges/radii/ceiling/nav доказательств. |
| Delete | Отсутствие occupants/active booking/vault/visits либо согласованный source-owner выход; unregister site/destination/merchant/access; invalidation jobs/receipts; restore collision masks/render state на отказ; не удалять canonical world bank/police только потому, что удалён его visual alias. |
| Clone/add | Новый editor ID; source asset/resource sharing без clone canonical `bank:*`, `detention:*`, merchant/employee/visit ownership. Владелец выдаёт новый безопасный site/authority identity и точный интерьер/door/Nav package либо явно отдельный geometry-only object; нельзя взять pilot001 package для нового ID. |
| Fresh load/import | Source-bound patch validation до сцены; все источники immutable; rebuild владельцем **derived** anchors/runtime records по patch, не изменение исходного source transform/hash в обход attach guard; staged lifetime/current-session receipts; свежие actor/nav/access generations; save→load→door/service/custody/route parity на чистой сцене. |
| Undo/redo и failure | Такие же проверки и owner stages, не просто обратный visual delta. Состояния public/service fractions+targets, employee/customer/visit/custody leases, nav generation, collider/filter state и document/history должны вернуться точно. |

До реализации и проверки этих owners корректный пользовательский статус:
«Типография001: перенос интерьера и служб ещё не подключён»,
«Банк/изолятор: требуется игровой адаптер»,
«Главный комплекс/красный мост: источник защищён, semantic adapter отсутствует».
Нельзя завершать требование «двигать все здания» отчётом о перемещённом GLB.

## Рекомендуемая следующая ограниченная реализация

1. Начать с **print001 transaction adapter**, поскольку он реально есть в
   текущем native block: paused owner lease, separate interior root and anchors,
   public/service door state, HUD, source jobs/nav recapture и exact rollback.
2. На чистой headless сцене проверить move/rotate→public E/service proximity/
   floor/wall/sweep parity→undo/redo→save/fresh load; не открывать вторую GPU-игру.
3. Затем bank/detention создать реальные native owner adapters, отдельно
   original canonical gameplay migration и editor copy identity policy.
4. Police/red bridge сначала экспортировать exact immutable semantic graph;
   любые изменения их источников согласовать с main/topology/custody owners.

Никакого исполнения кода/сцены или изменения этих операций аудит не производил.
