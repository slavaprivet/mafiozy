# Художник18 — текущая память

19 сентября 2026. Задача `01a0bb21-19d8-7640-9946-ad095a16d52c`, создана и
закреплена. Пользователь затем сказал «так начинай выполнение».

**Живой город НЕ готов.** Последнее наблюдение пользователя: жители и машины
стоят. Важен видимый результат короткими проверенными патчами.

Новый координатор18: `01a0bb23-8430-7262-b885-97bb496a2406`.
Единственная игровая вкладка у него. GPU вкладки здесь не открывались.
Предыдущие владельцы дорог/парковок сохраняются; их parking READY не дублировать.
Полная передача: ARTIST18_HANDOFF.md и ARTIST17_MEMORY.md.

## Новые результаты18

- route_queue_audit18: `_npcReserveRouteWork` использует свежий clock в момент
  допуска. Старые timestamp после выбора цели давали уже истёкшие 4 мс, 0 работы.
  Проверка после: 74 раскрытых узла. NPC_QUEUE_CLOCK_AUDIT18_20260919.md.
- Root: учёт actual route CPU между завершёнными запросами, пять try/finally
  scopes в world. Тот же budget 4 мс/2 допуска, FIFO и коллизии.
  NPC_ROUTE_CPU_BUDGET18_20260919.md. CPU READY, LIVE не подтверждён.
- Аудит реальных входов: hospital/printshop/pawnshop/gunshop/townhouse/garden
  walkup имеют хотя бы один физически свободный grid connector к двери.
  test_npc_entry_grid_admission_audit18.mjs. Гипотеза всех недоступных дверей
  не подтверждена; геометрию по ней не правили.
- Восемь actual townhouse подходов: все завершаются у реальной двери без
  заблокированного последнего отрезка. test_npc_visit_goal_connector_audit18.mjs.
- Субагент route_fast_path18 проверяет bounded прямой путь к building_entry
  только в npc_native_directed_route_source.js. Root этот файл не редактирует.

## Загрузка / чужие границы

У координатора запрошен статус combined reload: elapsed ordinary NPC, parking,
queue clock, crew elapsed, shot FX и другие его изменения. До подтверждения
считать эти пакеты READY на диске, не LIVE. Новый CPU budget передать отдельно.
npc_population shot latch от visuals19 завершён, motion/yaw/gait не менялись.
Наёмники/FX/hero — координатор; дороги/worker/parking — автор автомобилей.

Открытый bottleneck: сотни маршрутов многократно обходят FIFO, при низком FPS
ожидание растягивается. Синтетические CPU показатели не выдавать за общую сцену.
Следующий шаг: снять через координатора прогретые движения/очередь/поездки,
проверить actual car travelled и продвижение waypoint после нового parking.

## Дополнительное поручение: подключить 3-й закреплённый чат и своих агентов

Проверен список закреплённых: третий — «Автомобили — продолжение архитектора»,
01a087f0-fda6-7e13-8baa-1bbd1c5cc26e. Ему переданы транспортные жизненные циклы,
несколько одновременных поездок/заторы, согласование GPU только с координатором.
Он подключил своих агентов. Actual long async 895.97м/6958 frames и восемь седанов
с восемью живыми водителями PASS; LIVE ещё нет. Другие транспортные аудиты идут.

Наши три исполнителя:
- route_fast_path18 READY: короткий swept direct building entry. 26/108 стартов
  обходятся без A*, actual building tests и printshop purchase PASS.
  NPC_SHORT_VISIT_ROUTE18_HANDOFF.md.
- resident_activity_lifecycle18 READY: optional activities не выбрасывают pending
  search; stationary завершение возвращает готовый безопасный маршрут.
  NPC_ACTIVITY_ROUTE_RESUME_20260919.md. Root дополнительно исправил повтор
  недоступной лавочки: NPC_BENCH_RETRY18_HANDOFF.md.
