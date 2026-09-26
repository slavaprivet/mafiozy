# Координатор21 — актуальная память

## Update 27 сентября, 02:35 MSK — compact14b, moving exit LIVE

Единственная интерактивная source игра PID45824, editor6508. Revision s01-20260927-compact14b. Actual GPU QA native01 выполнял настоящие E/W input events, посадку, разгон, выход и перекат; report passed=true, failures=[], stable_hashes=true, restored_interactive=true. Все четыре viewport PNG просмотрены. SpringArm исключает свой кузов: spring hit4.8m во всех фазах, приближение к голове устранено. Реальная середина переката видна, машина продолжает движение. Поза сохраняет исходный source tumble, контакт/перемещение проверяет physics host; это не full ragdoll.

Frame time ms: pre p50/p95 6.973/8.053, roll6.939/11.143, post6.965/7.749; roll pose CPU p50/p953.126/3.585ms. PNG readback frames исключены. Это короткий тест одного квартала/одной машины, не производительность полного города. Evidence outputs/coordinator21_vehicle_liveqa/native01/report.json и seated/mid-release/mid-tumble/settled.png.

После GPU исправлены два видимых дефекта: stale BLOCKED hint очищается при resumed ACTIVE; компактная правая плашка имеет minimum width280 вместо сброса в полоску. Final outputs/compact14b_live.png просмотрен: обе плашки компактны и читаемы, E выделена. Capture p957.8ms/144FPS после прогрева, не сравнение fullworld. Export exports/win64/s01-20260927-compact14b: build receipt unchanged inputs, PCK smoke PASS main/transport/interior/water/dive. Source physics остается EXACT a382537914fe9494b72c042a35d9ba76948ab90fb79397e05767dd9d7ca59401. Candidate873/coast/wall/handbrake отдельно, НЕ production acceptance; текущий газ+ручник известный pending дефект. Не stage candidate tests как проверенные production.

NPC host c8f3019a готов отдельно73actual-mainPASS, НЕ подключён main. Его CPU p95~1.17ms/3moving, выброс6.661ms, cold34ms/actor. Cargo319 pure geometry admission готов отдельно, реальные предметы/authority/visible cargo НЕ подключены. Полная миграция остается ACTIVE; cloud/Astra assignments paused до reset по user/lead, локальные авторы продолжают. Исторические статусы ниже.


## Update 27 сентября, 02:15 MSK — vehicle13 LIVE

Единственная source игра PID10376, окно15861446; editor6508. Старые PID2080/32516 закрыты пользователем; свежий inventory подтвердил отсутствие перед запуском13. Source `s01-20260927-vehicle13` с hotnotes. Capture outputs/vehicle13_live.png просмотрен: герой/машина/E/актуальные5пунктов и явно временная граница видны. Короткий статический LIVE144cap, p95~7.85–7.89ms,669drawcalls; это НЕ сравнительный benchmark/выходс перекатом/fullcity. PCK13 smoke PASS включая transport ready.

Реальный пользовательский дефект12: машина выехала за cropedge x43.05 и упала; герой завис снаружи. Причины: seated move_and_collide цеплялся за мир; main автоматически телепортировал actor y<-12 на старт и выдавал on_foot, оставляя occupied seat. Исправлено: full6DOF seat attachment с временным0/0collisionfilters только SEATED/EXIT_HOLD; точное восстановление до физического EXIT; upright независимая камера. Main больше не телепортирует: y<-25 => local preview death, герой остаётся в падающей машине, E/W заблокированы, R reload новый session. Временная видимая ограда по реальным cropbounds; исходный floor/вода не подменены. Это локальная previewdeath, server HP/save ещё не перенесены.

