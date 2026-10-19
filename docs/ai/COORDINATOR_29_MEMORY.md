# Координатор 29 — продолжение NPC, 15 октября 2026

Прямое поручение пользователя в чате `01a13c92-3f51-7d40-acb3-3bb807ee1340`:
«кординатор 28 завис. проверь почему. прочитай его чат продолжи его задачу».
Позднее: дождаться и принять работающего субагента28. Это выполнено:
navigation `01a13c6a-31d3-7953-9837-1422e69b4311` завершил death28,
API completed; life/doors также completed/idle. Root28
`01a13c68-161c-7293-b4ee-ebdfe7170017` теперь interrupted/idle, подтверждено API.
Старых авторов не будить. Текущий чат переименован «Координатор 29».

## Восстановленный контекст

Все прямые сообщения пользователя в доступном чате28 прочитаны; прочитаны
COORDINATOR_28_HANDOFF.md и COORDINATOR_28_MEMORY.md, передача всех трёх авторов.
Последний открытый дефект: долгий простой после больницы и ресторана.
Один тестовый resident_1; 296 нельзя включать без отдельного разрешения.
Обычная случайная прогулка по суше с обходом физики, 17 случайных занятий.
HP строго <50% — больница, 1.5с лечения внутри, реальный выход.
Энергия строго <20% — случайно ресторан/магазин, около2с внутри, энергия100.
Цена5–50$ сохраняется; если не хватает, сначала банк до1000, затем та же покупка.
Больница бесплатная; исторически надпись «Житель» цветом HP, без полосы/цифр/энергии;
при оплате краткая надпись −N$. Смерть прекращает задачи/поиск до новой жизни,
новая жизнь имеет полные HP/энергию/1000$. Всё проверять настоящим Godot.

## Причина зависания чата — границы доказательства

Последний ход28 оставался inProgress без error/approval и без незавершённой
команды; его cycle52_05 уже завершился exit0, source_drift[]. Godot-процессов
на первом свежем inventory не было. Субагент navigation при этом работал.
Точная внутренняя причина остановки генерации не установлена. В журнале приложения
есть повторные ошибки фонового Git review-summary (1135 аргументов, spawn_failed),
но причинная связь с зависанием не доказана. 15.10 01:47 MSK пользовательский
turn/interrupt завершил старый ход; API затем подтвердил idle/interrupted.
Ruflo/ToolSearch не представлены среди доступных инструментов.

## Собственный кандидат и принятые исходники

`outputs/coordinator29_npc53/game` — побайтная копия1055 файлов game52 без .godot,
проверка источника source_drift[]. BASELINE.json хранит все SHA. Старый game52
не менялся. Все три пакета скопированы в `upstream_packages/{economy,ambient28,death28}`.
Хэши economy/death сверены. integrate_packages.py и integrate_death.py объединяют
экономику,17занятий,hostpose,смерть/возрождение с сохранением изменений маршрута.
Все пакеты SOURCE READY от авторов, native приёмку выполняет29.

## Маршрут53

Подтверждён cycle52_05: после выхода больницы21с поиска, после ресторана6с,
позже случайная цель за фундаментом снова вызывает долгий поиск.
В route53 применена сетка1.2м для внешних путей>8м, сохранены полная капсула,
проверки опоры/воды/коллизий, оригинальная сетка.4м при отсутствии крупного пути.
Первые import01 и graphical route53_01 exit0/stderr0/source_drift[].
Больница/ресторан завершены; после выхода не было стояний>2с на первых переходах,
но поздняя случайная прогулка дала47с на недопустимой цели. Поэтому общий PASS
всей прогулки НЕ заявлять. Точные исходники этого опыта заморожены в
route53_01/changed_sources; OBSERVATION.json/STALLS.json — факты.
ROUTE_FIXTURE01.json: три nativePASS — обход, переход к точной сетке в узком
проёме, отказ щели.6м при диаметре капсулы.72м. Маски/размеры сохранены.

Следующее исправление уже в game53: случайные цели проверяются полной капсулой,
опорой и видимостью; прогулка без продвижения2.5с отменяет цель с честным blocked,
не добавляет completed и повторяет выбор через.25с. Перерыв1–3с остаётся после
настоящего arrived. Целевые больница/экономика не отменяются этим ограничением.

## Текущий незавершённый этап

import02 общей сборки PASS, exit0/stderr0. Запущены:
- death53_01: graphical, entry_death28.gd, hp49/energy19/cash25,
  near-player1, respawn2s, проверка настоящего sniper input и новой жизни.
- economy53_01: headless180s, hp100/energy19/cash0/seed53,
  требуется банк→та же еда→выход→прогулка, реальные account receipts.

