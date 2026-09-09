# NPC основной игры: источники для переноса в /walk

Дата: 2026-09-09. Read-only аудит world.html, mafiozi_bot.py, npc_empire.py, three_preview.js. Изменён только этот документ. Это инвентаризация исходников, не подтверждение живой миграции или состояния пользовательской БД. Номера строк относятся к текущему срезу и могут сместиться при параллельной работе.

## Готовая точка интеграции

**Не писать второй сборщик населения.** Уже есть `window.Mafiozi3DBridge` (world.html:67042), метод `getDynamicEntities(radius=38, preferredVehicleId='')` (67677). Возвращает `{cars,npcs,...}` (68212). Сбор NPC: 67804–67928. Рабочий потребитель — three_preview.js:217 и 5269: `bridge.getDynamicEntities(65, preferredVehicleId)` с отдельной частотой обновления dynamic snapshot. Статический город берётся через `getWorldSnapshot(radius)` (world.html:67574), а не через NPC snapshot.

`getDynamicEntities` — **смешанный снимок уже работающей основной игры**, а не серверный список всех людей города. В нём объединены серверные сущности, клиентские живые AI-коллекции, статические служебные люди и явно обозначенные fallback/preview фигуры. Нельзя объявлять весь массив серверно-авторитетным.

Радиус отсчитывается от `world.player.r/c`, не от камеры нового /walk. Ограничение `NPC_LIFE_NPC_CAP=72` (15891); категории mission/police/guard/gang/civilian; резерв до 24 гражданских и sticky IDs (67865–67903). Это ограничение видимых акторов, не всей популяции. Не удалять NPC из игрового состояния при выходе из снимка. Нельзя требовать от одного снимка присутствия всех 19 боссов по всему городу.

`_threeNpcEntityId` (66559): явный `id/uid/serverId` превращается в `npc_${id}`; иначе WeakMap создаёт `local_npc_${serial}`. Финальный ID сохранять дословно. Внутренние ID из таблицы ниже получают этот внешний `npc_` префикс. Не повторять префикс и не использовать индекс массива как ID. `_threeNpcActionRefs` связывает ID с исходным объектом (67904/67928); `openNpcActions(entityId)` (68306) вызывает существующее меню/логику по этой связи.

## Категории и реальные источники

