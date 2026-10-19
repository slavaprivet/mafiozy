# Cached цели Виктора и Мусы: отдельный reproducible gap

23 сентября 2026, Художник21. READ-ONLY / ISOLATED, production не менялся.

## Позднее: проверены цели всех 19 из того же capture

`outputs/empire_live_route_replay23_all_boss_targets.json`, флаг
`--inspect-target`: только физические запросы, route search НЕ запускался
(`planningSkipped:true`; ready=false здесь не означает route failure).
13 целей point/body/full footprint проходят. 6 не проходят:
Leila, Alisa, Viktor — depth2.22м; Inga — point/body/footprintblocked;
Musa — body/footprintblocked; Nico — только full footprintblocked.
Leila/Inga имеют настоящие captured pending requests; остальные — current
targets. Alisa была walking=true: наличие движения не делает её цель безопасной.
Это census координат в fixture, не полный LIVE timed run всех 19 и не
доказательство одинаковой причины исходного выбора каждой цели.

Последующий isolated replay **всех шести** с повторным выбором и Nico full
footprint guard: 6/6 READY и physical arrived, max step .168572 cell,
blockedMovementSweeps=0 для каждого фактического шага, без телепортов.
Пути Leila20.50м, Alisa19.46м, Inga56.25м, Nico43.80м, Viktor13.20м, Musa42.17м.
Отчёт `outputs/empire_live_route_replay23_all_six_invalid_reselected.json`.
Это подтверждает доступность выбранных точек в fixture; runtime cached-target
invalidation всё ещё НЕ реализована и общая сцена НЕ проверена.

Источник: capture `2026-09-22T22:29:59.531Z`, переносимый
`test_fixtures/empire_route_capture23.json`. Оба имеют offline patrol и failure
backoff, НЕ active pending request. Replay использует captured current target и
проверяет source контракт boss request `.8 / 42000 / empire_action`.

| Босс | Сохранённая цель r/c | Actual geometry в CPU fixture | Baseline |
|---|---|---|---|
| viktor | 137.7546228963 / 16.6067969812 | depth 2.22 м, point/body false | EMPTY, 42000 visited, 255 slices, 1029.74 мс суммарного CPU |
| musa | 134.7048205898 / 115.7239273594 | point true, body false, full stationary sweep blocked | EMPTY, 1 visited, 3.29 мс CPU |

Повторная **существующая** `_nearestEmpireWalkPoint` после готовности геометрии,
без нового Nico footprint фильтра, выбирает соответственно `133.5/17.5` и
`134.5/116.5`. Actual planner: 23 и 32 visited, оба READY. Actual `_npcAdvanceRoute`:
13.20 м / 3.43 simsec и 42.17 м / 9.14 simsec, arrived, без телепорта и blocked
сегментов. Это изолированная подмена цели для диагноза, НЕ production recovery.

Новый Nico фильтр здесь даёт те же точки, поэтому этот результат не следует
приписывать его улучшению stationary footprint. У Nico отдельный дефект:
старые body samples принимают цель, которую полный footprint отвергает.

## Source anchors

- `_installNpcEmpireFallbacks` (`world.html:21086`) ставит activity/target только
  при `!npc._empireAction`; повторный fallback не перевыбирает существующую цель.
- Первоначальный вызов — `setTimeout(...,0)` (`21110`). Это не ожидание готовности
  асинхронной Walk геометрии.
- `registerWalkNpcNavigationResolver` (`70209`) регистрирует native query и
  вызывает `_npcInitialSafePlacement`, не обновляя boss activity targets.
- `walk_preview.mjs:510` регистрирует `npcNativeNavigation.query`.
- Boss ветка `updateNpcs:18665` предпочитает существующий `_empireTarget`.
- `loadNpcEmpireState:22240` меняет цель только при новом action key.

Гипотеза: цель могла сохраниться до native geometry/resolver или до её изменения.
Время её исходного выбора не записано в capture, поэтому именно этот порядок
LIVE пока не доказан. Подтверждены невалидность текущих координат в fixture и
успех штатного повторного выбора.

## Возможный следующий bounded scope

После unfreeze согласовать invalidation только мирного offline patrol при
появлении native resolver/подтверждённой невалидности cached цели. Не перевыбирать
каждый кадр, не менять authenticated business/raid identity, не телепортировать
босса, не добавлять поиск вне общего бюджета. Сохранять action/base/current
target согласованными; отменять старую pending/frontier прежде нового запроса.
Один лишь Nico nearest patch не переустанавливает уже cached target.

Проверки до runtime: correct target не меняется; повтор same resolver не churn;
другая generation и боевой приказ защищены; одна отмена очереди без обхода старших;
реальный маршрут к новой точке. Затем root LIVE на тех же Viktor/Musa.

Отчёты:
- `outputs/empire_live_route_replay23_other_backoff.json`
- `outputs/empire_live_route_replay23_other_backoff_original_reselect.json`
- `outputs/empire_live_route_replay23_other_backoff_reselected.json` (Nico filter comparison)

CLI расширен только флагами `--reselect-current` и безопасным `--report=<tag>`.
Пример: `node test_empire_live_route_replay23.mjs assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json unique_viktor unique_musa --current-target --reselect-current --walk-result --report=other_backoff_original_reselect`.

Обе цели вне building footprint, поэтому fixture грузит hospital как обычный
контрольный GLB; ландшафт/water и прочие static colliders соответствуют fixture.
Нет original frontier, runtime railway/машин/GPU/таймлайна. Simsec — физический
CPU replay без конкурентов; производительность общей сцены не проверена.
