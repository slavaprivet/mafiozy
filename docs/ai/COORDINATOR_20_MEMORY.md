# Координатор20 — актуальная память

20 сентября 2026. Чистый чат-преемник `01a0bc08-cb3e-7181-be11-a53aaee54535`.
Передача18→20 и память17 прочитаны. Исторические V/X/очередь/пинок/60с страх
LIVE проверки остаются в COORDINATOR_20_HANDOFF.md, не потеряны.

## СРОЧНО: поздний приоритет пользователя через NPClead19

### 23 сентября — главный текущий запрос

САМОЕ ПОЗДНЕЕ: пользователь расширил gameplay-задачи: каждый NPC/босс/банда
имеет понятную цель; поездки NPC; банда застревает в воде и не следует игроку;
запугиватель должен работать по движущейся цели; чёрный телефон с антенной и
улучшенная анимация звонка; найм бандитов; подключение войн банд из world.
Требуется настоящий LIVE. Пользователь просит отчёт КАЖДЫЙ ЧАС: существующая
automation npc обновлена на ACTIVE hourly, новые дубли не создавались.
Пользователь разрешил решать зависания новых художника/транспорта; judge по
результатам, а не только active. Новые чаты получили scope, подтверждений ещё нет.

Проверщик2 сообщил уточнение пользователя: ВСЮ оптимизацию/8Астра ведёт он,
root больше НЕ применяет/повторно исследует их optimization diff. Root
сосредоточен на NPC и публикует текущий checkpoint по поручению пользователя.
Перенос8пакетов из более раннего поручения теперь ownerChecker2; scope согласован.
Perf shops ведёт отдельный existing npc_skin_pick_memo candidate, defaultOFF;
его actual mixed fixture21rays/176hitsparityPASS, CPUнеfullframe; нужноA/B.

Root LIVE загружен: viewport1280x720 GTX980, resident205 фактически двигался,
затем ожидал route16.9s. frame113.3/122.7ms p50/p95, interval139.6/510.8ms,
GPU61.23/66.74ms, mercenaryUpdate17.8/20.5ms,2857main+1034shadowcalls.
Это baseline без before/after сравнения, лаги НЕ устранены. Consoleerrors[].
Настоящий UI JSON export сохранён в .git/ai-pipeline-local/live23/
npc-inspection-checkpoint23.json:72cachedactors+route rows, presentation.state
null (getActorState пока не передан), не полный pose replay.

Checkpoint: runtimeclosure25modified+14new; JS35syntax/Python3AST/world7PASS.
Presentation23suite PASS, survivor CRLF исправлен root. Broader24suite:
21 сразу PASS, ещё ambulance/health/robbery fixture paths исправлены и PASS.
Robbery ownership передан Checker2→root, поскольку Checker2 теперь только perf.
Root исправил preview повторный release/confiscate и неподходящий outcome;
17 actual isolated SQLite receipt tests +10 actual AST preview tests PASS.
Backend не импортирован, реальные БД/credentials не использовались.
Child gang_water_follow23 готовит actual candidate + пять бойцов; child
astra_local_inventory23 — moving intimidation candidate, production пока нет.
Main checkpoint ещё не опубликован; далее root exact manifest stage/commit/push.

Позднее поручение: агент передаст патчи, root продолжает NPC; обновить main и
сообщить Проверщику ЧАТОВ2 подтверждённый SHA для работы Астра на новой базе.
Проверщик2 уже передал сводку всех8: готовые архивы1/2/6/7/8 на527e9c0,
3/4 статические аудиты,5 regression matrix. Текстовые unified diffs пока
ожидаются; сводка не равна применённому патчу. Порядок7 explosion →2 furniture
→1 allocations →8 vehicle batching;6 транспортное gameplay review.

Пользователь сам остановил зависшие Художник19 и Автомобили и поручил создать
продолжения. Созданы same-directory forks с завершённой историей:
- Художник20 `01a0cb0a-a267-73e1-9b01-319d5d3d4b72`, pinned2;
- Автомобили — продолжение2 `01a0cb0a-d013-79b1-a979-1612fdaa27bc`, pinned3.
Старые откреплены, больше не будить. Новым переданы память/границы; первое
задание read-only review текущих shared hunks для checkpoint, production
freeze до root SHA. Root владеет commit/push по новому поручению пользователя.
Художник20 теперь NPClead; транспорт2 наследует транспорт/скорую/двери.

