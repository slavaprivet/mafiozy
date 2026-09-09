# Парковки Координатора 15 — 10 сентября 2026

Scope этой передачи: новые `city_parking_plan.mjs`, `city_parking.mjs`,
`test_city_parking.mjs`. Общий worker/walk/environment подключает Координатор 15.
Ни topology, ни placements, ни native 4.1, ни игровые ID не изменяются.

## Подключение

`createCityParkingPlan({topology, instances, keepouts, railPlan, metresPerCell:4.1})`
возвращает только сериализуемые данные, пригодные для structuredClone/worker.

- `lots`: площадки, ссылка на исходный `buildingId`, `layout`, размеры,
  `entryPaths`, `exitRule`, `servedBuildingIds`, `tour`.
- `bays`: координаты/направление/габариты стояночных мест.
- `surfaceRects`: world AABB покрытия; `keepouts`: те же участки для травы/декора.
- `accessKeepouts`: AABB полного автомобильного манёвра и устья на дороге.
  Передать в `createCityRoadDressingPlan({accessKeepouts})`; сами surface keepouts
  тоже передать в обычный список road keepouts для стоек и переходов.
- `colliders`: стойки P/«Уступите дорогу», обычные `polygonCR` в native4.1.
- `coverage`, `walkingRoutes`: доказанные сухие пешие связи до точки стояния
  в 0.7м перед реальной входной дверью. Путь не рисует самодельный тротуар.
- `mapFeatures`: метка P строго в центре реального AABB, включая узкий карман.

Pure helpers: `isCityParkingSurface(plan,x,z)`,
`cityParkingGroundHeight(plan,x,z)` (0 или null),
`cityParkingCarFits(plan,x,z,yaw,shape)`. Последний проверяет полное покрытие
прямоугольника кузова объединением native road и парковочных прямоугольников
через вычитание выпуклых полигонов. Он дополняет обязательную runtime collision
проверку существующих/новых препятствий; не разрешает обход коллизий зданий.

`createCityParking({THREE,plan})` → `object`, `colliders`, `mapFeatures`,
`update({focus})`, `stats`, `dispose()`, wrappers трёх helpers.
Ни новых lights, ни canvas/textures, ни покадрового rebuild. Материалы сдержанные
clay; разметка и P геометрические. Стойки и покрытия InstancedMesh по ячейкам128м.

После расстановки дорожных стоек вызвать
`replanCityParkingWalks(plan,{topology,instances,keepouts,railPlan,extraBodies})`.
Передать roadPlan.colliders и procedural decor colliders в `extraBodies`,
исходные/декоративные keepouts, но **не** собственные parking keepouts.
Результат — новый plain plan с обновлёнными пешими путями/coverage, исходный plan
не мутируется. Площадки/автомобильные заезды не перемещаются. Отдельный тест
ставит стойку посреди существующего маршрута и подтверждает обход с46/46.

## Геометрия и доступ

- Перпендикулярные площадки: 2 или 4 места 3.2×5.4м, манёвровый проезд6.2м,
  driveway9м через существующую плоскую обочину. Два въезда/поворота по дуге
  радиуса4.8м, по49 поз полного кузова каждый. P обращён к въезжающему,
  уступание — к выезжающему.
- Узкие параллельные карманы: площадка14.4×4.4м, одно место3.2×6.4м,
  оставшаяся длина для плавного заезда.65 поз кузова на S-переходе с улицы.
  Дорожный mouth включает весь манёвр19.1м вдоль улицы.
- Площадки только на native8/9, не на проезжей части, воде, protected/police.
  Сохраняются все footprint/clearance/entry corridors/авторские decor envelopes,
  железная дорога и подходы станции. Топология исходного покрытия неизменна.
- Перед въездом подтверждается прямая существующая проезжая полоса шириной6м
  и непрерывной длиной18м. Дополнительно проверяется полный кузов на каждом
  шаге поворота, включая отклоняющиеся за пределы этой полосы углы.
- Дорожный AI и парковочные NPC не добавляются. `exitRule` — явный контракт
  будущему traffic host: уступать движению улицы и пешеходам.

## Проверки и важное условие порядка планирования

`node assets/maps/city_rebuild_v1/test_city_parking.mjs` PASS:
39 площадок,61 место,1 больничная площадка на4 места; все46 текущих целевых
домов/больница имеют доказанную общую парковку.7 зданий без личной площадки
обслуживаются общей.23328 проб покрытия,3195 автомобильных поз,7454 проб пеших
путей;42 draw calls,14712 triangles,0 lights. Проверены запрет изменения входных
данных, structuredClone, ориентация P, коллизии стоек, нормальный dispose,
exact-support тест с отверстием под кузовом, невидимым corner-only проверке.

Этот результат включает авторские buildings/decor и rail, но initial test
не включает поздно посеянный procedural exploration decor. Если procedural decor
планируется раньше parking и его коллизии добавляются как новые keepouts,
получается38 площадок/61 место и45/46 целей: для
`REBUILD-VISUAL-coastal_orchard_house_v1-002` декор занимает все подходящие
участки в95м, ближайшая оставшаяся парковка в159.65м.

Рекомендуемый обязательный порядок для заявленного полного покрытия:
preliminary parking plan по авторским placements → его keepouts резервируют
участки в `planExplorationDecor` → final parking plan проверяет итоговые
procedural colliders → roads/grass учитывают final parking keepouts.
Координатору передан этот нюанс; не объявлять46/46 для живой сцены, пока полный
интеграционный test не подтвердит её фактический порядок/данные.

Spatial index keepouts16м сократил full-scene parking planner примерно с29с
до2.5с в Node. Это одноразовая работа worker, не frame update.

## LIVE

Браузером владеет только Координатор 15. Автор этой scoped передачи LIVE не
проводил; CPU PASS не означает визуального одобрения. Больница tour:
`{x:679.45,z:13.4,yaw:Math.PI}`. Для жилой сцены использовать актуальный
`parkingPlan.lots.find(l=>l.kind==='residential').tour`, поскольку дополнительные
keepouts могут менять детерминированный выбор участка.
