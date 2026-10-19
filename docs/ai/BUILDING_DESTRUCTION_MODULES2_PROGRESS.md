# Buildings2 — общие модули, 30 сентября 2026

## Актуально 1 октября: frozen40 проверен, новые требования41 ещё в работе

Root26 `01a0f41b-db0e-7540-a5bd-2e0eb68b8fd4` — действующий координатор;
старого25 не будить. QA token ROOT26-B40-20261001-0010 RELEASED. Root26
владеет следующим engine/F5/current-launcher слотом, Buildings2 двигатели
не запускает до нового согласования. Единственную игру оставляет root.

Frozen40 `outputs/buildings2_c4_glass40/ASSEMBLY.json`, 299 pins,
SHA3b3544d958a87db8c74abe24101f5c9a5cfc1a71a186a6ac8d58831e6bf607ed.
Полная передача `outputs/buildings2_c4_glass40/HANDOFF_ROOT26.md`.
Не менять40 и НЕ запускать refresh40: city_candidate уже содержит41.
Manifest отражает момент staging; actual результаты в RUN/RESULT и handoff.

Настоящие прогоны: support39_01 839PASS; support39_native04 141PASS;
finished40_01 175PASS; c4_glass40_02 61PASS; c4_glass40_gpu01 69PASS.
Все exit0/ошибок0. Реальный E/W/S, RPG4+4, TT→стекло, RPG→стекло→стена,
обвал безопорных частей, C4 Q/hold3sec/remote/таймер проверены. GPU timer
и afterblast скриншоты просмотрены. Последний fixed-camera matchedperf
perf292_02→perf40_02: p50 7.045→6.990ms, p95 9.620→9.743ms,
draws1374→1411, RSS1.585→1.672GB; исходные8зданий/3NPC сохранены.
Это не fullworld287/allcity PASS; экспорт и source-isolated pack не проверены.

Последние требования пользователя: близкая закладка, подробная C4 и движение
рук, любая поверхность карты, ранение/смерть немедленно прерывает hold.
41 SOURCE ONLY: c4_equipment REACH1.35/horizontal1.15, generic PhysicsBody;
c4_visuals подробная модель и временные arms/chest. Ground/crouch требует
согласованного equipment pose hook вместе с dive39, shared player не трогать.
API interrupt_for_damage отменяет только текущую установку, новый hold после
release/press, без создания damage receipt или HP. Actual hero HP/incoming-shot
producer в текущей native игре отсутствует; Root26 уведомлён. Не объявлять
настоящую отмену от стрельбы готовой до подключения и native проверки.
Все прежние статусы NOT_RUN ниже — история, заменены результатами выше.

## Позднее 30 сентября — пользовательский показ, опоры, стекло и C4

Прямое «ты сам то подключи» разрешило Buildings2 собственную интеграцию.
Обычный игровой Palazzo уже собран в `outputs/buildings2_palazzo_live/`:
frozen292 `ASSEMBLY.json` SHA2f5e36118c5b9aa5ef7850321d49cabfb42dee5d053621f547dae8e85deeca95.
Root25 показывает этот isolated source preview с внешним ammo50 bootstrap;
исторический PID29176, launcher session10946, перед действиями нужен свежий
inventory. Production25a не заменена, frozen292 не менять во время осмотра.
Площадка/4дерева/2скамейки и E сохранены, добавлены реальные каменные пандусы.
Native01: реальный W/S вход/выход без прыжка и K97/Jreset PASS; Eпослезакрытия
и RPGaimfixture FAIL, исправлены только в исходниках без повторной QA.
Скриншоты пользователя подтвердили реальные RPG разрушения, но НЕ matchedperf.

Пользователь показал зависший верх после уничтожения нижних стен. Это новый
приоритет и отменяет исторический запрет ниже на support работу. Новый
`city_candidate/building_support.gd` использует реальные foundation/plaza,
связность collision bounds, grid2м/contact.05м, bounded работу и8 gravity
releases/кадр. `palazzo_support39.gd` разворачивает неподдержанные стены в
существующий pool; не создаёт фальшивый RPG, не ждёт K. Неразбиваемые секции
возвращают passthrough[body], иначе helper законно отклонит пустой hook.
`test_support.gd` готов, НЕ запускался; stage_support39.py готовит отдельный294.
Движки/headless/GPU/тяжёлые копии сейчас OFF по окну Root25: пользователь играет.
Новое QA окно запрошено через Root25 и штаб, подтверждения ещё нет.

