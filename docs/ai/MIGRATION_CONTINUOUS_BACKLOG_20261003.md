# Непрерывный перенос Walk → Godot — 3 октября 2026

## Актуализация root27, 07:50

Далее сохранён первоначальный source-аудит root26; его статусы45/47 исторические.
Текущий accepted/F5 — release48, manifest51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7.
Усиление C4/физический проход/Fire3/camera reset/sharedshape/marks37/40 уже включены,
полный перенос не завершён. Production остаётся Палаццо/триNPC/текущие машины.

Следующие конкретные ветки:

- C4 pose49: исправлены перекрёстные хваты и authored torso lean; actual original
  target .815м native57PASS, неподвижные стопы/капсула и длины рук. Low surfaces,
  actual GPU skin и полный допустимый диапазон ещё не приняты. Предыдущий pose48
  HOLD и closer C→stand failure сохранены, не объявлены готовой анимацией.
- Step48: actual capsule/corpse проверки + graphical component review выполнены,
  исторический transient cap123 FAIL имеет явное component exception. Нужны
  настоящий Palazzo passage и полный movement cost. Короткий dive48 native404+404
  ограничивает движение3.36м без удаления cinematic recovery; visual/perf не приняты.
- Weapon checkpointv2: native127PASS, 14 исходныхUID через8фаз; реальный выстрел
  расходует патрон896→895, reload/ground/cargo сохраняют state. Codec collisions,
  boundary depth и pending input исправлены. Это capture/codec/plan безrestore;
  `coordinator27_weapon_restore49` реализует отдельный two-process local restore
  с owner APIs/fresh bindings/clock reconciliation. Server grants остаются0.
- Car49 и NPC24: функциональные результаты сохраняются, полный сопоставимый perf
  и текущие NPC contact/recovery исправления ещё не приняты. Детали у владельцев.
- Новые здания: только private restaurant placement49 на final owner source;
  active48 пока не меняется. Нужны реальный soil/main/player/E/stairs и perf.
- Полные NPC saves, economy/business/gangs/mercenaries/server transactions,
  полный город/редакторы/vehicle condition persistence остаются OPEN.

Scheduler0194 в `docs/godot/TEST_SCHEDULER.md`: functional без rootGO, дваheadless
плюсgraphical; perf требует свободного окна. Чужие immutable proofs сохранять.
Root владеет production/pointer/Git; новый checkpoint не означает публикацию.

Рабочая очередь root26 по новому прямому поручению пользователя: продолжать полный
перенос, использовать десять существующих «Астра N (агент)», оптимизировать до
выпуска. Преемники27/28 допустимы при большом контексте; передача должна сохранять
точную принятую сборку, владельцев, незавершённые пакеты и следующий исполнимый шаг.
Этот документ — проверка исходников и сохранённых результатов, не новый LIVE.
Чаты, движки, Git и production-файлы при подготовке документа не изменялись.

## От какой игры продолжать

На момент чтения `godot/current_version.json` указывает на
`s01-20261001-palazzo-frames45`. SHA указанного `outputs/coordinator26_frames45/ASSEMBLY.json`
совпал: `f797214092875a9e91cd47aa30cf751b99909f089d9b3b6bb8f4be34c6336b21`;
статус `ACCEPTED`, 473 source pins. Это точка продолжения, а не доказательство
наличия сейчас открытого процесса. Исторические PID здесь намеренно не используются.

По `ACCEPTANCE.json` и `docs/godot/PALAZZO_FRAMES45.md`: gameplay61/0,
дверь109/0, combined glass173/0, компонентный baseline рам7457 и candidate8074.
Сопоставимая полная сцена квартала: idle p95 9.994→10.218мс, damage/recovery
p95 10.096→10.457мс, peak working set +13.03MiB. Эти результаты относятся к
сохранённому кварталу с тремя NPC, а не ко всем механикам Walk или полному городу.
Шапка `docs/godot/MIGRATION_BOARD.md` ещё описывает24b и не определяет текущую игру.

**Не возвращать старые здания.** Активная сцена содержит только Палаццо;
старые8 домов, печатня/её интерьер и modular30 выключены вместе с их навигационными
препятствиями. Архивы остаются. Дороги, вода, декор, три текущих NPC и транспорт
сохраняются. Будущие коробочные здания требуют отдельного поручения. Полный перенос
механик не даёт разрешения незаметно восстановить старую геометрию ради тестов.
Старый чат traversal `01a087e2-a009-7873-a45f-8e1a4c2effc4` остаётся OFF:
не будить, не передавать ему задачи и не создавать его замену по этому backlog.

