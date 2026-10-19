# Контактное извлечение водителя из машины — read-only contract

23 сентября 2026. Согласовано между Transport3 и Художником21 как граница
следующей итерации после checkpoint. Production не изменён, GPU не запускался.
Driver-wait остаётся первым малым NPC fix после публикации.

## Текущее поведение и разрыв

Source уже сохраняет identity, HP/death clock, авторскую дверь и непрерывный
root: `approach → open (250 мс) → pull_driver → enter`. Жертва физически идёт
от seat к проверенной drop point со скоростью 0.85 source cell/s; blocked door
останавливает последовательность без teleport. Presentation получает только
`seated/pulled(progress)/released`.

У живой жертвы текущий `applyVictim` после середины extraction даёт короткий
stagger, но не контактный захват и не падение. `released` сразу вызывает
`_npcVehicleHijackReleased`, после чего начинается protest/retake/flee.
Расстояние само по себе не даёт времени рукам сцепиться до начала движения.
Дверь также получает общий `exit(progress)` curve: на границе начала pull она
может закрыться после уже открытой фазы, затем снова открыться.

## Additive source receipt

Сохраняются существующие `seq.phase='pull_driver'`, victim `phase:'pulled'` и
старый `progress` для совместимости. Добавляются поля:

```js
{
  eventId, victimId, carId, seatId, side,
  stage: 'grab' | 'extract' | 'release' | 'fall' | 'settle',
  stageProgress: 0..1,
  stageSince: sourceMilliseconds,
  sourceNow: sourceMilliseconds,
  doorOpen: 0..1
}
```

`eventId` не меняется между стадиями. `stageProgress` монотонен внутри стадии,
но сбрасывается при переходе. `sourceNow-stageSince` позволяет presentation
восстановить позу после cull/reload без локального таймера. Snapshot никогда не
создаёт damage, смерть, custody или ownership.

Предварительная source последовательность, финальные времена проверяются на
actual male/female rigs:

1. `grab`: около 0.20 с, жертва остаётся в точном seat root; дверь полностью
   открыта. Это окно для двух точек контакта рук.
2. `extract`: начало существующего collision-swept seat→drop root, progress
   берётся из реально пройденной дистанции. Контакт рук допускается только пока
   actual-rig anchors остаются в сертифицированном reach envelope. Дверь открыта.
3. `release`: руки отделяются в явной физически достижимой точке, затем жертва
   самостоятельно завершает оставшуюся collision-swept часть пути к drop point.
   Это продолжение одного source root path, а не teleport или visual offset.
4. `fall`: ориентир 0.45–0.65 с, тот же root, авторское падение на землю.
   Никакого HP damage и подмены `_knockedUntil`.
5. `settle`: короткая стабилизация контакта с землёй. Только после неё source
   ставит старый `phase:'released'`, очищает occupant/controlled flags и один раз
   вызывает `_npcVehicleHijackReleased`.

Пока идут `release/fall/settle`, `_vehicleHijackControlled` остаётся true:
agenda, protest, retake, flee и бой не получают NPC раньше падения. Dead victim
остаётся dead и использует существующую corpse extraction ветвь; source не
оживляет и не создаёт вторую смерть. Interrupted до начала physical extraction
может вернуть прежнего seated owner; после начавшегося extraction действуют
существующие безопасные ownership cleanup rules.

Не использовать `_knockedUntil` как быстрый способ показать падение. Текущий
`_npcVehicleHijackReactionTick` удаляет hijack reaction у knocked NPC, а общий
stun имеет собственные recovery/death приоритеты. Dedicated hijack stages
сохраняют причинность и не меняют боевую механику.

## Контакт рук и ног

Художник21 добавляет shared presentation helper, который для actual victim rig
возвращает парные world anchors верхней части руки/плеча и валидность кадра.
Root player hook передаёт в `applyPuller`:

```js
gripsWorld: { l: {x,y,z}, r: {x,y,z} }
```

Текущий одиночный `gripWorld` остаётся fallback для старых snapshots. Он не
считается доказательством двухручного контакта. Player palms и victim anchors
должны оставаться в допустимом зазоре только до подтверждённого release; кости
не растягиваются, pelvis/root не переписываются pose-кодом. Victim legs проходят
непрерывно из seated fold через door sill, затем принимают падение без
первого-frame snap.

