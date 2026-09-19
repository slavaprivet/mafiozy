# CHAT CHECKER 17

## Действующий протокол

С 2026-09-19 пользователь передал Проверщику самостоятельную проверку и интеграцию результатов Astra. Проверщик может применять подтверждённые production/test изменения и запускать подходящие локальные CPU-тесты. Координатор 17 не получает рутинных сводок и не используется как обязательный интегратор; обращаться к нему только при конфликте активного owner-scope, пересечении файлов, необходимости единственной LIVE/GPU-проверки или неснимаемом локально блокере.

Итог отправки этого события: Astra=5, coordinator_summary=1 (доставка инструментом подтверждена); все пять новых userMessage receipts прочитаны. Новых исследовательских результатов в этом событии не принимали.

Обновлён 2026-09-19T16:39:18.2774112Z по прямому поручению Координатора 17; заменяет старые запреты таймера и ожидание общей приёмки пяти чатов.

- Разрешён двухминутный таймер. Проверять только пять Astra; читать последний завершённый ожидаемый результат. Пропущенные heartbeat не считаются наблюдёнными циклами.
- Разрешены локальные чтения, сбор пакетов, production/test изменения, CPU-тесты и checker-owned LIVE в отдельной игровой вкладке по прямому разрешению пользователя. Внешние платные API запрещены; единственную пользовательскую игровую вкладку других владельцев не закрывать и не использовать для замеров.
- Единственный владелец CHAT_CHECKER/CHAT_QUEUE/CHAT_MAIN_MANIFEST — проверщик. mercenary_core.mjs и test_mercenary_lifecycle_restore.mjs сейчас изменяет координатор по NPC-LIFE-001/002; другим правки не поручать.
- Один ASSIGNED на чат; не более двух QUEUED на область. Не писать занятому чату. Не более пяти рабочих сообщений за скользящие пять минут и одной объединённой сводки координатору за цикл.
- Безопасное новое исследование после завершения предыдущего не ждёт приёмки всех пяти или интеграции. Нужны новый вопрос, полный необходимый контекст и проверяемый PASS исследования.
- Приёмка исследования не равна интеграции или LIVE. После отдельной проверки Проверщик может внедрить bounded patch и выполнить CPU-регрессии. Не ухудшать картинку/дальность/тени/коллизии/NPC ради счётчиков.
- Долгий активный ответ сам по себе не зависание и не переводится в STALE_REVIEW по времени или числу heartbeat. STALE_REVIEW ставится только при доказанном source drift, ошибке результата или явном блокере. После двух повторных выводов без нового источника — WAITING_SOURCE, не пинговать.
- В реестр вносить только дельту. Координатору писать лишь при owner-конфликте/LIVE-блокере; никаких рутинных ACCEPT-сводок и messages_saved.

## Fresh-main gate

Перед каждой отправкой получить main SHA, dirty owner-файлы, SHA256 фактических байтов и timestamp. Передать реальный текст всех нужных файлов или явно ограниченный самодостаточный excerpt; локальный путь и манифест не являются контекстом обычного чата.

Проверить hashes до/после чтения и после сборки. SOURCE_SNAPSHOT_ID = SHA256 UTF-8 строки MAIN_SHA + LF + отсортированные строки path TAB whole-file-hash TAB boundary, разделённые LF. Если источник меняется — пересобрать, не отправлять старый пакет. Проверить idle непосредственно перед отправкой и receipt через фактическое userMessage.

При результате сверить TASK_ID, MAIN_SHA, SOURCE_SNAPSHOT_ID, границы и текущие hashes. Изменение source => STALE_REVIEW, не молчаливая приёмка. Ссылка chatgpt-content-reference не полученный патч: получить доступный файл либо один bounded текст diff до 12000 символов. Отчёт до восьми строк отдельно от diff.

## Дельта текущего цикла