Не считать их PASS до чтения итоговых файлов. Новые ошибки исправлять в game53
после завершения обоих читателей, через scheduler write lease. Дальше нужны
полный совмещённый цикл, низкие/точные пороги, отмена при смерти, повторная жизнь,
визуальная проверка17занятий/лавочки/предметов/денежной надписи и измерение стоимости.
Все native запуски через tools/godot/test_scheduler.py (2headless+1graphical,
perf отдельно), свежий inventory, завершать только свои процессы.

F5/current_version и принятая сборка48 не изменялись. godot-4 PAUSED сохраняется.
Не откатывать artist24 merged_root48_08. Пользовательские окна сохранять.
Git WIP27 и исходные .godot cache сохранять; stage-all запрещён. Новые исходники
ещё не опубликованы/не приняты. Переход29 не означает завершение всей миграции.

## Поздние прямые поручения и выполненное 15.10

Пользователь прямо разрешил своих субагентов. Активны navigation29 (маршруты),
venues29 (места/очереди/новые компактные здания), ambient29 (занятия/позы/лавочки).
Нужно учитывать будущих286 жителей, но разрешения включить всю population нет.
Новые заведения разрешены: ближайшие больницы/банки/рестораны/магазины, ёмкость,
разные места внутри и пропуск одного через дверь. Одна тестовая жизнь сохраняется.

Новое UI-поручение отменяет прежний запрет цифр: рядом при наведении карточка
«Житель» + HP, именно широкая рамка бойцов банды из Walk, разделитель двух строк.
Тёмный фон соответствует оставшемуся HP, потеря осветляет справа налево плавно.
Пользователь подтвердил правильный reference three_preview.js:3156 (gang cards).
Физический focus один ray/frame общий, расстояние5м от игрока, стена закрывает UI.
focus53_01 native7casesPASS: full/half/lowHP, far/lookaway/wall/dead hidden,
286проверок в кадре не создают286лучей. focus_game53_02 — настоящий viewportaim
на текущего resident_1, HP60/60 из владельца; source_drift[], stderr0.
Однако TAA реального города размывает текст: подготовлен общий canvas renderer
в proposals/root_ui29, stage_canvas29.py; НУЖЕН запуск/визуальная проверка.

Пользователь увидел ambientfixture и прислал три скриншота: collar у груди и
pocket у пояса пересекают пиджак. Это подтверждённый VISUAL FAIL, не выдавать
17занятий за принятые. Добавлено прямое поручение «в телефоне сидит ещё сделай»:
ambient29 готовит18-е действие phone (смотреть/нажимать), исправления IK/предметов,
позы проверять со всех сторон. Отдельный ambient29_pose, старые freeze сохранять.

death53_01 FAILsetup: near-player1 переносит в заблокированную точку; не использовать.
death53_02 graphicalPASS: настоящий sniper input→shot/terminal/HP receipts,
deathframe1118→respawn1239, мёртвый не делал daily/nav/routequery. Новаяgeneration2:
HP60/60,energy100,cash1000,новыеbody/owners/account. ПодтвержденоDEATH28.json,
exit0/stderr0/source_drift[]. После новой навигации смерть повторить.
economy53_01 nativePASSbank0→1000→та же restaurantprice12→cash988, energy100,
physicalexit,12реальныхroams и3ambient. BEHAVIOR_ACCEPTANCE29.json фиксирует инварианты.

navigation29 source интегрирован: общий soft1800us/frame physicalqueue, FIFO RR,
порции1сосед/опора, directfullcapsule до32м, coarse/finefallback сохранены.
Native candidate01:4fixturesPASS, baseline01:2PASS;286requests на1fixturebody
завершились за66кадров, maxfirst9, maxframe1848us; это не286жителей/FPS.
SimpleHospital теперь cancel physicaljob при смене/отказе/смерти/конце.
service_approach отделён от roam2.5s timeout. Дальние nativequeries ещё ограничивает
новый proposal navigation29_long через СУЩЕСТВУЮЩИЙ PathJobQueue, не вторуюauthority.

venues29 интегрирован с71nativecapacitychecksPASS286requests/0NPC (capacity53_01).
Ресторан6/магазин4/банк2/больница4, проверенные distinctroompoints, FIFOportal,
слот держится до настоящего выхода/смерти. Hospital использует тот жеphysicaldriver.
cycle53_01 остановлен root по точной identity своегоchild23280/02:06:45.195371:
QAobserver ошибочно вызывал oldactive() у новогоhospitalwrapper. Отдельно fixed
Godot get_meta(META,null) absentmeta ERROR в registry/windowindex (has_meta gate).
cycle53_02 сейчас180sheadless: уже реальноhospital→bank→food→walk→watch,stderr0;
по завершении прочесть RUN_CHECK/OBSERVATION и validate_cycles29.py.