Preview18538 восстановлен root (PID21980), read-only monitor, не backend.
В root одна game tab3; старт загрузки наблюдён, первый click PvE timeout
во время boot, итог LOADED/OBSERVED пока не подтверждён. Holdclock23 candidate
готов16CPUcases, runtime не подключён. Root pollfix уже подключён.

Пользователь: прочитать готовые патчи ВОСЬМИ закреплённых Астра (они работали
2 часа над оптимизацией), проверить и внедрить в Walk; также баг посадки в
машину, продолжать NPC с Художником19, обязательный LIVE, не много GPU-вкладок.
Все восемь найдены в list_threads. Два подхода к read_thread завершились
тайм-аутами загрузки ChatGPT. Повторный batch cell8 сохранит результаты в
functions store astra23_1..8; все восемь вернули timeout. send готового результата
к Astra8 тоже timeout, сообщение НЕ доставлено. Новых локальных пакетов23.09
в repo/.git/ai-pipeline-local/Downloads нет (старые16.09 не выдавать за новые).
Веб fallback открыта одна НЕигровая вкладка ChatGPT Астра1: требуется вход.
Пользователю отправлен async запрос войти в тот же аккаунт; ждём «вошёл».

IDs: Астра1 6aa9c2e0-8740-83e9-a530-7a3a71a4d41b;
Астра2 6aaae883-dc18-83ea-9f78-cd95de568011;
Астра3 6aaae8ab-f55c-83e9-bef7-232232b2f8fe;
Астра4 6aaaf0ef-b1a4-83e9-987e-60477590b078;
Астра5 6aaaf113-78c8-83ea-b5d3-173b3c945ae6;
Astra6 6ab2cebc-b550-83e9-a07f-0ff790a47236;
Astra7 6ab2d09b-22ec-83ea-84a8-c75478bfb5bb;
Astra8 6ab2d17d-76a8-83ea-8f95-a5cc36e23e41.

Root получил independent actual vehicle bug proof: Walk.poll только внутри
sourceVehicleActive оставляет adapter.pending после exit/interrupt навечно.
Исправлен только порядок poll перед active-gate. test_vehicle_entry_pending23
_audit.mjs --require-fixed: offline exit/online ACK/interrupted entry PASS3;
world_vehicle_player_access, car_entry, actual male/female player_pose PASS.
VEHICLE_ENTRY23_READONLY_AUDIT.md описывает baseline; production теперь fixed.
При7FPS hold0.3 ещё длится~1.14s из-за dt cap; это отдельно не изменено.
Source4seat limitations не расширять локальным обходом authority.

19/Checker2/transport уведомлены оscope и новых8пакетах, ихзадачи active,
новых результатов пока нет. Root принимает единственнуюGPU game18538 для
baseline/LIVE; monitor слушает127.0.0.1:18538, backend не запускать радиpreview.
ПатчиАстра23 ещё НЕ получены и НЕ интегрированы. Не обещать FPSпобеду.

Уточнение21: actual nativeRPG integration PASS7/15/60Hz, floor damage117,
moving skin160, endpoint160, once/reject. Medical crawl priority production
READY12+12, docs NPC_BLAST_SURVIVOR_PRIORITY21_HANDOFF.md. Новых LIVE нет.
Серверныйtest21 однажды перезаписал .bot-token fixture, root восстановил
штатный Desktop/bot-token-backup.txt и проверил запись без вывода секрета.
Не импортировать mafiozi_bot для тестов без полной изоляции import sideeffects.

### 21 сентября — актуально после перерыва (старые статусы ниже исторические)

Пользователь через19: РПГ/C4/взрыв машины не наносят ожидаемый урон.
LIVE19 до перерыва: прямой RPG resident306 HP60→1, тяжелоранен жив;
взрыв о землю/объекты не проверен. Source-аудит доказал рассинхронизацию:
native эффект у поверхности, old2D source взрыв в конце луча. Приоритет —
реальная точка/получатели/однократный урон, а не только blast parts.