- 2026-09-19: двухминутная automation `astra` удалена по прямому запросу пользователя. Создана активная долгосрочная цель этой задачи: непрерывная оптимизация walk без потери качества с постоянной загрузкой пяти Astra, собственной проверкой, CPU/GPU/LIVE A/B и уведомлением после каждого проверенного результата.
- ACCEPT+INTEGRATED `static-residential-render-hotspot-20260919`: Astra 4 обнаружила quality-дефект — distance-only batch update не отражал позднее `visible=false` исходного mesh/предка. Новый `test_static_render_visibility.mjs` сначала RED, после hierarchy visibility propagation GREEN. Existing `test_static_render_batches.mjs`, vehicle-shadow suite и render-freeze 30/30 PASS.
- LIVE после quality-fix: 9674 batched members / 125 batches / 112 active; cullLights p50 0.0 ms, p95 0.8 ms. Город, дома, машины, NPC и тени визуально загружены. Это подтверждает низкую стоимость исправления, но не является before/after FPS-ускорением.
- ACCEPT+INTEGRATED safety finding Astra 1: shadow QA handler теперь использует `performanceProbe?.reset()`, поэтому сравнение не падает при отсутствии probe. Default culling gate не отменён: checker уже выполнил более полный fixed-pose LIVE A/B и сохранил rollback `vehicleshadowcull=0`.
- REJECT `npc-distance-square-hotpath-20260919`: Astra 2 доказала конечный overflow-контрпример (`1e200`), при котором squared-distance меняет visible/shadow/pose. Production не менялся; качество сохранено.
- REVIEW_ONLY `collision-query-allocation-hotpath-20260919`: point-query уже allocation-free на cache hit; предложенные queryBounds tests полезны, но сами лаг не устраняют. Следующая задача проверяет безопасный caller-owned scratch только для единственного production consumer.
- Новые ASSIGNED: Astra 1 `vehicle-batch-bounds-refresh-20260919`; Astra 2 `npc-pose-actor-cost-split-20260919`; Astra 3 продолжает `building-report-generation-cache-20260919`; Astra 4 `static-batch-admission-census-20260919`; Astra 5 `collision-bounds-scratch-buffer-20260919`.

- 2026-09-19: пользователь потребовал уведомлять о каждом результате только после проверки. Automation `astra` обновлена: активная работа и непроверенные исследования остаются тихими; уведомление содержит изменение, реальный сценарий, цифры до/после, качество и ограничения.
- ACCEPT+INTEGRATED `vehicle-shadow-default-gate-20260919`: checker-owned fixed-pose LIVE A/B, 120 кадров на режим, одинаковые hero/NPC/traffic/viewport. OFF→ON: frame p50 65.8→61.2 ms; GPU p50 35.47→31.77 ms; total passes 3519→2823; main passes неизменны 1752; vehicle shadow passes 993→297. Визуальный контент, машины, персонажи и видимые тени сохранены. Обычная ссылка без `vehicleshadowcull=1` после patch загрузилась с `vehicleShadowCulling.enabled=true`; `vehicleshadowcull=0` оставлен как rollback.
- CPU/structural validation PASS: `test_vehicle_shadow_culling.mjs` 76,320 conservative swept-volume checks; `benchmark_vehicle_shadow_culling.mjs`; `test_render_freeze_qa.mjs` 30/30; syntax and scoped diff check PASS. Это локальная render/LIVE приёмка, не backend/network acceptance.
- ACCEPT+APPLIED `grass-cell-index-parity-20260919`: добавлен `test_grass_cell_index_parity.mjs`; новый тест, `test_environment_grass_selection.mjs` и `test_grass_prefix_uploads.mjs` PASS. Production grass content/дальность/fade не менялись.
- Astra 2 result `npc-hot-path-frame-cost-audit-20260919` принят как безопасный узкий candidate: `hasAction` избегает JSON clone только для занятых наёмников; реальный FPS эффект пока не проверен, поэтому production ещё не применён.
- Astra 3 `diagnostics-static-report-churn-20260919` DEFER: дефект повторной сериализации подтверждён, но исходного пакета было недостаточно для безопасного diff. Отправлен новый полный bounded package `building-report-generation-cache-20260919`.
- Astra 2 получила `npc-distance-square-hotpath-20260919`; Astra 1/4/5 продолжают vehicle-shadow/static-residential/collision allocation задачи. Все задачи запрещают уменьшение качества, дальности, теней, NPC и контента.

- 2026-09-19T16:57:27Z: Astra 1 ACCEPT research; все четыре owner-source hashes совпали. Получен доступный bounded test diff полного parity: IDs/order, per-mesh counts, fade, negative boundaries, equal-distance ties, budgets и widest-radius AABB halo. Не применён и не запускался; материал сохранён в ASTRA_GRASS_CELL_INDEX_PARITY_20260919.md.
- Astra 5 inventory-test-body-coverage-20260919 принят частично как review: duplicate implementation/tests уже внедрены координатором, поэтому 157-line matrix не повторяется. Новые полезные границы — failed equip/dismiss side-effect isolation и реальная _dismissGangMember delegation/former-row/refund uniqueness.
- Координатор сообщил текущий inventory fix: mercenary_world.js SHA256 aadd4a3b86af0bbe2a9e9d9f29f9abbf014cf114f1a87c7fa9f004275f0be476; связанные suites 54 PASS по его прогону, LIVE/reload pending. Fresh-copy-of-reconciled-rows остаётся внешним неизвестным version contract.
- Astra 5 получила ровно одну свежую задачу inventory-dismiss-guard-tests-20260919 с текущим adapter, текущим тестом и точным source _dismissGangMember; receipt 2c80050d-c56f-4ecb-b7e2-f1eca1f8218c подтверждён.
- Git main не обновлялся: обычные Astra не получают рабочую версию через GitHub. Для каждого задания передаются фактические тексты working tree и hashes, поэтому старый main не блокирует исследования.
- Непрерывный контроль остаётся на automation astra; опрос не считает активный долгий ответ зависанием.
- Astra 4 получила свежий локальный Three r180 vendor package и текущий camera resolver/test. send_message принят, чат active; receipt ещё не виден в read-back, поэтому повтор запрещён до появления истории или ошибки.