| Категория | Исходная коллекция / создание | Внутренний ID / роль | Статус источника |
|---|---|---|---|
| Жители города и обычные пляжные жители | `NPCS`, `spawnNpc` 8673/8675; `initNpcs` 10472; `maintainNpcPopulation` 10987 | `resident_${serial}`; archetype ниже | Клиентский AI основной игры, не отдельный серверный NPC endpoint |
| Саид | описание 9536; `_placeSaidInCity` 10470 | `said_story_npc`, role `said`, specialistId `said` | Особый сюжетный NPC и существующие найм/диалоги |
| 19 боссов-специалистов | `UNIQUE_NPC_BLUEPRINTS`, `SPECIALIST_NPCS` 9694; `_placeUniqueNpcsInCity` 10461 | `unique_${leader_id}`, role `unique_npc`, empireBoss=true | Профиль + серверное состояние империи + клиентское перемещение; исходные hp999999 из конструктора НЕ боевое здоровье |
| Эскорт и рекруты босса | `EMPIRE_CREW_NPCS` 9704; `_spawnEmpireCrewArrival` 9753; `_adoptEmpireStreetRecruit` 9796; `_syncEmpireBossCrews` 9930 | `empire_crew_${leaderId}_${serial}`; принятый рекрут может сохранять свой ID | Состав синхронизируется с империей; клиентские визуальные/маршрутные акторы добавлены в NPCS |
| Охрана владений империи | `EMPIRE_HOLDING_GUARDS` 9705; `_spawnEmpireHoldingGuard` 9872; `_syncEmpireHoldingGuards` 9885 | `empire_guard_${leaderId}_${holding.kind}_${holding_id.replace(',','_')}_${slot}` | Серверные назначения/владения, клиентские видимые посты; уже в NPCS |
| Личная банда игрока | `_myGang`, сбор 67807 | `crew_${g.id}`, role `gang_fighter`, follows_player | Существующий игровой отряд; не создавать повторно из server catalogue |
| Полицейское подкрепление | `_policeBackupUnits`, сбор 67808 | `police_${cop.id}`, role `police` | Коллекция действующей системы полиции |
| Городские патрульные, включая штат тюрьмы | `cityCops`; `spawnCityCop` 11288, `initCityCops` 11347, `updateCityCops` 11388; `_createPrisonStaffCop` 11152 | `city_cop_${cop.id}`, role `police`; prisonStaff/gear/shield | Клиентский AI, взаимодействующий с существующей полицией/розыском |
| Серверные полицейские реагирования | `worldCops`; snapshot `d.cops` → `applyCopsTargets` 27513 | `world_cop_${cop.id}`, role `police_response` | Серверный WS источник; responseTier и другие поля сохранять |
| Босс и охрана конвоя | `worldEvent.boss/guards`, сбор 67809; `applyConvoyTargets(d.event)` 27501 | `world_event_${event.id}_${person.id}`, convoy_boss / convoy_guard | Серверный WS `event`; x/y преобразуются в c/r |
| Бойцы опасных зон/защитники районов | `aggroZones[zone].bots`; `applyAggroTargets(d.aggro)` 27614 | `aggro_${zone.id}_${bot.id}`, role из bot.kind, sourceId=bot.id | Серверный WS; hireable отключается для district defender |
| Охрана гнёзд банд | `gangNests[].guards`; `d.gang_nests` 27623 | `nest_${nest.id}_${guard.id}`, gang_guard либо guard.kind | Серверный WS; семейство и принадлежность сохранять |
| Idle-охрана бизнеса игрока | `BUSINESS_POIS`, `myBusinesses`, `_idleBusinessGuardPose`; сбор 67817 | `biz_guard_${biz.id}_${slot}`, role guard | Визуальные посты по owned/guards; hp100 в сборщике — заглушка представления, не разрешение наносить урон |
| Отдельные отдыхающие | `beachgoers`, `_beachgoerWorldPos`; сбор 67818 | `beach_${id}`, beach_civilian | Клиентская коллекция; исключаются evacuated/carried, трупы используют death coordinates |
| Майкл и его охрана | `MICHAEL_POS`, `michaelGuards`, `_michaelDecor`; сбор 67828–67836 | michael_dealer, michael_guard_${id}, michael_decor_${index} | Майкл статический quest_giver; охрана либо реальные игровые экземпляры, либо декор при пустой коллекции |
| Пассажиры автобусов | `_busWaiters`, `_busRiders`, сбор 67837–67838 | bus_waiter_${i}, bus_rider_${i}, bus_passenger | Клиентские транспортные акторы; существующие индексные ID не подменять постоянными server IDs |
| Гоночные зрители/механики/фотограф | RACE_CHEER_CREW, RACE_MECHANICS, RACE_PHOTOGRAPHER, сбор 67839–67841 | race_fan_${i}, race_mechanic_${i}, race_photographer | Статические/ambient акторы |
| Медики скорой | serviceVehicles с active `_medicalScene`, visible `_medicalCrew`, сбор 67842 | medic.id без добавочного внутреннего префикса, role medic | Действующая сцена спасения; carrying/action/progress сохранять |
| Рабочие свалки | сборщик 67863–67870 (искать workerRoutes) | junkyard_worker_0/1/2, junkyard_worker | Процедурное визуальное дополнение сборщика, НЕ серверные рабочие |
| Интерьеры зданий/банка | `_buildingInt.npcs`, `_bankInt.npcs`, выбор 67804 | Исходный ID/role/type: владельцы, guards, персонал, посетители, участники рейда | Отдельные локальные координаты текущего интерьера; в vault банк отдаёт пустой NPC список; не размещать их в уличной системе координат |
| Нападение на штаб/рейд в интерьере | `_spawnNpcEmpireAssaultNpcs` 20399; dispatcher 59089; raid reconcile/resolve 62620 | Идентификаторы текущего encounter/roster/slot | Требуются серверный token/поколение/подтверждения потерь, а не статический список guards |
| Fallback логова | AGGRO_ZONES, ветка сборщика 67821–67827 | lair_fallback_${zone.id}_${i}, 12 на зону | Только отсутствие живого authoritative aggro; не выдавать за server population и не создавать второй fallback в /walk |

