# Редактор карты `/walk` — изолированная первая веха, 23 сентября 2026

## Поручение пользователя

Встроить в настоящую `/walk` понятный 3D-редактор, открываемый клавишей `K`:

- вид сверху и свободный полёт;
- выбор, добавление, перемещение, поворот и удаление ПКМ;
- все существующие дома и объекты карты;
- асфальт, обычные/просёлочные дороги, земля, трава, фонари, знаки, памятники и последующие типы;
- undo/redo, безопасное сохранение, импорт/экспорт и подготовка публикации;
- без ухудшения графики, коллизий и игровых механик.

После фактического завершения и LIVE-приёмки этого этапа следующая задача —
редактор персонажа по `docs/ai/CHARACTER_EDITOR_NEXT_PHASE_20260923.md`. До
завершения карты этот следующий этап не должен забирать её агентов или менять
production-файлы.

## Реализовано изолированно

Новые файлы не подключены к `walk_preview.mjs` и поэтому пока не влияют на текущую игру:

- `walk_map_editor_document.mjs` — lossless overlay-документ, композиция add/modify/delete, атомарные транзакции, undo/redo, проверка геометрии, импорт/экспорт, recovery checksum и preflight публикации;
- `walk_map_editor_ui.mjs` — русская панель с режимами, инструментами, категориями, поиском, выбором, подсказками и защищённым удалением;
- `walk_map_editor_input.mjs` — K/top/fly, editor ownership, text/modal/IME guards, WASD, Q/E, undo/redo, безопасный ПКМ 4px/500ms, pointer capture/cancel и защита от игровых mouse-событий;
- `walk_map_editor_protection.mjs` — trusted masks/source hashes/base records/footprint adapters, защита police/bridge/protected cells и gameplay-active/critical entities;
- `walk_map_editor_authored_adapter.mjs` — каталог и preview цельных authored building/decor groups с полным raw snapshot и stable source ID;
- `walk_map_editor_building_derive.mjs` — чистый compiler transform для footprint/clearance/collision/entry/corridor, 90° rotation, horizontal/uniform scale, dry road access и overlap/protected validation;
- `walk_map_editor_runtime.mjs` — единый lifecycle UI/input/host: вход/выход, фазы top/fly, выбор, protected delete, undo/redo/save и безопасный откат при ошибке host; отмена нового объекта доходит до host, удаляет 3D-preview и возвращает инструмент выбора;
- `walk_map_editor_palette.mjs` — проверенный каталог «На карте / Добавить новый» с русскими именами, адаптерными блокировками и четырьмя покрытиями;
- `walk_map_editor_surface_adapter.mjs` — непрерывная клеточная кисть доказанных native-покрытий без дыр при быстром движении;
- `walk_map_editor_ground_overlay.mjs` — lossless custom geometry для земли и просёлочной дороги: cells/polygon, protection masks, deterministic mesh-plan и render/road-navigation dependencies без подмены native tile 9/14;
- `walk_map_editor_camera.mjs` — точный capture/restore камеры и controls, top/fly навигация, pan/look/zoom/speed и очистка held input;
- `walk_map_editor_asset_placement.mjs` — кэшированный preview новой 3D-модели и fail-closed commit только через trusted record compiler;
- `walk_map_editor_storage.mjs` — checksum recovery, JSON export и атомарный import/restore через branded policy/preflight;
- `walk_map_editor_compile.mjs` — deterministic trusted-source compiler для topology/buildings/decor/custom, canonical artifacts SHA и настоящий publish receipt;
- `walk_map_editor_generated_adapter.mjs` — стабильные ID, lazy metadata/proxies и delete/transform contracts для road dressing, parking, exploration и других procedural plans; semantic ground-point picking позволяет выбирать объединённые generated объекты без отдельной Mesh-коробки и без покадрового обхода;
- `walk_map_editor_authored_prepare.mjs` — trusted prepare для переноса authored buildings: stale-before guard, полный derive footprint/clearance/collision/entry/corridor и объединение dirty dependencies;
- `walk_map_editor_walk_host.mjs` — готовая узкая связка runtime/camera/picking/move/rotate/place/paint/delete/commit/rebuild, чтобы production integration в `walk_preview.mjs` оставалась минимальной.
- `walk_map_editor_city_schema.mjs` — concrete branded adapters реальных topology 200×180, buildings 75, decor 164 и empty custom с lossless top-level/unknown fields.
- `walk_map_editor_publish_bundle.mjs` — повторно проверяемый publish bundle: manifest + ровно четыре canonical JSON artifacts с SHA-256, byte/name limits и injected download callbacks без прямой записи production source.
- `walk_map_editor_lazy_gate.mjs` — лёгкий capture-gate для первого `K`: без статических editor-зависимостей, один dynamic load, parity повторного K, retry после ошибки и безопасный late dispose; после успешной установки отдаёт K основному editor input.
- `walk_map_editor_files_dialog.mjs` — русский доступный файловый workflow: проект JSON, import/recovery preview с явным Apply, stale-session guard и подготовка пяти publish-файлов только через trusted callbacks.
- `walk_map_editor_autosave.mjs` — revision-aware debounce/idle recovery: dirty только после успешного commit/undo/redo/import apply, flush на close/pagehide/dispose, quota errors остаются dirty и не блокируют игру.
- `walk_map_editor_selection_visual.mjs` — отдельная editor-only рамка выбранного цельного объекта: золото/защищённый красный/preview зелёный, без изменения материалов и текстур объекта и без покадрового обхода сцены.
- `walk_map_editor_special_building.mjs` — audited full-rebuild compiler/preparer для особых зданий с отдельным trusted receipt; visual-only commit запрещён.
- `walk_map_editor_live_bootstrap.mjs` — side-effect-free factory полного editor graph из injected raw texts/live groups/services; source parsing, generated inventory, files UI и тяжёлые adapters создаются только после вызова factory/первого `K`.
- `walk_map_editor_generated_sources.mjs` — lazy bridge реальных road/parking/exploration/rail plan shapes в semantic generated collections, без импорта generators и без создания Mesh для каталога.
- `walk_map_editor_async_catalog.mjs` — cancellable background catalog loader: batches до 160, category priority, русский progress/retry, generation guard и cache replay без покадрового polling.
- `walk_map_editor_deferred_adapter.mjs` — staged owner facade: generated key/pick/command недоступен до атомарной регистрации соответствующей batch, затем O(1) routing к trusted owner.
- `walk_map_editor_decor_prepare.mjs` — authoritative transform/delete pipeline всех 164 authored decor records со stale guard, spatial validation, точными rebuild dependencies и rollback.
- `walk_map_editor_signal_placement.mjs` — safe road-control placement/prepare для трёх signal GLB и трёх approved sign GLB: real-road snap, grouped intersection semantics, occupancy/spatial checks и traffic/render/minimap dependencies.
- `walk_map_editor_ground_overlay_preview.mjs` — editor-only preview mesh земли/просёлочной дороги: combined geometry, bounded LRU cache, no per-frame rebuild, z-fighting guard и cancel/commit/rollback/dispose.
- `walk_map_editor_special_anchor_migration.mjs` — staged atomic executor для 3 банков и 3 detention sites: authored-shell coordinate authority, exact 27 consumers/5 artifacts, immutable digests, protection authorization, detached validate/install/live-verify, rollback и reauthorization undo/redo. По умолчанию объекты остаются locked до полного injected LIVE service.
- `walk_map_editor_generated_override_apply.mjs` — trusted применение semantic tombstone/transform override к реальным generated plans до Mesh: source revision/base signature guards, точные dependencies и полный rollback.
- `walk_map_editor_live_qa.mjs` — откатываемый сценарий будущей LIVE-приёмки: K/top/fly, preview/cancel/commit, короткий ПКМ против drag, save/reload, door/collision/minimap proof и frame/draw-call/triangle/catalog measurements без ложного PASS при отсутствии свежих проб.
- `walk_map_editor_visual_parity.mjs` — явный transition/acceptance-аудит визуала: геометрия, материалы, текстуры, anisotropy, тени, render flags и дочерние transforms должны остаться прежними; разрешается только заявленный transform/visibility корневого объекта.
- `walk_map_editor_topology_paint.mjs` — safe native-paint compiler для topology 200×180: только asphalt tile 0/grass tile 8, single cell/штрих, stale guards, building/entry/parking/access/protection checks, полная связность road graph, copy-on-write receipt/inverse и atomic rollback.
- `walk_map_editor_production_seam.mjs` — узкий lazy production-controller: первый чистый K, async bootstrap parity/retry/dispose, единый input ownership guard, точный capture/restore игрового состояния и policy подавления legacy editor только для `render=3d&renderer=walk`.
- `walk_map_editor_atomic_rebuild.mjs` — сериализованная detached-generation транзакция для будущего live renderer: snapshot → build → validate → single install → verify; build/validation не касаются live, partial install/verify failure восстанавливают точный prior generation, dispose отменяет staging.
- `walk_map_editor_generated_preview.mjs` — editor-only circle/rect ghost для semantic generated объектов: pointermove O(1), cumulative yaw, реальный root/material не меняется, Enter создаёт один transform command, Esc/reject/dispose освобождают ресурсы.
- `walk_map_editor_exploration_addition.mjs` — trusted addition/duplicate compiler для 7 tree, 4 monument и 10 furniture kinds: deterministic IDs, real-plan spatial validation, exact dependencies, inverse receipt и atomic rollback; unknown/custom-GLB kinds запрещены.
- `walk_map_editor_exploration_placement.mjs` — isolated placement service для добавления и дублирования exploration-объектов через preview/commit path; palette и host используют его только при наличии полного trusted capability.
- `walk_map_editor_legacy_7_2_import.mjs` — fail-closed converter старого `map_overrides.json`: переносит только доказанные native tile 0/8 и точные stable decor/building IDs, выдаёт аудит неоднозначных beach/tile записей и не принимает JSON-команды снятия защиты.
- `walk_map_editor_scene_rebuild_bridge.mjs` — production-ready bridge поверх atomic rebuild: сверяет document/source/artifact/generated-plan digests, topology, ровно 78 building roots, collision/entry/minimap receipts и visual parity до единственной установки; rollback восстанавливает exact prior generation.
- `walk_map_editor_production_adapter.mjs` — fail-closed runtime context adapter для production seam/scene bridge: exact raw sources/revisions, отдельные 78 building и 164 decor roots, capability-safe generated plans, input/camera ownership и frame hook; `horizontalScale` применяется как `[uniform*hx, uniform, uniform*hz]` без изменения материалов.
- `walk_map_editor_module_placement.mjs` — trusted placement path для 20 standalone plaza/curb/surface-transition/forest-path GLB: реальные SHA и socket nodes, material/water/slope contracts, полный spatial inventory, preview/commit/delete/reactivate и history без визуальной подмены.
- `walk_map_editor_walk_generation_contract.mjs` — точный контракт будущей detached generation для реального `/walk`: inventory 18 live-owned подсистем, exact 78/164 split, capability plans, ownership ledger, readiness/visual proof и single install без live mutation.
- `walk_map_editor_walk_generation_builder.mjs` — isolated detached builder поверх injected production factories: кэширует 33 unique templates для 242 authored roots, собирает 18 owned components вне live scene, проверяет 78/164 split/proofs и полностью очищает stage при partial GLB, live mutation или forged readiness.
- `walk_map_editor_module_integration.mjs` — lazy capability bundle для будущего bootstrap: собирает module compiler/preparer/live adapter, включает 68/68 palette contract, маршрутизирует только `placementMode=module`, даёт русские подсказки берега/уклона/перехода и откатывает document/root при rebuild failure.
- `walk_map_editor_walk_generation_install.mjs` — isolated one-swap installer: exact snapshot всех live references/arrays/controllers/listeners, install/verify/restore/release ordering, no-op повторной generation и exact rollback при partial install/verify failure. Current `walk_preview` anchors пока не экспортируют этот seam.
- `walk_map_editor_special_anchor_live.mjs` — lazy bootstrap capability для банков/detention: без сервиса показывает точную русскую блокировку; с полным authority service разрешает move/rotate без delete, выполняет special executor вместо generic rebuild, reauthorizes undo/redo/reload и сохраняет отдельную verified history.

