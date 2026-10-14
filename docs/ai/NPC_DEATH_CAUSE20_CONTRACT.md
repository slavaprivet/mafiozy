# Причина смерти NPC: контракт и аудит 20

20 сентября 2026. Владелец: субагент `npc_death_cause_contract20`, Координатор20.
Первый этап был read-only world / actor / surface / pose. После отдельного
разрешения NPClead19 добавлен узкий source producer, описанный ниже. Lifecycle,
actor, surface и pose этот субагент не менял. Нормализатор пока не подключён:
cause в source snapshot готов, вариативные анимации ещё не интегрированы.

## READY: окончательная локальная смерть жителя

Добавлены `npc_death_record20_source.js` и `test_npc_death_record20_source.mjs`.
В `world.html` только три собственных изменения:

- Подключение classic helper рядом с `npc_incident_reactions_source.js`.
- В `hitNpc`, после окончательных dead/deadAt и очистки medicalDowned, перед
  `_registerMurderIncident`/`_respawnResidentImmediately` присваивается `_deathRecord20`.
- Street view: `deathRecord: projectNpcFatalRecord20(x,id,death)` с безопасным
  отсутствием helper. Никаких новых dead/HP/capture/authority решений.

`createNpcFatalRecord20` получает **текущий параметр принятого weapon**, не поля
последнего попадания. Известные projectile weapons→bullet, fists→melee,
rpg/grenade/c4/явные explosive labels→blast, fire labels→fire, vehicle→vehicle.
Остальные unknown. Дополнительные super/kick/dropkick разрешены только при
совпадающем ref/bridge id, local melee, confirmed context, age в действующем
окне `window[1]+250`. Ничего не удерживает context и не расширяет окно.
Все точные point/векторы копируются; нулевое направление остаётся null.

Отдельного счётчика событий НЕТ: `eventId = local-death:<bridgeId>:<deadAt>`;
deathKey — строка точного source deadAt, того же epoch, который уже использует
lifecycle. Один record неизменен, повторная projection возвращает ту же ссылку
без аллокации. Повторный вызов creator на тот же target/epoch возвращает его.
Это identity локального окончательного death event, не серверный shot receipt.

В действующем `_respawnResidentImmediately` труп не пересоздаётся и не очищается:
он остаётся в NPCS. `_scheduleResidentRespawn` вызывает spawnNpc для **нового**
гражданина и копирует только archetype/appearance generation; deathRecord новому
объекту не достаётся. Actual tests исполняют обе функции и это проверяют. При
legacy оживлении прежнего объекта projection живой строки возвращает null;
новая definitive смерть перезаписывает запись новым epoch. Same-ID corpse view
copy сохраняет record; clone с другим bridge ID его не экспортирует.

Этот slice НЕ добавляет severity/скорость отлёта частей, normal не выдаёт за
travel, не меняет серверные ACK, empire/police/interior death producers.

Новый source+profile набор: **11/11 PASS**. `test_world_walk_shots.mjs`: PASS.
Старый `test_world_walk_melee.mjs` FAIL на строке15: ожидает expiry через500мс,
но параллельный contact-owner уже добавил +250мс delivery grace. Мои изменения
не затрагивают эту функцию/тест; Координатор20 передал проблему владельцу.
Все inline classic scripts и source helper проходят syntax.

CPU микрозамер, 15×20 000 вызовов после20 000 warmup, мкс/вызов p50/p95:
прямое чтение record 0.0093/0.0166; guarded projection 0.3381/0.5112;
создание нового frozen record 1.4167/1.4446. Creation только на смерти,
projection без сканирования actor lists. Это VM/CPU замер, **производительность
общей сцены не проверена**, LIVE/GPU не запускались.

SHA256 на передаче (world shared может дальше изменяться другими авторами):

- `world.html`: `008170a6c63079a72d74d6806c8a6de1a7ae53ca3c81a0475bdbb4b010370d5b`
- `npc_death_record20_source.js`: `a48ecad1eb598bc1ffac0436c31360728c69223b1ec15de6ef12277ea3dfc38a`
- `test_npc_death_record20_source.mjs`: `75932e6e23949afc5e52f2ef4d0455a9d50b69307cef99c1831eba930c9c4d68`
- HEAD на момент проверки: `ce5272b8bbbe85513b4174f53991978355b40fc4`.