- 2026-09-19T16:49:54Z: новые финалы Astra 2/3/4 прочитаны один раз.
- ACCEPT Astra 2: source hash exact; repeated moveMember(id,null) cannot be deduplicated because it must clear an intervening goal.
- ACCEPT Astra 3: confirmed duplicate inventory defect [1,1] with reserve 1 -> current [0,0], required [0,1]; bounded current inventory UI function rechecked after unrelated whole-file drift.
- STALE_REVIEW Astra 4: indoor_camera is unchanged, but clearance and caller changed materially; current clearance adds a 6 m/s cap, invalidating part of the answer.
- Astra 1 and Astra 5 remain active; времени ожидания недостаточно для вывода о зависании, счётчик timeout не ведётся.
- No next task sent: rolling dispatcher cap was already five messages. Detailed material: ASTRA_RESEARCH_DELTA_20260919.md.
- Координатор сообщил локальный vendor для будущего camera parity: D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js. До нового пакета проверить точную локальную версию и передать фактический bounded source; CDN не использовать.

- Пять прежних финалов повторно проверены: все завершены, новых результатов не было; устаревшие ASSIGNED в таблицах удалены.
- Собраны четыре свежих полных по заявленной области пакета; после сбора проверка hashes/main PASS. Отправлены Astra 1/2/3/5. Для Astra 5 передано полное тело существующего test_mercenary_world.mjs; отсутствующий acceptance-файл не выдан за существующий.
- Astra 4: BLOCKED_NOT_SENT. Import map world.html указывает three@0.180.0 CDN; локальные Raycaster.js/Mesh.js в проверенном node_modules отсутствуют. Не выдумывать vendor implementation и не отправлять прежний аудит без него.
- Терминал использован только для разрешённого локального чтения/git/hash. Production не менялся, тесты/LIVE/внешние API не запускались.

| Чат | Новый TASK_ID | Delivery receipt | Наблюдённых незавершённых циклов |
|---|---|---|---|
| Astra 1 | grass-cell-index-parity-20260919 | f28d9ab8-6ec3-473b-8c45-052f4b1042e3 | 0 |
| Astra 2 | npc-adapter-callback-effects-20260919 | 45c75c99-ce4f-458c-9f4a-9a484e9d99c5 | 0 |
| Astra 3 | world-inventory-duplicate-contract-20260919 | 87cb9be0-6e57-4095-b785-c4d9eb1ece51 | 0 |
| Astra 5 | inventory-test-body-coverage-20260919 | 3dd06dae-618e-45a7-8a9b-23eca3cb4e74 | 0 |

Получено сообщение координатора: NPC-LIFE-001/002 исправлены им; core SHA256 c4dd915a03adeefa89b38389ddd08cc6b2b634a9f8619c2d84cfba38925482f9, сообщены 8 FAIL до / 9 PASS после, 54 PASS с existing suites. Это сведения координатора, не собственный прогон; LIVE/FPS не принят. Handoff: ASTRA_NPC_LIFECYCLE_INTEGRATION_20260919.md. Повторно как неисправленные не выдавать; текущие четыре пакета core не включают.

Счётчики этого события: sent_astra=4; fresh_manifests=4; stale_legacy_tasks=15; stale_rejected=0 (новых ответов не оценивали); integration_accepted=0. coordinator_summary учитывается после фактической отправки.

## Исторический checkpoint завершённых результатов

Receipt Astra 4 подтверждён userMessage 71ee98a1-23ee-48b5-a01e-c56f2812b19d; delivery receipt есть у всех пяти новых задач. Новые ответы ещё не оценены.

Дополнительная дельта: freshness Astra 4 обнаружила изменение walk_preview.mjs, отправка старого пакета отменена. Полная функция clampBuildingCamera(dt) перечитана, hashes повторно проверены; выдана новая узкая задача camera-damping-dt-boundary-20260919, не требующая vendor semantics. Полный vendor-parity вопрос остаётся BLOCKED_NOT_SENT. Итог: sent_astra=5, fresh_manifests=5; stale_rejected=0, source_rebuilds=1. У новой задачи 0 наблюдённых циклов. Receipt проверяется отдельно; повторять отправку нельзя.

