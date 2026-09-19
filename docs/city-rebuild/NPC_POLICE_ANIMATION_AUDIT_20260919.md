# NPC и полиция: визуальная реакция и остановка при стрельбе

19 сентября 2026. Scoped owner `/root/police_animation_qa`, интеграция Художник17. Новые GPU-вкладки не открывались. Производительность общей сцены не проверена.

## Исправления с воспроизведением

1. `npc_actor.mjs` проверял `life.lifeState` и отдельные flags, но пропускал `life.state:'panic'`. При устаревшем active reading видимая книга оставалась у убегающего NPC. Отдельный `life.fleeing` также не отменял legacy talking arms. Добавленный actual male/female regression сначала упал (`priority state panic`), после единого escaping predicate проходит. Телефон, книга/сигарета, скамейка и profession pose теперь используют одинаковую проверку panic/flee по state/lifeState/flags. Существующие cower/surrender/custody priorities сохранены; измеренная `motionSpeed` остаётся главным источником темпа походки.

2. `updateCityCops` намеренно удерживал полицейского на дистанции стрельбы 2.8–7 source tiles, но затем нулевая дельта попадала в obstacle fallback. Коп сдвигался на .01 tile каждый кадр и включал walking, хотя движение вообще не запрашивалось. Actual source fragment test сначала упал (`−.01 !== 0`), затем прошёл: fallback выполняется только после запрошенного и не отложенного движителем перемещения. Сохранены приближение, поиск последней позиции, отход и swept fallback при настоящем препятствии. Удержание позиции больше не тратит collision queries. Это не изменение дистанций боя/HP/wanted/скорости.

## Новая анимация полицейского осмотра

`_threeNpcPoliceObservation(entity, now)` получает original cop через `_actionRef`, передаёт `{since,until}` только для живого прибывшего patrol с действующим `_civilianSuspicion`. Поездка, движение, pursuit и `_casePhase` исключаются. Deadline ограничен прежними 5.5 секунды; подход к месту происшествия не считается осмотром. Snapshot имеет `policeObservation:null` во всех остальных случаях.

`npc_police_observation_pose.mjs` плавно добавляет повороты головы/шеи при осмотре. Сам источник уже управляет общей ориентацией полицейского. Новый overlay не меняет root, руки/оружие, маршрут, обзор, HP или ID. Срабатывает и при штатном оружии в руках, но прекращается при действии/выстреле, попадании, смерти/падении, прыжке, поездке, движении и panic/phone/custody gesture. Нет новых props/геометрии/материалов/particles. Lazy instance содержит только пять переиспользуемых THREE scratch objects; прогретый apply не создаёт THREE объектов. Hero rig не изменён.

## Проверки

- `node test_police_pursuit_hold.mjs`: actual movement fragment, stationary fire lane, deferred route wait, approach/search/retreat, swept obstacle fallback.
- `node assets/maps/city_rebuild_v1/test_npc_police_observation_pose.mjs`: actual source helper, canonical ref, no approach/expired/dead/busy receipt; реальные male/female GLB, head scan, неизменные кисти и root, приоритеты других действий; 0 warmed THREE construction. Отчёт `outputs/npc_police_observation_20260919.json`.
- `node assets/maps/city_rebuild_v1/test_npc_social_pose.mjs`: обе модели, рост 1.65/2.05, книга/курение/разговор, реальные seat/foot anchors, death/phone/weapon/escape interruptions и новые aliases. Overlay active p50 .0534–.058 ms, p95 .0551–.0773 ms, 0 новых THREE объектов после прогрева.
- `node --import ./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs assets/maps/city_rebuild_v1/test_npc_activity_pose.mjs`: обе модели, крайние росты, сидение/вставание/телефон, реальные подошвы не под землёй.
- PASS actual source tests `test_police_perception_discovery.mjs`, `test_npc_suspicion_dispatch.mjs`, `test_police_initial_admission.mjs`, `test_police_ground_transport.mjs`, `test_police_convoy_source.mjs`, `assets/maps/city_rebuild_v1/test_npc_civilian_weapon_policy.mjs`.

Изолированный новый observation overlay, 40 warm +100 measured: idle p50/p95 .0002–.0003/.0002–.0005 ms; active male .0059/.0187 ms, female .0012/.0014 ms. До scratch optimization первая версия использовала allocating hero rotateAdd: male .0098/.019, female .0016/.0028 ms. Разные JIT фазы ограничивают сравнение этих микросекунд; надёжное отличие — eliminated 8 THREE constructions на активный кадр. Это не FPS всей игры и не оценка затрат базового NPC walker.

## Оставшиеся реальные ограничения

- Нужна визуальная проверка осмотра/переключений в единственной игровой вкладке после общей перезагрузки. Ни новая сценовая производительность, ни сегодняшняя полной цепочка patrol→crime→cuffs→physical prison delivery не заявляются принятыми.
- Существующие CPU source контракты FOV/LOS, hearing-only inspection, last-seen pursuit, custody ownership, живой водитель/boarding и driver-death stop проходят. Они не доказывают authenticated server deployment и весь городской маршрут.
- Исторический server LOS остаётся legacy tile contract, не native GLB геометрия. Полная серверная civilian identity/vision authority ранее не была завершена; текущая задача этого не меняет.
- Density/commerce/trips принадлежат другим scoped агентам. Никакого сброса canonical IDs/ролей/маршрутов/эмпайров не сделано.
