# Первый живой NPC slice: source residents → типография → покупка → выход

26 сентября 2026. Статический аудит действующего локального кода и имеющихся Godot данных. **Ни один NPC snapshot не выдуман и не экспортирован; runtime/main не изменены.** Manifest: `outputs/coordinator21_npc_port/SOURCE_INVENTORY.json`, reproducible collector рядом. Прочитаны 27 source/data files; manifest содержит точные bytes/SHA и линии world symbols.

## Вывод

Минимальная законченная игровая вертикаль — существующий source продавец типографии и существующий source житель: житель получает реальную цель из agenda/needs, резервирует место, физически доходит до входа и прилавка, получает одну оплачиваемую газету через session checkout, выходит, освобождает занятость и продолжает agenda. Продавец принадлежит реальному NPC roster, реагирует на interruptions; после подтверждённой смерти новый source body появляется скрыто не раньше 60 секунд, физически возвращается за прилавок, после чего продажи снова доступны.

Один продавец, поставленный за стойку, или несколько rig-моделей с циклическими waypoint не закрывают эту вертикаль. Доступны исходники всех её основных частей и geometry типографии, но **ещё нет Godot source session/roster, полного host/navigation/agenda/commerce исполнения и appearance/pose bridge**. Публичная capped render projection не может заменить их.

## Кто является authority и почему seed недостаточно

`world.html:8726–8797`: `NPCS`, `_residentSerial`, `spawnNpc(seed, opts)`. Обычные жители — session-owned simulation, не серверный multiplayer roster. Factory создаёт `resident_${++_residentSerial}`; начальное здоровье 60/60, source look, archetype/speed/emotions, position/tr/tc. `seed` выбирает сектор и retry sequence, но position/archetype/look/speed/emotions используют **Math.random** и текущий `getGameHour()`. Повтор `spawnNpc(0)` не восстанавливает существующего жителя.

`initNpcs()` очищает коллекции и публикует residents из factory, native target 288. Это city-wide lifecycle, а не требование создать 288 актёров в восьми домах Godot. `npc_city_population_source.js` поддерживает 30 секторов; bounded replenishment максимум 3 births/6 attempts/2 ms, с `NPC_RESPAWN_MIN_DIST`, body-clear spawn и без переноса уже опубликованного NPC к удобному doorway. `_npcInitialPlacementPending` не допускается в render/physical body projection до source validation.

Для сохранения существующих IDs/прогресса нужен **полный trusted source session capture/import**: raw source ID, life/generation, pose/source position, HP/fatal receipts, look/archetype, clocks, agenda, wallet/inventory/receipt/transaction state, reservations/interior occupancy, serial allocator и control owner. Такой capture в доступных Godot данных отсутствует. Здесь он не изготовлен. Нельзя восстановить состояние из ID-счётчика или разложить `resident_1..N` вручную около игрока.

Для нового игрового сеанса допустим будущий точный порт самого session factory/bootstrap с actual geometry/game-hour/RNG providers, а не выдача synthetic fixture за перенесённый старый сеанс. Выбор import existing session против new-session bootstrap — интеграционное решение root. Аутентифицированные gang/mission/HP/денежные серверные данные при этом не становятся client authority.

## Три identity, которые нельзя смешивать

| Назначение | Точный контракт |
|---|---|
| Ordinary source body | `resident_<serial>` выдаёт factory. Конкретные живые значения в этом аудите неизвестны. |
| Render/action bridge identity | `_threeNpcEntityId` (`world.html:69693`) возвращает `npc_` + explicit source ID; для жителей это `npc_resident_<serial>`. Нельзя дважды добавлять/снимать prefix. |
| Employment slot продавца | `REBUILD-VISUAL-print_shop-001:news-counter:employee` — постоянная должность, не source тело. |

**Уточнение прежнего предположения oldID/newID:** отдельно прочитанный `employee.mjs` действительно сохраняет employeeId и повышает generation. Однако полный `service_pilot23_candidate/source.mjs` передаёт в FSM view именно стабильный employmentId. Он отдельно вызывает `host.spawnNpc(++seed, {cityOnly:true})`, проверяет уникальный новый `resident_…`, публикует его в `host.npcs`, сохраняет `sourceBodyId` в spawn receipt и увеличивает employment generation. Старый corpse не переиспользуется. Поэтому **полный source host уже совместим с новым source ID после 60 секунд**; ошибка возникла бы при прямом использовании FSM employeeId в роли render/source entity ID.

