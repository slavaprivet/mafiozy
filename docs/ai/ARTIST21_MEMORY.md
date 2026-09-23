# Художник21 — актуальная память

## Последнее: пользователь «продолжай задачи без остановок»

NEW USER: живые видимые NPC-продавцы/сотрудники услуг, кассы, покупатели
подходят к сотруднику за товаром; мёртвый продавец не обслуживает,60сrespawn,
обычная HP/crime/police реакция, мирная роль stationary service. LATER correction:
в каждом здании кладовка/техническая дверь; после60сspawn ВНУТРИ подсобки,
открыть дверь→физически выйти→вернуться к кассе, никакого pop-in снаружи.
Concept updated NPC_PERSONAL_ECONOMY_NEEDS_20260923.md, root informed, requested
interior owner actual room/door/work/customer anchors. Next isolated service
candidate can validate supplied layout/lifecycle; production still frozen.

NEEDS reviewer fixes FINAL54 own +11 actual-commerce PASS; independent reported
11/11PASS. HP history8 handles both snapshot/receipt orders, changed HP beforeheal,
newer damage/death not overwritten, no old HP world effect, no-op healing rejected.
Cancelled goal ring16 + completedAt + injected pre-cancel completion proof; without
proof explicit account-sync-required. Bank headroom bounded; police ACK guard.
Host MUST stop bank executor before committing after robbery; history exhausted
or external committed mismatch requires authoritative reconciliation, not refund.
Handoff final hashes e9a8e0e/97f21e9/0b403cc. Sending directly to reviewer subagent
via app tool rejected; root forwards. No production wiring.

FOLLOWUP needs candidate now44 checks PASS: higher-priority hospital/police
bypasses failed lower-priority errand retry, while same-priority backoff and
failed-place cooldown remain. New test_npc_resident_needs23_commerce.mjs11PASS
executes actual commerce source and world resident visit tick (passability stubs):
existing wallet/inventory/history/serial survive, one actual checkout→one mirror
debit, no second wallet debit; cancelled/forged/stale-balance receipts rejected.
Test host only, NOT production adapter. Receipt-ID after journal trim explicitly
delegated to trusted host immutable ID→sequence mapping. Latest hashes in handoff.
Root memory still freeze pending fire pose/reload5; no production edits.

LATEST isolatedneeds READY CPU/NOTWIRED: npc_resident_needs23_candidate.mjs +
test_npc_resident_needs23.mjs, handoff NPC_RESIDENT_NEEDS23_CANDIDATE.md.41checksPASS,
80people×24decisions79distinctsequences; pendinggoalstable. Personalfinitecash/bank,
conservation, physicalarrival+externallyverifiedreceipt, robbery→policeACK→bank,
healthpriority/treatmentversion, criticalHPexistingEMS, roleshold, nofakeonlinebank.
Authmode requiresNPCaccount before/after+monotonicactorreceiptsequence; current
backendrobberypayout lacks those, integrationadapter stillneeded. Journal64+
sequencehighwater rejects oldreplaysaftertrim.384stableintentsp50/p95 .372/.532ms.
Production0, no bank/hospital LIVE claims. Candidate/root review next.
Transport3 saved agreedread-only animationcontract:
docs/ai/NPC_VEHICLE_HIJACK_CONTACT23_CONTRACT.md; dedicatedfall avoiding_knockedUntil
andpostsettlereaction; explicitdooropennessfix planned, notproductionyet.


