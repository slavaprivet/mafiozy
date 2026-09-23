# NPC walk → board continuity — 23 сентября 2026

Статус: READY CPU, applied в shared tree; LIVE общей сцены ожидает координатора20.

## Причина и изменение

На текущем test_npc_vehicle_transition_continuity female first-board прыжок стопы был 0.123546 м (limit 0.1). Тот же текущий тест с подстановкой только locomotion e33212e: 0.048945 м, PASS. Новая походка изменила последний показанный шаг; vehiclePose(fold=0) мгновенно восстанавливал нейтральную стойку.

В npc_locomotion_pose добавлена ленивая запись последней показанной позы только при walk → board с progress ≤ .2. Она смешивается с существующей позой посадки за .22 с времени анимации. Два вызова в npc_actor: перед сбросом походки и сразу после применения vehicle binding. Корень NPC/скорость/маршрут/авторитет транспорта не меняются. Fire/readiness sections не правились. При смене машины/сиденья, потере binding, полной посадке или недопустимой позе буфер сбрасывается. Ранняя отмена через exit может закончить тот же краткий переход. В обычной ходьбе буфер не создаётся.

## Проверки

- Оригинальный actual transition тест: PASS, исходный предел 0.1 м сохранён. Male/female first-board max < 8e-8 м, вся последовательность 0.0871/0.0921 м. Отмена 0.0765/0.0794 м, восстановление exit после cull 0 difference.
- Новый test_npc_walk_board_entry23: 64 случая, 2 пола × 2 передние двери × 8 прогретых фаз шага × normal/early-cancel. Первый кадр < 8e-8 м; максимальный шаг кости за 50 мс 0.099734 м при limit 0.1. Корень сохранён, остатка перехода в drive нет.
- Existing actual footplant/no-stretch/root/profession/zero warmed THREE allocations, 16 upright gait modes, vehicle death continuity, population: PASS. Syntax/scoped diff check PASS.

## Цена и пределы

Serial actual rigs, 60 warm + 200 measured входов/пол: добавленный one-time capture p50/p95 male .0078/.0145 мс, female .0085/.0266 мс. Active blend .0099/.0151 и .0087/.0192 мс. Два неактивных вызова .0002/.0002 мс. Baseline helper отсутствует (incremental 0). Это CPU microbenchmark, **производительность общей сцены не проверена**. Замер и визуальная приёмка через координатора20.

Буфер короткого перехода локален renderer actor и не сериализуется. Уже существующая проверка cull/return относится к progress .4 exit, после завершения нового короткого blend; cull в первые .22 с не проверен на идентичность уходящей позы. Root/source остаются корректными. Не объявлять это полной приёмкой всех транспортных сценариев.

Отчёты: outputs/npc_vehicle_transition_board23_test.json, outputs/npc_walk_board_entry23.json, outputs/npc_walk_board_entry23_cost.json.


## FINAL floor follow-up — supersedes initial cost/grounding limits

Дополнительный actual skin scan выявил новый минус1.843см в промежуточном кадре
female/front_right; без blend исходный vehicle pose имел минимум минус3.294мм.
Root разрешил узкое исправление outgoing blend, без иных sections.

Только `npc_locomotion_pose.mjs`: в активных кадрах после первого добавлен подъём
visualPivot по полу, никогда не понижает уже поднятую посадкой позу. Root и X/Z
не меняются; первый кадр сохраняет точное наследование походки. Полный groundPose
был проверен и заменён более дешёвым точным расчётом: кеш групп влияния костей с
консервативными box bounds пропускает только доказанно верхние вершины; все
потенциально касающиеся пола вершины проходят исходное applyBoneTransform.
Замена position/skin attributes или их version инвалидирует кеш; неподдерживаемые
skin данные используют полный groundPose. Никаких сохранённых результатов старой
позы, условной высоты подошвы или ослабления пола. Остальные пути actor не менялись.

- test_npc_entry_floor23:256 comparisons against full native groundPose, maxerror
  1.15e-16м,64 versioned geometry changes; continuity/root assertions сохраняются.
- Normal64 actual phases/doors/sex/cancel: max50msstep.098252м (<.1), first<8e-8м.
- Original transition, footplant/zero warmed THREE allocations, vehicle death,
  syntax/diff checks PASS. Floor changes don't execute in ordinary walking.
- Full skin oracle448poses/3,683,680vertices: min -.002770м только i5 после
  завершения blend. Active new penetration устранена; inherited purevehicle
  миллиметровое касание не выдаётся за абсолютный0 во всех поздних кадрах.
- Полный scan active p50/p95 male1.237/1.517мс, female1.119/1.371мс.
  Optimized warmed helper .249/.370мс и .180/.234мс; inactive gates .0002/.0003мс.
  Первый cold cache4.56/3.88мс на актор измерен отдельно, не скрыт warm цифрами.
  Это локальный CPU, **производительность общей сцены не проверена**.

Reports: `outputs/npc_entry_floor23_oracle.json`,
`outputs/npc_board_skin_floor23_readonly.json`,
`outputs/npc_board_skin_floor23_readonly_baseline.json`,
`outputs/npc_walk_board_entry23_floor_cost.json`.

Final SHA256 (npc_actor совместно правит fireowner, его whole-file hash не фиксируем):
- `assets/maps/city_rebuild_v1/npc_locomotion_pose.mjs`: `5d602c6b64f2362c8286803abbe58382783e8713c90969d38bd579d39755863d`
- `assets/maps/city_rebuild_v1/test_npc_walk_board_entry23.mjs`: `91ff14db7333bcd94676325a86fc55e68075880e09392b7ed0d97fdb0c63c533`
- `assets/maps/city_rebuild_v1/test_npc_entry_floor23.mjs`: `747dd9d0d5c574c461034ce92efcff17f8f75337bb1891f735373cd901e9b071`
