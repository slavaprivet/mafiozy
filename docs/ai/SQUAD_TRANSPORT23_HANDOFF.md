# Squad transport — 23 сентября 2026

## Kingswell LIVE finding — scoped исправление

В root LIVE3passengers застряли board у `fleet:red_sedan` (x612.95/z59.45/yaw0).
Отдельный Surface geometry signature mismatch исправляет Художник21; этот
пакет не меняет surface state и не выдаёт исправление surface за своё.

Независимо воспроизведено: `walk_preview` присваивает Kingswell замороженные
`VEHICLE_SEATS`, в которых нет doorDistance/doorFront. Общий NPC resolver
давал outside.r/c=NaN. Только bridge теперь создаёт кешированный geometry
view с точными existing `vehicleDoorPoint` defaults1.9/anchor.front,
оставляет full-body clearance и отклоняет любые нечисловые accesspoints.
Общий resolver и frozen seat records не изменены.

Kingswell также не реализует actor.poseOccupant. По согласованному1method
lock в `npc_vehicle_pose.mjs` добавлен existing walker.vehiclePose fallback
с authored seat.canDrive и steering grips; binding.actor firingowner сохранён.

Root moving-board замечание воспроизведено: дофикс sourcec9.585→10.609
(4.2m за0.1s). Теперь >0.5m/s приостанавливает board. Если кузов уже освободил
текущую полную source footprint, боец возвращается к обычному подходу,
сохраняя резерв своего места; в противном случае остаётся pending. Даже
после изменения pose следующий board step ограничен3m/s и source/native
sweep, progress растёт только после физического достижения шага.

`test_squad_kingswell23.mjs` PASS: actualcreateDemoCar/frozenVEHICLE_SEATS,
4door geometry, explicitNaNreject, full source host+nativebody/sweep из трёх
LIVE исходных координат →3board/ride/3exit, departure whilepartialboard,
male/female actualGLB ×4seats board/drive without nonfinite/poseexception.
Результат: `outputs/squad_kingswell23_results.json`. Это open-road fixture,
не полный capturedcity и не новыйLIVE/FPS. 23scopedtransportchecksPASS;
surface owner/root должны принять совместный reload отдельно.

## Повторная приёмка после независимого review

Первый READY отозван из-за трёх воспроизведённых дефектов. Они исправлены:

- Door corridor теперь требует `squadDoorPath`: existing dynamic five-probe
  source check (ignore только own vehicle) плюс native static swept footprint
  `mode:sweep`, radius0.18 source tiles. Hook `bridge.canCross` fail-closed.
  Actual narrow pillar c10.08..10.12/r10.06..10.10: старый source helper=true,
  новый supplemental sweep=blocked; board admission/steps и exit door закрыты.
- Новая преграда в body corridor либо отрицательная финальная проверка drop
  инвалидирует цель, продвигает bounded search attempt и повторяет поиск
  после0.2s. Current source position и seat reservation сохраняются. Null из-за
  отсутствия бюджета не сбрасывает цель. В обоих actual-host сценариях найден
  другой выход без скачка, общий лимит4геометрическихпроверки/tick сохранён.
- Body stage в decorated snapshot передаётся `exit_walk`, riding=false и
  walking/moving по фактическому движению. Raw phase остаётся `exit`, поэтому
  seated fire intent запрещён. Door stage сохраняет прежний `exit` pose.

22actual-hostchecksPASS. `test_squad_exit_gait23.mjs --expect-fixed` на actual
decorator→actor→male/female GLB PASS: thigh variation0.981256207/0.936274587,
точно как ordinary walk при2.85m. Никакого browser/GPU прогона не было.
Обновлённый long-follow passenger regression такжеPASS. SyntaxPASS.

Координатор20 разрешил scoped production после main
`272d12c25ed0843e0ec525288f06af7556f2d990`. NPC trip17 отложен по новому
поручению пользователя: моя банда садится на свободные места, едет, выходит
со мной и стреляет по команде. В этой задаче seats/ride/exit; стрельба у
childvehicle, безопасное размещение/догоняние у childgang, LIVE у root.

## Внесено

- `mercenary_world.js`: squad transport subsection. Реальные authored
  passenger seats, отдельная бронь подхода, стабильные места при смене
  порядка roster, остановка у своей двери, phased board 0.75s, отдельные
  координаты сидений при движении. Нет прежней посадки из радиуса 6m.
  Не расширяет authenticated server rights:
  весь squad tick сохраняет existing `local()` gate.
