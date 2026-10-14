# Первый native-site: конкретное подключение к source world

20 сентября 2026. Координатор20, независимый read-only аудит. План, не применённая
интеграция. Production/world/server/DB не изменялись; браузер/GPU не запускался.

## Один объект и реальная точка подключения

Цель: `native-site:REBUILD-VISUAL-old_town_narrow_townhouse_v1-001`.
Instance уже находится в `assets/maps/city_rebuild_v1/buildings_placement.v1.json:585`.
Никаких `apt_key`, округления до квартала или новых домов. Его actual GLB проверен:
полы world Y≈0.105/3.090/5.990 м, крыша Y≈8.575 м; каталог принимает этажи,
отвергает крышу/воздух/подпол. SHA placement и точный instanceId — версия геометрии.

`walk_preview.mjs:1367–1376` читает placement, собирает физические `buildingEntries`
через `createWindowedBuildingEntry`. Здесь построить каталог из этих же entries,
с explicit policy только для oldtown001; инвалидировать его при `clearContent`/
reload/pagehide. Сейчас import `native_site_control.mjs` в runtime отсутствует.
Шаблон подключения host уже есть: `walk_preview.mjs:512–514` регистрирует resident
access, `world.html:69908` принимает resolver. Лучше отдельный узкий site resolver
рядом, а не изменение semantics traffic/nav. Он отвечает только за loaded/revision,
approach и `catalog.contains(id,feetPoint)`; собственность там не хранится.

## Какие source-факты есть и чего не хватает

| Факт | Точная существующая точка | Ограничение/необходимое изменение |
|---|---|---|
| Стабильный NPC ID | `world.html:69153` `_threeNpcEntityId`; raw NPC `id` | Не использовать array index или имя; prefix presentation отдельно от raw ID |
| Семья NPC | `world.html:11604` `_empireLeaderIdOf`, `_empireLeaderId`/`_specialistId` | `_myGang` относится к игроку; client custom-gang name не identity |
| Здоровье/боеспособность | `world.html:11761` `_empireDisplayHealth`, raw `dead`, HP, `_empireDownUntil`, `_knockedUntil`, custody/medical/transport flags | `_empireCombatReady:11764` НЕ read-only: восстанавливает HP, завершает downed, произносит реплику; snapshot его не вызывает |
| Охрана владений | `world.html:11345` `_empireHoldingId/Kind/Key`, `EMPIRE_HOLDING_GUARDS` | `_syncEmpireHoldingGuards:11360` ограничивает distance<48, число sites и 1–3 guards, удаляет дальних. Это НЕ полный roster; исчезновение модели не смерть |
| Отношения | `world.html:11334` `_empireRelationIsHostile`, `_npcEmpireDiplomacy` | false означает также отсутствующее отношение. Нужен explicit host classification attacker/nonblocking/hostile, unknown отдельно |
| Позиция игрока | `walk_preview.mjs:545` hero.object.position; `world.html:69920` syncWalkPlayer | Source sync сохраняет r/c/ang, НЕ world Y. Передавать actual feet для local host; не вычислять Y=ground вместо настоящего положения |
| Позиция NPC | raw source r/c; `npc_population.mjs:27–29` presentation groundHeight+elevation | `world.html:70812` даёт elevation=0 вне casino. Native floor/feet actor proof ещё отсутствует; визуальная интерполяция не authoritative pose |
| Полный список | Raw source collections/назначения, не renderer | `getDynamicEntities:70580` spatial filter и `70765+` capped selection. getActors/getDynamicEntities не доказывают occupantsComplete/defendersComplete |

Нужен один source-owned registry назначения охраны oldtown001: explicit raw actor
IDs + состояние назначения/потерь. Использовать уже существующих NPC, без второго
набора охраны и без teleport. Если назначенный actor исчез/не hydrated — unknown,
а не defeated. Согласовать с19 добавление связи site→actor и чтение collection,
смерть/плен/медицинскую эвакуацию; не менять его spawn/sync/nav/agenda.
Для первого среза захватчик — игрок с actual feet; NPC захват требует отдельного
согласованного feet contract, а не подмены позиции groundHeight. Активный чужой
actor у здания с неизвестным этажом должен блокировать complete proof.

## Исполнимый первый runtime patch: локальный вертикальный срез