- wander_throughput18 пока WIP: два эксперимента rejected по actual sustained
  движущимся 288 NPC (CPU не улучшился). Возвращает прежний алгоритм, проверяет
  только дублирование footprint query. Не reload до его READY/отката.

Root combined actual visit queue test: 38 стартов у типографии, тот же shared
FIFO/4ms/2slots. До/после short direct: 34→31 кадр для завершения запросов,
wait p50 16→11 кадров, reached 33→33, route CPU122→98мс в одном замере.
Wall-clock шум на общей машине; это не FPS и не полный игровой цикл.
test_npc_actual_visit_queue18.mjs. Проверка всех опубликованных сегментов вынесена
за измеряемые кадры. Новый dataset routeQueue.budgetMode='search-cpu-v1'
помогает координатору отличить загруженную версию; frameUsedMs показывает бюджет.

## Пользователь обнаружил старую сетку / ложную «Биржу труда»

Новое прямое steering: пользователь подозревает старую карту NPC; затем прислал
скрин с золотой «Войти на Биржу труда» на дороге без нужного здания рядом.
Это приоритетный integration defect, не спорить успешными CPU tests.

route_fast_path18 read-only доказал: масштаб в adapters одинаковый4.1; текущие
78building+detention placements совпадают с CPU snapshot, snapshot создан19сентября.
12 отказов раннего fixture оказались внутри закрытых помещений (fine тоже не
проходит), но внешний scan НАШЁЛ два настоящих coarse-grid тупика:
- print_shop start r4.990913843951179,c97.94314630350254 → дверь
  r12.377913843951179,c98.30614630350254. Coarse expanded1/no route;
  fine .25source с прежним footprint .18 и sweep находит72exp/109nodes.
- hospital start r6.469984627970292,c165.137 → r9.356984627970292,c164.
  Coarse expanded1; fine19exp/31nodes, реальный свободный путь.
`test_npc_native_fast_path18_grid_audit.mjs --scan`,
`outputs/npc_grid_resolution_scan18.json`. Это часть причины no-route, не
доказательство причины каждого LIVE NPC.

Ему разрешён bounded fine fallback candidate в native directed module, но
**production заморожен**: координатор сообщил общую reload/startup48%.
До его прогретого снимка90–120сек агенты готовят candidate/tests отдельно.
Если изменил module до freeze — должен срочно сообщить точную версию.

resident_activity_lifecycle18 получил узкий ghostPOI scope: world _gtaBtn возле
32260, job anchor36,16 и тот же actual interaction dispatch. Только candidate
до снятия freeze. Не удалять механики/ID/server, привязать к реальной native
двери; не приглашать в пустоту при отсутствии matching building. HUD styles
координатора не трогать.

wander_throughput18 FINAL READY до reload: только устранение дубля native point
gates в прежней BFS, не новый fast-walk. 1152edge equivalence, sustained288moving
NPC PASS. Handoff NPC_WANDER_POINT_DEDUP_HANDOFF_20260919.md. Ему поручены только
обновление historical regex test и read-only coarse wander audit, productionfree.

После общей reload координатор должен снять budgetMode, реальные source/render
координаты одного стоящего resident и goal; traffic travelled/waypoint. Пока
данные не получены; root не открывал GPU и не менял текущую вкладку.

## Получен LIVE первой сборки; второй grid/physical-entry пакет применён

Coordinator18 прогретый снимок atMs876740: budgetMode search-cpu-v1 подтверждён.
alive288/moving35/driving4/visiting5/social12/pending257; physical6,
purchases128/spent1593; route-pending118/no-reachable37/blocked10/walking13/
visitcomplete53. Queue233, admitted6363,deferred1056452,expired3634.
Resident1 wander0/1 age39404 admittedAgo298614 queue204;
resident2 wander42/60 age87067 queue142; resident3 wander0/1 routeblocked;
resident4 pawnshop003 buildingentry expanded0; resident5 coastal_orchard_house001
expanded0; resident7 wander53/62 age96271. Это НЕ приёмка живого города.

