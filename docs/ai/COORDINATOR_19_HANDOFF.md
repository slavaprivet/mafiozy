# Координатор 19 — передача 20 сентября 2026

**Созданный преемник: `01a0bbfb-382f-74f3-a365-3137828ca634`, закреплён первым.**

Пользователь дважды прямо попросил: «как доделаешь создай координатора 19 передашь туда контекст продолжишь там», «напиши как закончишь создавай координатор19 продолжим новую задачу». Преемник Координатора18 `01a0bb23-8430-7262-b885-97bb496a2406`. Общий shared каталог C:/Users/Слава/Desktop/Мафиози, сотни чужих dirty changes: никаких broad git add/reset/commit. 18 прекращает новые production правки после передачи. Пакет source готов; НЕ путать unit/CPU PASS с LIVE приёмкой.

## Что пользователь хочет сейчас

Главная задача — надёжная банда: V всем за мной, X земля отменяет работу/очередь и ведёт на точку; X объект специалист выполняет дело; несколько действий у цели открывают компактное меню. Рабочие таймеры над целями. Догонять движущуюся машину до остановки, начать полный таймер установки, если тронулась — сбросить незавершённую закладку и продолжать погоню до отмены. После установки самостоятельный заряд, безопасный отход не менее8м, взрыв.

Очередь: X щиток, затем X ворота — инженер сначала первое, потом второе. 8 ожидающих задач на специалиста. Номера целей, зелёная текущая, янтарные ожидающие, красная выбранная; выполненная без выделения. Мягкие дуги вместо красного корпуса и резких рёбер. Машины без hull и без верхнего красного X, только центр-подсказка и назначенные номера. NPC только нижнее кольцо; свои имя/профессия/МОЯ БАНДА над головой. HUD чистый, сообщения приказов и свидетелей над миникартой; QA Ctrl+Shift+F9.

E рядом со своим — разговор, в нём уволить. Выбранный спокойный боец близко поворачивается к игроку и приветствует, без отвлечения от боя/работы. Реплики 251, профессии разные, V герой «Все ко мне», Xground «Все сюда» и варианты. Текст строго НАД ГОЛОВОЙ как бейджи, не в центре. Голоса мужские/женские из реально установленных RU системных TTS, записанных реплик вassets не найдено. Не выдавать singlevoice fallback за двух актёров. Исправлено обрывание по TTL и новым событиям, текущая речь договаривается, очередь2 срок4.5сек.

Запуганный NPC бежит от преступлений/выстрелов и не звонит; несделанный звонок отменяется, уже отправленный report/ACK не отменяется. ПОСЛЕДНЯЯ ПРАВКА: страх РОВНО60сек от успеха запугивания; новые выстрелы/преступления не продлевают. Повторное успешное запугивание запускает новую минуту. Над NPC метка «Страх» с LOS/offscreen/living guards.

Громила крупнее/мускулистее, пользователь отверг раздутые рукава/опущенные плечи/длинную шею. Причина fixed: dynamic bindMatrixInverse вместо inverse(bindMatrix) искажала вершины вдали отorigin. Плавные плечи, taper рукавов, трапеции, шея короче25%; root/оружие не ломаются. Latest удар по прямому запросу усилен: snap~112мс, нога до1.4x только на пике, потомточное восстановление, actual toe door gap<1.4см male/female. Пинок громилы или бомба открывают физическую QA дверь.

## SOURCE READY / файлы и проверки

Все модули assets/maps/city_rebuild_v1. Субагенты18 завершены, новых владельцев не дублировать.
- mercenary_core.mjs/world.js: очередь, follow route stable/free slots, safeexit до открытиястворки, movingcar pursuit. Root добавил movingBombTarget по фактическому contact delta, settle.3сек, no vehicle approach timeout. Agentworld сохраняет поиск/безопасный префикс движущейсяцели, reconnect2Гц. Движущаясяцель5/10/30FPS source тестPASS; новогостоячегоblockedcar до120секиотменаPASS.
- mercenary_targets/walk/selection/task_markers/action_menu: мягкие дуги, очередь/окклюзия, автоwreck больше не предлагаетподрыв; X choice single-direct/multi-menu. getHero:()=>hero?.object подключёнroot вwalk_preview.
- mercenary_breach_door.mjs: настоящая дверь2x2.38м, lockkick/bombonce, 2collisionupdates. Найден LIVE дефект: центр луча в4ммшве досок -> X шёлвземлю. Исправлен цельной НЕрендеримой picksurface вместе со створкой, 0draw, реальныеколлизиипрежние. ActualThree sourcecamera reproduction4PASS.
- npc_actor/mercenary_pose: форма и резкийпинок. docs/ai/BRUISER_VISUAL18_FRONT_SIDE.png — CPUprojectedactualgeometry, НЕLIVEскрин. 3actualGLBtestsPASS.
- mercenary_chatter, speech_bubble, badges: реплики/TTS/пол/приветствия/страх. Source world hooks witness тоже. Числа targetedtests вhandoffs.
- Root final regression test_mercenary_walk/world/vehicle_persistence18:50PASS. Старые ожидания path_timeout и установки сразу после остановки обновлены подновыйявныйконтракт, недефектыспрятаны. Все6classicworldscriptscompile.