Текущий изолированный editor-suite PASS, включая:

- `test_walk_map_editor_document.mjs`
- `test_walk_map_editor_input.mjs`
- `test_walk_map_editor_ui_contract.mjs`
- `test_walk_map_editor_protection.mjs`
- `test_walk_map_editor_authored_adapter.mjs`
- `test_walk_map_editor_building_derive.mjs`
- `test_walk_map_editor_runtime.mjs`
- `test_walk_map_editor_palette.mjs`
- `test_walk_map_editor_surface_adapter.mjs`
- `test_walk_map_editor_ground_overlay.mjs`
- `test_walk_map_editor_camera.mjs`
- `test_walk_map_editor_asset_placement.mjs`
- `test_walk_map_editor_storage.mjs`
- `test_walk_map_editor_compile.mjs`
- `test_walk_map_editor_generated_adapter.mjs`
- `test_walk_map_editor_walk_host.mjs`
- `test_walk_map_editor_city_schema.mjs`
- `test_walk_map_editor_authored_integration.mjs`
- `test_walk_map_editor_publish_bundle.mjs`
- `test_walk_map_editor_lazy_gate.mjs`
- `test_walk_map_editor_files_dialog.mjs`
- `test_walk_map_editor_autosave.mjs`
- `test_walk_map_editor_selection_visual.mjs`
- `test_walk_map_editor_special_building.mjs`
- `test_walk_map_editor_live_bootstrap.mjs`
- `test_walk_map_editor_generated_sources.mjs`
- `test_walk_map_editor_async_catalog.mjs`
- `test_walk_map_editor_deferred_adapter.mjs`
- `test_walk_map_editor_decor_prepare.mjs`
- `test_walk_map_editor_signal_placement.mjs`
- `test_walk_map_editor_ground_overlay_preview.mjs`
- `test_walk_map_editor_special_anchor_migration.mjs`
- `test_walk_map_editor_generated_override_apply.mjs`
- `test_walk_map_editor_live_qa.mjs`
- `test_walk_map_editor_visual_parity.mjs`
- `test_walk_map_editor_topology_paint.mjs`
- `test_walk_map_editor_production_seam.mjs`
- `test_walk_map_editor_atomic_rebuild.mjs`
- `test_walk_map_editor_generated_preview.mjs`
- `test_walk_map_editor_exploration_addition.mjs`
- `test_walk_map_editor_live_bootstrap_exploration_addition.mjs`
- `test_walk_map_editor_legacy_7_2_import.mjs`
- `test_walk_map_editor_files_legacy_7_2.mjs`
- `test_walk_map_editor_scene_rebuild_bridge.mjs`
- `test_walk_map_editor_production_adapter.mjs`
- `test_walk_map_editor_module_placement.mjs`
- `test_walk_map_editor_walk_generation_contract.mjs`
- `test_walk_map_editor_walk_generation_builder.mjs`
- `test_walk_map_editor_module_integration.mjs`
- `test_walk_map_editor_walk_generation_install.mjs`
- `test_walk_map_editor_live_bootstrap_special_anchor.mjs`

