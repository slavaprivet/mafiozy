# Координатор 17 — передача от 16, 13 сентября 2026

Пользователь прямо попросил: «создавай кординатор 17 продолжишь задачу там». Продолжать в общем рабочем каталоге C:/Users/Слава/Desktop/Мафиози. Все текущие изменения незакоммичены и разделены между активными авторами. Не reset/checkout/clean/commit. Не начинать реализацию заново. Прочитать COORDINATOR_16_MEMORY.md и MERCENARY_SQUAD_20260912.md; эта передача уточняет поздние изменения и открытые проблемы.

## Последние прямые требования пользователя
- Наёмники 5 профессий, E разговор/найм, личное имя/скин/обычный личный пистолет. В мирное время пустые руки, оружие достают только для боя; гражданские вообще без стволов. Protected police/guards/bosses/gangs сохраняются.
- Плашка только у NPC, на которого направлена камера, до12м: Наёмник + профессия в ОДНОЙ рамке, E сверху при допустимой дистанции3м. Отвёл камеру — исчезает сразу. Не перекрывать HUD/карту, не липнуть к краям. Ближний круг — тонкий латунный Art Deco double ring/4акцента.
- Свой отряд зелёный. Миникарта ТОЛЬКО толстые зелёные точки; на большой M карте hover показывает имя/профессию/статус/Ваш отряд.
- TAB скрывает/показывает большую левую панель. Имена боссов/бойцов увеличены12px, карточки96px, портрет60px и имя отдельно ниже на тёмном фоне.
- Нажатие своего бойца слева → персональная карточка навыки/прокачка/реальный инвентарь/смена оружия/увольнение.
- V объект под камерой подсвечивается, действия по имеющимся профессиям: авто подрыв/взлом запертого, сейф вскрытие, ограда резка. Боец подходит/анимация/реальный эффект. Повторное V отменяет незавершённый приказ; установленный заряд/awaiting транзакция не отменяются.
- X ставит точку сбора, бойцы занимают раздельные физические места. Жёлто-золотой красивый маяк плавно исчезает за3сек, сам приказ остаётся. Кнопка Следовать за мной возвращает строй.
- Больница300сек и заметное уведомление/таймер HUD. Автооборона когда атаковали, после боя прекращают и возвращаются к приказу.
- Пользователь разрешил и попросил агентов. Три subagent16 mercenary_core/pose/ui завершили scoped работы; в новой задаче создать новых при необходимости, не будить старых координаторов.

