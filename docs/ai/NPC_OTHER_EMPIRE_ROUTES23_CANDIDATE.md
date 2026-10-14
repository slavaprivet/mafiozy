# Охрана / набор / отступление: isolated native routing

ПОЗЖЕ: actual guard-post producer scenario выявил6/12reached какдо,такпосле
и ростCPU при native. Guard production candidate пока НЕ принят; см.
`NPC_GUARD_POSTS23_REJECTION.md`. Ниже остаётся результат прежней ограниченной
выборки, он не отменяет нового отрицательного теста.

23 сентября 2026, Художник21. CANDIDATE ONLY; runtime freeze сохранён.

Из audit подтверждён геометрический дефект: `world.html:_planNpcRouteTo`
отправляет empire_holding_guard / empire_recruit / empire_street_recruit /
empire_retreat в coarse поиск, хотя empire_action/escort уже используют native
planner со swept edges. Физические задачи существуют, менять их сценарии не нужно.

`test_empire_other_kinds23.mjs` читает actual source и сравнивает три варианта в VM:
production; только допуск четырёх kinds к существующему native helper; допуск плюс
существующая точность intermediate waypoints в `_npcAdvanceRoute` для этих kinds.
В world, planner-source, здания и бюджеты изменений нет.

## Геометрический результат

Переносимый `test_fixtures/empire_other_kinds23.json`: шесть прежних scalar route
inputs, четыре исторически проблемных + два контроля, один район/общая стартовая
точка. Каждый проверен с четырьмя actual kind/radius/limit контрактами из source.
Это специально выбранная диагностическая выборка, НЕ процент проблем всего города
и НЕ реальные captured guard задания.

| Вариант | Прибыл | Пути с unsafe edge | Реальные шаги с blocked sweep | Pending |
|---|---:|---:|---:|---:|
| Production coarse | 12/24 | 16/24 | 16/24 | 0 |
| Только native planner | 24/24 | 0/24 | 0/24 | 0 |
| Planner + точность углов | 24/24 | 0/24 | 0/24 | 0 |

Actual `_npcAdvanceRoute` проходил пути, каждый шаг отдельно проверен полным
swept radius .18. Телепортов нет. Различие 12 blocked и 16 unsafe объясняется тем,
что некоторые coarse пути возвращают arrived несмотря на пересечение, поэтому
одного признака arrived недостаточно для приёмки.

Точность углов в этих шести маршрутах не даёт отдельного прироста: не заявляем,
что необходимость второй строки доказана этой выборкой. Применение только guard
kind первым пакетом позволяет держать реальный scope ещё уже.

## Стоимость и отмена

CPU поиска суммарно 354.13 → 64.92 мс для 24 запросов; p50/p95 на запрос
0.846/119.382 → 1.297/7.239 мс. Это сумма slice costs на запрос, не frame time.
Медиана коротких запросов выросла; тяжёлые стали дешевле. Pass predicate calls
37484 → 6470. Порядок AB чередовался, но это один bounded прогон, не city benchmark.
Производительность общей сцены не проверена.

Дополнительно 20 actual pump сценариев (4 kinds × generation/cancel/dead/hidden/hp0):
native pending frontier сохраняется между slice; повтор pump в том же frame не
даёт второй поиск; отменённый запрос не делает новых collision queries и не
публикует stale route. Для этой части стоимость predicate детерминированно
учитывается как .25 мс; её числа НЕ включены в CPU AB выше.

Запуск: `node test_empire_other_kinds23.mjs`. Отчёт
`outputs/empire_other_kinds23_candidate.json`. Actual hospital GLB, остальные
объекты — static snapshot colliders; runtime транспорт/railway/GPU не воспроизведены.

Следующий этап только после root SHA/unfreeze: выбрать один kind, например
holding_guard, и получить реальный guard→post replay/наблюдение. Внедрение всех
четырёх kinds этим CPU результатом не считается согласованным.
