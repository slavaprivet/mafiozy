# Художник 22 — текущая память

Прямой преемник Художника21, chat `01a0eeca-67c0-7160-9f41-b86362cc05c9`.
Прочитаны ARTIST22_HANDOFF, свежие и поздние секции ARTIST21_MEMORY,
COORDINATOR_22_MEMORY, MIGRATION_BOARD и AGENT_HUB.

## 30 сентября, позже — тени, recovery и видимые действия

Пользователь прислал скрин с чёрными точками тени под шеей NPC/героя и под
шляпой героя. Actual3 GLB/material audit: NPC opaque, без alpha-hash/normal/AO
maps; shared directional sun Soft Low2 при 4096/16bit. Причина общего shadow
filter/self-shadow пока гипотеза. Рекомендация Root22: same-pose GPU A/B Low2→
Medium3, затем HARD0 диагностика, сохранив реальные тени. Точный порядок
`outputs/artist22_npc_shadow_audit/ROOT_AB_ORDER.md` SHA
`ac99a678d243f3e726f8c0c6883ea0ad0dbedbe4a7f17ac69a133a4e2b85c471`.
NPC receiver-off script SHA `518649827e5858a863db75e7a1012d39992675a30a593f72f111be501ccb2bf7`
только diagnostic 159PASS, НЕ подключён. Hero/main/light/GPU только Root22.

Recovery agent frozen: `npc_ragdoll_host.gd` SHA
`ca079b9c6df96b6ce5928493ea5ec6f8e54cf103fb12395ea358b83c8ad6cbbb`,
`npc_ragdoll_recovery.gd` SHA
`0ca1957ec97a3681efcfafcb738039fc2daada4fcf12a27b52be0a413cc89107`,
`outputs/artist22_npc_recovery/RECEIPT.json` SHA
`90835afa1ab5a2010a8bbd4d7adb1b1a14ab22db7c21f34bf20bc59dc9027792`.
Core10261PASS; recovery fixture561checks/4 retained acceptanceFAIL;
actual-main156checks/2 retainedFAIL: 169/252 stand,72 retries/HOLD due full-skin
initial 2.456mm floor overlap. Restun, final-death, car obstruction and failed
resume guard safety pass. ACTIVE step CPU actual-main p50/p95 233/384→285/598us;
RISING 2351/3721us is too costly to call optimized/full-game ready.
Source gate/host/gameplay not wired; worker now reviewing exact optimization.

Root22 says visible NPC action priority after weapon LIVE. Own host WIP extends
three-stage preview from 2m out/back to bounded varying ~3.25–3.95m circuit,
source-admitted native routes, idle head/chest look on actual rig. Initial actual-
main headless exit0: moved3.10–3.55m, max head turn .20–.24rad; no LIVE.
Static directions and max2 route attempts/frame added later, tests pending Root
GPU QUIET release. This is explicitly visual preview, not original source agenda,
HP/progress or authenticated active city. User wants richer package and cost proof.

## 30 сентября — физическое падение, автомобиль и вставание

Новый прямой запрос пользователя: окончательная смерть — физическое падение
вместо старой анимации; машина должна сбивать NPC по скорости/массе и
проезжать телом без «столба»/застревания. Дополнение: после **несмертельных**
ударов NPC всегда пытается подняться; окончательно мёртвый не встаёт.
Root22 владеет source HP/authority/main/export/LIVE/Git; ФизикаАвтомобилей12–13
владеет native car/underbody/wheel. Наш участок — собственный NPC host,
source response, rig/ragdoll/get-up, tests/docs. Не утверждать LIVE или готовый
переезд по headless.

Физическое падение core: `npc_ragdoll_host.gd` SHA
`b89366a7a771302ad9db283b2f89c0441b3a0a0b98b869fcf123c774dbb3990a`,
receipt `outputs/artist22_npc_ragdoll/RECEIPT.json` SHA
`52227cbd92e115f4f863871d475019d9a8373cc4da2acaf468154eee0ccb457b`.
Godot4.7.2 actual3 source rig/core 10261PASS exit0, 16RigidBodies/15joints,
28bone pose, no duplicate accepted J. `preview_resident_host.gd` current frozen
SHA `64e2ce14c8db3b6423bb03630d5be0b7586e5c4bb09bd763ca50c2b42c92a278`
adds transient collider target identity, physical_life_current independent of
owner.dead/capsule, prepare_physical→activate_physical→step writer, IDLE stale
cleanup/ACTIVE failclosed/same-frame corpse footprint. Actual-main staging
test SHA `252af22c220504e65018a0f0868d49941de2d1e6f0cc3522e631ae2e6431490a`
exit0, TEST_ONLY final-death resident72 moved .881m over120frames, old host73PASS.
Independent own-host review `outputs/artist22_resident_physical_peer/REVIEW.md`
SHA `091b3f2e058b5cc69dc54cce8cece5fc9d61f9ba1f302b83a230233bd826a254`,
three actual-Godot final runs exit0/errors[]. Root+Hub informed. Current source
HP/actual completed death provider, real gun contact and LIVE still not wired.

