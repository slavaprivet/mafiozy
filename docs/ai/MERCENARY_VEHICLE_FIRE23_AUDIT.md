# Огонь банды из машины по X / «Устранить»: integration audit

23 сентября 2026, исходный HEAD `272d12c`. Только чтение runtime и новый
isolated audit/test. **Функция в игру не внедрена, LIVE/FPS не проверены.**
Transport3 владеет seats/local/source bindings; этот аудит их не изменяет.

## Что уже есть и что мешает

| Участок | Фактический контракт / препятствие |
|---|---|
| `mercenary_walk.mjs:123,133` | X заново выбирает цель при нажатии, затем использует существующий `host.command('eliminate', target)`. Новый command UX не нужен. |
| `walk_preview.mjs:808` | Общий `isBlocked` включает `!!occupiedSeat`: X недоступен в local fleet машине. Source машина имеет отдельное состояние; простой перенос этого условия на все машины недостаточен. |
| `mercenary_world.js:197–218` | `focusTarget` проверяет source identity, alive/downed/friendly/own/invulnerable. Приказ проверяет дистанцию от игрока 60 м и LOS, затем выставляет `_mercenaryFocus` и `_mercenaryDefending=true`. HP при приказе не меняется. |
| `mercenary_world.js:165–181` | Обе проверки `squadVehicleTick` исключают defending. Поэтому existing eliminate **высаживает всех трёх пассажиров** на следующем tick. |
| `mercenary_world.js:540–563` | Tick пропускает дальнейшее движение seated member. Однако `ownsUpdate` пропускает defending в старый `_updateGang`; простое сохранение seat всё ещё оставит separation/strafe в world. |
| `world.html:23624–23918` | `_updateGang` владеет cooldown, `_shotSeq`, `_visualShot`, damage dispatch и XP. Он двигает бойца и строит 2D muzzle. На улице после принятия приказа нет новой LOS проверки; interior LOS — отдельная ветка. |
| `mercenary_world.js:564` | Любой riding snapshot принудительно экспортирует `weapon:'none'`. |
| `npc_actor.mjs:250,302` | Реальная seat binding/pose уже есть, но оконной aiming/fire позы после неё нет. |
| `vehicle_window_fire.mjs:24–80` | Existing helper допускает только своё боковое окно, ограничивает pitch, сохраняет root/legs, проверяет muzzle снаружи, reach, голову/шею и двусторонний raycast кузова. Он не проверяет улицу/союзников и не авторизует урон. |
| `npc_contact_ray.mjs:10–47` | Уже умеет настоящий posed-skin contact и препятствия; первый попавшийся союзник может оставаться физическим blocker. Это contact, не authority. |

Существующий `mercenary_targets.hasLineOfSight` (`:92`) — команда/выбор цели:
он добавляет высоты `+1.15/+1.05`. Его нельзя выдавать за точную проверку от
реального muzzle или вызывать с уже поднятым muzzle без поправки контракта.

## Минимальная согласуемая интеграция

1. **Transport3 — binding proof.** Для уже сидящего бойца выдавать stable
   `memberId/sourceVehicleId/presentationVehicleId/seatId`, actual vehicle pose
   и revision/identity binding. Команда огня не меняет места, ID, собственность,
   driving authority или порядок выхода. Не пытаться заново садить стрелка.
   Сохранение seat должно учитывать explicit focused combat у уже сидящего,
   не разрешать обычным сражающимся пешим бойцам внезапно телепортироваться внутрь.

2. **Existing X, только разрешение команды.** Отделить допуск X/eliminate в
   стабильной seated фазе от общего запрета разговоров/E/специалистских действий.
   Сохранить health/menu/input/transition guards и свежий pick при нажатии.
   Не убирать весь `occupiedSeat` block из общего UI. Не добавлять кнопку,
   хоткей, автоматическую стрельбу по одному наведению или новое меню.

3. **Source focus остаётся главным.** Использовать existing eliminate и
   `getFocusedTarget` с повторной проверкой живого source ref перед выстрелом.
   Ралли/«за мной», смерть/исчезновение/дружественность цели, downed/hospital,
   смена оружия и изменение vehicle binding инвалидируют прошлую shot proof.
   Недоступное окно/угол заставляет сидящего ждать, а не выходить/обходить машину.

4. **Одна seated firing branch перед обычным движением/боем.** После ownership
   проверки в `_updateGang` сидящий наёмник должен иметь единственный путь:
   seated shot attempt → `continue`. Он не проходит formation/separation,
   melee pursuit/strafe и второй generic firing block. Source сохраняет
   `_nextShootAt`, единственный `_shotSeq` и существующий damage/XP dispatch.
   Предпочтительно выделить общий accepted-shot dispatch для пешего и seated
   пути, а не копировать целиком HP, XP и server send branches.

5. **Presentation preparing proof, не второй стрелок.** Armed focused riding
   snapshot разрешает реальное оружие; snapshot остаётся riding с тем же seat.
   После `applyNpcVehicleBinding` применять existing window plan/pose с blend.
   Перед shot admission требуется актуальная совпадающая binding/weapon/target
   proof с `canFire`, actual muzzle/direction и неизменной seated нижней частью.
   Static оконный frame кешировать на actor/seat; invalidate при remap/model
   change. Не кешировать мировую позу/допуск через движение машины.