Координатор снял freeze. Root перенёс staged physical-entry-only transform,
fine buildingentry module и wander fineexit в production. `world.html`
_npcFindWanderGridExit использует точный origin, .25source, максимум384узла,
прежний 4ms/FIFO. Все legacy обычные entry кнопки снаружи Walk отключены по
прямому уточнению пользователя, native physical door/2D/car/NPC/server raid
сохранены. Не делать mapped goldbuttons: этот вариант прямо отменён пользователем.
В tests actual fixture добавлен настоящий helper. Adaptive+physicalentry tests
на appliedsource, fairness/wait/bench/plan/worldsyntax/melee/printshoppurchase PASS.
wander agent обновляет только applied test alias, production не меняет.

Для следующего DOM: npcResidentVisits.routeQueue.navigationVersion physical-grid-v2;
jobs включают position{r,c},target{r,c},door{id,r,c,native},fineGrid и
gridExit{expanded,visited}. Координатор получил READY/диагностику, следующаяreload
у него после отдельной door-задачи. Ещё НЕ утверждать исчезновение кнопок в
открытой старой странице или улучшение LIVE v2.

Транспортный владелец передал новое прямое требование пользователя: около90
реально едущих машин; существующих288 жителей достаточно, population не повышать.
Он владеет масштабированием транспорта/водителями/route/admission с субагентами;
root pedestrian nav и планы. Не считать припаркованные машины или декоративные
клоны результатом; CPU стоимость90 и LIVE frame time нужно измерить отдельно.

**Более позднее уточнение через транспортного владельца отменяет фиксированные90:**
песочница, сколько реально поедет по делам, столько поедет. Критерий естественная
видимая смесь движения/парковки/покупок/прогулок и приемлемый FPS. Не повышатьcap
ради цифры и не увеличивать существующих288 жителей.

## Финальная граница LIVE / browser

Root прочёл computer-use SKILL и сделал единственный CUA getState read-only:
в browser1 с metadata session01a0bb21 tabs=[]; вкладка координатора недоступна
в инвентаре этой задачи. Новую GPU вкладку НЕ создал, никаких кликов/reload/камеры.
Координатор уведомлён, что только его session может проверить загруженную v2.
Applied wander regression теперь читает настоящий production helper без double
inject, appliedProduction:true PASS; все scopes root/агентов свободны.
Координатору дан FINAL READY и просьба не задерживать короткий city/button reload
ради новой мускулистой модели громилы. Разрешён узкий npc_actor visualbruiser scope
его единственному агенту, нашими исполнителями npc_actor/mercenary_pose не занят.
Открытая игра пока подтверждена только search-cpu-v1; physical-grid-v2 нужно
подтвердить в его DOM. Никакого утверждения о полной готовности живого города.

## 20 сентября: живой снимок v2 и применённый physical-grid-v3

Поздний снимок Coordinator18 подтвердил ВТОРУЮ reload с physical-grid-v2.
at370017ms: alive289/moving41/driving9/visiting6/pending232; queue208,
admitted3847/deferred612577/expired2301/epoch3086. Ambient45 все approach,
board0/drive0. Source CPU p50/p95 16.5/21.2ms; renderframeCPU74.8/90.6;
frameinterval94/112ms (~10.6FPS), GPU37.07/52.91, draws2965.
Пользователь прав: это не готовый живой город.

**Позднейшее прямое указание пользователя, переданное транспортным автором:**
«с Художником разбирайте задачу, Координатора не трогайте — он занят другим».
Больше НЕ писать координатору и не просить reload. Его вкладку не трогать.
Нашей GPU вкладки нет (CUA tabs=[]), новую не создавать. Работа с транспортным
владельцем 01a087f0-fda6-7e13-8baa-1bbd1c5cc26e продолжается в shared source.

Применённые root изменения:
- `_maybePlanResidentBuildingVisit`: стабильный callback non-plan посетителя,
  сохранение `_residentVisitTargetId` при pending, отсутствие нового случайного
  отказа/смены двери на каждом slice. Динамические actor rules продолжают
  читаться. `test_npc_nonplan_visit_resume18.mjs` actual print shop, registry
  reorder + random reroll, worker18/bandit16calls послеv3,0restarts, PASS.