## Что реализовано и проверено
Модули assets/maps/city_rebuild_v1/mercenary_*; root integration walk_preview/world.html/HUD. Source world41testsPASS, adapter/targets/vehicle locks/selection/HUD/UI/badgesPASS. Последний badges13PASS (aimOnly true default, distance12), UI9PASS. Общего FPS acceptance нет.
- mercenary_world: source-owned метрическое follow вместо legacy4.25тайла (~17м); rally/follow/cancelCommand/isDefending API. Живые бойцы ходят по отдельным местам ≥2.1м, collision step, не телепорт. Оборона реальной тревогой6с отдаёт existing gangAI, затем follow/rally. world guard mercenaryMeleePursuit расширен isDefending.
- Препятствия пока локальный обход, не полноценный глобальный поиск пути: замкнутый блок безопасно останавливает.
- Личная own/issued gun source/inventory сохраняется, render weapon:'none' вмирное время. Старые кандидаты в бою не теряют профессию; leakpistol очищается убывших ordinarycitizens. Artist16 дополнительно внедрил npc_civilian_weapon_policy inlineworld+population (21PASS), обычные гражданские рукопашные, protectedroles сохранены.
- Сохранение: после первого LIVEreload исчезли3бойца. Исправлены late-local restore-before-save, legacy _gang_X remap поsourceBotId, запрет overwriteпустым при corrupt/incomplete save. Конкретный первыйкореньнеустановлен. НОВЫЙ LIVE найм Елена Конти merc_resident_33 сохранён и послеreload восстановлен точно: DOM mercenaryPersistence storedIds/ids merc_resident_33. Не воссоздавалиутраченных поимени.
- LIVE собственнымиUIдействиями подтверждены Eдиалог+наймЕлены иTAB. Userскриншот подтвердил X маяк/назначение1бойца и прибывшуюЕлену рядом. Полныйбой/больница/сейф/C4 live acceptance всёещёнепройден.
- Парковочные CARS новый mercenary_vehicle_locks.js real source _lockpicked=true после safecracker action/дистанции/целостности, безугона/собственности. Sourcehijack учитывает _lockpicked. Nativefleet толькоsourceVehicleIdbound проверяетзамокприentry; unboundartistfleet/сервер/police невыдумываются. Coreunlock_door vehicle5сек.
- selectionview ArtDeco beacon2draw, 3секfade. Root ПЕРЕНЁС selection.update вupdatePresentation(rawDt), чтобыобщийdt.04 нерастягивал3сек. Badgeprojectionтамжепослекамеры.
- Hoverpicking был15ms last/max35.7ms LIVE. RootподключилgetPickRoots → existing shotObstacles(origin,direction,Infinity)+NPCroots; raycast_root_index поддерживаетInfinity. Стены/машины/люди сохранены. Новыйsame-sceneпослепрогонаещёнезамерен. DOM mercenaryPicking lastMs/maxMs/samples (4Гцприmembers>0).

## ОСТАВШИЙСЯ БЛОКЕР ЛИЧНОЙ КАРТОЧКИ
Клик по Елене влевойпанели вLIVE НЕпоказалpersonalUI. Вкоде hookcontroller openMercenaryMember ДОlock; adapteropenMember нормализует IDs и открывает UI.openMember(actualId); тестыPASS. НО tools locator.click/pressSpace сообщаютуспех, аобработчикcard click НЕставитсвоидиагностики. ВозможнапроблемадоставкивводавCUA, не надоисправлятьвслепуюкод.
Последняявременнаядиагностикаоставлена:
- walk_player_hud host.dataset.hudRevision='mercenary-click-20260913' — LIVEподтвердилновыйкодзагружен.
- hostcapture pointerdown/pointerup/click пишетhost.dataset.lastPointer. Послеtoolclick НЕпоявился.
- buttonlistener node.dataset.lastAction — НЕпоявился.
- controller body.dataset.walkHudLastAction — НЕпоявился.
- adapter documentElement.dataset.mercenaryMemberOpen {id,key,reason,ok} — НЕпоявился.
- DOMelementFromPoint центраcard возвращаетеёIMG, никакихперекрытий; buttonнеdisabled, hostavailabletrue. Значиттекущийнаблюдаемыйclickнедоходитдосамогоhost. НеобъявлятьготовымLIVE.
SourcePvPmodalbuttonclick иEнаймработали. TABработает. Spaceнаbuttonможетперехватыватьсяобщимwalkjump; Enterопенитchat, текстнеотправляли. Вscriptglobalcaptureblock естьтолькоrender_freeze_qa active, ноработающийTAB делаетегомаловероятным.
Rootдобавилзапретgenericgangfallbackдляизвестногоmercenaryприотказеopen иshowNotice; текущаяпричинаunknown. Когдаразберёшься—уберивременныеpointer/revisionдиагностики.

