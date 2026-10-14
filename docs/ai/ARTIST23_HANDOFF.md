# Художник 23 — передача NPC от Художника22, 30 сентября 2026

## 30 сентября ~16:25 МСК — причина недоступного входа NPC в типографию

`outputs/artist23_actions_source/RAMP_CLEARANCE_AUDIT.md`: в актуальной
headless-сцене реальная public дверь запросом открылась полностью, но старый
физический квадрат host отверг все 61 точки исходного входа: на пандусе он
пересекает пол, у порога также дверь/стену. Диагностический запрос точной
капсулы NPC 0.36×1.9м при y+2см не пересёк препятствий в этих точках;
дополнительная точная капсула-реплика с настоящей гравитацией и floor snap
непрерывно прошла 3.25м внутрь (122/122 кадров на полу), вернулась (117/117),
без заблокированных кадров и без отключения пола/двери/стен. **Три исходных
NPC не двигались**: это доказательство геометрической проходимости, не
действие зарегистрированного жителя, source agenda или LIVE.
При закрытой настоящей двери парная проверка остановила капсулу на x5.686:
87 кадров blocked и реальная коллизия SourceDoor_public; обход двери не нужен.
Отдельно outdoor source policy отверг 31 внутреннюю точку, а дальний маршрут
resident169 ранее остановился на x21.908/y−0.0324. Для настоящего посещения
нужны one-entry source lease, безопасное движение по пандусу и проверка двери,
стен и обратного пути; ничего не отключено и LIVE не заявлен. Входной пакет
сохранён без изменения. Root/HQ уведомлён.

## 30 сентября ~15:45 МСК — исправлен порядок source random, isolated HOLD

В `outputs/artist23_rpg_sever_bridge/stage` обнаружил и устранил расхождение с
`world.html`: `_markCombatBleeding` делает 50/30 случайных выборов для струи
крови и 4 для следа **до** шанса отрыва, а успешный `_maybeSeverLimb` делает ещё
5 выборов эффекта **до** медицинского survival-roll. Прежний кандидат пропускал
их, поэтому мог выбирать другую конечность/исход жизни. Исправлены только
`npc_local_preview_hit_owner.gd` и `npc_source_sever_rules.gd` в isolated stage;
новые seed-проверки учитывают исходный порядок. Loaded original-three-rig
matrix **835/0**, export PCK `da56e708befc698d22ca33312342d870a597490a127bb204047a16cbbafb2281`,
compiled ordinary **781/0**. Подробности и ограничения —
`outputs/artist23_rpg_sever_bridge/HANDOFF.md`. PRNG Godot и JavaScript разные:
подтверждён порядок вызовов и формулы, не битовое равенство случайных чисел.
Shared runtime, открытая игра, GPU и Git не менялись; нога/RPG blast всё ещё HOLD
до текущей Root23 интеграции и LIVE.

## 30 сентября ~15:00 МСК — RPG/leg-sever совместимость, isolated HOLD