Задержанные NPC отдельно приходят в WS `npc_custodies` (mafiozi_bot.py:26047), включая mode/phase/hidden_in_vehicle/cuffed/prisoner. Их клиентский транспорт — world.html:24476. Не размножать фигуры скрытых в машине задержанных поверх исходной коллекции; проверить существующую custody-проекцию и флаги перед включением в новый renderer.

## Каталог ролей не равен экземплярам

`NPC_ARCHETYPES` (world.html:10555): worker, pensioner, student, housewife, businessman, drunk, bandit, homeless. Время суток/веса и `_pickArchetype` выбирают экземпляры; TARGET_NPC_COUNT=96 (9525), `_targetNpcCount` (10618) меняет население по часу. Пол задаётся `look.gender` при создании, не выводится из профессии.

19 устойчивых server leader_id (`npc_empire.py:109`, PROFILE_BY_ID:158):

`leila`, `rustam`, `marco`, `vera`, `arsen`, `damir`, `marat`, `zara`, `niko`, `alisa`, `boris`, `inga`, `timur`, `emil`, `roman`, `sofia`, `viktor`, `yana`, `musa`.

Актуальные имена применяются через MAFIA_BOSS_NAMES (132) и replace(PROFILES) (151); пример rustam — Билли Капоне, а не старое имя из исходного конструктора. HQ_KEY_MIGRATIONS (143) меняет шесть штабов. Координаты нельзя брать из старого hq_key или статического blueprint, когда имеется живой маршрут/активность. Уникальное оружие имеет отдельный uniqueWeaponId/profile; нельзя молча заменить уникальный профиль обычным pistol/rifle по виду.

## Серверные точки и сохранение авторитета

| Endpoint / entry point | Источник | Назначение |
|---|---|---|
| WS `/world/sim` | mafiozi_bot.py:34813, h_world_ws:30759; world URL builder26943/connect27088 | Единая сессия мира, существующая аутентификация/WS ticket; snapshot event,cops,aggro,gang_nests,npc_custodies,others (server26027–26070) |
| GET `/npc-empires/{uid}/state` | server34788, handler29680; npc_empire.state_for4626; client loadNpcEmpireState19904, polling68738 | Состояние empires/events/diplomacy/districts/leaderboard/interior_raids/server_time; клиент использует `_apiRequest`; это НЕ покадровый список r/c всех NPC |
| POST `/custom-gang/{uid}/npcs/sync` | server34787, handler29672 | Существующая синхронизация пользовательского отряда; не вызывать из renderer |
| POST `/npc-empires/{uid}/assault/prepare`, `/assault/hit`, `/assault/resolve` | server34793–34795; handlers29743/29784/29866 | Контекст боя/токен/shot_seq/проверка геометрии, боевой результат |
| POST `/npc-empires/{uid}/hospitalize` | server34791, handler29727 | Госпитализация по доказательству, не по локально придуманному hp |
| POST `/npc-empires/{uid}/interior-raid/casualties`, `/interior-raid/resolve` | server34796–34797 | Подтверждение потерь по roster/slot и завершение рейда |
| POST `/npc-empires/{uid}/property-guards`, `/street-recruit`, `/diplomacy`, `/building/action` | server34789–34792,34798 | Назначения охраны, набор, дипломатия, операции. Сохранить UI и серверные пути; renderer их не заменяет |

