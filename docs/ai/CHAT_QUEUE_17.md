# CHAT QUEUE 17

Актуальный протокол: CHAT_CHECKER_17.md. Срез 2026-09-19T16:39:18.2774112Z. Источник — working tree поверх main, не старый snapshot.

| Чат | TASK_ID | Состояние | MAIN_SHA | SOURCE_SNAPSHOT_ID | MANIFEST_AT | STALE_REASON |
|---|---|---|---|---|---|---|
| Astra 1 | grass-cell-index-parity-20260919 | ACCEPTED_RESEARCH | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 4a3e599dd600002edf3d7a9434d7a78acbfec9b9c0aa2be159622475bcb18612 | 2026-09-19T16:39:18.2774112Z | — |
| Astra 2 | npc-adapter-callback-effects-20260919 | ACCEPTED_RESEARCH | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | b757eaf52427091a3d213b636a731a3e90689c45c8f1685ae097ae27d1a95884 | 2026-09-19T16:39:18.2774112Z | — |
| Astra 3 | world-inventory-duplicate-contract-20260919 | ACCEPTED_RESEARCH | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 9b035d7da3c880a906bd52815a67e1d2852f2e494ace62a5d3607ec30776bdeb | 2026-09-19T16:39:18.2774112Z | whole world.html drifted; bounded current inventory function rechecked and matched |
| Astra 5 | inventory-test-body-coverage-20260919 | PARTIAL_ACCEPT_REVIEW | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | d68228da8fc2f539db47ee1c5e15426b2bcdcf94e24c8dadff32fcabc4cdb8a1 | 2026-09-19T16:39:18.2774112Z | implementation finding superseded; failure/dismiss coverage remains useful |
| Astra 5 | inventory-dismiss-guard-tests-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | e08389060a0930c0b49fd5ca47f2ed381b97d47d71921d0e51e5ea560be65934 | 2026-09-19T16:57:27.9148794Z | — |
| Astra 4 | camera-vendor-parity-20260919 | BLOCKED_NOT_SENT | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | NOT_READY | 2026-09-19T16:39:18.2774112Z | Нет локальной реализации vendor Raycaster/Mesh; сетевое получение запрещено |
| Astra 4 | camera-damping-dt-boundary-20260919 | STALE_REVIEW | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 9ac0a122c0c59bccd2990e57db94bfe049ee4f768c39665fa9c78ff06c070884 | 2026-09-19T16:45:53.2857992Z | clearance and caller changed; current clearance now has 6 m/s cap |
| Astra 4 | camera-visible-ancestor-raycast-parity-20260919 | ASSIGNED_SEND_ACCEPTED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 82c3e5502b3af1cf5c4ea6bc59bdfa199feadffb38aa258407907e5e5199f855 | 2026-09-19T17:02:40.1472663Z | send accepted; history receipt not visible yet, do not resend |
| Astra 1 | vehicle-shadow-default-gate-20260919 | ACTIVE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 11e0d721e8472304c2fc1b7d66eb25df4a6d0ed4eafe8b7b686541cd59019e00 | 2026-09-19 | checker independently accepted default after LIVE A/B; await research final, do not resend |
| Astra 2 | npc-hot-path-frame-cost-audit-20260919 | ACCEPTED_RESEARCH | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 5ac6a3e46f49a947796e23d6bc40a23795825f70bc2f651262f5fd3b74f876a6 | 2026-09-19 | safe boolean-presence candidate; implementation/test pending checker review |
| Astra 2 | npc-distance-square-hotpath-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | current package in chat receipt | 2026-09-19 | exact threshold/quality parity required |
| Astra 3 | diagnostics-static-report-churn-20260919 | DEFER | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 | 2026-09-19 | source package was insufficient; no diff accepted |
| Astra 3 | building-report-generation-cache-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | current package in chat receipt | 2026-09-19 | exact JSON parity and clear/rebuild generation required |
| Astra 4 | static-residential-render-hotspot-20260919 | ACTIVE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | sent current working-tree package | 2026-09-19 | no visual/content reduction allowed |
| Astra 5 | collision-query-allocation-hotpath-20260919 | ACTIVE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 4b2dbbbe976139fddc3c07cb4b18230071e954285f36589b03609bdb6a2a7c03 | 2026-09-19 | exact ordered identity parity required |
| Astra 1 | vehicle-batch-bounds-refresh-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | current full source package in chat | 2026-09-19 | prove moving BatchedMesh bounds conservative; quality gate |
| Astra 2 | npc-distance-square-hotpath-20260919 | REJECT_COUNTEREXAMPLE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | d45f7ed6935bde51931cc9d43f30360c8ff357e094c4fd5e7e0dca3fd6c15566 | 2026-09-19 | finite overflow changes visibility/shadows; do not implement |
| Astra 2 | npc-pose-actor-cost-split-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | current full source package in chat | 2026-09-19 | exact pose/surface/walker parity required |
| Astra 4 | static-residential-render-hotspot-20260919 | ACCEPTED_INTEGRATED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 14e6cbb9ef457147c193f007629c1d7c6b21fb9408caa678d395ac019b113be5 | 2026-09-19 | visibility defect RED→GREEN; no batching removal |
| Astra 4 | static-batch-admission-census-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | current full source package in chat | 2026-09-19 | instrumentation first; no visual behavior change |
| Astra 5 | collision-query-allocation-hotpath-20260919 | REVIEW_ONLY | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | 4b2dbbbe976139fddc3c07cb4b18230071e954285f36589b03609bdb6a2a7c03 | 2026-09-19 | tests only; no measured production improvement |
| Astra 5 | collision-bounds-scratch-buffer-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | current full source package in chat | 2026-09-19 | default fresh-array contract must remain |

