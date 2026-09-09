# Source vehicle cabin render batches — 10 сентября 2026

Независимый helper `assets/maps/city_rebuild_v1/vehicle_render_batches.mjs` предназначен для подключения координатором к `world_traffic_presentation`. Обычный fleet, damage physics, исходные модели, двери и водительские механики не изменялись.

```js
const renderBatches=createVehicleRenderBatches({THREE,root:actor.object});
// После actor.update, до rendering:
renderBatches.update();
// До существующего release(actor.object):
renderBatches.dispose();
// Диагностика — объект, не метод:
renderBatches.stats;
```

## Контракт

Только непрозрачные Mesh под `Interior_*`, группировка по identity исходного material, точному layout атрибутов, shadow flags, renderOrder и layers. Каждый BatchedMesh прикреплён непосредственно к тому же Interior root. Полные исходные вершины/нормали/индексы копируются без упрощения, local matrix части хранится отдельно. Перемещение/наклон всей машины автоматически наследуются через исходную иерархию.

Steering, wheels, doors/hinges, engine/hood/trunk, damage/detached, glass/windows/lights, подвижные педали/рычаг исключены. Skinned/Instanced/Morph/материальные массивы, неполный drawRange и отрицательные local transform не включаются. Батчи менее3 деталей не создаются.

У исходного Mesh сохраняются геометрия, parent, visible, layers и Mesh.raycast. Только его material временно заменён скрытым clone, как в существующем static batching. Batch использует оригинальный material: сохранённые внешние ссылки на его color/emissive/maps/visible продолжают работать. Дополнительных Proxy, render callbacks или changes drawRange нет.

`update()` отражает source.visible и родительскую видимость внутри салона, обновляет изменённые локальные матрицы и bounds. При замене material/geometry, изменении версий geometry атрибутов, отсоединении либо отрицательном local transform конкретная деталь возвращается к обычной отрисовке. Изменение свойств скрытого материала переводит связанные с ним детали в обычную отрисовку, сохраняя изменённый материал. Изменение матрицы всей машины не требует перезаливки её деталей.

`dispose()` идемпотентен: возвращает исходные material refs для активных источников, удаляет/освобождает собственные BatchedMesh и оставшиеся собственные hidden clones. Исходные geometry/material не освобождаются. Изменённый hidden material, уже возвращённый в source rendering, передаётся существующему владельцу машины и освобождается позднейшим обычным release. Поэтому **helper.dispose до release машины обязателен**.

## CPU приёмка

`node assets/maps/city_rebuild_v1/test_vehicle_render_batches.mjs` PASS: все12 настоящих авторских GLB и production createArtistVehicle,751044 проверок мировых вершин в двух положениях/наклонах автомобиля, сохранение source geometry/raycast/ancestry/anchors/seats, source visibility, исключение steering/doors, изменение локальной матрицы, замена material, geometry version, изменения оригинального material и hidden clone, идемпотентное освобождение только собственных ресурсов.

| Модели | Деталей в batch | Batched draws | Убрано draws на машину |
|---|---:|---:|---:|
|hatchback, compact/executive sedan, wagon, SUV, police|47|6|41|
|coupe, van, pickup, bus, ambulance, fire|21|4|17|

Остальные части машин остаются обычными meshes, их draw calls не включены в таблицу. Число треугольников и близкое качество не сокращаются. Реальное объединение draw требует WEBGL_multi_draw (координатор подтвердил наличие в текущем renderer). CPU update одного helper в500 повторах примерно0.02–0.14мс; браузерный FPS этим не заявляется.

Root интегрирует только sourcecars, у которых destructive damage сейчас хранится metadata. Это не новая поддержка деформации fleet и не разрешение включать helper туда без отдельной приёмки. Агент не изменял host и не открывал браузер; LIVE выполняет координатор.