Актуальный полный прогон: **56/56 test files PASS**, **251/251 tests PASS**; `node --check`: **50 editor modules PASS**. Publish принимает только живой branded compile receipt, связанный с document/revision/canonical SHA, точными topology/buildings/decor SHA, protection digest и output artifacts. `compiled:true`, cloned/plain receipts, ambiguous base resolver и пустой spatial footprint отклоняются.

## Инвентарь карты

- Здания: 75 `buildings_placement.v1.json` + 3 `detention_native_sites.v1.json` = 78.
- Авторский декор: 164.
  - 128 фонарей, 8 фонтанов, 18 скамеек, 5 клумб и 5 урн.
- Палитра: 68 моделей: 45 базовых + 3 road signs через существующий road-control adapter + 20 standalone modules через verified module adapter; при двух полных capabilities доступно 68/68. Также 4 покрытия.
- Generated exploration: 2 036 деревьев, 22 памятника, 382 furniture/lamps/decor.
- Grass: 72 970 tufts / 622 patches по актуальной worker-цепочке.
- Road dressing current plan: 6 449 markings, 445 signs, 60 signals.
- Parking: 39 lots, 59 bays, 57 signs, 78 surfaces/driveways.
- Railway: 1 alignment, 2 stations, 12 crossings, 17 crossing signals.
- Native topology: 200×180, 4.1 m/cell; protected mask 1 536 cells.