NEW DIRECT USER23SEP: качественные vehicle посадка/ноги/двери +grab→extract→fall;
затем resident personalbudget/spend→bank, lowHP→hospital→resume, far→car;
непредсказуемость, personalcash+bank, robbed→police→bank. Concept+actualgapmap:
docs/game-design/NPC_PERSONAL_ECONOMY_NEEDS_20260923.md. Root принял.
NOW AUTHORIZED isolated npc_resident_needs23_candidate.mjs/tests: finite session
cash+bank, conserved idempotent transfers; sameNPC acceptedrobberyreceipts only;
online needs injected authoritative receipts, absentbankendpoint unsupported.
Actual healingarrivalreceipt, urgentHPpriority, policeack→bank. NOproductionwiring
untilcheckpoint. Next sourceowned by Artist21 residentagenda, Transport3 fartrip,
root serverauthority/Walk hooks. Do not wake archivedArtist20/transport2.
Animationaftercheckpoint: I own vehicle_hijack_pose victim/contact +npc_actor
scopedpresentation; Transport3 01a0cb2d-d723-70c2-aa21-79f76a12481f source timing/
doors, root playergrab/Walk. Sentread-onlystagecontract: grabdwell.20s before
rootmovement, extract/release/fall/settle metadata, actual2handgripsWorld anchors.
Existinglivingvictimonlystaggers; releasedimmediatelyprotests. Need deferreaction
untilsourcefallsettled; _npcVehicleHijackReactionTick clears on _knockedUntil.
Hospitalyield isolatedDONE:27contracts+4actualHzPASS, docs/ai/NPC_GUARD_YIELD23_HANDOFF.md.
No wiring, oldwaitdetourstill4/6. Deferredfornewuserpriorities.


LATEST floor priority after READY: root authorized narrow npc_locomotion_pose only.
Actual skin firstblendregression -.01843m (old purevehicle-.00329). FIX active
floor exact influencebucket bounding cache, onlyraise visualPivot Y; ordinary
walk nofloorcost. Fullnativeground oracle256PASS maxerror1.15e-16 incl64versioned
sole edits. Normal64PASS maxstep.098252, first<8e-8; original transition/footplant/
zero warmTHREE/vehicledeathPASS. Fullskin448poses3.68M min-.00277 only afterblend.
Warmfloor p50/p95 male.249/.370ms female.180/.234 vsfull1.237/1.517 and1.119/1.371;
coldcache4.56/3.88ms. FINAL handoff NPC_WALK_BOARD_ENTRY23_HANDOFF.md hashes.
Productionfreeze afterready; fireowner independentlydoingheadlean forX.
Root LIVE loadedpriorfloorbuild: resident53 upright walk_to_shop→walk_to_bench,
resident115 enteredbuilding; actual late .3474doubletap dive1.25s,1.90092m,y0,
noextraimpulse. Immediate .42 apex notobserved. LIVEfloor pendingfinalreload.
NEXT authorized by root: isolated bounded hospital yield helper/tests/handoff,
reservation/deadlock/retry/collision; NO productionwiring. Start afterfloorREADY.


READONLY later rate check: hospital original .6cell yield fails safely15Hz,
works7/5/3. Same direction .8cell yield passes actual15/7/5/3Hz,0unsafe and
speed*dt bounds, original .34stop. Output npc_hospital_yield_rates23_readonly_0.8.json.
No runtime/candidate edits; root informed. Need bounded production producer later.

READONLY guard продолжение: outputs/npc_hospital_grid23_readonly.json/.mjs.
Hospital .15cell dense grid4500nodes no path with2stationaryguards; removing
one body (each independently) opens path. Actual source follower normal .34 stop:
guard2 yields3steps to r7.38575/c164.31595, waitingguard then15steps actualpost
remaining.28518cell,0unsafe/interior. Guard0 96yieldprobes none. Densegrid not
runtimebudget, no candidate/production edits. Root informed; future bounded
ordered yield + reservation/owner/cancel contract needed, not integratedready.