- Astra 1 / decor-distance-root-audit-20260918 / 3b4d030a-3118-4aa1-a6d5-ab500700e199: decor default 360, grass независим; актуальные roots не доказаны.
- Astra 2 / npc-state-serialization-budget-20260918 / 481bdafe-bb70-4bd8-8e5f-46ec62a07f3b: повторные snapshot обходы, receipt-set; CPU не измерен.
- Astra 3 / report-consistency-check-20260918 / ff639f3a-2527-4ff1-bb3e-99619d45dcaf: PARTIAL/DEFER; 14 методов не 14 PASS.
- Astra 4 / interior-visibility-transition-check-20260918 / c3954239-c66a-4dab-a431-a4293742f137: hide ancestor меняет camera hits; vendor не передан.
- Astra 5 / inventory-dedup-test-review-20260918 / 62963775-2f71-47c7-8f9a-1d3f16516179: NOT_RUN, тела acceptance-теста не было.

## 2026-09-19 — непрерывная оптимизация, принятая дельта

- `building-report-generation-cache-20260919`: ACCEPTED_INTEGRATED. Добавлен поколенческий WeakMap-кеш диагностических отчётов входов без изменения JSON-схемы, значений, порядка, дверей, интерьеров или игрового поведения.
- Синтетический сопоставимый прогон: 78 отчётов, 120 warmup + 1000 измерений. Полный путь `294.5131 ms` суммарно (`0.2945 ms`/публикацию) → кеш `18.0446 ms` (`0.0180 ms`/публикацию), одинаковые `97,015,000` выходных символов; обходы отчётов `78,000 → 0`, JSON-visits `17,869,000 → 6,000`.
- LIVE reload PASS: `buildingEntry` парсится, `count=78`, полный массив `doors=78`, ошибок консоли нет. Визуально сохранены NPC, транспорт, дома, трава, тени, оружие и HUD; качество не снижалось. Текущий несопоставимый живой кадр: frame p50 `74.8 ms`, p95 `87.3 ms`; это контроль стабильности, не FPS-доказательство кеша.
- `static-local-matrix-default-gate-20260919`: REJECT default-on. Точный блокер — после freeze локальная мутация `position/quaternion/scale/matrix` не обязана снять заморозку до world-update/raycast; возможна устаревшая матрица. Production не менялся, текущий opt-in сохранён.
- Astra 3 получила одну следующую задачу `static-local-matrix-mutation-failopen-20260919` с неизменившимся полным исходным пакетом и повторно проверенными hashes. Цель — fail-open и точное восстановление без потери качества; receipt подтверждён.
- `vehicle-batch-bounds-refresh-20260919`: ACCEPT_RESEARCH. Для основного `vehicle_render_batches` пропущенный AABB refresh не подтверждён; root/door motion учитывается `matrixWorld`, member/detail/damage paths пересчитывают box, отсутствие box уже fail-open. Предложенный большой тест пока не применён: он не доказывает отдельного wheel-owner и фактического порядка pose/damage → update → render.
- Astra 1 получила `vehicle-wheel-batch-bounds-order-20260919`: полный актуальный wheel-owner плюс точные caller excerpts и hashes. Проверка запрещает уменьшение колёс, машин, теней, дальности, геометрии и качества; receipt подтверждён.
- `collision-bounds-scratch-buffer-20260919`: REJECT_SINGLE_SCRATCH. Точный reentry chain `sweep → footprint.overlaps → solidAtContact → groundHeight → query(sweep) → bodiesInBounds` может перезаписать единственный scratch, пока внешний iterator активен. Production не менялся; публичный свежий массив `queryBounds` сохранён.
- Astra 5 получила `building-report-cache-adversarial-tests-20260919` с полными актуальными helper/test текстами и hashes. Она независимо проверяет вложенные мутации, clear/rebuild и exact byte parity; production писать запрещено.

## 2026-09-19 — NPC idle trig

- `npc-pose-actor-cost-split-20260919`: ACCEPTED_INTEGRATED. В `hero_walk::posturePose` вычисления `sin(phase)`/`cos(phase*2)` перенесены ниже уже существующего early return для обычной стойки; формулы, cadence, gait, surface, weapon/aim, reactions, water и callbacks не менялись.
- Регрессия `test_npc_pose_idle_trig.mjs`: 64 idle-вызова `sin/cos 64+64 → 0+0`; exact scalar parity на границах crouch/prone. ABBA CPU proxy, 32,768 warmup + 262,144 измерений: before mean `15.8111 ms`, after mean `2.82835 ms` (`-82.1%` только внутри микрофункции, примерно `0.0495 µs` экономии на idle-вызов; не FPS).
- Полные проверки PASS: `test_hero_walk.mjs`, `test_npc_pose_clock.mjs`, `test_npc_actor.mjs`. LIVE reload PASS: 71 seen / 19 visible, console errors 0, frame p50/p95 `72.0/89.0 ms`, GPU `29.41/41.87 ms`, NPC `6.4/16.1 ms`; визуально NPC, оружие, машины, трава и тени сохранены. LIVE-снимок не строгий A/B и не приписывается этому микропатчу.
- Следующая `npc-source-stage-attribution-20260919` была первоначально отправлена со stale hash `ee283...`; параллельный рабочий файл изменился до `fe173a...`. Попытка correction во время active ответа отклонена системой. Любой результат старого пакета считать `STALE_SOURCE`, после финала перечитать и выдать свежий полный пакет; повтор сейчас не отправлять.

