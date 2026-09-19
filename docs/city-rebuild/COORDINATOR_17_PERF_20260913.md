# Координатор17 — общая производительность, 13 сентября2026

Пользователь переключил приоритет на устранение тяжёлых лагов без ухудшения качества. Root17 `01a097a0-5d69-7660-9aa0-7845289a887e`. Renderer/vehicle/shadows ведёт действующий optimizer `01a06e4d-e3ed-7f13-bda3-7fd677972336`; собственные субагенты17 ведут HUD/mercenary повторные расчёты. NPC/lifecycle — Artist17. Снижения качества, населения, теневого разрешения или дальности17 не делал.

## Чистая одна игра

Создана replacement root17 browser1/tab1 с тем же localhost integrated world URL (npccombatqa=1,npctransportqa=1,perfqa=1,vehicleshadowcull=1). Проверены screenshot реального города, rendered/error:null,242/242,78зданий,164декора, NPCpending0. Елена merc_resident_33 восстановлена из сохранения.

Только после готовности replacement Artist16 закрыл свою3: реальный CUA result 2026-09-12T22:16:32.897Z inventory tabs[]. Root16 подтвердил tabs[], cover2 закрыта, остальные владельцы GPU0. Архитектор завершил временно разрешённый workerparity и подтвердил CPUheavyidle всех четырёх исполнителей. Замеры ниже спустя более120кадров после закрытия дубля. Никаких reload/камерных перемещений между A/B.

## Normal gameplay baseline

2026-09-12 около22:17:30UTC; camera[167,2.74,168],feet[164,0,164],845×920,DPR1,GTX980/ANGLE D3D11,multiDraw=true. NPC60seen16visible,pending0;traffic18,loading0,1810/1810batchmembers,fallback0. CullingON,330отсечено/1266проверено. Окна120кадров.

| Метрика, мс | p50 | p95 |
|---|---:|---:|
| Интервал кадров |105.7|126.5|
| Frame CPU |95.1|116|
| Renderer CPU |82.2|97.7|
| Main submit |42.5|48.7|
| Shadow pass |21.6|26.9|
| Shadow submit |10.5|12.4|
| Matrix update |7.9|10.3|
| NPC |7.4|10|
| healthHud (включает mercenary) |0.7|11.1|
| GPU |57.93|65.02|
| Реальный source update |8.2|12.4|

Source failedUpdates0,windowFailedUpdates0,max38.7ms. Frame draws total4264/main2550/shadow1714; total triangles3779958/shadow1301488. Около10FPS, лаги НЕ устранены. Timings вложены: их нельзя суммировать; interval-frame не равно worldCPU.

## Held render-only shadow A/B

Только явный hold через #render-freeze-qa: source world продолжает жить. Snapshot NPC61seen15visible,pending0,traffic18loading0, та же camera/quaternion/projection/845×920/DPR1. В обоих чтениях freeze.active=true, frames330/900,полные120timings. OFF/ON переключает только conservative shadow volume rejection, не все тени.

| Метрика, мс | OFF p50/p95 | ON p50/p95 |
|---|---:|---:|
| Render CPU / frame |83.1 /100.1|79.2 /86.5|
| Interval |98.3 /117.7|94.1 /105.8|
| Main submit |42.1 /51.3|40.9 /44.2|
| Shadow pass |23.1 /30.9|21 /23.6|
| Shadow submit |12.7 /16.1|10.3 /11.8|
| Matrix |8 /10.6|7.7 /9.4|
| GPU |60.51 /74.83|62.27 /67.3|
| Source update |13.7 /16|13.1 /14.9|

Draws total4571→4241; **main2527 в обоих**;shadow2044→1714. Main triangles2455766 в обоих; shadow1621839→1301488. CullingON330/1266,unsupported0. Материалы/модели/камера/позы сохранены. Снимки обеих фаз в разговоре17 визуально совпадают по игровому содержимому и видимым теням; это не pixel-diff всех ракурсов.

Медиана renderer -3.9ms; GPU медиана не улучшилась, не заявлять GPUускорение. Основной main submit остаётся тяжёлым. Это одна render-only пара, не доказательство игровогоFPSвдвижении/всехракурсов. В конце ON возвращён, hold снят manual при1074frames; управление работает, единственнаяtab1оставленаmarkDeliverable.

## Следующий этап

- Root17HUD conditionalDOM:103→0повторныхsettercalls/200ms при одинаковомsnapshot; качество/частота/HP/IDsсохранены,4suitesPASS.
- Root17mercenary: удалёндубликатhead/project, registryrefresh2→1втомжесинхронномpick; sourceprecedence/liveposeсохранены,20testresultsPASS. BroadphaseплашекпокаНЕменялся.
- Третийсубагент17 готовит copyодногоmemberrecordвместокопиивсегоростера; безtimecache.
- Optimizer готовит отдельныйsameUUIDfixturebatchcandidate и аудитколёс. ОнинебылизагруженывэтомA/B, результатытенейимнеприписывать.

