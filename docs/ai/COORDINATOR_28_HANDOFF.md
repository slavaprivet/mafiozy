# Координатор 28 — передача 15 октября 2026

Пользователь прямо попросил создать и закрепить Координатора28, передать весь рабочий контекст. Root27 прекращает production после передачи. Репозиторий C:/Users/Слава/Desktop/Мафиози. Предыдущий чат 01a0fed6-c1dc-75b2-8fda-194f729e8bb8. Новому root разрешены субагенты, реальные прогоны, исправления и интеграция; пользователь остановил DeepSeek. Не будить исторических координаторов.

## Последние прямые поручения — выше старой истории

- Обычное состояние жителя: случайная прогулка, паузы1–3с, обход физических препятствий, настоящая анимация ходьбы и поворот по движению.
- Выстрел снижает HP строго ниже50% → больница. Ровно50% не запускает больницу. Физически войти внутрь, постоять1.5с, вылечиться, физически выйти и продолжить прогулку.
- Энергия строго ниже20% → ресторан. Очередь: если энергия кончилась во время пути в больницу, закончить больницу и выход, затем ресторан. Энергия не снижает скорость, тратится от шагов. Сначала один житель, затем проверенное масштабирование286.
- Больница, ресторан и прочие подписанные здания сейчас являются КОПИЯМИ ПАЛАЦЦО. Не искать/возвращать старые модели больницы. Пользователь разрешает удалять из игры неразрушаемые здания: нужны разрушаемые. Сначала инвентаризировать реальные экземпляры, сохранить архивы, убрать и остаточные коллизии удаляемого.
- Нужны двери как у Палаццо: NPC сам открывает и проходит; игрок также открывает и входит. Последнее уточнение пользователя: «и вроде как дверь дипсик сделал проверить надо». СНАЧАЛА проверить существующую реализацию дверей, не переписывать вслепую.
- Игра/editor пользователя сохраняются. Завершать только собственные диагностические процессы после свежей проверки PID/path/creation. Functional параллельно разрешён, perf только эксклюзивно. Один писатель на файл; никаких запусков недописанного исходника.

## Что уже подготовили root27 и три субагента

Новый изолированный кандидат: outputs/coordinator27_npc_hospital51/game. stage.py скопировал1043файла текущего рабочего дерева побайтно, без .godot; BASELINE.json хранит исходные пины/HEAD. baseline/ содержит исходники до правок. Оригинальная сцена outputs/dsh_living_city_01/game не переписана. Все три агента завершили файлы и заморожены. Новый root может принять эти файлы и назначить своих агентов с непересекающимися участками.

Обязательно прочитать HANDOFF_NAV.md, HANDOFF_LIFE.md, HANDOFF_VISUAL.md в пакете51.

1. game/scripts/hospital/npc_simple_hospital.gd и npc_physical_route51.gd: новый ограниченный физический A* по настоящей капсуле, движение move_and_slide, проверенный step34см, без телепорта/уменьшения коллизии. Сетка.4м, до16расширений/1800мкс за вызов, мягкий бюджет, максимум18kузлов. Дверь использует неизменный owner.anchor, не origin вращающейся створки. Отдельные legs подход/вход/комната/выход. API begin(target,body,map,id,source), step→walking/arrived/blocked, is_inside(), outside_point(). source roam/hospital_exit не классифицируются как новый вход. SHA simple8cf5a3a14fcc51b339560017afb67745f5ec5ec3757173957cb008bdfd5a862f; route194ec6085d8a33ec86d253e9f221d604841e2635b06726c024290c824d5a20f1.
2. game/scripts/npc_daily_life.gd: за --city-simple-hospital=1 INBOUND→проверенная комната→непрерывно1500мс→heal через текущего владельца здоровья/receipt→OUTBOUND→прогулка. --city-hp стал однократной инициализацией, раньше постоянно скрывал лечение. Случайные точки5–15м с проверкой пола, паузы1–3с. SHA9693608dadfe20523cc0eadd6f518ceac072a8cafea2541dfdfe91b41f0f076a.
3. game/scripts/npc_visual/preview_resident_host.gd + hospital/npc_motion_visual51.gd: исправлен конфликт двух записей анимации. daily двигал тело/писал gait, затем host с собственным нулевым движением перезаписывал idle. Теперь host единственный владелец yaw/gait, получает реальные from/to с проверкой frame/body/delta. Текущий физический NPC анимируется и дальше30м. Штатный режим без свежих метаданных прежний. HostSHA4ace11bd10ee19b50431608e33eeecaad9766d3dabc5bb1fb7ae22c6bbdebe19; helper81145ee67f97b63634c9b5cb8c01107b34c2542f053cdd72dd90dc9a57e5a845.