Read-only geometry audit обнаружил важную границу: текущий source выбирает
drop offset до `±0.45` source cell вдоль машины, то есть `1.845 м` при масштабе
4.1, а player всё время `pull_driver` остаётся в `access.outside`. Полный контакт
до endpoint поэтому нельзя требовать даже с парными anchors. Первая реализация
должна выбрать один из двух проверяемых вариантов:

- минимальный: source задаёт ранний `contactReleaseProgress`, измеренный на
  actual vehicle/sex pairs; после него victim один завершает swept ejection;
- расширенный: player получает отдельный collision-swept staging path и
  физически сопровождает victim до release point.

Source не должен читать renderer bones для принятия gameplay решения. Граница
контакта выводится из authored access geometry/profile и подтверждается actual-rig
тестами. Если ни один безопасный player staging step не существует, используется
раннее отпускание. Pose никогда не удлиняет руки и не двигает root, чтобы скрыть
возникший зазор.

Presentation может изменять bones/visual pivot только внутри authored envelope.
Физические `r/c`, yaw, drop point, collision и event lifecycle принадлежат
source. Если vehicle или victim actor временно отсутствует, source ждёт/идёт по
своей bounded последовательности; renderer не телепортирует roots для создания
контакта.

## Door contract

Transport3 владеет source timing двери. Нужен узкий explicit режим access,
например `phase:'hijack-door'`, где `progress` означает непосредственно
`doorOpen`, а не общий board/exit curve. Это позволит:

- сохранить doorOpen=1 от конца `open` через grab/extract/release/fall/settle;
- при player `enter` удержать дверь открытой до прохода корпуса и плавно закрыть
  её на последней части физического seat path;
- закрыть дверь при interrupt/release ровно один раз через существующий owner;
- избежать скачка `open → closed → open` на границе pull_driver.

Обычные E enter/exit, squad boarding и fire window door state не меняются.
Режим принимает только finite 0..1 и exact authored seat/door ID.

## Владение файлами после checkpoint

- Transport3: `npc_vehicle_hijack_source.js`, точный mirror block в `world.html`,
  узкий door progress path в `world_traffic_presentation.mjs`/access tests,
  `test_npc_vehicle_hijack_source.mjs`. Не трогает actor/fire/floor.
- Художник21: `vehicle_hijack_pose.mjs`, shared contact-anchor helper/API,
  узкий presentation gate в `npc_actor.mjs`, actual-rig pose/contact tests.
  Не меняет source roots, HP или двери.
- Координатор20: `walk_preview.mjs` player grab hooks/anchor lookup, E/action
  priority и итоговый integration/LIVE. Не дублирует source timing.

Перед каждым shared файлом владелец сверяет опубликованный SHA и текущие WIP
hunks. Current defensive fire upper body, E priority, walk→board floor blend и
vehicle seated pose не должны быть перезаписаны.

## Приёмка

- Source: один eventId; grab dwell без root movement; каждый victim и optional
  puller staging step swept; contact завершается до выхода из certified reach;
  blocked corridor удерживает exact previous root; release/fall/settle не дают
  agenda/combat; reaction вызывается один раз после settle; interrupt and dead
  matrices сохраняют identity/HP/death clock/ownership.
- Contact: actual male/female victim × supported vehicle seats, обе hero palms
  на victim anchors от grab до explicit release; endpoint separation не
  маскируется bone stretch/root shift; без cabin/door penetration и limb snap.
- Door: finite authored door, без discontinuity на open→grab→extract и без
  закрытия через torso/legs; interrupt закрывает дверь штатно.
- Rates: 60/15/7/5/3 Hz, long frame/cull restore по source timestamps; нулевой
  или повторный dt не повторяет release event.
- Integration: grabbed → physically extracted → released → fall → ground settle
  → protest/retake/flee. Player enters только после освобождения corridor;
  огонь, death, custody и E priority сохраняют более высокий existing priority.
- Производительность: CPU до/после на actual rigs и общий LIVE/FPS отдельно.

Это контракт следующей итерации, не объявление готовой анимации.