Авторитет field hits: `_npc_empire_live_field_position` 27678, route witness27694, geometry27738; h_npc_empire_assault_hit получает context и lock, затем assault_field_hit_authorized (29819–29859). Не переносить локальный renderer-raycast в право списывать hp, госпитализировать или захватывать владение. Не запрашивать мутирующие endpoint ради инвентаризации.

## Координаты, кадры и представление

Исходные улицы: r=row=y серверной плоскости, c=column=x. Для абсолютного native /walk: `worldX=c*4.1`, `worldZ=r*4.1`; обратное `r=worldZ/4.1,c=worldX/4.1`. Высоту пола брать у host. Старый three_preview.js:247 использует плавающий originR/C: `(c-originC)*4.1,(r-originR)*4.1`; **не переносить этот offset в абсолютный /walk**. Для источника угла, заданного atan2(deltaR,deltaC), hero +Z yaw=`PI/2-ang`; при движении надёжнее вычислить yaw из действительного world displacement. Проверить особые police/vehicle heading отдельно.

В snapshot есть `elevation` (например major_casino), role/look/gender, hp/maxHp, dead/deadAt/recoverable, lifeState, walking/moving/speed/walkPhase, meleeStunned/meleeBlock/meleeCharging, _shotAt/_shotSeq/weapon/uniqueWeaponProfile, burning/bleeding/hitAt/bruiseAt, forcedCrawl/severMask и медсостояния (67905–67928). Не превращать временный knockout (`dead:true` вместе с meleeStunned) в окончательную смерть. Не брать исходные hp999999 у boss, уже есть `_empireDisplayHealth`.

Для мужской/женской GLB нужен клон скелета на актор, собственные pose/surface состояния и общий безопасный кэш ассетов. Не разделять один Skeleton между людьми. Скин/костюм/шляпа должны опираться на look и существующую роль. Намокание определяется актуальной позой и sampled water plane. Wet vertex updates и projected wounds для 72 skinned персонажей требуют LOD/cadence/per-frame budget; не запускать полный mesh scan на каждом NPC каждый кадр без замера.

**Точного места попадания в старом NPC snapshot недостаточно:** hitAt/hitAngle/hitPower/bleeding — сводные эффекты, не подтверждённый world point+normal конкретного удара. Для нового `createArtist14Surface.receive` нужна отдельная confirmed receipt с исходным entityId, уникальным hitId, world point/normal, blocked/heavy/fatal. Не придумывать точку в носу/голове и не создавать persistent bullet wound только из падения hp. Пока нет такой квитанции, можно отобразить подтверждённое существующим источником состояние dead/knockout, но не заявлять точную локализацию ран.

## Практическое подключение без дублирования AI

1. Сохранить единственный runtime world и его WS/AI/timers. Подключить renderer /walk к **его** Mafiozi3DBridge либо вынести существующий snapshot provider в согласованный host. Просто импортировать кусок world.html в отдельную страницу нельзя: он зависит от замыканий, DOM и порядка инициализации.
2. Явно согласовать player position/aim/input и интерьерный контекст. Иначе snapshot останется центрирован на старом world.player, а новая камера уйдёт к пустым улицам. Второй скрытый world с собственным WS может удвоить игрока/симуляцию; это не прозрачная миграция.
3. Новый renderer reconciles `snapshot.npcs` по готовым IDs; исчезновение из radius/cap означает culling, не смерть. Внутренний catalogue служит только проверкой покрытия ролей.
4. Сохранить исходные действия через ID→actionRef/bridge, все server tokens и receipts. Render не создаёт спавны, армии, health, ownership или случайные боевые исходы.
5. Живая приёмка: гражданские обоих полов, Саид, несколько разных боссов/эскортов, city/server/prison police, convoy/aggro/nest, медики и carried bodies, охрана и owner интерьера, переход улица↔интерьер, visibility cap/повторный вход, оружие/плавание/падение. Статический парад моделей или синтетический QA snapshot не доказывает миграцию всех живых механик.