Новые требования: все старые дома заменить семейством деревянных разрушаемых
2/3этажных зданий с разными размерами/формами/планировкой/цветами; обычные пули
тоже выбивают дерево. Настоящее прозрачное разбиваемое Walk стекло, убрать
щели между блоками. `city_candidate/REPLACEMENT_PLAN.json`:7 текущих неактивных
фасадов в phase1, functional printshop отдельный phase2;78source placements
НЕ являются78живыми домами. Все здания ещё НЕ готовы. Source family/navlease
и host подготовлены, не подключены. Finished окна имеют реальные проёмы и
compound осколки; ожидается2069collisions вместо657, общая цена НЕ проверена.

C4: выбор через существующий Q, удерживать ЛКМ3сек у стены; заряд-липучка,
пульт, взрыв3×РПГ. Последнее требование — красивый текст+таймер. Подготовлен
`city_candidate/c4_equipment.gd`: ivory/gold карточка «Установка C4», кольцо,
3,0→0,0с, «Заряд установлен»; ранний отпуск отменяет. Отдельный remote выбор,
до8зарядов, после установки пульт. `c4_building_blast.gd` сначала потребляет
реальный одноразовый charge receipt, затем очередь1взрыв/physicsframe, чтобы
первый взрыв не отменял остальные бомбы на той же стене. Pin world.preview_c4,
отдельный честный C4glass dispatch; не fakeRPG. Directbudget12tiles против4,
radius2.4 против.8, power480 против160. QAfixture test_c4.gd готов, НЕ запускался.
`palazzo_structural_site.gd` объединяет finished/glass/support. Stage40 готовится
отдельно, открытая292 не меняется. Root25 отдельно ведёт orphanmarks37 и dive38.

Все перечисленные поздние support/glass/wood/C4 изменения SOURCE_ONLY_NOT_RUN.
Нельзя объявлять парсер/native/GPU/performance/экспорт или весь город PASS.

## Native Палаццо принят как компонент, три простых варианта готовы

Позднее поручение: «добавляйте проверяйте», «просто с другой планировкой и
раскрасить по другому их». После RELEASED25 и разрешённого прогона точный
Палаццо прошёл1362 native headless проверки,0errors, PID12868 exit0. Три новых
prefab наследуют этот же контроллер: кирпичный с двумя комнатами, серо-зелёный
с коридором, светлый с передним залом. Изменены только4 цвета и внутренние
перегородки; новая механика разрушений не создавалась. Варианты51PASS, PID10572
exit0/0errors. Первая попытка выявила слишком широкую секцию перегородки;
исправлено повторением исходных модулей до1.98м, прежний local4 сохранён.

`palazzo_site_candidate/READY_RECEIPT.json` SHA
`9bc79e7c72021b8e5678f9e29aa12ed5918227aa4f915443225d3a80b598528c`.
Статус NATIVE_FUNCTIONAL_PASS_LOADED_GAME_PENDING. Пакет и результат переданы
в штаб для Root25. Исходные4 runtime-файла не менялись; новые варианты отдельные.
Root25 выполняет размещение, нативныеE/RPG, прохождение21смступени, GPU и
сопоставимую нагрузку. Ни основной Палаццо, ни варианты здесь не объявлены уже
включёнными в игру; все78 старых размещений также не объявлены готовыми.

## Последнее прямое поручение: точный Палаццо, участок и дверь

Пользователь повторил, что нужны ОБА режима из первого показа: разрушение стен
и полное разрушение дома. Приложенным скриншотом подтвердил именно
`outputs/destruction_showcase_20260930/intact.png`, затем прямо попросил внести
этот дом в игру «вместе с площадкой деревьями скамейкой» и добавить открываемую
дверь. Сохраняются 22×18 м площадка, четыре дерева, две скамейки, архитектура,
материалы и прежнее поведение. Подтверждён новый главный Координатор25
`01a0f38a-404b-71b1-a2f6-b7edeb29b725`;24 больше не будить.

Подготовлен `outputs/building_destruction_modules2_20260930/palazzo_site_candidate/`:
исходный showcase сохранён отдельно, адаптер участка не создаёт демонстрационные
камеру/игрока/UI/небо. Размещение, настоящий игрок/оружие/E и окончательная общая
приёмка остаются у Root25. Полное обрушение — прежний явный сценарий трёх этапов;
сложную новую structural/support ветку не возобновлять. Нельзя сузить поручение
до локальной пробоины или объявить все78 размещений подключёнными.

