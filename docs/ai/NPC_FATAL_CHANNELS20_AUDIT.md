# Все NPC: аудит окончательных смертей и следующего blast-контракта

Поздний статус: пакет bank/beach/local-interior source metadata уже реализован
отдельным разрешённым срезом; см. `NPC_LOCAL_DEATH_EXTENSION20_HANDOFF.md`.
Ниже сохранён исходный аудит, не текущий статус этого пакета. Его executable
audit tests обновлены под добавленные producers.

20 сентября 2026, `npc_death_cause_contract20` для Координатора20. Только аудит,
новый тест и этот документ. Runtime freeze19 соблюдён; world, helper, lifecycle,
actor и surface в этом этапе НЕ менялись. Номера строк относятся к shared на
момент чтения; точные имена функций являются устойчивыми anchors.

## Основной вывод

Одного общего вызова `createNpcFatalRecord20(raw, _threeNpcEntityId(raw))`
недостаточно. Для police/beach/crew/server entities renderer использует wrapper
ID; city cop/decor/aggro при смерти создают другой corpse object. Также
`alive=false` используется при штатном уходе службы. Только конкретная финальная
ветка принятого damage event может подтвердить причину; обход всех HP0/alive=false
объектов недопустим. Никаких выводов по severMask, крови, последнему hit или
ближайшему explosion FX.

## Таблица source producer → renderer

