# Автономная визуальная проверка автопарка

`export_runtime.mjs` собирает 12 исходных GLB и красный Kingswell настоящими
`createArtistVehicle` / `createDemoCar`, `createVehicleHood` / `createVehicleTrunk`.
Используется официальный `RoundedBoxGeometry` Three.js 0.180.0, совпадающий с
importmap игры. Контроллеры открываются через штатные `toggle` и обновляются
90 шагов по 1/60 с; двери открываются через `setDoorById`.

Экспорт содержит все видимые mesh с учётом видимости предков, мировые вершины,
нормали, треугольники, группы материалов, цвета и параметры материалов. Исходные
GLB проверяются по SHA-256 из каталога и не изменяются. Хеши runtime-модулей,
состояния панелей и число треугольников сохраняются в `runtime_metadata.json`.

```powershell
node tools/vehicle_fleet_qa/export_runtime.mjs
& 'C:/Program Files/Blender Foundation/Blender 3.4/blender.exe' --background --factory-startup --python tools/vehicle_fleet_qa/render_runtime.py
```

Результат: `outputs/vehicle_fleet_continuation/runtime_closed.json`,
`runtime_open.json`, `runtime_metadata.json`, четыре PNG
`fleet_{closed,open}_{front,rear}.png` и `display_scales.json`.

Это **offline QA геометрии**, а не живой прогон игры. Свет, шейдеры и прозрачность
Three.js приближённо представлены Blender Eevee. JSON сохраняет native-метры.
Только на контактном листе модели нормализуются по длине, один и тот же
коэффициент применяется к закрытой и открытой машине и указан в подписи.
Кадры не предназначены для сравнения физических размеров разных классов машин.

`RoundedBoxGeometry.mjs` скачан без изменений из
https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/geometries/RoundedBoxGeometry.js
(Three.js, MIT; лицензия проекта: https://github.com/mrdoob/three.js/blob/r180/LICENSE).
