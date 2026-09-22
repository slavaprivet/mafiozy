# Художник21 — устаревший поиск охраны, 23 сентября2026

IMPLEMENTED / CPU TESTED. LIVE и производительность общей сцены не проверены.
Scope согласован координатором20: только отмена empire_escort при прямом
следовании/прибытии. Глобальный `_clearNpcRoute` и бюджеты не изменены.

## Причина и patch

Мирная ветка `_empireCrew` в updateNpcs шла к видимому месту формирования
напрямую либо уже достигала его, но `_clearNpcRoute` очищал лишь готовый путь.
`_empirePendingRoute`, `_empireRouteQueued`, retained directed frontier и обе
очереди сохраняли старую заявку empire_escort. Pump продолжал ненужный поиск
после физического подхода; движение меняло origin и могло перезапускать поиск.

Добавлен `_cancelEmpireEscortRoute(n)` в world.html и ровно два вызова: перед
прямым шагом сопровождения и при прибытии/расстоянии<.8. Helper отменяет только
empire_escort, освобождает shared route queue через штатный cancel и удаляет
свою заявку из empire pump queue. Если текущая заявка другого владельца
(empire_action/recruit/retreat), она остаётся. Никаких телепортов/новых целей.

## Проверки

- `test_empire_escort_cancel23.mjs --require-fixed`: actual crew branch/pump/
  planner. До первого допуска, с retained frontier и уже по прибытии:
  после подхода раньше оставалась1заявка и41–43запроса passability;
  теперь0заявок/0запросов. Физический шаг одинаковый. Другие3 kind сохраняются.
- `test_empire_escort_cancel_geometry23.mjs`: actual city collision snapshot,
  наблюдённые позиции Лейлы25.5/23.5 и crew3 25.39554744/20.30881462.
  Slot0 и старая заявка24.5/15.5 — контролируемые входы, не полный LIVE replay.
  Одинаковый физический шаг0.1602787456cells и точная позиция после него,
  проверка проходимости PASS. Ненужные navigation predicates37→0;
  единичный pump sample2.5032→0.0798мс (включая fixture nextFrame).
  Это иллюстрация удалённой работы, не устойчивый FPS/whole-world A/B.
- `test_empire_pending_slices19.mjs`:19/19боссов в mixed/long jobs, существующие
  cancellation/generation/one-slice guards PASS.
- `test_npc_route_cohort_drain23.mjs --require-fixed`, check_world7 PASS.

## QA входы для следующего фактического долгого поиска

В `_residentVisitDiagnostics` добавлены scalar `empireRequest` (goal/radius/
maxVisited/kind/generation/targetKey/queued), `empire` (identity/action/target/
formation/retry) и `search` (algorithm/fine/limit/bestDistance/anchor/heap counts).
Нет сериализации фронтира/геометрии или новых navigation queries. Существующий
gate npcqa/1Hz/512actors сохранён. `ageMs` теперь только active pending;
`lastRequestAgeMs` сохраняет исторический возраст. Это устраняет ложное чтение
старого запроса idle escort как20минут текущего ожидания.

`test_npc_empire_replay23.mjs`: actual diagnostics и штатный JSON export roundtrip
PASS,1Hz/QA/512/no-frontier PASS. CPU512 p50/p95 .826/1.109→1.083/1.360мс при1Hz
и включённом npcqa; добавка не относится к обычному выключенному QA.
Старый `test_npc_route_replay_diagnostics19.mjs` PASS.

## Файлы

- world.html: helper+2 вызова; scalar additions в `_residentVisitDiagnostics`.
- test_empire_escort_cancel23.mjs, test_empire_escort_cancel_geometry23.mjs.
- test_npc_empire_replay23.mjs.
- outputs/empire_escort_cancel23.json, empire_escort_cancel_geometry23.json,
  npc_empire_replay23.json.
- Этот handoff; актуальная память ARTIST21_MEMORY.md.

Единственный LIVE у координатора20. READY отправлен для его общего reload.
Следующий source repro: unique_niko/empire_crew_sofia_25 из нового экспорта с
реальными goals; нынешний patch не объявляется исправлением их долгого поиска.