Root independent: 141 all4roll/fall/collider +29 blocked +9coast PASS; deepfall17PASS actual process crosses−12 and−25 no teleport; fast exit20PASS actual appliedtumble101samples, thighfold1.9rad, quaternionmax3.10694, carcoasts8.6144m. Freezeподробности outputs/coordinator21_transport_scene_review/*REVIEW.md. Root cycle14PASS current13. Физика steering a3825379 исправляет A/D/колёса; native127+independent26+8signedchecks, actualmain Aleft/Dright. Boundary unit47PASS, actualgravityeast дополнительный ownerreceipt ожидается.

Transport rev6 manifest ca32e094,19files,137independentPASS: единый timing1.2s по прямому пользовательскому изменению (исторические2.6s отменены), EXIT support-aware floor correction<=5cm с сохранением actualfrom_m, movingexit tumble>15km/h. Root убрал autoBrake после начала выхода; машина катится физикой и после освобождения driver. Pure exitpose source1afafedf:4409PASS,72frames; CPU p50/p95 2.986/3.457ms +floorphysicscalls, фактический LIVEFPS во время переката ЕЩЁ НЕ ПРОВЕРЕН. Root routes exit_body (раньше flatpose безfold терялась).

Visual13 actual factory rawGLBs сохранены .bytes, rawmanifest source10133bb9, productiongeometry exact31,394PASS /4,460,817corners. Source independent28,699PASS. Occupant7b82de39 source3371+rotated125PASS; root smoothgrip устранил скачок ладони27cm до.19mm, currenthinge/wheel updated before singleposewriter, approachgait иheadinghandoff. Капот/багажник nativecompartments99ee5fcd+data423c09c2:11793native/274sourcePASS на13профилях, engine49parts exposed; rootEnearfront/rear, speed/roll/onfootgates, autoclose>2.5m/s. Не путать geometry contains_item с inventory! Genericnativecargo/importedbankbags/questboxes transfer/visibleitems ЕЩЁ НЕ ПОДКЛЮЧЕНЫ; user прямо просит реальныевидимые предметы, docs/godot/VEHICLE_COMPARTMENTS_SOURCE_HANDOFF.md.

Полный перенос остаётся ACTIVE. Пользователь также Artist21 поручил входы/бордюры (Traversal уведомлён) и просит реальных NPC сейчас. Artist21 frozenpendingprovider017d46e6, correctedsourcepacket e926... проходитactualsource151/provider46PASS; НЕ использовать rejected384f. Preparedsessioncache precisionfix в работе уArtist. Rootagent migration_next_package делает эксклюзивный preview_resident_host.gd на existing NavigationHost/realplacement/cache/IDs; main ещёнеподключён. Imported saves/authority/commerce/AIagenda/fullworld не объявлятьготовыми. Пять авторов +14Astraчерезlead+штаб работают; batch20QA refs неruntimeacceptance.

Часовой Git checkpoint готовится scoped native13; чужой Walk/backend WIP не stage/reset/stash. Предыдущий origin7afd372d, локальныйbase a9cbd7e. Последующие исторические записи ниже.

## Update 27 сентября, около 01:16 MSK

Пользователь: «ок. делай. не мешаю». Пять авторов продолжают брать пакеты
из действующего штаба; старый запрет на сообщения в штаб отменён.

Текущая единственная видимая игра снова из редактора: **PID32516**, parent6508,
`--scene res://scenes/main.tscn`, окно2688712. Редактор6508 / окно2754302.
После QA закрыта только standalone игра41156; fresh inventory подтвердил её
отсутствие, затем F6 запустил source scene. Hotnotes source Timer2s доступен.
Windows screenshots всё ещё недоступны; не объявлять новую визуальную проверку.

Root static batching hook реализован, **default OFF**. Независимый actual-main
review54 PASS: 69 groups /248 instances, сохранены source nodes/IDs/resources,
коллизии и работа двери. `S01_STATIC_BATCH_MAIN_REVIEW.md` содержит границы.
Candidate11 экспортирован. Настоящий GPU OFF/ON/ON/OFF прогон отменён вводом
на первом OFF окне после61 кадров; report `outputs/static_render_qa11/report.json`
имеет cancelled/input_seen/interactive_restored=true. Частичные FPS недействительны,
PNG/readback/сравнение не выполнены. Не включать batching до новой приёмки.

Native NavigationServer3D backend завершён:357 actual headless PASS, реальные
коллизии квартала и физический проход через типографию. Фоновый bake p50
1244→262ms — НЕ FPS. Handoff `PREVIEW_ENGINE_NAVIGATION_HANDOFF.md`.
Child migration_next_package делает production host adapter существующей main
геометрии, без fake NPC/permissions; trusted roster provider у Художника21.

Transport3 самостоятельно сделал локальный scoped commit **a9cbd7e009e44e0224855482809597b0a6512396**
(17 transport files), он теперь HEAD; origin/main по-прежнему **7afd372d**.
Root запретил автору дальнейшие Git mutations, историю не переписывал.
Новый uncommitted frozen manifest c968fe46… содержит70 author PASS и fixes;
independent review нашёл Area3D sensor, ошибочно допускаемый как опора.
Автор исправляет. Старый position_m failure относится к предыдущему snapshot;
актуальный runtime test98687ce5… независимо9/9 PASS. Main integration HOLD.

Physics12-13 сдал native body121 +scaling11 author PASS; perf_acceptance проверяет
независимо source/impulses/lifetime. Main/LIVE ещё не подключены. Художнику21
разрешён NPC-only FLOAT32 COLOR/CUSTOM0 seam как выключенный кандидат: source
HDR clamp и KHR material equivalence остаются GPU HOLD, допуски не расширять.
Следующий hourly Git checkpoint около01:54; только проверенные scoped изменения.

## Update около00:57MSK

Опубликован scoped80files checkpoint **7afd372d239066dd988ed12e3270224b8997c9fa**;
push/ls-remote совпали, index пуст. Чужие Walk/server WIP не включены.
Последующие изменения ниже пока локальные до следующего hourly checkpoint.

Root подключил preview_update_panel.gd (21headlessPASS) вместо staticbuilder.
Native Timer2s/stat-only; bounded16KiB/5items; ошибки сохраняют lastvalid;
runtime_revision mismatch показывает restartnotice без новых неподгруженных
механик. Source main/JSONrevision `s01-20260927-landing-notes10`, titleпроисправление
подъёма после броска, E и hotnotes. Экспорт10/PCKheadlesssmokePASS.

После нового прямого поручения обновлять данные пользовательская сцена обновлена
через существующий editor F6. Новый единственный GPUgame **PID29172**, start00:56:35,
editor6508, Responding=true. Загружен source10/finalplayer13e3d83b. Native screenshot
Windows не получен: SetIsBorderRequired0x80004002. Не объявлять visual/FPS finalfix
проверенным screenshot; предыдущие пользовательскиекадры E/квартала есть.
User earlier Escape остановил только ту попытку UI; новый restart по свежемупоручению.

Три новые tasks активны по wait_threads; heartbeat10min создан каждому:
godot→Transport3, godot-2→Physics12-13, godot-3→Traversal.
Artist heartbeat21-14-astra обновлён наNPCvisual; roothourlywalk-godot-14 на5owners.
Штаб снова активен по прямому поручению, получил свежий batch01..10 index и
checkpoint; пакеты маршрутизируются одному владельцу, безACKциклов.

Physics12-13 предупредил о промежуточных ParseError в своём vehicle_native_body.gd,
пойманных живым editor. Автор исправляет; main ещё не импортирует этот WIP.
Не менять его файлы. Попросил публиковать .gd вproject только после isolatedparse.
Native navigation actual async bake+agent/body переход publicdoor PASS уrootchild;
negative/lifecycle проверки ещё продолжаются. Staticbatch root hook ещёOPEN.

## Новое поручение пользователя около00:50MSK

Добавлены к внедрению существующие закреплённые3/4/5: Transport3 (logicaltransport),
ФизикаАвтомобилей12-13 (nativephysics), Добавитьпрыжокиперелезание (nativetraversal).
Итого5 внедряющих сroot/Artist21. Прямые задания доставлены; Transport3 подтвердилстарт.
Пользователь ВЕРНУЛ общий штаб: Проверщик публикует там пакеты, все5 ихвнедряют.
Это отменяетзаглушение в старомразделениже. Канонические IDs/границы AGENT_HUB.md.
Новый запрос: постояннообновлять «Чтонового». /root/perf_acceptance делает новый
preview_update_panel.gd с Timer2s/stat, boundedJSON, revisionguard; main/data уroot.

## Актуально 27 сентября, 00:44 MSK — выше исторических записей ниже

Предыдущий turn дал progress: отдельная светлая клавиша E над реальной дверью,
45 проверок взаимодействия PASS и пользователь подтвердил «я проверил все ок».
Пользователь остановил Computer Use физическим Escape; управление окнами не
продолжать без нового основания. Он затем подтвердил замеченное выпрямление после
броска и прямо поручил исправить. Штаб по-прежнему заглушён; туда не писать.

Текущий свежий inventory: editor Godot4.7.2 PID6508, единственная игра из редактора
PID32648 (`--editor-pid 6508`). Release06/07 старые PID больше не актуальны.
Проект зарегистрирован в `%APPDATA%/Godot/projects.cfg`; новый helper
`tools/godot/register_project.gd` сохраняет другие записи. Editor autosave убрал
явные default settings: фактический renderer Forward+, physics60 сохраняются.

Готовый runtime: free mouse/wheel, источник прыжка/позы, удлинённый бросок Max Payne
1.25s до приземления / .45s восстановление после контакта, типография с физическими
дверями и интерьером, brick/concrete source finishes, волны/глубина воды, старт у
publicApproach, список изменений справа и floating `[E] Открыть/Закрыть дверь`.
Обычный прыжок .8s/1.05m сохранён. Source IDs/данные карты не менялись ради спавна.

Final player SHA13e3d83baa7648be5040bde64d1b899404bc2d7984aed22afe8b02b0c9b4db57:
исправлено зависание над полом при перепаде <2cm и один кадр стоячей позы до
физического контакта. Добавлена проверка overlap конечной точки permission capsule
.36m для тонких стен; body .30m не менялся. Три integration runs по6489 PASS,
independent101 PASS (все8 premature_recovery пусты), actual-main2 прыжка PASS.
Root legacy player PASS / обычный airborne231 PASS. Это CPU, не LIVE/FPS новой позы.

Export09 `exports/win64/s01-20260927-landing-fix09` содержит final13e3d83b и новую E.
Export08 содержал предыдущий e2a742 и НЕ окончательный pose fix. Export07 содержал
старый короткий бросок; его GPU-прогон нельзя выдавать за новый длинный бросок.
Открытая игра32648 запущена раньше final13e3d83b, обновление ещё требуется.

Настоящий native GPU QA воды07: OFF/ON/ON/OFF,1280x720,Forward+,GTX980,144fps cap,
600 кадров/окно после прогрева, p50 примерно6.94ms/p95 7.12–7.15ms,1507draw calls.
Примитивы235423→232393. Кадры воды/полёта/interior просмотрены, ошибок shaders нет.
Это квартал без NPC/машин под cap, не полный город и не доказательство ускорения.
Evidence `outputs/water_render_qa_07/report.json`; новый motion harness
`tools/godot/preview_motion_perf.gd` готов для единственного согласованного окна.

Текущие владельцы:
- Root: main/project/export, Git, одна игра, дальнейшая интеграция static batching.
- Художник21 сдал static helper53618a28:71+130+172452 CPU checks; runtime ещё не
  подключён, оценка179surface submissions не фактические GPU draw calls. Новое
  назначение — source NPC appearance/model bridge scripts/npc_visual, без births.
- /root/migration_next_package: native NavigationServer3D backend actual crop +
  printshop107 bodies; async bake/query lifecycle, version fences, physical admission.
  Main/реальные NPC ещё не подключены. Source reference planner/index10977 PASS
  остаётся отдельным пакетом, не заменяет встроенную навигацию новой ветки.
- /root/perf_acceptance и /root/airborne_integration завершили final player13e3d83b.
- Проверщик ЧАТОВ1-8 единственный lead14; batch08/09 сохранены в outputs/коллектор.

Открытые fidelity находки: A6 Godot не переносит source KHR_ior/specular у4hero
материалов; analytic F0 не доказательство pixel/BRDF parity, скаляр наугад не ставить.
Два source PointLights типографии также OPEN (near-distance attenuation mismatch).
A13 cash=0 mirror, concurrent robbery pending slot, conditional ID truncation —
source defects для отдельного владельца, не считать проверенной миграцией/backend.
NPC session authority/roster/agenda/commerce/save/полный город остаются OPEN.

Hourly scoped checkpoint готовится сейчас; предыдущий verified remote0c08e01e...
Не добавлять чужие Walk/server WIP или outputs. Старые ссылки/PID ниже — история.

26 сентября 2026. Чистая задача `01a0df60-f834-7e23-a846-00b47c48e0cc`.
Предыдущий goal turn дал реальный progress: perf подключён и проверен,
scoped checkpoint `0c08e01e844ca3ae88f9dacd02e49cad45104170` опубликован,
remote main сверён. Полный перенос не завершён.

## Последние прямые указания

- Продолжать полный перенос игры и сразу оптимизировать каждый пакет.
- Регулярно обновлять единственную видимую сцену готовыми изменениями:
  подготовить сборку, один последовательный restart, оставить игру открытой.
- Справа сверху список «Что нового и что попробовать», пункты 1/2/3.
  Root добавил `data/preview_updates.json` и панель в main; следующий экспорт.
- Мышь без ПКМ вращает камеру, колесо приближает/отдаляет. Root внедряет;
  независимый camera input test у airborne_integration.
- Макс Пейн обязателен. В source поздние параметры speed4.2/max3.36/apex.42,
  flight.8/recovery.45/secondSpace≤500ms; текущий release содержит обычный прыжок.
- Общий штаб пользователь заглушил ради токенов: больше туда не писать/не будить.
  Художник и Проверщик уведомлены; роли остаются прежними.

## Текущая живая игра

UPDATE около20:49UTC: единственная игра теперь **PID12540**, release
`s01-20260926-camera-notes06`, **session49876** не terminate.
Предыдущий2868 завершился сам/пользователем в20:46:51 с exitCode0;
причина не установлена. Root перед заменой подтвердил отсутствие процесса
и всех остальных release, запустил только новый06. Live viewport
`outputs/godot_release06_live.png` просмотрен: правильная панель сверху справа
с пунктами1–4, новая строка управления, герой/квартал видимы. Responding=true.
В06 свободная мышь/колесо3..16/EscTabClick и numberednotes. Независимый50checks
PASS, затем rootrerun50PASS, exportedPCK main/printshop/airbornePASS,38entries.
ФизическийOScapture/feel userinput не объявлен rootLIVEтестом.
Ниже прежний05 как история.

**PID2868**, release `godot/mafiozi_walk/exports/win64/s01-20260926-jump-interior05/`.
Lifetime shell **session67057**, не terminate. Старый43332 завершён корректным
CloseMainWindow по прямому указанию обновить сцену. Запущен только один visible
экземпляр, Responding=true. `outputs/godot_release05_lifetime.json`.
Root просмотрел фактический viewport `outputs/godot_release05_live.png`:
новый HUD «Типография открывается через E», герой и исходный квартал.
В этом release уже обычный airborne+printshop, но ещё НЕТ новой camera/notes/water.
Screenshot малой сцены не полноценная визуальная/перфприёмка интерьера/походки.

## Принятый код и доказательства

- Perf core48/async77/independent56 headless PASS, mainhook18OFF/18ON PASS.
- Airborne integration root независимо298checks/4physicscycles PASS,
  owned_pose CPU66/130µs p50/p95; full author4000×8338 skinPASS.
- Printshop main root независимо42headlessPASS: actualE, physical вход/выход,
  obstruction, exact24unmodifiedold +111newbodies. Admission5reject+valid PASS.
- Export05: 37PCK entries; все9runtime script payloads,6GLBimports,2JSON.
  Source selectedinputs unchanged. Actual exportedPCK admission PASS через
  console engine --main-pack: mainready, printshopready, airbornebound.
- Release templates здесь ИГНОРИРУЮТ внешний --script: два headlessprobe
  запустилиdefaultmain и не завершились, точечноостановлены поPID+path+headless.
  Не выдавать consoleengine --main-pack тест за executionreleaseEXE или егоFPS.
- Native OFF/ON/ON/OFF harness готовится у airborneagent; 4windows20checks
  protocolselftest PASS, GPU/LIVE overhead ещё OPEN.
- PathJobQueue: author7075checks/11375exactsourceoperations PASS; rootreview
  и mainNPCintegration ещё OPEN. SourceWIPworld.html неизменён, некоммититьего.
- Water material root47headlessPASS, factory exactsource shader; GPUcompiler
  и renderedparity ещё OPEN. Автор делает actualdepth/geometryhost.

## Владение

- Root: main/project/export/UI/camera controls/Git/LIVE.
- Художник21: preview_water_surface + exporter/data/tests; factory сдан.
- /root/perf_acceptance: теперь MaxPayne purepose/semantics+hostcontract,
  main/interior scope освобождён.
- /root/airborne_integration: camera tests + perf protocol doc correction,
  production player/locomotion уже освобождены.
- /root/migration_next_package: NPC first vertical slice source contract,
  queue runtime scope освобождён.
- Проверщик ЧАТОВ1-8 единственный lead14Astra. A8review очереди, не второйавтор.

## Экспорт и следующие шаги

Preset resources selected явно включает main и все literal runtime scripts,
а также GLB, которые main загружает из JSON: Godot не включил GDScript preloads
автоматически при первоначальном selected export03. Он НЕ показан пользователю.
Export04 прерван receiptcheck из-за независимого WIPnavigation изменения.
Exporter теперь хэширует только выбранные inputs и explicitJSON filters;
сохраняет unchangedgate. Добавлена проверка code/data/importpayload в PCK.
`launch_preview.ps1 -CheckOnly` распознаёт release, не создаётдубликат.
Новыеcamera/notes и прочие пакеты пока localWIP, следующий пользовательскийпоказ
после cameraheadless+сборки+проверки. Git обычно раз в час;0c08e01 был внеочередной
checkpoint по прямому поручению пользователя через20. Не add-all/reset/stash.
