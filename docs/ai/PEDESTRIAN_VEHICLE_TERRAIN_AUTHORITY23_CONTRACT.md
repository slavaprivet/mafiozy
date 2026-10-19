# Пешеходная и автомобильная проходимость рельефа — общий контракт

23 сентября 2026. READ-ONLY. Основан на прямой пользовательской политике:
пешие игрок/NPC используют физически доступный рельеф, непрерывный крутой склон
проходят как scramble, стена блокирует или требует явного traversal; автомобили
остаются на дорогах, парковках и разрешённых подъездах. Production не изменён.

## Две независимые authority

Пешеходная authority отвечает на вопрос «может ли тело человека физически
пройти/вскарабкаться здесь». Автомобильная authority сначала отвечает «является
ли поверхность разрешённой для машины», а затем проверяет полный hull, воду,
уклон, высоту и динамические препятствия.

Разрешение пешехода не разрешает машину. `terrainAllows`, `canWalk`,
`nativePedestrianLand`, walk/scramble/climb masks и pedestrian slope никогда не
передаются как `poseAllowed` или route permission автомобиля. Совпадающая
геометрическая точка может быть `scramble` для NPC и `vehicle_surface_forbidden`
для машины.

## Пешеходный результат

Traversal lead владеет классификацией. Рекомендуемый read-only результат:

```js
{
  mode: 'walk' | 'step' | 'scramble' | 'vault' | 'mantle' | 'blocked',
  reason: 'clear' | 'no_surface' | 'unsupported' | 'headroom' |
          'body_blocked' | 'vehicle_moving' | 'water_transition' | 'wall',
  position, supportY,
  rise, maxRise,
  slope, slopeGrade,
  supportKind,
  traversal // optional explicit traversal description
}
```

- `walk/step`: непрерывная опора, допустимый обычный уклон или физически
  достижимая ступень и полный body volume.
- `scramble`: непрерывный terrain support без стены/нависания/разрыва; скорость,
  поза и расход движения принадлежат traversal, обычная ходьба не подменяет его.
- `vault/mantle`: явное препятствие и валидная authored/physical traversal arc.
- `blocked`: стена, потолок, неподдержанный разрыв, недопустимая вода, solid body
  или отсутствующая конечная опора. Большой уклон сам по себе не превращает
  вертикальную стену в scramble.

Player и NPC используют одинаковую геометрическую классификацию тела с явно
заданными различиями размера/позы. NPC потребляет только `walk/step/scramble` и
свою отдельную explicit traversal policy; player дополнительно использует
`vault/mantle`. NPC route не телепортирует actor между режимами. Traversal
movement повторно проверяет каждый physical segment и безопасно останавливается
при изменении мира.

## Автомобильный результат

Transport/road owner владеет отдельной семантической маской:

```js
{
  status: 'allowed' | 'blocked',
  surfaceClass: 'road' | 'lane' | 'parking' | 'driveway' |
                'service_access' | 'forbidden',
  accessRouteId, lotId,
  reason
}
```

Разрешённые поверхности:

- canonical road/lane graph;
- authored parking bay и проверенный parking entrance/exit prefix;
- authored driveway/access route, связанный с дорогой и lot/building identity;
- service access, явно зарегистрированный для конкретного здания/службы.

Grass, mountain, pedestrian path, scramble slope, plaza без vehicle tag и
произвольный `terrainAllows=true` остаются запрещёнными. Emergency/service car
не получает общего off-road исключения: он паркуется у ближайшего проверенного
access point, затем экипаж идёт пешком. Новый банк, магазин, больница или
наличный сценарий создаёт destination demand, но не создаёт подъезд без
authored access identity.

После semantic allow обязательны существующие physical gates: полный vehicle
hull и swept rotation, static/dynamic vehicles/pedestrians, water depth,
finite ground, clearance и допустимый vehicle grade. Разрешённая дорога может
быть физически заблокирована; semantic tag не является collision bypass.