Root21: world_walk_combat + weapon_effects + projectileOnly режим contact ray,
узкий Walk onImpact. Native RPG движется от принятого muzzle и возвращает
реальную точку удара в impactWalkRpg; full elapsed sweep при низком FPS.
Субагент rpg_source_impact21: world accepted flight, once/TTL/range/ray checks,
отключение old2D timer только native RPG, bypass gas/car single-shot branches.
Субагент rpg_server_contract21: read-only actual tempDB authority audit.
Важное: weapon_fire на launch конфликтует с remote target receipt на impact;
сохраняем прежний единственный impact claim. Серверный player AoE/launch
контракт отсутствует, локальное исправление НЕ объявлять его реализацией.
Субагент npc_blast_reaction21: approved два actor gate — медицинский crawl
имеет приоритет над stale cower/bench/phone. Actual baseline head1.08–1.41m
против правильных .41–.44m. sourceDown=false/surface idle сами по себе нормальны
для living crawl; кровь требует отдельного подтверждённого blast receipt.

Художник19 возобновил C4/local blast helper и навигацию; transport — per-event
vehicle callback и exposure resolver. Checker2 ведёт robbery receipts/пять
Astra. Perf ждёт actual mixed fixture; sparse navigation JSON для этого
недостаточен. Новых координаторов и лишних GPU-вкладок не создаём.
19 восстановил monitor18538 после остановки; его одна вкладка пока error,
reload ПОСЛЕ root READY. Gameplay backend не запускался. LIVE/FPS не принят.

Prone+vehicle death settle УЖЕ READY: NPC_PRONE_SETTLE20_HANDOFF.md, actor/helper
освобождены прежним агентом. Ambulance loading ownership УЖЕ READY:
AMBULANCE_LOADING_OWNERSHIP20.md. Citycop fatal metadata и timed bleedout
НЕ применены, отложены до урона взрывов. Caps/GPU blast upgrade тоже отложены.
Текущие edits ещё проверяются; тесты обычного combat/weapon effects прошли,
полный native RPG integration и LIVE остаются следующим шагом.

### Самая свежая дельта — death variants runtime

LATEST FIRST BLAST RUNTIME READY (вышеисториянижетолькоистория):
NOW: Proneplanapprovedproduction originvehicle/pronecombinedhelper, childanimation
владеетactor/death_entry20только; rootНЕправитactor/helperпокаREADY. Прототип28
actualcases noflip0rad first<5.6e-8/maxstep1.255мм; narrowfullproneonlypelvisP
formula, combinedstrictsaveoriginvalidation+blastvisualReplacedregressionsneeded.
19RPGпослеreloadвпроцессе, Liveblastдоказательствещёнет. Sourcechildcitycopprod
после4candidatePASS, затемbleedoutapproved. Propscapschildindependentnewhelper.
19singleReload LOADED,freezeСНЯТ,началRPGUI+routeReplay. Rootsourcechild
разрешёнcitycop4candidatePASS→production, потомотдельныйtimedbleedoutexplicit
cause/finalflags patch; неHP/balance. Checker2 surrenderdeadlineREADYвshared,
architectwetdryguard44PASSвэтотreload. Новыезадачи: architectactualmixedpopulation
hotpath measuredprofileчерез19;Checker2 robbery_id historicalreceipts еслиpending.
LowFPS latest:19requestedactual7HzbeforeLIVE. Root changed ONLYdefault
maxVerticesPerStep256→2048 (same1.25mssoftbudget/maxWork2048), prototypeactual
12cold/prepared+300TTLcyclesPASS (testquotaupdated2048, theoreticalminreportfixed).
Fullactual male/female7Hz31/28frames=4.43/4sec,15Hz2.13/1.8s,60Hz.58/.47s,
maxobservedslice2.18ms. ДотTL8успевает, задержкапокаплохая;19уведомлёнREADY
singleReload. Test_npc_blast_runtime20 supports NPC_BLAST_FPS=7/15/60.
Rootcurrentruntimefreezeдо19LOADED, этоНЕpendingproductionerror.
NPC_BLAST_RUNTIME20_HANDOFF.md. WorldRPGhelper/include +enrichmentproduction,
Walkimports/create/onSnapshot/updateпослеactor/dispose/npcWorld.blastданыroot.
Root actualsourcehelpers→male/femaleparts→bodyreplacement→save/cull/TTL→respawn
PASS51/49coldframes (~.85/.82sec@60), source/RPG/gas/host13PASS, death26PASS,
parts12ground3m6m180queries<=192PASS. 19сообщёнREADY, сейчасждёмreloadLOADED;
20existingruntimefreezeДОloaded, newisolatedhelper/testsразрешены.