Послеtestsсовместныйreload; проверитьновыеhotpaths/ошибки/поведение/сопоставимыецифры. Производительность последующихHUD/core/vehicleправок общей сцены ещё не проверена.

## Второй LIVE: combined reload и автодетали

Пользователь явно разрешил «Можно перезагрузить и измерить». Перед этим вкладка была изменена извне: герой переместился, появились выстрелы и сбросился hold. Старый baseline с новым не сравнивается. В новом окне viewport 549×920 вместо 845×920; настройки качества не менялись. Единственная tab1 перезагружена; 242/242 объектов, 78 зданий, 164 декора, startup error null. Runtime подтверждает fixtures: traffic 19, fixtureMembers 188 / fixtureBatches 56, activeMembers 2043, fallback 0, loading 0. Woodland включён: static optimization 41 batches /1162 members, +5/+72. Все владельцы подтвердили heavy CPU idle, GPU вкладок больше не открывали.

Normal120 после входа: interval p50/p95 97.6/121.2 мс, render 72.1/94.2, NPC 4.9/6.4, healthHud 0.2/11.1, source 12.7/16.1, failedUpdates 0. MercenaryPicking last 9.6, sticky max 68.8 мс. Это новая динамическая сцена, не before/after доказательство HUD/woodland.

Held detail OFF→ON, около 01:34–01:36 MSK: active true в обоих образцах (750/1230 frames), fixed camera [165.7771456105,2.5599384974,167.8472706401], feet [163.5075291032,0,163.3514332242], одинаковые quaternion/projection, NPC56 seen/16 visible/pending0, traffic19/loading0, DPR1. Source world продолжает обновляться. Это сравнение всего existing detail lane вместе с новыми fixtures, не только fixtures.

| Метрика, мс | OFF p50/p95 | ON p50/p95 |
|---|---:|---:|
| Render CPU |74.7 /86|73.8 /81.4|
| Interval |94.2 /108.4|93.6 /103.2|
| Main submit |29.4 /34.4|29.6 /32.6|
| Shadow pass |25.4 /29.2|25.8 /30.2|
| Shadow submit |11.9 /14.1|13 /15|
| Matrix |9.1 /11.1|8.7 /10.5|
| GPU |35.27 /45.21|36.68 /43.8|
| Source update |17.1 /23.5|16.4 /23|

Draws total3553→3289, main1570→1478, shadow1983→1811. **Main triangles1692224 одинаковы**. Shadow triangles1524879→1528407 (+3528), передано владельцу проверить гранулярность batch bounds. Renderer median -0.9 мс; GPU median не улучшилась. Снимки визуально совпадают; это не pixel-diff всех ракурсов. Значительного выигрыша FPS нет, лаги не устранены. Census optimized: traffic1740calls, включая1090shadow, более половины total3289. Качество/население/материалы/дальности не снижались.

Hold снят Escape, checkbox вернулся0; optimized ON, tab1 markDeliverable. CPU окно освобождено всем владельцам. Следующий root17 этап — точный opt-in probe естественного mercenary pick; vehicle wheel/materials остаются у optimizer.

## GPU-таймер: проверка собственного overhead

Combined reload загрузил grass prefix upload и picking probe. Первый timer ON→OFF опыт отвергнут: при втором чтении hold уже истёк по120s и timer сам восстановился ON. Его числа не сравниваются.

Повторная пара OFF→ON корректна: holdactive330/660frames, camera[167,2.74,168],feet[164,0,164],911×920,DPR1, одинаковыеprojection/quaternion,NPC52seen18visible/pending0,traffic19/loading0. Все владельцы CPUheavy idle. OFF явно gpuTiming=disabled/gpuMs=null, ON enabled. Окна120.

| Метрика, мс | OFF p50/p95 | ON p50/p95 |
|---|---:|---:|
| Renderer |99.9 /110.7|100.3 /113|
| Interval |116.6 /129.1|116.7 /132.2|
| Main submit |49.7 /54.9|49.7 /54.2|
| Shadow |27.6 /31.3|27.7 /30.8|
| Matrix |9.6 /11.3|9.4 /11.4|
| Source |14.4 /20.6|14.2 /20.2|

Одинаковые draws4638(main2744/shadow1894), triangles4322877(main2753644/shadow1569233), geometry7122/textures803. GPU ON70.43/78.76ms; OFF отсутствует, не0. Source failures0. Разница median renderer0.4ms, таймер не объясняет тяжёлые лаги в этой сцене. В конце Escape, holdfalse, timerON, tab1markDeliverable; всем CPUrelease.