Фактическая вкладка добавления: 68 моделей + 4 покрытия. Базово доступны 45/68; при полном road-sign и module-placement capability доступны 68/68. Все 33 типа, уже используемые 242 authored records, представлены. Collection GLB исключён. Три signal GLB и три approved sign GLB проходят полный signal-placement adapter. Для 20 plaza/curb/surface-transition/forest-path GLB проверены реальные SHA/bytes, collision/clearance и socket nodes берега/воды, материалов и уклонов; guessed dimensions/custom paths отсутствуют. Для native topology доказаны только `asphalt → tile 0` и `grass → tile 8`. `tile 9` — sidewalk/curb, `tile 14` — sand; поэтому `earth`/`dirt-road` не подменяют эти коды. Земля и просёлочная дорога разблокируются только при полном ground-overlay preview/compiler path; commit сохраняет custom overlay, а topology grid остаётся без изменений.

Native asphalt/grass path подключён внутри isolated bootstrap: stroke проверяет sourceRevision, каждую исходную клетку, здания/entry/parking/access/protection/water и связность road graph. ПКМ restore возвращает только trusted base tile 0/8; base 9/14/16/unknown fail closed. No-op не создаёт commit/rebuild. Earth/dirt остаются отдельными custom overlays. Undo/redo/save/reload и generated lazy=0 до K проверены.

