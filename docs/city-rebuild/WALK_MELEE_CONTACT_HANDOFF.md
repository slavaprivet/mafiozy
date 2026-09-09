# World walk: рукопашный контакт

2026-09-09. Изменён существующий `punch()` и добавлены методы `Mafiozi3DBridge`; standalone pose/input модули не менялись.

`setWalkMeleeCharge(active)` и `setWalkMeleeBlock(active)` используют существующие source функции и WS-сообщения. Заряд измеряется source `performance.now()`; renderer не передаёт длительность. После одного heavy заряд сбрасывается. Host обязан отпускать charge при pointerup/cancel/потере захвата.

`beginWalkMelee({angle,heavy,airborne})` возвращает `{accepted,seq,type,side,startAt,duration,contactWindow}`. Угол source atan2(deltaR,deltaC), startAt и contactWindow в миллисекундах, duration в секундах. Обычный тип source выбирает один раз: 20% kick, иначе punch; heavy представляет бэкфист, airborne даёт dropkick без заряда. Действуют исходные cooldown, PvE, оружие, блок, stance/transport/arrest и menu/chat locks. Встроенный renderer должен использовать принятый тип, не свой повторный roll.

`resolveWalkMelee({seq,contact})`: contact содержит `{npcId,point:{x,y,z},normal:{x,y,z},zone}` в абсолютных world метрах. Вызывать при фактическом контакте активной конечности. При окончательном промахе contact=null. Раннее обращение не расходует seq; после начала окна решение одноразовое, включая miss/invalid. Контакт проверяется на source ID, finite геометрию, дистанцию, время, актуальный lock и существующую line-of-sight. Нет 2D fallback при пустом контакте.

В walk-вызове punch не ищет target и не запускает собственный dash/damage timer: сохраняет прежнюю damage closure до resolve. Обычный legacy punch сохраняет выбор цели, timer и heavy dash. Host отвечает за физическое продвижение dropkick.

Local damage проходит прежние hitNpc/hitCityCop/bank/decor/beach функции и их авторитетные hooks. Событие `artist14:confirmed-hit` получает `kind:'melee'`, `attackType`, `super`, `blocked`, `knockdown`, точку/нормаль и source damage. Dropkick в блок уменьшает damage и не нокаутирует. 2D кровь для walk подавлена, контактную кровь создаёт renderer по подтверждённому событию.

Ограничение: существующий server путь punch отправляет `melee_hit`, но его обработчик не найден ни в production, ни в preview сервере. Поэтому sourceworld cop/aggro/convoy и другие не покрытые local ветки возвращают `source-melee-handler-unavailable`, без фальшивого урона/крови. PvP `player_melee` существует отдельно, но этот NPC contact adapter не подменяет его. Новые серверные операции не добавлялись.

Snapshot теперь дополнительно передаёт реальные `_meleeStunnedAt/Until`, `_empireDownAt/Until`, `_policeCuffed`, `_arrestPhase`. HP не синтезируется.

Проверки: `test_world_walk_melee.mjs`, `test_world_walk_gateway.mjs`, 9 existing melee input/dash tests, 4 charge cancellation tests, 8 interior LOS tests — PASS. Live физический прогон делает основной host-владелец; CPU тест не заменяет живую приёмку.