6. **Физическая линия перед эффектом.** После cooldown gate, до изменения
   ammo/shot sequence/HP, от actual muzzle выполнить один existing contact ray
   по posed NPC и широкофазно выбранным препятствиям. Свой кузов сохраняется
   в obstacle set; окно должно реально быть открыто соответствующей позой.
   Союзников/игрока/других пассажиров не фильтровать из физического blocking.
   При первой чужой/friendly цели либо стене — reject, без выстрела и HP.
   Для минимального explicit-focus поведения допускать только контакт с тем же
   живым source identity, которому отдан приказ. Нельзя наносить direct damage
   исходной цели, если actual ray попал раньше в другой объект.

7. **Порядок source/renderer нужно доказать actual-host тестом.** World tick
   и NPC render update не являются одним и тем же callback. Нельзя принять
   произвольный stale cached muzzle после перемещения/вращения машины.
   Owner boundary должен обеспечить либо синхронное получение proof на текущем
   binding transform, либо проверяемый handoff актуального pose sample. Missing
   actor/weapon/window, stale binding, cull/reload — fail closed без расхода.
   Это оставшийся integration вопрос, не уже работающий API.

8. **Один подтверждённый visual receipt.** После source accepted shot публиковать
   существующий sequence с зафиксированными muzzle/contact. `npc_shot_effects`
   сейчас выводит origin из текущего оружия, а конец — из target ground+1.05;
   для машины нужен optional accepted physical ray, чтобы движение между кадрами
   не переместило уже сделанный выстрел. Эффекты не наносят урон, не тратят ammo
   и не переотправляют действие. Сохранить pooled tracers/flash без новых lights.

## Authority, оружие и боеприпасы

`mercenary_world.js:6` разрешает управление только при `_LOCAL_PREVIEW` и без
`_serverAuthoritativeAmmo` / `_customGang`. Проверять это не только при приказе,
но и непосредственно перед новым seated shot; переход online не должен
оставлять старую локальную авторизацию активной.

Текущий отряд имеет personal/выданное weapon assignment, quantity transfer при
equip/dismiss (`:94–95,402–404`) и cooldown. Отдельного конечного магазина/
ammo ledger бойца в прочитанном source-контракте **нет**. Не создавать и не
клонировать патроны ради этой функции; сохранить действующую модель компаньонов.
Не вызывать hero `worldWalkCombat.step` / `bridge.fireWalkShot`: это API магазина,
cooldown и shot authority **игрока**, а не бойца. Если нужен конечный запас NPC,
это отдельная source-механика, её нельзя изображать локальным счётчиком renderer.

Existing `_updateGang` вызывает `hitNpc(...,{kind:'npc',ref:m})`, `hitCityCop`,
bank/interior callbacks, а для некоторых удалённых целей использует server
messages; PvP намеренно не притворяется выстрелом владельца. Новый seated путь
не расширяет доступные онлайн цели/права и не вводит local fallback для server
rejection. Для подлинной online поддержки нужен server-owned companion actor
и отдельный подтверждаемый shot contract; в этом аудите он не обнаружен.

Оконная поза сама по себе не превращает RPG/стрелы/дробовые pellets в правильную
баллистику. Первый вертикальный срез можно принимать на реальных pistol/SMG
контрактах, затем расширять только с настоящим существующим projectile authority.

## Новый actual audit / candidate composition

`assets/maps/city_rebuild_v1/test_mercenary_vehicle_fire23_audit.mjs`:

- Actual `mercenary_world` + actual `_updateGang` воспроизводят четыре blocker
  выше. Production bodies не исправляются в памяти. Только browser import
  подменён загрузкой того же настоящего core в VM, как в existing fixtures.
- Подтверждены existing friendly/own/downed/invulnerable/occluded order gates,
  online rejection без изменения inventory/weapon state, и отсутствие второго
  `_shotSeq` при повторе update до cooldown.
- Candidate composition: реальные NPC male/female, compact_sedan GLB, три
  пассажирских места, yaw 0/1.1, TT и Uzi. **24/24 poses allowed**, root и
  нижние конечности не сдвинулись (`maxLowerBodyShift=0`), actual muzzle outside,
  ownCarClear/selfClear/reach true, direction согласовано. Луч от muzzle также
  не пересёк собственную actual posed skin.
- Три actual posed-skin contact проверки: enemy попадает первым; поставленный
  перед ним friend становится первым контактом; непрозрачная стена блокирует
  enemy. Это демонстрирует пригодность existing ray для безопасного допуска,
  а не внедрённый production shot.
- Existing `test_mercenary_focus_source.mjs` **8/8 PASS** и
  `test_mercenary_vehicle_follow18.mjs` **2/2 PASS**.

```text
node assets/maps/city_rebuild_v1/test_mercenary_vehicle_fire23_audit.mjs
```

Тест использует tracked GLB/core/fixture sources и существующий внешний THREE
vendor: `MAFIOZI_THREE_VENDOR` либо
`D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor`.
Никаких новых browser/GPU вкладок, backend imports или runtime edits.

## Приёмка после реализации

Actual full host должен доказать X→source order→pose→single accepted hit при
неподвижной и движущейся/поворачивающей машине, обеих сторонах и всех трёх
пассажирских местах. Противоположный борт, голова/кузов, стена, союзник, смерть
цели, повтор команды, cooldown, remap/reload, отсутствие actor/weapon, downed и
online transition должны отвергать небезопасный выстрел без dismount, двойного
HP/XP/ammo события. Seat IDs/driver controls/physics не меняются. LIVE и стоимость
общей сцены замеряет координатор на единственной игровой вкладке; CPU composition
не заменяет эту приёмку.