| Класс | Окончательная ветка / clock | Фактический ID и projection | Следующее минимальное изменение |
|---|---|---|---|
| Жители, медики, NPCS workers | `hitNpc:8947`, dead/deadAt=performance.now; после medical decision | `_threeNpcEntityId(n)`: `npc_<explicit>` или WeakMap `local_npc_N`; street view:709xx | Уже подключён первый producer. У медиков нет отдельного synthetic HP100 actor: они физические NPCS. |
| Тяжело раненный житель | update NPC medical bleedout:18471, отдельный окончательный deadAt | Тот же NPCS ID | Создать явную cause=bleedout в этой ветке, не bullet/blast от старого ранения. Сейчас helper этот producer не покрывает. |
| Empire street boss / crew / holding guard | `_hitEmpireCombatant:11823` → `_downEmpireCombatant:11837`, dead=true/deadAt=now, hospital later | Это реальные NPCS с существующим ID; `_deathR/C` фиксируют тело; street view | Передать immutable accepted event из hit в down. Сам down вызывается также при server proof/hydration, поэтому default unknown. Не объявлять каждый down blast. |
| Empire boss, server field | `_queueNpcEmpireBossHit:20986`, successful matching hit result, затем proof_ready + final HP → down | Тот же street NPCS ID; серверный encounter и shot_seq отдельно | Freeze context конкретного request, привязать к final ACK/death epoch. `prepare.proof_ready` означает уже бывшую смерть и не доказывает причину нового request. `_threeHit*` пишутся до ACK и непригодны. |
| City police / prison staff | `hitCityCop:9035` alive=false; `:9060` создаётся отдельный corpse с новым deadAt | До смерти `npc_city_cop_<cop.id>`; corpse `npc_<cop.id>_corpse` в NPCS | Bind запись к **новому corpse ID**, а не автоматически переносить targetId живого cop. Для blast передать accepted weapon/event дополнительно к нынешним dirR/C/damage. Не читать currentWeapon. |
| World police / Michael guard / convoy boss и guards | server handlers `cop_hit`, `mg_hit`, `player_shot`, `_applyGangShotCopArrival:7546` и snapshots | `npc_world_cop_<id>`, `npc_michael_guard_<id>`, `npc_world_event_<eventId>_<id>` | Только matched accepted ACK + stable epoch. Wrapper `dead:alive===false` не даёт причины. Если clock впервые создаётся projection map, producer должен заранее закрепить единый clock, не брать новый now каждый snapshot. |
| Police service уход | `:12760`, `:14934`, `:16113` alive=false при возвращении/отсутствии incident | Обычно тот же city wrapper | Не fatal! Не расширять helper до любого alive=false. Не создавать части тела при despawn. |
| Player crew / наёмники | `_myGang` HP0; `mercenary_world.getMember:155` явно dead:false/downed:hp<=0; core tick:156–164 → downed/hospital | `npc_crew_<id>`; `decorateEntities:513` может убрать hospital row и подавить fake death | Не превращать HP0 в fatal ради эффекта. Current mechanics лечат/возвращают бойца. Достоверная отдельная fatal authority потребует отдельного решения, иначе normal downed. |
| Bank guard | `_hitBankGuard:9247`, final dead/deadAt:9283; сохранение/restore:661xx | getDynamicEntities при inside: `npc_<id>` либо WeakMap. getInteriorState row.id — raw string/index, а death-cache key `interior:<biz/type>:<id>` | Добавить accepted event/weapon в hit signature и callers. Сам helper не знает пуля это или удар: сейчас читает currentWeapon лишь для крови. Source clone/save должен сохранять record+epoch или честно unknown при старом save. |
| Local business/other interior guard | `_hitInteriorNpc:62692`, локальная final branch:62837 | Те же два разных surfaces ID; generic NPC actor получает `_threeNpcEntityId(n)` | Создать record только в локальной final branch с фактическим weapon и dirR/C. Добавить projection отдельно в getInteriorState, если этот канал потребителю нужен; не использовать cache key как targetId. |
| NPC HQ guards / HQ boss | `_hitNpcEmpireAssaultNpc:22709`; server result guard map→final dead:22729; victory boss→dead:22733 | Native n.id в interior, generic `npc_<id>` при getDynamicEntities | Response может показать смерть **нескольких** guards. Приписывать weapon текущего request всем нулевым guards запрещено; cause known лишь у совпавшего target accepted event. Остальные unknown. |
| Business raid attackers/defenders/guards | `_damageBusinessRaidNpc:65293`, final deadAt + конкретная roster row casualty | `npc_<n.id>` в generic bridge; отдельный interior raw row | Передать source event через source arg, сейчас строка `player`/combat не содержит cause/vector. Casualty restore не создаёт новый death effect. |
| Major guards / occupiers | `_hitInteriorNpc` рано возвращает через server contract; ACK branches:27660,28810 | Interior IDs и отдельные server IDs нельзя смешивать | Final matching killed/death update + accepted attack ID; не добавлять local fatal на отправке запроса. |
| Aggro gangs / nests | `_applyIntergangBallisticArrival:7533`, `aggro_hit:288xx`, `aggro_killed`; `spawnBotCorpse:26744` | Live `npc_aggro_<zone>_<bot>` / `npc_nest_<nest>_<id>`. Новый corpse без id→WeakMap `local_npc_N` | Новый target binding к corpse и accepted kill event. Сейчас `spawnBotCorpse` ставит `_evacuated:true`, а общая admission исключает evacuated: добавленный record сам по себе **не сделает corpse видимым**. Отдельно согласовать semantic distinction «без скорой» vs «скрыт». |
| Business fight remote corpse | accepted killed → `spawnTransientNpcCorpse:26829` | `npc_corpse_business_fight_<target>`; новый local deadAt | Функции нужно передать accepted event, она сейчас получает лишь id/position/look/angle/role/HPmax. Не угадывать cause по role. |
| Beach | `_hitBeachgoer:19337`, final deadAt:19344, anchored _deathR/C | `npc_beach_<raw.id>` — raw `_threeNpcEntityId(b)` даст неправильный ID | Передать фактический accepted weapon/event (signature сейчас их не имеет); bind к beach wrapper. |
| Bus passengers / waiters / parking | `_killDecorNpc:9178`, удаляет original из массива и создаёт NPCS corpse:9204 | До: bus WeakMap alias `npc_bus_waiter_N` / `npc_bus_rider_N`, parking alias; после: anonymous corpse `local_npc_N` | Причина сейчас вообще не передаётся: выстрел и melee вызывают одну kill-функцию. Нужен explicit event + новое corpse binding, normalise direction без source teleport. |
| Quest / immortal / pressure owner | hitNpc `_invulnerable` early return; interior key/mafia_hq/police_st reset alive; owner clamp≥1; major boss pressure | Rendered NPC может выглядеть ordinary, authority остаётся protected | Не снимать protections ради «всех NPC». Нет принятого fatal — нет dismemberment. |
| Synthesized lair/business guards/race decor | `getDynamicEntities` создаёт render rows, часть без persistent damage ref | `npc_lair_fallback_*`, `npc_biz_guard_*`, race_* | Не создавать gameplay death только для visual row. Сначала найти/добавить реальный source target отдельно; это вне текущего fatal metadata slice. |

