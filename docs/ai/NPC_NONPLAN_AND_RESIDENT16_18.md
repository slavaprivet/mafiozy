# Non-plan callback candidate + LIVE resident16 reproduction

19 сентября 2026. Production frozen: никаких production edits в этом этапе.

## Минимальный staged candidate

`test_npc_native_fast_path18_nonplan_candidate.mjs` экспортирует `stageStableNonplanPass(source)`. Exact transform на единственном `_maybePlanResidentBuildingVisit` callsite добавляет cache `npc._residentVisitPass={pointPass:npcWaypointOk,pass:(r,c)=>npcWaypointOk(npc,r,c)}` и использует cached pass в non-plan branch. Смена самой функции npcWaypointOk заменит callback; смена native resolver продолжает инвалидировать штатный A*. Actor flags и dynamic navigation не кешируются.

`node test_npc_native_fast_path18_nonplan.mjs` PASS, actual print-shop/source planner, принудительно шесть deadline checks на slice:

- planned worker: before/after успешен за18 вызовов,0 рестартов, exact door;
- non-plan bandit: before180 вызовов,179 рестартов, результата нет; candidate13 вызовов,0 рестартов, exact door;
- каждый возвращённый отрезок соответствует динамическому callback; после `_beach=true` тот же cached callback честно меняет ответ на false.

Это фикс только identity. Non-plan branch по-прежнему не сохраняет `doorId` между попытками: при нескольких входах случайная смена цели может вызвать новый restart. Нельзя объявлять все non-plan journeys исправленными только по single-door тесту. Данные: `outputs/npc_nonplan_pass_candidate18.json`.

## Resident16: дорогой заведомо недостижимый coarse goal

`node test_npc_native_fast_path18_resident16.mjs` выбирает actual GLB **coastal_orchard_house_v1-002** (fixture по умолчанию выбирал бы001). Selection адаптирован только через test module load hook, shared fixture не изменён.

- LIVE start r139.111932568,c173.181051759;
- actual door r150.89358536790058,c165.7479268829997, совпадает с переданной LIVE целью лучше1e-7;
- start/goal body-clear;
- production current `_civilianRouteTo`, настоящий shared4ms бюджет без других queue owners:43–48 slices,175–197мс CPU, expanded1160/visited1200, false,0рестартов;
- при5FPS это8.6–9.6сек без конкуренции; shared очередь множит ожидание. На25-м срезе одного прогона expanded465/visited489, близко к LIVE488/514.

Причина: в goalRadius.8 находятся только coarse centres150.5,165.5 и151.5,165.5. **Оба body-blocked и connector-blocked.** Поиск никогда не сможет принять goal, но обходит1200 узлов.

Диагностическая fine.25 сетка с тем же footprint/sweep находит физический путь до exact door (1865expanded/2019nodes, около82мс CPU). Это НЕ новый production алгоритм и не предложение повышать лимит.

Есть более дешёвый безопасный подход: в square±2source около двери единственный coarse centre с полным свободным прямым connector — **r150.5,c167.5**, расстояние1.79573652source (7.36м). Перспективное исправление — bounded подготовка реальных goal anchors и exact terminal connector, а не слепое увеличение goalRadius или global fine grid. Передано root, реализация не назначалась этому этапу.

Полные данные/путь/nearbyConnectors: `outputs/npc_resident16_coastal002_audit18.json`. Общая сцена/FPS не измерялись, GPU вкладки не открывались. Fixture не содержит остальных runtime cars/railway и состояния всех активных дверей; это доказательство конкретного статического coarse-goal mismatch текущих файлов.