## Picking: первая атрибуция после reload

Natural hover snapshot122roots/13815visitednodes/10591raycastcalls, camera[167,2.74,168],rayfarInfinity. Native asphalt3.4ms/water3/grass2/paving1.1; cars8270calls3.6ms; environment720calls1.1ms; landscape.4; NPC1458calls.9; registry.2. Exclusive raycast15.6ms, originalintersect20.4ms. QA prepare6.9/restore1.4/residual4.8ms — эти расходы не считать production speed. First accepted asphalt at12.752384m/face5914, targetnull. Native meshes ~9.5ms — обоснованный следующий exact triangle-index candidate, не изменение geometry/drawdistance.

Grass после reload272visibletufts/5batches/23520tri, полный план67250/6103476tri прежний. Камера/viewport другие, поэтому прежние257tufts не являются before/after mismatch. Буферные meaningful tests подтверждают точные данные, но отдельный LIVE FPS выигрыш prefix пока не выделен.

## Native picking, static matrices, wheels — combined LIVE 13 сентября

Одна tab1, URL добавлены nativepick=1/staticmatrix=1/wheelbatched=1, detailed mercenarypickqa отсутствует. Все владельцы heavy CPU idle. После загрузки 242/242, 78 зданий, 164 декора, NPC pending0, traffic19/loading0. 911×920/DPR1, камера [167,2.74,168], feet [164,0,164]. Native6meshes build130.1ms, static2232 frozen sources, wheel95batches/380members/fallback0. NPC после прогрева31walking; это подтверждает движение, не полную приёмку поездок.

Native natural whole-hover вне hold: OFF40 разрешённых samples p50/p95 **10.1/11ms**, ON32 samples **4.4/5.4ms**. По1 blocked отдельно, failed0, generation2, fallback0. Камера/viewport совпадают; население динамическое, поэтому это не полное gameplay FPS A/B и не чистая стоимость raycast. В обоих случаях естественная частота, дополнительных лучей нет. Четыре запрошенных native meshes в ON проверяли15+0+12+0 кандидатов, остальные2 не затронуты данным лучом. Следующий шаг — включить точный индекс по умолчанию с nativepick=0 escape hatch, отдельная задача агенту.

Static matrix held OFF→ON,120frames/window, hold300/600frames, NPC58seen/18visible, traffic19/loading0. Точные одинаковые draw4422(main2612/shadow1810), triangles4345460/shadow1633946. Frozen0→2232. Картинка на двух снимках совпадает (не pixel-diff всех ракурсов).

| Метрика, мс | OFF p50/p95 | ON p50/p95 |
|---|---:|---:|
| Renderer |89.6/99.9|89.1/94|
| Interval |101.3/112|100.7/106.9|
| Matrix |7.9/10.2|7.8/9|
| Main submit |44.3/48.5|44.2/46.7|
| Shadow |26.8/30.1|26.4/28.7|
| GPU |67.66/73.97|68.8/73.28|
| Source |9.6/11.8|10.1/12.6|

Слабый median выигрыш0.5ms, не решение лагов; оставлен opt-in. После Escape начат отдельный hold для wheels.

Wheel held OFF→ON,120frames/window, hold330/630frames, NPC59seen/20visible, traffic19/loading0. Draw4841→4464 (-377), main2864→2654, shadow1977→1810. **Точные одинаковые total triangles4389940/shadow1633946**. Камера/projection/viewport совпадают. Снимки без видимых изменений. Traffic wheel stats во время hold сохранены от последнего обычного update, поэтому переключение доказано checkbox+draw, не stale stats.

| Метрика, мс | OFF p50/p95 | ON p50/p95 |
|---|---:|---:|
| Renderer |91/99.9|91.3/101.2|
| Interval |103.4/112.1|103.6/117.6|
| Matrix |8/9.6|8.2/10.1|
| Main submit |45.6/48.9|45/49.2|
| Shadow |26.4/30.2|27.1/30.7|
| GPU |67.61/74.1|69.32/77.79|
| Source |10.8/13|10.7/12.6|

FPS не улучшился; глобальный default wheels не включать по этому замеру. Все source windows failures0. В конце Escape holdfalse, native/static/wheel/detail/shadow/timer ON, tab1 markDeliverable; CPU release всем владельцам. Качество, густота травы, дальность, геометрия и население не снижались. Общая игра всё ещё около10FPS — не объявлять лаги устранёнными.

## Подробный per-draw probe — LIVE после collision/NPC reload