LATEST срочный root blocker female board0 после нового gait: A/B confirmed
old locomotion .048945m/current .123546m. FIX READY NPC_WALK_BOARD_ENTRY23_HANDOFF.md:
locomotion lazy outgoing pose capture at walk→board, .22s blend into existing vehicle
output, TWO npc_actor gate calls only; fire sections untouched. Actual original
transition PASS first<8e-8m, sequence .087/.092, cancel/cull unchanged. New64 warm
sex/door/phase/earlycancel cases PASS maxstep .099734m (<.1). Footplant/0 warmed
allocations/16gaits/vehicledeath/population PASS. CPU capture p95 .0145/.0266ms,
blend .0151/.0192ms, inactive .0002ms. Root reload/LIVE pending, files stable.
Buffer is transient renderer state, cull first .22s not covered; existing exit .4
rehydration PASS. No source/root authority changes.
Guard readonly exact staging: output npc_guard_exact_staging23_readonly.json;
printshop 15/7/5/3Hz with exact bend arrival 4/4 safe final arrivals; .34stop fails
3/4. In-memory follower substitution only, production/candidate NOT changed.


LATESTroot usersteering: главноеNPCbehavior/animation/activities/follow/transport,
послеприёмкикопы/банды. Gait/dive+elapsedFINALREADY rootпринял; егоindependent
16gaits/footplant/hero_jump PASS, keyboard rerun; combinedreload ждётfirechild.
PRODUCTION FREEZEдоcheckpoint; rootразрешилread-onlyguardgeometry.
Printshopstaging margin readonly: extension.35/.4 при15/7/5Hz не решает
secondedge, no unsafe. report npc_guard_staging_margin23_readonly.json.
Безsnap/подменыarrived. Sourcefollower.34early слишкомгрубдляузкогоповорота;
новыхproductionпараметровпока нет. Hospital312gridbendsnone, неproofневозможности.

САМОЕ ПОЗДНЕЕ newuserpriority via root: полуприседприходьбе + MaxPayne jump
too high/far. Implemented CPUready `NPC_UPRIGHT_WALK_DIVE23_HANDOFF.md`.
Production3scopes: npc_locomotion_pose ordinarystride2.32→1.9(slow1.65), dynamic
pelvisdrop fromactualfootphase; hero_jump dive4.8→3.36m, immediatearc.8→.42m;
root separatelyauthorized Walk updateJump+singleframe rawDtcall ONLY.
LATESTrootreviewисправлен: validrawDt≤1sec consumes min(dt,.25),7maxsubsteps≤.04;
hidden/invalid/>1secgap freeze. .26/.33cityframesprogress, no deferreddebt,
3FPSjump1.667sec. Тест3FPS/.26jitter/2secgapPASS,40negativecases. Старый>.25
полныйfreeze ОТВЕРГНУТиубран. traversaloldcap,
globalphysics/fire/vehicle/NPCdtне тронуты. Actual5FPSjump6.4→1.4s,10FPS3.2→1.3,
60FPS1.25same. Late200msdoubletap peak.843/400ms1.05 сохраненырадиcontinuity.
Actual111 flags: activitynull/gesturework/seek_shop НЕ накладываютworkpose.
Oldfixedhipdrop9.37/9.87cm→cycle.4–6.17/6.45cm; maxkneeflex101/99→65/63deg.
Crouch/rununchanged, footplantnostretch/sourcecoordinatesPASS. 50rigwarm200A/B
overlayp50/p95 .289/.454→.282/.432ms, НЕwholeFPS. 16posecases,23population,
jumpkeyboardactual30negative,14weapon1348pose,60landing,posture/surfacePASS.
Allruntimeworkdone; need FINALREADY sendroot + LIVE. No own GPU.
Guard work deferred again: latestafteravoidPoint/lateralprobes4/6, hospital
no-safe-two-leg andprintshop safe stagingthen second-leg-blocked. Oldhandoff
2nomovement obsolete; no runtimeimports. Offlinegrid foundprintshopdesired
bend butsource stops .34early, revalidationcorrectlyblockssecondleg. Keepforlater.

