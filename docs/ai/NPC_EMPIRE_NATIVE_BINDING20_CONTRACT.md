# Боссы: игровой ID → физический вход, Координатор20

> Последнее уточнение пользователя20: дальнейшее направление — захват
> существующих неподвижных зданий Walk по их instanceId. Штаб сначала
> захватывают как готовое здание, затем назначают штабом. Автоматический
> crosswalk старых владений и строительство новых HQ на пустырях сейчас
> не реализуем. План: `../game-design/NATIVE_SITE_CAPTURE_HQ_20260920.md`.

20 сентября 2026. Участок назначен Художником19 после checkpoint
`7370157da12af9944d01cff330d9ff3d1e96b640`. Пока аудит и контракт, не готовая
миграция и не LIVE-приёмка. Production-файлы этим документом не меняются.

## Подтверждённый разрыв

`world.html::_empireActivityTarget` использует `activity.target_r/target_c`
раньше `target_id`. `_npcEmpireHoldingPoint` берёт BUSINESS_POIS или
`_playerEmpireBuildingMeta`, построенный по старому кварталу. Серверная
`npc_empire.py::_hq_coords` — номинальный центр `br*10+6,bc*10+6`, не дверь.
Это не исправляется выбором ближайшей новой модели: такая подмена назначила
бы другому зданию существующий игровой ID.

В текущем `buildings_placement.v1.json` 75 экземпляров, только 3 с ненулевым
`gameplayId`: `bank:large`, `bank:medium`, `bank:small`. Явных business,
building и HQ bindings нет. Независимый аудит подтвердил тот же результат.
Архитектор-магазины подтвердил, что в его передаче утверждённого crosswalk
World business/HQ → REBUILD instance нет.

`REBUILD-VISUAL-nightclub-001` не является `business:club`: его gameplayId
равен null. Parcel, название GLB, тип комнаты и близость не доказывают связь.
Десять business IDs остаются unresolved в плане размещения.

Источники, которые не закрывают этот пробел:

- `docs/city-rebuild/rebuild-ledger.generated.json`: plannedRC — план, без
  связи с загруженным физическим экземпляром; coverage persistent instances
  неполная.
- `assets/buildings/city_v3/accepted_v1/main_native_bindings.v1.json`:
  старые визуальные замены legacy shell; gameplay targets прямо исключены.
- `gameplay_migration.mjs`: isolated-preview stage, readyForMain=false;
  нельзя считать его применённым серверным переносом.
- `docs/city-rebuild/BUSINESSES_BANKS_INVENTORY.md`: отличает fixed business,
  operation_type, visual IDs и ключи динамической собственности.

## Минимальный контракт

1. Вход resolver: явные `kind` и `id`, не пара координат. Namespace важен:
   `business:casino` и `major:casino` — разные объекты.
2. Источник физических входов — текущий `resident-access/list`: его r/c
   получены из реального `entry.approachPoint()` после transform / 4.1.
   `placement.entry.anchorRC` — порог, не обязательная безопасная точка подхода.
3. Совпадение только по объявленному gameplay alias/identity. Не использовать
   `_residentDoorBySource`: там смешаны legacy/native и duplicate last-wins.
4. Результат содержит status (`resolved`, `missing`, `ambiguous`, `not-ready`),
   исходный semantic key, instanceId, doorId и физическую точку. При нескольких
   разных instanceId один alias неоднозначен; нельзя брать первый/ближайший.
5. Для `resolved` цель движения native берётся раньше старых target_r/c.
   Владения, IDs, серверные записи, generation key, экономика и дипломатия
   не переписываются. Изменение destination само по себе не разрешает захват.
6. 2D сохраняет прежний путь. Неидентифицированные roam/recruit и серверные
   active field anchors не переносить через эту таблицу. Field encounter
   hydration/receipt остаются источником подтверждённой позиции.
7. `missing/ambiguous/not-ready` должны быть видимыми диагностическими
   результатами. До согласованной миграции сохраняется прежнее поведение;
   его нельзя объявлять корректной native-привязкой или новой интеграцией.
8. Кешировать только index опубликованной версии списка входов; не кешировать
   физическую доступность навсегда. Коллизии и выбор безопасного подхода
   остаются действующими проверками. Нет второго AI/update/render loop.

## Проверки перед включением

- Реальная геометрия существующего relocated банка: resolver выбирает
  actual approachPoint, координаты server state и placement не мутируются.
- Разные namespace с одинаковым short ID; duplicate alias разных зданий;
  unbound visual; unloaded/replaced registry; invalid coordinates.
- Business/HQ explicit fixture отдельно обозначен синтетическим: он проверяет
  контракт, но не доказывает, что таких bindings уже хватает в городе.
- 2D, roam/recruit, active field encounter и исходная ownership identity.
- После появления утверждённого crosswalk — настоящий business/HQ, физический
  маршрут/прибытие и LIVE с Художником19; до этого ни банк fixture, ни CPU PASS
  не являются исправлением жизни боссов.

## Следующий шаг и границы

Художнику19 переданы факты и контракт. Требуется адресная авторская таблица
business/building/HQ → loaded instance/door, либо отдельный независимый участок
устранения простоя. Pending-slice boss fix уже включён19, не дублируется.
Native coarse-BFS edge blocker пока только read-only по его поручению.
Навигация гражданских, agenda, транспорт, crime и perf принадлежат другим
авторам. Новых GPU-вкладок нет; производительность общей сцены не проверена.