ВАЖНО: всё выше SOURCE READY, НИ import, НИ игровой PASS для нового кода ещё нет. Не выдавать за уже исправленную игру.

Открытый дефект: npc_city_daily._create_visit вообще не содержит restaurant, только hospital/bank/shop/drive. Исходный маршрут restaurant зацикливается unknown_activity. Новый daily честно хранит restaurant_pending/native_restaurant_not_implemented и временно гуляет; это НЕ удовлетворяет полной очереди пользователя. После больницы реализовать настоящий ресторан, не отмечать закрытым. Энергия0 не останавливает движение.

## Источник DeepSeek и доказательства

Документы находятся ВНЕ репозитория: C:/Users/Слава/Documents/deepseek-harness/default-workspace/MAFIOZY_STEP0_PACKAGE.md, MAFIOZY_NPC_REPORT.md, MAFIOZY_PROMPT_FOR_COORDINATOR.md, MAFIOZY_STEP0_HANDOVER.md, AGENT_SYNC.md, MAFIOZY_LINEAR_BRIDGE.md. Прочитать пакет/полный prompt. Там команды/логи/пины. DeepSeek остановлен пользователем.

Исторический tag scene-accepted-2026-10-15 →2d98dfd2e6bcbe75182c9db4ca33cce8da44f58d. Последний наблюдавшийся HEAD4c5ce4a6 (проверить свежий). В метке нет последнего физичного движения/дверей; оно оказалось в более новом рабочем слое.

DeepSeek сообщил: OriginalPlaza не зарегистрирована как пол → current_source_floor_missing,0шагов, очередьпуста; flag city-plaza-support-plate исправил до13.3м. Касание капсулы пола мешало плану. Повышение pathbudget4000→12000мкс снизило ожидание10.4→.19с, НО p05FPS70→12–15, это не принятая оптимизация. Длинные пути NO_PATH111→15 всё ещё застревали15.4м. Фасад не равен входу! Клонбольницы за исходной navcrop; местный физический поиск нужен по актуальной геометрии, включая проломы.

Сценарий: resident_1, старт(42.2,.13,-2.5), больница TownClone_1 origin(70.5,0,0), старый marker(72.11,.30,-1.32), AABBx58.5..82.5,z-12..12. Эти точки надо сверять с фактической дверью. Ранее marker/leaforigin были ошибочны.

## Запуски, процессы и следующий шаг

Движок C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe; версия4.7.2.stable.official.ed1daf0bf; SHAab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424.

Scheduler: tools/godot/test_scheduler.py, docs/godot/TEST_SCHEDULER.md. probe перед запуском, run --mode headless --access write для import, read для игры; --project точный game, --wait-seconds30 --timeout180/300/600 --out новыйлогдир -- engine args. До2headless+1graphical, perf отдельно. Не обходить чужие процессы.

Root27 запустил видимую ИСХОДНУЮ сцену (не candidate51), scheduler outputs/coordinator27_npc_hospital51/baseline_gui01, shellsession50777, timeout600. Последний свежий inventory15Oct: PID19872, creation2026-10-15T00:43:44.926033+03, путь original dshgame, own diagnosticroot27. Перед любым действием обновить inventory: мог завершиться. Передаётся root28 для диагностики; не завершать никакой другой процесс по старому PID. Полная команда сохранена в SCHEDULER_RUN.json либо процессе/логах.

Flags исходного запуска: res://scenes/main_city.tscn -- --city-qa=1 --city-resident-name="тест 1" --city-resident-diag=1 --city-simple-hospital=1 --city-plaza-support-plate=1 --city-medical-threshold=0.5 --city-energy-drain-per-m=0.05 --city-energy-threshold=0.2 --city-palazzo-clones=1 --city-clone-step=22 --city-town=1 --city-door-free-entry=1 --city-site-door-physics=1 --city-needs=1 --city-shop-release=1 --city-nav-pump-budget-us=12000 --city-nav-pump-every=1 --city-daily-slice=286 --city-walk-pose=1 --city-pose-far-cap=512 --city-clear-cache=1 --city-timing=0 --city-health-lease --city-resident-detail=1. HPoverride не задан, чтобы стрелять реально. free-entry может маскировать дверь: отдельно проверить реальную дверь с правильными флагами, исходники DeepSeek сначала прочитать.

