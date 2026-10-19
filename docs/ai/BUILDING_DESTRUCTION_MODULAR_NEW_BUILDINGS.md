# Buildings2 — новые модульные здания, 30 сентября 2026

Позднее поручение пользователя: «здания с нуля не быстрее создать? с
разрушаемыми объектами просто разной планировкой». Основное массовое направление
переключено на новые корпуса из реальных объёмных модулей. Пользователю сообщено:
работа на несколько часов, готовые группы передаются по мере проверки.

Buildings2 меняет только isolated outputs и свою память. Root24 сохраняет
main/player/project/export/LIVE/Git и единственную игру. Новых GPU окон и
production-редактирования Buildings2 не делал. Задача всех зданий ещё не завершена.

## Отдельная первая доставка у Root24

Frozen `outputs/building_destruction_modules2_20260930/delivery/RECEIPT.json`,
SHA256 `c95040f1c63f205a60d6a84dc1f8f488d0907acf46a78a315e093c5541a59dc2`:
37 проверенных файлов, новый hollow/measured runtime и точный Armor75 blocker.
Дополнительный immutable `bindings/long_armory_shell_world030.json`, SHA256
`d9a2ff9e1dc2b98bc8de0bc6d84384b3b39c66657cd720b78b8692f71c4ccc83`:
явно новый .3 WORLD-metre stone core, threshold172.5, не прежние .25 model metres.
Root подтвердил isolated26, native RPG4/W passage03 в работе. Его финальный успех
Buildings2 не подтверждал. Root ведёт glass first-material hitch, мы стекло не меняли.

Root попросил минимальный новый модульный дом для ближайшей доставки. Ему
честно сообщено: пролом и стоящий проход проверены, **полного обрушения всего
дома пока нет**. Автоматическая потеря опоры каркаса ещё не реализована; нельзя
объявлять geometry-local cuts тем самым целиком снесённым домом из showcase.

## Активная работа в expansion

### Продолжение: townhouse013 в текущем квартале

Root24 проверил минимальный chalet002 и нашёл его вне текущих восьми source
records и physical ground. Chalet не переносить и frozen33 не менять. По его
запросу передан отдельный immutable companion для
`REBUILD-VISUAL-old_town_narrow_townhouse_v1-013`, который уже есть в
`outputs/coordinator24_quality/candidate27/godot/mafiozi_walk/data/block.json`.

Независимая сверка source/prefab/placement: PASS13 в
`expansion/modular_buildings/townhouse013_mapping_review.json`. Source GLB
`fd0178400e608c44f4c7c8841d9a308e0ae2ec4db4df36033f04401f9b135067`, prefab
`abfc9126737481f1bed5cc4c63095115a8f756e8c21ceb9b9209fa6a21c6c485`:
40381 bytes, 116 parts, 1392 triangles, четыре surfaces, один MeshInstance.
Сохранённый frame origin `[18.45, 0.104999914, -2.095999956]` отличается от
source `positionLocalM`; geometry уже world metres, source scale повторно
не применять. В source record ровно **два** collisionBodiesM. Все дополнительные
runtime bodies и их владельцев Root проверяет отдельно до замены.

Оба исходных входных anchor сохраняются. К новой двери нужны подходы 0.207 м
по горизонтали и 0.015 м вверх; два connector и 22 glazing пока pending.
Root дал GO короткому headless load/register/reset после RELEASED pair06;
сопоставимые performance-замеры здесь не ведутся. Полное обрушение отсутствует.

Companion завершён и передан Root24/штабу:
`outputs/building_destruction_modules2_20260930/modular_townhouse013_companion/RECEIPT.json`,
SHA256 `437c871355cdc641e91d3d177e8454293ed94cea2d2875155e2f8b77be2dfa0a`.
12 payload files, 109411 bytes; entrypoint SHA
`37246d0886a0ac94ccabed6f603f3f77e3a801a5581b5a3b8b14c3a679130b3a`.
Exact frozen runtime load/register/reset/dispose **PASS106**, sealed verification
**PASS178**, hashes повторно сверены root этого чата. Использованы два fixture
collider из точного original JSON record; это не замена actual LIVE bodies.
Native origin `[18.450000762939453,0.10499991476535797,-2.0959999561309814]`.
Cold diagnostic load7.011ms/bind1.815ms/register101.438ms, static memory delta
11053780bytes; один functional run не является проверкой FPS/памяти общей сцены.
Engine закончил за1.09s, CPU освобождён. Runtime/loader/chalet не менялись.

Read-only `expansion/modular_buildings/townhouse013_test_targets.json` содержит
три сплошных участка, frame и доказательство отсутствия исходных проёмов.
Primary south-left wall `[15.800001,1.105,2.308500]`, outward+Z, foot-reference
approach `[15.800001,.135,4.308500]`. Это уточнение раннего x15.65: вся0.6m
capsule column входит в сохранённый public corridor. Оно не подменяет настоящий
RPG/W. При неудаче Root должен записать actual blocker, не искать счастливый луч.

`expansion/modular_buildings/current_quarter_mapping.json` — точная сверка
всех восьми current records с prefab library: 8/8 ID, asset и source SHA
совпали; 799 parts, 9588 triangles, 285023 binary bytes. Это каталог, не
внедрение. Остальные 70 placements отсутствуют в current block, и их нельзя
произвольно переносить в квартал. Для print_shop остаётся отдельный owner
интерьера.