Actual unchanged `NativeVehicleBody` compact sedan against all3 source NPC
ragdolls **25471 checks, 9 FAIL**, acceptance exit1: dragged under chassis
7.6s, final13/15/16 contacts, joint stretch up to.418m, floor capsule
penetration up to.186m. Four current wheels are RayCast3D, no collision shapes.
See `outputs/artist22_npc_ragdoll/HANDOFF.md` and explicit failed logs.
Physics owner received exact test path/SHA and works on geometry; his first
chassis-only receipt EB268 has self-state binding blocker and stays proposal-only.
No collision layer bypass/shape deletion. Source vehicle-pedestrian numeric
response helper `npc_source_vehicle_pedestrian_response.gd` SHA
`3a04de9a2513c4eba6d2379692e1c2d092e6d14dd29a17d751802e0694476933`,
773author+557peer PASS, source speed/cooldown only; no HP/J authority or
invented car-mass multiplier. Root+Hub received packet.

Current next step: dynamic_review builds source recovery gate from actual
NPC_RECOVERY20; capture_plan builds NPC-only physical safe-rise/fullskin clearance
and adds narrow post-peer ragdoll recovery API. Nonfatal body must retry getup
after source release while clearance blocked, preserve crouch/medicalDowned/
forcedCrawl and final-death priority, avoid animation teleport. No current
recovery or LIVE claim. Separate original-source FIRST getter capture03 packet
`outputs/artist22_first_getter_arm/RECEIPT.json` SHA25d8d664… is CPU-reviewed
but GPU/runtime capture remains Root GO HOLD. Agenda prefix320d7de5 and hit
presentation745b50da component-only delivered Root+Hub, not game AI/HP.

## 30 сентября — срочный видимый NPC-срез по прямому поручению пользователя

Пользователь потребовал добавить NPC в игру сейчас и наблюдать поведение; Root22
согласовал расширение Artist22 scope на `preview_resident_host.gd`, сам владеет
`preview_population.gd`/main/export/LIVE/Git. Никакого второго GPU-окна у Artist22.
Все три оригинальные raw birth cells принятого offline new-session packet оказались
roadMask=1 для узкой preview policy; не объявлять их разрешённой outdoor placement.
Для QA отдельно явные PREVIEW_STAGE позиции у машины, оригинальные source IDs,
descriptor/models/birth packet неизменны. `preview_resident_host.gd` SHA
`326daf9e28717c44ef5a96484fa495a3f94a5179f03c735d9da9bdf0d1158878`:
source+physical gated stage, Godot native nav/CharacterBody, bounded walking
exercise, new guarded request on blocked/stale, snapshot placement_mode.
Official actual-main Godot4.7.2 headless: legacy73 PASS, new stage3/3 travelled
1.8557–1.8600m in600physics frames, CPU host+walk p50/p95 .622/1.035ms;
not LIVE FPS/full326/source agenda/authority. Tests SHA70f594bb/ba1d5773.
Handoff `docs/godot/NPC_ARTIST22_VISIBLE_STAGE_HANDOFF.md`. Root22 owns sole
LIVE acceptance, export currently in progress at last message. Do not alter host
while it is packaging. Dedicated current-access denial180frames remained stopped;
restore resumed a new guarded route within540frames (official headless exit0).
Root independent same-frame overlap test found physics broadphase delay; fixed
owned-body footprint reservation pre/post asset loading. Exact independent
actual-main29/29 PASS; result `outputs/artist22_overlap_acceptance/RESULT.json`
SHA292c597d. Legacy73/new staging+deny/recovery tests PASS after fix.
Root's sole-window GPU comparison still pending; PNG readback QA hang is a
harness issue until isolated from gameplay. Root revises mouse-capture startup.
UPDATE: Root22 retry05 BOTH LIVE PASS; sole new game PID37616/PCKde2728bb,
3 NPC actual travel6.909/8.550/5.690m over12s. Same1280×720/1731drawnframes:
frame p50/p95 off6.987/8.220ms→NPC7.020/8.747 (+.527p95), render monitor
6.923/7.389→6.944/7.194ms, physics1.338/1.564→2.562/2.901ms,
drawcalls1021→1161/primitives503932→639740. Full city FPS not measured; no
improvement claim. User sees exact3 staged residents; preview walk is QA only.
New user order: continue NPC with own subagents; Root integrates all packages.
dynamic_review owns original agenda state/effect producer, mercenary_review owns
source hit presentation only (no local damage authority), capture_plan owns
unpaused arm-at-registration transformer+FIRST getter reader; all GPU-free.
Root capture03 disarmed collector1b5ea4/receipt889871... complete in separate
background subagent; reader/transformer untouched, source GPU capture paused.