ПОЗЖЕ: root shortLIVE centre→Kingswell PASS:5crewcatchup, прежнийsurfaceexception
не повторился,hero/NPCupdate идут,carentering progressing. Это shortfixloaded,
не wholecity/FPS/vehicleacceptance. Root разрешил продолжитьisolatedguard.
Guardwait/detour now NPC_GUARD_WAIT_DETOUR23_HANDOFF.md:20lifecyclecasesPASS,
4/6actualtwoleg arrivals,80physicalsteps0unsafe/interior;2 explicitblocked
(hospital slot1step1,printshop slot2step3). Staticentrance proof отдельныйcallback,
обеactualноги сохраняютdynamicguardbody.1500msqueryfreewait,12bends,96/slice,
4096/job,lease12sec+owner/cancel/expiryrelease.24bendsнепомогли→reverted.
Sourcefollowerнеправлен: stagingarrived .34early затем validatefromREALposition.
NO runtime imports/authority edits. OldWIP superseded. Не объявлять6/6.

СРОЧНО / самое позднее: root остановил guardработу из-за LIVE Surface geometry
signature mismatch после centre→Kingswell. Actual GLB population RED воспроизведён:
hired bruiser geometry изменена, но recreation restore идёт до activation shape.
Root разрешил npc_actor shape/save/restore только, firechild frozen. Productionfix
на диске: bodyShape{version:1,bruiser} в envelope, restoreShapedSurface23 применяет
savedshape перед existing strictvalidation, rollbackgeometry on error/rethrow.
`NPC_BRUISER_SURFACE_REENTRY23_HANDOFF.md` — READY CPU, rootLIVE pending.
4actual male/female×base/bruiser cachecycles, wet+wounds+bruises+dedup,
28atomicreject и48visiblewetattribute checks PASS. Existing surface/population23/
actor/bruiservisual2/resources PASS,syntax/diffcheckPASS. Root wet-attribute
secondclone suspicion НЕ подтвердилось: owned wetgeometry и attridentity intact.
Никакихsharedpopulation/fire/vehiclepose/world edits по этомуfix. Нужен rootreload.
Root independentactualGLB review тожеPASS (private/appearanceOwned,10secwetdry,
wounds/receipt/rollback/legacy). FINALREADY отправлен, npc_actor lock released.
Applied scoped27linepatch вoutputs/npc_bruiser_surface_reentry23_applied.patch,
не reapply. Root повторяетLIVE, не открыватьсвоюигру.

Guard wait/detour PAUSED explicit root. New isolated wait/detour module/test и
native_guard_crowded23 fixture НЕ READY: 6 stationarycrowds остаются blocked,
4 no-safe-two-leg-post и2querybudget. Wait1500ms/source singleleg staged design,
никакихproduction imports. Не включатьвсрочныйrelease. Вернуться послеrootLIVE.
Подробностипродолжения: NPC_GUARD_WAIT_DETOUR23_WIP.md.

САМОЕ ПОЗДНЕЕ: isolated exterior guardpost producer готов для review, НЕ APPLY.
`NPC_EXTERIOR_GUARD_POST23_CANDIDATE.md`, module/test и output одноимённые.
Actual hospital + print_shop + bookmaker: 36/36 physical arrivals, 0 unsafe/interior;
matched source baseline 23/36 real, 31 route-arrived, 2 unsafe. Existing catalog
entry approach + controlled already-owned input, authority/HQ/runtime не тронуты.
33 contract/cancel/budget cases PASS. 36 candidates, 96 callbacks/slice,4096/job,
cooperative2ms. Cost source→candidate p50 1.105→1.821ms, p95 112.105→5.746ms,
sum739.344→85.724ms; not LIVE/FPS. Occupied3guards series30/36;6 explicitly
BLOCKED (4hospital,2printshop), no fakearrival. Crowd-safe local detour/wait remains
integration work; don't claim all36 occupiedpaths ready. Root получил prelim,
handoff отправить с этим ограничением. Cachedboss production package не менялся.

