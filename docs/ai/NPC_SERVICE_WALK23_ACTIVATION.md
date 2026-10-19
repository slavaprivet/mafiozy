# Один настоящий магазин: composed World/Walk proposal

23 сентября 2026, Художник21. **Независимый narrow ACCEPT. Не применён автором.**
Scope: только `REBUILD-VISUAL-print_shop-001`. Никаких новых GPU-вкладок.

FINAL: inventory review повторно ACCEPT после panic fix:20немедленных yields,
lease null с первого tick, commerce cancel1/80/receipt0, actualpanic+.78m,
физический выход41frames, все6 interruption scenarios и actualGLB4skins112bones
PASS;30 reviewedSHA совпали. По поручению root пересобран exact пакет на
текущие2shadow-comment строки Walk: **patch38d5b63a**, World272a→9f5cc5a1,
Walk8c10460d→337d53c2. Runtime modules неизменны. LIVE маршрут в
`NPC_SERVICE_WALK23_LIVE_PATH.md`; автор production не применял, GPU не открывал.

UPDATE 2: актуальный пакет **f2c952c3** заменяет b219f766. World272a2266→9f5cc5a1,
Walk unchanged d1e3eeea. Independent reviewer нашёл service handler, который
потреблял NPC tick при panic, хотя exit movement правильно отвергал чужое
управление. Новый `_residentServiceYield23` в activation addon (accepted customer
module не переписан) отменяет unsettled commerce/lease и немедленно возвращает
управление существующему interruption owner без записи walking/coords/route.
Физический exit certificate остаётся у исходного visit, после incident выход
возобновляется с фактической позиции через прежние floor/sweep guards.

`test_npc_service_interruption23_candidate.mjs` **322546d8** PASS6 scenarios:
panic в await/approach/counter, combat/report/conversation у кассы. В каждом
20ticks handler возвращаетfalse без присвоения чужого движения/route; деньги80,
receipt0. Actual original panic branch+route executor переместил покупателя .78m;
после окончания инцидента все6физически вышли без переноса. Полное восприятие
угроз/бой не симулировались. Normal actual GLB fullcycle повторно PASS,
актуальный test SHA **7f2980c4**. Последний отдельный CPU384 прогон:
native .0006/.0009ms, composed .2832/.4320ms, idle .0082/.0200ms. GPU/FPS нет.

UPDATE 1: пакет **b219f766** был перебазирован на World272a2266 (heroepoch
координатора сохранён); Walk6b242067 unchanged. Host module **757c3992** исправляет
обнаруженный actual-population дефект: getActor возвращал parent у скрытой cache
копии после stream-out. Теперь readiness требует актуального getActors membership,
того же actor.object, текущего source ID и видимых предков. Никакого runtime apply.

Новая основная проверка `test_npc_service_skinned23_candidate.mjs` **df72df21**
использует настоящий production npcPopulation/getActor, verified GLB, SkeletonUtils,
4 skinned mesh/112 bone references, creationBudget1 и cap72. Точный source selection
slice проверяет service priority даже против100 mission drivers и24civilian reserve.
Full cycle/касса/смерть60s/blockers проходит с настоящими скелетными моделями.
Stream-out retained cache, hidden object/ancestor, detached actor, missing source,
wrong employment generation и disposed population не разрешают движение.
Новый продавец получает новый GLB actor, не старую модель трупа.
Проверка source projection после quota использует обычные поля NPC fixture;
полный getDynamicEntities serializer/рендер-кадр здесь не запускался.
CPU384 actual skin fixture: native point .0013/.0019ms, composed .3215/.5453ms,
idle controller .0090/.0226ms. Только стоимость логики; LIVE/FPS не проверены.

## Что передаётся

`NPC_SERVICE_WALK23_ACTIVATION.json` содержит точные before/after SHA обоих
host-файлов, все 11 runtime dependencies, proposal/test SHA и результат прогона.
`NPC_SERVICE_WALK23_ACTIVATION.patch` — единый World+Walk delta относительно
текущих shared файлов. Проверка `git apply --check --ignore-space-change` PASS.
Не применять старые source/customer/return patches поверх этого: они уже включены.
Если host изменился, регенератор `outputs/build_service_walk23_proposal.mjs`
строит только output copies/manifest/patch и не пишет production.

Шесть модулей `assets/maps/city_rebuild_v1/service_pilot23_candidate/` реально
доступны на 18538: все HTTP 200, text/javascript. Root candidate URLs дают 404,
поэтому Walk импортирует именно `./service_pilot23_candidate/walk_host.mjs`.
Пакет пока нигде в production не импортирован. Генератор
`outputs/package_service_walk23_candidate.mjs` делает воспроизводимые копии:
employee без изменений; source = accepted source + accepted return hook +
синхронное обновление collider двери; return/visits меняют только пути imports;
visibility и Walk host — новые review candidates. Исходные accepted четыре SHA
source/customer/return не переписаны.

