# Нико — цель пересекает препятствие, 23 сентября2026

CANDIDATE / CPU TESTED. В world/Walk НЕ внедрено, runtime freeze до общего SHA.

## Actual причина

Штатный export22:29:59.531Z, unique_niko r31.94320576484316/c148.89717564650158,
patrol target25.647106432580646/148.93801954695365, failed backoff~2.67сек.
Pending запроса в snapshot уже нет: испытана его фактическая текущая цель с
параметрами очередного patrol request из actual branch (.8/42000).

Проверен именно GLB/entry `REBUILD-VISUAL-glass_pavilion_small_v1-002`, а не
обобщённый AABB. Центр и5body probes свободны. Полный stationary footprint
(штатный swept square radius.18,from==to) blocked=true. Поэтому `_nearestEmpireWalkPoint`
принимает цель, в которую действующий physical swept planner не может войти.
Actual directed planner EMPTY; reverse goal micro-exit тоже1visited/FAILED.
Коллизии нельзя снимать ради доступа к этой точке.

## Изолированный candidate

`npc_empire_target_footprint23_candidate.mjs` строит вариант существующей
`_nearestEmpireWalkPoint`: после прежней5point проверки проверяет полный
stationary footprint через тот же native resolver. Legacy/unsupported sweep
сохраняют старое поведение. Вода/территории/динамические point checks сохранены.
Нет изменений в общем path passability, коллизиях, budgets или A*.

Добавленная проверка первоначально стоила слишком дорого на отвергнутой цели:
original .034/.064ms → candidate .807/1.079ms p50/p95. Оптимизирован только
этот новый candidate: probes внутри кольца идут по расстоянию, дальнейшие
кольца прекращаются по доказанной нижней границе radius-.5. Не меняются12колец,
набор координат и выбор ближайшей точки; ties сохраняют порядок r/c.
300deterministic parity cases со старым порядком полного footprint PASS.

После этого actual target selection p50/p95 .039/.067→.119/.155ms.
Здесь original возвращает непроходимую точку, candidate делает проверенный
поиск замены. Это isolated helper cost (100 измерений, alternating AB,
сброс frame cache), не full-scene FPS и не сравнение всех19боссов.

Дополнительная actual GLB матрица169точек вокруг исходной цели: старый выбор
вернул21точку с пересечением полного footprint; candidate заменил ровно эти21,
остальные148сохранил, пропавших целей0. Ordered/brute nearest parity169/169.
Candidate matrix helper p50/p95 .064/.217ms. После этого прогрева отдельный
100sample AB на исходной Nico цели дал .036/.051→.094/.133ms. Это разные
CPU выборки, не противоречащие прежним sample и не заявленный FPS выигрыш.

## Actual маршрут

Candidate выбирает26.5/148.5 (около3.93м от старой точки). Point/body/fullfootprint
свободны. Actual planner15expanded/27visited READY, путь43.804м; actual
`_npcAdvanceRoute` приходит к26.5/148.5 за9.571симулированнойсекунды, все сегменты
проходимы, maxstep.168571cells,телепорта нет. A* CPU после прогрева~8.73ms
за2slices; это неподвижный CPU сценарий, не наблюдение NPC в игре.

Существующая цель `_empireTarget`, уже закешированная у живого NPC, сама от
candidate не изменится до штатного перевыбора/инициализации. При интеграции
проверять обычный reload и следующий новый target; не выдавать одну подменённую
цель теста за готовый recovery всех текущих NPC. Другие цели за закрытой дверью
могут быть физически свободны внутри: этот guard не обещает их достижимости.

## Проверки/файлы

- `test_empire_target_footprint23.mjs`: controlled source contract +300parity.
- `test_empire_live_route_replay23.mjs`: actual GLB, native planner и foot loop.
- `npc_empire_target_footprint23_candidate.mjs`: изолированный код, runtime не импортирует.
- outputs/empire_target_footprint23_candidate.json
- outputs/empire_live_route_replay23_goal_probe.json
- outputs/empire_live_route_replay23_solid_goal_candidate.json
- `assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json`:
  scalar выбраные empire actors+residents205–207 из реального экспорта.

```text
node test_empire_target_footprint23.mjs
node test_empire_live_route_replay23.mjs assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json unique_niko --current-target --reverse-goal-probe
node test_empire_live_route_replay23.mjs assets/maps/city_rebuild_v1/test_fixtures/empire_route_capture23.json unique_niko --current-target --solid-goal-candidate --walk-result --target-cost
```

Остальные здания в тесте остаются static snapshot, runtime cars/railway/GPU
отсутствуют. Производительность общей сцены не проверена. Не внедрять до
снятия координатором текущего runtime freeze и scoped review.