Добавлен buildingqa=1, текущая общая сборка загружена242/242, source failures0. Новый grouped collision:17250bodies/79groups/404cells, initial79replacements; на неподвижном интервале dirtyGroups0/verticesDelta0/allBodiesBuilds0. Сравниваем только стоимость диагностики, не старую и новую игру с изменившимся населением.

Held OFF→ON,120frames/window, frames360/690,911×920/DPR1,camera167/2.74/168,NPC55seen14visiblepending0/traffic19load0. Exact3463draws(main2166/shadow1297),3539017tri/shadow1151171. OFF directProfilingfalse без submit/census, ONtrue. Renderer70.7/76.2→73.3/78.5ms; interval82.4/88.4→85.1/90.5; GPU51.27/55.92→53.63/59.15; matrix7.2/8.6→7.1/8.4;shadow18.8/21.6→19.5/22;source9.4/13.3→9.9/13.3,failures0. Стоимость подробных счётчиков около2.6msmedian, не главная причина лагов.

ON material census main: Standard opaque1902calls/2016000tri/29.1mssubmit; Standard transparent81/23022/2.3ms; Physical opaque120/298208/4.3ms,transparent32/15960/.9ms; Basic opaque28/21504/.4ms,transparent2/10752; Shader transparent1/2400; shadow1297/1151171/10.5ms. Submit времяCPU, не самостоятельноеGPUtime материала.

В конце Escape/holdfalse/diagnosticsON. CPU release после появленияUIoverlap препятствия при выборе здания: buildingqa top120left12 перекрытconvoy/HUD/профилем. Native clickselect не поменялvalue; Tab открылличноедело(globalhotkey), Escape егоне закрыл. Indoor LIVE ещё не принят; решается реальным UI. NPCafterreload43s tripapproach localvehicle22/resident53; later planninglocalvehicle19/no-native-road-route,visitscomplete43/pending10/physical0. Driverпоездканепринята.

## LIVE проходы внутри зданий

UI препятствие преодолено штатными Playwright `selectOption` и `button.press('Space')`. Enter перехватывается игровым чатом; Tab — личным делом. Обход игровых контроллеров через globals не использован. CUA session reset вернул документацию, старые пары переменных потеряны, цифры сохранены выше. QA status text остаётся устаревшим: панель в document.body, код ищет через shadow helper; доказательство входа берётся из body.dataset.buildingEntry и снимка.

**Жилая башня002:** `inside=REBUILD-VISUAL-compact_podium_glass_tower_v1-002`, heroY=floorY=.259999997, feet[662.05,.26,174.0115], camera[661.557,2.803,179.129]. Открытая дверь пройдена штатным movement/collision; на снимке мебель, лестница и NPC сохранены. Seven storeys,14 furnished rooms,55 furniture/881parts/41508interiortri. Idle collision dirtyGroups0/verticesDelta0/allBodiesBuilds0; buildingRail p50/p95 .3/.4ms.

Найден отдельный indoor performance lead: **heroCombat stage26.4/31.1ms**, снаружи башни ранее1.4/2.1. Он включает clampBuildingCamera, updateCombat, hero.update и прочее; виновник без substage ещё не доказан. Renderer105.4/143.2ms,5994draws(main3876/shadow2118),5006927tri/shadow1366380. CPU других владельцев уже разрешены и сцена динамическая — это воспроизводимый hotspot, не controlled A/B. Передано владельцу камеры для атрибуции и исправления без изменения изображения.

**Малый банк:** через QA подход, реальное E-controller открытие и штатный проход. `inside=REBUILD-bank:small`, floorY=heroY=.1,openFraction1. Сохранились7 furnished rooms/24 furniture/491parts/21624interiortri. На первом интервале после E **dirtyGroups1,bodiesDelta136,verticesDelta544**,allBodiesBuilds0; после анимации снова dirty0/vertices0. Нет полной пересборки17250 тел города.

Банк: heroCombat .9/1.4ms,buildingRail .3/.4ms,renderer65.7/84.7ms,2106draws(main989/shadow1117),1946255tri/shadow917040. Camera shoulder с wall/headDistance1.479, boom1.524; крупная голова при близкой стене передана владельцу камеры, не объявлена исправленной. Source failures0. Это другой вид/городская сцена и не сравнение с башней на одинаковых условиях.

QA выход из банка завершён: inside=null, feet[226.55,.00455,131.2],camera[231.657,2.666,131.548]. Holdfalse,sourcefail0,tab1markDeliverable. Все CPU окна освобождены. Качество/материалы/дальность/густота/мебель не сокращались. Проверка интерьеров выполнена; устранение общей тяжёлой отрисовки и отдельного tower hero/camera hotspot остаётся открытым.
