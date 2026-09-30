# Координатор 24 — действующая память

## 30 сентября 17:45 — Esc из багажника исправлен, cargo24b открыта

Новое точное воспроизведение пользователя: открыть содержимое F, затем Esc —
для продолжения требовался ЛКМ. Baseline exact24a подтвердил1клик/0m движения.
Причина: cargo.window_input явно делал close_window(false), затем освобождал мышь.
Candidate22 меняет только этот маршрут на существующий close_window(). Первый Esc
потребляется окном; echo/key-up не повторяют действие; следующий отдельный Esc
вне окна по-прежнему освобождает мышь. Focus-loss guard сохранён.

Exact24b headless26PASS, focusedGPU30PASS, ошибок движка нет; после Esc capture2,
heldW движется0.0342m без клика, UID/ammo/крышка/посадка сохранены, выстрелов0.
PNG after_modal_escape.png просмотрен. Ввод в Godot синтетический; ручная проверка
Windows и настоящий Alt-Tab этим прогоном не доказаны. Добавленной per-frame работы
нет: однострочный key-route использует уже проверенное закрытие окна.

PCK `becb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749`;
209 исходных хешей/артефакты экспорта сверены. Scoped promotion3пути (cargo/main/notes),
1725прочих файлов сохранены. Доказательства outputs/coordinator24_cargo_escape и
outputs/coordinator24_delivery24b. Версия `s01-20260930-quality24b-play` открыта17:45,
PID34044 отвечал; ярлык обновлён. Старой игры24a при проверке уже не было;
ProjectManager45268 сохранён. Всегда свежий inventory, не запускать второй GPU.

Пользователь также поручил показать жителей и сделать новые попадания по уже мёртвым
NPC с сохраняющимися следами/повреждением одежды и небольшим физическим толканием
тел ногами вместо прохода насквозь. Это НЕ входит в24b и ещё не принято.
NPC candidate21/quality24c пока только изолированный base+черновики scheduler/test;
до freeze включить новое Esc24b, не откатить cargo. Художник24 завершает public
navigation lease и реальный визит resident169; latest delivery manifest перепроверить.
Нужны normal-scene visit/combat/perf перед доставкой. Полный roster326 сохранён,
но native подготовлены только3; увеличивать MAX_RESIDENTS без моделей/геометрии нельзя.
DEAD_NPC_AUDIT.md фиксирует два пробела: dead-hit owner не допускает новые marks;
player mask1 не блокируется corpse layer256, а текущий proof требует ненулевого
фактического движения. Просто добавить256 недостаточно. NPC правки через Художника24,
root-owned collision/contact proposal изолирован. Отчёты только в общий штаб.

Cargo24a сохранена и опубликована: `a498d8bcbfcd30bc1601aed10ad86c4a7fd855d9`.
Ниже историческая приёмка24a; её Esc policy заменена24b.

## 30 сентября 17:18 — cargo24a принята и открыта

Текущее пользовательское окно: exact candidate20, `s01-20260930-quality24a-play`,
PID31528 отвечал при запуске17:17; всегда проверять свежий inventory. ProjectManager45268
сохранён. Проектный ярлык «Мафиози — актуальная версия» теперь указывает24a.
PCK `634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5`.
Доставка `outputs/coordinator24_delivery24a/{PROMOTION.json,OPENED24A.json,ACCEPTANCE.md}`.

Исправлены ДВА воспроизведённых дефекта: удерживаемая W/A/S/D терялась после F/E;
directE при удержанной ПКМ сбрасывала камеру до повторного aim/ownership admission.
Восстанавливаются только физически удерживаемые locomotion/run keys при допустимом
focused return; E/fire/SPACE не воспроизводятся. Pre-take cancel_inputs(false) сохраняет
прицел до успешной парной передачи UID, затем обычный reset. Focus/Esc policy прежняя.
Редкий пользовательский extra-click/freeze целиком НЕ объявлен устранённым.
Windows Computer Use screenshot/coordinate input недоступны; ручного OS-input proof нет.