TTLledger childисправил: Mapexpiry eventAt+8,256LIVEаnelifetime,300cyclesPASS;
capacitybusyнетconsume hostretryuntilTTL. Roothosthistoryтожеretire8s; стойкий
visualReplaced внутриactor deathPresentation save/restore +mark/is methods
не возвращаетцелыйcorpseпослеhistoryTTL/recreate; resetнаnewlife.
GroundmemoУЖЕactorruntime: exactearlyposeMeshlist +contextonlydeadraw>=.62,
actual6cases89hits/1miss,p50male1.37–1.48→.75–.86ms,female1.21→.63–.67.
VehicleentryУЖЕruntimevehicleonly,newhelpernpc_death_entry20;6/6tinyjump,
clock/surface/death26/ground6/recovery8PASS; actorосвобождёнchild.
Prone/crawlfirststepещё1.64–1.75мflip; childизолированнопрonefinalposeделает.

19LIVEsniperresident318 confirmedDamage132/hp0/surfaceDead,лежитневстаёт;
6позвизуальноещёнеприняты. ActorQAdeathCauseбудетnextreload. Город19новое
наблюдение:288alive67moving8drive8visit13social211pending; егоnavownerчинит
backlogthroughput, живойгородещёнеготов. 19GPUfrozenpalettefeasibilityready,
17/16draws,~.35–.54mswarmfreeze, noCPUskinbake, ноgroundbounds/shader/material
непроверены; текущийCPUruntimeрадипервойприёмкинезаменятьнемедленно.

Currentchildren: sourcecitycopplanapprovedcandidateunderfreeze (6thacceptedImpact,
replacementcorpse receiptbinding), потомtimedmedicalbleedoutmetadata+clearflags.
Partschild NEWcapshelper дляпростогоclosedarmloop, нередактируетruntimeprototype
приfreeze, GPUowner19не дублирует. Animationchildpronefinalinmemory, vehicleREADY.
Transport48fleetcasesproductionREADY NPC_VEHICLE_DOOR_FLEET20.md; следующая
конкретнаязадачаambulanceloading/crawl двойноеbody доcarried.42 (findingChecker2),
сначалаfixtures/anchorsподfreeze. Checker2 stalehands surrenderexpiry→flee, пять
Astra read-onlyregressions уженагружены; medicalissuesраспределенынедублировать.


UPDATE после527e9c0 sharedbloodcheckpoint: Checker2 medicalforcedcrawl теперь
движется (stunFlag=downed&&!forcedCrawl), новый lifecycleтестsourceDownfalse.
ЕгоdeathFromDowned age=max(.72,actualAge) конфликтовал сactorrawclock; ROOT
заменил на age=actualAge+отдельныйfromDowned:true, actorfreshdeathVisualBias=.62.
Actualmale/female integration26PASS: crawl→deathage0,sourceAt1,saverestoreexact;
clockactualpopulationPASS,recovery8+productionregressionPASS,lifecyclePASS,
population23PASS,surfacePASS. Checkerподтвердил совместимость иfreezeactor.
19сейчасделаетreload6cause/melee;20держитexistingruntimefreezeДОявногоloaded.
Послеrelease: sourcechild готовhistoryproven gasstation if(!bi...) deletion,
rootreviewdocGAS_STATION20_FIX_HANDOFF.md approvedinprinciple, productionещёнет.
Bank/beach/localinteriorfinalmetadata ужеproduction22PASS scopeосвобождён:
NPC_LOCAL_DEATH_EXTENSION20_HANDOFF.md. allclassesещёнеготово.
Perfowner NEW npc_ground_correction_memo.mjs68casesPASS,rootintegrationpending.
Важныйrootworldmatrixmustkey: IEEEactualGLB1.09e-7 difference наrootmove;
cachehitssteadyonly. ExactposeMeshlistcaptureсразуwalkercreateпередphone/surface.
Root NEW npc_blast_presentation20.mjs hostownership ONLY isolated; expects
profile.blastPresentation:{version:1,originSource:{r,c},visualSpeed:5}. Normalizer
ещёнепротягиваетполе, sourceproducerещёнепишетего =>никуданеподключатьпока.
План explicitRPG enrichment после t.hit толькоNEW acceptedfatalrecordcauseblast,
с originтогоRPG иявнойдизайнерскойspeed5, не measuredforce. Children: sourcegas
candidate потомRPG; partsprototypeинтегрирует19groundhelperсglobal192queries;
animation vehicle+pronecrawl captureblend, firstframe~7e-8 ноmidcrawl17см
bad, нужнаотдельнаяpronefinalpose;productionтамне менятьбезreview.