`outputs/artist23_rpg_sever_bridge/HANDOFF.md`: старый RPG lifecycle из
соседнего пакета при копировании целиком стирает уже принятый lethal anatomical
headshot. В отдельной stage перенёс только admission-kind строку и связал
одноразовый native RPG target ticket с текущим HP/физикой/правилом
отрыва ноги. Получатель блокирует повторный вход; подтверждённый HP создаёт
32 частицы в существующем пуле112, но без выдуманной раны/капель из кожи;
исходное состояние кровотечения сохраняется, повтор receipt не создаёт кровь.
Поздний Root23 `outputs/coordinator23_rpg23i/blood_proposal` проверил точный
физический anchor после медицинского падения и получил native118PASS. Для
current23h выбирать его более строгий blood adapter/renderer; мой ранний
burst покрывал IDLE до падения и не должен подменять новый пакет Root.
Толчок взрыва равномерный, без точечного вращения; импульс оторванной ноги
вычитается из общего. Loaded 3 исходных рига: 831/0; настоящий gun/head/leg regression
781/0 в compiled PCK `edb64409c2fdeb359e96c5993f2723d130cf5b7cd3c4a5dd32e582c16522d2fc`.
RPG recipient 22 проверки используют явный TEST_ONLY ticket double. Ещё 28
проверок в той же загруженной сцене провели настоящий source Fire/Inventory/
Flight/native query через три оригинальных NPC с test-only root callbacks:
1 запуск/1 запрос/1 impact, урон195/108/115, два final и один medical,
у первого закрыты глаза, оторвана исходная нога, толчок439.4634 N·s без
точечной torque; через60 кадров нога2.377м от pelvis, 3 контакта пола.
Replay не дал повторного HP. Отдельный mock: damage160, HP0, mask4,
total420.7317 N·s без удвоения (380.7317 тело +40 нога), нога3.478м/2
контакта. Native gate отдельно445PASS у sibling. **В принятом root/game
хуков ещё нет; test-only callback не LIVE.** Требуется Root review/current-build
integration и GPU/frame/memory проверка. Shared/Git/игра/GPU не менялись.
HQ предупреждён о риске регрессии headshot.

## 30 сентября ~14:00 МСК — проверен source hit → физический отрыв ноги, кандидат HOLD до LIVE

Изолированный полный пакет `outputs/artist23_sever_hit/HANDOFF.md` поверх принятого
23g: 13 пушек × 3 исходных NPC, native receipts/HP/head/marks, 781 checks/0 errors.
При окончательной смерти source-выбор ноги подтверждается той же HP-квитанцией
и ACTIVE ragdoll; sniper 135 N·s разделён без удвоения импульса, нога через
60 кадров отстоит на 1.618 м с 7 контактами пола, глаза закрыты. Compiled PCK
`fcce07b7a33d6eb88ccbb000fb838a60624ab8e5e0c45c48de26e390b83cd035`
прошёл повторные 781/0 через `--main-pack` без GPU. Источник
предложил ногу живому медицинскому пострадавшему — HOLD без смены маски/сустава,
пока нет оригинального ползания и безопасного вставания. Руки HOLD из-за skin
швов. Selector p50/p95 10/14 µs; matched hit p50/p95 baseline6.076/7.568ms,
candidate5.924/7.473ms в одном прогоне, но candidate p95 ранее гулял до9.453ms.
Это не FPS/LIVE. Root/physics owner должен рассмотреть generic joint API,
explicit export нового helper и провести единственный GPU прогон. Shared runtime,
игра, Git не менялись; HQ — единственный маршрут отчёта.

## 30 сентября ~13:08 МСК — leg detach API кандидат, общий рантайм не менялся

`outputs/artist23_sever_candidate/HANDOFF.md`: additive physical joint API
реализован только в isolated stage, Source hit/HP ещё не подключён. Exact3rig
12/12 attached/detached PASS, generic legacy3193PASS (baseline3197PASS,
разница settle tick), NPC host11838PASS matched baseline11838PASS, recovery
gate9PASS. Дубликаты/неверный ID/arm/rebind проверены; 16 bodies/collisions
сохранены. Один component CPU замер не равен loaded/GPU/LIVE. User 23g
PID12304 не трогали; report только HQ. Следующий шаг — same-life source selector,
полный hit→HP→ragdoll budget и visible art/loaded perf, затем Root rollout.

## 30 сентября ~12:42 МСК — sever feasibility, 23g уже доставлен Root