## Согласованный участок 29 сентября 2026

Root22 `01a0eec3-2733-7130-9aea-c289c76574af` подтвердил:
1. Закончить dynamic/mercenary frame + input_proof_receipts и независимые проверки.
2. Подготовить original capture plan: launch/source SHA, isolated profile,
   FIRST lazy getter, bounded success/abort, renderer cleanup.
3. GPU HOLD. Единственная игра восстановлена root, сообщённый PID42040 —
   это сообщение, не наш свежий process inventory. Не останавливать её.
4. Не менять main/preview_resident_host/player/project/export/combat/Git.
   Root agent владеет melee_contact_selection. Lead14Astra — Проверщик.

ToolSearch/Ruflo не доступны в inventory; используем файловую память.
Новые собственные субагенты: capture_plan (после аудита узкая правка capture
script), dynamic_review (read-only ce4 + новые независимые tests), mercenary_review
(read-only новый exporter/native + новые независимые tests). Это не Astra.

## Работа текущего пакета

Exporter mercenary 1f992349 не сохранял frame/proof_receipts, обязательные в
native capture admission. Исправлен: frame и глубокая копия input_proof_receipts;
safe-integer revision; capture требует явный fixture_only=false.
Новый exporter SHA `76ba432338ff2673062d88b3695af4a424afaddd7d12bff8cd6dd7f0c80e1d8d`.
Native EXPORTER_SHA обновлён, остальной код на момент этой записи прежний.
BEFORE bytes сохранены в outputs/artist22_mercenary_author.

Авторские проверки: 132 Node PASS (22 реальные original constructor case,
20 HOLD + новые envelope negatives), actual Godot4.7.2 180 PASS.
Native setup p50/p95 687/851 us, collections 28.2/29.79 us,
2 warmups + 50 compact fixture samples. Это не FPS общей сцены.
Независимая проверка ещё идёт, пакет не объявлен принятым.

Capture audit нашёл старый hardcoded PID43848, неполную FIRST getter цепочку,
таймер только после goto и неполный cleanup early failures. Исправление
поручено capture_plan без server/browser/GPU execution.
Debugger capture всегда diagnostic и НЕ uninterrupted birth baseline.
Никакого actual current source frame пока нет; fake defaults/renderer/storage
substitution запрещены. Source_capture-shaped QA canary — только тест схемы.

Независимая проверка завершена: mercenary45 Node +192 Godot PASS;
dynamic ce4 новый677 + inherited3903 PASS. Дефектов в проверенном scope нет.
Dynamic receipt все13 файлов parent hash-checked. Полный frozen packet передан
Root22 и штабу через app tools: outputs/artist22_frame_delivery/DELIVERY_RECEIPT.json
SHA dca6aa4058acbe3a13d9132d8416ebdc0fca313952788d63afe575870ceeb5fe,
42 скопированных файла 2679717 bytes, все copy hashes проверены.
Handoff docs/godot/NPC_ARTIST22_FRAME_COMPONENTS_HANDOFF.md содержит root hooks.
Это CPU-ready component packet, не production acceptance/actual capture/FPS.

Root22 сам сверил все42 copied files dca6aa и принял bounded CPU prerequisite.
Дополнительный root seam: dynamic.configure читает точные .gd contact bytes;
compiled-PCK source availability ещё не доказана, pin нельзя отключать.