1. Добавить opt-in local preview gate для oldtown001; одного `_LOCAL_PREVIEW`
   недостаточно: localhost бывает клиентом настоящего сервера. Явно исключить
   authenticated authority. Пример разделения local/auth уже есть в
   `world.html:69762–69785` для оружия; не связывать новый gate с ammo-флагом.
2. В source world держать session site owner/revision, defenceRevision, HQ revision,
   assigned source actor IDs и receipts. Initial owner/guard assignment задаются
   явной preview fixture, не случайной ближайшей бандой. Это интегрированный
   preview; не выдавать его за постоянную серверную собственность.
3. Bridge action получает только site/action/operationId и expected versions.
   Source заново читает свою охрану/роли и geometry resolver, формирует полный
   claimant-relative snapshot, вызывает существующий planCapture/planHQ.
   Только одна source функция после повторной проверки меняет owner/HQ/revisions
   и запоминает receipt. Нет `await` между проверкой и local commit; replay того же
   operationId возвращает прежний receipt, другой payload с тем же ID — conflict.
   Урон остаётся в `world.html:8885` hitNpc/действующих empire hit hooks.
4. Preview session можно завершить при reload. Если нужен reload acceptance,
   сохранять один versioned sessionStorage envelope (owner/HQ/receipts/fixture
   assignments), scope по manifest+site+preview session. Не сохранять отдельно
   owner и receipt; не восстанавливать fabricated «все охранники мертвы» при новом
   source roster. Путь authenticated никогда не читает этот envelope.
5. В `walk_preview.mjs:993` nearestInteraction добавить контекст site только
   внутри `catalog.contains`, а не от фасада. Использовать существующие prompt/
   E-handler (`1035`, `1647–1660`), без нового global key listener. Первый E открывает
   карточку Capture/HQ, повтор клавиши не коммитит. `mercenary_walk.mjs:128–131`
   раньше перехватывает E для loot/разговора: сохранять этот приоритет, уважать
   defaultPrevented и не совмещать capture с открыванием двери/посадкой.

Первый patch реалистично доказывает: та же дверь/дом → реальная охрана из source →
смерть/нейтрализация → физический вход игрока → один local owner transition → HQ.
19 предоставляет actor assignment/движение и GPU окно; автоматический подход NPC
не реализовывать параллельно его навигации. Без доказанного полного roster состояние
остаётся unavailable — UI не должен показывать успешный захват.

## Authenticated commit: готовый транспорт, отсутствующая native authority

Клиентский запрос должен идти через `world.html:3272` `_apiRequest` (Telegram/
Steam headers, один 401 retry). На backend `mafiozi_bot.py:28063–28112`
`_requires_actor_binding`/middleware связывают UID с authenticated character.
Новый `/native-sites/{uid}/...` prefix обязательно включить явно; сейчас его нет.
Роль лидера брать из `custom_gang_members`/`custom_gangs`, как
`mafiozi_bot.py:15565`, а не из client request.factionId.

Новых site owner/HQ/receipt tables и native server presence сегодня нет.
`WorldSim.apply_input:18232`, interior branch `18369` понимают legacy business/major
интерьеры, не instanceId+world feet/этаж. Поэтому простой POST с inside=true или
полученным client intent НЕ авторизует online capture. Нужен серверный fixed-site
geometry/presence контракт и подтверждённый roster/бой, прежде чем включать кнопку.
Переиспользовать pattern транзакции/receipt из `npc_empire.py:5170–5205`:
BEGIN IMMEDIATE → replay/conflict → current owner/defence/HQ + проверенный actor
snapshot → условная смена версии → receipt в той же transaction. Сам endpoint
`/npc-empires/.../building/action` не подходит: только whitelist legacy holding и
purchase/sabotage. `custom_gangs.hq_apt_key` также не адаптер native identity.

При будущей online ошибке сети повторять тот же operationId, запрашивать receipt;
не давать local success fallback. До этого first patch ограничен явным preview.
Приёмка: alive/offscreen guard и unknown pose блокируют; roof/below блокируют;
двойной E/retry не дублируют owner/HQ; stale versions и другой actor отклоняются;
после capture геометрия/IDs сохранены. CPU и local preview не заменяют online/LIVE/FPS.