## Очередь механик и точные границы

Путь runtime в таблице — относительно принятой frozen45. «Есть в45» означает
принятую локальную реализацию с указанными ограничениями, а не полный source parity.
Владельцы: root26 — интеграция/player/weapons/приёмка; Buildings3 — Палаццо/C4;
Художник24 — NPC; Transport3 — посадка/места/багажник/транспортные правила;
«Физика Автомобилей» — native body/контакт. Их актуальные handoff перечислены ниже.

| Механика Walk → Godot | Реальное состояние и владелец/пакет | Следующий результат и приёмка |
|---|---|---|
| Палаццо, дверь E, разрушение стен, рам и стекла | **Принято45.** root26 + Buildings3; `outputs/coordinator26_frames45`, `outputs/buildings3_door43/revision5`, `buildings3_frames44`, `buildings3_glass44`. | Сохранять как обязательную регрессию каждого нового релиза: дверь/опоры/стекло/J, исходные коллизии и NPC. Не добавлять другие здания. |
| C4: близкая физическая поверхность, иконки, усиленный взрыв/огонь | Старый C4 есть в45; **новый изолирован,47 собрана только в исходниках**. Buildings3 runtime `outputs/buildings3_c4_delivery45r2/DELIVERY.json`; root `outputs/coordinator26_c4_47/ASSEMBLY.json`,484pins. Component179/0 и native FX PNG не являются full-game PASS. | **Первый этап очереди:** import47 и настоящий Q→3с ЛКМ→пол→отход→пульт, стекло/отмена/replay, визуальный просмотр; затем одинаковая полная нагрузка45/47 с1 и8 зарядами, полным хвостом опор/физики/FX. См. точный план ниже. |
| Урон автомобилю от пули, мотор/шина, дым/авария | **Изолирован car46, native NOT_RUN.** root26 принимает пакет `outputs/car_damage_20261001/current45/ASSEMBLY.json`, 480pins; Physics/Transport3 сохраняют свои API. | После47 — новый rebase на фактически принятую базу, без возврата45/43. Первый настоящий AK terminal: расход патрона, source shot ID, попадание в native поверхность и engine HP. Затем дым/шина/авария, on/off/on и сравнимый frame-time/RSS. Не смешивать car46 с C4 до отдельных доказательств. |
| Обычное движение, прыжок, нырок и возврат контроля | Базовый player есть в45; **новый full-volume dive39/rotation40/return41 изолирован** у root26: `outputs/coordinator26_dive39`, `optimized_rotation40`, `return_admission41`. | Совместить checked restoration с владельцами Physics и Transport3: проверка полной капсулы и точной возвращаемой mask ДО включения коллизий. Real native проход/потолок/труп/посадка/отмена/новая жизнь; сохранить1.9м×0.30м капсулу. Затем цена query/update в загруженной сцене. Player-only41 не закрывает межвладельческий порядок восстановления. |
| Step-up через пролом, контакт с трупом | **Функционально принят только isolated headless33, production_promoted=false.** root26: `outputs/coordinator25_step33/newfixture/ACCEPTANCE33.json`; в45 player всё ещё baseline SHA64707b7c… | Узкий перенос на актуальный player с регрессиями corpse-pressure и прохода реального Палаццо; GPU и стоимость полного movement path. Старый townhouse fixture — историческое доказательство, не повод вернуть дом в сцену. |
| Оружие14, прицел, Q, патроны, pickup/drop, багажник | **Есть в45 локальная сессионная реализация**, включая прежние cargo/E/F/Esc fixes, RPG, native hit-owner/HP трёх жителей. root26 + Transport3; `scripts/weapons/*`, `scripts/transport/trunk/*`. | Сохранять UID/боезапас/перенос вещи/захват мыши в регрессиях. Полная серверная власть и сохранение через перезапуск не следуют из локального PASS; это отдельные строки ниже. |
| Следы пуль/RPG/C4 на исчезающих поверхностях | **Патч не принят.** root26: `outputs/coordinator25_orphan_marks37`, `coordinator26_surface40_fix`, `coordinator26_surface41_qa`. Frozen45 `weapon_surface_impacts.gd` bc116e… отличается от исправления4adeb6… | Rebase QA с40 на текущие frames/glazing45+принятый C4. Настоящие TT/RPG pending→fractured, ordinary advance cleanup, движущийся fragment, J generation, generic hidden helper; затем C4 wall mark retirement без выдуманного preexisting glass hit. Сравнить стоимость обновления/память. |
| Близкий AK по трупу и задержка первого выстрела | **OPEN/изолировано**, root26: `outputs/coordinator25_close_ak33/optimization36`, `outputs/coordinator25_cold_shot35/AUDIT.md`. Исторический cold TT max123.392мс — не новое измерение45. |36: точный same-pose hit/triangle parity и cache invalidation, затем полный cold/moving/settled shot path.35: разделить launch и first metal impact в настоящем холодном запуске, исправлять измеренный источник. Прогретый kernel не закрывает первую задержку. |
| NPC: ходьба, локальные HP/смерть/ragdoll/следы | **Три текущих NPC приняты**, основные hit/blood/dead-contact модули входят45. **Полный город и daily cycle изолированы** у Художника24: `outputs/artist24_daily_cycle/city/scene_project`; память `ARTIST24_MEMORY.md`. | Не накатывать старую city-сцену со снятыми зданиями. Сначала перенести bounded startup/nav/controller на разрешённую геометрию, сохранив исходные identities; фактическое движение, прерывание попаданием, жизнь/смерть и общий бюджет. Изолированные75/287 и сервисные14/14 не заменяют приёмку. Controller max20.090мс и logic max77.957мс изrun21 требуют устранения, не уменьшения состава ради PASS. |
| Банк/магазины/медицина, экономика NPC, посещения | **Не приняты в активную45.** Художник24; `artist24_daily_cycle/city/NPC_BANK_FLOOR_SEAM_HANDOFF.md`. Банк/газета проходили отдельный canary; printshop visits в45 намеренно выключены. | Сначала отделить transaction/identity/состояния от отсутствующей геометрии; не выдумывать cash/HP и не создавать невидимый банк/печатню. Физические визиты включать только в отдельно разрешённых новых местах, с отменой/возвратом к ходьбе и cost профилем. |
| Рукопашный бой, входящий урон игроку, общий combat authority | **Melee practice есть, реестра целей нет.** `scripts/combat/preview_melee.gd` явно отвергает targets. NPC owner сообщает `new_local_session_hp`, неполные social/medical/respawn последствия. root26 + Художник24/Physics. | Один вертикальный native combat slice: реальная цель/контакт→одно подтверждённое событие→HP/реакция/смерть; stale/replay/occlusion negatives и сохранение source ownership. Полный source callback не заменять косметическим hit или synthetic receipt. Замерить contact→owner→pose/HP весь путь. |
| Вождение/места/выход, парковки, трафик и столкновение с NPC | Основное управление/посадка/выход есть в45. **Парковочный preloader/39lots59bays, road-yield AI, contact damage/debris — отдельные кандидаты**, не считать принятыми. Transport3 и Physics; `docs/ai/TRANSPORT3_HANDOFF.md`, `VEHICLE_PHYSICS_DESTRUCTION_LEAD_20260923.md`. | Сначала scoped parking/preloader seam на текущем мире с проверкой исходных ID/shape/path; не занимать несуществующие здания. Далее реальный vehicle/NPC contact с owner token, подмашинный no-trap, occupant roster на момент взрыва. Полные startup/poll/update и matched driving cost; isolated10/10 не доказывает LIVE. |
| Вода/рельеф/дороги/декор/сутки/фонари | **Частично приняты** native поверхности текущего квартала, вода/clock/day-night, лампы/машинный свет и звук. Полный source world/водный gameplay/rail/shore hooks этим не покрыты. root26 + street/terrain/Transport3 владельцы. | Сначала source coverage map по разрешённой геометрии; проверить physics, camera, water exit и часы при паузе. Не объявлять визуальную воду плаванием, наличие дорожного графа — трафиком. Сопоставлять одинаковые геометрию/свет/камеру, отдельно холодные эффекты. |
| Наёмники/банды/боссы/заведения/полиция | **Не перенесены в принятую45**: нет соответствующего native host wiring в pinset. Root26 интеграция; NPC — Художник24. Source: `assets/maps/city_rebuild_v1/mercenary_core.mjs`, `mercenary_walk.mjs`, `mercenary_world.js`, `world_walk_host.mjs`, `npc_empire.py`; `docs/ai/MERCENARY_CORE_HANDOFF.md`, `GANG_SYSTEM_MEMORY.md`. | После combat/ownership seam — один source-backed recruit→command→physical follow→effect→cancel/save slice. Деньги/профессии/оружие/награды, server ACK и boss decisions сохранить; не создавать недоступные заведения. Проверять bounded scan/navigation/cleanup в полной сцене. |
| Сохранения, серверные транзакции, reload/reconnect | **Полный Godot save/ownership bridge не принят.** Root26; материалы Астра7/10: `outputs/astra14_collection_20260926/new_agents/A10_PERSISTENCE_SOURCE_BOUNDARY.md`, `outputs/coordinator22_astra9_10/a10`. Source `weapon_transfers.py` и `world_weapon_transfers.mjs` — не готовый Godot SaveStore. | Замороженный whole-document inventory+cargo+ground+UID snapshot после завершения pending transfers, trusted ACK/reconciliation, atomic save, corrupt/truncated/kill/replay/restart tests. Не сериализовать RID/lease как право владения. Приёмка с неизменными предметами/патронами/cash и измеренными save/load паузами. |
| Редактор карты/персонажа и весь UI Walk | **Не включены в accepted45.** Root26 принимает owner-пакеты; browser source `walk_map_editor_*.mjs`, `docs/ai/WALK_MAP_EDITOR_HANDOFF_20260923.md`, native `outputs/map_editor_*` остаются отдельными. | Сначала минимальная native editor overlay transaction/undo/save с current-world IDs, безопасным input ownership и pause clocks. В45 K уже означает обвал Палаццо — согласовать отдельный input, не перехватывать K молча. Редактор не может восстановить запрещённые здания. |
| Лестницы/перелезание/подтягивание | **Изолированные source/native proposals, не playable45.** История `docs/godot/TRAVERSAL_NATIVE_HANDOFF.md`; прежний чат OFF. | Root хранит очередь; брать уже сохранённые материалы лишь в своём явно ограниченном этапе после player/owner restoration. Нужны input/rig/actual contact/abort recovery и fullscene cost, без возвращения лестницы удалённой печатни. |
| Экспорт/постоянный запуск | **Pointer/F5 приняты для frozen45**, отдельный exe/PCK нового47 ещё не проверен. Root26; `godot/current_version.json`, `tools/godot/launch_current_game.ps1`. | После native/perf47 — отдельная проверка resource closure и PNG в PCK, если выпускается экспорт. Затем одна последовательная замена игры с новым receipt и обновлением пяти подсказок. Добавление export path в конфиг само по себе не является export PASS. |

