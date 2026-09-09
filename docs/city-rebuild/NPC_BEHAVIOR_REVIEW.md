# Проверка существующего поведения NPC перед переносом renderer

2026-09-09. Аудит и последующие две адресные правки world.html по разрешению владельца; server не изменён. Дополняет NPC_WORLD_INVENTORY.md. Не заявляет построчную проверку всех 70 тысяч строк или прохождение всех server suites. Ниже проверены центральные dispatchers, переходы, контракт авторитета и конкретные воспроизводимые дефекты.

**Статус после разрешённых правок:** из updateGangAggression удалена только отправка legacy gang_dmg при косметическом входящем выстреле. В _npcSenseNearbyDanger первые24 глобальные машины заменены общим пространственным индексом активных машин (ячейка3 тайла, обновление250мс), ближайшие кандидаты из соседних ячеек, прежний лимит24 и все предохранители. Это улучшение существующей AI, не второй AI. Остальные рекомендации ниже остаются планом; старый тест почти100% косметических попаданий отдельно не менялся.

## Что уже работает и должно остаться единственным AI

| Система | Точка исполнения и состояния | Владелец результата |
|---|---|---|
| Гражданские | `updateNpcs` world.html:16261 вызывается из update (37110). Перед акторным циклом синхронизирует охрану/эскорт, очередь маршрутов, жителей внутри, популяцию, разговоры, эмоции, отношения и life tick. Каждый tick сбрасывает walking, затем только реальное движение выставляет его снова. Мёртвые фиксируются на первой deathR/C; раненые ползут/истекают кровью, knockout ждёт таймер. Диалог с игроком останавливает маршрут; опасность отменяет мирный разговор/помощь. | Клиентская симуляция основной страницы + действующие server hooks. Renderer не заменяет этот цикл random wander. |
| Жизненные реакции | `_npcLifeTick`16058: раз/250мс, максимум18 акторов с вращающимся cursor; helper раз/1000мс. Состояния15870: idle/routine/social/alert/panic/cower/help/helping/surrender/injured. Приоритет: injured → surrender → panic/cower → helping → alert → social → routine. `_npcBeginPanic`15975 учитывает пригодность свидетеля, несражающийся/неоглушённый статус и event priority. | Те же объекты NPCS, память max6/TTL60с, social group max4, speech max5, state cooldown650мс. Не сбрасывать память при renderer culling. |
| События опасности | bullet60, fire50, vehicle40, corpse30, fight20, social10, routine0 (15892). Стиль freeze/cower/call/flee, источник опасности и память. Помощь требует достижимого route/близости и отменяется при бою/панике. | Исходная life state machine; не выбирать реакцию повторно в новой анимации. |
| Городская полиция | `updateCityCops`11388: восстановление патрулей от штаба, тюремный штат, assault alarm, pursuit/response. `prison_staff`/`murder_response` имеют собственные обработчики; arrest_* исключает generic collision recovery. Пока игрок внутри bank/building, уличные копы не используют его интерьерные r/c. Bank response держит пост у входа. | Клиентский маршрут/служебная сцена + серверная полиция, wanted, jail и authoritative damage. |
| Полиция реагирования / задержание | Серверный cops snapshot → applyCopsTargets; murder response имеет поездку, посадку/высадку, поиск, бой, handoff/booking. Существующий транспорт переносит arrested player и скрывает transported NPC. | Не запускать второй chase поверх arrest/custody; не телепортировать копов к камере renderer. |
| Банды | Серверный WorldSim owns aggro/city gangs/nests, spawn/replacement, tactical act, shots/hits/custody. Клиент сохраняет представление и отдельные ambient/cars функции. | Для живых серверных бойцов читать snapshots/события; рендерер не выдумывает атак/урона или найма. |
| Боссы, эскорт, охрана | npc_empire.advance3289/state_for4626; клиент sync crews/holding guards, queue routes, stall watch, `_empireFieldCombatThink`10327 и `_empirePlayerCombatThink`10412. Состояния: activity travel/meeting/engage/defend/raid/recovery/hospital, рекрут approach→talk→confirmed promotion. Переговоры запрещают параллельный patrol/combat. Для candidate оружие/семья включаются после подтверждения платного набора. | Серверная империя и encounter tokens/shot receipts; клиентские физические маршруты и анимации. Не использовать начальное hp999999 как боевое. |
| Войны/интерьеры | Босс против игрока исключён при _buildingInt/_bankInt; interior raid имеет roster/slot/casualty checkpoints и resolve. Внешние координаты и локальные room coordinates различаются. | Существующие server endpoints и business/interior state. |

## Найденные дефекты и три ограниченных улучшения

### 1. Устранить устаревший запрос урона из обстрела gang-машины

`updateGangAggression`17875–17922 рисует incoming shot и отправляет `{t:'gang_dmg',d:{dmg,sx,sy}}`. Комментарий обещает списание hp, но **server handler mafiozi_bot.py:34093 уже намеренно не доверяет такому урону**: он увеличивает wanted_gangs не чаще раза/4с. Следствие по коду: получая косметические выстрелы, клиент повторно повышает угрозу банд; hp-комментарий неверен. Не возвращать серверу доверие client dmg.

Дополнительно в том же блоке missR/C=(random−.5)*.7, а isHit требует abs<.35: практически каждый выстрел объявлен попаданием (кроме точной граничной выборки random=0). Детерминированная выборка1000/1000 даёт hit. Это не настоящий шанс промаха или проверка касания.