Дополнение: sourceDeathClock уже production actor (3узкихизменения), rootreview
и самостоятельный test_npc_death_clock_persistence_prototype20 PASS. Actual
population cull/reentry rawage5.01→.01 безposejump; 12male/female clocksdiff0.
Childanimation завершает recoverytest rollbackanchor адаптацию (толькоtest),
затем actorотпустити займётсяvehicle→death in-memoryproposal. ЖдёмегоREADY19.
Sourcechild получил следующийproduction slice bank/beach/localinterior final
metadata+acceptedweaponforwarding _localBallisticTargets,19уведомлён. Безdamage/
HP/recipients/protections. ОстальноеallNPCfatalcoverage неготово.
19navigationagentделаетisolated npc_blast_ground20.mjs+tests, partsprototype
нетрогает; rootпотомраспределитобщийbudget acrossparts. Rootblastchild уменьшает
latency cold43–55warm35–41steps приsamebudget; ещёне runtime.
Transportследующеезадание: 2–3разныхреальныхкузова×4двери×male/female1.65/2.05,
actualcontacts/transitions; actordeath неего. Проверщик2 activeполицейскоекачание,
попросилсверку5Astraследующихзадач. Perfownerisolatedgroundmemo: нуженexact list
poseMeshes captureвactorсразупослеcreateHeroWalkerдоphone/surface, rootвставит.


19 снял runtime freeze после reload; кровь LIVE PASS: pistol confirmedDamage24,
HP60→36 alive, wound1, bleeding1, drops1→11, ground redmarks visible.
Root подключил npc_death_pose20 + npc_death_presentation20 в actor/lifecycle.
NPC_DEATH_POSE20_HANDOFF.md:6поз, actual integration24PASS, pose12PASS,
recovery8/lifecycle/surfacePASS. Unknown exactbase, selection frozen firstpose,
matching record/epoch, optional save/restore strict validation. Нет LIVEпозещё.
PoseCPUbase/profile p50 1.364/1.349,p95 1.576/1.611ms; fullscene nottested.
19 requested settledground scan cache; автороптимизации получил isolated exact
memo helper task, actor/hero/pose20 не редактирует. Потом root интегрирует.
Children ongoing: animation persistenceclock in-memory (externaldeath15/private10
save доfirstpose теряет5s, legacy muststay); cause audit allNPCfinalpaths (police
corpse ID differs!); blast latency reduction warmup/cache. Blast incremental stage
6GLBbitwisePASS but65–75steps/victim, no ground/caps, NOT runtimeREADY.
Транспорт cancellation/occupancyREADY; следующий exit→death обнаружил hand54смjump,
делает actualmale/female board/seated/exit fixtures, actor fix20послеclock.
Current actor20ownership root; subagent persistence толькоin-memory точныеhunks.