Root23 доставил accepted23g и один игровой процесс PID12304; в этой сборке
есть head+marks+кровь+foot, но **нет** отрыва конечностей. Подробности Root
в `docs/ai/COORDINATOR_23_MEMORY.md` и `WEAPONS_23G_CHECKPOINT.md`.
Художник не перезапускал игру и не делал GPU capture. Новая независимая
изолированная проверка `outputs/artist23_sever_probe/HANDOFF.md`: exact3 GLB
geometry 0 bridge/skin-cross для каждой ноги, arm seams125–203 tris; actual
16-body physics12/12 PASS, detach52N·s даёт0.823–1.102м против linked
0.112–0.156м, floor contacts/snapshots intact. Source selector13/13 PASS.
Это только feasibility: authoritative hit, one-time joint API, source crawl,
cut cap, rendered LIVE и loaded perf не подключены; shared files не менялись.
Рабочий отчёт направлен только в Общий штаб.

## 30 сентября ~12:16 МСК — wound/head combined проверен, видимое окно исчезло

После пользовательского GO открылся head-only PID30184. Поздний fresh inventory
больше не видит MafioziPreview; Windows Application Error за последние два часа
не найден. Причину закрытия не приписывать пользователю/сбою без доказательств,
повторно игру без нового GO не открывать. Изолированный head+marks+blood пакет
`outputs/artist23_headmarks23e/HANDOFF.md`, PCK
5e07232af7cb8cd7357ca34a7354e474d0645354e7b5a388c3bdba7c8370772e:
compiled actual marks input23PASS, head input17PASS,13×3 native+1mark782PASS,
parallax116PASS,bounds221PASS; native anatomical656PASS. Head mark использует
уже доказанную skin точку без второго полного coarse ray. Matched no-game
first-hit p95 old combo8.478→headmarks8.657ms; loaded walking
head-only1.243→headmarks1.176ms, post-hit .626→.915ms, RAM+5.252MB/3NPC.
Headless/CPU только: shared marks НЕ устанавливались, GPU/визуал/fullcity HOLD.

## 30 сентября ~11:59 МСК — новая единственная игра после отдельного GO

Пользователь дал отдельный GO на одно переключение. Fresh inventory: прежний
point-only PID48272 уже отсутствовал. Открыт ровно один видимый
`outputs/artist23_head23e/package_direction/MafioziPreview.exe`, PID30184,
Responding=true/window6227506, PCK SHA51e4dea55946d803a89f56633f3e61e1c94dcf777448b2287379eea3e817ae3e.
Здесь готовые точный headshot и исправленный физический импульс дробовика;
нумерованный список в игре обновлён. Реальный видимый выстрел и GPU frame-time
ещё не наблюдались, не выдавать простой запуск за LIVE acceptance. Marks/blood
combined пока отдельно HOLD; новый headmarks isolated кандидат проходит CPU.

## 30 сентября ~11:34 МСК — анатомический headshot и направление дроби

Самостоятельно установлен проверенный NPC source-пакет: точный skin-ray после
реального native попадания делает попадание в голову сразу окончательной смертью;
рука перед головой, корпус, стены, invulnerability и medical остаются отдельно.
Импульс дробовика теперь направлен по реальной дробине (при headshot — по
головной), исправляя найденный Root23 parallax 43.15°. Shared owner SHA7e203b25,
head-zone99b61a6e, lifecycle7b01789e, export preset2e32e4f4 включает новый
NPC script. Сохранены старые файлы, Git не трогал. Точный изолированный EXE/PCK
51e4dea55946d803a89f56633f3e61e1c94dcf777448b2287379eea3e817ae3e:
compiled actual player-input17PASS, 13×3 guns743PASS, parallax116PASS; native
head/arm/medical656PASS на frozen и shared. Same-window loaded CPU walking
p95 1.172→1.183ms, post-hit .633→.637ms; +4.48MB для трёх исходных ригов.
Не whole-scene FPS и не rendered LIVE. Точный handoff
`outputs/artist23_head23e/HANDOFF.md`. Единственная видимая игра PID48272
по-прежнему point-only; новую сборку НЕ переключал без отдельного GPU GO.
Persistent marks/blood combined не входит в новый head PCK, остаётся HOLD.
Открыты sever/RPG/medical getup/runover/black shadows.