Ограниченная правка: отделить визуальный car-shot от любых gameplay packets, убрать legacy gang_dmg из пути incoming visual shot; отображать действительные подтверждённые server shots/hits либо явно оставить косметический tracer без обещания урона. Если нужен threat bump от действий игрока, направлять его из существующего проверенного действия игрока, не из получения вражеского выстрела. Не менять урон/скорость/cooldown authoritative AI.

Проверка после правки: во время ожидания под косметическим обстрелом wanted_gangs сам не растёт; server-auth shot всё ещё меняет body/armor по своему receipt, нет двойного hit. Сохраняются `test_npc_player_damage_authority.py`, `test_world_gang_ballistic_arrival.py`, `test_npc_gang_ballistics.py`, `test_npc_melee_directional_block.py`. Эти server suites здесь перечислены для следующего этапа, не объявлены запущенными.

### 2. Убрать постоянную слепую зону гражданских к машинам после индекса23

`_npcSenseNearbyDanger`16034 использует только `for(i=0;i<Math.min(24,CARS.length);i++)`. Это бюджет, но он навсегда игнорирует остальные машины вне зависимости от дистанции. Воспроизведение actual extracted function: одна и та же движущаяся машина рядом с жителем вызывает панику на индексе0, но не вызывает на24 при 24 припаркованных впереди.

Ограниченная правка: один раз за life tick строить/переиспользовать пространственные ячейки ближайших активных машин либо ограниченный round-robin candidate cache; передавать жителю ближайшие кандидаты, сохраняя бюджет24 и неизменные speed/dist/priority/memory guards. Не увеличивать каждый житель×все машины до полного перебора каждый frame.

Проверка: одинаковая опасная машина в начале/конце CARS одинаково замечается; parked/wrecked/towed не пугают; дальняя не вытесняет ближнюю; high-priority bullet panic не отменяется машиной; бюджет остаётся ограничен. Живой проход через насыщенную улицу нужен отдельно.

### 3. Ввести адаптер одного runtime, а не новую логику NPC для /walk

Это интеграционный пробел: текущий самостоятельный walk_preview не запускает world NPC AI/server runtime. Реальное улучшение — новый renderer в основной странице, использующий готовый Mafiozi3DBridge и все перечисленные состояния, вместо ручного набора процедурных прохожих.

Конкретная ловушка флага: `JAIL_ISLAND_3D_ENABLED` world.html:5901 проверяет **render==='3d'**, bank checks тоже используют эту строку. В three_preview.js:88 почти любой render кроме canvas включает старый renderer. Поэтому просто `render=walk` может одновременно включить старый WebGL renderer и выключить игровые 3D collision flags.

Рекомендуемый контракт: оставить gameplay `render=3d`, добавить отдельный renderer selector (например renderer=walk) и гарантировать взаимоисключающее включение старого/new renderer. Либо согласованно распознать walk во всех shared gameplay gates; первый вариант меньше затрагивает механику. Сама основная страница остаётся единственным владельцем player/ws/update/timers. Старый `frame`66444 уже умеет при stage.three-mode выполнять `_timedWorldUpdate(dt)` на30Гц без второго Canvas draw; использовать это вместо запуска нового AI clock.

Новый renderer: читает getPlayerState/getDynamicEntities/getInteriorState, возвращает input через существующие bridge handlers; удаление модели из GPU-пула не удаляет source NPC. Подключать новые улицы/здания через отдельный scene-content host, а не импортировать самозапускающийся walk_preview вместе с его клавиатурой/движением/камерами. Нельзя создавать скрытый второй world iframe со вторым WebSocket или копировать world update в /walk.

Отдельно точные кровь/раны требуют confirmed contact point+normal: старые сводные hitAt/hp не несут этого. Квитанцы добавлять на source-side точки подтверждения события, сохранять entityId/shotId, не придумывать попадание для новой анимации. Падение/смерть/knockout выводить из существующего state, не локальных100HP.

## Выполненная проверка

- `python -B test_npc_life_system.py` → NPC_LIFE_SYSTEM_CONTRACT_OK. Статические контракты + ограниченная reference state model, не live AI.
- `python -B test_npc_social_pair_budget.py` → PASS spatial search contracts.
- `python -B test_police_foot_navigation.py` → POLICE_FOOT_NAV_OK: arrived12, deferred46, overlapFrames0, patrolResets0, plans20, stallsSecondHalf0. Детерминированный actual-function navigation harness.
- `python -B test_empire_boss_stall_recovery.py` → 12/12 deterministic gates PASS.
- `D:/codex_release/artist14_shot_effects_20260908/test_npc_behavior_findings.mjs` → actual danger-sensing index bias reproduced, gang hit condition1000/1000. JSON: NPC_BEHAVIOR_FINDINGS_QA.json в той же папке.

Попытка pytest не запустилась: текущий Python не содержит pytest. Вместо установки зависимостей выполнены предусмотренные standalone entrypoints четырёх suites выше. Server database не открывалась, gameplay mutation не выполнялась, live browser не использовался.

После адресных правок все четыре suite повторно PASS. Новый `node test_npc_incoming_threat_and_traffic.js D:/codex_release/artist14_shot_effects_20260908/NPC_BEHAVIOR_OLD_FUNCTIONS.json` исполняет фактические старые и новые функции: машина29 ранее не замечалась, теперь замечается; 18 жителей используют одно построение индекса; parked/wrecked/towed/slow/far/recent-memory/active-panic исключения сохранены; координата0 источника не подменяется координатой жителя. Старый incoming shot посылает gang_dmg, новый — ни одного запроса, а четыре визуальных эффекта побайтно эквивалентны после JSON-нормализации. Без аргумента тест проверяет только текущие функции и не зависит от личной D-папки. Live-проверка владельцем обязательна перед заявлением игровой приёмки.