Свежая дельта после этой шапки:19 сообщил опубликованный общий ce5272b
(root локально до сообщения видел7370157, remote сам не проверял). 64scoped
файла; read/socialfinish иdeath/blood/meleeWIP вcheckpoint не вошли.
19 готовит следующийreload blood/ground/melee,20 обещал runtimefreeze до
release; tests/docs/new isolated modules можно. Currentproduction20safe.
Recovery УЖЕproductionREADY actor-only, NPC_RECOVERY20_HANDOFF.md:
originalaudit8/8PASS, external sync gap+rawclocks+legacy saves+deathallPASS.
Mixedexpiredstun+freshdeath остаётся толькоin-memory agent experiment.
Cause producer УЖЕна диске: npc_death_record20_source.js и3worldhunks
(script tag, finalhitNpc послеmedicalreturn доrespawn, streetsnapshot).
Actualsource+profile11PASS, finaldeathrecordimmutable,target/epochbinding;
другие deathpaths покаunknown. Старыйmeleetest500ms противнового250msgrace
падает поизменению19meleeowner, ему передано, мыокнонетрогаем.
Root npc_death_pose20.mjs иtest_npc_death_pose20.mjs покаISOLATED:12actual
male/female×6causesPASS, directionfromprofile,unknownexactbase,inheritweight
rawAge0exactbase, groundskin~0, maxhandstep2.4–3.8см при60FPS. CPUbase/profile
p50≈3.387/3.445ms, concurrent noisy p9512/18 НЕperfacceptance. Newhelper
notimported; послеfreezeподключатьnpc_source_lifecycle→actorprofile/save→
NPCposepresentReaction. Hero/surfaceblood НЕ писать.19агентbloodвsurface,
другойgroundbloodFxconsumer walk_preview snapshot/update/dispose.
Blastproto actual6appearancesPASS, admission9–30ms слишкомдорого; agent
incrementalbudget+WeakMapimmutablegeometry/signaturecache (неJSONfullarrays),
eventage/dedupeTTL8s, max12parts2victims, atomicwholebody→readyallparts.
LegacysourcebodyPartFx/goreFx есть, consumer rootthree_preview.js5682,
Walkпокаего нечитает; отсутствуетtarget/death/eventbinding, не делатьдубль.
Checker2 иtransport/perf найденныеidle повторно получилиследующиеbounded
tasks. TransportNPC_VEHICLE_TRANSITION_CONTINUITY20 READY; дальшеcancel/
occupiedseat. PerfNPC_ACTOR_OBJECT_PROJECTION_20260920 READY .00394→.00149ms
за71actor rootscall (небольшойhygiene, неlagfix),19scopeconfirmed.

19 передал два новых прямых поручения: разные смерти по способу убийства,
проверить плохо попадающий melee; больше крови/капель у раненого и разлёт
частей NPC при взрывах. КООРДИНАТОР20 владеет death variation/continuity
и blast dismemberment. 19 лично кровь/drips, егоwander_cost meleecontact.
Не пересекать их файлы. Native capture source vertical slice отложен за
urgent death, не отменён. Не выдавать prototype за интеграцию/LIVE.

Актуальные дети (старые статусы ниже исторические):
- npc_animation_quality_audit20: seat/read/help/talk уже production READY,
  теперь in-memory recovery fix86°. Initial prototype headjump1.1м→.35–.38мм,
  clocks/dead authority untouched; ждём exactplan/regression дляproduction.
- boss_native_binding_audit: native audit done; теперь isolated actualGLB
  blastparts prototype. GLB material meshes, нет authored limbs; partition
  triangles по skin regions, bake actual pose, materials reuse, bounds/lifetime.
  Production actor/pose/source не трогает; seams/caps art QA отдельно.
- npc_death_cause_contract20: новый bounded audit damage→snapshot→actor;
  отдельный explicit fatal-cause normalizer/tests/plan, production world/actor/
  surface НЕ трогает. Не infer изHP/старогоhit/random; unknown прежняяпоза.

Текущий capture helper: native_site_local_authority.mjs НЕruntimeimported.
Source callbacks + synchronous local session commit/replay/CAS/HQ loss;
original+independentcallbackaudit8/8PASS, root исправил reentry/dispose/gate/
permission revoke. Следующий sourcebridge/E/roster ещёне сделан.19разрешил
oldtown001 localQA: leila/marat stable specialistId, реальныеeligibleбойцы
обычными маршрутами безteleport; полныйявныйroster, missing=unknown, до
прибытияcaptureunavailable. Нет полноценногоnativepresence/rosterнаserver:
подготовить честныйblockedadapter, не подделыватьcomplete. ExistingEcontext,
local explicit gate, не API realaccount; backend persistence неготов.

