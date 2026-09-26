# Перенос Walk → Godot

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

Одна source игра **PID32516**, editor6508, после F6; hotnotes доступны.
Root static render hook:54 independent actual-main PASS, default OFF.
Candidate11 GPU comparison отменён вводом после61 кадров; partial timings
не являются приёмкой. Подробности `S01_STATIC_RENDER_QA.md` и fresh memory.
Native navigation backend357 headless PASS, production host adapter в работе.
Transport70 author PASS/frozen проходит независимые negatives; Area3D-only
support выявлен как gap. Physics121+11 author PASS передан independent reviewer.
Main/NPC/transport LIVE остаются отдельной незавершённой интеграцией.
HEAD локально a9cbd7e (transport author commit); origin/main7afd372d.
Пять авторов и штаб активны. Последующие статусы ниже исторические.

## Update 27 сентября, 00:57MSK

Main/origin verified **7afd372d239066dd988ed12e3270224b8997c9fa**, scoped80files.
Новая единственная editor game29172/редактор6508 после F6 содержит final13e3d83b
и hotnotes Timer2s; экспорт10/PCK smokePASS. Визуальный захват Windows недоступен,
новый loaded-scene FPS не измерен. Hotnotes/mainhook после checkpoint локальные.
Пять авторов и Общий штаб снова работают по явному новому поручению пользователя;
точные scopes/IDs в AGENT_HUB.md. Старое заглушение и PID ниже исторические.

## Текущая шапка — 27 сентября, 00:44 MSK

Актуальная память: `docs/ai/COORDINATOR_21_MEMORY.md`, первый раздел выше истории.
Editor6508 / одна пользовательская игра32648; старые release PID ниже неактуальны.
Source final player13e3d83b: длинный бросок1.25s, восстановление после контакта,
101 independent и3×6489 integration PASS; новую позу ещё обновить в живом окне.
Пользователь подтвердил выделенную кнопку E над дверью и поручил исправить
преждевременный подъём после броска. Export09 подготовлен, новая поза LIVE OPEN.
GPU QA воды07 пройден в малом квартале (p95≈7.12–7.15ms при144cap), не fullcityFPS.
Художник21: staticbatch сдан/root hook впереди; новый scope NPC appearance bridge.
Root subagent: встроенный NavigationServer3D backend; actual source NPC session,
agenda/commerce/server/fullcity остаются OPEN. Lead14 только Проверщик ЧАТОВ1-8.
Штаб заглушён. Обновление игры — один экземпляр, не параллельные GPU-прогоны.

## Актуальное распределение — 26 сентября, чистый Координатор21

Текущий LIVE после последовательных обновлений: **release06 PID12540,
session49876**, `exports/win64/s01-20260926-camera-notes06`.
Обычный прыжок/landing, типографияE и физическийвход, свободнаямышь/колесо,
списокобновленийсправа показаны вновомviewport. Root50camera/42interior/
298airborneheadlessPASS; полноесравнимоеLIVEFPS и interiorvisualещёOPEN.
Freshmemory `docs/ai/COORDINATOR_21_MEMORY.md` важнее старыхPIDниже.

**Координатор21** `01a0df60-f834-7e23-a846-00b47c48e0cc` — чистый преемник20,
общий каталог, интеграция/main/project/LIVE/Git. Сначала
`docs/ai/COORDINATOR_21_START.md`, затем `COORDINATOR_21_HANDOFF.md`;
fork `01a0df5c-6cff-7341-a3a5-b7f8b3d00f31` завершил передачу.
**Проверщик ЧАТОВ 1-8** `01a0bbdc-edb1-7cc3-9cda-1160f3bc057b` управляет всеми
14Astra: следующие независимые задания, полные пакеты, контроль приёмки.
**Художник21** сдал perf recorder+async JSON; следующий exclusive scope — water material factory;
рассылку Astra больше не ведёт. Его прежний dispatcher heartbeat PAUSED.
Root20 завершил передачу. Airborne sampler сдан, интеграция player/locomotion
у субагента чистого21; interior ещё у прежнего автора до финальной сдачи.
База main/origin ff717ebf20293620e500b54d2deb30f4a940a6f9.
Один release PID43332 и exec9305 не закрывать. Сохранение в GitHub раз в час.

Ниже история этапа, старые роли и PID не являются текущим назначением.

Текущий показ: **Forward+**, настоящие материалы поверхности и походка героя.
Один видимый standalone release PID **43332**, пакет `s01-20260926-review02`.
Debug PID48888 неожиданно завершился; причина открыта. Новая shell-сессия9305
ожидает release и сохраняет exit code — не останавливать её. Подробности ниже.
Живые результаты и ограничения: [S01_MOTION_LIVE_20260926.md](S01_MOTION_LIVE_20260926.md),
[сравнение рендеров](S01_RENDERER_COMPARISON_20260926.md).
Пользователь просит сохранять показ открытым. При необходимом обновлении сначала
готовить сборку/команду запуска, затем кратко перезапускать ровно свой экземпляр
и сразу возвращать окно; не оставлять его закрытым по окончании проверки.

