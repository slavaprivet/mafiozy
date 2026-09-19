# NPC isolated-start fine fallback — candidate

19 сентября 2026. **APPLIED в production module после снятия freeze координатором.** Root повторно проверил actual adaptive movement, shop buy/exit и source regressions. Следующая игровая reload/LIVE этой версии ещё не подтверждены.

Candidate source: `test_npc_native_fast_path18_candidate.mjs` экспортирует `candidateSource`. Проверка: `node test_npc_native_fast_path18_adaptive.mjs`. Исходная причина: `docs/ai/NPC_NATIVE_GRID_AUDIT18.md`.

## Узкое исправление

Только если прежний native building_entry A* исчерпал frontier после единственного start node (`qi===1`, `nodes.size===1`), тот же search переходит на шаг .25 source = 1.025 м, привязанный к фактическим r/c NPC. Все остальные маршруты остаются прежними. Fine heap/frontier хранится в том же `_npcDirectedSearch`, ключ цели/позиции и identity pass/resolver продолжают инвалидировать устаревший поиск.

Полный NPC square .18 source, callback samples .14 и continuous native sweep сохранены. Общий лимит поиска не повышен: fine получает `maxVisited-1` после уже рассмотренного coarse start. Общие FIFO, 2 jobs/4 ms не трогаются; каждое продолжение идёт в существующей admitted slice. Fine goal внутри goalRadius принимается только если целиком свободен физический connector к actual door. Fine exhaustion возвращает false вместо публикуемого partial route.

## Проверки и цена

Два actual внешних старта из grid audit:

| Случай | Раньше | Candidate | CPU до/после | Проверенное движение production foot branch |
|---|---|---|---|---|
| print_shop r4.990913843951179,c97.94314630350254 | false, expanded1 | true, expanded103, visited141 | 1.95 → 16.07 мс суммарно | 35.588 м / 450 кадров .05 s |
| hospital r6.469984627970292,c165.137 | false, expanded1 | true, expanded17, visited28 | .96 → 7.64 мс суммарно | 15.088 м / 190 кадров .05 s |

В тесте специально урезан slice до 1 мс для проверки continuation: 15 и 6 срезов, max1.23 и1.52мс из-за атомарных collision checks. Production budget остаётся 4мс. Это не ускорение прежнего false-ответа: платится ограниченная дополнительная работа, чтобы NPC смог реально пройти.

Полные пути до точной двери сохранены в `outputs/npc_adaptive_grid_candidate18.json`. Все сегменты и реальные footsteps проходят тот же production body+sweep. Max physical step .082м, final approach .268м соответствует stopping radius .08source. IDs и HP не менялись.

PASS: bounded blocked wall, water, near-goal wall fine cases; pause/resume без restart; изменение pass/resolver/origin/goal сбрасывает frontier ровно один раз и выдаёт новый endpoint. Прямой быстрый probe сохранён.

## Публикация и границы

После разрешения root candidateSource переносится в `assets/maps/city_rebuild_v1/npc_native_directed_route_source.js` и запускаются existing direct / native shop / queue tests. Тест adaptive автоматически использует actual served module после появления fine gate и отключает только fine gate для before-сравнения.

Нет GPU/LIVE/FPS приёмки. Это исправляет изолированный coarse start, не все случаи недоступных широким NPC проходов и не каждый coarse route bottleneck дальше по маршруту. Обычную прогулку независимо проверяет `wander_throughput18`; файлы не пересекаются.