## 30 сентября ~10:20 МСК — направленный толчок в одной игре, marks combined кандидат

Усиленный NPC shot-point impulse и удаление мгновенного standing slide
установлены только в `scripts/npc_visual`: owner SHA9e019898f91073fe51bb1076c17f8ef73b6c7289fdd4eb2372054f1bb9fbcdfd,
helper SHAfe4ddd5272e6ea0f0b746b003c8254022a561120a867b54088355ffddb53abe2.
По прямому указанию пользователя самостоятельно внедрить необходимое добавлен
helper в shared explicit `export_presets.cfg` (SHA B1500EC4427311B2EAC326832E2A9A595EBDA634C3A232179466D29A4B29146B).
Без Git. Точный handoff: `outputs/artist23_point23e/HANDOFF.md`.
Native merged834PASS, compiled PCK реальный player input22PASS и13×3 firearms743PASS,
matched loaded CPU walking p95 1.097→1.117ms, accepted-hit p95 1.232→1.117ms;
GPU/FPS/визуальная приёмка НЕ выполнены. После fresh inventory открыта ОДНА
видимая игра outputs-only point23e PCK EC737F864181031E574BC4EB9E179A6D70CF3BE6282A6068371B388B25167179,
PID48272, Responding=true/Window18876652 на последней проверке. Не открывать вторую.
Root23 и HQ получили точную передачу ранее; поздний статус Root23 systemError/usage-limit,
поэтому дальнейшее принятие Root в этот момент не подтверждено.

Постоянные skinned skin/clothing marks и усиленная читаемость крови теперь
совмещены с point impulse в изолированном `outputs/artist23_combo23e/stage`;
shared файлы marks НЕ установлены, текущая игра их НЕ содержит.
Оптимизированная spatial cell 0.45m + triangle-AABB coarse query сборка
`outputs/artist23_combo23e/package_grid045` PCK
20B208A3D5932268F3CF4F40A4985DEE91327209179CB91A20413ECCF99BBEBA:
actual player-input23PASS,13×3 native743PASS, cap/barycentric221PASS,
39/39 wound hashes побайтно совпали с базовым renderer. В одинаковом условии
открытой игры loaded walking p95 point-only1.158→combo1.138ms, after-hit
1.064→1.521ms, однократная hit transaction p95 base-combo10.037→optimized7.880ms
(point-only2.910ms). GPU/whole-game LIVE всё ещё pending, поэтому combined PCK
остаётся HOLD и не заменяет единственную игру. Индексированный renderer
24 marks/actor через3 рига p95 1.497ms (агентский component proof).
Точный отчёт `outputs/artist23_combo23e/HANDOFF.md`.
Anatomical headshot остаётся HOLD: latest native_head02 653 checks/9 invalid
arm-cover fixture failures, 7.5–9.3ms ray query; native_head03 timeout до
итогового отчёта. Sever/RPG/medical getup/vehicle runover/black spot shadows открыты.

## 30 сентября 05:43 — обратная связь из 23e, физика и отметины

Update05:57: scoped no-slide fix INSTALLED shared owner SHAaff6e378a23804f55886a86de53e4e59db1439f5a9471d276da0eeec91149e07,
isolated frozen23e native91PASS; `outputs/artist23_no_slide/HANDOFF.md`.
Not packaged/LIVE. No Git by Artist; Root/HQ notified.

Update05:45: marks native03 63/63 PASS actual3rig, first mark6.219–7.511ms,
second9.295–16.737ms, two-mark update.398–.455ms. Component-only; 24cap,
loaded scene/perf and rendered look still pending. Point-split A/B engine test
authorized in next clear window; prior 465PASS uniform overlay remains HOLD.