Capture script fix + independent review завершены: author49 + independent97
PASS, inherited49 independently rerun. Frozen capture be62ca1b7c28c6b9b574d77fbe270929813ef9b728cf99f0d3be58528cf72f22;
lifecycle5c2b5aa01635bd76f1745cf7d9ed560ee420188e4224fbbc562119d93e2392ae.
Packet outputs/artist22_capture_delivery/DELIVERY_RECEIPT.json
SHA3a2bf2bd85123b84205f12d2fb974d4804118243d29dab119a4e70eb039e3e40:
43copied files5777702bytes, source/copy/independent hashes verified,
передан Root22+штабу. RootGO не создан. Browser/server/GPU/probe NOTRUN.
Root_restore_allowed всегда false: actual Chrome/CDP/Windows cleanup untested,
нужен root inventory descendants. Debugger timing не uninterrupted births.

Root22 поручил concrete unpaused capture path после diagnostic plan. Собственный
mercenary_review только read-only sources/docs в outputs/artist22_unpaused_capture_path.
Lazy row accessors и actor.position.y означают: deferred serialize не snapshot,
дополнительный y read вызывает ground. Complete-frame missing natural ground HOLD.
GPU HOLD сохраняется. Root QUIET START принят: тяжёлых PID нет; только чтение/доки
до отдельного RELEASED. Native inputs/body/export root frozen.

Позднее Root22 явно RELEASED CPU quiet: его baseline/after braking22 PCK QA PASS,
единственная новая интерактивная игра сообщена PID43120, PCK14a1e0de.
Это root-сведения, не наш свежий inventory; native/GPU не трогать.
CPU/headless своих scope можно; источник GPU всё ещё HOLD без отдельного GO.

Unpaused path завершён parent review, только документация:
outputs/artist22_unpaused_capture_path/NEXT.md SHA526f16c346e3f5ecf50bb1b58a1c20eb1734101141c4b8bf5f3fe51e6387c2f2;
PLAN.md SHA19df04c24485ba3727cd661f05bcee1cdb3db519de88bde3f9ca425378d5c9d8;
RECEIPT.json SHA7a102616fafb19bf63144de623010c28ab3538fdbbf35446e68605530e65bae4.
15 source hashes parent verified, unique anchors/byte offsets recorded. Plan author
был остановлен после сохранения полноценного plan; parent исправил неверную дату
на29SepMSK (clock20:35Z), убрал двусмысленное paused и добавил concise NEXT.
Никакой observer implementation/GPU/source mutation/performance measurement нет.
Передано Root22+Hub. Следующий предлагаемый scope — bounded scalar natural-output
observer + source-byte transformer/CPU semantics tests, separate NEW plan/rootGO.
Не расширять full-frame acceptance: natural unvisited ground отсутствует; отдельный
static replay только DERIVED с equality proof. Existing registration roster не
история birth events. Инструментация имеет стоимость, не pristine/zero-impact.

Все текущие bounded implementation/review пакеты сданы. Родитель не делал
stage/commit/push, GPU/server/browser запусков или main/player/host правок.

## 30 сентября 2026, 00:00 MSK — unpaused observer реализован

По свежему прямому поручению Root22 выполнен executable observer, не новый plan.
Новые scoped files: tools/godot/npc_observer_transform.mjs e944293c65cc23d4df659c70ed1a68644e3a57e3f94e4ac599fd4eb8b782a3d6;
npc_observer_collector.mjs ca7df2b4f3c907c8d24ed5336c63a3b92a703de563b3f2d8e8248b7e16b24bdd;
read_npc_observed_roster.mjs 6623ac0fe70b3bd0161d04444d417ee5a660aeb9b41d44e4e09e9d025efcff3a;
capture_npc_unpaused.mjs c6c3611c6fa2f9f8e6aadc7bc5f072c0df33e719c863f676720429a75e20ad7e.
Original6 source files unchanged. Old paused diagnostic be62/lifecycle5c2 unchanged.
13 exact HTTP response bindings:6 transformed+7 unchanged entry/navigation/traffic/rail.
Collector primitive bounded fixedbuffers; overflow/unsupported/missing -> HOLD.
Actualsource exception/receiver/order/lazyreads preserved in CPU tests; unknown
ground, optionalgateundefined ambiguity, incompletecolliders never promoted.
Reader only prequeue sourceordered roster; no currentframe/birth/alias/authority.