Вместо blocked vendor parity Astra 4 получила самостоятельный скалярный вопрос dt/boom recovery с полными indoor_camera.mjs, indoor_camera_clearance.mjs и актуальной полной clampBuildingCamera(dt). PASS: монотонность и границы length при dt/teleport/reset. Raycast/vendor/LIVE явно исключены, контекст не обрезан молча.

Новый vendor-parity пакет использует локальный Three REVISION 180 из D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build, а не GitHub/CDN. Переданы точные Raycaster/Mesh excerpts, текущий resolver и полный текущий test_indoor_camera.mjs.

## Контракты текущих исследований

### Astra 1: grass-cell-index-parity-20260919

Проверь текущий chunksByRow cell-index против прежнего полного обхода chunks: отрицательные координаты, границы, widestTuftRadius, порядок отбора при исчерпании бюджета. Дай конкретный bounded diff регрессионного теста parity старого полного обхода и текущего индекса. Не меняй grass content, fade, дальность, budget, force/pending uploads. PASS исследования: тест сравнивает IDs/order/count/fade, а не только число; запуск не заявляй.

Переданы реальные тексты: assets/maps/city_rebuild_v1/environment_grass.mjs (FULL), assets/maps/city_rebuild_v1/environment_grass_plan.mjs (FULL), assets/maps/city_rebuild_v1/test_environment_grass_selection.mjs (FULL), assets/maps/city_rebuild_v1/test_grass_prefix_uploads.mjs (FULL). Только текстовый материал; изменения production не поручались.

### Astra 2: npc-adapter-callback-effects-20260919

Узко проследи side effects адаптерных getMember/getTarget/moveMember/onAction/scanReviveTargets и внешних callbacks, которые они вызывают. Какие из них нельзя пропускать/кешировать даже на idle NPC? Только статическая карта чтений/записей и один минимальный воспроизводимый counterexample, не патч core. core и test_mercenary_lifecycle_restore.mjs сейчас принадлежат координатору и меняются; их поведение НЕ выводи из старой памяти. GroundHeight/targets implementations не приложены: явно пометь неизвестные эффекты. PASS: конкретные поля и call chain, без предположения о чистоте внешних функций.

Переданы реальные тексты: assets/maps/city_rebuild_v1/mercenary_world.js (FULL). Только текстовый материал; изменения production не поручались.

### Astra 3: world-inventory-duplicate-contract-20260919