## Ближайший исполнимый этап: C4-47, затем автомобиль

1. **Исходники уже готовы.** `prepare47.py` SHA
   `53df654474c4de92ccb1dfcbb8c38490e95c8064b6975fe9468037f8e17fcd49` не изменился;
   Python AST разобран. Basef797 и все пять закреплённых owner manifest SHA
   совпадают с текущими файлами. **Обновление в конце аудита: root успешно выполнил
   `--stage`03.10; `PREPARED.json`, `ASSEMBLY.json` и `candidate/` уже существуют.**
   После аудита root выполнил import47: `outputs/coordinator26_frames45/runs/c4_47_import01`,
   7.099s/exit0/stderr0, stdout без SCRIPT/SHADER/PARSE ERROR,484pins неизменны.
   Это только импорт, не native/fullgame/performance приёмка. Исполнитель
   исходного аудита сценарий не выполнял. Prepare-скрипт не запускает движки: default read-only, `--prepare`
   создаёт малый patch/manifest, отдельный `--stage` копирует frozen source без `.godot`.
   Созданная47 имеет15 patch paths и484 source pins:473 base +10 новых runtime
   resources + уже существующий `door_close43.gd.uid`. Import PASS; native/perf47 ещё NOT_RUN.
   SHA текущей ASSEMBLY47:
   `5c5b4455ee8f8b7f9d81766a4977974faf6482aaed15be9b82968f2d5786714f`.
   `ACCEPTANCE.json` отсутствует. Import-логи находятся под frames45/runs, поскольку
   использован прежний guarded runner. `PREPARED.json` и ASSEMBLY сохраняют исходные
   статусы подготовки; отдельный RUN.json подтверждает более поздний импорт.
