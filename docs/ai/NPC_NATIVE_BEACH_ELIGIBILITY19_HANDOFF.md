# Walk: старый флаг пляжного жителя блокировал новую сушу

21 сентября 2026, узкая правка NPC navigation. GPU и Git не использовались.

## Причина и результат

В сохранённом LIVE-срезе `outputs/npc19_live_pending_walk_20260920.json`
`resident_12` стоял в `(r=161.5, c=94.88630498861984)`, `_beach=true`.
Текущая физическая карта определяет эту точку как свободную сухую `land`, а
старый MAP содержит тротуар `8`. `npcWaypointOk` раньше возвращал false по
условию пляжного жителя (`MAP===14`) до проверки поверхности Walk.

В `world.html` только порядок двух условий `npcWaypointOk` изменён: реальная
native land/road проверяется перед legacy beach/sand разрешениями. Поэтому
житель может пройти по новой суше и продолжить обычный маршрут. `_beach`
не удаляется; цели, ID и координаты не переписываются.

Перед разрешением суши остаются границы карты, тюрьма, арена, логово,
`_npcRouteWalkBlocked` (вода/геометрия), unique/said authority и pit corridor.
Road не разрешается как место прогулки. Без native resolver поведение
старого World полностью прежнее. Движение остаётся через существующие
body-clearance, edge sweep и ограничения скорости. Телепортации нет.

## Проверка

`node test_npc_native_beach_eligibility19.mjs`:

- actual static collision snapshot + native land/water + actual building/car
  geometry; старое условие воспроизведено из текущей функции перестановкой;
- до изменения исходная точка отвергается;
- после изменения actual source planner нашёл 21 узел за 3 кадра fixture;
- actual movement прошёл 3.068 клетки, каждый шаг ограничен speed/7,
  каждое ребро проверено прежней физической проходимостью;
- legacy sand rules и все запретные зоны/road/blocked/unique negatives PASS.

Изменение не увеличивает cohort 8, CPU budget 4 ms или maxVisited 520.
Добавляется проверка native surface для пляжных кандидатов, которые раньше
ошибочно отбрасывались до неё; физически возможные поиски выполняются в
существующем общем бюджете. Сравнение FPS и производительность общей сцены
не проверены; single-actor fixture не имитирует 289 живых NPC.

## Счётчики маршрутов

При начале этой задачи CPU-счётчики уже были на диске, их повторно не меняли:
`_routeWorkCpuMs`, `_routeWorkLastCpuMs`, `_routeWorkQuanta`,
`_routeWorkLastWaitMs`; экспорт `npcRouteReplay` в существующем QA 1 Hz gate.
Новый `test_npc_route_owner_cpu19.mjs` проверяет отдельную атрибуцию владельцу,
прошедший/последний CPU quantum, ожидание отдельно от CPU, denial, double
finish, unfinished caller и отсутствие native acquisition в legacy.
`test_npc_route_replay_diagnostics19.mjs` дополнен проверкой этих полей.
Счётчики — накопленные scalar поля, только DOM-экспорт ограничен QA.

Также PASS: route_cpu_budget18, route_batch19, route_work_budget.

## Что не решено

Общая LIVE очередь 198–211 pending при 7 FPS не воспроизведена и не объявляется
исправленной. Uniform replay расходится с LIVE. Candidate cohort 32 не
применён. Нужен новый полный replay с owner CPU/wait/quanta, затем отдельная
проверка реальных ожидающих жителей. `resident_140` с thin pole — отдельный
случай, не затронут этой правкой. RPG/C4/смерти/транспорт не менялись.
