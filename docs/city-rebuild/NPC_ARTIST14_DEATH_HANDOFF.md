# Готовая смерть Artist14 для NPC — 2026-09-10

## Что исправлено

Используется существующая `createArtist14Pose().reaction({kind:'dead',age,...})` через `createArtist14Surface`. Арт-модули и сама анимация не менялись. Lifecycle теперь обрабатывает `npc_actor.mjs`, поэтому он одинаково работает через population, отложенное создание и прямой normalized actor snapshot.

Старый corpse, впервые попавший в область видимости, сразу показывает соответствующий возраст готовой анимации по `deadAt` и часам источника. Свежая смерть с неизвестным timestamp начинает существующее падение с начала. Появление timestamp позже не запускает падение повторно. Сериализация/LOD/culling сохраняют возраст и исходный ID. Только явный alive/новое подтверждённое поколение смерти сбрасывает состояние.

При смерти базовая стойка нейтральная: forcedCrawl/prone не добавляется второй раз к падению. Остаточная плавательная поза не накладывает второе вращение; существующее затухание buoyancy сохраняется. Приоритет смерти также блокирует gestures, seat/vehicle, jump/tumble, melee/reload. Ни урон, ни HP, ни движение AI этот слой не создаёт.

## Source контракт

`npc_source_lifecycle.mjs` экспортирует `normalizeNpcLifecycle(src,{time,sourceNowMs})` → `{dead,explicitAlive,key,age,side}`. HP=0 и alive=false сами по себе не являются подтверждением смерти в renderer.

- `deathConfirmed:true` — явная летальная смерть; побеждает устаревший meleeStunned/downed в отображаемом снимке.
- `deathConfirmed:false` — legacy `dead` не интерпретируется как смерть.
- При отсутствии нового поля legacy `dead:true` остаётся совместимым, если нет meleeStunned/downed/lifeState=downed.
- `deadAt` — milliseconds из часов существующего world; `sourceNowMs` должен использовать те же часы, а не epoch и не независимый renderer clock.
- `dead:false` без nonfatal флагов — явное возрождение, в отличие от пропущенного поля/невидимости.

Координатор изменил `_threeNpcDeathState` и оба consumers в `world.html`: main dynamic snapshot и interior snapshot. Source сохраняет legacy `dead`, добавляя отдельный `deathConfirmed`, не принимает null/empty HP за ноль, передаёт medical/empire downed. Эти world изменения сделал координатор, данный scoped patch их не редактировал.

`npc_population` сохраняет смещение явно переданных часов source между sync и deferred creation/update. Без этого actor, созданный на следующем кадре из старого corpse snapshot, ошибочно получал возраст 0 при разных часах.

## Проверки

`node assets/maps/city_rebuild_v1/test_npc_death_all.mjs` — PASS:

- Реальный `_threeNpcDeathState` извлечён из актуального world и исполнен в VM: 24 семейства, 9 пограничных lifecycle случаев, стабильные death timestamps, null/empty HP.
- 71 запись существующих каталогов проходит normalization с сохранённым ID.
- 26 ролей на настоящих male/female GLB показывают готовую смерть с первого корректного кадра; проверяются neutral base, старый corpse, новое падение, hydration timestamp, cache eviction/reentry, respawn, deferred creation.
- Сохраняются nonfatal stun, medical downed и custody. Для обоих полов проверен приоритет смерти над остаточной swim-позой.

Существующие `test_npc_population` (19 проверок), `test_npc_actor`, `test_npc_lifecycle`, `test_npc_surface_state`, `test_npc_lod`, `test_npc_motion_speed` — PASS. Их CDN-загрузка SkeletonUtils в sandbox получила EACCES, поэтому использован test-only offline bootstrap:

`node --import ./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs assets/maps/city_rebuild_v1/test_npc_population.mjs`

Bootstrap делает hierarchy/skeleton remap для клона только в тестах; production продолжает получать SkeletonUtils от host. Никакой production network/dependency путь не менялся.

Живой прогон основного мира и фактических NPC остаётся у координатора. Каталог/VM/GLB проверки не являются объявлением завершённой миграции всех игровых механик.