- `pickNpcWaypoint`: одна полноценная longWalk цель вместо8вариантов, прежние
  depth>=8/net>=6source/footprint/sweep/FIFO4ms2slots. Дет. xorshift permutation
  dirs поid/origin/previous origin сохраняется между slices. Четыре AB/BA
  сравнения actual288/60s при20 и10Hz дали больше движения/маршрутов, меньше
  plannerCPU, но10Hz p95wait всё ещё45–49s. Это частичный выигрыш, не готовность.
  Contracts256directions N63/S60/E68/W65; historical actual267/267 clear PASS.
  Документ NPC_WANDER_SINGLE_GOAL_CANDIDATE_20260919.md помечен APPLIED.
- `npc_native_directed_route_source.js`: bounded goal anchors до городскогоA*.
  В пределах прежнего radius проверяется полный connector до настоящейдвери;
  если none, допускается проверенное соединение к anchor до2.25source. Discovery
  сохраняется в4ms slices. Connector перепроверяется перед публикацией.
  Сохранён fine isolated-start узкийкоридор (найденная review regression
  исправлена ДО переноса). No-anchor не тратит1200узлов для обычного coarse
  старта. Возвращается только маршрут до exactgoal, прежний partialbest убран.
  Diagnostic `navigationVersion:'physical-grid-v3'`.

Точный LIVE resident16 start139.111932568,173.181051759 → coastal002 door
150.893585368,165.747926883 воспроизведён actual GLB002: оба coarsegoal внутри
.8blocked. Раньше1160expanded/1200visited,175–213msCPU,43–52slices,fail. Теперь
18expanded/50visited,3–4slices/~10–17msCPU,physical75.866m/926steps max.082m до
настоящей двери. Новый safeanchor150.5,167.5. APPLIED goal + direct/adaptive +
shop entry/pay55→52/exit PASS. `NPC_GOAL_ANCHORS18_HANDOFF.md`.

Транспортный автор внёс отдельно: driver admission radius6 вместо18, короткий
approach только после полного safe sweep сразу физическим маршрутом безBFS,
distributed initial spawn. Его `_civilianVisitOfferReady` gate нового seek_shop
применён вworld:78/288начинаютвизит,210сначалагуляют; committed/pending/trip
visits сохраняются. Его dismissed-mercenary scopes/retaliation НЕ трогать.

Read-only audits: native entering/browsing/exiting6GLB PASS; bench иactivity
бесконечныйreset не подтверждён. Actual source→bridge→male/female rigs→minimap
при10/4Hzsource и60/10/5Hzrender:source/render/gait14.4m совпали, дополнительных
остановок0. Mini dots используют именно actor.Object3D.position. Не анимационный
стопор. Gate policy arena/lair/prison/sand объясняет исключения, не снимать их.
Cap2→8 оставляет прежние4ms, но нестабильный малый выигрыш — НЕ применялся.

v3 применён В ФАЙЛЫ, LIVE этой версии и FPS общей сцены НЕ проверены.
Не выдавать CPU результаты за оживший город в открытой вкладке.

## 20 сентября: physical-grid-v4, после нового «стало лучше, но стоят»

Основная задача всё ещё не объявлена завершённой. Root применил ещё три
доказанных исправления, без Coordinator/браузера:

- Native wander frontier теперь depth-first через insertion после current,
  вместо обхода всей широкой окрестности. Только прогулки, directed не менялся.
  Все visited/parent/goal reservations/4ms2slots/depth18/520node/body/sweep и
  longGoal depth8/net6source сохраняются; 2D сохраняет BFS. Actual288 test:
  последние20сек при10Hz moving45.27→68.72%, pending54.11→30.46%; при20Hz
  moving75.64→96.27%, pending23.32→1.41%. Planner CPU тоже ниже. Это CPU fixture,
  не FPS/live; короткие confined fallback некоторых жителей остаются и стали
  чаще при20Hz. Doc NPC_WANDER_DEPTH_FIRST_CANDIDATE_20260920.md APPLIED.
