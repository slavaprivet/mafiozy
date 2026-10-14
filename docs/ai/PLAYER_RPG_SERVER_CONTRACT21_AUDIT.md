# Player RPG: server route authority audit

21 сентября 2026. Production backend/world не изменялись этим автором.

## Решение для текущего Walk bridge

Нельзя отправлять `_sendWorldWeaponFire('rpg_world', shotId, firedWeapon)` на
старте native ракеты, а затем `_sendRemoteWeaponHit` с тем же ID на попадании.
Первый пакет закрепляет durable receipt за `(weapon, generation, world,
rpg_world)`. Remote packet требует другой route/target и получает
`shot_conflict`. Замена ID тратит второй патрон и также неверна.

До отдельного серверного launch/impact протокола сохранить один существующий
claim на impact: remote target ИЛИ world fallback. Native flight хранит исходный
ID/weapon локально, передаёт его ровно один раз в source resolver. Это сохраняет
старую authority, но не делает launch серверно подтверждённым. Текущий сервер
проверяет ammo/cadence/ownership в момент обработки impact claim.

`_sendWorldWeaponFire` также очищает `_authoritativeShotId`, если ID совпадает
с global. `_sendRemoteWeaponHit` резервирует единственную target claim на ID
на 15 секунд; его true означает отправку, а не подтверждение попадания.

## Проверено actual кодом

Новый `test_player_rpg_route_contract21.py`: 5/5 PASS. Исполняются извлечённые
без изменений actual WS branch bodies, реальные WorldSim methods, durable
ammo/receipt helpers и изолированная временная SQLite БД. WS только записывает
пакеты, LOS открыт fixture, critical отключён. Сервер не запускается.

- `weapon_fire` RPG launch списывает один патрон и сохраняет world/rpg_world.
  Последующие cop/event/mg/aggro/player packets с тем же ID: shot_conflict,
  никакого target damage и повторного расхода.
- Exact world replay возвращает saved receipt; в БД одна запись/один расход.
- Только impact `cop_shoot` без launch claim наносит 160 HP одному cop.
  Соседний cop в 0.1 source tile не повреждён. Повтор не наносит новый урон;
  другой cop либо world fallback с тем же ID отвергаются.
- Произвольные r/c/damage в weapon_fire игнорируются, nearby server NPC/PvP
  не получают damage.
- Нет ownership → weapon_denied без расхода; нет ammo → no_round.

Anchors: `claim_authoritative_weapon_fire` и
`WorldSim._claim_player_weapon_fire_once` сравнивают полный binding;
WS weapon_fire только делает claim. Remote handlers после failed/replayed claim
выходят. `apply_cop_shoot` выполняет direct damage одной цели. PvP
`_apply_player_shoot_once` также отвергает prior receipt другого binding.

## Чего нет

Player RPG launch/impact AoE endpoint отсутствует. Существующий
`_apply_server_npc_rpg_arrival` принимает лишь серверно созданный bot shot и
перебирает players, не server NPC. Это не пригодный endpoint для клиентского
player impact. `test_world_explosion_damage.py` покрывает именно bot RPG и C4,
а не player RPG. Старые server targets нельзя повреждать локальным HP overlay.

## Ограниченный следующий серверный пакет — предложение, не реализация

1. Отдельный launch endpoint с authenticated shooter, immutable shot ID,
   weapon generation, server profile, source space/epoch/map revision,
   origin/direction и deadline. Ammo claim и projectile row должны создаваться
   одной транзакцией; один nonce не может менять binding или расходовать ammo
   заново. Bounded active count и TTL, без refund от произвольного client cancel.
2. Impact ссылается только на свой pending projectile. Не вызывает fire claim
   второй раз. Проверяет finite coordinates, допустимый flight time/range,
   origin/space, первый collision и expiry. Existing backend LOS двумерный:
   проверки native этажей/mesh отсутствуют. Одних client r/c/y недостаточно;
   нужна согласованная серверная geometry либо явно ограниченный поддерживаемый
   режим. Нельзя объявлять native wall/floor proof уже существующим.
3. Server перечисляет живые authority-owned цели у подтверждённого impact,
   проверяет LOS от impact и высоту, прежние PvP/FF/interior/защиты отдельно для
   каждого типа. Сохраняет authored player radius2.7 и falloff, без заимствования
   иной bot damage формулы. Клиент не передаёт damage или authoritative victims.
4. Durable projectile result и target-qualified damage receipts обеспечивают
   duplicate/reconnect/restart replay. Для in-memory server NPC нужен отдельный
   lifecycle generation и согласованное сохранение damage/rewards; существующий
   weapon receipt сам по себе не делает multi-target изменения атомарными.
5. Проверки: пустой/чужой/expired ID, invalid geometry, 2–3 near targets и outside,
   blast LOS, защищённые цели, повтор/конкурентный replay, смена оружия/жизни/space,
   rollback ammo+launch и crash между victims. Затем одна согласованная LIVE сессия.

Производительность общей сцены и actual authenticated network RPG не проверены.

## Побочный эффект первого запуска и восстановление

Первый запуск audit импортировал backend, чей существующий module-level код
копирует env BOT_TOKEN в `.bot-token`. Файл был ненамеренно перезаписан fixture
токеном. Координатор уведомлён сразу после обнаружения. Root восстановил файл из
настроенного Desktop/bot-token-backup.txt, предварительно сверив, что текущий
файл содержит именно fixture. Секреты не выводились; актуальность backup против
live сервера не проверялась. Самостоятельного дальнейшего изменения токена нет.

После этого import guard запрещает записи builtins/io/os.open, DB connections
и network connections при импорте; fixture env ограничен mock.patch.dict и не
использует исходный пользовательский BOT_TOKEN. Static audit module-level
вызовов backend и восьми local imports нашёл token write, настройку logging и
построение статических данных; DB/server start находятся в функциях/main guard.
Последнее расширение import guard проверено только статически по просьбе root:
backend повторно не импортировался. 5/5 относится к уже выполненной версии
с теми же actual tests; отдельно нужен разрешённый безопасный rerun harness.