## 2026-09-19 — отзыв building report cache

- `building-report-cache-adversarial-tests-20260919`: CONFIRMED_CORRECTNESS_DEFECT. Astra 5 доказала, что shallow stamp по top-level ссылкам не замечает вложенную мутацию `roomWorld`/`interiorDesign`/массивов; после clear/reuse WeakMap также мог вернуть прежний JSON.
- Предыдущее `ACCEPTED_INTEGRATED` для `building-report-generation-cache-20260919` отозвано. Несмотря на синтетическую экономию `0.2945 → 0.0180 ms` раз в публикацию, выигрыш недостаточен для риска устаревшей диагностики.
- `building_entry_report_cache.mjs` и его тест удалены, `walk_preview.mjs` возвращён к прямому `JSON.stringify` полного объекта с `doors: buildingEntries.map(entry=>entry.report)`. Игровая геометрия, входы, интерьеры, NPC, дальности и визуальное качество не менялись.
- Проверки после отката: syntax PASS; detention, hospital, tower и render-freeze suites PASS. Два существующих building-теста имеют несвязанные текущие падения: scale guard и floating-point `5.68e-14` против exact zero. Они не вызваны откатом и не исправлялись.
- LIVE после отката PASS: `buildingEntry` успешно парсится, `count=78`, `doors=78`, ошибок консоли 0. Контрольный снимок: frame p50/p95 `73.6/82.1 ms`, GPU p50/p95 `33.69/42.03 ms`, main/shadow/total passes `1720/1252/2972`; это проверка стабильности, не A/B-доказательство отката. Визуально сохранены герой, оружие, NPC, транспорт, город, трава, тени и HUD.

## 2026-09-19 — следующая загрузка Astra

- Astra 1 `vehicle-wheel-global-shadow-order-20260919`: LOCAL_SAFE_GLOBAL_UNKNOWN. Локальный owner обновляет wheel bounds после pose/damage, но первый bounded package не содержал всех поздних frame-paths. Отправлен ровно один следующий полный по заявленной области пакет `vehicle-wheel-shadow-order-final-20260919` с source-vehicle, water, window-fire, combat, fleet sync и render wrapper.
- Astra 2: stale `npc-source-stage-attribution-20260919` отвергнут без применения. Отправлен свежий `npc-bridge-roster-allocation-audit-20260919` с полным текущим `npc_population.mjs`, актуальными excerpts `world.html`, MAIN_SHA, working hashes и новым SOURCE_SNAPSHOT_ID.
- Astra 3 `static-local-matrix-mutation-failopen-20260919`: DEFER_RISKY_PROTOTYPE. Предложены monkey-patches `updateMatrix`/`raycast` без запусков и измеренного выигрыша; default остаётся OFF. После двух timeout и read-back без сообщения сокращённый точный vendor-пакет `static-local-matrix-vendor-contract-20260919` принят системой; повторов нет.
- Astra 4 `static-batch-admission-census-20260919`: DEFER_RUNTIME_INSTRUMENTATION — безопасная новая категория batching не доказана, production census не применяется. Выдан `static-admission-offline-census-20260919`: только фактические fixture-тесты, без runtime complexity.
- Astra 5 после подтверждения stale JSON получила `building-current-test-failures-triage-20260919` для двух существующих падений building suites; только test-only исправление, если production корректен.

## 2026-09-19 — LIVE-оптимизация взрыва без потери качества

