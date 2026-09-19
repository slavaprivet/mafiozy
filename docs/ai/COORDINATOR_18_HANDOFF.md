# Координатор 18 — прямая передача 19 сентября 2026

Пользователь прямо поручил Координатору17 передать задачи Координатору18, создать новую задачу и продолжить там. Новая задача **01a0bb23-8430-7262-b885-97bb496a2406**, fork same-directory; исходная **01a097a0-5d69-7660-9aa0-7845289a887e**. Рабочий каталог общий `C:\Users\Слава\Desktop\Мафиози`. Никаких broad git add/reset/commit: сотни общих изменений других авторов. Координатор17 прекращает новые production edits после этой передачи; два его субагента завершают уже оговорённые узкие правки (ниже).

## Последнее прямое поручение пользователя

«важно чтоб объект выделялся красным когда выделен зелёным когда идёт работа и не выделен когда работа сделана по нему. проверь чтоб выделение было без резких углов потому что щас не красиво выделяется объект. может улучши по другому выдели как-нибудь».

Приоритет: рабочие специалисты без застреваний, таймеры над их целями, удобное наведение и эстетичный мягкий контур. Красная заливка уже отвергнута. Последний белый inverted-hull машины также отвергнут (стёкла залиты, детали шумят): **весь кузов не подсвечивать**, оставить действие X и отдельную белую дверь только <=1.3м для посадки. NPC и собственная банда — только нижнее кольцо, никаких красных тел; над своими рамочка имя/профессия/МОЯ БАНДА. Сделанный объект не должен выделяться даже при наведении.

Также открыты: подрывник не взрывает авто; X «Устранить» слишком короткая дальность; при огне банды не видно стрелка/отдачи, трассеры из непонятного места; очистить экран от QA кнопок, сохранив карту/оружие/отряд/таймеры/игровые подсказки. Max Payne чрезмерная дальность — исходный fix готов, ещё не загружен.

## Одна живая игра, не открывать вторую GPU-вкладку

URL `http://127.0.0.1:18538/world.html?direct=1&previewcity=1&render=3d&renderer=walk&weapon=pistol&cash=5000&npccombatqa=1&npctransportqa=1&perfqa=1&vehicleshadowcull=1&mercenaryqa=1`.
У17 была IAB browser1/tab2, но18 должен получить свой актуальный inventory/handle; не закрывать пользовательскую игру. Передача UI ещё не перезагружает её. Разрешение на LIVE/перезагрузку дано раньше, пользователь параллельно играет; не приписывать все действия своим инструментам. CUA evaluate только readonly DOM, не мутировать игровые globals. Реальные кнопки QA позволяют подготовить площадку, осмотреть конкретный объект, подготовить раненого. На новом чистом HUD будут за кнопкой **Проверка**.

В DOM `document.body.dataset.mercenaryShowcase` JSON1Гц содержит layout/safe/vehicles/members/actions/targets. В actions: id/action/position/**movement**/posture/target. movement: reason, search{expanded,checks,slices}, pathLength/pathIndex,goal/routeGoal,lastAction{kind,targetId,phase,reason,at}. Диагностика исходная, не сама по себе FPS proof.

## Что LIVE подтверждено и что нет

Текущая сессия **QA-MERCENARY-1789845186707**: пользователь реально открыл сейф и поднял мешок. DOM safe opened=true,collected=true,locked=false,lootDropped=true,revision2. cut_fence completed и cage.cut=true; power.powered=false; medic revive completed и bruiser hp35/active. Бейджи МОЯ БАНДА восстановлены. Это актуальное подтверждение, старый handoff ошибочно ещё называет сейф неподтверждённым.

**Авто НЕ взорвано**: hp240/wreckedfalse; plant_bomb отменялось reason=path_timeout. Root повторил команду и подтвердил approach/search_pending, эффекта пока нет. Причина найдена: реальная половина ширины demoCar1.28м, а picker терял profile и брал1м. Подход1.84м попадал в body+NPC radius1.28+.738=2.018м. Root исправил сохранение profile и чтение halfwidth; теперь подход2.12м, тест реального clearance PASS. **Этот fix ещё НЕ перезагружен.**

Сейф вскрыт, но специалист после него зажат раскрытой дверью: safe root155.7597,0,173.4047,yawPI; actor merc_resident_138 в155.80387,0,172.00738; returngoal162.7597,0,169.4047; no_route expanded1/checks4. Оператор стоит local(0,0,1.34), дверь -112deg на hinge(-.369,0,.352). Нужно проверить swept body .738м и выбрать безопасный рабочий anchor сбоку от хода створки/отход до раскрытия. **Root НЕ менял anchor**, идея localx+.65 ещё не проверена. Коллизии не ослаблять, не телепортировать.

Текущий squad: merc_resident_33 engineer Елена Конти;187 medic София Моретти;95 bruiser София Манчини;192 demolitions Пьетро Фонтана;138 safecracker Энцо Романо. QA раненый — настоящий95, Prepare ранит его на600сек, identity/equipment сохраняются. Другие тестовые NPC не нанимать вместо профессий.

