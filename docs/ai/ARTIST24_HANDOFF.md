# Художник 24 — передача NPC, 30 сентября 2026

> Продолжение24: сначала читать `ARTIST24_MEMORY.md`. Новые isolated результаты
> посещения типографии и recovery supersede соответствующие строки ниже.
> Старый2.456мм recovery blocker уже исправлен пакетом23 `artist23_floor_fix`;
> source-release/gameplay recovery и LIVE этим не подтверждены.

Пользователь попросил создать новый чат «Художник 24» `01a0f291-6661-7430-bbd8-599c42c32c53` и продолжить там работу Художника23. Работать в том же общем каталоге `C:/Users/Слава/Desktop/Мафиози`; Художник23 после передачи прекращает NPC production. Сначала читать этот файл, затем `docs/ai/ARTIST23_HANDOFF.md`, свежие `COORDINATOR_24_HANDOFF.md`, `AGENT_HUB.md`, `docs/godot/MIGRATION_BOARD.md`, `ARTIST22_MEMORY.md`. Новый действующий root — чат «Координатор 24» `01a0f288-91e5-7092-9d8b-ef7d725cc696`; Root23 уже остановлен. Все рабочие отчёты только в «Общий штаб агентов» `01a0df67-44d3-79c0-b243-fa6a9b891fde`, без прямых сообщений координаторам.

## Точное состояние игры при передаче

30 сентября после проверки процесса: один `MafioziPreview.exe` PID 11604 из `godot/mafiozi_walk/exports/win64/s01-20260930-quality23h-play/`; Координатор24 сообщил, что открыл принятую версию23h. Не угадывать PID при продолжении, сделать свежий inventory. В принятом NPC-пакете есть три исходных жителя с их моделями/ID, попадания из обычного оружия, смертельное точное попадание в голову, сохранённые следы попаданий/кровь, закрытые глаза при окончательной смерти, усиленный точечный импульс дробовика, физическое падение и контакт лежащего тела с ногой. Доказательства — `docs/godot/WEAPONS_23G_CHECKPOINT.md`; 23h добавил багажник/курсор, не новые NPC-механики. Не объявлять 23i и отрыв конечностей частью открытой игры.

Root23 подготовил RPG-кандидат18: `outputs/coordinator23_rpg23i/` и `outputs/coordinator23_quality/candidate18/`; настоящий GPU pair есть в `gpu/COMPARISON18.json`, визуальные кадры в `gpu/visual18/`. На момент передачи нет записи о принятии/публикации кандидата; shared runtime/игра остаются23h. Старый Художник23 изолированно связал RPG ticket → original-three HP/физику/оторванную ногу, сохранив lethal headshot и source random draw ordering: `outputs/artist23_rpg_sever_bridge/HANDOFF.md`, compiled ordinary 781/0 и loaded matrix 835/0. Это test-only root callback, не LIVE. Root23 создал более строгий `blood_proposal` с физическим anchor; не подменять его ранним burst-адаптером Художника23. Медицинский отрыв и руки HOLD, пока нет безопасного оригинального ползания/вставания и skin seams. NPC-импульс не удваивать при отделении ноги.

Свежий отзыв пользователя об открытой 23h: багажник в целом понравился, но после взятия оружия клавишей E иногда требуется дополнительный клик либо управление будто замирает. Пользователь сам сообщит об этом Координатору24; NPC-чат не должен параллельно менять оружейный UI.

## Исходные действия и типография

`outputs/artist23_actions_source/` содержит точный original source one-entry packet `LOCAL_PRINTSHOP_ENTRY.json`, native owner `npc_local_printshop_visit.gd`, source agenda bridge и тесты. Source decision/parity 696 JS случаев и 4885 Godot checks; отдельный owner16 checks, но movement callback тестовый и оригинальный житель не вошёл. Пакет не даёт current registered full-city source authority или LIVE.

`RAMP_CLEARANCE_AUDIT.md`, `RAMP_CLEARANCE_PROBE.json`, `RAMP_CLEARANCE_CLOSED.json`: настоящая открытая дверь +61 floor/entry samples. Консервативный square query host отвергает все61 на физическом пандусе. Точная diagnostic capsule 0.36×1.9m при +2cm прошла физически внутрь/наружу по реальному пандусу (122/117 кадров с контактом пола), а закрытая дверь остановила её на x5.686; три оригинальных NPC в этих пробах не двигались. Outdoor source policy запрещает interior samples30–60, нет one-entry lease. Дальний маршрут resident169 всё ещё теряет контакт с полом около x21.908/y−0.0324. Следующий безопасный шаг: изолированный actor-specific route/lease с исходным .738m source footprint, настоящей дверью/полом/стенами и непрерывным движением оригинального NPC; измерить стоимость и лишь потом предлагать Root24. Не отключать коллизии и не подменять реальный визит тестовой капсулой.

## Другие открытые NPC-задачи

Нелетальное вставание: `outputs/artist22_npc_recovery/RECEIPT.json`, core10261PASS, fixture561/4FAIL и actual-main156/2FAIL; resident72 удерживает 2.456mm skin-floor overlap, RISING p95≈3.7ms. Не подключать как готовое. Переезд машиной требует совместной native-body/underbody проверки с физическим владельцем; прежний sedan no-snag тест9FAIL. Чёрные точки теней NPC/героя: `outputs/artist22_npc_shadow_audit/ROOT_AB_ORDER.md`; причина пока гипотеза, GPU A/B и общее освещение у root. Receiver-off diagnostic не выпускать, он уничтожает настоящие тени. Три жителя и локальный preview не равны полному source-городу. Сохранять модели, IDs, HP/progress/authority, коллизии; headless/fixture не называть LIVE.

Наш участок `godot/mafiozi_walk/scripts/npc_visual` и связанные source exporters/assets/tests/docs. Координатор24 владеет main/player/project/export/LIVE/Git и единственной игрой. GPU/source capture только по отдельному GO, тяжёлые CPU тесты с учётом текущего окна. Пользователь разрешил самому запускать нужные тесты и требовал проверять производительность до включения. Никаких git stage/commit/push от NPC-чата. ToolSearch/Ruflo может отсутствовать: использовать файловую память, не выдумывать вызовы.
