# World → walk: здоровье и реакция героя

Новый presentation-only модуль `world_walk_health.mjs`; scoped автор не менял
world/walk, artistSurface, artistPose или сервер. HP/урон/смерть/возрождение
остаются в существующем world, модуль только читает источник.

## Фактический bridge

В `world.html` getPlayerState отдаёт:

- `hp:myHp`, `dead`, `combat_state.body.current/max/dead`;
- версия реально `combat_state.combat_version`;
- удар реально `impact:{stamp,age,angle,power,kind,bodyPart}` — age в миллисекундах,
  stamp — performance clock. Alias `at` тоже поддержан;
- `meleeStunned` — объект `{remaining,duration,startedAt}` либо null;
- `dead:true` бывает при arrestPhase downed с положительным HP. Более того,
  `_beginMurderPoliceArrest` и `_queueAnyPoliceDeathPickup` используют HP0/myDeadtrue
  для живого раненого задержанного: все активные custody фазы также не смерть.

Рекомендуемые два новых поля source bridge, которые добавляет только root:
`healthDead:!!myDead`, `healthCustody:!!arrest`. Custody имеет приоритет над всеми
dead/HP0 признаками. Вне custody explicit healthDead (включая false) имеет
приоритет над stale combat.body.dead/current. Без новых полей fallback распознаёт
active arrestPhase до booking включительно; phase prisoner уже не custody.

Приоритет HP: конечное число source.hp, иначе body.current. Maximum берётся из
body.max и сохраняется при неполном временном snapshot. Отсутствующий maximum
возвращается null; module не выдумывает100 и не обрезает preview HP5000.
Локальное положительное myHp после emergency restore может быть новее
body.current0/deadtrue при той же combat_version — это поддерживается.
Combat versions ниже уже принятой игнорируются; одинаковая версия допускает
существующие local HP изменения. Custody/downed/stun блокируют ввод,
но custody даже приHP0 не создаёт fatal/death или последующий фальшивый respawn.

## Контракт подключения

```js
const health = createWorldWalkHealth({bridge:npcBridge});
const frame = health.update({actorKey:hero, time:performance.now()});
```

Можно передать `source` явно, если host уже прочёл getPlayerState в этом кадре.
Это избегает лишнего чтения animation telemetry. `actorKey` — identity текущего
hero/rig, не постоянное строковое имя игрока. Controller живёт весь lifecycle
одного world bridge; смена source/session создаёт новый controller.

Результат:

- `snapshot`: available, hp, max, dead, deathConfirmed, deathSource, custodyOwned,
  downed, stunned, inputsBlocked, combatVersion, sourceDead, stale.
- `events`: одноразовые edges `death`, `restore`, `impact`.
- `actorSync`: текущая смерть при первом подключении/смене rig, settled age>=1.
- `reaction`: `{kind:'hit'|'dead',age:seconds,side:1,zone:null}` либо null.
  Для hit это нейтральная безопасная реакция без выдуманной стороны ранения.
- `inputsBlocked`: смерть/downed/stun; пропавшее чтение не снимает блокировку.
- `sourceError`: текст ошибки bridge либо null, пригоден для диагностики.

Порядок host hooks:

1. До движения/ввода/стрельбы прочитать frame. При inputsBlocked очистить held
   controls и не начинать новые атаки/прыжки/входы в машину. Не изменять
   серверные HP/позицию/арест; транспорт/custody продолжают собственный lifecycle.
2. `death` edge → `artistSurface.receive(worldWalkHealthSurfaceReceipt(event))`.
   Receipt confirmed fatal/dead и **не содержит point**, ран/крови не создаёт.
3. `restore` edge → reset artistSurface, безопасно сбросить старую реакцию/
   transient input. World сам определяет восстановленное HP и место respawn.
   `reason:'custody-takeover'` означает передачу позы живого раненого полицейскому
   конвою, а не исцеление/respawn. Не телепортировать/разблокировать ввод по edge.
4. Если frame.actorSync — `synchronizeWorldWalkHealthSurface(artistSurface,
   frame.actorSync,{time:performance.now()/1000})`. Helper использует валидный
   snapshot **нового rig** и заменяет только reaction на settleddead. Не копирует
   раны другого тела, не проигрывает падение и не придумывает контакт.
5. Nonfatal `frame.reaction.kind==='hit'` можно передавать напрямую
   `artistPose.reaction(frame.reaction,hero.artistContext())` после базовой позы.
   Не применять поверх custody/vehicle/owned traversal/сильной artist реакции.
   При обычной death анимацией уже владеет artistSurface — не накладывать второй
   dead pose из frame поверх его реакции.