Generated adapter держит 8 000 synthetic records без покадрового обхода: owner routing O(1), cached sorted summaries, bounded proxy queries. CPU-only Node benchmark создания+сортировки+8k enumerate+2k lookup после удаления дублирующего `raw` snapshot ≈348–375 ms / ≈11.2–11.4 MiB против прежних ≈440 ms / ≈20 MiB. Это не LIVE/FPS замер. В production создавать после загрузки мира/по первому K, не добавлять эти ~0.35 s к стартовой загрузке игры. UI строит не более 160 карточек за раз и подгружает следующие по кнопке.

Actual generated-sources bridge индексирует 9 659 semantic objects только после первого `K`: observed Node construction ≈620–657 ms и ≈17–18 MiB, затем `hasKey/record` работают через Map O(1). Cosmetic dash/edge/arrow markings допускают безопасный tombstone; crosswalk/stop/yield остаются locked. Signs и незаблокированный exploration-декор допускают validated transform/delete; парковка удаляется только атомарно всей группой lot; parking child surfaces, signal groups и railway topology остаются locked. Любой generated override проверяет sourceRevision/baseSignature и откатывает исходный plan при failed rebuild. Это CPU-only измерение, не LIVE/FPS.

Bootstrap теперь применяет registered generated override к единому trusted plan snapshot до Mesh. До регистрации batch команда недоступна; forged adapter/locked target/stale revision/base signature отклоняются. Rebuild получает новый plan только при изменившейся override signature или rollback; обычные edits не пересобирают все 9 659 объектов. Исправлены канонические несовпадения `null`/`0` для `y/yaw` и отсутствие `transform` у suppress override. Undo/redo и reload повторно получают тот же semantic plan.

Exploration addition теперь также подключён внутри isolated bootstrap: палитра показывает 7 деревьев, 4 памятника и 10 видов мебели только при полном injected service. Add/duplicate проходят через registered generated owner и trusted `explorationDecor` plan до Mesh; дубликат сохраняет variant/scale/yaw/zone и неизвестные trusted поля, но получает новый deterministic ID. Перед commit проверяются topology/protection, здания и входы, парковки, occupancy и railway. Renderer failure возвращает документ и полный prior plan; undo/redo/save/reload проходят. До первого K/catalog/action generated plan не загружается.

Files workflow автоматически различает текущий проект и legacy 7.2 v20/wrapper `/__studio_map`. Legacy сначала проходит dry-run и показывает русский отчёт; Apply остаётся disabled до успешных protection/preflight и использует тот же atomic storage import. Реальный `map_overrides.json` даёт 2 converted strokes/7 доказанных cells, 107 ambiguous decor и 4 unsupported записи; неоднозначные записи не применяются. Audit download не содержит raw значений. Cancel/Escape/stale/error не меняют карту, а failed host replacement возвращает прежнюю session.

Статический lazy gate занимает 3 566 raw / 1 293 gzip bytes; весь редактор и большой generated inventory создаются только после первого `K`. CPU-only predicate benchmark 1 000 000 смешанных key events ≈49 ms в Node; это не браузерный frame-time замер.

MVP подключает ровно 78 домов первым независимым адаптером. Дороги, трава, signs/markings, exploration decor и railway индексируются лениво и не задерживают открытие редактора.

## Stable IDs и lossless policy

Ключ — `dataset:id`, через `walkMapEditorEntityKey`; runtime UUID, faceIndex и instanceId не сохраняются.

