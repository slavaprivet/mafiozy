# READY FOR REVIEW — native-ready cached offline targets

Позднее: root разрешил apply; IMPLEMENTED/CPU TESTED. Актуальная передача и
exact production validation — `NPC_CACHED_TARGET23_HANDOFF.md`. Ниже сохранена
история до apply; кандидатный patch не применять повторно.

23 сентября 2026, Художник21. По конкретному поручению координатора20 после
публикации `f70cba1ee293b8111fcf329073858c3313b6cc21`.
**ISOLATED CANDIDATE; world production НЕ изменён.**

## Один reviewable patch

`outputs/npc_cached_target23_candidate.patch` (82 строки unified diff, два
участка world), `git apply --check` PASS с сохранёнными mixed line endings.
Генератор: `npc_cached_target23_candidate.mjs:buildCachedTargetCandidate23`.

1. Рядом с `_nearestEmpireWalkPoint` — ранее проверенный Nico full-footprint
   predicate/nearest и новый `refreshEmpireCachedTargets23`.
2. В `registerWalkNpcNavigationResolver` — вызов refresh только при ненулевом
   resolver, отличающемся от прошлого; исходный `_npcInitialSafePlacement` сохранён.

Nico helper — явная зависимость этого единого patch: без него Nico снова выберет
тот же unsafe footprint. Это не guardkind/collect/транспортный пакет. Сортировка
прежних 12 колец nearest сохраняет прежний набор кандидатов и правило nearest;
её 300 synthetic +169 actual geometry parity ранее подтверждены отдельно.

## Узкий scope

Обновляются только `_empireBoss` с текущим `patrol` и точным
`target_id=offline:<specialistId>`. Authenticated поручения/бизнесы не перепривязываются.
Action object, key, generation и позиция NPC сохраняются. Исправление заменяет
только невалидный физический target; base меняется лишь если был равен старому
target, отдельная base остаётся прежней. Нет переноса NPC или повторного найма.

Проверяются point/body и stationary full footprint. Если близкая допустимая
точка не найдена, прежнее состояние сохраняется. Для изменённого target
отбрасываются только его ready path/frontier; pending request получает новые
координаты при той же generation/targetKey. Empire queue, shared queue и active
cohort не удаляются/не переставляются; обычный следующий slice строит маршрут.

Бой/паника/stun, машина/посадка/угон, помещение, лечение, разговор и другой
владелец route/request исключены. Для pending action проверяется его generation
и targetKey; stale/чужой request не перезаписывается. Повторная регистрация того
же resolver вообще не запускает target scan.

## RED → GREEN

- Actual исходный registration сохраняет шесть невалидных целей.
- Baseline actual planner для всех шести: 0/6 READY.
- Candidate **через изменённый registration hook**, затем actual planner и
  `_npcAdvanceRoute`: 6/6 READY/arrived, full swept movement 0 blocked.
- Leila20.50м, Alisa19.46м, Inga56.25м, Nico43.80м, Viktor13.20м, Musa42.17м.
  Максимальный шаг .168572 cell; ни одна позиция не меняется в refresh.
- 13 остальных целей/акторов полностью unchanged (JSON состояния до/после),
  action ownership/generation сохраняются для всех 19.
- `test_npc_cached_target23.mjs`: 7 групп PASS, 39 excluded states; queues/cohort
  order unchanged, stale pending protected, missing candidate protected,
  same resolver zero repeated queries, invalid registration/null/renderer gates.
- Синтаксис candidate HTML: все 7 inline scripts PASS. Patch applicability PASS.

Физические отчёты: `outputs/empire_live_route_replay23_registration_baseline_six.json`,
`...registration_six.json`, `...registration_valid_thirteen.json`.
Lifecycle: `outputs/npc_cached_target23_candidate.json`.

В capture нет исходных activity/base координат: в physical fixture они явно
инициализированы captured current target. Это ограничение не скрыто; отдельная
отличающаяся base проверена lifecycle-тестом. `_npcInitialSafePlacement` в
изолированном hook тесте — граничный no-op, чтобы не дублировать его собственный
repositioning; реальные boss исключены из его source eligibility.

## Стоимость

100 тёплых чередующихся baseline/candidate samples для каждого из 19 actual
geometry fixtures. Сумма выровненных по индексу индивидуальных samples:
p50/p95 0.0186/0.0209 → 0.9860/1.2162 мс. Это добавленная стоимость проверки
целей при ready, НЕ один одновременный callback общей сцены и НЕ FPS.
Первый холодный вызов для Leila около1.1мс; остальные per-actor меньше0.6мс.
Обычные кадры этот scan не вызывают. Повтор same resolver — 0 geometry queries.
Отчёты `npc_cached_target23_cost_summary.json`, `...registration_all_cost.json`.

Производительность общей сцены не проверена. Нужно root LIVE в существующей
вкладке после согласованного reload: эти шесть целей, отсутствие телепорта,
13 сохранённых целей, обычные frame p50/p95 после прогрева. Это не исправление
всего живого города и не authoritative boss war.

## Воспроизведение до apply

`node test_npc_cached_target23.mjs`

`node test_empire_live_route_replay23.mjs assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json unique_leila unique_alisa unique_inga unique_niko unique_viktor unique_musa --current-target --refresh-candidate --walk-result --report=registration_six --summary`

Candidate tests пока строят patch поверх исходного world. После согласованного
apply нужен режим проверки actual deployed helper/registration без substitution;
до этого production/LIVE статус не присваивается. Commit/push — только root.