Production freeze20 соблюдён после READY; дальнейшие изменения только docs.
Ниже сохранён начальный аудит проблем остальных каналов и downstream план.

## Подтверждённые разрывы цепочки

| Канал | Фактический текущий путь | Где теряется достоверность |
|---|---|---|
| Пуля в жителя | `world.html: hitNpc → _walkConfirmDamage → medicalDowned либо dead` | Receipt отправляется до окончательного решения: при HP=0 он ещё `fatal:false`; затем 72% первичных падений могут стать HP=1/downed. `_threeHitWeapon/Angle/Power` — последний удар, не причина смерти. |
| Удар кулаком / super / kick / dropkick | `punch.applyImpact → hitNpc(...,'fists')`; `_walkMeleeDamageContext` содержит animation.type/heavy/airborne | Все варианты в `_threeHitWeapon` становятся `fists`. Receipt сохраняет attackType/super, но не связывает их с окончательной смертью. Нельзя восстанавливать super по величине урона. |
| Серверный melee / bullet | `_walkConfirmServerHit → _walkConfirmDamage(..., killed || alive===false)` | Проверяется actor/target/attack ACK, поэтому fatal достовернее; всё ещё нет связи с death epoch. `attackType` приходит из клиентской animation, даже если serverHeavy/serverStunned false: клиентский dropkick не даёт права объявить серверную причину dropkick. |
| Семьи, охрана, боссы | `_hitEmpireCombatant → _walkConfirmDamage → _downEmpireCombatant` | Receipt снова раньше финальной смерти; `_downEmpireCombatant` не получает damage event. В async `_queueNpcEmpireBossHit` поля последнего удара меняются ещё до ACK, а confirm идёт до применения boss_hp/proof_ready. |
| Банк / интерьер / полиция | `_hitBankGuard`, `_hitInteriorNpc`, `hitCityCop` | HP и accepted hit приходят раньше dead/alive transition. City cop использует alive=false; source classifier создаёт стабильное время при отсутствии deadAt. |
| RPG | `_spawnRpgExplosion → _localBallisticTargets.hit` | Радиальное направление имеется в source, но нет отдельного per-target fatal record; общего shotId недостаточно для нескольких жертв. |
| Граната / АЗС | `_explodeThrowable → hitNpc(...,0,0,q.kind)`; `_explodeGasStation → hitNpc(...,'rpg')` | У гранаты направление сейчас нулевое; у АЗС weapon маскируется как rpg. Причину blast и вектор от центра надо сохранить в момент повреждения, не угадывать по weapon. |

`_threeNpcDeathState` возвращает только dead/deadAt/deathConfirmed. Общая street
snapshot добавляет hitAt/hitWeapon/hitAngle/hitPower, интерьер не имеет того же
набора. `hitAt` общей snapshot идёт через `_threeTrackCombatBleed`, то есть может
отражать наблюдение изменения HP. Сходство hitAt и deadAt не связывает события.

`normalizeNpcLifecycle` оставляет dead/key/age/side. `npc_actor.syncSourceLifecycle`
создаёт `world-death:<id>:<key>` только с dead/side. Прямой confirmed-hit получает
surface через `walk_preview` → combat/melee host → population.receive → actor.receive.
`hero_artist14_surface.receive` схлопывает fatal/dead в reaction.kind='dead';
`hero_artist14_pose.reaction` использует один задний наклон и небольшую сторону.
Cause, направление и контекст исходной позы в reaction/save/restore отсутствуют.

## Готовый независимый контракт

В source-owned snapshot хранится `deathRecord`:

```js
{
  version: 1,
  confirmed: true,
  fatal: true,
  targetId: 'npc_existing_7', // стабильный bridge ID конкретного NPC
  eventId: 'accepted-damage-event-7',
  deathKey: '5000',          // ТОЧНО тот epoch, который lifecycle.key отдаёт сейчас
  cause: 'bullet',           // melee, super, kick, dropkick, blast, fire, vehicle, bleedout
  travelWorld: {x: 1, y: 0, z: 0}, // необязательный вектор распространения удара
  pointWorldMeters: {x: 41, y: 1.2, z: 82} // только если настоящий контакт известен
}
```