- `_civilianRouteTo` больше не append второй exactgoal. Послеv3module это
  заставляло ordinaryfoot перескочить entry check и заново искать путь у двери.
  Предыдущие lifecycle tests вручную вызывали retry и скрывали этот баг!
  Новый test_npc_postexit_audit18.mjs гоняет настоящий ordinaryfoot/pick без
  manualretry: normal/pending теперь полностью проходят hospital entry/exit.
- Новый `npc_road_egress_source.js`, загруженный script вworld: после no-goal
  recovery житель на road (или centerland/cornerroad) физически выходит на
  ближайший проверенный целикомland footprint, затем гуляет. Прежний waypoint
  запрещал road с первогоsample, давая0м/60s. Shared4ms/FIFO, routekind
  civilian_road_exit, fullbody/sweep/water, сохранён committed building visit.
  Actual recovery шаг200ms, land850ms, затем>5m; helper0.44–0.67ms/3calls.
  Stale orphan search/merc_resident/world_person/guards/water/dynamiccar PASS.
  Hook вpick имеет typeofguard для legacy fixtures; actualfixture грузитhelper.
  Doc NPC_ROAD_EGRESS18_HANDOFF.md APPLIED. World diag physical-grid-v4.

Отдельный запрос транспортного автора по LIVE скриншотам: NPCмашина паркуется
диагонально/в проезде, водительвыходитистоит. Он владеет parking/source drive;
наш scope postexit выше + renderer. `world_traffic_presentation.mjs` теперь
вычисляет steer по фактическойкривизне/подписанномупробегу/wheelBase, если source
не публикует steer (раньше всегда0). Explicit steer авторитетен; reverse,
teleport, braking, parkedreturn/zeroidlework PASS в test_npc_traffic_steering18.
Геометрия/physics/sourceAI этим не меняются. Измерения FPS общей сцены нет.

Транспортный автор отдельно передал пользовательский police visual scope:
lightbar/steering/siren/display, без его dispatch/incidents. route_fast_path18
нашёл: sourceemergencyLights уже публикуется, ноWalkтолькодержитmetadata, GLB
LightbarRed/Blue постоянноemissive1.3/1.4. Готовит isolated visualhelper private
lampmaterials, phase170ms, безPointLights/геометрии. Audioсиреныexistingнет,
world _audioCtx/_sfxOut private; второйAudioContext НЕ создавать. Оттранспортного
владельца нужны emergencyLights/serviceState/emergency/sirenActive, ему передано.

Police lightbar helper затем APPLIED root в world_traffic_presentation.mjs:
createTrafficEmergencyLamps, два private material, фазовый update170ms,
inactive/wreck off, restore/dispose, нет PointLight/newgeometry/drawcalls.
Root добавил emptylampfastreturn и finite dt дляclock. Steering/presentation
tests PASS, agent заканчивает appliedactual3GLBtest. Siren AUDIO НЕ добавлен;
unsupported police_armored_van/SWAT/paddyvan renderer mapping передан автору
автопарка: требуется настоящий профиль, не подмена седаном. Его диспетчер и
incidents остаются его scope. LIVEv4/lighting/fullsceneFPS не проверены.

## 20 сентября: пользователь «решайте проблему», applied physical-grid-v5

Подробно: `docs/ai/NPC_IDLE_V5_20260920.md`. Вworld применены max8 cheap route
admissions при прежних4ms/FIFO; resumable wander neighbor expansion вместо
атомарных4соседей; убрана повторная случайнаяпауза ordinaryeligibleWalk после
готового маршрута; bench nativeA*/stablepass/1.8m approach (2D .6m сохранён);
bounded native visit recovery при missingdoor/blockedexit. Никаких телепортов,
снятия коллизий или роста population. HTTP18538 отдаётphysical-grid-v5.
CUAинвентарь сноваtabs=[]; новуюGPUвкладкунеоткрывали. LIVE/FPSнеподтверждены.

