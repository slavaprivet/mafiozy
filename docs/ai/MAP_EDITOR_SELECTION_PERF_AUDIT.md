# Редактор: выбор, рамка и inclusive input cost

Source-only аудит и новые candidate файлы, 27 сентября 2026. Frozen
registries/controller/Host/Workspace/pause modules не изменены. GPU/main/Git
не тронуты. ProductionWired=false.

## Главное обнаружение

`Controller.handle_input` не вызывает pick на MouseMotion. Pick выполняется
только LMB press и short RMB release. Поэтому ускорение поиска объекта само
по себе не устраняет заметную цену каждого движения мыши.

При действующем Host→Workspace object-mode→Controller:

1. Host.handle_input вызывает _lease_valid → Compound.verify_pause.
2. Workspace._ready_for_action вызывает Host.transaction_ready, снова
   _lease_valid → Compound.verify_pause.
3. Host вызывает Compound.transaction_ready → Compound.verify_pause.
4. Scene.transaction_ready проверяет сцены до owner callback и после него.
5. Compound.transaction_ready проверяет обоих owners после ready callback.

Итого **6 полных scene checks + 4 animation checks на MouseMotion**, а
registry.pick не вызывается. Animation._state каждый раз собирает словари и
читает engine phase/queue/root-motion properties. Scene проверяет flags всех
участников, metadata/lifetime/parent, body state, fields и Timer phase.

Новый `test_selection_input_cost.gd`, actual native fixture: 50 RigidBody3D,
8Timer, 8AnimationPlayer; реальные Host/Workspace object branch/Controller,
реальные v2 owner callbacks/capsules. 74 checks PASS; mousemotion p50 4410us,
p95 5266us. Pick calls 0, world_bounds calls 1 (initial empty selection).
Search/pointer GUI guards сохраняются; изменённый настоящий Timer приводит
к Host fault, никакого cachetrue нет. Это object-mode method fixture, НЕ
fullground Workspace.setup и НЕ actual NPC/server/nav admission. Не FPS.

Нельзя просто кешировать `verify_pause=true` между events/physics frames.
Следующий root-reviewed пакет должен либо получить настоящий source-owner
revision/checkpoint fast-proof, либо передавать capability строго внутри
одного synchronous проверенного input call с повторной admission после
owner callbacks. Такой capability не должен переживать callback, reentry,
authority/control change, await или frame. K/resume/mutations требуют всех
своих admissions. В этом аудите checks НЕ ослаблены и bypass не добавлен.

## Новые изолированные candidates

`selection_spatial_index.gd`: BVH мировых AABB, dynamic clone insertion,
targeted parent refit, исключение deleted/discarded bounds, original registry
iteration order при exact равном hit distance. Клик не читает world_bounds
всех объектов. Invalid ray и endpoint semantics сохраняют reference scan.

Конфигурация принимает trusted registry (ids/has_object/world_bounds) и
`bounds_revision(cached_revision) -> {ok, revision:int, from_revision:int,
changed_ids:Array}`. Source owner должен выдавать полный journal всех bounds
changes с cached_revision, включая move/rotate/delete/undo/copy/discard,
rollback/import/full scene replacement. Для полного replacement используется
rebuild. Gate — pure synchronous read-only getter; off-lease/unknown generation
возвращает ok:false. Reentrant gate отказывается, не мутирует stack/index.

Owner revision отличается от admitted → pick_result `{ok:false,error}`,
никогда stalehit. refresh_ids обязан покрыть ВСЕ owner-reported changed_ids;
неполный refit не принимает новую revision. Gate перепроверяется после чтения
bounds до установки нового индекса. Caller не может произвольно объявить
чужую changed_ID list исчерпывающей. На каждом successful record action/undo
нужен targeted refresh; atomic fullinstall/rollback требует rebuild либо
реально исчерпывающий owner delta. Root сейчас ещё не выдаёт этот receipt —
candidate не подключать с произвольным `true` или номером document history.

`pick_result` должен использоваться root integration: отказ показывать как
ошибку readiness, а не очищать выбор. Compatibility `pick` возвращает пустую
строку на отказ; нельзя незаметно заменить этим frozen picker без такого
guard. Root/source owners остаются единственным источником текущих bounds.

**Semantics:** composite/procedural picker использует merged WORLD AABB.
NativeRegistry.pick использует transformed LOCAL per-mesh AABB. Они различны!
BVH candidate сохраняет именно мировую семантику composite/procedural. Для
NativeRegistry без composite нужно сохранить local narrowphase после
broadphase — в этом пакете не реализовано и не объявлено готовым.

`selection_outline_cached.gd`: один unit ImmediateMesh/материал на весь срок
рамки. show_bounds изменяет только transform/visibility, exact 24 endpoints
сохраняются. Original visual materials/geometry не меняет; original gold,
unshaded/no-depth/no-shadow settings остаются. Parent/controller должен
сохранять прежнюю local placement convention рамки.

## Измерения

| Сценарий | Linear p50/p95, us | BVH p50/p95, us | Проверки |
| --- | --- | --- | --- |
| Synthetic9901 WORLD AABB owner,160 одинаковых лучей | 5817 / 7260 | 43 / 64 | 334 PASS |
| Actual9394 source exploration/road native registry,180 одинаковых лучей | 3917 / 4764 | 42 / 65 | 195 PASS |

Actual9394 manifest SHA:
`82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd`.
Factory строит настоящие shared MultiMeshes/Mesh road paint; тест работает с
реальными records/bounds/source geometry и trusted geometry-only fixture
owner, не gameplay authority. Move→delete→undo→clone→discard ближайшие ID
совпадают с actual reference registry. Full ~9901 combined authored+procedural
geometry не замерена — число9901 в первой строке явно synthetic.

BVH actual bounds tests p50/p95 29/39 вместо полного9394 scan. Actual targeted
refit41us, dynamic clone insert80us. Initial full BVH build532882us: это
существенная одноразовая стоимость! Не выполнять rebuild на каждом клике,
action или клоне. Root должен отдельным bounded/prewarm этапом построить
index и держать readiness=false до его завершения. Большое количество
пространственно перемещённых объектов со временем может ухудшить форму BVH;
перестройка нужна отдельным explicit paused stage, не скрыто на input.

Outline synthetic repeated160bounds: old p50/p95 12/17us, cached1/1us.
Geometry/resource identity рамки сохраняется после всех changes и hide.
Это CPU measurements, не общая игровая сцена/FPS/visual GPU acceptance.

## Воспроизведение

Из repo root с Godot4.7.2 console:

- `--headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_selection_spatial_index.gd`
- `--headless --path outputs/map_editor_procedural_native_v3 --quit-after 1200 --script C:/Users/Слава/Desktop/Мафиози/tools/godot/map_editor_candidate/tests/map_editor/test_selection_index_actual.gd`
- `--headless --path tools/godot/map_editor_candidate --quit-after 1200 --script res://tests/map_editor/test_selection_input_cost.gd`

Actual runner загружает свой candidate index относительным путём от теста;
frozen procedural project не переписывает. Нужен уже admitted staged source
project; при его отсутствии сначала использовать root-owned V3 stage runner.