- Пассажир помнит прежний presentation ID после выхода/пересадки игрока.
  Нет безопасного drop — seat и pending exit сохраняются. Приказ eliminate
  не высаживает; смерть/ранение не вызывает safe relocation.
- Выход по фазам через свою дверь и далее к проверенной точке, скорость
  не выше 3m/s, source/native sweep каждого шага и финальная повторная
  `validateSquadSafeDrop` в общем бюджете 4 проверки на tick. Moving car
  приостанавливает выход, не освобождая seat. Автопринудительного торможения
  машины нет. Поздняя преграда/нет бюджета оставляет pending, без origin fallback.
- Поздний transport catchup: только боец с реальной бронью свободного места,
  stopped car <=0.5m/s, >65m в течение 6s или 10s без прогресса, cooldown20s.
  Shared helper проверяет внешнюю точку дважды (>=60ms), дополнительно нужна
  связь со своей дверью. После переноса снаружи — обычный подход и физическая
  посадка. Full car / no safe ground / conversation / interrupted frame
  не вызывают перенос. Water/path caches после переноса сбрасываются.
- `_mercenaryVehicleChase` направляет существующий route/move к своей двери
  через согласованную короткую clause в tick. Root safe catchup не дублируется.
- `mercenary_vehicle_bridge.mjs`: source actors и local fleet, IDs
  `quest_...` / `fleet:<record.id>`; использует existing authored access
  resolver. Бронь передаётся hero local entry, чтобы он не садился поверх NPC.
- `walk_preview.mjs`: bridge, native own-fleet ignore только своего ID для
  короткого door crossing, local fleet binding в existing NPC pose resolver;
  shared `createMercenarySafePlacement` с 9 samples, full source body,
  building interior, railway и реальной геометрией всех машин с circumscribed
  radius. `mercenary_walk.mjs` передаёт hooks в host.
- По поручению root: options `isCommandBlocked` и Walk guards добавлены;
  общие действия блокированы в local/source car, firing-only allowance
  зависит от `canIssueVehicleFireCommand()`. Handlers правил root.

## Стабильная граница для firing owner

Raw member: `_mercenaryVehicleId`, `_mercenaryVehicleSeat`,
`_mercenaryVehiclePhase` (`board`/`drive`/`exit`), `_mercenaryVehicleProgress`,
`_mercenaryVehicleExitPending`. `targets.squadTransport.getVehicle(id)`
возвращает `{id,source,r,c,ang,speed,seats,occupied,blocked}`;
`getActor(id)` возвращает actual actor;
`access({carId,seatId,phase,progress})` — authored source r/c door/seat.

Decorate вызывает `getVehicleFireIntent(m.id)`, если функция присутствует,
и передаёт compact `mercenaryVehicleFire`. Weapon скрыт при отсутствии
допустимого seated intent. Fire owner владеет intent/validate/ownsUpdate,
actual window pose, companion shot journal и safe seated combat branch.

## Проверки и ограничения

`node assets/maps/city_rebuild_v1/test_mercenary_squad_transport23.mjs`
исполняет фактический subsection текущего host и старого published baseline.
23 проверки PASS, результат `outputs/mercenary_squad_transport23_results.json`.
Старый провал воспроизведён: forbidden exit всё равно удалял seat и ставил
NPC в origin. Новый host сохраняет seat при отсутствии/невалидности точки,
blocked sweep, смене машины и пропавшем actor. Проверены unique/full/hero
occupied seats, порядок roster, approach/board/ride, moving/blocked door,
seated focus/death и unknown source occupancy.

Дополнительно обновлён existing full-host long-follow fixture под реальный
bridge и phased board/exit; исходные assertions очистки staged route сохранены,
целевой test PASS. Проверены numeric/string quest keys, protected sourcecar,
скорость прежней машины из questCars после выхода игрока, transition guard
`bridge.isPlayerInVehicle()`.

CPU fixture, одинаковые 3 пассажира sourcecar: последний замер baseline p50/p95
0.0048/0.0068ms, current 0.0161/0.0240ms. Это стоимость subsection с
подставленными provider checks, не измерение загруженного города.
Производительность общей сцены не проверена. Синтаксис изменённых modules PASS.

LIVE, общий FPS, совместная стрельба и реальное door navigation в городе
этой задачей не подтверждены. Единственная GPU игра остаётся у root.

Не перезаписывать shared файлы целиком: в тех же mercenary_world/Walk уже
находятся параллельные hunks root/childgang/fire owner. Не commit/push здесь.