- Buildings и detention используют dataset `buildings`, sourceFile сохраняется отдельно.
- Authored decor использует dataset `decor`.
- Новые procedural объекты используют dataset `custom` и trusted catalog adapter.
- Generated objects сохраняют source revision fingerprint и semantic fallback; отдельный transient instanceId не является ID.
- Исходный record сохраняется полностью, включая неизвестные будущие поля и `_private` ключи.
- Удаление — tombstone/net patch с полным before snapshot; исходный JSON не стирается.

Композиция net patch:

- add → move остаётся add с новым after;
- add → delete сворачивается в отсутствие patch;
- modify → modify хранит первый base before и последний after;
- modify → delete хранит исходный base before;
- delete → restore исходного record сворачивается в отсутствие patch.

Stale `before`, duplicate add/delete, отсутствующий trusted base resolver и missing protection policy отклоняют всю транзакцию атомарно.

## Графика и transform

Каждый дом в live является одним `THREE.Group` с `group.userData.instance`. Preview меняет только group transform; record не мутируется.

Обязательно сохраняются:

- `positionM`, `yawDegrees`, `uniformScale`;
- `horizontalScale` по X/Z;
- `modelLocalOffsetM`;
- `preserveSiteBounds`;
- все неизвестные поля record.

`horizontalScale` уже учтён: preview/cancel не делает дома уже/шире и не меняет силуэт.

Selection visual вычисляет глубокие bounds один раз при bind/invalidate; перемещение/поворот обновляют рамку O(1), без обхода иерархии большого здания на каждом pointermove. Rebuild инвалидирует кеш.

## Коллизии, входы и навигация

Визуальный сдвиг Group не является завершённым commit. После перемещения/удаления здания compiler/host обязан пересчитать и атомарно заменить:

- footprint, clearance, entry corridor и door anchors;
- building entry, doors/glass, interior floor/camera и room helpers;
- walk collision и vehicle collision;
- building sample/camera indexes;
- parking и road-access validation;
- decor/grass keepouts;
- minimap и static render batches.

До появления scoped derived compiler допустим один full world rebuild после pointer-up/Enter. Rebuild во время pointermove запрещён. Если новый derived world не прошёл validation, live scene и document остаются на предыдущей версии.

Чистый compiler уже реализован для обычных authored buildings. Он сохраняет исходный record, неизвестные поля, `horizontalScale` и `modelLocalOffsetM`, ограничивает первую версию безопасными поворотами 0/90/180/270°, проверяет воду/protected cells/пересечение и ищет прямой сухой выход к дороге. Сквозной integration test проходит real adapter → trusted prepare → derive → document/protection transaction → rebuild; stale preview, invalid 45° и injected rebuild failure оставляют document и scene на предыдущей версии.

Отдельно проаудированы восемь special records. Мэрия и больница допускаются только через явную protected authorization + trusted `mode=full, visualOnly=false` receipt и полный rebuild всех dirty dependencies. Три detention видимы, но locked до доказанного пересчёта stopFootprint/stopLane/detention anchors. Три банка видимы, но locked: placement сам помечает незавершённую host gameplay/original-anchor migration. Любой `gameplayActive` record также locked. Защита не ослабляется ради редактора.

Live inventory test показывает 75 records из buildings artifact + 3 detention из отдельного source, итого 78 зданий в каталоге. Nightclub обычный и редактируемый; лишняя блокировка снята. Detention остаются отдельным read-only source и не смешиваются с canonical buildings artifact из 75 records.

Подробный read-only аудит: `docs/ai/WALK_MAP_EDITOR_SPECIAL_ANCHOR_AUDIT_20260923.md`. У банков сейчас три несовпадающие системы координат (legacy BANKS, rebuild ledger, authored shell entry); detention используют stopFootprint/stopLane/collision и отдельные client/server destination/convoy/jail consumers. Без выбора authoritative bank exterior, миграции hardcoded police coordinates и atomic executor receipt из 27 consumers/5 artifacts эти шесть объектов остаются locked.

Обычное удаление здания теперь проходит trusted prepare и помечает полный набор rebuild dependencies. После rebuild reversible tombstone скрывает root и убирает запись из каталога; undo возвращает запись, root и authoritative transform. Special/locked удаления этим не разблокированы.

## Защита

Protection policy использует только trusted host data:

- полные SHA-256 topology/buildings/decor;
- `protectedMask`, `policeMask`, `bridgeDeckMask`;
- trusted base records и gameplayActive;
- trusted footprint adapters.

JSON не может сам снять защиту. Missing base/adapter/report fail closed. Base resolver строго tri-state: `found/absent`; `undefined`, `null`, add поверх базы, modify/delete без базы и несовпадающий before отклоняются. Protected action требует structured authorization с `approvalId`; clear и protected действия получают отдельные immutable branded audit receipts. Undo/redo пространственных действий повторно проходят актуальную policy.

Красный мост, полицейский комплекс, банки/активные здания и попадание нового footprint в защищённую область не меняются случайным ПКМ.

## Минимальная интеграция в `walk_preview.mjs`

Сейчас интеграция отложена до согласованного окна Координатора20: у него единственная LIVE-вкладка и текущий NPC checkpoint.

Свежий source-аудит `walk_map_editor_walk_generation_contract.mjs` показывает `ready=false` для текущего `refresh()`: он вызывает `clearContent()` и освобождает прежние ресурсы до полной проверки новой сборки, напрямую мутирует `content`/minimap/navigation и пока не экспортирует detached build/install/restore/parity receipts. Инвентарь всех 18 live-owned подсистем уже зафиксирован, а целевой injected contract проверен, но production подключать до появления этих hooks нельзя — иначе ошибка GLB или renderer могла бы оставить город частично очищенным. Это реальный оставшийся integration blocker, не проблема UI/editor document.

Нужны четыре input guards:

1. editor ownership включить в общий `mercenaryInputBlocked()`/`hudInputBlocked()` путь;
2. отдельно guard RMB waypoint handler;
3. `pointerlockchange` не должен повторно включать OrbitControls при active editor;
4. `refresh()` не выполняется во время editor preview.

При assembly хранить отдельный `buildingGroups` только для 78 зданий, затем `editor.syncWorld(...)`. Нельзя брать все 242 `instances` за здания.

Текущий assembly в `walk_preview.mjs` использует `group.scale.setScalar(t.uniformScale??1)`. При интеграции редактора это место обязано применять `horizontalScale` как `[uniform*hx, uniform, uniform*hz]`; иначе full rebuild после сохранения визуально исказит дома, хотя preview был правильным.

Вход: releaseControls, закрыть arsenal/menu/minimap, снять pointer lock, сохранить camera/controls, отключить game controls. Выход: cancel незавершённого gesture, восстановить camera/controls, очистить held keys, затем вернуть phase `game`.

Legacy editor 7.2 в `world.html` автоматически делает `init()` на строке около 75740 ещё до `rendererSelection`; для `renderer=walk` этот вызов надо пропустить, иначе F8/save/load и старые overrides конфликтуют с новым K-editor. Старые 4.0/5.0/7.0/7.1 уже оставлены как source reference и не запускаются.

## LIVE acceptance первой вехи

`walk_map_editor_live_qa.mjs` требует transaction-bound fresh visual phases `before-open`, `editor-idle`, `move-preview`, `move-cancelled`, `move-committed`, `saved-reloaded`. Idle/cancel сравнивают точные node/resource/transform references, preview разрешает transform только выбранного root, commit/reload не допускает downgrade geometry/material/texture/anisotropy/shadow/LOD/binding. Отдельный catalog proof требует ровно 78 unique building roots и ровно 8 видимых protected records с причиной. Missing/reused/mismatched proof остаётся `unverified`, а не PASS.

1. Каталог показывает ровно 78 unique buildings, 0 decor в категории домов.
2. Все 78 выбираются кликом и списком по одному stable key.
3. Move/rotate preview сохраняет silhouette/horizontalScale; Esc возвращает точно; Enter даёт один undo item.
4. ПКМ удаляет только коротким кликом; drag не удаляет; protected action требует подтверждение.
5. В editor E/Space/X/Q/R/LMB/RMB не запускают игру; после выхода всё работает один раз без залипания.
6. Дождаться >15 секунд: auto-refresh не уничтожает selection/preview.
7. После commit дверь, interior, collision и minimap находятся в новом месте, а в старом их нет.
8. Undo/redo и save/reload восстанавливают полный record/ID.
9. Одна вкладка, до/после p50/p95 + draw calls/triangles; idle editor не обходит 78 домов каждый кадр.

До прохождения пункта 7 результат называется preview, не готовым редактором зданий.