Свежие handoffs в docs/ai:
MERCENARY_QUEUE_20260920_HANDOFF.md, MERCENARY_QUEUE_UI_20260920_HANDOFF.md,
MERCENARY_MOVING_TARGET_ROUTE_20260920_HANDOFF.md, MERCENARY_MEMBER_TALK_20260920_HANDOFF.md,
MERCENARY_X_CHOICE_20260920_HANDOFF.md, MERCENARY_CHATTER_20260920_HANDOFF.md,
MERCENARY_OVERHEAD_SPEECH_20260920_HANDOFF.md, MERCENARY_INTIMIDATION_WITNESS_20260920_HANDOFF.md,
MERCENARY_FEAR_BADGE_20260920_HANDOFF.md, MERCENARY_BRUISER_VISUAL18_20260919.md,
MERCENARY_DOOR_ACTIONS_20260919_HANDOFF.md, MERCENARY_BREACH_DOOR_QA_20260919.md.
Также читать COORDINATOR_18_HANDOFF.md для17наследования/остальныхмеханик.

## Одна игровая вкладка / LIVE правда

URL http://127.0.0.1:18538/world.html?direct=1&previewcity=1&render=3d&renderer=walk&weapon=pistol&cash=5000&npccombatqa=1&npctransportqa=1&perfqa=1&vehicleshadowcull=1&mercenaryqa=1
CUA18 browser1 tab1 bindingwalkGame18;19 долженполучитьсвойinventory/handle, неоткрыватьновуюGPUвкладку. CUAread-onlyevaluate толькоDOM/datasets, неglobals/мутации. Пользователь ранее разрешил reload и3–5минуправление. Параллельноиграет! Камера/патроны/QAменяютсямеждунашимиинструментами; неатрибутироватьвсёсебе. Проверщикучатовотправленоостановитьегоbrowserдействияеслионибыли.

LIVE18 CONFIRMED: Xplant_bomb наQAcar → completed20.3сек, carhp0/wreckedtrue, операторвернулсяarrived. V всяпятёрка переместилась~15м и всеarrived (positions проверены). Xground позднеедал«Точка...4бойцов», все4arrived; пятыйгромилараненпослеподготовки. Текстгероя «Все сюда!» появилсявреальномDOM, надголовнаяпозицияпоследнегопакетаещёнеоцененаскрином. Дверь в однойпользовательскойсессииopenedmodeblast, неrootприказ. Safe/cut/power/revivecompletedбылиактуальновDOM предыдущейсовместнойсессии, пользовательподтверждалостальныеработают.

LIVE NOT COMPLETE: новаяпогонядвижущегосяавто/очередьдвух/пинокдвери/Eувольнение/genderaudio/ровно60сfear — провереныCPU но нужнопройтиUI. Необъявлять«всёисправлено/принято». Последняяreload18 сделана ПОСЛЕ fear60/overhead/voicefix/doorpick/snapkickready. Продолжение ниже добавитточноефинальноесостояние.

QA: CtrlShiftF9 открывает; button «Подготовить площадку и отряд» занимает15–25с и иногдаlocatorCDPtimeout, сначала freshAX затемповтор. Dropdown aria-label «Объект профессии»: overview,door,patient,vehicle,safe,power,cage; «Осмотреть объект» ставитгероя/камеру кцели черезявныйQA. Подготовка намеренно делаетгромилу95раненым длямедика — передпинкомсначаламедик(patientX)!! Новаяreloadсбрасываетплощадку, не нажиматьбесконечноprepareвожиданииreset существующихцелей.
DOM body.dataset.mercenaryShowcase: layout/door/safe/vehicles/members/actions+movement. Snapshot1Гц; immediateпослеkeyможетустареть. docElement datasets npcCityPopulation/npcResidentVisits/civilianTrip/nativeParkingAdmission/ambientTrafficDrivers/worldUpdateProfile, body.walkPerformance.

## Производительность и внешние владельцы — требуется окно