Последний shared status:19 сделал reload и СНЯЛ2минfreeze, НОВЫЙ COMMIT
НЕ делал из-заvehicle/hero/pickingWIP. Remote main остаётся7370157.
Проверщик2 перенёс crime/phone/cash/surrender и дал actorREADY. Наш help/talk
затем применён узко, егополя сохранены. NPC_PRESENTATION20_RELOAD_MANIFEST.md.
2починил старыйsocialtest: pooledphone diagnostics вместо legacyNPC_Phone,
sharedsocialsuitePASS. Емуназначен robbery_idimmutable receipt/crimecoords
поAstra3, безdestructivemigration. Он такжеисправил victimcallorder/toast:
сначалаvictimcaller slot, потомwitnesses; FALSEqueue не даёт ложныйtoast.

READY20 (CPU, неLIVE/FPS): seat24–26см→0; readingexpiry18.39/15.85см→
.042/.036см, книга actualtrianglecontact<=2.17/1.50мм; help/talk42–55см→
3.5–4.6см при60FPS,26priority+8longgapPASS. Handoffs NPC_SEAT_ENTRY20,
NPC_READING_EXIT20, NPC_GESTURE_EXIT20_HANDOFF.md. Root reviewed seat/readdiff.
Help hasextraexitCPU .0577/.0947→.139/.2153мс p50/p95 только.3сfade.
Perfавторготовskin perraycachedefaultOFF, CPUhit10.04→5.42ms на10rigs,
miss.026→.064ms;19ведётLIVEA/B, лаги ещёнерешены.

## Последнее прямое поручение

Пользователь переключил приоритет на совместную работу с Художником19:
«цель сделать живой город», затем непрерывно загружать действующих авторов,
агентов и субагентов улучшением NPC и качеством анимаций всех действий.
Активная цель создана в этой задаче. Не объявлять город готовым по CPU PASS.

Принято: здания Walk не перестраиваются от смены хозяина; охрана→бой→вход
внутрь→захват. **HQ сначала захватывают как готовое здание, затем превращают
в штаб.** Это явный ответ пользователя, который отменяет раннюю идею новых
домов на пустырях. E/длительность удержания пока предложения, не утверждённый
баланс. План `docs/game-design/NATIVE_SITE_CAPTURE_HQ_20260920.md`.

## Действующая команда

- Художник19 `01a0bbea-e50a-71f1-b148-e12196d0c102`: NPClead, pedestrian
  agenda/nav, единственный согласователь LIVE/GPU. Его дети заняты road-egress,
  shoreline/body-invalid boss spawn, native cache/building entry, lowFPS
  peaceful activity. Не дублировать. Его свежий boss queue fix сохраняет
  максимум одну actual search slice/frame, пропускает DENIED запросы, 19/19
  вместо0/19 в actual-source fixture; LIVE после reload ещё требуется.
- Автомобили — продолжение архитектора `01a087f0-fda6-7e13-8baa-1bbd1c5cc26e`:
  transport, подход/посадка/поездка/парковка/выход, двери/салоны.
- Архитектор — магазины и отель `01a06e4d-e3ed-7f13-bda3-7fd677972336`:
  perf/getPickRoots. Получил продолжение точного безопасного picking и
  следующего подтверждённого узкого bottleneck, без снижения качества.
- Проверщик ЧАТОВ2 `01a0bbdc-edb1-7cc3-9cda-1160f3bc057b`: crime/robbery/
  phone и пять Astra. Actor phone/robbery сейчас его; не пересекать.
  Астрам напрямую не писать, не расходовать сообщения на пустой статус.
- Координатор20: native-site capture/HQ, общий контроль, animation audit.

Всем действующим владельцам передано непрерывно брать следующее конкретное
задание после проверенного результата, по границам19. Старые17/18 не будить.
Automation `npc`, heartbeat каждые15мин, ACTIVE, на этой задаче: чтение памяти,
контроль действующих исполнителей, полезная работа и тишина при неизменном
состоянии. Старый `astra-walk` PAUSED на17 не изменялся. Другой heartbeat19
не нужен, он подтвердил достаточность нашего контроля.

## Собственные субагенты

