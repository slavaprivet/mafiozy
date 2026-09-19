# Художник19: native wander lazy DFS

20 сентября 2026. Applied в `world.html`, только native-ветка расширения
`pickNpcWaypoint`. Admission/FIFO, directed destinations, транспорт и renderer
не изменялись этим автором. Общая задача живого города этим не закрыта.

## Изменение

Прежний native DFS сначала проверял все четыре ветви каждого узла, затем шёл
в одну из них. Теперь после первого физически допустимого соседа немедленно
продолжается выбранная ветка. Оставшиеся направления хранятся на родителе;
тупик возвращает поиск к ним. Кандидат добавляется один раз, каждый переход
сохраняет проверку точек тела и непрерывный swept footprint. Между переходами
сохраняется проверка общего бюджета. `qi` считает впервые расширенные узлы,
а незавершённость native поиска определяется непустым стеком.

Сохранены minDepth8/netDistance6 клеток, maxDepth18/22, limit520, запрет
повторных точек, занятых целей, прежнего близкого назначения, water/solid/car
проверки, fallback выхода из узкой области, отмена при panic/death и 2D BFS.
Полный маршрут по-прежнему готовится до начала движения; это сокращение
лишних веток поиска, не движение по ещё не проверенному пути.

## Проверки

- `test_npc_wander_lazy19.mjs`: clear8-step route sweeps25→8, point callbacks
  1025→320; forced yield после каждого перехода даёт тот же новый маршрут;
  backtracking, тонкая swept-преграда, panic, 256 actor seeds и точное
  сохранение legacy2D результата. Направления N63/S60/E68/W65.
- `test_npc_wander_depth_first_contracts18.mjs`,
  `test_npc_wander_single_goal_contracts18.mjs`,
  `test_npc_wander_continuation.mjs`,
  `test_npc_wander_neighbor_slice18.mjs`: PASS. Старые mock-cost .25/.45
  больше не гарантировали pending после оптимизации; стоимость изменена на2
  для явного многокадрового случая. Исторический neighbor-тест реконструирует
  предыдущий eager planner, затем запускает новый actual lazy contract.
- `test_npc_wander_first_slice_starvation.mjs`: PASS (очередь другого автора).
- `test_npc_wander_grid_exit_candidate18.mjs`: actual print_shop/hospital
  узкий выход, дальнейшая обычная прогулка и занятая цель PASS; использован
  applied production без повторной подстановки candidate.
- `python check_world.py`: все семь inline scripts синтаксически PASS.

## Actual geometry CPU, не LIVE/FPS

`test_npc_wander_lazy_actual19.mjs`: 288 жителей по карте, 60 simulated seconds,
10Hz, одинаковая геометрия/очередь/скорость/проверки движения в каждом A/B.
Forward и reverse order проверены. В обоих blocked=0 и дальние маршруты
не короче8 точек/24.6м net.

| Показатель | Forward eager→lazy | Reverse eager→lazy |
|---|---|---|
| Движение в последние20сек | 73.68%→89.79% | 64.71%→82.24% |
| Pending в последние20сек | 25.30%→8.50% | 34.48%→16.36% |
| Ожидание p50 | 5.9→1.5сек | 9.5→2.7сек |
| Ожидание p95 | 21.6→16.4сек | 28.6→18.0сек |
| Суммарный planner CPU | 3149→2721мс | 3511→2906мс |
| Planner CPU/маршрут | 4.31→3.17мс | 5.77→3.72мс |
| Planner frame p95 | 6.64→6.44мс | 8.04→6.81мс |

Отчёты: `outputs/npc_wander_lazy19_10hz.json` и
`outputs/npc_wander_lazy19_10hz_reverse.json`. Реальный общий frame time не
замерен; CPU fixture не рендерит город. Timing зависит от нагрузки общей
машины. Движущихся стало больше, поэтому общий motion CPU выше. Confined
short fallback остался и встречается чаще; p95 ожидания всё ещё велик.
Нужна наблюдаемая браузерная приёмка, до неё не объявлять NPC исправленными.