НОВЫЙ guard followup — NEGATIVE/НЕ APPLY: `NPC_GUARD_POSTS23_REJECTION.md`.
Actualguardpostproducer aroundexistinghospital 3slots×4turns: coarse12routearrived,
но6действительныхpostarrival; nativeтоже6/12иCPU318→2135ms. Остальныепосты
изолированы/заclosedapproach; partialendpoint2–5.33cellотцели. Простое
guardkindnativeвключение покаотвергнуто. `test_empire_other_kinds23 --guard-posts`
сохраняетnegative report и намеренноFAIL. Не включатьвcurrentpatchCIкакPASS.
Старые24/24syntheticselectionнеполнаяприёмка. Cachedbossproductionне затронут.

САМОЕ ПОЗДНЕЕ: root briefreview далapply cachedtarget+Nico footprint на272d12c.
IMPLEMENTED/CPU TESTED, `NPC_CACHED_TARGET23_HANDOFF.md` содержит exactpaths.
World только2sites; sourcewaterqueryfinite depth ужеready, secondaryadapternull
не мешает (actual19assert). Production lifecycle7groups/42exclusionsPASS;
6actualphysicalarrived0blocked/13validbyteunchanged с --require-fixed читает
actualhelper/registration безsubstitution. Full nearest300parity, native64paths,
unique30, escortcancel/retarget/pendingPASS, syntax7PASS. Localpatrol oldgoal
больше не создаётся новымnearest: fixture теперь отдельноseedhistoricalcached
goal45EMPTY→1 и prevention0EMPTY. RuntimeLIVE pendingуrootпослеsquadпакета.
Commit/push не делал; rootvehiclefire можетправить independent _updateGang.

АКТУАЛЬНО ПОЗЖЕ: root опубликовал f70cba1ee293b8111fcf329073858c3313b6cc21,
включая cohort/escortcancel/retarget. Новый scoped candidate по его поручению:
`NPC_CACHED_TARGET23_CANDIDATE.md` READY FOR REVIEW, production НЕ изменён.
`outputs/npc_cached_target23_candidate.patch`82lines/2worldsites; apply--check
PASS, syntax7PASS, lifecycle7groups/39exclusionsPASS. Actual registrationRED
6invalidunchanged, baseline0/6routeREADY→candidate6/6physicalarrived0sweepblocked;
13validactorsbyteunchanged. Action/key/generation,positions,queues/cohort preserved.
Только offlinepatrol при new resolver ready; Nico footprint helper включён
как явнаязависимость. Общийcost synthetic alignedsum19fixtures p50/p95
.0186/.0209→.9860/1.2162ms, неfullcallback/FPS. После rootreview нужно actual
production test mode без substitution; до review неapply. Crewteleport/car
copassengers — root/transport, не дублировать. Guardkind идёт отдельно позже.

Read-only аудит следующего участка готов: `NPC_BOSS_WALK_BINDINGS23_AUDIT.md`.
Все 19 в capture22:29:59Z имеют offline patrol, не authenticated world activities.
Охрана, сопровождение, набор и отступление физически существуют. Missing:
native site identity в выборе цели/постов (root scope); отдельный collect/inspect/
defend/invest arrival executor; native directed routing для guard/recruit/retreat;
authoritative NPC-vs-NPC итог, поскольку server advance считает войну отдельно.
Root получил audit и предложение одного bounded collect-визита на существующем
собственном native site, без клиентского дохода и нового здания/HQ.
До нового разрешения runtime freeze; возможна isolated модель lifecycle.

Модель теперь сохранена: `NPC_COLLECT_VISIT23_CANDIDATE.md`, pure helper и
7 групп tests PASS. Только isolated, нет импорта world/Walk и нет native adapter.
Exact arrival + holding/owner/site gate, once-generation, отмена/освобождение
паузы при бое/смерти/смене приказа/владения. CPU19calls p50/p95 .0029/.0034ms,
НЕ полныйupdate/FPS. Серверные деньги, позиции и здания не меняются.