Полная staged библиотека передана отдельным immutable companion:
`outputs/building_destruction_modules2_20260930/modular_library78_companion/RECEIPT.json`,
SHA256 `930d86c67cbff882d25147c6a16e20fa278f9e9db64f79f7f874beb0c24181dd`.
23 модели/78 unique placements; бинарные сцены3019322bytes; весь пакет90files,
4404525bytes. Сохранены manifest/specs/source anchors и protected-room данные,
source current block, mapping8/70, QA76005/export1399/hash754. Portable/workspace
verify **PASS669**, включая23 GLB/42 input pins и frozen33. Содержимое read-only;
не менять. Runtime/loader не продублированы. Это пакет для следующего rollout,
а не автоматическое разрешение всех78 и не приёмка их в общей игре.

Root24 теперь владеет candidate30 bridge/native RPG/W/actual owner replacement.
Buildings2 может исправлять конкретные доказанные дефекты новым companion, не
переписывая принятые frozen-пакеты. Для будущего structural collapse сохранён
read-only проект `expansion/modular_buildings/support_collapse_review.md`:
реальные residual islands, явные foundation contacts, ограниченный отдельный
перенос крупных остатков и tombstones. Эта механика ещё не реализована.

### Финальная передача первого нового дома

Root24 принял immutable
`outputs/building_destruction_modules2_20260930/modular_minimal_delivery/RECEIPT.json`,
SHA256 `adc588b7ec0790994f722a0ab024b7d9a888379215a7813ed58b26fc30e181fb`.
33 файла/525771 байт: runtime preload closure, loader, chalet prefab и отчёты.
Не менять этот каталог. Здание REBUILD-VISUAL-hillstep_chalet_v1-002:
29 частей/348tri/4surfaces/один MeshInstance; binary16303bytes. Exact prefab SHA
`524fb0caba7e9c6af002387369116102f47773bf898460e7e314d44001a5071b`.

Финальный QA: builder **PASS76005**, все78 реальных/23модели +4synthetic;
8533parts/102396tri/8,601,264bytes packed payload. Export **PASS1399** плюс
independent hash check754, бинарники всех78 всего3,019,322bytes. Source/full
geometry metadata стабильны. Финальный private host **PASS39** включает actual
collider breach, standing capsule, replay/reset и material mutations до
subthreshold/послеRender. Real-triangle contact **PASS47**, 45° shield подтверждён.
Exact minimal prefab native register/reset/dispose **PASS22** заново после правок.

На момент приёма Root собирает candidate30 от24d; его cargo_input_fix проверяет,
есть ли данный source record в текущих8 активных зданиях, затем native RPG/W.
Не переносить prefab произвольно, не накладывать на старый exterior. Обычная игра
24d PID16508 открыта по сообщению Root; не трогать. Root попросит конкретные
owner/glazing данные при необходимости. Полное обрушение по-прежнему отсутствует.

Ниже история этапов; статусы промежуточных FAIL не заменяют финальные данные выше.

Всё под `outputs/building_destruction_modules2_20260930/expansion/`.

- `modular_buildings/specs/models.json`: 23 модели, 78 размещений, 39 размеров,
  21 банковская комната и 6 комнат изоляторов. Node QA4341. Четыре tower entrance
  connector findings8.40–11.19м сохранены, не телепортировать owner anchors.
- `modular_buildings/modular_builder.gd`: новые стены с проёмами, перекрытия,
  перегородки и ступени. Один MeshInstance на корпус, до512 настоящих box-модулей,
  6144tri/4материала. World-metre geometry, frame только rotation+translation.
  Общая межэтажная плита служит полом и террасой без микрополос; исходные размеры
  и footprint union сохраняются. Важные комнаты и owner IDs остаются отдельно.
- `compound_render/compound_render.gd`: exact-byte incremental mesh composition,
  PASS210546, до512 замен. Townhouse69 total76–78мс по шагам, maxadvance.849мс;
  не FPS. Код и contract стабильны.
- `compound_node/compound_dispatch.gd` / `compound_runtime.gd`: per-component
  damage strength, cumulative cuts, exact face ownership; inherited pool/collider
  transaction и reset/generation. Private host генерируется из frozen delivery,
  исходный пакет не меняется. Новый printshop allowed только explicit generated
  modular provenance после loader validation, старый guard сохраняется.
- `compound_node/test_compound_runtime.gd`: PASS29 до последних guard усилений:
  новый двухэтажный дом, четыре admitted160 receipts, standing capsule1.7м через
  пролом, соседняя стена, pooled fragments, source arrays, reset/dispose/replay.
  Native player weapon и LIVE не проверены. Финальный повтор после guard нужен.

Третий массовый native QA: **все78 реальных placements PASS** geometry/closed
volume/no overlap/actual aperture rays/standing entrance capsule/protected-room
clearance/footprint union. 8535parts/102420tri/8.60MB packed payload суммарно,
2365 aperture rays,128 входных capsule checks. Один synthetic stepped случай
ещё давал6мм band; новый дизайн согласует почти совпадающие lintels, финальный
QA ожидается. Старые FAIL отчёты сохранены в validation, не удалять.

После GREEN exporter в `modular_buildings/export/` пишет .scn prefab и loader
с hash/identity/selectors guards. Он не подключает protected interiors/glazing
и не поднимает collision_replacement_approved без явного аргумента вызывающего.

Независимый review выявил и исправляет:
1. P1 material mutation после Render и при subthreshold: raw/effective snapshots
   и owned-material glass guards теперь проверяются в compound validate/_finish.
2. Mutable glass/held ownership в одном compound mesh пока запрещено: отдельные
   nodes, не безопасно просто убрать current_mesh equality и воскресить стекло.
3. P2 rotated AABB nearest visibility: меняется на ближайшую точку настоящих
   текущих треугольников и обязательное совпадение ray hit component; в работе.

Дальше: final QA/export, минимальный frozen дом Root24, сопоставимый LIVE/FPS и
native controls через Root. Отдельно остаётся настоящее полное обрушение/опоры.