Artist18 01a0bb21-19d8-7640-9946-ad095a16d52c: физgridv5/activities-v1 READY, CPUidleнапоследнемсообщении, docs/ai/NPC_ACTIVITY_AGENDA18_HANDOFF.md. Roadowner01a087f0-fda6-7e13-8baa-1bbd1c5cc26e sourceagenda/atomicdrive ready. Не выдаватьisolatedCPUзаFPS. Lastwarm18 болеераннегобилда: sourceCPU16.5/21.2ms,frameinterval94/112ms (~10FPS),GPU37/53ms,draw2965(1869main1096shadow),tri2.984m. Игравсёещётяжёлая, качества неурезать.

Архитектор-магазины 01a06e4d-e3ed-7f13-bda3-7fd677972336 по прямомуuserrequest подготовил controlledrenderisolation, ждёт LIVE. docs/city-rebuild/RENDER_ISOLATION_20260920.md. Добавить isolationqa=1 втужеURL (однаreload); CtrlShiftF9→Зафиксировать3D→select «Подсистема для замера»→«Проверить выбранную подсистему». 45warmup+121frames baseline/OFF/baseline, каждыйопытвотдельномhold. DOM body.dataset.renderIsolation.last. Modesresolution/shadows/residents/vehicles/interiorsfurniture/pointlights/water. finallyrestore/membershipchangeabort. SourceAI продолжаетработать! Неозначает исключениеCPUпричины. CPUвладельцевсогласоватьidle доэксперимента. Вкладкунепередаватьбезобщегоinventory/согласования. Егоruntimeготов24+3+30tests, GPUнеоткрывал. 18 обещалокнопослебанды, нужнонеигнорировать.

Проверщикчатов01a0b15c-1b67-7711-a726-7298ca2e63a7 руководит5Astrachat, userпроситнесспамить(200смс). Егоработачастичнопараллельнатрава/decor, нестирать. УведомитьID19кратко. Старые17/18 послеhandoffнебудитьнаproduction.

## Финальные наблюдения перед fork19

Последняя reload уже загрузила door pick proxy и усиленный пинок, fear60 и speech above head. Ошибок консоли при предыдущей общей reload0. На финальном скрине чистый HUD, все5бойцов перед героем, новаяформагромилы безраздутыхрукавов. RootV дал«Отряд следует за вами» надминикартой. NPCЭнцоРомано произнёс вDOM«В сейфах обычно интереснее, чем снаружи» — скрин подтверждаетbubble именнонадегорамочкой, НЕцентрэкрана. Звук напрямуюнепрослушан. Плашкипрофессий близкихбойцовперекрываются, улучшениерегулировкивысотывозможнопозже, невыдаватьзаидеал. ПользовательпараллельносменилоружиенаЗолотойКольт15/0. ИграоставленаоткрытойmarkDeliverable.

НовыйArtist19 ID01a0bbea-e50a-71f1-b148-e12196d0c102 появилсявсообщенияхархитектора; ownershipуточнитьпоlist/readthread, покаегоhandoffнерочитан. АрхитекторнашёлhealthHudp5021.8/p9525.7 вArtist19LIVE; этоaggregatehealthSync+playerHud+mercenaryUpdate. Scoped nestedprobe stagesвwalk_previewУЖЕвнесены имПОСЛЕпоследнейreload18, tests11+freeze30PASS, CPUidle/GPU0. docs/city-rebuild/HEALTH_HUD_ATTRIBUTION_20260920.md. НуженfreshNORMAL120frames послеreload(stageupdatesвfreezeнеидут), timings3+aggregate/render/source + mercenaryPicking. 120ms aimпри124msframesидёткаждыйкадр — гипотеза, неготоваяпричина.

Внешний новый robbery worktree agent01a0bbdc-edb1-7cc3-9cda-1160f3bc057b пишет C:/Users/Слава/.codex/worktrees/b60d/Мафиози, ЕГО КОДНЕВSHARED иНЕпроверен18538. ПросилLIVEcashhold/handsup/phone. 18ответилнеподменятьбилды/неоткрыватьGPU, сообщилsharedfear60contract. Необъявлятьегоновуюмеханикузагруженной.

ВАЖНО ПОСЛЕДНЕЕ: Artist19 подтвердилпрямоеuserпоручениеглавныйпоNPC+явноразрешённаяноваяиграуНЕГО. ЧитатьобновлённыйAGENTS и docs/ai/NPC19_TEAM_BOARD.md. Онкоординируетroad/perf/ПроверщикЧАТОВ2 (`01a0bbdc...`) и5Астра; 18стараяинфопроединственнуюGPU теперьисторическая. У18вкладкаостаётся, нельзяслепозакрытьusergame; общийinventory/GPUокносогласоватьсArtist19. ЕгоLIVEpending190–222/288, routecohort+lazyDFScandidateготовится. Не дублироватьегоNPCнавигацию. Нашиmercenarycore/worldscopedhooksпереданы, онпредупреждён.
