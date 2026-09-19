# Парковка → вход: пешеходные переходы, 13 сентября 2026

Владелец: interior_furnishing, интеграция worker — root, controls/traffic graph — interior_layout, реальные входы башен — interior_safes. GPU не запускался.

## Исправленное поведение

Старый парковочный поиск разрешал идти по любому проходимому асфальту. В исходном аудите 34 из 46 маршрутов переходили общую дорогу вне зебры; продольные заходы на асфальт и территории самих парковок считались отдельно.

Новый `city_parking_pedestrian_routes.mjs` строит маршрут по сухому грунту и частным парковочным поверхностям. Общую проезжую часть можно пересечь только целиком через явно заданный crossing portal. Несколько соседних зебр не превращают асфальт между ними в разрешённую пешеходную площадь. Сначала используется существующая сеть переходов и все подходящие общие парковки. Только оставшийся спрос создаёт кандидаты новых переходов; неиспользованные и заменимые переходы удаляются до установки геометрии. Соседние дома используют общие переходы.

Полная окружность персонажа радиусом 0,38 м и её непрерывное перемещение проверяются против реальных polygon bodies, границ запрещённых клеток, железной дороги и разрешённых дорожных поверхностей. Это исправляет прежнюю проверку пяти точек, пропускавшую касание угла между пробами. Поиск выполняется один раз в worker; per-frame поиска нет. Кешируются геометрия разрешённых участков дороги и неизменные рёбра сетки. Неиспользуемые поля массового поиска до дверей в этом режиме не выделяются.

Новые зебры имеют сухие берега, физически свободную полосу, спрос от конкретных парковок и зданий, знаки с обеих сторон и линии уступания перед переходом. Кандидаты поверх существующих stop/yield/arrow/crosswalk знаков разметки отклоняются. Новые переходы проверяются и друг против друга: вся пешеходная полоса одного не может пересекать зебру либо линию уступания другого. Конфликтующая зебра переносится на ближайшее допустимое место с повторной проверкой всех достижимых входов. Продольные линии локально обрезаются перед новой зеброй; их оставшиеся части и исходные дорожные IDs сохраняются. Служебные проходы выделены в `trafficPlan.serviceCrossings`, с правилом `vehicles_yield_to_pedestrians`; общественная зебра на служебном въезде не рисуется.

## Worker-контракт

После окончательной установки дорожных столбов и `replanCityParkingWalks`, перед компиляцией дорожного графа и `prepareTrafficControls`:

```js
import {resolveCityParkingPedestrianAccess} from './city_parking_pedestrian_routes.mjs';
const pedestrian = resolveCityParkingPedestrianAccess({
  parkingPlan, roadPlan, topology, instances,
  extraBodies: decorPlan.colliders, railPlan, metresPerCell: 4.1,
});
parkingPlan = pedestrian.parkingPlan;
roadPlan = pedestrian.roadPlan;
```

Функция сохраняет положение, размеры, IDs, автомобильные въезды/выезды и места всех парковок. `walkingRoutes`, `walkingAlternatives`, `coverage`, `servedBuildingIds` отражают реально проверенные пешеходные связи. Максимальный разрешённый путь — 300 м; выбирается короткая доступная связь, а не случайная ближайшая зебра на другой улице. `walkingAlternatives` содержит только варианты, для которых сохранился проверенный путь через итоговые переходы. Новые столбы размещаются вне выбранных и альтернативных проверенных путей, а также всех сохранённых `sidewalk`, `doorRoute` и `doorRouteViaCrossing` исходных и новых переходов.

Если сухой островок между соседними переходами короче стандартного шестиметрового тротуарного подхода, `walkingAccess.sidewalk` может содержать `{kind:'crossing_connector',nextCrosswalkId,length,points}`. Это проверенный непрерывный сухой путь к реальному endpoint другой зебры длиной до 18 м; проходы через автомобильную часть в такой соединитель не допускаются. Наличие основного parking→door пути само по себе не заменяет проверку боковых подходов.

Общественный crossing: `{id,kind:'parking_access',roadId,center,tx,tz,endpoints,roadStart,roadEnd,signalControl:null,priority:'pedestrians_on_crossing',demand:{buildingIds,lotIds},signIds,stopControls}`. `stopControls.point` обозначает линию уступания; это не положение центра кузова. Учитывать длину автомобиля при остановке. Для служебного прохода `kind:'service_access'`, приоритет `vehicles_yield_to_pedestrians`; структура геометрии та же. Обработчик дорожных controls должен учитывать обе коллекции, включая crossing на длинных connections, а не только внутри turn.

Для двух compact podium towers устаревший `entry.anchorRC` лежал на дороге и не совпадал с дверью модели. `planTowerPublicApproach(instance)` предоставляет проверенную площадку перед настоящим пандусом. `route.points` заканчивается на этой ground landing, `route.entryApproach.points` содержит реальный 3D suffix `[landing,rampToe,door]`, `requiresDoorInteraction:true`. `distance`, `walkingDistance` и краткие альтернативы включают длину suffix; `groundWalkingDistance` сохраняет отдельную длину наземного пути. Геометрия, коллизии и исходные placement/anchor IDs не заменяются. Actual GLB тест Safes: 4/4 PASS, 1446 положений капсулы и проверок высоты пандуса, `outputs/tower_public_approach_20260913/actual_route_report.json`.