`normalizeNpcDeathProfile({targetId,lifecycle,record,yaw})` проверяет точное
совпадение NPC и epoch, confirmed/fatal/version/eventId. Generic key `dead`
непригоден. При отсутствии или несовместимости записи получается
`{known:false,cause:'unknown',reason}`: действующая общая поза сохраняется.
HP, weapon, ближайший взрыв, timestamp proximity, random не используются.

Векторы нормализуются и копируются; весь результат неизменяем. World +X — колонка,
+Z — строка, +Y — вверх. Контакт уже в метрах Walk (масштаб source 4.1 применяется
при создании записи один раз). travelWorld — направление движения пули / удара /
от центра взрыва, НЕ normal поверхности. Направление dimensionless. При известном
actor yaw возвращается inverse-Y rotated directionLocal; local +Z — вперёд.
Без достоверного направления возвращается null, не случайная сторона.
Без измеренной силы blast не выдумывается скорость частей из hitPower.

Это проверка согласованности presentation payload, НЕ проверка подлинности сети.
Untrusted renderer не вправе прислать себе confirmed:true и создать gameplay death.

## Точный следующий интеграционный срез для владельцев

1. Source world owner добавляет запись **в окончательную ветку death**, после
   medical/downed/survival и после подходящего ACK. Локальные `hitNpc` и
   `_hitEmpireCombatant/_downEmpireCombatant` получают immutable context принятого
   damage event; eventId создаётся один раз, сохраняется на трупе и при повторном
   snapshot не меняется. Clear при настоящем respawn. Для старых трупов без context
   запись отсутствует. Подготовка server proof или snapshot hp=0 не создаёт cause.
2. Локальный melee context передаёт source attackType: punch→melee, heavy→super,
   kick→kick, dropkick→dropkick. Серверный super только по accepted heavy ACK;
   dropkick только после поддержки сервером такого attack type. Пока подтверждено
   лишь melee без типа — cause=melee. Обычные NPC-кулаки без подробностей = melee.
3. Blast source передаёт собственный blast event + target binding и radial travel
   от источника. RPG shotId можно сохранить как parent, но per-target record/epoch
   обязателен. Для центра радиуса направление неизвестно, не atan2(0,0)=восток.
   Grenade/АЗС/vehicle/server explosions внедряются отдельно; визуальный explosion
   FX сам по себе не является принятой причиной урона.
4. `_threeNpcDeathState`/обе projection ветки (street и interior) сохраняют record
   с текущим key. Нельзя заменить targetId ближайшим отображаемым NPC или создавать
   отдельную запись каждый frame. Сборка stable ID должна совпадать с action refs.
5. `normalizeNpcSnapshot` один раз нормализует запись рядом с lifecycle, передаёт
   `lifecycle.profile`. В actor death receipt переносится профиль; surface reaction
   и save/restore поддерживают profile. Receipt и snapshot одного event не
   перезапускают смерть. На смене epoch старый профиль сбрасывается вместе с surface.
6. Pose owner выбирает причину/направление только из validated profile; `unknown`
   сохраняет старую позу. Начальная фаза должна брать текущий presentation наклон
   при повторном stun/смерти во время recovery, не сбрасывать upright. Подробное
   доказательство 86° discontinuity: `NPC_RECOVERY20_AUDIT.md`. Нельзя менять
   source deadAt или source root, чтобы скрыть этот скачок.
7. При сохранении уже лежащего/старого corpse и возвращении после cull вариация
   и epoch сохраняются, история удара/частицы не переигрываются. Нормализатор не
   решает возраст смерти: существующий lifecycle.age остаётся источником времени.

## Проверки и пределы

`node --test assets/maps/city_rebuild_v1/test_npc_death_profile20.mjs`: 5/5 PASS.
Тесты исполняют настоящие `_threeNpcDeathState` и `_walkConfirmDamage`, а не их
копии: показаны промежуточный HP=0/fatal:false, все пять melee/firearm типов,
legacy snapshot без причины и необходимость epoch даже для fatal ACK. Отдельные
contract cases: wrong actor, stale lifetime, unknown/invalid record, точный yaw,
метры контакта, immutable copy, отсутствие изменений входных данных.

Графические позы/GLB не менялись; actual GLB continuity — отдельный владелец.
Нормализатор не подключён; добавленный позже source producer описан выше.
Производительность общей сцены и LIVE не проверены; CPU PASS не является приёмкой анимаций или
серверной persistence. Новые GPU вкладки не открывались.