Выведи текущий контракт duplicate weapon rows между reconcileInventory и фактическим _syncMyWeaponsFromInventory в world.html. Случаи qty/count/quantity, id/item_id, резерв1 для [1,1], repeated same objects vs fresh objects. Отдели mutation-инвариант количества от UI dedup. Дай один конкретный дефект и bounded исправление только функции reconcileInventory как текст diff (не применять), либо доказательство отсутствия дефекта. Не исследуй lifecycle core. PASS: таблица до/после и объяснение однократного распределения резерва без удаления оружия.

Переданы реальные тексты: assets/maps/city_rebuild_v1/mercenary_world.js (FULL), world.html (22508-22520;38280-38330). Только текстовый материал; изменения production не поручались.

### Astra 5: inventory-test-body-coverage-20260919

Передаю настоящее полное тело существующего test_mercenary_world.mjs, а не отсутствующий test_mercenary_inventory_acceptance.mjs. Узкий review coverage: duplicate reserved rows и failed equip/dismiss, изоляция fixture; проверь реальный _dismissGangMember против stub. Дай bounded diff новых тестов к существующему тесту (без реализации исправления), которые ловят недостающие инварианты. Не трогай hospital/lifecycle/core — ими занят координатор. Не объявляй тесты выполненными; core не приложен, его runtime поведение не предполагается. PASS: конкретные assertions, повторный вызов и fresh vs same row identity, отсутствие повторов существующих тестов.

Переданы реальные тексты: assets/maps/city_rebuild_v1/mercenary_world.js (FULL), assets/maps/city_rebuild_v1/test_mercenary_world.mjs (FULL), world.html (22508-22520;38280-38330). Только текстовый материал; изменения production не поручались.

## Предыдущие задачи — исторические, не активные

Все записи ниже STALE_FOR_CURRENT_SOURCE: свежий MAIN_SHA + working-tree источник не были переданы. Это не утверждение, что старые факты неверны или что завершённые задачи зависли. Старый общий gate не блокирует независимые новые исследования.

- world-distance-grass-budget-20260917: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- grass-selection-dedup-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- decor-distance-root-audit-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- npc-population-update-budget-20260917: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- npc-idle-update-gates-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- npc-state-serialization-budget-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- live-acceptance-gate-20260917: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- report-consistency-check-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- regression-pass-template-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- interior-object-culling-audit-20260917: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- camera-clearance-repeat-audit-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- interior-visibility-transition-check-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- walk-mercenary-inventory-acceptance-20260916: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- mercenary-restore-regression-matrix-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.
- inventory-dedup-test-review-20260918: STALE_FOR_CURRENT_SOURCE; не отправлять повторно.

## Текущая дельта 2026-09-19