- `world-blast-static-bounds-prune-20260919`: ACCEPTED_INTEGRATED. `applyWorldBlast` теперь пропускает целиком только явно помеченные неподвижные `InstancedMesh` с заранее рассчитанным консервативным `boundingBox`; эвристика по draw usage запрещена. Opt-in добавлен траве, этажам, парковке, интерьерной мебели, интерьерным и кровельным лестницам, оконным рамам/стеклу. Динамические двери, машины, частицы, осколки и vehicle batches не включены.
- Точный regression grass: кандидаты `120→120`, broken/surface parity, `instancesTested 600→120` (`-80%`), `prunedInstancedMeshes=8`. Forest regression: кандидаты `3→3`, `28,997→908`, `prunedChunks=65`; текущий `test_world_blast.mjs` также PASS.
- Профильные suites PASS: `test_environment_grass.mjs` 13/13; `test_city_parking.mjs` 39 lots / 59 bays; `test_interior_mesh_pool.mjs` 5/5; `test_residential_windows.mjs` все 9 pinned profiles. Syntax и scoped `git diff --check` PASS.
- Сопоставимый LIVE RPG выстрел в той же стартовой сцене: до расширенного opt-in `candidates=12`, `surfaceHits=1`, `scorch=1`, `instancesTested=16,866`, `prunedInstancedMeshes=3`; после `12/1/1`, `instancesTested=8,246`, `prunedInstancedMeshes=339`. Это `-8,620` или `-51.1%` проверок экземпляров при совпавших эффектах. Не объявлять это строгим frame-time A/B: население и rolling render window между reload менялись.
- LIVE ошибок blast/Three нет. Сохраняются прежние локальные предупреждения HTML вместо JSON для apartment/business endpoints; они не вызваны patch.
- Astra 1 `vehicle-explosion-detach-cost-audit-20260919`: SAFE_MICRO_ONLY — индексный цикл вместо `slice().entries()` сохраняет порядок/RNG/10 деталей, но не доказан причиной фриза; production не применён.
- Astra 2/Astra 3 независимо REJECT безусловного удаления второго root matrix refresh: callbacks/getGlass могут менять transforms между refresh и `applyWorldBlast`; контрпример сохранён, production не менялся.
- Astra 4 `blast-scorch-visual-cost-audit-20260919`: TEST_ONLY_CANDIDATE — caller-owned `intersectObjects` result array может убрать до `Q-1` массивов, но не основную ray/triangle работу; пока не интегрирован.
- Astra 5 `blast-current-ab-benchmark-20260919`: BENCHMARK_DESIGN_NOT_RUN; текущие численные LIVE/регрессионные данные получены checker-ом, предложенный benchmark ещё не принят.
- После чтения финалов все пять чатов были idle и получили ровно по одной новой узкой задаче с фактическими текущими текстами, MAIN_SHA и hashes: Astra 1 `vehicle-detached-bounds-exact-cache-audit-20260919`; Astra 2 `blast-surface-ray-occlusion-audit-20260919`; Astra 3 `blast-static-bounds-safety-regression-20260919`; Astra 4 `blast-surface-ray-scratch-rebase-20260919`; Astra 5 `blast-static-bounds-current-ab-benchmark-20260919`. Все пять send receipts подтверждены; повторов не отправлять.
## 2026-09-19 — LIVE range-pruning железной дороги при взрыве

- `world_blast.mjs` получил fail-open поддержку точных статических диапазонов экземпляров; `exploration_railway.mjs` публикует консервативные диапазоны по 64 экземпляра для рельсов, шпал и статических деталей платформ/переездов. Геометрия, количество экземпляров, порядок instance ID, материалы, тени, дальность и визуальное качество не менялись.
- CPU parity на фактическом railway plan: candidates `59 → 59`, instancesTested `3990 → 182` (`-95.4%`), пропущено `3808` заведомо далёких экземпляров. Grass, forest, полный world blast, railway и city railway access suites PASS.
- LIVE, один RPG-выстрел в той же игре: candidates `12`, surfaceHits `1`, scorch `1`, broken `0`; instancesTested `8246 → 4310` (`-47.7%` от предыдущего принятого результата, `16866 → 4310`, `-74.4%` от исходного). Пропущено `3936` экземпляров по 66 диапазонам. Новых blast/Three ошибок нет.
- Это оптимизация всплеска взрыва, не обычного кадра. После прогрева текущий общий frame p50/p95 `80.2/91.6 ms`, render `67.6/77.4 ms`, GPU `32.26/46.06 ms`, main/shadow/total passes `2048/1059/3107`. Пользователь прав: постоянные подтормаживания остаются; следующий приоритет — render submit/draw workload без удаления NPC, города, теней или дальности.
- MAIN_SHA `3442bf0d84dd66e787005aa2bbb456caf298b9ca`; hashes: `world_blast.mjs` `235b63d53e88d3ad25790884c1172944df746aa30802441d5f7a0443c5b32715`, `exploration_railway.mjs` `c11a7b1bd7a146aa03df8d3a81f996aa8522245f9632a34f13beb1089c84f098`, railway regression `8ad6f3346f0e47ed147fbc48f28ea919508010bd0dd3f1f8148922bb5faab649`.
## 2026-09-19 — пять Astra переведены со взрыва на постоянный кадр