## Точное значение `roadsOnly`

Существующий `roadsOnly:false` нельзя толковать как «машина может ехать по
любому terrain». После будущей интеграции он означает только: запросу разрешено
проверять canonical vehicle-access поверхности вне road mask — парковочный bay,
его authored prefix, driveway или service access с identity. Без такого
identity результат `vehicle_surface_forbidden`.

Основная часть civilian/ambient/service route остаётся `roadsOnly:true` по
lane/road graph. Короткий стартовый/конечный connector допустим только внутри
заявленного `accessRouteId` или parking prefix; ограничение расстоянием само по
себе не авторизует off-road. Последний прямой sweep к endpoint не расширяет
surface authority.

Player vehicle подчиняется той же маске. Если сохранённая/унаследованная машина
уже стоит вне неё, recovery может использовать только найденный обратный
authored connector или безопасно остановить управление; нельзя snap на дорогу,
прокладывать маршрут по горе либо наследовать pedestrian scramble.

## Текущие места, требующие осторожной будущей интеграции

- `npc_native_navigation.mjs` и `walk_preview.mjs` используют pedestrian
  `terrainAllows`; это scope traversal lead.
- `npc_vehicle_navigation.mjs` сейчас допускает `roadsOnly:false` через общий
  `poseAllowed`, а near-start/final connector временно снимает road requirement.
  Будущий vehicleAccess gate должен применяться внутри каждого pose/sweep, не
  только в route planner.
- `car_drive.mjs/createCarWorld` физически разрешает несколько плоских типов
  поверхности. Это collision/physics baseline, не достаточная semantic
  авторизация маршрута.
- `city_road_navigation.mjs`, parking origin и service access уже несут
  `accessRouteId/lotId` и являются источником разрешённых non-road connectors.
- `civilian_parking_trip_source.js`, ambient traffic и ambulance должны
  сохранять road/access identities при каждом replan; pedestrian destination
  не должен передаваться машине как конечная terrain pose.

## Владение и порядок

- Traversal lead `Добавить прыжок и перелезание`: `hero_surface_motion`,
  pedestrian pose modules/tests, walk/step/scramble/vault/mantle semantics.
  `walk_preview.mjs` — только после отдельного слота Координатора20.
- Transport3/road owner: vehicleAccess mask, road/parking/driveway/service
  identities, trip/parking semantics и vehicle regressions.
- Координатор20: shared wiring в Walk, сохранение приоритетов, единый LIVE/GPU.

Общие файлы не редактируются параллельно. Сначала публикуется текущий checkpoint,
затем Transport3 применяет уже готовый узкий driver-not-ready lifetime fix.
Terrain contract интегрируется отдельным пакетом после точных fixtures и review.

## Приёмка

Пешеходы:

- continuous shallow terrain → walk;
- continuous steep terrain с опорой → scramble;
- vertical wall/overhang/gap → blocked или explicit vault/mantle;
- одинаковая классификация при 60/15/7/5/3 Hz, без шага сквозь solid;
- player и NPC доходят физически, без route-only teleport.

Автомобили:

- road/lane, 59 parking bays и их exits остаются доступны по identity;
- authored driveway/service access проходит только со своим route ID;
- mountain, pedestrian trail и untagged grass отклоняются даже если там может
  пройти NPC и `poseAllowed` не видит solid;
- full hull/rotation/water/dynamic blockers сохраняются;
- civilian, ambient, ambulance и player не получают off-road после расширения
  pedestrian terrain;
- off-road casualty обслуживается как vehicle-to-access + crew-on-foot;
- cash/bank/shop/hospital demand без доступного подъезда выбирает другую
  парковку/пеший остаток или bounded отказ, не прямой автомобильный shortcut.

CPU route/sweep до/после измеряется отдельно; LIVE/FPS — в единственной вкладке
Координатора20. Этот документ — граница authority, не готовая механика.