## Промежуточный результат на интегрированном городе

`outputs/roads_logical_20260912/final_worker_parking_pedestrian_audit.json`, source SHA256 `044973256e6f9ad29c36596bd57b3698082ba9b10a51e5cb0feac9fd9ca9a90f`:

Это исторический snapshot до финальных T-join/rail изменений и усиления взаимной проверки новых зебр. Поздний аудит обнаружил в нём наложение полосы parking-crosswalk-3/4 и пересечения стоек с короткими тротуарными ветками. Исправления находятся в текущем helper; этот snapshot требуется пересобрать, его старые числа не являются финальной приёмкой.

- 78 зданий, 39 парковок, 59 мест, 46/46 обслуживаемых входов.
- 31 вход связан существующей сетью; добавлено 19 общественных переходов и 1 служебный проход. Всего 73 общественные зебры и 1 service crossing.
- 40 знаков, 380 новых полос/штрихов, 20 продольных элементов локально обрезаны под зебрами.
- Наибольшая длина пути 143,75 м.
- 19 429 проверок полной капсулы на итоговых телах: 0 ошибок; 0 наложений зебр на старую управляющую разметку; 0 необслуживаемых входов.
- Существующие общественные переходы, знаки, светофоры, turn/connection/approach IDs и правила сохранены.

Автомобильные подъезды перепроверены `test_city_parking_access.mjs` на итоговом candidate: 6/6 PASS; 106 путей, 39 въездов и 39 выездов, 38 928 положений кузова / 29 990 промежуточных проб, 0 конфликтов с новыми столбами, полосами и поддерживающей поверхностью.

## Стоимость и проверка

До/после добавления переходов на одном 78-building fixture: 67 → 67 draw calls, 5 → 5 equipment batches; 178 884 → 198 302 triangles. Новые знаки и разметка используют существующий общий renderer без отдельного mesh/light на каждый предмет. В более позднем интегрированном snapshot итоговая структура составляет 67 draws и 198 550 triangles после независимых изменений графа.

Финальное измерение exact-edge cache выполнено на сыром плане **до** пешеходного post-pass: `raw_worker_dressing_snapshot.json`, SHA256 `6c82005eec316f1faf239fe9c23b25a85ec7351383ec3537eab271c2818cfcc2`. Четыре чередующиеся пары, первая прогревочная, три измеряемые: p50 8184,9 → 3290,4 мс; p95 8255,4 → 3322,8 мс. Каждый маршрут, знак, полоска и метаданные before/after совпали. В замер вошли создание кандидатов, их сокращение, полная проверка рёбер, новые знаки, защита альтернативных пеших путей и реальный 3D suffix двух башен. Исходники стабильны. Отчёт `parking_pedestrian_cpu_comparison.json` содержит source manifest.

Этот более поздний raw fixture уже содержит промежуточные T-joins другого автора: 527 junctions, 4999 turns, 57 исходных зебр и 15 controllers. Post-pass и на нём сохранил 46/46 входов. После усиления взаимной проверки новых зебр: 20 новых общественных переходов + 1 служебный, 42 знака, 414 полос/штрихов, 19 локальных обрезок продольной разметки; максимум 148,40 м. Проверено 19 286 положений капсулы, ошибок/paint conflicts 0. Структурно: 67 → 67 draws, 184 896 → 205 346 triangles. Последний одиночный запуск после исправления взаимного наложения переходов — 3,53 с; измеряемое сравнение кеша выше выполнено до этой узкой правки выбора кандидатов. Изменения количества controllers происходят до post-pass; его before/after сравнение всех сигналов и правил проходит побайтно по структуре. После завершения T-join graph root повторяет полный worker QA; не подменять это текущими промежуточными числами.

Регрессии: 7 новых содержательных тестов полной капсулы, водного угла, непрерывного касания между пробами, полного crossing portal, блокирующего столба, ограниченной частной парковочной поверхности и взаимного положения зебры/линии уступания. Вместе с существующими тестами pedestrian access, дорожного control placement и renderer lifecycle — 19 PASS.

Производительность общей сцены не проверена. CPU и структурные draw/triangle counts не заменяют LIVE приёмку в очереди Координатора16/Artist16.

Команды:

```powershell
node --test assets/maps/city_rebuild_v1/test_city_parking_pedestrian_routes.mjs assets/maps/city_rebuild_v1/test_city_pedestrian_access_plan.mjs assets/maps/city_rebuild_v1/test_city_road_dressing_control_placement.mjs assets/maps/city_rebuild_v1/test_city_road_dressing_render_lifecycle.mjs
node tools/road_dressing/audit_parking_pedestrian_production.mjs outputs/roads_logical_20260912/integration_candidate_snapshot.json --existing
node tools/road_dressing/compare_parking_pedestrian_cpu.mjs outputs/roads_logical_20260912/raw_worker_dressing_snapshot.json
node tools/road_dressing/audit_final_crosswalk_access.mjs integration_candidate_snapshot.json
node tools/road_dressing/audit_rail_and_crossing_controls.mjs integration_candidate_snapshot.json
```