- Все пять предыдущих blast-задач завершены. Astra 1/A2/A4 подтвердили конкретные parity-риски кэширования bounds/raycast scratch; небезопасные сокращения REJECT. Astra 3 дала test-only кандидат для opt-in static bounds, Astra 5 — неисполненный benchmark design; текущая checker-owned railway регрессия и LIVE уже дают более свежую проверку.
- После повторной проверки фактических текущих текстов и hashes каждому свободному чату выдана ровно одна новая задача: Astra 1 `static-house-unbatched-call-audit-20260919`, Astra 2 `npc-model-draw-call-audit-20260919`, Astra 3 `static-shadow-conservative-cull-audit-20260919`, Astra 4 `static-material-equivalence-batch-audit-20260919`, Astra 5 `static-batching-visual-parity-harness-20260919`.
- Все пять send receipts получены. Пакеты содержат фактические тексты нужных source/test, MAIN_SHA `3442bf0d84dd66e787005aa2bbb456caf298b9ca`, working-tree hashes и SOURCE_SNAPSHOT_ID. Production/LIVE/API запрещены; обязательны точная визуальная/теневая/механическая parity и отсутствие уменьшения NPC, дальности, геометрии или качества.
- После сохранения LIVE blast-профиля единственная игровая вкладка переведена с диагностического URL (`npccombatqa=1&npctransportqa=1&perfqa=1`) на обычный `world.html?direct=1&previewcity=1&render=3d&renderer=walk&weapon=rpg&cash=5000`. Город загрузился, QA-панели и `walkPerformance` отсутствуют. Это убирает измерительный overhead без изменения графики/контента; строгий FPS A/B для обычного URL не заявляется.

## 2026-09-19 — static architecture material equivalence LIVE

- REJECT до production: частичное batching multi-material old-town shell оказалось ложным направлением — `GLTFLoader` уже разделяет primitives на отдельные single-material meshes. Попытка полностью отменена, её результат не учитывается.
- ACCEPTED_INTEGRATED: только для четырёх проверенных семейств жилых домов и точных статических архитектурных категорий ключ batching теперь использует полное каноническое состояние `MeshStandardMaterial`, а не UUID экземпляра. Texture, custom shader hooks, clipping и неизвестные категории fail-open остаются раздельными. Двери, стекло, динамика, геометрия, тени, дистанции и контент не сокращались.
- Текущие hashes: `static_render_batches.mjs` `f01bd0c8480b448daa683a37ca06f2704cddfb5e4a1f9d6259c80d6a815d9ebc`; `test_static_woodland_batches.mjs` `e02154bc5058988ed61032419f1cc2d1e3845cb257c8c14411c4f9a83c69f7fd`; `test_static_houses_batches.mjs` `92f06dacd73eeba28803c023cb9ef5e5190f330c613ee383fde86c74d09f329d`.
- Проверки PASS: houses/woodland/render/visibility/culling/interior-disposal. Actual GLB parity проверяет вершины, индексы, canonical material state, world matrices, source instance colors, exclusions, raycast, visibility/culling и disposal.
- Структурный fixture всех 22 old-town домов: main-like submissions `1408 → 464` (`-67.0%`), shadow submissions `1298 → 375` (`-71.1%`). Это локальная структура домов, не FPS всей игры.
- Сопоставимый LIVE после прогрева: frame p50/p95 `80.2/91.6 → 73.8/90.1 ms`; render `67.6/77.4 → 61.3/69.9 ms`; GPU `32.26/46.06 → 27.69/45.94 ms`; main/shadow/total submissions `2048/1059/3107 → 1762/987/2749`. Медиана кадра улучшилась на `8.0%`, render p50 на `9.3%`, GPU p50 на `14.2%`, total submissions на `11.5%`; p95 кадра изменился лишь на `1.6%`, поэтому кардинального устранения лагов не заявлять.
- Остаточный профиль: `worldUpdate` p50/p95 `14.9/16.8 ms`, render main submit `29.0/33.3 ms`, shadow `15.6/17.2 ms`, NPC stage `7.3/10.4 ms`; крупные группы environment `1225/557`, residents `680/82`, traffic `721/307` main/shadow. Следующие цели — hillstep, NPC и traffic без снижения качества.
- Финалы Astra: A1 REJECT generic static widening; A2 DEFER one 11-mesh curly candidate pending lifecycle proof; A3 REJECT broad static-shadow culler по stale projection counterexample; A4 REJECT shared geometry pool без immutable lifetime proof; A5 HARNESS_ONLY/NOT_RUN. Production по этим предложениям не менялся.
- Новые TASK_ID: A1 `hillstep-native-call-census-20260919`, A2 `npc-curly-batch-lifecycle-proof-20260919`, A3 `audited-static-material-key-safety-20260919`, A4 `traffic-render-call-bounded-candidate-20260919`, A5 `static-material-equivalence-current-parity-20260919`. Receipts подтверждены для всех пяти; A4 после первого timeout был перечитан, задача отсутствовала и отправлена один раз без дублирования.