1. Проверить pins целых файлов, import candidate51 (--headless --editor --import --quit). Исправить ошибки, затем реальные bounded прогоны49HP и50HPnegative. Для полного цикла нужны entered/treated/exited/roam, лог+геометрия, не только близость к marker.
2. Проверить существующие двери копий Палаццо, открыть NPC и игроком с обеих сторон. Закрытая створка физически блокирует, открытая даёт проход. Выход тоже физический.
3. Проверить настоящим выстрелом через текущий weapon/hit pipeline, а не только debugHP; анимацию/поворот/обход/1.5с/очередь. Никаких ложных PASS.
4. Довести restaurant очередь, замерить стоимость, затем интегрировать проверенное и показать игровое окно.286 не включать вслепую.

QA observer: пакет51/qa/visual_observer.gd вне res://. Можно скопировать в приватнуюgameQA, Nodeподcurrent_scene, resident_id/output_path; save(), awaitcapture_png(absolute). Реальные thigh rotations/yaw/капсула/позиция, priority1000. Нужен engine viewport screenshot.

WindowsUI: навык computer-use был прочитан, @oai/sky через mcp__node_repl__js. sky.list_windows находит игру, но get_window_state дважды failed FrameArrived/window capture timeout после восстановления. Никаких кликов/выстрелов не делалось. Не выдумывать визуальную приёмку, не обходить skill через Win32SendInput/самодельный screenshot. Engine viewport observer допустим. Новый root перечитывает skill передUI.

Ранее outputs/coordinator27_npc_step0_20261015 был gitarchive baseline: importPASS19.385s, но runtime bootstrap failed current_city_block_pin. Причина упаковки: gitarchive нормализовал окончания, city_blockSHA стал5e504… вместо реального38b4b50ca06fb60172173b04c5b49ff567a84509ea01901a24306ab0d3b41dc7. Это НЕ доказательство ошибки исходной игры. OwnPID18192 остановлен root27. Новыйstage51 byteexact решает упаковку; не повторять gitarchive для этихпинов. Тамошний hp45 не прошёл bootstrap, hp50 не запускался.

## Интеграция, память, коммуникация

godot/current_version.json всё ещё version48, фактически artist24_melee_contact/merged_root48_08/ASSEMBLY.json SHA10f29304511fb705d0b18fc7db9a5a76fcd001f59c9225b2c4194ca201fa11f9. Это ранее разрешённое обновление artist, НЕ откатывать на старыйrelease48. Кандидат51 НЕ опубликован/F5непереключён. Архивы сохранять. Gitstageтолько свои проверенныефайлы, никаких stageall/forcepush/пустыхcommit. При проверенных изменениях main+origin каждыйчас, подтверждать SHA. Проверитьgitstatusсвежий; root27 docs memory/backlogмодификациисохранять, .godotcacheневыдаватьзаproduction.

Linear заметка https://linear.app/mafiozy/document/zhiteli-deepseek-i-koordinator-zadaniya-i-progony-godot-30c6e5c9b0b6 ; documentID061ba02a-e247-41c7-9b0b-0791aabf68ab, issueMAF-5 UUID97d3c4fb-68da-4fd0-a148-d8d676bfc3e2. Полныйuserpromptтамдобавлен. DeepSeekSPAнечитает, естьlocalbridgeвыше. АктуальнаяработатеперьCodex, внешние сообщения без необходимости не отправлять.

Для широкой истории читать docs/ai/COORDINATOR_27_MEMORY.md и COORDINATOR_27_HANDOFF.md, MIGRATION_CONTINUOUS_BACKLOG_20261003.md, ASTRA_CONTINUOUS_DISPATCH_20261003.md. Старые heartbeatуказания не должны отвлекать от актуального жителя/дверей. РуководительАстра01a0f2a3-81ab-7fe0-b1b1-c259c97818c6, общийштаб01a0df67-44d3-79c0-b243-fa6a9b891fde; старые paused traversal/координаторов не будить. Единственную automationgodot-4 переноситroot27, дубликат не создавать. На диске оставалось~6.8GB, не копировать всюrepo.