Передача `palazzo_site_candidate/HANDOFF_ROOT25.md`: точные четыре runtime-файла,
адаптер SHAebac39944f743c532730fd2a793a98fd83cb7df4773d6d5350276292a1557a92,
SOURCE_PROOFce3262… и независимый source review PASS. Дверь90°/.5с, настоящая
коллизия и соответствующие фрагменты открытого полотна. Полный native fixture
готов (test SHA764bacd3b9706a00e52c1cdaeb58e4e402356d86ee2d7a29bfea41ec6f19776e),
но НЕ ЗАПУСКАЛСЯ из-за QUIET25. Ни compile/native, ни реальный E/weapon, ни общая
GPU приёмка не заявлены. Точный статус SOURCE_REVIEW_PASS/NATIVE_TEST_PENDING_QUIET25.

Отдельное небольшое исправление нынешнего modular013 готово в
`expansion/showcase_restore/`: `RESTORE_RECEIPT.json` SHA
`b2126d9d724819c3727d75bbe668a2619d8c05a4c51817faf2e3c5d9f02283bd`.
Per-piece native151PASS + точный frozen013 A/B: четыре обломка, наружное движение
за .45с выросло .78–.88 → 1.42–1.50 м. Это разлёт, не исправление задержки/ступени.
После чтения актуальной памяти25 действует QUIET для street-lamps; новых engine
запусков здесь нет до освобождения окна. Исходный Палаццо имел до554 awake в stress;
перенос не является уже принятой производительностью общей игры.

## Позднее прямое исправление приоритета пользователем

Пользователь: уже была хорошая механика, нужно сделать такие же разрушаемые
дома; нынешний тест хуже прежнего показа. Support/full-collapse разработка
ОСТАНОВЛЕНА и сохранена отдельно, не условие массового подключения.
Возвращаем ПРИНЯТЫЙ showcase `outputs/destruction_showcase_20260930` v3:
быстрый локальный пролом, разлёт лёгких отталкиваемых «как пенопласт» кусков,
проход настоящего героя в обе стороны. Полное обрушение — отдельное действие.
Эти два исправления унаследовал Root25; работы остановленного24 не дублировать.
Buildings2 сравнивает показанный prototype/его параметры с frozen33, затем
распространение готового результата на существующие23templates/78placements.
Новое инженерное усложнение не подменяет эту приёмку.

**Позднее направление — новые модульные здания с разной планировкой.** Текущая
передача: [BUILDING_DESTRUCTION_MODULAR_NEW_BUILDINGS.md](BUILDING_DESTRUCTION_MODULAR_NEW_BUILDINGS.md).
Source-preserving candidate ниже сохранён отдельно и уже у Root24.

Поздняя передача Root24 завершена: immutable `modular_townhouse013_companion`
(receipt `437c8713…`, точный current дом, PASS106 register/reset) и
`modular_library78_companion` (receipt `930d86c6…`, 23 модели/78 размещений,
PASS669 SHA/source validation). Оба внутри outputs/building_destruction_modules2_20260930;
пакеты не менять. Полные SHA и ограничения в текущей передаче по ссылке выше.
Root ведёт candidate30/native RPG/W. Это ещё не all-building LIVE/FPS/owner
приёмка; полное обрушение ещё не принято. GPU здесь не запускался.

## Сохранённая изолированная ветка — потеря опоры точного townhouse013

По поручению Root24 готовится отдельное дополнение
`expansion/support_collapse013/`: граф контактов реальных остаточных тел,
поэтапное отделение максимум двух кусков за транзакцию, тяжёлые обломки с
настоящей массой и сохранёнными материалами, общий лимит64 динамических тел
и максимум8 тяжёлых. Frozen33, frozen013, library78 и production не менять.
Native component QA: graph331PASS, detach318PASS, structural pool+cross-pool
support bridge101PASS. Runtime compile без ошибок. Whole-house FAIL после
116supported baseline и local blast: raw Hollow clip endpoints расходятся2ULP;
реальный mesh assembler уже сваривает их, raw support snapshot этого не отражает.
Подробности `support_collapse013/SUPPORT_STOP_HANDOFF.md`. Новых engine/adapter
работ по этой ветке после пользовательской корректировки не вести.
Проверка whole-house использует явно обозначенный geometry-kernel разрез
опор, не выдаётся за стрельбу native RPG или общую FPS-приёмку.

