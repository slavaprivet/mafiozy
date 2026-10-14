# Native site capture/HQ — первый изолированный контракт20

Принятое направление: `../game-design/NATIVE_SITE_CAPTURE_HQ_20260920.md`.
Штаб — роль захваченного существующего здания, не новый дом на пустыре.

## Готово / пределы

`assets/maps/city_rebuild_v1/native_site_control.mjs` содержит каталог
настоящих instance IDs с явным списком разрешений и planner capture/HQ.
Он ничего не подключает в `world.html`, не меняет owner, DB, размещение,
интерьер, серверную экономику и AI. Возвращённый intent **не является**
квитанцией успешного захвата. Это первый обратимый строительный блок.

Для намерения нужны актуальные manifest/ownership/defence версии, полные
данные защиты/присутствия от доверенного host, боеспособный живой участник
внутри именно этого site. Принадлежность проверяется до HQ. Перенос HQ
передаёт ожидаемый старый штаб и его revision для атомарного обновления.
Не задаём неутверждённую длительность удержания и не создаём второй AI.

## Проверки

- `test_native_site_control.mjs`: guards/presence/contested/identity/
  manifest/HQ prerequisites; planner не мутирует переданный мир.
- `test_native_site_control_geometry.mjs`: актуальный placement75,
  фактические GLB/entry controller oldtown001 и banksmall. Настоящий roomPoint
  принимается как interior, approachPoint остаётся снаружи. Банк без явного
  policy не становится захватываемым. Оба файла прошли первый root прогон.
- Независимый adversarial review исправил sparse/duplicate actor gaps:
  dense уникальные списки, явная disposition относительно claimantFactionId,
  hostile defender roster вместо неоднозначного списка всех защитников.
  Root suite unit+adversarial+geometry: 5/5 PASS.
- Height audit исправлен: catalog.contains использует floorHeight с текущей
  высотой и ceilingHeight. Ноги в пределах15см от пола, ниже потолка;
  отсутствующая/нечисловая/ошибочная геометрия отклоняется. Actual GLB:
  три этажа таунхауса принимаются, крыша8.575м отклоняется; банк floor0.1м
  принимается как интерьер, roof4.995м отклоняется и capture policy запрещён.
  Под полом(-.2м), в воздухе(+.5м), над зданием и outside approach отклоняются.
  Unit+adversarial+actual geometry после patch5/5 PASS (субагент,603.9мс CPU).

Не проверены: server commit/CAS/idempotency, permissions лидера, бой,
реальное перемещение NPC внутрь, E/UI, сохранение после reload, LIVE/FPS.
Модуль не импортируется runtime, поэтому общего per-frame overhead не добавляет.

## Что переиспользовать, а что нельзя объявлять готовым

В `mafiozi_bot.py` фазы `_city_gang_business_set_phase` и snapshot
`_city_gang_business_operation` дают существующую форму approach/breach/
capture/guard и operation_id/phase_seq. Однако прежний capture — удержание
у внешнего входа, не вход внутрь. `_npc_business_controls` — runtime racket,
не persistent ownership; его событие не считать передачей native-здания.

`create_custom_gang_db` полезен транзакционной схемой ownership-before-HQ
и audit. Но `hq_apt_key`, apartment_coords_from_key, покупка и snapshots
ожидают legacy tile/block keys; нельзя вставить туда длинный REBUILD ID
или свести два разных native-дома к одному старому кварталу.

## Следующий интеграционный шаг

Источник мира должен владеть полным site roster, подтверждёнными
neutralised hostile guards и containment настоящих actors. Adapter строит
snapshot относительно конкретной атакующей банды; render culling не меняет
количество защитников. Перед commit он заново проверяет наличие/бой/
присутствие, actor binding и права лидера, затем одной транзакцией сравнивает
версии и сохраняет владельца с operation ID. Replay возвращает прежнюю
квитанцию, две конкурирующие попытки дают одного владельца. HQ обновляется
отдельной атомарной операцией только после владения.

Новый endpoint должен явно включаться в authenticated actor-binding policy;
существующие middleware prefixes не защитят его автоматически. Offline QA
и authenticated server должны иметь явные разные адаптеры, без заявления
о серверной готовности по monitor18538. До согласованного адаптера ничего
не начислять, не переименовывать старую собственность и не запускать захваты.