2. **Интеграционный агент root уже получил исправление QA-подготовки.** Прочитанный
   до переключения `qa/MANIFEST.json` закреплял
   floor fixture revision2 SHA9cd4f506…; `buildings3_c4_surfaces45_revision3`
   исправляет выбор контакта на реальном стекле четырьмя bounded точками. Его
   `visual/patch` entry SHA6b3c8e55… supersedes старые floor fixtures; runtime
   остаётся revision2. Завершить и проверить один новый frozen QA entry/closure с этими
   проверками и actual-event PNG. Старый пакет не перезаписывать. Для perf использовать
   `buildings3_c4_input_perf45` + `revision2` (исправленный eviction oracle).
   Art revision3 — отдельный непроверенный вариант, не подмешивать в47 автоматически.
3. **47 уже staged; не запускать повторный `--stage` поверх неё.** Передать27
   существующие ASSEMBLY/PREPARED и завершённый новый QA manifest. Включены только surface6,
   FX4, PNG2, main revision, пять notes и additive export. Doorv5/frames45/player/
   nav/машина45 сохраняются. Car46 в этом этапе отсутствует.
4. **Одно согласованное окно:** свежий inventory/receipt, общий mutex; после успешного import →
   настоящий floor/input/glass/negative-replay fixture → просмотр фактических PNG.
   Затем одинаковые baseline45/candidate47 с1/8 зарядами, полной geometry/NPC,
   холодным первым эффектом и хвостом до stable graph/retired FX. Записать
   p50/p95/max кадров, draw calls/primitives, support/dispatch, memory/RSS.
   Незавершившаяся очередь — INCOMPLETE. Регрессия остаётся изолированной и исправляется.