Общая зависимость между старыми мелкими и новыми тяжёлыми обломками реализована
и проверена native contacts в обе стороны, отмена/общий64/reset сохраняются.
Исходный frozen013 имел реальные float32 зазоры между этажами1–2ULP и baseline
44supported/72detached. В новом отдельном townhouse013_support_ready.scn
исправлены common authored planes/лестничная grid; бетонные solid-ступени явно
bearing_stair_core. PASS27059, saved/reloaded116supported/0detached, graph EPS
не ослаблен. SHA05ff7436b207cc97d6ba0b179f4b239f0e1dd9d225b6a64c0eb8094c5b4dd274.
Максимум world vertex delta1.966050µm. Frozen013/33/library78 не менялись;
повторная библиотечная проверка669PASS. Это не full-collapse/LIVE acceptance.

Native gateway описан в expansion/support_collapse013/NATIVE_ADAPTER_CONTRACT.txt.
Root24 подтвердил hidden old visuals, отсутствие активных glass/Edoor013 и
существующий conservative original-hull navigation lease. Будущий gateway должен
использовать этот owner, не создавать вторую систему. Текущий controller пока
только isolated fixture: любые external owner Callables отклоняются; отдельный
verified Root lease/revoke gateway ещё не реализован. Shape_id/generation могут
меняться при волнах, stable replacement body/runtime должны сохраняться.
Точные source owner nodes/двери/стекло переданы Root24 отдельно в
`expansion/modular_buildings/townhouse013_runtime_owner_audit.md`.
Старые14 стеклянных панелей не соответствуют22 новым оконным проёмам;
дверные полотна шире новых проёмов. Это внешние owner-обязательства,
не автоматически готовые двери/стекло нового дома.

Прямое поручение пользователя: делать **все здания**, ускорить работу общими
коробками/модулями с разными скинами. Это продолжение, не сокращение до gunshop.
Чат Buildings2 `01a0f2a0-1629-7063-a462-913fd6b939be` сохраняет компоненты;
Координатор24 сохраняет main/player/Git/экспорт и единственную видимую игру.

Старый `outputs/building_destruction_rollout_20260930/verification/BUILDINGS2_READY.json`
заморожен для принятия root24 и в этом этапе не меняется. Новая работа целиком в
`outputs/building_destruction_modules2_20260930`. Vendor-зависимости скопированы с
проверяемыми SHA; production и source GLB не изменены. Engine только headless,
последовательно. Работа продолжается; это не all-building READY.

## Замороженная передача root24

`outputs/building_destruction_modules2_20260930/delivery/RECEIPT.json`
SHA256 `c95040f1c63f205a60d6a84dc1f8f488d0907acf46a78a315e093c5541a59dc2`.
Все 37 файлов проверены по SHA и размеру; delivery больше не редактировать.
Конкретное первое применение — node75 Ground facade armor по запросу root24:
настоящая широкая плита .493499964 м, source/frame/geometry pins и строгие caps,
без ослабления материала. Stone strength примерно 283.7625. Binding в
`delivery/modules/armor75_binding.json`; root должен повторить native RPG/W.
Private runtime включает новые dispatch, восстановление material overrides и
совместимый pool mask1/1025. Production/LIVE ещё не принят; all buildings false.
Последующая массовая работа находится в `expansion/`, отдельно от delivery.

## Реализовано

- Полый корпус из точных исходных convex-плоскостей: наружная форма/скины
  сохраняются, внутренняя полость отделена от материала стен. Углы разделены
  последовательным отсечением остатка, противоположные стороны не получают
  двойной объём обломков. Это явно новые gameplay-рецепты, а не восстановленные
  исторические сведения о составе стен.
- Общая поэтапная вырезка, накопительное состояние, повторные и перекрывающиеся
  отверстия. Кэш последних32ударов не ограничивает общее число выстрелов.
- Поэтапная сборка меша, сохранение оригинальных атрибутов/провенанса; исходные
  значения отдельно от измеренной повторной упаковки нормалей движком.
- Закрытые обломки из удалённого объёма, дополнительное ограниченное деление
  крупных кусков; прежний лёгкий пул обломков и атомарная замена коллизий.
- Private `candidate_runtime.gd`: прежний проверенный host через новый dispatch.
  Для старых небольших монолитных деталей оставлен pinned adapter. Новый модуль
  корпуса включается только явным профилем. Override исходного фасада запекается
  в его поверхности, чтобы не перекрашивать внутренний материал пролома; reset
  и dispose восстанавливают исходный override.
- Source decomposition даёт townhouse Shell3012tri как69 закрытых компонентов,
  не69 новых видимых объектов. Компоненты пока не означают готовое массовое
  разделение render/physics authority в игре.