Все прикладные проверки проходят: 23/28actualbenchwalk/sit/release, printshop
55→52 purchase+exit, sixGLBvisits, postexit, queuefairness/cpu, wandercontracts,
neighbor-yieldexactrouteparity. Whole ordinary288/10Hz reverse сравнение
moving66.7→75.17%, CPU p50 11.01→12.17ms/p95 13.66→13.98ms; forward доneighbor
yield показал только70.99→71.52%. Не скрыватьограничения/необъявлятьживойгород.
P95 ожиданиявстрессетесте22–24секвсёещёслишкомдолгое.

Пользовательуточнил«копыболее-менеходят,почемунеможемNPC»: actualcopmover
сначаладелаетdirectsafestep, ordinarywanderждётwholeouting. idle_route_audit
получилread-onlylookahead/prefetchfeasibility, productionэтогоещёнет.
StaticcrossframecacheНЕприменён(нетнадёжногоcollisiongeneration).

Transport owner ужеисправилugon→advancedWalkphysics/claimPlayerControl/DRIFT.
Playervehiclebridgeегоscope, нетрогать. Optimizer01a06e4d готовитisolationqa
сединственнымGPUу18; сообщилемунашCPUbusy, послепрогоновосвободитьCPU.
Пользовательпопросилкоординаторанебеспокоить—по-прежнемунеконтактируем.

## 20 сентября: очередь занятий с резервированием

По прямому предложению пользователя применены agenda и лимит 15 посетителей
на физическое здание (pending + inside). Полная передача:
`docs/ai/NPC_ACTIVITY_AGENDA18_HANDOFF.md`. Новые production helpers
`npc_activity_agenda_source.js`, `npc_activity_reservations_source.js` загружаются
в world; hooks выбора, физического входа/выхода, отмены и lifecycle подключены.
Лавочка резервируется до pending поиска; неудача/отмена освобождает, поиск
лавочки имеет предел 45 секунд. Agenda сохраняет pending frontier и реальные
владения, unavailable немедленно переходит к следующему делу. Native shop
обходит прежний повторный случайный фильтр. Завершённые walk/shop/bench
продвигают очередь; фоновый lifeTick не похищает следующий walk под bench.

Actual printshop stress: 15 физических входов/покупок/выходов, после выхода
0 slots, 16-й идёт гулять (21.8 м), max step .082 м. Helper/lifecycle/unit и
старые purposeful/native/bench/recovery tests PASS. HTTP18538 отдаёт patch.
Диагностика dataset.npcActivityAgenda version activities-v1. LIVE общей сцены,
GPU/FPS и личное пространство 15 посетителей не проверялись. Не объявлять
массовый простой всей карты решённым по этим проверкам.

Transport owner 01a087f0-fda6-7e13-8baa-1bbd1c5cc26e внедряет atomic
_npcAgendaTryDrive + admission filter + drive Complete в shared world и
canonical civilian_parking_trip_source.js. Его реестр машин единственный.
Root передал review: полный город вместо first128, ambient нельзя забирать
занятых shop/bench, совокупный framebudget. Старый native_trip_contract
показал expected approach/actual planning, сообщено владельцу на проверку.
Итог транспортных проверок смотреть последним приложением в handoff.

Итог этого прохода: transport owner обновил fixture реальной парковкой
(destination.lotId + parking-anchors); native_trip_contract теперь PASS.
TryDrive whole-fleet spatial cache500ms +4attempt/frame, atomic register,
global/ambient owner guards и release применены. Root повторно bridgePASS:
720 машин lookup p50 .664/p95 .873 мс (CPU adapter only). Bench pending
regression 10cases PASS. Inline canonical transport exact parity, HTTP200
оба новыхhelper exact served. Combined activities-v1 source готов, обычный
reload пользователя; полной LIVE/GPU/FPS приёмки по-прежнему нет.