## Точные подключения

- World: accepted source lifecycle/calm movement, pre/post-loop ticks, customer
  lease/checkout/reverse exit, staged remote return через настоящий public entrance.
  Новый merchant installer связывает source ownership, сервисный registry и lease.
  `_getWalkServicePhysicalBodies23` читает полный текущий source roster до renderer
  distance/72 cap. Полицейские/медицинские interruption сохраняют приоритет.
- Walk: `ensureStationaryServiceWalk23()` в начале updateNpcPopulation ждёт готовых
  buildingEntries/hero/population/nav/collision index и вызывает merchant installer.
  Создаёт геометрию кладовки/кассы и самостоятельную collision group. Leaf update
  сразу меняет группу и сбрасывает cache native sweeps. clearContent/pagehide
  unregister/dispose удаляют собственную группу, lease/provider/mesh resources.
- Только настоящий owned service body получает mission admission перед остальными
  кандидатами при сохранении общего лимита72. Рядом с игроком source стоит внутри,
  пока actual population actor не включён в текущий snapshot с видимым object.parent.
  Retained hidden cache недостаточно. Нет отдельного decor NPC.
- Hidden birth: актуальная камера/frustum либо консервативное полное перекрытие
  bbox одной непрозрачной гранью/convex pair. Положительные результаты не кешируются.
  Видимая кладовка, glass/cutaway/deformed/uncertain occluder держат respawn.
- Полный физический host: source NPC/корпсы + current presentation poses + player +
  uncapped source traffic + fleet/traffic transforms. Источник перечитывается при
  каждом запросе, не подменяется 100ms renderer snapshot. Нет truncation списка64.
  Unknown NPC Y — консервативная колонна; соседний другой этаж может задержать NPC.
  Неизвестный nearby aircraft/tow блокирует. Это ограничение пилота, не точная
  окончательная высотная модель всех физических персонажей города.
- Native capsule остаётся radius .18cell/.738m, поддержка пола/ceiling/water и
  статический sweep проверяются до динамического sweep. Нет записи actorY/teleport.

## Проверено

`node assets/maps/city_rebuild_v1/test_npc_stationary_service_walk23_candidate.mjs`
использует именно packaged modules, настоящие source functions/commerce/GLB/
native geometry/door routes/uncapped source roster. Продавец появляется скрыто,
ждёт model admission, открывает дверь, идёт к работе. Покупатель проходит до
кассы, 80→77 / один receipt, выходит обратным маршрутом. 100 неотрисованных NPC,
65 у двери, source авто между кадрами, hidden fleet, retained corpse и player
блокируют. На другом этаже actual hero Y не блокирует. Мёртвый продавец не продаёт;
нет замены в59s; новый source ID в60.1s появляется в той же кладовке. Старый corpse
JSON не меняется. Dispose удаляет provider и collision group.

Пределы: confirmed-death boundary здесь инъецируется; actual hit/downing/bleedout
проверены отдельным ранее accepted source suite. Старая геометрическая проверка
использует Object3D stand-ins; новая основная скелетная проверка описана выше. Паника/return
были проверены отдельным accepted actual source planner suite, не full-world AI.

Visibility: actual-building camera suite PASS; независимые17 cases +6 convexPair
PASS, narrow ACCEPT SHA `0a9143fb5bbee58e986ed2f68115770ad90cefa7d7cffa1301339c9bdb334d24`.
Полный roster отдельно14 cases PASS. Walk syntax и точный patch check PASS.

## Стоимость и LIVE

CPU fixture,384 source NPC, одна и та же точка кладовки, прогрев30/120 samples:
native point p50/p95 .0006/.0012ms; composed full physical point .2751/.4052ms;
idle employee controller .0065/.0078ms. Далёкие NPC всё равно перечисляются; это
цена полного fresh roster. Sweep/read выполняется при движении/двери/респавне,
а не каждым кадром спокойно работающего продавца. Geometry21parts/4draws/924tris
из предыдущей проверки станции; это не измеренный renderer frame.

**Производительность общей сцены не проверена.** После независимой проверки
координатор применяет пакет и согласует единственную LIVE/GPU сессию: продавец
видим целиком; двери/руки/ноги; покупатель/касса/обратный выход; убийство и60s;
камера внутрь кладовки задерживает birth; blockers; unload/reload. Сравнить
прогретую одинаковую камеру/население/settings p50/p95/draw calls/triangles до/после.
До этого не объявлять работающий магазин опубликованным. Другие здания, личный
банк/больница и контактное вытаскивание из авто остаются отдельными задачами.