## Изменения на диске после последней reload — обязателен общий reload и LIVE

Все пути ниже `assets/maps/city_rebuild_v1/`:

- `walk_debug_panels.mjs` новый; подключён в walk_preview. Точные QA панели спрятаны по умолчанию за компактной кнопкой Проверка; URL flags и диагностические update не удалены. `world.html` существующему convoy panel добавлен id npc-transport-qa. Smoke toggle/dispose PASS; docs/ai/CLEAN_GAME_HUD_20260919.md.
- `hero_jump.mjs` только dive speed10.5→6м/с:8.4→4.8м. Обычный прыжок2.8м/высота/позы/оружие/коллизии сохранены. Real keyboard/frame tests5/10/30/60FPS/повторы/столкновения PASS. Общий frame dt≤.04 по-прежнему растягивает время при5FPS, не исправлен. docs/ai/MAX_PAYNE_DISTANCE_20260919_HANDOFF.md.
- `mercenary_selection_view.mjs`: whole-vehicle hull полностью отключён, invalid/completed/opened не отображаются. 12testsPASS. Inverted hull других объектов ещё резкий, новое эстетическое поручение требует доработки18. Не заявлять этот визуал окончательно принятым. NPC onlyring.
- `mercenary_walk.mjs` root: завершённые safe/cut/power не передаются в selection; working green для фаз working/awaiting/retreat/countdown илиarmed. Пока только текущая наведённая цель зелёная, если нужно сохранять рабочую подсветку при отведении камеры — сделать осознанно с бюджетом. Aim теперь120мс по wallclock OR накопленному dt вместо .25 поclamped dt (на5FPS раньше до1.25с задержки). Source bindTargets включает hasLineOfSight(from,to,id).
- `mercenary_targets.mjs` root: register сохраняет profile car/actor; actual halfwidth с objectscale дляcar approach/contact. Compactprop band .6..1.2м с angularpadding; добавлен NPC near-miss band .25..1.2 с настоящим LOS доцентра; no-wall-picking сохранён. Новый hasLineOfSight(fromFoot,toFoot,targetId) поднимает eye1.15/1.05м. Root тест targets PASS; test_mercenary_walk PASS после замены старой assertion wholecarhighlight на его отсутствие. Новые NPCassist/LOS cases ещё расширить при необходимости, не делать бесцельных broad suites.
- `mercenary_world.js` agent: Устранить назначается≤60м с host LOS; еслидалеко, route ведёт до старой fire range≈41м, сама стрельба не расширена. Focus+route15PASS, selected116PASS.
- Предыдущий загруженный пакет уже содержит core HP-loss cancel, C/Z squadposture, pendingroute fix, штатные таймеры и бомбы. Смерть/ранение до окончания работы отменяет эффект и награду. Уже заложенная бомба самостоятельна с safe retreat. C/Z и повреждение во время работы пока не пройдены LIVE.

## Два работающих субагента17 — не создавать дубли

1. `/root/mercenary_actions19` сейчас делает **только crew lowFPS elapsed** в mercenary_world/core/route. Подтверждён min(.05,dt): при5FPS3м/с превращаетсяв.75, длиннаязадача истекает40сек. Просьба: bounded swept substeps/realelapsed/pause reset, никакоготелепорта и общихNPCclocks. Передаст READY в18 иличерез17. До READY не редактировать эти участки. Предыдущие его114/116тесты относятся доэтойновойправки.
2. `/root/mercenary_visuals19` делает **NPC shot FX+recoil provenance**, новый ограниченный модуль и scoped walk_preview/world gangshot. Причина: gangfire только _shotAt без _shotSeq; recoil160мс отsource timestamp пропадает накадрах200мс; legacy _npcMuzzleWorldPoint использует ISO w2s/s2w вместо реального3Dmuzzle; gang spawnBullet безshooterId. Вwalk отсутствует отдельный потребительNPCprojectileFX. Требование: показ из resolveWeaponShotTransforms(actualNPCweapon), boundedtracers/flash безPointLight, sequence-latchedshot, не воспроизводитьстарыйsnapshot, не добавлятьурон/второйвыстрел. Художник18 РАЗРЕШИЛузкийlatchв npc_population.mjs; сохранитьmotionanchors/yaw/gait, не правитьnpc_actor/hero_walk. Егоtool можетнеуметьписатьв18:17перешлётготовность. ДоREADY не делатьдубликат.

## Другие владельцы и пакеты

