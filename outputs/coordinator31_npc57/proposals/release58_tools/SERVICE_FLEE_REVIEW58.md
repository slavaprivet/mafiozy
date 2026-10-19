# Независимый review выбора пути побега

Reviewer: `/root/services31_resume`,15 октября2026. Read-only просмотрены два файла
`service_flee58/patch/scripts/city/runtime/npc_threat_route30.gd` и
`npc_threat_life30.gd`, diff, действующий `npc_physical_route51.gd` и final runner
`service_threat58_final/run58.py`. Изменений production при review нет.

Блокирующего нарушения коллизий или сброса бюджета не найдено. В stage58_03 root
интегрировал именно SHA `6b330fbf8374f4fb95064970a383bda0d4abb1011a3c5e4c5fd2338e64fb5968`
и `ad989e07fc03691bceca3e751f03d42496aefbc1eab5c37064eda4cc8b6d13ae`.

- Выбор ограничен10 кандидатами на попытку, по одному за физический кадр, максимум
  три прежних попытки. Направление рассчитывается от последней замеченной угрозы.
- Проверяются настоящий floor, capsule standing и sweep. Затем исходный incremental
  planner проверяет путь и опору; реальное движение, маски и ограничения стены,
  двери, игрока, NPC и обломков не подменены предварительным sweep.
- `floor_at/standing/sweep` увеличивают query counter, но сами не входят в
  `service_us29`. Поэтому отдельное `selection_us58` не дублирует их время.
  `begin/cancel` не сбрасывают накопленное время; retries не получают новый бюджет.
- Лимит200000us остаётся проверкой допуска плюс одна неделимая операция/общий pump,
  а не жёсткой верхней границей реального времени. Это ограничение прежнего механизма
  сохранено и явно описано автором.
- Preselection находится вне общего4ms route pump, хотя оплачивается из общего
  incident budget. Десять одновременных выборов ещё не измерены; FPS-выводов нет.
- `begin` сбрасывает обычный query counter. Время выбора и максимум одного выбора
  доступны отдельно, но полное число preselection queries после begin не сохранено.
  Это диагностическое ограничение, не обход лимита и не ослабление столкновений.

В сохранённой native fixture автора `budget01`12/12 проверок PASS: реальный отход
вдоль стены2.508м, скорость1.980007м/с. Selection732us, максимум211us, route2929us.
Отрицательный случай199999us route+2us selection блокирует до нового query и после
cancel/retry сохраняет200001us. Эти числа относятся к маленькой fixture, не городу.

Final runner проверяет явные manifest path+SHA, оба merged SHA, exact release57
baseline и1135 source pins; использует обычные flags и настоящий native observer.
Все non-engine controls архивируются, engine отдельно pinned; Lease, owned-child
watchdog и before/after drift guards сохранены. Overlay не используется.

Реальный исходный `shop_calibration01` с FLEE0 сохранён как отрицательное доказательство.
Два новых final merged interruption receipts нужны до freeze; overlay PASS их не
заменяет. Release validator проверяет19 именованных gates и сырые данные покупки,
выстрела, выхода, побега и повторной оплаты. Обе роли остаются PENDING до terminal.