Дополнительные реальные local final branches: случайная драка `:24247`, наезд
quest-car `:40227`, direct police shot target `:16107`. Они обходят hitNpc.
Их явные причины melee/vehicle/bullet можно привязать в собственных ветках после
согласования, но старые corpses без context остаются unknown.

## Blast coverage: что уже существует и чего нет

- `_spawnRpgExplosion:373xx` обходит `_localBallisticTargets:37063`. Там есть
  NPCS, beach, cityCops; внутри bank/interior возвращается отдельный список.
  **Нет** bus/parking, _myGang, server police/Michael/convoy в local list.
  Bank/beach/cityCop callbacks теряют firedWeapon: damage function принимает
  только число и направление. Не подставлять global currentWeapon — оружие
  могло уже смениться до arrival.
- `_explodeThrowable:56141` бьёт NPCS и building NPC с нулевым dirR/C, плюс
  отправляет server gang requests. Для radial direction брать target−blastCenter
  из **этого принятого события**, в центре оставить null. Анализ metadata не
  даёт права добавлять новые damage recipients или обходить server validation.
- `_explodeGasStation:6164` бьёт NPCS и city cops, _myGang получает HP delta.
  Последний случай остаётся mercenary downed, не автоматически fatal.
- `_applyWalkVehicleBlast:69356` — player health local adapter, не all-NPC
  damage endpoint. `spawnCarExplosion`/parts/кратер сами по себе не fatal proof.
- Authenticated RPG/throwables не имеют здесь универсального per-NPC accepted
  blast receipt. Для server classes сначала согласованный accepted event/target
  contract. Не трактовать generic killed ACK рядом с explosion как blast.

## Предлагаемые следующие точные пакеты (ещё не применены)

1. **Локальные NPC с постоянным объектом:** `_hitBankGuard`, `_hitBeachgoer`,
   local final `_hitInteriorNpc`; добавить опциональный accepted impact argument,
   передать firedWeapon/source context из `_localBallisticTargets` и явный fists
   context из punch, не использовать глобальное weapon. Сразу bindings bank и
   beach, dual projection test. Вне новых параметров damage/HP неизменны.
2. **City police corpse:** изменить только создание corpse на переменную,
   создать deathRecord с её destination ID/deadAt, push тот же corpse. Передать
   accepted context из police hit callers. Тест смерти через blast и отдельно
   despawn не создаёт record; не удвоить live-cop/corpse parts.
3. **Empire:** frozen optional accepted event в `_hitEmpireCombatant` → down.
   Отдельная explicit branch для server matching ACK. Prepare/hydration,
   восстановленная casualty и несопоставленные guard deaths — unknown.
4. **Decor/remote corpses:** отдельный corpse creation contract с destination ID
   и source-event link; затем решить existing hidden-aggro-corpse с NPClead19.
   Это не должно происходить как side effect metadata patch.
5. **Наёмники/immortal:** не менять текущую authority. Смерть/части допустимы
   только если отдельный authoritative gameplay contract действительно объявит
   fatal, иначе предусмотренный downed/recovery.

## Исполняемые доказательства

Новый `test_npc_fatal_channels20_audit.mjs`: **7/7 PASS**, около339мс CPU.
Исполняет реальные source функции hitCityCop, _killDecorNpc, _hitBankGuard,
_hitBeachgoer, _downEmpireCombatant, _hitInteriorNpc, _damageBusinessRaidNpc,
spawnBotCorpse, _threeNpcEntityId, _threeNpcDeathState и mercenary getMember.

Проверяет actual corpse identity replacement, protected NPC survives999 damage,
конкретную raid roster casualty, downed-vs-dead, stable anonymous IDs, aggro corpse
hidden flag, stale identity rejection. **Предлагаемое** создание blast record
вызвано только внутри теста с явно заданным fixture event после фактической
смерти; production coverage этими тестами не объявляется. Real server ACK
аутентификация, multi-target blast damage и GPU не воспроизводились.

Production изменений нет → новой runtime стоимости нет. Производительность
общей сцены и визуальное качество all-NPC смерти не проверены. Известный
11/11 source/profile PASS предыдущего этапа не означает coverage этих классов.