- Новый **Художник18** `01a0bb21-19d8-7640-9946-ad095a16d52c` наследовал17, тотproductionбольшенеправит. docs/ai/ARTIST18_HANDOFF.md. Пользовательговоритгородстоит — ещёнепринят.
- Старый первый NPCpatch (wanderFIFO/corners/trafficwatchdog) уже LIVE. После41сек было289alive/39moving/1driving/pending257, console0. Этораннийснимок, неуспехвсегогорода.
- Второй **npc_civilian_elapsed_source.js + scoped worldhooks READY**, только спокойнаяходьбаordinaryresidents, общийdt/hero/combat/vehicleнеизменены. ЕщёНЕ LIVE. Художник18 просит прогретый snapshot90–120секпослеобщейreload. См.NPC_CIVILIAN_ELAPSED_PROPOSAL_20260919.md.
- Roadowner «Автомобили — продолжение архитектора» `01a087f0-fda6-7e13-8baa-1bbd1c5cc26e`: city_parking_origin/city_road_navigation/city_lane_route_worker READY.59/59выездов,20/20конфликтовзанятыхсоседнихместисправлены; workerparity/lifecyclePASS. ЕщёнеLIVE. docs/city-rebuild/PARKING_ORIGIN_MANOEUVRES_HANDOFF_20260919.md. Братьвтужеreload.
- «Проверщик ЧАТОВ» `01a0b15c-1b67-7711-a726-7298ca2e63a7` — менеджер5Астрачатов, работаавтоматизирована. Сообщить новыйIDкоординатора, проситьтолькофактыиосновныепроверенныерезультаты. Не спамитьчаты,200сообщений/неделя; актуальностькобщемуmain/dirtyHEADпроверять. ПредыдущаясхемавCOORDINATOR_17_MEMORY.md, tools/ai_pipeline. Старыеобычныечатысамостоятельнокоднеприменяют.

## READY — mercenary_actions19: время движения отряда

**READY, 119/119 тестов PASS.** Подзадача `/root/mercenary_actions19` завершена; новых задач не начинает. Полная передача: `docs/ai/MERCENARY_ELAPSED_20260919_HANDOFF.md`.

- В `mercenary_world.js` исправлено только source-owned движение наёмников: реальное monotonic elapsed → максимум 6 проверенных подшагов по 0.05 с, не больше 0.3 с на кадр. Пауза >0.75 с / скрытый document не воспроизводит накопленное перемещение; visibility сбрасывает sample, `host.resetMovementClock()` доступен владельцу явной паузы. Коллизии, таймеры core, обычные NPC и legacy combat loop не переписаны.
- Измеренный старый результат при 5 FPS — 0.75 м за секунду. Теперь 5/10/30/60 FPS дают ровно 3 м/с стоя, 1.5 присев, 0.65 лёжа. Реальный source body radius 0.18×4.1 проверен.
- Один и тот же маршрут вокруг автомобиля с установкой/отходом/взрывом прошёл при всех четырёх FPS: начало работы 8.2/6.2/5.07/4.78 с, взрыв 18.2/16.2/15.13/14.82 с. Взрыв ровно один, оператор минимум в 8 м. Это actual-source CPU fixture, **не LIVE приёмка**.
- Новые тесты `test_mercenary_elapsed.mjs` 3/3 PASS; общий набор elapsed/route/rally/world/actions/focus/lifecycle 119/119 PASS. QA `getMember(id).movement.clock` показывает elapsed/used/dropped/paused/substeps.
- Дальняя команда source60м+LOS и подход до прежней зоны огня уже в пакете. Car half-width fix находится в root targets и готов к совместной загрузке. Сейф вскрыт пользователем; зажим открытой створкой после работы остаётся отдельной геометрической задачей18.

Первый из ожидаемых двух READY получен. Второй — стрелковые FX/визуальный пакет соседнего исполнителя; не подменять его готовность этим сообщением.

## Проверка после передачи

Прочитать COORDINATOR_17_MEMORY, MERCENARY_PROFESSION_LIVE_20260919 (с поправками выше), MERCENARY_CREW_ROUTES_20260919, ARTIST18_HANDOFF и действующийAGENTS. СобратьдваREADY17; ограниченнаясверкаизменений; общаяreloadединственнойигры. ПроверитьчистыйHUD, открытьПроверка→подготовкаплощадки, carX approach→4секработа→безопасныйотход→видимыйfuse→hp0, safeopeningиотход, medicheal,C/Z,hitcancel. ЗатемNPCX60м: реальныйфокус, понятныйстрелок/оружие/эффекты, stopdead+ordinarycombatpreserved. ПроверитьконтурыRED→GREEN→NONE, углынемилыепеределать. Сохранитьигровуювкладку. FullsceneFPS beforeafter не измерен, никакихпретензийнасравнимуюприёмку. Неоткладыватьправдуобограничениях.

## READY от mercenary_visuals19 — NPC shot FX, 19 сентября

Готова bounded presentation-связка gang source receipt → NPC recoil latch → реальные 3D muzzle/tracer/flash. Подробности и точные проверки: [MERCENARY_NPC_SHOT_FX_20260919.md](MERCENARY_NPC_SHOT_FX_20260919.md). FX 7/7, source combat 13/13, существующая population 22 проверки PASS; walk syntax PASS. Scope npc_population согласован Художником18; npc_actor/hero_walk не менялись. Файлы свободны. LIVE/GPU общей сцены не проверены; ничего не перезагружал. Whole-car outline отключён, completed/opened/invalid подсветка удаляется, selection 12/12 PASS. Смягчение контура — отдельная новая доработка.