| Чат | TASK_ID | Статус | MAIN_SHA | Evidence | Ограничение |
|---|---|---|---|---|---|
| Astra 3 | building-report-generation-cache-20260919 | ACCEPTED_INTEGRATED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | exact JSON tests + synthetic 0.2945→0.0180 ms/publication + LIVE 78/78/no errors | не считать синтетический CPU-прокси FPS |
| Astra 3 | static-local-matrix-default-gate-20260919 | REJECT_COUNTEREXAMPLE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | local transform mutation can remain frozen before world-update/raycast | default оставить off |
| Astra 3 | static-local-matrix-mutation-failopen-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | source 62421cd6b19f7f365fff231f20ee3bdd048732d19e965859c3a04cfd6d1d00d8 | no traversal/visual/raycast regression |
| Astra 1 | vehicle-batch-bounds-refresh-20260919 | ACCEPT_RESEARCH | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | owner refresh traced; no confirmed production defect | wheel owner/order remained unproved |
| Astra 1 | vehicle-wheel-batch-bounds-order-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | wheel source 057b4af2fc508af188eca7f28ad86b31def13dcf290626aa2021f9a12f9212cb | no wheel/shadow/detail reduction |
| Astra 5 | collision-bounds-scratch-buffer-20260919 | REJECT_COUNTEREXAMPLE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | nested groundHeight sweep can clobber one active scratch | default fresh-array contract unchanged |
| Astra 5 | building-report-cache-adversarial-tests-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | helper 2b57393087949a9f1e459c7ebe28ff88de61f8bf45f57c8dd28212eed32e36fd | exact byte parity; no gameplay/quality change |
| Astra 2 | npc-pose-actor-cost-split-20260919 | ACCEPTED_INTEGRATED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | idle trig 128 calls/64 updates → 0; full NPC suites + LIVE PASS | scalar CPU proxy only; no FPS claim |
| Astra 2 | npc-source-stage-attribution-20260919 | INVALIDATED_SOURCE_PENDING_RESEND | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | sent ee283... but current captured fe173a... | reject stale final; resend only when idle |
| Astra 5 | building-report-cache-adversarial-tests-20260919 | ACCEPTED_DEFECT | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | nested mutation + clear/reuse stale JSON counterexamples | production cache reverted |
| Astra 3 | building-report-generation-cache-20260919 | REVERTED_CORRECTNESS | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | exact direct JSON serialization restored | prior CPU result withdrawn from production acceptance |
| Astra 1 | vehicle-wheel-global-shadow-order-20260919 | PARTIAL_GLOBAL_UNKNOWN | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | local order safe; late frame paths absent | continued with complete bounded callers |
| Astra 1 | vehicle-wheel-shadow-order-final-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | SOURCE_SNAPSHOT_ID from exact current excerpts in chat | no wheel/shadow/detail reduction |
| Astra 2 | npc-source-stage-attribution-20260919 | REJECT_STALE_SOURCE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | answered against old ee283... source | no patch accepted |
| Astra 2 | npc-bridge-roster-allocation-audit-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | full current npc_population + current world excerpts | exact roster/order/identity parity |
| Astra 3 | static-local-matrix-mutation-failopen-20260919 | DEFER_RISKY_PROTOTYPE | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | monkey-patched updateMatrix/raycast; not run | default remains off |
| Astra 3 | static-local-matrix-vendor-contract-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | exact local Three r180 Object3D methods | read-only safety verdict |
| Astra 4 | static-batch-admission-census-20260919 | DEFER_RUNTIME_INSTRUMENTATION | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | no safe category proved | production instrumentation not applied |
| Astra 4 | static-admission-offline-census-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | actual static fixtures supplied | test-only evidence |
| Astra 5 | building-current-test-failures-triage-20260919 | ASSIGNED | 3442bf0d84dd66e787005aa2bbb456caf298b9ca | full current failing tests and owners | test-only unless production defect proved |

## Взрывы — текущая принятая дельта 2026-09-19

| Чат/владелец | TASK_ID | Статус | Evidence | Следующее ограничение |
|---|---|---|---|---|
| Checker | world-blast-static-bounds-prune-20260919 | ACCEPTED_INTEGRATED_LIVE | same-effect LIVE `16,866→8,246` instance checks; regression grass `600→120`, forest `28,997→908` | только explicit immutable opt-in; не заявлять rolling FPS A/B |
| Astra 1 | vehicle-explosion-detach-cost-audit-20260919 | SAFE_MICRO_ONLY | `slice().entries()` removable with exact order/RNG parity | не применять без измерения; не уменьшать 10 частей/геометрию/FX |
| Astra 2 | blast-duplicate-matrix-refresh-audit-20260919 | REJECT_COUNTEREXAMPLE | callback can mutate queried root after first refresh | второй refresh сохранять |
| Astra 3 | blast-matrix-refresh-regression-20260919 | REJECT_COUNTEREXAMPLE | `getGlass()` mutation breaks unconditional skip | test-only material; production unchanged |
| Astra 4 | blast-scorch-visual-cost-audit-20260919 | TEST_ONLY_CANDIDATE | reuse one surface-ray result array per blast | require exact ordered hit/payload parity and measured gain |
| Astra 5 | blast-current-ab-benchmark-20260919 | BENCHMARK_DESIGN_NOT_RUN | ABBA design for spatial prune | refresh hashes before any run; current world hash is `405f2900...` |
| Astra 1 | vehicle-detached-bounds-exact-cache-audit-20260919 | ASSIGNED | exact current `vehicle_damage` + detach regression | exact nested-transform/grounding/debris parity; no slice micro-repeat |
| Astra 2 | blast-surface-ray-occlusion-audit-20260919 | ASSIGNED | exact current `world_blast` hash `405f2900...` + LIVE 8,246 remaining checks | preserve nearest occlusion/order/instance semantics |
| Astra 3 | blast-static-bounds-safety-regression-20260919 | ASSIGNED | exact current `world_blast` + grass regression | test-only moved parent/prefix/broken glass/dynamic non-opt-in |
| Astra 4 | blast-surface-ray-scratch-rebase-20260919 | ASSIGNED | exact current `world_blast` hash `405f2900...` | reentrancy/custom raycast/order proof before production |
| Astra 5 | blast-static-bounds-current-ab-benchmark-20260919 | ASSIGNED | exact current world + grass + forest test texts | ABBA only; exact effects; no legacy scorch reconstruction |
## 2026-09-19 — очередь после LIVE blast railway acceptance