Следующий isolated repro готов: `NPC_OTHER_EMPIRE_ROUTES23_CANDIDATE.md`.
Guard/recruit/street_recruit/retreat coarse маршруты на 6 избранных geometryinputs
×4kind:12/24arrived,16unsafe; nativecandidate24/24arrived,0unsafe/blockedsteps.
20actualpump отмена/same-frame PASS. CPUtotal354→65ms, но p50 .846→1.297ms;
не FPS и не representative city. Runtime НЕ менялся. Для next scope сначала
один guardkind+реальный LIVEpost, не автоматически все четыре.

Ещё отдельный repro: `NPC_CACHED_BOSS_TARGET23_REPRO.md`. CapturedViktorцель
в fixturewater2.22м,42kvisited/1.03sCPU EMPTY; Musa bodyblocked/EMPTY.
Повторный СУЩЕСТВУЮЩИЙ nearest helper после geometryready (без Nico нового
фильтра) даёт обоим23/32visitedREADY и physical13.20/42.17м arrival.
Нет production invalidation hook: cachedtarget остаётся при sameaction,
registerNativeResolver только initialsafeplacement. Startup timing — гипотеза,
не captured evidence. Root уведомлён. Runtime freeze сохранён.

Проверка19targetsonly:13point/body/footprintOK,6invalid — Leila/Alisa/Viktor
depth2.22,Inga point/body/footprintblocked,Musa bodyblocked,Nico толькоfootprint.
Leila/Inga activecapturedpending; Alisawalkingtrueнеозначаетsafegoal.
Отчёт `empire_live_route_replay23_all_boss_targets.json`, planningSkipped:true,
это НЕ19routefailures и НЕwholecityLIVE. Production не менялся.

Sixinvalidreselection replay завершён:6/6physicalarrived, fullbodysweeps0blocked,
путь13.20–56.25м; отчёт all_six_invalid_reselected. CLI теперь проверяет каждый
реальный шаг sweep, поддерживает --summary/--inspect-target/--reporttag.
Это кандидатная подмена goals, НЕ lifecyclecachefix; next приоритет именно
cachedtargets invalidation перед collectвизитом, после снятия rootfreeze.

ПОЗЖЕ: координатор20 послеreview разрешил одну строку escortretarget.
Она теперь IMPLEMENTED/READY в world. Production test `--require-fixed` читает
fixed branch дословно, без candidate substitution. Guard/cancel/pending19bosses/
syntax7 PASS. Координатор включит в общий reload вместе с Ehold bugfix.
С этого момента runtime freeze до SHA; Nico дальше только isolated candidate.

Nico candidate готов изолированно: actual pavilion002 goal проходит5bodypoints,
но полный stationary footprint blocked. Кандидат `_nearestEmpireWalkPoint`
выбирает полный свободный footprint26.5/148.5,actual43.804м route/9.571simsec
arrival PASS. Новая стоимость снижена сортировкой прежних finite ring probes,
300parity PASS, isolated p50/p95 .039/.067→.119/.155ms. Production НЕ менялся.
Документ NPC_NICO_TARGET_FOOTPRINT23_CANDIDATE.md описывает ограничения и код.
Сохранён переносимый scalar fixture empire_route_capture23.json, чтобы не
зависеть от Downloads. Следующий шаг — broad bounded target-selection review
по этому fixture и LIVE от координатора; текущие новые targets не объявлять
готовыми для всех NPC по одному стендовому маршруту.

Bounded actual pavilion matrix выполнена169точек:21старый unsafe footprint,
candidate меняет ровно21 и сохраняет148, missing0, sorted/brute parity169/169.
Это дополнительный readiness candidate, не разрешение менять freeze runtime.