Пользователь посмотрел стрельбу: падение при смерти оценил положительно, но
требует сильнее направленный импульс, мгновенную смерть от подтверждённого
попадания в голову, устойчивые следы/синяки на коже и одежде и более заметную
кровь. Он уточнил, что реакция Walk слишком слабая, кровь там хорошая. Root23
владеет толчком трупа ногами через player; NPC ACTIVE pool не заморожен,
причина отсутствия контакта — player layer2/mask1 против ragdoll layer256/mask257.

`outputs/artist23_hit_impulse/ready_impulse_only` exact native_ready01 465PASS,
shotgun225 N·s на трёх исходных моделях отбрасывает на1.86–2.11м, medical75
на0.52–1.19м. **Production HOLD:** базовый exit_ragdoll_body.start делит
импульс равномерно на16 сегментов и не создаёт момента от точки попадания.
Root23 подтвердил это; отдельный NPC-owned point split в работе. В этом overlay
убран мгновенный сдвиг стоящего NPC на.369м, но stage
`outputs/artist23_impulse23e/HANDOFF.md` пока не экспортировать/включать.
Медицинское вставание в игре не подтверждено.

Headshot exact native skin-ray: первые12 actual head rays дали final death,
но native01 539checks/6fixtureFAIL и27–37ms/head-hit, HOLD до ускорения и
исправления контролей. Permanent marks actual3rig native02 63PASS, по2
отметины/210вершин/1draw на NPC и сохранение через ragdoll/closed eyes,
но первый hit14–22ms и следующий22–28ms, HOLD до оптимизации и LIVE.
Blood20 подтверждён native, визуальное увеличение отдельно ещё не принято.
Root23 открыл новую 23e PCK023070fe..., PID21024 позже исчез из inventory;
Root уведомлён, не открывать вторую игру. Shared/Git со стороны Artist не менялись.

## 30 сентября 05:18 — единственная игра с выстрелами NPC открыта

По прямой просьбе пользователя и после уведомленияRoot23 открыт outputs-only
`outputs/artist23_combat_next/package/MafioziPreview.exe`, PCK
`d583983b5f559e241247f67403c8e0da93c134f37a199567d1f0e8624224ce22`.
Fresh inventory: PID43212 Responding=true с видимым MainWindow, плюс неизменённый
ProjectManager45268. Root иHQ получили exact PID/path. Не запускать вторую игру.
Пользователь может пробовать NPC hit/blood/final closed eyes. Это INTERACTIVE
launch, но сама стрельба/крупные планы/производительность в новом окне ещё
не наблюдены; compiled-headless20+743PASS из handoff не переименовывать LIVE.
Новые strong impulse/sever/RPG AoE/car no-snag не включены.


## 30 сентября 05:10 — пакет выстрелов NPC для показа

Пользователь попросил напрямую связаться с Координатором23 и дать в игре
попробовать попадания по NPC. Прямое сообщение отправлено по его новому явному
разрешению, общий штаб тоже уведомлён. Точный outputs-only пакет:
`outputs/artist23_combat_next/HANDOFF.md`, PCK SHA
`d583983b5f559e241247f67403c8e0da93c134f37a199567d1f0e8624224ce22`.
Compiled headless20 actual player-input/HP/physical/blood/closed-eyes и743
native weapon-rig matrix PASS clean. Blood optimized loaded CPU path, источник
и ограничения в handoff. НЕТ rendered/LIVE acceptance и текущая игра пока
quality23c без этого пакета; Root проверяет compatibility перед одним
последовательным переключением. Новый запрос на near-shot force/detachable limbs
ведётся отдельно, 225Ns medical directional getup FAIL, нельзя объявлять готовым.


## 30 сентября04:09 — floor seam fix installed, LIVE pending