Code evidence: source.mjs `employmentId`, `view()`, `spawn()`, `birth.sourceBodyId`; существующий `test_npc_stationary_service_source23_candidate.mjs:67–76` явно сравнивает `second.id != first.id`, bridge IDs и одинаковый employmentId. Этот старый test импортирует root candidate/patch и записывает чужой output, поэтому в данном аудите не запускался и не называется свежим PASS действующего host.

Исходные комментарии «World does not import it»/«isolated candidate» устарели относительно wiring: текущий `walk_preview.mjs:1` импортирует `walk_host.mjs`, `ensureStationaryService23` подключает его; `world.html:9750`, `70531`, `70653–70655` предоставляют source registration, а `updateNpcs` вызывает controller до и после основного NPC update (`18703`, `19279`). Авторитетом подключения являются эти вызовы, не старый комментарий в файле.

## Что даёт публичный bridge, а что не даёт

- `Mafiozi3DBridge.getDynamicEntities(65)` — 10 Hz presentation selection, cap 72 NPC; pools/priority/sticky radius, hide carried/evacuated/pending placement. `npc_population.mjs` consumes it и прямо запрещает создавать gameplay entities/HP/AI. Это **не полный roster**, не сериализатор, не сохранение agenda/wallet и не источник world collision occupancy.
- Render rows содержат `id/r/c/look/HP/deathConfirmed/deathRecord/source clock` и action projections; ordinary row `sourceId` может быть пустой строкой. Нужна source reference mapping, нельзя считать все строки server-owned.
- `_getWalkServicePhysicalBodies23` (`world.html:70553`) — uncapped bounded-area source census с `complete`, `sourceFrame`, aliases/ref, posture/seated/dead. Отказ при missing/uncertain source/legacy interior. Это правильное основание physical occupancy; `getDynamicEntities` и visibility этого не заменяют.
- `getWalkNpcVehicleTraffic`, real hero shape и rendered vehicle/skin bounds дополняют physical roster. Unknown poses дают conservative vertical column, unsupported nearby vehicle закрывает проход. В native Godot этих source providers пока нет; пустой массив «все свободно» недопустим.

## Реальные geometry/IDs уже доступны

Godot block origin `[395.65, 0, 45.1]`, scale 4.1 m/source cell. `local X=c*4.1-origin.x`, `local Z=r*4.1-origin.z`; anchors Godot уже local metres. Source `r/c` не записывать в local x/z без conversion.

`data/block.json` содержит восемь исходных зданий: print_shop, gun_shop, pawnshop и пять old_town_narrow_townhouse с исходными IDs (полный список manifest). `data/printshop_interior.json`: 103 static bodies, 41 mesh records, 3 rooms, current public/service moving doors. Это geometry snapshot, **не NPC roster**.

| Объект | Existing ID |
|---|---|
| Типография | `REBUILD-VISUAL-print_shop-001` |
| Resident access/capacity key | `native:REBUILD-VISUAL-print_shop-001` |
| Станция | `REBUILD-VISUAL-print_shop-001:news-counter` |
| Кладовка | `REBUILD-VISUAL-print_shop-001:floor:0:room:1` |
| Техническая дверь | `REBUILD-VISUAL-print_shop-001:stockroom-service-door` |
| Public leaf | `REBUILD-VISUAL-print_shop-001:public-door` |

Local anchors (metres, rounded здесь; использовать точные JSON values):

| Anchor | X | Y | Z |
|---|---:|---:|---:|
| spawn | -3.86835 | 0.39 | 5.555097 |
| doorInside | -3.22570 | 0.39 | 5.475097 |
| doorOutside | 0.47430 | 0.39 | 5.475097 |
| work | 0.58430 | 0.39 | 3.750447 |
| customer | 3.06430 | 0.39 | 3.750447 |
| customerVia | 3.06430 | 0.39 | 5.649447 |
| publicApproach | 7.40520 | 0 | 5.649447 |
| publicInside | 2.81520 | 0.39 | 5.649447 |

