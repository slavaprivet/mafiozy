# Проверенный кандидат редактора Godot

Исходный пакет сохранён вне рабочего res://, чтобы промежуточная разработка
не нарушала открытый редактор/единственную игру. Не является отдельной GPU-игрой.

Сборка main/player/project/export и запуск принадлежат Координатору21.
Интеграция: `scripts/map_editor/preview_host_bridge.gd`, явные begin/end callbacks.
Сначала остановить управление, физику и устаревшие навигационные receipts;
после изменений пересобрать зависимости и только тогда возвращаться в play.
Код controller.handle_input вызывается до gameplay handlers; текст/GUI не должны
передаваться в игровой ввод при активной edit lease.

Все 7 тестовых suites этого проекта повторно проверены Godot4.7.2 headless.
Дополнительный `map_bundle.gd` — data-only файл публикации: object patch,
ground patch и проверенные SHA256 ресурсов. Его отдельные11checks PASS;
контрольная сумма не заменяет игровые права или допуск доверенного host.
`map_bundle_store.gd` сохраняет оба слоя в одном JSON с read-back и резервной
копией;13native checks PASS. Загрузка проверяет базу, наличие ресурсов и ground
validator, но сама не устанавливает документ в игровую сцену. Повторная загрузка
объектов/земли должна быть общей транзакцией владельца, не двумя независимыми.
Сохранённый кандидат земли: `../map_editor_ground_candidate`,126+66+19956
native checks PASS. Подключение обоих документов в игровой workflow ещё нужно.
Проверки сценариев и тесты исходных assets находятся также в
`outputs/map_editor_assets_factory`. Документ приёмки и ограничения:
`docs/godot/MAP_EDITOR_NATIVE_PACKAGE.md` относительно корня репозитория.

База девяти runtime-модулей — frozen-кандидат
`outputs/map_editor_wip/scripts/map_editor`; UID и кэш не являются поставкой.
Controller дополнительно исправлен: повторный отказ scene admission при импорте
не заменяет документ/историю, staged clones удаляются.12native checks PASS;
controller/additions/controls/hotpath359 suites повторно PASS.
Обычные действия обрабатывают только одну запись; импорт/загрузка проверяют
всю карту. UI имеет русский поиск/категории, полёт/вид сверху и подсказки.

Не считать пакет готовностью всей карты: procedural/ground adapters,
interiors/story dependencies, gameplay gates и один LIVE прогон ещё обязательны.
Публикация означает проверенный файл карты, не неподтверждённую загрузку на сервер.

`editor_workspace.gd` объединяет UI/input объектов и земли. Внедрить после
controller.setup, brush.setup и renderer.configure: workspace.setup(controller,
brush, ground_panel, renderer, persistence_actions, transaction_ready).
Main вызывает workspace.handle_input FIRST и отдельно блокирует gameplay при
controller.active даже для GUI/text событий, которые возвращают false.
Обе панели имеют кнопки «Объекты / Земля и дороги», общий save/load/import/export
идёт только к trusted persistence_actions(action,payload), не к двум document
stores. Input groundmode никогда не удаляет object через RMB. Brush committed
завершает renderer transaction; отказ cleanup блокирует K/actions до retry.
Rollbackfailure требует owner restore_session, не простого cleanup retry.
25synthetic actual-panel/inputchecks PASS, не live/main acceptance.

`editor_host_adapter.gd` — согласованный owner-only adapter, без main edits.
mount(existing_main,callbacks) требует pause_gameplay(request), cancel_pause(request),
verify_pause(receipt), resume_gameplay(receipt,objects,ground),
transaction_ready(receipt), ground_patch(). Передать returned enter_gate/leave_gate
в controller.setup и transaction_ready в workspace.setup, затем bind_workspace.
pause receipt содержит owner_id=current main instance, request_id=request.request_id,
token=owner-issued nonempty string. Resume возвращает ok/owner_id/request_id,
только после exact state restore и geometry/nav/water readiness. Callbacks должны
атомарно отказаться: partially resumed session становится fault и остаётся
input-blocked до восстановления владельцем. Ни один Boolean из JSON не callback.
Main routes adapter.handle_input FIRST, затем if adapter.gameplay_blocked():
не выполняет gameplayinput/update; GUI false не является разрешением играть.
Adapter не меняет processflags, SceneTree.paused, authority или source hash.
13native callback/lifetime/reentrancychecks PASS; actual main hook ещё pending.

`catalog_ui.gd` derives narrow display rows from source catalogue, using original
Russian labels/categories. Only registry.has_object/is_editable admits availability,
never catalog.available. Protected present objects say «нужен игровой адаптер»,
missing objects «ещё не подключён к сцене». Selection label lookup changes no
source records. Full9901 inventory9checks PASS, no heavy geometry/source duplication;
display remains bounded160. preview_host_bridge.attach optional seventh argument
source_catalog enables these labels/inventory while preserving explicit locks.

Atomic source extensions now admitted independently: atomic_map_import.gd,
MapDocument/ObjectRegistry/EditorController + ground candidate model/renderer.
Actual242 authored objects + fresh243 reconstruction/full200x180 terrain:
66599 native checks PASS, repeated import817275us CPU (not gameplay FPS).
Both documents commit silently only after scene staging and trusted nav/water
admission. Failed rollback retains receipts; committed cleanup only retries
finalize, never scene-only rollback. Normal mutation APIs remain guarded.
Registry checkpoints additionally require same scene parent/lifetime;7checks PASS.

`editor_persistence.gd` configures shared file workflow with controller/ground/
atomic owner + trustedresource tables/readiness/text read-write hooks. save/load
use user://maps/current-map.json; export writes user://maps/published.json plus
text through the owner hook; import/load only call atomic.install_bundle.
11 file/routing checks PASS; full actual UI+atomic assembly independently passes
12777 checks on actual242/fresh243 authored objects and full200x180 ground.
Workspace retry_pending routes before ordinary readiness and both panels have
«Завершить / восстановить обновление». Owner-confirmed readiness still gates exit.

Reproducible source-only fixture: `tools/godot/map_editor_assembly_candidate`,
staged by `tools/godot/stage_map_editor_assembly.mjs --stage`. All196 original
GLBs/30212460bytes admitted by SHA; no import cache or UID copied. Fresh headless
Godot import then assembly12777PASS; load897902us CPU, not game startup/FPS.
15 stage checks PASS. Main/gameplay/nav/water remain owner-supplied fixtures;
production and GPU acceptance are still pending.

Immutable numeric transport gate: `trusted_json.gd` accepts only exact source
or its exact deterministic Godot JSON roundtrip; caller values are never
normalised and no epsilon is used. Registry caches admitted variants once.
Controller restores original trusted source/header/transform extras after
admission, preventing drift across save cycles. 133 native checks PASS,
including 30 cycles and explicit adjacent IEEE64 rejection. Controller/additions,
hotpath359 and composite36 repeated PASS. Ordinary targeted actions still do
not serialise the world (synthetic242 move+undo p50/p95 479/627us, not FPS).