Exact compiled20 headless78PASS; attachedRMB→singleE28PASS; normal focusedGPU136PASS:
mouse capture возвращается без клика, ammo/UID/старое оружие сохранены, keyup отпускает
все9маппингов. Движение тормозит после отпускания:1.8→0m/s за6физических шагов,
ещё3шага без дрейфа, одинаково послеmodal и при обычномW. Первый focused01 FAIL
был ошибкой фиксированных3ожиданий кадров в harness; сохранён, production не менялся.
Shared ordinary startup24PASS после promotion:14guns/3NPC/8buildings/377colliders,
5notes24a без ложного restart banner. Shared01 ошибка типа Node/RefCounted была
только в новом harness; corrected shared02 чистый.

Парный последовательный GPUperf: wallp95 3.758→3.430 /4.539→3.865 /4.393→4.087ms;
GPU p95 maxdelta +0.070ms. Сохранены3NPC/8buildings/377colliders, drawcallp95 те же.
Это offscreen NO_FOCUS с existing cache, не whole-city FPS; first model hover SKIP
на обоих fixed attached camera. Подробные цифры/ограничения в ACCEPTANCE.md.
209source и316payloads проверены; импортные node_id и main scriptUID изменились
из-за fresh import, остальные декомпрессированные байты сцен одинаковые.

В shared перенесены только cargo/weapons/main/preview_updates с before-SHA guard,
1724остальных файла сохранены. Не копировать candidate целиком поверх чужих WIP.
QUIET24 RELEASED через штаб после приёмки; одна пользовательская GPUигра остаётся.
RPG19 изолирован и отложен. Его rebase теперь должен учитывать новую cargo24a,
не откатывать эти исправления через старые beforeSHA16/18.

## 30 сентября, позднее — приоритет сбой управления после багажника

Пользователь подтвердил качество багажника, но сообщил: после E иногда нужен клик
или игра «встаёт». Уточнил, что бывает и по модели, и в окне через F.
RPG19 теперь подготовлен изолированно: только исправление номера в main;210source
проверены, экспорта/GPU ещё нет. Его доставка отложена до исправления управления.
Свежий inventory после пользовательского теста: только Manager45268; открытый ранее
11604 завершён, причина неизвестна, журнал без ошибок. Не выдавать игру за открытую.
Exact23h bounded headless matrix23PASS: directE сохраняет heldW; modalE теряет
action_forward при физически удерживаемойW и даёт0m до нового нажатия. Это доказанный
дефект modal movement, но НЕ полное объяснение обеих пользовательских ситуаций.
Дополнительный клик при blur→focus — текущая политика; Windows probe готовится.
Исправления только в `outputs/coordinator24_cargo_input`; production не изменён.
Независимый аудит directE выявил cancel_inputs→aim_camera.reset→повторныйrayUID:
возможно отказ при прицеливании, проверяется изолированно `coordinator24_cargo_aim_race`.

Параллельно пользователь назначил **Художника24** `01a0f291-6661-7430-bbd8-599c42c32c53`.
Читать `ARTIST24_HANDOFF.md`; не будить Художника23. Новая шапкаAGENTS/штаба сохранена.

## 30 сентября 2026, 16:43 — принята работа зависшего23

Прямое поручение пользователя: «кординатор 23 завис. возьми его задачи и продолжи в этом чате».
Текущий чат `01a0f288-91e5-7092-9d8b-ef7d725cc696`, общий каталог сохранён.
Root24 принимает main/player/project/export/LIVE/Git/оружейную интеграцию.
Не будить старого23. Его чат показывает inProgress, но последняя операция — просмотр
снимков candidate18; новых игровых/проверочных процессов при приёме не было.
Не утверждать, что старый turn технически остановлен: отдельного stop tool нет.
Передачу объявили в общем штабе; NPC23/Transport3/Physics сохраняют владение.
Все отчёты только штаб `01a0df67-44d3-79c0-b243-fa6a9b891fde`, Astra у Проверщика,
остановленный traversal не будить. ToolSearch/Ruflo отсутствуют, используем файловую память.