Scoped shared preview_resident_host SHA f6e95a9000fa2c1c9f64aa7a66c67a3eed7e9bf2edb91a260e20f50d1367f125.
New permanent test_preview_resident_floor_recovery.gd SHA bc5bc433a449e95efc2b0a3bf8201c1db63871826181974d278626701ebb517a.
Native bounded floor recovery fixes the real3cm terrain-seam overlap, with
unchanged source/footprint/collisions/IDs. Same harness baseline15legs BLOCKED,
final27ARRIVED near printshop; all3 pass townhouse005+004. Further goal still
REJECTED; mixed printshop ramp/door/whole agenda remain OPEN with Head/A4.
Installed actual headless39negatives + staging3movement + bound-hit47 PASS,
clean logs. Callback free/dead/dispose/filter/margin/upward guards included.
Loaded NPC CPU baseline615/1033us p50/p95, final601/1036us; not GPU/FPS/fullcity.
Evidence outputs/artist23_floor_seam/HANDOFF.md, RECEIPT.json, INSTALLED.json.
Shared+ownstage edited only host+test; runningNPC23b not restarted; noGit/GPU.
Final root source adoption/rendered benchmark/release remains pending.

Joint-control outputs/artist23_joint_control/HANDOFF.md:12actual controls,
accepted.8/1 only pair passes main211+fixture668 getup. All3pairs productioncar
drag480ticks,37–38kJ total NPC KE; softerjoints notfix. Research corrected-inertia
no-bumper separates but allpairs fail .20m joint bound. Retain acceptedjoints;
actualrunover/getup source integration unresolved. Reported HQ, noforeignedits.
Head1–10 sent concrete A6/A8 fixes; received files HOLD (missing realarrival/
typedsourceACK/currentlife). Root03:57GPUHOLD RELEASED03:59; later freshcheck.

## Актуальное03:40: NPC23b открыт, поздние полномочия пользователя

Сначала читать свежую шапку ARTIST23_MEMORY.md. Пользователь позднее прямо
разрешил самостоятельно тестировать и внедрять без ожидания координатора;
старые запреты ниже описывают исходную передачу. ОднаGPUигра и сохранение
чужихWIP остаются. Git не делать. Рабочиепакеты вHQ.
Также пользователь разрешил прямую координацию с «ГЛАВА ЧАТОВ1–10»
01a0eeca-df53-76d3-afa9-a8ef1a056d37; все10Astra уже назначены им наNPC.

Проверенная видимаяNPC23b доставлена в exports/win64/s01-20260930-npc23b,
PCK6c38e64e866e251715db278dec7fae8d34a76d7127653031c8d84c5121bc4f1f,
interactivePID31088 (сверять заново). Настоящий playerinput+gunmuzzle+ammo+
nativehit→HP→physicalmedicalfall→secondhitdeath: actualGPU23PASS;
same-quarterrenderp957.141ms. ShadowsNPC/hero MediumTAA чистые, basisdrift
walkfix принят. Только3исходныхжителя и7singlehitguns/newlocalsessionHP;
неfullagenda/city/server/save. Blood/social/ambulance/respawn не выполнены.
Vehicleknockdown/getup/actualbumperno-snag остаютсяOPEN.
Точные receipts: outputs/artist23_live/{npc23b,npc23b_input},
outputs/artist23_hit_binding/BOUND_AND_INPUT_HANDOFF.md.

Пользователь прямо попросил новый закреплённый чат Художник23 продолжить эту
задачу. Новый чат `01a0ef91-fe19-75f2-8fde-54cebc289ec3` создан и закреплён;
Художник22 `01a0eeca-67c0-7160-9f41-b86362cc05c9` прекращает production.
Shared checkout `C:/Users/Слава/Desktop/Мафиози`, без worktree. Сначала
читать этот файл, `docs/ai/COORDINATOR_23_HANDOFF.md`, свежие верхние секции
`docs/ai/AGENT_HUB.md`, `docs/godot/MIGRATION_BOARD.md`, затем
`docs/ai/ARTIST22_MEMORY.md` и при необходимости старую передачу21/22. Новый
Root23 `01a0ef87-7a4d-7f73-93c9-8c643602aa04` владеет main/player/project/
export/LIVE/Git и единственной игрой; прежний22 production прекратил. **Все
рабочие пакеты направлять только в «Общий штаб агентов»
`01a0df67-44d3-79c0-b243-fa6a9b891fde`, не напрямую Root.** Текущий короткий
GPU/тяжёлый CPU QUIET23 соблюдать до явного RELEASED. GPU/source capture без
отдельного GO не запускать; не stage/commit/push, не трогать чужие WIP/Astra.