## Сохранённые проверки

- `modules/hollow_report.json`:35 PASS, настоящий Long armory shell gunshop,
  108tri/78 геометрических плоскостей. Outer1295.13м³ → air1146.27 и walls148.86;
  вырез1.5×2.2×.2м удаляет .66м³. Mask1 луч и стоящая капсула1.7м проходят,
  соседняя/задняя стены остаются; повтор не дублирует обломки.
- `modules/runtime_hollow_report.json`:24 PASS. Реальный импортированный корпус
  через inherited receipt/damage/pool/collider/reset/cancel. Stone.3 world-design:
  первый power160 держится, второй меняет основной корпус,8 обломков. Это
  receipt-level тест, **не стрельба настоящим nativeweapon**.
- `modules/runtime_hollow_override_report.json`:28 PASS, дополнительно правильные
  поверхности наружного override/внутреннего материала и восстановление.
- `modules/dispatch_report.json`:79 PASS: крупный вырез .99м³ делится до pool
  limits, бюджет2000 совместим с assembler1000,40 отдельных отверстий, старый
  повтор после удаления из кэша не возвращает объём; source/recipe/frame guards.
- `panels/verification.json`:222095 PASS, все source face IDs без потерь;
  native codec normal/tangent drift отдельно от точного raw attribute oracle.
- `modules/mesh_assembler_report.json`:14327 PASS. Вместо synchronous25–31ms
  сборка разложена по шагам: native initial/cut max .612/.725ms, total21.04/26.19ms
  в этом headless. Это кооперативный бюджет, не жёсткий realtime deadline и не FPS.
- Profiles:19657 Node checks; catalog hollow candidates:3514 Node checks.
- `modules/mass_hollow_report.json`:113749 QA assertions PASS,48 попыток/13
  моделей,37 native PASS и11 `wall_core_fills_source_interior` HOLD. Это тонкие
  исходные детали, для которых делается отдельный measured-solid путь.
  Все23 модели/78размещений присутствуют в сводке;13 моделей ≠ весь город.
- `modules/measured_solid_report.json`:308 PASS. Все 11 тонких деталей получили
  корректный measured-solid путь; отдельно точный Armor75 и настоящий bank roof.
  Корпус здания не подменяется заполненным solid; реальные отверстия и коллизии.
- `modules/missing_channel_report.json`:1921 PASS, сохранены исходные packed
  каналы; добавляется только отсутствующий UV у untextured исходников. 16
  structural деталей, включая 4 primary nightclub корпуса, доступны этому пути.
- `compatibility/rubble_1025_report.json`:125 PASS реальной физики и exact patch
  reconstruction 11 PASS. Layer2/mask1 или1025, прочие guards неизменны; маска
  персонажа никогда не меняется. Frozen/vendor не изменены.
- Финальные runtime24/override28/hollow35/dispatch79 заново проходят после
  подключения measured dispatch и совместимости маски1025.

## Активные незавершённые направления

1. Corner review завершён: каждый fragment замкнут, volume/physics проходят.
   Strict zero-overlap остаётся FALSE. Exact dyadic SAT подтвердил реальные
   float32 пересечения глубиной до .353 мкм; независимый ULP-бюджет их покрывает.
   Strict FAIL и доказательство сохранены отдельно от precision-budget PASS.
2. Массовые measured-solid привязки по всем исходным структурным компонентам:
   `expansion/measured_catalog`. Не считать наличие плана включённой физикой.
3. Невыпуклые корпуса pavilion/hospital/civic: точный разбор сохранённых
   генераторов и triangle sectors в `expansion/complex_sources`.
4. Составные source nodes (townhouse), невыпуклые/открытые сложные оболочки,
   printshop/interior/door/window authority, дозированное включение всех78мест.
5. Настоящий текущий24 nativeweapon, персонаж, видимый GPU и сопоставимые общие
   frame-time/memory после rebasing — только с root24; этого этапа ещё нет.

`model_after_node` толщина в geometry-kernel учитывает normal-dependent scale.
Inherited damage ledger пока имеет один scalar strength, поэтому dispatch для
новых оболочек принимает только явный `world_metres` gameplay-design профиль,
а model-scaled вариант честно отклоняет до per-plane damage ledger. Не тихо
переименовывать model metres в world metres.

Рабочие отчёты — в общий штаб `01a0df67-44d3-79c0-b243-fa6a9b891fde`.
Никаких новых GPU окон, рестартов production или Git операций Buildings2 не делал.
