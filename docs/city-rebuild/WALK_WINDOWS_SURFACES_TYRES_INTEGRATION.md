# /walk — интеграция комнат, окон, фонарей и шин

2026-09-08, doors_glass. `walk_preview.mjs` и `tools/city_rebuild_walk.html` переданы
обратно root после интеграции. HUD оружия и Q не менялись. Collision index,
dirty cache входов и stableEntryLights сохранены. Подсветка дверей автомобиля
отменена пользователем: host вызывает `car.setHighlightedDoor(null)`.

## Что подключено

- SurfaceMotion применяется один раз за кадр ходьбы, в том числе при неподвижных
  XZ. Нет прямого сброса Y на землю при сходе с края. Reset после focus, выхода из
  авто и QA-перемещений; прыжок передаёт опору после приземления/падения.
- resolveJumpSurface ограничивает голову потолком и переводит удар/сход с высокой
  поверхности в гравитационное падение. Запрещён горизонтальный проход прыжком
  через слишком высокий пол или низкий потолок. Камера следует физической Y,
  существующий camera clamp стен/крыши остаётся.
- `?buildingqa=1`: выбор конкретного здания, «к выбранной двери», E, проход
  внутрь, центр полной комнаты, выход и прыжок. Проходы используют движение и
  промежуточную точку у двери, без телепорта внутрь комнаты.
- 43 жилых здания / 675 окон; 128 фонарей / 176 светильников / fixed 8 PointLights.
  По умолчанию день. В меню сцены есть видимая кнопка «Вечерний свет» и обратное
  переключение; она не меняет серверное время.
- TyreDamage получает исходный onImpact; effects перед stepCar; update с фактическим
  frame distance после stepCar и до car.update. Без stepCar используется distance:0.
  Reset вместе с carDamage, dispose на pagehide. Стекло/HP продолжают получать удар.

## Окна и комнаты: существенный порядок

Новый `building_window_integration.mjs` создаёт окна **до** room CSG: обратный
порядок терял одну исходную компоненту Garden Walkup и давал 671 окно вместо 675.
Пока строится entry, generated windows.group скрыт: ordinary-mesh CSG не должен
интерпретировать InstancedMesh без его instance matrices. Затем отдельные прорези
делаются только в новых внутренних стенах комнаты по тем же windows.panes.cut.
Стекло регистрируется последним, после всех изменений геометрии/материалов.

Teardown: glass → roomReveals → street lamp application → entry → windows →
doorsGlass; затем manager фонарей. Это восстанавливает цепочку приватных и cached
геометрий до освобождения refs. Кеш окон использует исходную shared geometry.

## Проверки и данные для профилирования

PASS `node --check assets/maps/city_rebuild_v1/walk_preview.mjs`.

PASS `test_building_window_integration.mjs`: все 43 полные комнаты + 675 окон,
попадание в один instance каждого дома, восстановление исходных geometry и
refs=entries=0 после teardown. Перед teardown: 106 entries, 535 refs, 429 hits,
106 misses. PASS `test_surface_motion.mjs`, включая потолок и сход прыжком с края;
`test_street_lighting.mjs`, `test_tyre_damage.mjs`, `test_car_drive.mjs`.

Datasets: `residentialWindows` (количество и cache), `windowCacheAfterClear`,
`streetLighting`, `surfaceMotion`, `tyreDamage`, действующие `buildingEntry`,
`glassBreakage`, `vehicleDamage` и `carDrive` сохранены. Node-проверки не заменяют
LIVE; браузер пользователя агентом не перезагружался и не управлялся.
