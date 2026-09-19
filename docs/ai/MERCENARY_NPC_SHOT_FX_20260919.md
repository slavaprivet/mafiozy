# READY — визуал выстрелов наёмников, 19 сентября 2026

Автор: подагент Coordinator17 `mercenary_visuals19`. Передано Coordinator18. Браузер и единственная игровая вкладка не использовались. Код готов к LIVE-проверке; визуальная приёмка и производительность общей сцены **не проверены**.

## Что исправлено

- Source `_updateGang` после принятого выстрела увеличивает `_shotSeq`, записывает `_shotWeapon` и `_visualShot` с sequence, source timestamp, render ID стрелка `npc_crew_<id>`, направлением и координатами цели. Snapshot передаёт отдельную копию receipt. Решение стрелять, патроны, попадание и урон не менялись.
- Новый `npc_visual_shot.mjs`: baseline первого snapshot, проверка свежего sequence/timestamp, запрет старых событий, повторов, отката часов/sequence и чужого shooter ID. Новый выстрел возрастом до 750 мс запускает один визуальный импульс, даже когда старое окно отдачи 160 мс уже прошло. При нескольких пропущенных выстрелах показывается последнее событие, без очереди старых выстрелов.
- Новый `npc_shot_effects.mjs`: фактический muzzle из текущего `actor.weapon` через `resolveWeaponShotTransforms` **после** обновления позы. Трассер идёт к source-цели; вспышка находится у оружия. Два InstancedMesh, максимум 16 активных выстрелов (API допускает не более 32), 96 отслеживаемых стрелков, длительность трассера 120–240 мс и вспышки 70 мс. Нет PointLight, raycast, impact callback, дополнительного урона или повторного source fire. При исчезновении/скрытии стрелка эффекты убираются.
- В `npc_population.mjs` согласованный Художником18 узкий latch отдачи. Первое появление и reentry не воспроизводят старый выстрел. Сохранены motion anchors, body yaw interpolation и distance-driven gait. Во время импульса оружие наводится в направление принятого выстрела. `npc_actor.mjs` и `hero_walk.mjs` не менялись.
- В `walk_preview.mjs` минимальные hooks: импорт и lifetime FX; snapshot feed рядом с traffic sync; FX update сразу после NPC pose; dispose при pagehide. Другие scoped hooks не затронуты.

## Проверки

1. `node --test assets/maps/city_rebuild_v1/test_npc_shot_effects.mjs` — **7/7 PASS**. Baseline, 350–400 мс задержка, timestamp freeze, source rewind/sequence reset, несколько стрелков, точный transformed muzzle, immutable source/HP, bounded pool, despawn/reentry, скрытое оружие, повторные события. Последний тест создаёт реального NPC из GLB и проверяет поданный в actor recoil, body yaw и неподвижную gait-speed.
2. `node --test assets/maps/city_rebuild_v1/test_mercenary_focus_source.mjs assets/maps/city_rebuild_v1/test_mercenary_combat_collision.mjs` — **13/13 PASS** (были запущены вместе с первыми 6 FX-тестами, всего 19/19). Реальный source gang loop сохраняет количество авторитетных попаданий, focus/смерть цели, движения и препятствия.
3. `node --test assets/maps/city_rebuild_v1/test_npc_population.mjs` — **22 существующие проверки PASS**, включая реальные GLB, независимые часы iframe, yaw/interpolation, 600 мс snapshot, distance-driven gait, lifecycle и сохранение повреждений.
4. `node --check assets/maps/city_rebuild_v1/walk_preview.mjs` — PASS.

Изолированный CPU, 5 новых выстрелов за update, 100 повторов: p50 **0,028 мс**, p95 **0,080 мс**, максимум 5 активных в данном сценарии; ресурсы повторно используются. Это не FPS/замер общей сцены. GPU — до двух дополнительных draw calls только во время эффекта, источников света нет.

## Предыдущая визуальная поправка

`mercenary_selection_view.mjs`: whole-car hull полностью отключён, отдельная подсветка автомобильных дверей остаётся. Спецобъект красный, `working:true` зелёный, completed/opened/invalid или `valid:false` удаляют подсветку, включая pending build. NPC — только нижнее кольцо. **12/12 selection-тестов PASS**. Новое пожелание пользователя о более мягком контуре без острых углов ещё не реализовано; отдельная задача Coordinator18.

## Осталось Coordinator18

LIVE на единственной вкладке: X «Устранить», увидеть оружие каждого стрелка, отдачу при низком FPS, вспышку непосредственно на стволе и уходящий от него трассер; затем смерть цели и прекращение огня. Проверить отсутствие дублей со старым renderer FX в реальной конфигурации (walk сам ранее не потреблял source projectile/muzzle snapshot). Проверить source combat authority и сцену под нагрузкой. Новую вкладку для этого не создавать.
