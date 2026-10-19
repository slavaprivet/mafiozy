# Wait perf56 — неподвижные ожидающие жители

Применение: `apply56.py <candidate>` либо `apply_to(project)` под scheduler
write lease владельца. Десять точных hunks в `PATCH56.json`: только
`npc_city_daily.gd`, `hospital/npc_simple_hospital.gd` и новый
`city/runtime/npc_wait_cohort56.gd`. Attention/visual/health/stalls56 файлы
не перезаписываются. Frozen release55 запрещён в apply. Default enabled;
`--city-wait-cohort56=0` возвращает полную частоту для A/B сравнения.

## Что пропускается

После полноценного Life/Simple такта helper запоминает только реально
неподвижного grounded жителя с актуальным zero-motion sample. Находящиеся
ближе25м к игроку **или активной камере** не попадают в cohort. Это важно для
камеры в машине/свободной камеры. Все287 жителей остаются в scene и daily;
нет удаления моделей, снижения числа жителей или масштабирования movement delta.

Поддерживаются Simple planning states searching/searching_guide/waiting_obstacle
и неподвижные capacity/inbound portal/service ожидания. Перемещающийся retreat,
готовый local path и любая обычная ходьба получают каждый physics tick. Hospital,
активные threat/attention/ambient и legacy visit проходят полный Life всегда.

Между полными тактами выполняются:

- точная проверка прежнего life/body/generation/health и нового HP revision;
- `should_pause_walk`, lowHP, impulse, смещение тела, движущаяся платформа;
- актуальное состояние маршрута/заявки, готовность движения;
- **настоящий support ray каждый пропущенный physics tick**. При исчезновении,
  отключении или существенном перемещении опоры выполняется обычный Life/hold
  в этом же такте. Gravity не интегрируется задним числом и movement dt не растёт;
- свежий zero-motion sample для существующего sole visual owner.

Максимум6 ticks между полными вызовами, плюс wall deadline100мс. При уже
зависшем движке нельзя обещать100мс абсолютной реакции без доступного physics
tick: по истечении deadline следующий доступный tick всегда полный. После
реального hit/угрозы/смены поколения/coordinator wake дополнительной cohort
задержки нет. State bound384, weak refs, explicit forget/dispose/scene cleanup.

## Planner и время

Существующий `Budget.pump` запускается перед физическим проходом ровно один
раз/frame благодаря его собственному dedupe. Пределы1800µs,128 units,384 jobs,
65536 nodes и131072 heap items сохранены; дополнительных budgets нет.
Готовый физический route будит actor сразу. Native topology queue продолжает
свои прежние admission/tick механизмы; проверка guide может задержаться не более
cohort deadline. Job stale threshold120frames выше6frames polling, cleanup
остаётся прежним.

`Simple.wait_clock56(delta)` добавляет пропущенное время только к planning
watchdog/replan clock. `_service_watch30.local_wait_ms` получает каждый skipped dt,
не motion idle. Полный `life._dsh_elapsed` обновляется прежним `_life_clock30`
после реального времени между опросами. `life._now` приходит из health clock при
полном шаге. Dwell/лечение не когортируются; ни один платёж или heal receipt
не может происходить в cheap path.

## Native проверка

`runs/candidate02` и `runs/baseline01` — один final harness и одинаковые scripts,
baseline использует только явный OFF flag. Оба PASS16/16, scheduler exit0,
stderr0, source/harness drift0. На120 ticks и287 реальных capsules:

| Измерение | OFF | ON |
|---|---:|---:|
| Полные life calls |34372|7386|
| Пропущенные stationary wait calls |0|26986|
| Пройдено движущимся actor |3.599857м|3.599857м|
| Вызовы движущегося actor |120/120|120/120|
| Вызовы близкого actor |120/120|120/120|
| Максимум между полными вызовами |1tick|6ticks|

ON skipped gap максимум5ticks/94мс. Настоящий удалённый native floor вызвал
падение в том же tick. Изменение health revision, threat port, generation и
приближение активной camera вызвали полный шаг в том же tick. Planning timer
сохранил2с, planner budgets не изменены. После cancel/clear jobs0 и states0.

Native physics движется настоящим production Simple/Physical драйвером. Fixture
использует контролируемые Life/Health/Threat ports, чтобы отделить gate от
большого города; это не настоящая пуля/магазин/модель жителя. Mean dispatcher
15.93→12.63мс на этом стенде измерен в functional lane, не exclusive perf, и
**не является городской FPS приёмкой**. Дорогой production brain в этом
стенде заменён портом; root измеряет итог на полной coherent scene287.

`candidate01` сохранён как FAIL: setup и первый dispatch произошли в одном
physics frame, поэтому harness ошибочно требовал120 новых вызовов вместо119.
Исправлен только момент начала измерения; production source не изменился.

Следующая проверка root: полноценный город287 с48–52мс исходного daily,
реальные completed walk/shop/restaurant/bank/hospital и native12HP injury,
наблюдение возраста planning jobs/готовых путей и реального движения каждого
actor. Не объявлять устранёнными утечку или все причины3FPS до измерения.