353 CPU checks PASS: collector99, transform70, reader41, independentsemantics92,
independentrunnerguards51. Actual original→transformed fixed workload cost p50/p95
ms getter1.1128/1.6986→1.7336/2.1615, support.2362/.2643→.5568/.6084,
logical.5879/.7902→1.3635/1.7620; same naturalreads/results, nooverflow.
Snapshot8192events later offsource p95 60.405ms. Это заметная diagnosticстоимость,
не 4/2ms slice admission, не sceneFPS/GC/RSS acceptance. Runtime untested.

Frozen delivery outputs/artist22_unpaused_delivery/DELIVERY_RECEIPT.json
SHA6a3d94f9c723f836714477649d07c672b7dea63aa35eebb2c160d751a369e2cd,
71copiedfiles11218630bytes verified source/copy/profile closure.
Final profile outputs/artist22_unpaused_profile_final/PLAN.json canonical
SHA015fac0d4671a9bd18aba35f34995e6269821d1ac010aee7c2c94a7bc47ffc35.
v1profile obsolete; current final executable prepare/write noGO PASS.
Handoff docs/godot/NPC_ARTIST22_UNPAUSED_OBSERVER_HANDOFF.md includes exactcommands,
API/cost/limits; tests/rawcost/logs independently pinned in delivery.
No GO generated. No sourceHTTP/browser/server/GPU/native game changes. Root fresh
exactplanGO required; parent exits != descendantproof, root_restore_allowed false.
Root temporary CPUquiet honored then RELEASED; GPU still HOLD. Root confirmed
latest staticlandscape SHA4e22e66258f4b013c5ab0f152e0a4d104f7a61eb7a2cba9f80b8b7799fa907b1;
old85b30272 pointer historical; Root own6739 staticwater checks not dynamicbinding.

## 30 сентября 2026, 00:16 MSK — actual run01 failure/fix01

Root22 singleGPUwindow ran finalplan015fac with freshGO (sourcebrowser only after
normalclose sole game43120). `outputs/coordinator22_source_capture/run01/RUN.json`
SHAe616c21bb8d40397ce58559b8da4ea4c948ee586628a6e1fc620b2114c5beba1:
original HTTP preprobe13 exact; fulfilled /walk, original walk_entry, transformed
world9f5cc5→fd79a7. Collector events0, `page.evaluate Execution context was
destroyed` at original `/walk`→`/world.html` location.replace. HOLD, no frame.
Browserownedkill PASS; serverPID15920 identity SKIPPED because UTF8 PowerShell
misdecoded Cyrillic full commandmarker; Root independently inspected/killed only
owned server, descendant inventory clear, restored exactPCK14a1e0de sole game
PID17312 at00:05:05MSK. Source runner must not claim success or userstate.

With Root FREEZE RELEASED fix01 new runner SHA
2fce8c6000d42f5f4740ea591298b23a3f1e3c524a55f0e5d7afe905e00a98a8:
strict two natural sameorigin documents, wait final DOMContentLoaded, fulfilled
worldSHA exactonce, currentworld bootstrap and history checked to snapshot,
ASCII processmarker `city_rebuild_monitor.py --port 18538`, shared cleanup helper;
cleanup failure forces HOLD. New finalprofile PLAN canonical SHA
e50b2a444e6e68c308401eca745499ed4c4aa4ea8e9710ca2added033bb71a37,
outputs/artist22_unpaused_profile_fix01. Old GO used/expired, old profile obsolete.
CPU nav11 original walk_entry, pure guards51, realCLI Python monitor port19139
forcedfailure cleanup7 ownershipkill/exitPASS; independent reviewer54 PASS on exact
new runner/plan, no new actionable findings. No repair browser/GPU/game launched.
Frozen fix01 delivery outputs/artist22_capture_repair/RECEIPT.json SHA
dc670bea4691ea250b2bdb7968981799517ec252a59c520e68566be102b1980b,
47files11008167bytes source/copy/planSHA verified. Handoff
docs/godot/NPC_ARTIST22_CAPTURE_REPAIR01_HANDOFF.md; Root+Hub sent once.
Root owns next short GPU window/GO and runtime restore; on runpath verify actual
roster/errors/cleanup. Observer partial roster alone lacks birth/look/currentstate/
all326placement/support/dynamics for existing preview_resident_host admission;
minimum in handoff. User/root prioritizes visible NPC with quality/perf first.