26 сентября 2026. Новый приоритет пользователя: полный перенос Walk, поэтапные живые прогоны, видимая сцена Godot. Всего **14 Astra** (уточнение пользователя). Более позднее распределение: **Художник21 управляет всеми14Astra; Координатор20 и его субагенты непосредственно переносят игру.**

## Владельцы

- Координатор20 `01a0bc08-cb3e-7181-be11-a53aaee54535`: Godotproject/main scene, интеграция, одна запущенная игра, LIVE/performance gates.
- Художник21 `01a0cb2d-a8ab-78e1-ba8e-3ef7915a2d71`: постановка и приёмка всех14Astra, следующие независимые задачи, пакетыroot. Не менять общие runtimeфайлы без согласования.
- root/godot_city_import: exporter+assets/data block, done/checking.
- root/godot_player_preview: preview_player.gd, controller+camera, testing.
- root/godot_s00_inventory: baseline/source/WIPcapture, independentaudit.

## Правило этапов

Исходный Walk сохраняется. HEAD3612fa6, serviceWorld9f5/Walk e80 WIP. ПолнаясводкаАстра10 сохранена в ASTRA10_PLAN_SUMMARY_20260924.md; полныйтекст16этапов36проверок запрошен, не считатьуже прочитанным. Godot4.7.2-stable проверен по https://godotengine.org/download/archive/4.7.2-stable/ .

Текущий наглядныйпроект `godot/mafiozi_walk` — квартал исходныхресурсов, не принятый переносмеханик.8зданий+8фонарей+hero, originprintshop. Консервативныеexteriorколлизии пока не интерьеры. Сцена1280×720 Compatibility дляпервого запуска; это не итоговыйбенчмарк1080p/финальныйrenderprofile.

Приёмка каждогоэтапа: исходныеидентичности/механики→тесты→живойпрогон→профильframep50/p95/p99/spikes/память→исправление→повтор→checkpoint. НельзяобещатьнольлаговилипринятьпустойкварталпоFPS. Hardware i9-10900F,GTX980≈4GB, RAM17113399296bytes. Цели60fps1080p,p95≤16.7ms,p99≤25ms,repeatspike>50ms—предварительны,неизмеренныйрезультат.

## Astra: передача Художнику21

Все 14 поручений доставлены, что Художник 21 подтвердил 26 сентября.
Единственный актуальный список назначений и приёмки —
[astra21_DISPATCH_20260926.md](astra21_DISPATCH_20260926.md).
Root не дублирует рассылку. Доставка задания не означает готовый или принятый
результат. Частично полученный текст плана содержит все поля этапов S00–S15:
[astra21_ASTRA10_RECEIVED_PARTIAL.md](astra21_ASTRA10_RECEIVED_PARTIAL.md).
Оставшиеся gate JSON и 36 проверок ещё запрошены.


## Незавершённые старые исправления

Hospital outputs/MERCENARY_HOSPITAL_RETURN26_PROPOSAL.md:22CPUcases,patch9382243e,NOTapplied,servicecheckpointdependency. Gun outputs/VEHICLE_READY26_FOCUSED_HANDOFF.md:Easton12endpoints clean,enterframe/KingswellcollisionHOLD;patch193a2c42NOTapply. Сохранитькакregressions,неинтегрироватьавтоматом.

## Постоянная работа

Активная цель создана на полный перенос и14Astra. Автоматизация `walk-godot-14` активна ежечасно; её промпт обновлён: Художник21 руководит Astra, root переносит игру. Прежняя `npc` оказалась удалена. Никаких новых координаторов или игровых вкладок.

## Первый живой показ, 26 сентября

Godot4.7.2 запущен в отдельном видимом окне «Мафиози — перенос в Godot (DEBUG)».
Текущий PID41772, предыдущие15960/36308 остановлены при последовательном обновлении.
Запуск: `tools/godot/launch_preview.ps1` не создаёт второй экземпляр этого проекта.
Настоящий viewport сохранён в `outputs/godot_preview_materials_20260926.png`.
Визуально подтверждены здания, фонари, исходные цвета героя и правильный вид со спины.
Исправлен потерянный флаг vertex colors у 7 поверхностей героя. Предыдущее
утверждение об устранении пересвета одной настройкой Filmic было ошибочным:
повторная проверка и кадр пользователя показали полностью белый тротуар.
Геометрия,8338 исходных линейных цветов и PBR сохранены; тест материалов и16 проверок
движения/камеры проходят. Весь gameplay, анимации и полноценные интерьеры ещё открыты.

Неподвижный debug квартал1280×720:144FPS,p95delta≈6.9ms,≈1016drawcalls/188168primitives.
Это предварительная render-only телеметрия, не экспорт приложения/городской gameplay FPS.
Windows capture недоступен(SetIsBorderRequired0x80004002); кадр получен собственной
диагностикой игрового viewport, без захвата других приложений.

Художник21 подтвердил все14 поручений: первоначальные loadtimeouts преодолены
повторной доставкой; точные receipts в `astra21_DISPATCH_20260926.md`.
Доставка не означает приёмку результатов. Не дублировать root-реализации и
рассылку. Полный план10 ещё ожидается.