ambient53_01 graphicalfixture16standingactions captured, общийFAILbench_arrival_too_far,
и ERROR absentmetawindowindex (root исправил). Benchdriver arrive.30 противgate.18
ещё чинит ambient29. ambient29_slotsSOURCEготов отдельно, пока неинтегрирован.
sites/longroute/pose продолжаются в отдельныхproposalпапках, root запускаетnative.

## 15 октября, 02:44 — текущая игровая версия53a и новые поручения

Пользователь прямо попросил подключить наработки к своей сцене/F5 и загрузить
текущую версию в GitHub. Подготовлен неизменяемый снимок
`outputs/coordinator29_release53a`:1098 source files, отдельные ASSEMBLY/ACCEPTANCE,
bootstrap и proof receipts. `godot/current_version.json` переведён на53a;
предыдущий pointer48 сохранён в PREVIOUS_CURRENT_VERSION.json. Старые48/52 сохранены.
Это текущая рабочая игровая версия, не полная приёмка переноса/286NPC/perf.
Launcher теперь читает pinned city launch_arguments, переносимый game_relative,
ограниченный timeout40–120с; старые manifests сохраняют старое поведение.
CheckOnly подтвердил и старую48, и новую53a. Новая обычная игра запускается root;
смотреть свежий `outputs/current_game/OPENED.json`, не исторический PID.

В53a включены общий canvas gang-style HP, настоящие красные расходы, shared queue
physical1800us и native query1submit/frame/2inflight, новые roam budgets,
физические slots и8 compactowned sites с нормальным порогом и закрытием при
утрате двери. Один resident_1, разрешения включать286 всё ещё нет.

Взгляд: Attention29 сохраняет активную цель/leg, плавно поворачивает к игроку;
после отвода готовый путь идёт в следующий physicsframe без нового поиска.
CityDaily срочно опрашивает только current/previous focus, максимум2жизни,
общий1ray/frame, поэтому не ждёт rotating slice. Тревога/health/retaliation старше.
Исправлен старый incident seam: обычный physical roam теперь отменяется при startle.
Service pause сохраняет slot/heartbeat и сбрасывает dwell, не оплачивает/лечит в паузе.

Фактические проверки:
- cycle53_02 PASS14: hospital→bank→restaurant12→988cash→roam/ambient, всеslotsreleased.
- focus53_02 PASS7: чёткая canvas-карточка, HP/full-half-low, wall/far/lookaway/death.
- money53_02 PASS6: реальная покупка12, один красныйpopup, подъём/затухание/удаление;
  screenshot spend_red.png просмотрен.
- navigation29_long/runs/long02 PASS3fixtures,286queryrequests, не286NPC.
- navigation29_integration/runs/integration05 PASS17physical+10dailychecks;
  готовый путь0.0300002м на первом кадре после resume,0новогоplannerus.
- attention53_01 FAIL QA: слишком резкие последовательные cameraaim corrections
  теряли цель. Вторая проверка плавным viewportinput: attention53_02 PASS7,
  drift0, turninput1159→release1160→motion1161, та же цель.
- attention_alarm53_01 PASS12 в actualcity+8sites: настоящий TT input→shot→alarm,
  взгляд во время тревоги не держит жителя; HPнеизменено, после тревоги снова держит.
- sitesrepair native sites08 PASS87/batch01 PASS48/world02 PASS24:8реальныхмест,
  C4nativeinput19chunks, RPG1shot/1blast, closeddoor/emergencyexit честные.
- play53_01 ordinarybootstrap53 graphicalPASS: populationready1,8sites,revision53a,
  stderr0/source_drift[]. Скрыта временная стараяHP- подпись при bootstrap.

Открытые прямые поручения (продолжаются в candidate53, НЕ менять frozenrelease53a):
1. ambient29: руки collar/pocket сквозь пиджак, телефон18, bench dock/slots. Автор
   долго не отвечал, root interrupt/followup в02:39, ждём конкретный новый пакет.
2. venues29_staff: кассир с терминалом, медик с меднабором, canonrig, один активный
   serviceклиент/FIFO; capacity slots остальных — ожидание. Dwell только у стойки.
3. navigation29_avoidance: spatialgrid, boundedneighbors, rightside/yield иdoorFIFO;
   первый worst-dense286proxy component median16.6ms/p9518.8ms НЕ принят, оптимизирует.
4. После объединения финальные циклы/death/визуальный/perf. Совместный FPS и286proxy
   проверки не выдавать за полную286NPCperformanceприёмку.
