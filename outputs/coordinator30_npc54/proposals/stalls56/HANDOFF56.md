# Stalls56 — очередь услуг и накопление неподвижных жителей

База: точная `outputs/coordinator30_release55/game`. Она не изменена. Применение
к новому кандидату: `apply56.py <project>` либо `apply_to(project)` внутри
scheduler write lease владельца. `PATCH56.json`: 8 точных hunks, 5 файлов;
SHA256 `dead440a0780f16814d28fb22df980b85e53324fec401068d91b2b6d7e6739ad`.
Полные соседские файлы не перезаписываются. Frozen55 заблокирован в apply.

## Причины

1. `shop/npc_economy_visit28.gd:113` корректно устанавливает `WAITING`, когда
   заведение занято. `shop/npc_local_account.gd:237` допускает только `INBOUND`.
   Account отвергает настоящий запрос; economy отменяет маршрут и очередь,
   сохраняет покупку и назначает retry через 8000 мс.
2. `npc_daily_life.gd:1407–1415` считает сохранённую покупку приоритетной даже
   во время cooldown. Он возвращает `true` и не даёт перейти к прогулке или
   занятию. `dsh_economy_priority_pending():1396` также отменяет ambient из-за
   этой покупки. Новые случайные покупки постепенно превращают почти весь
   город в повторяющееся ожидание.
3. Даже после исправления admission необязательная покупка могла бы удерживать
   человека в неподвижной capacity очереди до 120 секунд. В новом поведении
   необязательная покупка при занятом магазине сохраняется, запрос освобождается,
   retry назначается через 8–12 секунд, а человек продолжает обычные занятия.
   Голод (`restore_energy=true`), недостаток денег/банк и медицинский приоритет
   не превращаются в необязательные занятия.
4. `npc_city_daily.gd:594` печатал миллисекунды как `rest_left_mean_s` и сравнивал
   их с 9 как с секундами. Например, `1103.3` означает около 1.1 секунды. Исправлен
   перевод в секунды. Это ошибка диагностики, не причина реальной остановки.

Снимок живого лога: `LOG_AUDIT56.json`. Уже более10 000 отказов у более278
разных жителей. На frame13800: 268 RESTING, 16 WALKING; 1512 прогулок и 7 покупок
завершены. Ресторан/банк/больница — 0. Эти нулевые счётчики сами по себе не
доказывают отказ услуг: исходный запуск имеет здоровых людей с 1000 cash и высокой
энергией. Нужна проверка фактически возникшей потребности, а для больницы —
настоящее повреждение. Ранее frame4200 действительно имел 0 покупок, но позднее
лог показал 7; утверждение «не было ни одной покупки за весь запуск» неверно.

## Бюджеты и нагрузка

- Общего single-resident lock в этом пути нет. `npc_city_daily.gd:60` выполняет
  каждый активный physical life, а dormant decisions ходят по rotating slice.
- `hospital/npc_route_budget29.gd:5`: общий soft 1800 µs, до 128 units/frame,
  384 jobs, 65536 nodes, 131072 heap items. Это бюджет только incremental planner.
- `navigation/npc_navigation_work29.gd:5`: 384 guides, 2 native inflight,
  1 submit/frame, preparation600 µs. Его лимиты не охватывают move_and_slide,
  ground/capsule support и визуал каждого жителя.
- `venues/npc_venue_capacity29.gd:4`: 512 requests; waiting120s, offer15s.
  Registry default capacities: shop4, restaurant6, bank2, hospital4 на место;
  штатные staff venues могут предоставлять собственные реальные slots.
- На frame4200 active physical107 стоили29.3ms в одном physics tick, resident
  loop11.4ms. Это свидетельство высокой стоимости и не является чистым FPS
  сравнением. Позднее, когда осталось17 активных, physical cost около7–13ms,
  но наблюдаемый FPS всё ещё6. Из этого нельзя объявлять причину FPS исчерпанной
  или утечку отсутствующей. Root ведёт отдельный массовый профиль.

## Исправление и строгие условия

Account принимает `WAITING` или `INBOUND` только с актуальным телом/id/kind,
реальным registry owner и соответствующим состоянием ledger (`waiting` /
`reserved`). Новый `Route.admission_current56` не создаёт receipt и не двигает
NPC. Дебет остаётся исключительно в `settle_economy28`: настоящий DWELL,
подтверждённый интерьер, здоровье, непрерывное пребывание и повторная проверка
владельца. Старые health/threat/respawn hooks не изменялись.

## Native proof и ограничения

`ACCEPTANCE56.json` содержит hashes всех доказательств и историю неудачных
fixture-прогонов. `baseline03` и `fixed03` используют один окончательный harness.
Scheduler headless, source/harness drift0, exit0, stderr0. Проект включает44
скрипта-зависимости, город и модели не копировались. Пользовательская игра
оставалась открыта; производительность не измерялась.

- Baseline: все287 подлинных Account/Economy объектов отвергли WAITING.
- Fixed: 287 admission приняты; попытка списания из WAITING отклонена у всех287,
  cash/bank/spent/inventory/receipts не меняются. Reservation serial отдельно
  увеличивается по назначению и не является оплатой.
- Настоящая FIFO promotion ledger, отмена claims, stale owner/генерация,
  запрет экономики при12/60HP; обычные занятия разрешены во время необязательного
  retry, а голод сохраняет приоритет. Fixed18/18, baseline15/15.
- Отдельный один actor действительно проходит production `Economy.begin` →
  physical capsule route configuration → waiting admission на native полу;
  optional ветка отпускает очередь, food ветка удерживает её.
- 287 account-проверок используют явно заданные route ports/venue ledger. Это
  **не** 287 реальных городских входов, покупок или доказательство FPS.

## Следующая городская приёмка у root

Не уменьшать287 residents или12 staff, не выключать threat/экономику/respawn.
`observer_counts56.gd` — необязательный QA sampler, максимум1 раз/сек. Он читает
реальные owners без snapshot всего дерева. Отличает capacity, service и portal
очереди от отдыха, ambient, threat и медицинского маршрута.

Доказательство магазина/ресторана/банка: зафиксировать исходные потребность,
кошелёк и цену; затем `economy._phase` WAITING/INBOUND → DWELL → OUTBOUND,
настоящие positions и route._phase; receipt из Account и завершение
`life._completed[kind]` после физического выхода. Одно increase serial/started
или slot reservation недостаточно. Для ресторана использовать настоящую
низкую энергию либо явно документированную QA установку agenda, а банк
проверять при недостатке денег для сохранённой покупки. Нельзя создавать
успешные receipts fixture-кодом.

Больница: настоящее native попадание до12/60HP, HP event id, medical route
INBOUND → treatment/положительный authoritative heal delta → OUTBOUND →
`_completed.hospital` и подтверждённый exterior. Низкий HP не подменять
ручной записью в gameplay receipt. Отдельно проверить смерть во время очереди
и освобождение claims. Полная городская service-приёмка пока PENDING.
