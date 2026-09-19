# QA дверь для громилы / подрывника — 19 сентября 2026

CPU READY, 10/10 tests PASS. LIVE не выполнялся; подключение source/action adapter и окончательная проверка принадлежат Координатору18. Исполнитель `safe_operator_clearance18` освободил файлы.

## Файлы / контракт

- Новый `assets/maps/city_rebuild_v1/mercenary_breach_door.mjs`: настоящая деревянная дверь из восьми толстых досок, стальные рама/полосы, ручка/замок. Створка закреплена на петле и открывается от специалиста на 108° за .8 с. Ответная часть замка отламывается и падает; дверь не исчезает.
- `mercenary_profession_showcase.mjs`: layout.door = anchor +(5,-5); больше 12 м до автомобиля, 6 м до пациента, без наложения на старые объекты. Объект входит в реальные QA collision bodies и targets. `showcase.door` возвращает API.
- `mercenary_showcase_ui.mjs`: опция `door / Запертая дверь`.
- Новый `test_mercenary_breach_door.mjs`; существующий `test_mercenary_profession_showcase.mjs` расширен проверкой количества целей и безопасного расстояния.

Metadata: `{id,kind:'door',locked:true,lockable:true,breachable:true,bombable:true,workRange:.08,breakOpen(effect),blast(effect)}`. После первого успешного эффекта `opened=true`, `locked=false`, `breachable=false`, `bombable=false`, `object.userData.mercenaryOpened=true`. Повторы возвращают duplicate и не воспроизводят FX. Несовпадающий targetId/отказ collision callback не меняют дверь. `onBlast` вызывается один раз и только при `blast`, после принятия физического изменения. Бомба/таймер/отход/урон — ответственность source, модуль не инициирует их сам.

Контакты safe units: локальный approach `(.6,0,-1.08)`, point `(.6,.85,-.08)`, normal `(0,0,-1)`. Учитывается source radius `.18*4.1=.738 м` плюс accepted range `.08 м`. Дверь поворачивается в +Z, поэтому не закрывает оператора спереди.

## Физика / стоимость

На .8 с открытия резервируется консервативный полный объём движения створки, включая ручку. Это не позволяет пройти сквозь вращающуюся дверь и требует только **двух collision transactions**: начало и конец. После анимации остаётся точный повёрнутый узкий collider. Весь видимый mesh остаётся внутри временного объёма (проверены все вершины всех instances на 160 шагах). Отказ финального callback сохраняет блокировку и безопасно повторяет попытку; никакого снятия collisions без подтверждения.

Callback contexts: `breach_door_open` / `breach_door_motion`. Координатору желательно исключить эти transient contexts из тяжёлой пересборки дорожного worker, как `safe_door` (но обычный walk collision index обновляется обязательно). Два callback за всё действие, не каждый кадр.

Render: **5 draw calls / 204 triangles**, без lights, без создания geometry в update. CPU одной анимации p50 `.0005 мс`, p95 `.0016 мс`; idle early-return. **Производительность общей сцены не проверена.**

## Нужная интеграция root

- Source `breach_door` и door `plant_bomb` ведёт `crew_follow_routes18`, контракт ему передан.
- Target adapter должен вызывать meta.breakOpen / meta.blast для настоящей QA двери и сохранять breachable/bombable.
- Root `walk_preview` inspect должен поддерживать layout.door (обычно общий layout[key]).
- Showcase передаёт `onExplosion` событие `{kind:'breach_door_blast',targetId,position,effect}`. Старый root callback обрабатывал только vehicle record; нужен отдельный обычный blastResponse по position для видимого эффекта двери. В этом модуле взрывной урон не дублируется.
- Громила QA изначально ранен: прежде поднять медиком или подготовить доступного бойца обычным способом.

## Тесты

`node --test assets/maps/city_rebuild_v1/test_mercenary_breach_door.mjs assets/maps/city_rebuild_v1/test_mercenary_profession_showcase.mjs` — **10/10 PASS**. Проверены запрет/разрешение physical transaction, однократность blast/kick, .738 м тело по всем краям .08 м допуска при четырёх yaw, physical path через полностью открытую дверь, полный sweep геометрии, 2 collision transactions, disposal/QA guard/остальные площадочные объекты.

Реальные building doors, source/core/route, персонажи и браузер не менялись. Stage/commit не выполнялись.

## Root integration завершена исполнителем по отдельному поручению

Добавлены `onDoorBreach/onDoorBlast` в targets и walk. Только явно опубликованные `breakOpen/blast` дают capabilities; local world authority обязательна перед физическим изменением. `X` выбирает breach_door раньше plant_bomb; обе задачи доступны обычной панели отряда. `mercenary_action_timers` подписывает работу «Выбивание двери». `mercenary_charge_view` показывает source-armed заряд на authored door workPoint, с прежним ограничением 10 Гц и очисткой по source charge lifecycle. Ни источник урона, ни fuse не дублируются.

`walk_preview` получил door inspect высоту1.15 м, `door.getState()` в QA snapshot, door blastResponse по позиции, исключение двух временных collision contexts из roadworker rebuild. Walk collision index обновляется как раньше. Новое `lockpickable:false` QA двери сохраняется targets descriptor; crew/source owner предупреждён о необходимости уважать флаг в core unlock_door.

Повторная проверка integration/targets/physical door/charge/timers: **15/15 PASS**. Существующий `test_mercenary_walk` теперь проводит actual QA door через общий adapter: target metadata, нажатие X/kick priority, authority отказ без изменения, затем accepted kick или bomb ровно один раз, настоящий attached charge и timer text. `node --check walk_preview.mjs` PASS. **LIVE всё ещё не выполнен исполнителем.**
# LIVE centre-ray correction — 20 September 2026

Root observed an inspected locked door at world (169,0,173), hero (169,0,168), but X issued a rally behind it. Reproduced with actual Three source geometry and inspected camera (169,1.948726,163.015924): the centre ray and assisted centre ray both fell into the 4 mm vertical seam between instanced timber boards. Bounds and world matrices were correct.

Added a leaf-local command-picking surface matching the physical leaf dimensions (2 × 2.38 × .16 m). Its material is `visible:false`, so it adds no rendered draw, shadow or visual badge occlusion, and it follows the real hinge when the door opens. Existing collision transactions are unchanged. This preserves the decorative seams without letting commands leak through the closed door.

`test_mercenary_breach_door_pick18.mjs` uses the actual source model and camera: centre + seven seam positions pick the locked door, `pickGround()` refuses a rally behind it, opaque cover still blocks selection, and opening the hinge frees the former opening. New regression plus existing physical-clearance/animation tests: **4/4 PASS**. Still 5 visible draws / 204 triangles. LIVE acceptance remains with root.