## Браузер и GPU — срочно согласовать
Root CUA последнийbinding latestDemo16 tab4 browser iab, URL http://127.0.0.1:18538/world.html?direct=1&previewcity=1&render=3d&renderer=walk&weapon=pistol&cash=5000&mercenarydemo=1 . markDeliverable. Старыйtab3исчезизsession, inventoryбылtabs[], поэтомувосстановилиОДИНtab4. Неоткрыватьдублислепо. ПривязкиREPL17непереносятся.
Вновойзагрузке modeModal иногдаДЕЙСТВИТЕЛЬНОdisplayflexблокируетHUD, проверитьDOMrect/display преждеclick #modeOptPvp. AXчастопоказываетскрытуюsourceразметку. WorldrendererвShadowRoot#mafiozi-walk-host; HUD/mercenaryUIснаружиbody. BrowserDOMevaluateтолькоread-only DOM, неgameglobals/mutation. АрсеналвShadowRoot getByRoleне находил; Q + ShiftTab2 + Space убралооружие. Enterперехватилсяchat,Escapeзакрыл.
КРИТИЧНО: hiddenIABвсёравноdocument.hidden=false ирендерит. Прямоеuserapprovalвoptimizer13сент: «Да, оставить одну игровую вкладку» разрешаетзакрытьлишниеuserdemoна времяFPSпроверки, оставивтекущую. Rootвыбралtab4; Artist16затемсообщилчтоегоtab3npctransportqa/perfqaтожеuserambient. НЕзакрытьобе! НовыйкоординаторсогласуетОДНУ. IDsлокальныдлясессии! Coverполучилпоручениезакрытьownuserdemo2, ArtistзакрытьownQA; ожидатьподтверждений. Optimizerсвоихtabs[] неоткрывает.
ДляprofileoptimizerпроситкоставляемойURLдобавитьperfqa=1&vehicleshadowcull=1. Снять documentElementworldUpdateMs/worldUpdateMaxMs/worldSimulationFps, shadow/bodywalkPerformance,npcWorld,explorationRuntime,renderFreeze,vehicleShadowCulling. normal120frames; затемholdUI, shadows off120/on120сравнимыеполныекадрыpending0 иholdactive. interval.mean-frame.mean НЕworldCPU, maxstickyнеp95. Применитьsourceexceptionfixпередзамером.
OptimizerпоследнеенашёлпоArtist TypeError reading c в _ensurePoliceResponseFleet при0bays каждые1.5секпрерываетupdate. Artistperceptionисправляет—этоВАЖНОдлялагов!

## Владельцы и очередь
Optimizer 01a06e4d-e3ed-7f13-bda3-7fd677972336 — priorityfullsceneprofileпослеone-tabcleanup. Trafficpaintbatchfix LIVErootподтвердил fallbackMembers0/2583members500batches. ShadowoptinONLYбезacceptance. Skeletonhelper+Artistapprovedactorhook4→1skeletonнаNPC, exactvertices108008CPU,неFPS.
Artist16 01a08865-ebd3-7d12-a0d5-5312c76163fd переходитArtist17 (уточнитьID), транспорт/police/driver/custody/NPCactor. Handoff NPC_TRANSPORT_RESCUE_20260912_HANDOFF.md. Истиннаясмертьнеживойконвой; livingcustodyсохранять.
Интерьеры/дороги 01a087f0-fda6-7e13-8baa-1bbd1c5cc26e — камерау стен, routegraph/signals/parking, миникартаsetRoute НЕmercenaryhover. ГотовcameraCPU, road71/78terminalreachableи44/46walkingcrossing,ещёработает. GPUown0,уступаетoptimizer.
Укрытия 01a087e2-a009-7873-a45f-8e1a4c2effc4 — Ctrl/C,stickycover, naturalturn,lowhead, ownwalkhooks. Свояuserdemo2быланезакрываемойдоnewone-tabapproval. 15секrefreshbusyвыбивалcover, guardedautopoll!heroCover.active. Не перетиратьhook.
Крыши/лестницы 01a06e4e-0fcb-7830-a948-1332745a1cd2 — 22roofprofiles, ladder3.1/slide7.2,ownbuildingcollisioncorridor scope.

Продолжать последниеuserfix+LIVEиperformancepriority. Не выдавать CPU, isolatedpreviewилистарыеобещаниязавершённойсистемой. Полныебанды/зарплаты/заведения/крышаиавторитетныйservercontractнаёмниковне готовы.