Impact stamp дедуплицируется независимо от version/rig. Первый snapshot только
запоминает имеющийся stamp, не воспроизводит историческое попадание. Возраст>=480мс
не создаёт hit-pose. Понижение HP без точного impact stamp не выдумывает удар.
`worldWalkHealthSurfaceReceipt(impactEvent,contact)` вернёт nonfatal receipt только
при `contact.confirmed===true` и finite point. Normal/zone/side берёт исключительно
из contact, не из angle/bodyPart telemetry. Host должен независимо подтвердить
геометрический контакт; по этим текущим bridge данным его нет.

## Проверки и пределы

`node assets/maps/city_rebuild_v1/test_world_walk_health.mjs`: 11 PASS.
Проверены неизменность source, custody/stun, genuine HP0 смерть, edge dedupe,
guard при null/throw, stale version, local restore на той же версии, initialdead,
rig replacement без падения, весьHP0 custody lifecycle, explicithealthDead,
at/stamp дедупликация, отсутствие выдуманных точек,
истёкшие удары, settled surface sync из собственного snapshot, отмена после
dispose. Браузер/живой host в этом scope не проверялись: подключает Координатор15.

## Интеграция координатора15 — 10 сентября 2026

Пользователь: подключить HP и урон пуль/взрывов из world; затем применить готовую анимацию смерти художника ко всем NPC.

`walk_preview.mjs` читает health-модуль до обработки движения/оружия. Подтверждённая смерть передаётся в существующий artistSurface без выдуманной точки ранения; поза prone сбрасывается, остаточная swim-поза не вращает смерть второй раз. Ввод, стрельба и смена стойки блокируются при смерти/custody. При настоящем restore сбрасываются reaction и переходы, принимается source-позиция; custody-takeover сбрасывает лишь смертельную реакцию, не имитирует respawn. На замене rig используется его собственный snapshot. `world.html.getPlayerState` теперь явно передаёт healthDead/myDead и healthCustody/arrest. HUD продолжает читать канонический myHp, второго счётчика HP нет.

Новый `blast_response.onHeroExposure` сообщает один физический контакт взрыва (дистанция/преграда). Только отдельный walk fleet вызывает bridge.applyWalkVehicleBlast. В source `_applyWalkVehicleBlast` проверяет local-world authority, ID и физическую экспозицию; радиус10м, до70урона, bounded dedupe512, затем существующий _hurtLocal. Визуальный RPG без source-машины не начисляет второй урон поверх исходного RPG world. В authenticated mode этот localfleet путь ОТКАЗЫВАЕТ сserver-owned: renderer не получает полномочий менять серверное HP.

Серверный NPC RPG в mafiozi_bot.py теперь разрешается как взрыв при серверном arrival (радиус2.7sourceтайла, falloff/LOS, durable event/victim receipts, броня/смерть, PvE/interior/custody guards). C4 server damage сохраняется. Пули используют существующий combat_state.v1, никаких новых clientdamage endpoints.

Честный предел: исходный player weapon_fire отправляет только shot_id/weapon/route, без валидированного сервером запуска/impact; player RPG/selfgrenade/gas auth-урон через _hurtLocal не существовал и не становится серверно готовым от rendererhook. Для этих источников нужен отдельный серверно проверяемый launch/impact контракт. Не использовать gang_throwable danger endpoint для списания HP без расходования предмета/receipt. Это не завершённая миграция всех типов взрывов.

Проверки координатора: health11 PASS, actualsource+Threeblast integration PASS (35HP на5м, cover/range, repeatID, authenticated отказ, отсутствие двойногоRPG); cover bridge PASS; gateway PASS. Python test_world_explosion_damage + test_npc_player_damage_authority:14/14 PASS, включаяC4регрессию. Синтаксис worldclassic/walk PASS. Все тесты DB используют временную базу.

NPC отдельная передача: NPC_ARTIST14_DEATH_HANDOFF.md, actualsource24families/71catalogue/26actualGLBroles PASS. Это существующаяанимация, не новыйарт.

Живой прогон: в текущем CUA контексте старойtab1 уже не было (inventory[]); создана browser1/tab2 с /world.html?direct=1&previewcity=1&combatdemo=1&demoqa=1&render=3d&renderer=walk&carqa=1. World/HUD100/100/NPC и carQA загрузились, ошибокconsole[]; затем команды Runtime.evaluate/Emulation.setFocusEmulationEnabled стабильноtimeout на модальном выбореPvP/PvE. Реальные кликиурона/взрыва/смерти НЕ подтверждены. Вкладка markDeliverable, не закрыта. Не выдавать VM/GLB за LIVE.
Проверка процессов: только python city_rebuild_monitor PID47344, mafiozi_bot не запущен. Серверныйпатч требует запуска/проверки владельцем реальногосервера; монитор18538 его не исполняет.