`PreviewPrintshopInterior.anchor`, `request_door(key,open,actor_position,occupants)`, `advance(dt,occupants)`, `door_fraction` уже существуют. Service opening требует actor в 0.25 m от inside; door sweep принимает bodies `{position:Vector3,radius,height}`, invalid/>64 запрещает действие; step duration 0.6s. Перед подключением NPC host должен передать **всех** физически релевантных occupants, включая лежащих/скрытых/неотрисованных. Текущий main host не является готовым NPC census.

`npc_resident_building_access.mjs` выдаёт отдельный access door `native:<instanceId>` с authored entry-derived outside/inside и open readiness fraction>=.95. Не путать этот logical visit ID с public mesh leaf ID или service door ID.

## Appearance/model/controller — конкретный путь

1. Source bridge row → `npcAppearanceFromWorld` (`npc_population.mjs`) → `sourceLookAppearance` (`npc_role_catalogue.mjs`) + `bossArtDirectionForId` → `describeNpcAppearance` (`npc_appearance.mjs`). Stable appearance RNG использует **bridge row id**, не raw resident ID; изменение prefix меняет остаточные traits.
2. Canonical male `player_male.8130dfb1f7eb.glb`, 652732 bytes, SHA `8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00`; совпадает с `godot/mafiozi_walk/assets/hero.glb` byte-for-byte. Female `player_female.298d50e6244a.glb`, 641836 bytes, SHA `298d50e6244a7f17cf9cb66530fc34645fec0f19b575fe99d1df514709e90c40` доступен локально, пока не импортирован отдельным Godot NPC asset.
3. Оба GLB имеют один skin и **0 animation clips**. Нельзя вызвать `AnimationPlayer.play("walk")` и считать это переносом. Existing hero procedural locomotion можно переиспользовать только как pose subsystem после проверки rig/height; целиком `preview_player.gd` несёт player input/camera/control и не является NPC controller.
4. `applyNpcAppearance` меняет private cloned geometry/materials/vertex colors, body/face shape и собирает hair/accessory geometry, привязанную к canonical bones. Просто цветной material поверх общей hero mesh теряет лицо/волосы/пол/одежду и не является parity. Возможен future offline exporter **для реальных source descriptors** либо полный native descriptor-to-geometry adapter; сейчас ни один не реализован.
5. `normalizeNpcSnapshot` даёт metres, yaw=`PI/2-ang`, posture/action/aim/source time/lifecycle. `npc_source_lifecycle.mjs` не выводит fatal death из HP=0 или исчезновения; confirmed death/downed обязательно различаются. `npc_actor.mjs` сводит locomotion, Artist14 pose/surface/death, service/activities, vehicle ownership. Первый actor controller должен принимать source intents, выдавать physical motion receipts и позу фактической пройденной дистанции, а не запускать второй AI.

## Полный минимальный pipeline и точные зависимости