- `boss_native_binding_audit`: mapping/reuse server audits и исправление
  duplicate/sparse occupants завершены. Контракт требует claimantFactionId,
  remainingHostileDefenderIds и disposition attacker/nonblocking/hostile.
  Root scoped suite 5/5 PASS. Height containment READY: реальные floor/ceiling,
  feet±15см, три этажа townhouse принимаются, крыша/воздух/подпол отвергаются.
  После height agent suite5/5 PASS. Production entry/world/GPU0.
  Точный source integration plan READY: NATIVE_SITE_SOURCE20_INTEGRATION_PLAN.md.
  Render guards cull/cap нельзя считать полным roster; source нет native Y
  authority. Первым достижим только явный LOCAL session slice; сетевой commit
  требует отдельного native server контракта, не client intent POST.
  Следующий ACTIVE read-only actual-rig recovery/stun/death transitions audit,
  без production actor/world. Документ NPC_RECOVERY20_AUDIT.md по готовности.
- `npc_animation_quality_audit20`: разрешённый19 initial seat patch READY.
  npc_activity_pose.mjs первый кадр учитывает только возраст seat; рука
  male/female24.32/25.73см→0. Actual regression/old suite PASS, root diff
  reviewed. Handoff NPC_SEAT_ENTRY20_HANDOFF.md. LIVE/FPS pending у19.
  Calm help/talk prototype READY, только in-memory:42–55см→3.5–4.6см max step
  при60FPS,26interruptions matrixdiff0. Доп CPUexit p50.062→.147мс, не FPS.
  NPC_GESTURE_EXIT20_PLAN.md. Actor НЕ трогать до scoped READY Проверщика2;
  root попросил дополнить case long update gap против resurrected stale pose.
  Следующее ACTIVE, явное разрешение19: npc_social_pose.mjs read envelope
  последние.6с+actual regression; source/agenda/actor не трогать. Root audit
  audit_npc_reading_contact20.mjs подтвердил normal expiry руки18.39/15.85см
  male/female. Сгладить с сохранением контакта книги, immediate threat priority.

## Изменения20 и готовность

Созданы два документа: `NPC_EMPIRE_NATIVE_BINDING20_CONTRACT.md` (аудит старого
scope, отмечено новое решение пользователя) и план capture/HQ выше.
`assets/maps/city_rebuild_v1/native_site_control.mjs` — **изолированный**
каталог явных site policy и planner capture/HQ intents. Не подключён в world,
не пишет owner/DB/economy, не является готовым захватом. Доверенный host обязан
проверить actor/leader, полный guard roster, физическое присутствие и атомарно
применить receipt с версиями/idempotency. Предыдущая server exterior capture
не доказывает interior entry; native ID нельзя подставлять в legacy apt_key.
`test_native_site_control.mjs` PASS в том числе manifest revision guards.
Независимый adversarial review исправил sparse/duplicate gap, root suite
5/5 PASS. Проверка высоты внутри исправлена и проверена субагентом. Actual current
GLB `test_native_site_control_geometry.mjs` PASS: oldtown001 actual roomPoint
внутри, approachPoint снаружи; banksmall не получает capturable без policy.
План размещения hash90e0b27196b51fc1f09ccc67d4c5f8374d5c37611576106f34b30559e86ed3ca.
Только граница двери/комнаты; NPC combat/routes/authority/LIVE не проверены.

## Продолжение команды / анимации

Очередь всех семейств действий: NPC_ANIMATION20_QUEUE.md. Это карта работы,
а не объявление всех анимаций готовыми. После каждого READY — следующий
доказанный дефект в своём scope; GPU и shared reload согласует19.
Автомобили: очередь4машин PASS, min gap4.992м; следующий независимый audit
approach→door→seat→drive→exit actual rigs, пока19 получает LIVE blockerId.
Проверщик2: hands-up кисти у висков исправлены в b60d, bullet-only90%flee
обычных гражданских/прямое попадание, cash handoff/empty. Это его локальный
пакет, shared перенос pending. Imports/applyLifeGesture/visual update actor
его до явного освобождения. Help/talk transition за20 после освобождения.

## Браузер / shared

Наш fresh CUA inventory: собственный iab tabs=[], чужие вкладки недоступны.
У19 открыта разрешённая18538; у18 осталась старая пользовательская18538;
уПроверщика2 пользовательская18539. Не закрывать/создавать игры вслепую.
CPU/geometry не являются LIVE и FPS, общей сцены20 не измерял.
Художник19 отправил checkpoint7370157 наmain с verified remoteSHA, freeze
снят. Мы не commit/push, shared world других авторов не перезаписываем.
Ruflo/ToolSearch в каталоге нет, используем файловую память.