Последний Git HEAD при приёме `59731b44` — сохранённые изолированные RPG доказательства.
Последний принятый runtime23h — `b334f890d7137bc0a354bd243d8e0f29a0f32012`.
Полная передача23 прочитана по актуальным разделам и восстановлен его последний turn;
историю22 повторно не читать без причины. Подробный аудит: `outputs/coordinator24_takeover/INVENTORY.md`.

## Игра, багажник и новое прямое поручение

Пользователь уточнил «багажник доработали?» и попросил открыть последнюю версию.
Root24 открыл точную принятую23h в 16:42; PID11604 отвечал, только одна игра плюс Manager45268.
Всегда обновлять inventory, PID исторические. Доказательство `outputs/coordinator24_takeover/OPENED23H.json`.
Каталог `godot/mafiozi_walk/exports/win64/s01-20260930-quality23h-play`.
PCK `8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741`;
EXE `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` проверены перед запуском.
E: взять подсвеченную модель/карточку с UID и патронами, без выбора — крышка.
F: окно содержимого. Take сразу возвращает gameplay, без случайного выстрела.
Курсор ivory/gold arrow+hand; Q/X назад, Esc освобождает мышь. Это доставленная23h.
Сохранить открытую игру; новую GPU параллельно не запускать.

## Точное место продолжения RPG

23 остановился ПОСЛЕ candidate18, а не17. Память23 14:19 устарела в части RPG.
Candidate18: `outputs/coordinator23_quality/candidate18`, runtime notes23i;
PCK `9b9f502afacb1c2814782c289916d385e6676b39a856be7d8ad2594b51f677a1`.
`outputs/coordinator23_rpg23i/compiled18/ACCEPTANCE.json`: 415 PASS восьми native runs.
GPU `baseline02`, `candidate18_02`, `visual18` и `COMPARISON18.json` уже выполнены;
старые GPU_PENDING/NOT_RUN строки описывают момент ДО них. 7 PNG, intact3NPC/48parts.
Wall p95 idle4.053→4.558, blast4.085→4.599, second4.033→4.669ms;
max blast8.043→13.068ms. Сцена3NPC/8buildings, НЕ whole-city FPS/326NPC.
Кандидат выполняет новую работу HP/ragdoll; это не одинаковая логическая нагрузка после попадания.
Нельзя выдавать меньше drawcalls после падения за оптимизацию удалением жителей.

Root24 и оба независимых аудитора нашли blocker: `scripts/main.gd` всё ещё сообщает
runtime23h, но notes23i. На реальном PNG виден ложный баннер «перезапустите сцену».
Следующий шаг: изолированный кандидат с единственным исправлением revision,
новый экспорт/проверка полного соответствия байтов и рабочей плашки; затем scoped promotion.
Не переписывать целиком shared project: там чужие NPC/transport/palette WIP.
10 before-SHA guard paths18 при приёме ещё соответствовали accepted16.
Сохранять source horizontal radius11.07m, no NPC LOS, current-impact marksman,
opaque authentic Flight tickets, spread ровно один раз, finite ammo/R reload.
ACTIVE medical secondary body impulse, severing, selfHP, vehicle/building/server
damage не приняты этим пакетом. Industry all-building rollout отдельно HOLD.
Printshop NPC: capsule replica проходит открытую дверь и блокируется закрытой,
но текущий host square overlap и outdoor policy ещё блокируют реальный source visit.

## Автоматизация и сохранение

При начале найден hourly heartbeat `walk-godot-14` на23. Во время передачи его файл
исчез из `$CODEX_HOME/automations`; попытка прочитать перед update не удалась.
UPDATE/CREATE не выполнялись; не объявлять расписание перенесённым и не восстанавливать
исчезнувшую автоматизацию вслепую. Сохранённое пользовательское требование — проверенные
изменения в main/GitHub ежечасно, scoped paths, без add-all/reset/stash/чужих WIP.
Полный перенос Walk, бой/authority, fullNPC city остаются незавершёнными.