## Что просит пользователь

Реальные NPC в открытой игре, оригинальные действия и модели, плавные
повороты; физическое падение вместо death animation; машина сбивает по
физике, не упирается в стоячую капсулу, проезжает/переезжает без застревания;
после несмертельных ударов NPC постоянно пытается безопасно встать, после
окончательной смерти — нет. Последний скрин выявил чёрные точки теней под
шеей NPC/героя и шляпой героя; нужны нормальные тени. Последнее уточнение —
оптимизировать и сделать пакет богаче минимального. Не выдавать test/headless
за LIVE, fixture death за source HP, локальный preview за оригинальную agenda.

## Текущий видимый пакет — кандидат для Root23

`godot/mafiozi_walk/scripts/npc_visual/preview_resident_host.gd` SHA
`38bd36bae791f964bb403d0482a34251941829a657f664400cc016332c5b2ff0`
вместе с новым `npc_preview_activity.gd` SHA
`3f431c774e923512bdd1a7c5f217f98435716dda5695b2a5ed2e361a7e05fd06`.
Три проверенных исходных resident_72/169/252 на прежних staged местах вместо
монотонных 2m out/back ходят по различающимся кольцевым preview-целям радиуса
3.25–3.95m и плавно осматриваются в паузах. Маршруты проходят прежние текущие
source_admit/native navigation/коллизии. Список направлений создан один раз;
подбор ограничен двумя целями за вызов, отказ повторяется через0.25s.
Исходные тела, GLB, IDs, authority и progress не меняются. Это **preview**,
не original activities и не full-city population. Host также держит
ACTIVE/RECOVERING/RECOVERY_HOLD вне gait/navigation, не подключая source recovery.

Actual Godot4.7.2 `scripts/tests/test_preview_resident_staging.gd` SHA
`41f35299d1f6b1676c6d3af709e97f620730ce8936fdb95fc3397b1da1c2cb6d`
exit0/errors[] после final bounded-route patch: все3 прошли3.10–3.55m;
head turn max .20–.24rad; test-only confirmed physical death сохранил труп,
walking collider disabled. Same actual rigs paired idle component CPU1000
samples: gait p50/p95 7/10us → gait+activity8/12us. В этой headless прогонке
host step p50/p95 621/971us; это **не сравнимый FPS общей сцены**. Исходный
`test_preview_resident_host.gd` 73PASS exit0 после правок. Перед Root import
проверить clean candidate deps: host preloads `npc_ragdoll_host.gd` SHA
`ca079b9c6df96b6ce5928493ea5ec6f8e54cf103fb12395ea358b83c8ad6cbbb`
(native core10261PASS). Если чистый weapon-кандидат не содержит этот WIP,
Root должен включить explicit dependency либо применить только bounded-route/
activity hunks к своему уже принятому smooth-host. Никакого source HP/LIVE
acceptance физической смерти от этого нет. Текущая сцена пользователя эти
новые изменения пока **не показывает**; Root23 должен собрать/проверить.

Дополнительные authored anchors обследованы в
`outputs/artist22_anchor_routes/RESULT.json` SHA
`deba7381c648ddf20a48b42e2fccdd91c2240fb378c10703f3b42bbe326090a9`:
169 дошёл до townhouse005+004 через подцели≤8m;72 остановился
UNSUPPORTED_BODY,252 BLOCKED; lamp не достигнут, printshop goal физически
заблокирован. Это PARTIAL headless, не включать как готовый маршрут/визит или
source progression. По этому результату НЕ менять текущий кольцевой preview
без исправления/повторной проверки.