## Финальный аудит подходов и переездов — 13 сентября

`audit_final_crosswalk_access.mjs` проверяет исходные junction crossings, новые parking crossings и отдельные service crossings: сухие берега, настоящие двери/спрос, все сохранённые тротуарные ветки по итоговым телам, непрерывное пересечение, стоп-линии, соответствие реального светофора, весь 44-секундный цикл и запас времени пешехода, отсутствие полосы перехода в railway keepout. На последнем промежуточном raw fixture после защиты тротуарных веток: **78/78 crossings PASS**, 0 ошибок, ~486 мс CPU; основной audit — 46/46 входов, 19 286 проб капсулы, 0 ошибок разметки/физики. Регрессии 19/19 PASS. Автомобильные тесты с обновлённым физическим радиусом поворота также 7/7 PASS: 105 путей, 39 въездов + 39 выездов, 0 ошибок; это текущий CPU fixture, не движение NPC в LIVE.

`city_road_dressing_plan` передаёт `railPlan` в traffic planner и сериализует `trafficPlan.railCrossings`. Только исходные city&&drive переезды разрешает traffic owner; `isRoad`/`paintSafe` по-прежнему запрещают разметку в железнодорожном коридоре. `audit_rail_and_crossing_controls.mjs` проверяет точные IDs/геометрию реестра, сохранённые railway signal posts и указатели станций, положение разметки, worker-prepared canonical control index, pedestrian/rail occupancy и запрет поддельных control IDs. Он также выводит короткие stop leads и неохваченные crossing IDs для проверки владельцем графа.

Финальный полный worker snapshot после rail/ограниченных T-joins ещё ожидается. По поручению root тяжёлые CPU-прогоны приостановлены на время измерения общей сцены оптимизатором. Финальные raw/integrated audit и сопоставимый повтор CPU выполняются после освобождения очереди. GPU-сцен агент не запускал.

После разрешённого root worker run появился snapshot с 492 junctions, 4936 turns, 60 heads / 16 controllers и 74 public crossings. В нём выявлен один unsigned yield: `street-junction-205:L-CH-V-045:0:-1` рядом с существующим `city-rail-crossing-2`. Обычные 603 кандидата отклонил железнодорожный зазор. Узкая правка разрешает повтор поиска на том же непрерывном сухом берегу до 6 м от кромки только при исходном control center внутри railway reservation; запреты пересечь другую дорогу/воду/следующий junction и полные keepouts сохранены. Адресный probe нашёл левую стойку `(58.5658786, 415.3667637)`, yaw `-2.9699646`, setback 5.2 м, advance 0 м и 10.74 м до junction. Тесты control placement 8/8 PASS; адресный CPU probe ~805 мс (`unresolved_control_probe.json`). Общая пересборка после этой правки отложена до разрешения root, поэтому единственный unresolved в текущем JSON ещё не является результатом исправленного планировщика.

## Свежий raw после разрешения Координатора 17

Выполнен один свежий raw rebuild, SHA256 `ee4e33963c34a6867fa3a4bc5ea451645843d2392f01246b99712dbb36b83a08`: 6358 markings, 437 signs, 60 heads / 16 controllers, 492 junctions / 4936 turns, 55 исходных crossings, **unresolvedPlacement=0**. `final_raw_dressing_audit.json`: PASS без geometry и semantic review; `final_raw_crosswalk_access_audit.json`: 55/55 PASS. `final_raw_rail_controls_audit.json`: точный исходный реестр переездов, 0 paint в railway keepout, canonical pedestrian/rail occupancy запрещает движение при занятом переходе. Короткие stop leads переданы владельцу graph для переноса на реальный предыдущий участок маршрута; финальная проверка prepared worker после его правки остаётся у root.

При полном post-pass дополнительно проверены резервы `footprint`/`entryCorridor` вокруг каждой новой стойки. Все свободные места для двух стоек теперь проверяются **до** принятия demand-crossing. Два тесных crossing-кандидата заменены пространственно допустимыми, маршруты пересчитаны; существующие исходные crossing/sign/control IDs сохранены.

Последний `parking_pedestrian_candidate_snapshot.json`: 55 исходных + 21 новых общественных перехода и 1 служебный проход, **77 всего**, 44 новых знака, 469 новых элементов paint, 29 обрезок только продольных линий. 46/46 входов, максимум 164.47 м; 19 930 проб полной капсулы, 0 ошибок. `final_candidate_dressing_audit.json` и `final_candidate_crosswalk_access_audit.json` — PASS, нет стоек в резервах зданий/входов, разрывов тротуарных связей, нарушений фаз или railway band. Автомобильный access regression 7/7 PASS; остальные 20/20 PASS. Одиночный post-pass CPU 3593 мс; структурно 67 → 67 draws, 180 508 → 202 022 triangles. Это свежий raw + post-pass candidate, ещё не финальный worker после independent parking augment и upstream control anchors.