| Шаг | Source files/functions | Что требуется в Godot |
|---|---|---|
| Сеанс/roster | `spawnNpc`, `_pickArchetype`, `_initNpcEmotions`, `initNpcs`, `npc_city_population_source.js` | Один authority host, явный import/bootstrap и persistent identity allocation; никаких render-owned births. |
| Resident цель | `npc_activity_agenda_source.js`, `_civilianPlanNext/Arrive/Cancel`, resident commerce personal places | Existing agenda semantics/interruptions, а не fixed shop loop. Astra FSM scope не дублировать. |
| Building slots | `npc_activity_reservations_source.js` | Capacity 15 включает pending+inside; failed alternative не теряет прежнюю reservation; inside не истекает от render absence; physical exit releases. |
| Дойти до двери | `_planNpcRouteTo`, `npc_native_directed_route_source.js`, `npc_native_navigation.mjs`, `npc_swept_footprint.mjs` | Real resumable A* с direct sweep/goal anchors/fine isolated-start fallback; PathJobQueue только admission. Actual body/static/dynamic/floor/headroom checks; PENDING != NO_PATH. |
| Вход/визит | `npc_resident_building_access.mjs`, `_residentEnterBuilding`, `_residentNativeVisitTick`, `_residentServiceBeginApproach23/_residentServiceRouteTick23` | Open current public door, swept approach, handoff physical occupancy; route interruption/reverse exit stays owned. |
| Продавец | service `source.mjs`, `employee.mjs`, `return.mjs`, `_stationaryServiceReturnHost23` | Actual source body/generation, hidden/clear/model-ready birth, panic/report return through actual entrance, no teleport to work. |
| Обслуживание | `visits.mjs`, `npc_stationary_service_adapter.mjs`, `npc_resident_commerce_source.js` | Customer station lease + current physical arrival; employee stamp rechecked at commit. Newspaper price 3; wallet source owns exactly-once receipt/inventory. Server business revenue untouched. |
| Collision occupants | service `walk_host.mjs`, physical census, `visibility.mjs` | All source bodies, real hero/vehicle extents; partial census holds door/movement/spawn. Hidden birth visibility requires actual camera occlusion certification. |
| Отрисовка | `npc_population.mjs`, `npc_appearance.mjs`, `npc_actor.mjs` | Canonical clones per existing ID, source clock interpolation, private appearance, distance gait, source fatal/downed ownership, no render death/despawn of source. |

Сейчас можно последовательно переносить эти exact independent modules и geometry/model tooling. Необходимые source functions доступны локально; **недоступное состояние** — actual live authoritative roster, RNG state/clock capture, active IDs/transactions/leases и authenticated backend snapshot. **Отсутствующие native исполнения** — source session host, geometry query/actor movement providers, agenda/commerce/service adapters, appearance/pose bridge. Это разные ограничения; наличие source-кода не означает уже работающий Godot gameplay.

## Следующий bounded component на согласование root

Предлагаю точный порт **`npc_swept_footprint.mjs`** в новый `scripts/navigation/npc_swept_footprint.gd` плюс independent JS↔GD actual-polygon fixtures/headless tests. Это общий body sweep для authored concave polygons и service dynamic geometry; не зависит от Astra FSM, HP, воды/dive, main или actor spawn.

API сохраняет `set(from_rc,to_rc,radius=.18)`, `overlaps(polygon_cr,test_point=null)` и bounds. Нельзя заменить obstacle concavity convex hull или square footprint капсулой: source boundary semantics включают touching/contained/crossing polygons и callback на реальной контактной точке. Source epsilon 1e-10/1e-18 требует GDScript scalar float64 representation; Vector2 float32 нельзя без измеренной parity выдавать за точный порт. Test point callback остаётся host authority, не water logic внутри модуля.

Этот scope **только предложен**, реализация не начата. Нужен root assignment перед изменением runtime. Existing read-only source test `node assets/maps/city_rebuild_v1/test_npc_swept_navigation.mjs` выполнен: exit0, PASS thin/concave/contained/touching solids, bounds/dirty groups, real height/custom passage guards. Это source CPU PASS, не будущий Godot proof.

## Приёмка полного slice

- Source/read-model IDs, look и source clock соответствуют actual captured/bootstrap authority, generic aliases не сливаются. Reentry/model eviction не создаёт новый NPC и не сбрасывает HP/receipt.
- Житель physically входит и выходит, reservations не текут; blocked door/counter/NPC держит PENDING/hold. Cut-through walls/teleport запрещены.
- Один газетный receipt и ровно одно списание 3 после свежего employee/customer stamp. Death/panic/disconnect/site revision между quote и commit блокирует продажу.
- Подтверждённая death сразу закрывает checkout; до 59999 ms birth отсутствует; 60000 ms только разрешает attempt. Visible/occupied stockroom или model-not-ready держат продавца внутри. Новый raw/render ID, прежний employment ID, generation+1, corpse остаётся прежним.
- Interruption внутри не освобождает физический footprint; authoritative exit/death handoff, uncapped census и source reservations согласованы.
- Source JS traces → native headless → один root LIVE с фактическими NPC и geometry. Сравнимые population/camera/warmup, actor/queue/update CPU и frame p50/p95. GPU/LIVE в этом аудите не запускались; производительность общей сцены не проверена.