## Физика и вставание — честные границы

Опциональный `npc_ragdoll_recovery.gd` SHA
`0ca1957ec97a3681efcfafcb738039fc2daada4fcf12a27b52be0a413cc89107`,
full receipt `outputs/artist22_npc_recovery/RECEIPT.json` SHA
`90835afa1ab5a2010a8bbd4d7adb1b1a14ab22db7c21f34bf20bc59dc9027792`.
Core10261PASS; recovery561checks/4 retained acceptanceFAIL; actual-main
156checks/2 retainedFAIL:169/252 stand,72 repeats HOLD due initial full-skin
floor overlap2.456mm. Restun, final-death, moving actual chassis obstacle,
failed-resume guard/filter safety verified. No source release/HP/main hook.
Main ACTIVE CPU p50/p95 233/384→285/598us; RISING2351/3721us, too costly
for full-scene claim. One optimization failed: `outputs/artist22_npc_recovery_optimized/NEGATIVE_RECEIPT.json`
SHA `a9972ac01788251730e19e882c5c50a7addb39b6a47026cf75893d09d918cabf`,
actual RISING2323/3376→2647/3575us. Production exact0ca1957e restored;
reuse-extrema idea NOT IMPLEMENTED/tested. Do not import recovery as complete
get-up. Source pure gate `npc_source_recovery_gate.gd` SHA
`ca98c148277fa223d509ad5d7a9560d58e531e7d2a83c0a9c8a618983470bee2`
566PASS; requires actual source release and full collision clearance.

Current original compact sedan car-vs-ragdoll test still9FAIL for no-snag;
Physics owner has a separate candidate for underbody/wheels, no accepted
production result here. Source vehicle response pure component SHA
`3a04de9a2513c4eba6d2379692e1c2d092e6d14dd29a17d751802e0694476933`
773+557PASS, but source damage/contact authority remains Root/Physics scope.

## Тени и original source capture

NPC3 GLB materials opaque; no alpha hash/normal/AO maps. Shared directional
Soft Low2/4096/16bit shadow filter is a hypothesis for screenshot dots.
Root-only same-pose GPU A/B order
`outputs/artist22_npc_shadow_audit/ROOT_AB_ORDER.md` SHA
`ac99a678d243f3e726f8c0c6883ea0ad0dbedbe4a7f17ac69a133a4e2b85c471`:
Low2→Medium3 first, temporary HARD0 diagnostic, compare hero hat/NPC neck
and comparable frame p50/p95. Preserve real shading. `npc_skin_shadow_candidate.gd`
SHA `518649827e5858a863db75e7a1012d39992675a30a593f72f111be501ccb2bf7`
receiver-off diagnostic159PASS is NOT installed/final, would erase genuine
hat/chin shadows. Hub has received A/B order; Root23 owns actual GPU/light.

Original registered source capture remains GPU HOLD. FIRST lazy getter arm
transformer bcda9d9f, reader3eb05719, collector1b5ea4b1 CPU40+71+41PASS;
`outputs/artist22_first_getter_arm/HANDOFF.md` gives full hashes/limits.
Old capture plan/GO SHA must be regenerated against these bytes before any
future Root-approved isolated original WebGL run. Debugger-paused placement
clock is diagnostic, never uninterrupted source births. Current bounded
resident packet is pre-native-resolver stage with three previews, not a full
registered source frame; `npc_source_resident_activity.gd` can give original
agenda prefix but shop/bench/drive owners and current revision/clock are still
UNKNOWN. Do not fake source activities/HP with synthetic timer or fixture.

Новый Художник23 должен сначала передать в Hub уже готовый короткий видимый
preview-кандидат с точными зависимостями и ограничениями, затем после CPU
RELEASED/Root23 окна довести оптимизацию, доступные authored-anchor действия
и source authority. Сохранить исходные модели, поведение, IDs, progress и
коллизии, а также один игровой GPU процесс Root23.