## 2026-09-19 — static batching safety RED→GREEN

- Astra 3 `audited-static-material-key-safety-20260919`: ACCEPTED_DEFECT. Конкретный counterexample: одинаковые audited materials с разными `layers.mask` объединялись в один batch; mesh render/shadow callbacks и custom depth/distance materials также не имели безопасного переноса. `Material.clone()` в Three r180 не сохраняет custom `onBeforeCompile`/`customProgramCacheKey`; поздняя замена source material могла быть перезаписана при dispose.
- Исправление интегрировано: layer mask входит в ключ и переносится на batch; mesh callbacks/custom depth/custom distance fail-open; shader hooks явно копируются; cross-UUID material equivalence разрешена только для owner-tagged `staticRenderMaterialImmutable`; поздняя замена source material выключает только соответствующий batch member и сохраняется при dispose. Теги добавлены только фактическим статическим генераторам entry/storey/stair/roof-sign.
- Adversarial regression PASS: два разных layer batches `3+3`, untagged equivalent materials не объединяются, callback/custom-depth sources остаются source-rendered, custom shader hooks совпадают по identity, late replacement уменьшает batch visibility `3→2` и переживает dispose.
- Полные проверки PASS: static render/visibility/culling, actual house GLB для 22 old-town + 3 hillstep + 2 pine, actual woodland vertices/indices/raycast, interior disposal и 43-room/675-pane integration. Структурный выигрыш домов сохранён: old-town `660 source meshes → 12 batches / 3608 members`, hillstep `105→12/168`, pine `64→9/106`.
- Новые hashes: `static_render_batches.mjs` `2f4b5c9b50e7592e1c2a12f87aed274dc9282e1e30cd1aca8c45d048b1c6bfa7`; regression `55688e4c9d3a844c45bfe4b4a99be68fc98755ea534821a45e7fa34875b1adbe`.
- LIVE после safety-патча технически чистый, ошибок нет, static stats `21 optimization batches / 3944 members`, но frame A/B НЕСОПОСТАВИМ: текущая сцена содержит 15 traffic actors и traffic вырос до `1207/611` main/shadow против предыдущих `721/307`. Текущий прогретый frame `92.6/129.5 ms`, render `74.8/111.3`, GPU `39.42/135.47`; это изменение нагрузки/популяции, не доказанная регрессия safety-патча. Статический census остаётся около прежнего (`144` активных calls).
- A2 `npc-curly-batch-lifecycle-proof-20260919`: REJECT_NO_CONSUMER_PROOF; production не менялся. Ему выдан свежий полный consumer/lifecycle пакет `npc-curl-full-consumer-lifecycle-20260919`. A3 получила независимый review текущего RED→GREEN `static-batch-safety-redgreen-review-20260919`. Оба receipts подтверждены.

## 2026-09-19 — завершение текущего пакета и пауза диспетчера

- Astra 3 `static-batch-safety-redgreen-review-20260919`: ACCEPTED_DEFECT. Найден точный A/B-дефект: последовательность `setOptimizationEnabled(false) → update() → setOptimizationEnabled(true)` обнуляла visibility census и временно скрывала архитектуру. Исправление различает штатно восстановленный source material при OFF и внешнюю замену материала; внешняя замена по-прежнему fail-open.
- Добавлен RED→GREEN regression на существующем layer fixture: после OFF/update сохраняются 6 видимых source members, batches скрыты; после ON те же 6 members и оба layer batches видны немедленно, source materials снова скрыты.
- PASS: static render, visibility, culling, actual house GLB (`old-town 660→12/3608`, `hillstep 105→12/168`, `pine 64→9/106`), actual woodland (`64 source meshes`, `106 members`, `9 batches`), interior disposal и building/window integration. Текущие hashes: `static_render_batches.mjs` `523d63b1a1406ddf1e73638de42efb32d89ecdb62975f49c7d36ed3ff5ee73a5`; `test_static_render_batches.mjs` `5a60383804de98b8e5203389a5b2d9a041980ccb82c027423ee35b3ae4c5ee31`.
- Astra 2 `npc-curl-full-consumer-lifecycle-20260919`: REJECT. Прямое объединение 11 curls нарушает CPU ground/tumble vertex traversal и не покрывает оба disposal path; production не менялся.
- По прямому запросу пользователя непрерывная оптимизация и выдача новых Astra-задач поставлены на паузу после завершения этого пакета. Все пять Astra idle; новых TASK_ID не отправлено.