- ACCEPT+INTEGRATED `world-blast-railway-instance-ranges-20260919`: LIVE instancesTested `8246 → 4310`, candidates/surface/scorch `12/1/1` без изменений; CPU railway parity `3990 → 182`.
- Следующая checker-owned цель: постоянный кадр. Фактический прогретый профиль: frame p50/p95 `80.2/91.6 ms`, render `67.6/77.4 ms`, GPU `32.26/46.06 ms`, 3107 проходов. Не выдавать оптимизацию взрыва за FPS-исправление.
- Ограничения следующего шага: не уменьшать население, дальность, здания, транспорт, эффекты, тени или качество; требовать fixed-pose LIVE A/B и точную parity-проверку видимости/коллизий/механик.
### Активные Astra-задачи постоянного кадра

| Чат | TASK_ID | Статус |
|---|---|---|
| Astra 1 | `static-house-unbatched-call-audit-20260919` | sent, active |
| Astra 2 | `npc-model-draw-call-audit-20260919` | sent, active |
| Astra 3 | `static-shadow-conservative-cull-audit-20260919` | sent, active |
| Astra 4 | `static-material-equivalence-batch-audit-20260919` | sent, active |
| Astra 5 | `static-batching-visual-parity-harness-20260919` | sent, active |

### Активные Astra-задачи после принятого static architecture LIVE

| Чат | TASK_ID | Статус |
|---|---|---|
| Astra 1 | `hillstep-native-call-census-20260919` | sent, active |
| Astra 2 | `npc-curly-batch-lifecycle-proof-20260919` | sent, active |
| Astra 3 | `audited-static-material-key-safety-20260919` | sent, active |
| Astra 4 | `traffic-render-call-bounded-candidate-20260919` | sent after read-back confirmed first timeout delivered nothing; active |
| Astra 5 | `static-material-equivalence-current-parity-20260919` | sent, active |

### Safety follow-up после доказанного counterexample

| Чат | TASK_ID | Статус |
|---|---|---|
| Astra 2 | `npc-curly-batch-lifecycle-proof-20260919` | REJECT_NO_CONSUMER_PROOF; no production |
| Astra 2 | `npc-curl-full-consumer-lifecycle-20260919` | sent with full current appearance/actor/walker/tests; active |
| Astra 3 | `audited-static-material-key-safety-20260919` | ACCEPTED_DEFECT; checker RED→GREEN integrated |
| Astra 3 | `static-batch-safety-redgreen-review-20260919` | sent with exact current source/tests; active |

### Пауза после завершения текущего пакета

| Чат | Последний результат | Статус |
|---|---|---|
| Astra 1 | `hillstep-native-call-census-20260919` | idle; no accepted production candidate |
| Astra 2 | `npc-curl-full-consumer-lifecycle-20260919` | REJECT; idle |
| Astra 3 | `static-batch-safety-redgreen-review-20260919` | defect fixed and tests PASS; idle |
| Astra 4 | `traffic-render-call-bounded-candidate-20260919` | no accepted production candidate; idle |
| Astra 5 | `static-material-equivalence-current-parity-20260919` | stale/test-only; idle |

Новые задачи не выдавать: пользователь попросил завершить текущую работу и сменить задачу.