5. **Доставка только после explicit acceptance:** точные hashes, пределы проверки,
   shared scoped changes без чужого WIP, pointer/notes, одна обычная игра. Далее
   car46 на новом accepted base, затем player/step/marks и следующий combat/NPC slice.
   Не начинать ещё один общий аудит вместо этой уже определённой последовательности.

## Десять Астр: пакет для исполнителя, не новая группа

IDs ниже прочитаны из `outputs/artist24_astra_dispatch/DISPATCH.json`; это именно
существующие проектные чаты «Астра N (агент)», не исторические одноимённые14.
Таблица предлагает следующий непересекающийся batch и НЕ заменяет фактический реестр
`ASTRA_CONTINUOUS_DISPATCH_20261003.md`. Действующий диспетчер уже получил поручение
отправить всем10 задания. Это обычные чаты: в сообщение вкладывать нужные исходники;
ответом служит текст кода/patch/ревью/сценариев, а локальный запуск и проверка остаются
у рабочих агентов/root. Этот аудит сообщений не отправлял. Непроверенный
текст или isolated PASS не превращается в production.

| Астра | Существующий ID | Следующий ограниченный материал для владельца |
|---|---|---|
|1|`6abc2f7c-c5d4-83ea-a87d-6b15d4123a95`|Приёмочный comparator одинаковых C4 fullscene samples; cold/warm и RSS отдельно.|
|2|`6abc307b-8348-83ea-9676-95b4722accd5`|NPC lifetime/claim и bounded startup на palazzo-only; без старых зданий.|
|3|`6abc30a2-ddc8-83ea-9480-4adbbbb456d1`|Контракт сверки source/native packages и зависимости новой47, без нового универсального сборщика.|
|4|`6abc30af-72a4-83ea-913d-457ef7394129`|Geometry/door regression: нет phantom old-building collision, сохранены реальные Palazzo bodies/shapes.|
|5|`6abc30bc-38d8-83ea-9b0f-402fbe8f039d`|Сквозная отмена C4/транспорт/оружие: held input, modal Esc, source identity.|
|6|`6abc30c0-6318-83ea-8ded-c7f2c5d495fb`|C4 icon/FX asset closure и визуальные критерии; без объявления art/PCK PASS по исходникам.|
|7|`6abc30c5-6468-83ea-9f09-21a3951cd937`|Atomic SaveStore crash/replay protocol после pinned schema, без подмены server ACK.|
|8|`6abc30c7-3868-83e9-a47f-978b3886f344`|Navigation cancellation/fairness и cost на сохранённом geometry set.|
|9|`6abc30c7-4bdc-83ea-bf3c-081ec01fdb5c`|Actual combat contact/authority→HP contract, отрицательные stale/replay cases.|
|10|`6abc2d25-0460-83ea-a995-1482c8cdd336`|Whole-document weapon/cargo/ground UID codec + adoption plan; A7 занимается durability отдельно.|

Читаемые первичные сводки: `COORDINATOR_26_MEMORY.md`,
`COORDINATOR_26_HANDOFF.md`, `BUILDING_DESTRUCTION_3_HANDOFF.md`,
`ARTIST24_MEMORY.md`, `TRANSPORT3_HANDOFF.md` и принятый manifest45.
При передаче27/28 первым делом передать этот следующий этап, а не возобновлять
старые chat/process IDs или считать исторические SOURCE_READY готовой игрой.
