# Полные комнаты и опора ног — 2026-09-08

Работа doors_glass. Внешние входы приняты пользователем; задача расширяет комнаты
за ними и исправляет мгновенное падение на границах опорной поверхности.

## Согласование владельцев

Координатор передал `building_entry.mjs` и `building_entry_profiles.mjs` после
применения optimizer cache hunks. Полные комнаты реализованы поверх них:
staticBodies и collisionBodies cache с invalidation при движении двери сохранены.
`walk_preview.mjs`/HTML остаются у интегратора автомобиля, doors_glass их не меняет.

## Причина и решение высоты

На боковом крае рампы `floorHeight` возвращает null за пределами реальной геометрии,
host подставляет уличный0 и напрямую назначает hero.y. Это физическая ступень,
которая должна вызывать короткое падение, а не телепорт. Нельзя маскировать её
размазыванием высоты сквозь боковую стену платформы.

`createSurfaceMotion(options)` использует реальные floorHeight и world metres:

```js
import {createSurfaceMotion} from './surface_motion.mjs';
const support = createSurfaceMotion({stepHeight:.28, maxSlope:.8, gravity:18});
support.reset(hero.object.position);

// В pedestrianAllowed добавляется проверка высоты пути относительно текущих ног.
// Коллизии стен/створок остаются в существующем canWalk.
const surfaceAllowed = (x,z) =>
  canWalk(x,z) && (support.state?.grounded === false ||
    support.canMove(hero.object.position,{x,z},groundHeight));

// Один раз за frame ходьбы, после вычисления candidate XZ, до commit движения.
const next = support.update({x:candidateX,z:candidateZ,dt,floorHeight:groundHeight});
hero.object.position.set(next.x,next.y,next.z);
// next.blocked означает, что высокая поверхность отклонила перемещение.
// Камера/target следуют полной разнице XYZ, а не только XZ. Действующий
// camera ray clamp продолжает защищать потолок и стены комнаты.
```

Нужно убрать оба прямых присваивания hero.y=groundHeight в ходьбе. Controller
обновляется даже когда XZ неподвижны: иначе падение с края остановится в воздухе.
После QA-approach/focus/finishExit, завершения прыжка и любых внешних позиций нужно
`support.reset(hero.object.position)`. Во время jump/seat/exit-animation этот
controller не применяется: эти режимы уже имеют собственную вертикальную фазу.

Непрерывный спуск по рампе следует точному полу, без зависания ног и проникновения
под поверхность. Малые ступени до.28м допускаются; высокий подъём отвергается до
сменыXZ. Резкий большой перепад вниз даёт гравитацию и приземление на floor. Длинный
кадр проверяет промежуточные точки пути через.12м, а не только конечную клетку.

`node assets/maps/city_rebuild_v1/test_surface_motion.mjs` — PASS: рампа в обе
стороны; падение с1м края без teleport; высокая платформа заблокирована; ступень.2м
допущена; подземного y нет; пропущенная высокая поверхность ловится substeps.

## Аудит комнат

`building_room_profiles.mjs` хранит bounds настоящих основных объёмов на уровне
первого этажа, независимо от широких bbox козырьков, деревьев и верхних уступов.
Аудит использует GLTFLoader, реальные материалы/узлы и сечение y1.4 для merged
моделей. Tower LightLimestone проверен как один connected podium y0..4.4.

19 типов покрыты. У трёх тонких городских домов расширяется глубина7.3/14.72/14.05м
при сохранении узкого силуэта. Частные6домов используют MainBody. У civic/hospital
короткий входной проход соединяется с широким MainBody/MainWing. Помещение смещено
относительно двери там, где сама дверь находится сбоку фасада.

Предварительная проверка648 точек новых комнат по72placements: ни одна не попала
в запрещённый topology.walkableMask. Дополнительный обход уличного mask не нужен.

`createBuildingContentRoot(THREE,parent,instance,position)` создаёт пустой Group
`Building_Content_<instance.id>` с buildingInstanceId, gameplayId, assetId и
previewOnly. Это место последующего наполнения конкретного здания, не общий
шаблон содержимого. Игровой inventory/ownership/server interior не удаляется.

## Итог реализации и приёмка

Полные комнаты подключены в createBuildingEntry для всех 72 placements / 19 типов.
Это основное помещение первого этажа; отдельные боковые крылья, верхние этажи и
служебные входы не превращались в новый игровой layout. Узкие дома сохраняют
реальную ширину принятого силуэта, но используют всю глубину основного объёма.

API entry расширен:

- `contentRoot`: индивидуальный пустой Group по instance.id, начало координат в
  центре комнаты на её полу. Наполнение следующего этапа добавлять сюда.
- `roomCenterPoint()`: world Vector3 центра полной комнаты. `roomPoint()` сохранён
  как прежняя близкая к двери точка для QA/обратного взаимодействия E.
- `report.room`: minX/maxX/minZ/maxZ, width, usableDepth, area, height и source.
  Координаты относительно entry.object; для strip пол находится на local Y=.45.
- `ceilingHeight` различает потолок короткого входного коридора и основной комнаты.

У strip платформа теперь проверяется по реальным верхним треугольникам, включая
скруглённый скос, вместо выдуманного плоского прямоугольника. Новый
`building_floor_surface.mjs` собирает этот heightfield один раз. В floor domains
добавлен микронный допуск против численной щели на точной границе ramp/platform
у повёрнутых экземпляров. Боковой сход с настоящей платформы обрабатывает
surface_motion с гравитацией, а не расширение невидимого пола в воздухе.

`node assets/maps/city_rebuild_v1/test_building_rooms.mjs` — PASS всех 72 комнат:
648 внутренних точек, проход к ним и обратно, отсутствие визуальных перегородок
по лучам на высоте тела, совпадение floorHeight с реальным mesh под ногами;
вверх/вниз по рампе через обе точные границы, cache identity/invalidation,
сохранение геометрии CANON_WINDOW/Small_Interior и удаление contentRoot при dispose.
Канонические оконные дисплеи остаются в фасадных нишах, а contentRoot пуст.

| Тип | Площадь основной комнаты, м² |
|---|---:|
| old_town_narrow_townhouse_v1 | 22.13 |
| eastside_garden_walkup_v1 | 36.24 |
| eastside_stepped_apartment_v1 | 34.55 |
| coastal_orchard_house_v1 | 71.48 |
| garden_lane_house_v1 | 52.63 |
| hillstep_chalet_v1 | 60.58 |
| pine_ridge_cottage_v1 | 64.16 |
| veranda_bungalow_v1 | 67.75 |
| woodland_crosswing_house_v1 | 67.04 |
| pawnshop | 96.05 |
| print_shop | 143.45 |
| gun_shop | 127.60 |
| bookmaker | 128.76 |
| nightclub | 83.62 |
| civic_hall | 88.11 |
| hospital | 155.89 |
| compact_podium_glass_tower_v1 | 183.75 |
| glass_pavilion_small_v1 | 74.74 |
| strip_club | 99.76 |

LIVE визуальный прогон остаётся координатору. Модуль surface_motion готов, но
прямые присваивания hero.y в walk должен заменить владелец walk; сам этот срез
не изменял walk/HTML и не объявляет исправление телепорта интегрированным до hook.