Свежее23Sep01:29local: координатор передал штатный export
`C:/Users/Слава/Downloads/npc-inspection-1790116199540.json` (22:29:59Z).
Новых production edits пока не делать — до следующего общего LIVE-пакета.
QA поля загружены; escort cancel patch был позже reload и ещё неLIVE.

Доказан следующий isolated candidate: София12 ищет старую цель30.5/72.5,
хотя formation уже27.5/80.5 (>5.2 drift). Ready route обновляется, pending
игнорирует drift. Candidate одна строка coalesce, без нового поиска/бюджета.
Actual crew regression PASS; actual target GLB geometry:6000visited/EMPTY
→35visited/READY, физический путь48.785м пройден10.571симулированных секунд,
без телепорта/blocked segments. См. NPC_ESCORT_RETARGET23_CANDIDATE.md.
Это CANDIDATE, НЕ production и НЕ LIVE. У Nico иной текущий failed goal, у
Marat6 уже почти arrived formation — stale pending покрывает прошлый patch.

Работа продолжена. Второй короткий patch: отмена устаревшего empire_escort
при прямом следовании/прибытии, helper+2call в мирной crew ветке world.
Координатор20 явно согласовал scope; actual branch/pump и native geometry PASS.
Подробности/manifest: NPC_ESCORT_CANCEL23_HANDOFF.md. Также готов штатный QA
export empireRequest/empire/search для точного следующего repro Nico/sofia25.
Координатор включил QA в общий reload и обещал экспорт после него; LIVE остаётся
только у него. Ни whole-city behavior, ни FPS ещё не приняты.

23 сентября2026. Чистое продолжение зависшего Художника20; общий координатор20
`01a0bc08-cb3e-7181-be11-a53aaee54535`. Прочитаны ARTIST21_HANDOFF, актуальные
шапки COORDINATOR_20_MEMORY/NPC19_TEAM_BOARD, арт-канон, agenda18 и память19.

Первый bounded patch IMPLEMENTED/CPU TESTED: завершённая группа маршрутов
открывает следующую в том же кадре, сохраняя4мс/8допусков и приоритет старших.
Подробности, проверки, limits и точный пакет: `NPC_COHORT_DRAIN23_HANDOFF.md`.
Из world менялась одна строка `_npcReserveRouteWork`; root согласовал этот scope.
Не трогались `_npcFinishRouteWork`, вода/наёмники/телефон/транспорт/perf-пакеты.

Есть доказанный механизм лишнего ожидания, но не доказано, что он полностью
объясняет LIVE15.863с resident205. У205 agenda walk, seek_shop — stale phase.
Реальная геометрия/actual functions проверены; LIVE и full-scene perf ждут
единственную вкладку координатора20. Новые GPU-вкладки не создавались.

После source READY следующий участок — read-only разбор индивидуальных целей
боссов и физической охраны по actual export (empire_escort долгий pending), затем
согласованный короткий patch. Mercenary staged follow root/vehicle не дублировать.

## Начат read-only разбор следующего участка

В water-before23 охрана Лейлы1–4 имеет age1106–1227сек, но pending=false,
queuePosition=-1, routeRemaining=0. Эти числа — возраст старой заявки, НЕ
доказательство непрерывного ожидания в очереди. Source age/waitMs экспортируется
без pending-gate. Прежде чем чинить очередь охраны, различать намеренное нахождение
рядом с лидером, отсутствие нового заказа и реальный pending.

Доказанный долгий active pending: unique_niko516.433сек,1017expanded/1100visited,
86quanta/298.9ms накопленного CPU, queue105; empire_crew_sofia_25 66.202сек,
expanded3/quanta4/queue190. Niko далеко от текущей ограниченной presentation выборки;
его `_empirePendingRoute.goalR/goalC` в routeReplay отсутствуют (goalR/goalC null).
Для точного actual replay следующего дефекта нужны goal/targetKey/generation,
а не предположенная цель. Production нового участка пока не менялась.
