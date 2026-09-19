# Пересечения парковочных подъездов с пешеходными переходами

Read-only проверка `city_road_navigation.mjs`, физического `planCityParkingAccess` и общего crossing index. Production wrapper/router агентом аудита не изменялись. Отчёт: `outputs/roads_logical_20260912/driveway_crossing_control_audit.json`; команда: `node tools/road_dressing/audit_driveway_crossing_controls.mjs`. Полный worker и GPU не запускались.

На свежем candidate с 77 public/service crossings проверены 105 реальных автомобильных подъездов. Найдено шесть пересечений с четырьмя зебрами:

| Подъезд | Переход | Координаты, метры | Место требуемой остановки относительно начала подъезда |
|---|---|---|---|
| hospital-001 entry:1 | parking-crosswalk-0 | 674.119, 18.387 | +2.962 м |
| hospital-001 exit:-1 | parking-crosswalk-0 | 674.265, 17.513 | +2.638 м |
| old_town_narrow_townhouse_v1-002 entry:1 | street-crosswalk-16 | 261.142, 42.327 | +0.010 м |
| old_town_narrow_townhouse_v1-002 exit:1, задний ход | street-crosswalk-16 | 261.142, 42.327 | +4.986 м |
| old_town_narrow_townhouse_v1-005 exit:1 | street-crosswalk-23 | 453.474, 54.696 | +7.064 м |
| old_town_narrow_townhouse_v1-010 entry:-1 | parking-crosswalk-20 | 210.657, 211.583 | −2.357 м, на предшествующей дороге |

Точные исходные accessRouteId и crossingProgressM находятся в JSON. Участок wrapper добавляет `prefix`/`tail` после graph route; проверенная версия сдвигала существующие `result.controls`, но не индексировала добавленные пути. Изолированный тест настоящего wrapper с нулевым graph-участком в физической начальной точке подъезда подтвердил: три entry tails добавляются полностью, результат `ready`, при этом `controls=[]`. Это тест состава маршрута; он не выдаётся за доказательство графовой связности или LIVE движения.

Общий ответ `requiresLiveClearance:true` для accessRouteId сообщает правило уступания, но в проверенной версии не вычислял решение по `occupiedCrosswalkIds`. Нужен тот же канонический crossing control, что на улицах.

С владельцем graph согласован `router.registerExternalPathControls({id,points})`:

- `id` — существующий accessRouteId, подпись геометрии защищает динамический parking prefix от неверного повторного использования.
- Возвращаются канонические `id`, `crosswalkIds`, `railCrossingIds`, `progressM`, `crossingProgressM`; `evaluateControl` проверяет эти IDs через существующий registry.
- Gear не меняет геометрический поиск; wrapper сохраняет gear исходных точек.
- Wrapper переводит stop progress в расстояние по **полному** собранному маршруту. Отрицательное значение для tail переносится в реальный предшествующий graph-участок. Только остановка до самого начала всего маршрута получает `distanceM=0/startInsideApproach=true`.
- Для уже сформированных graph-controls нужно сохранить неокруглённый `requestedDistanceM`, иначе прежний clamp скрывает остановку на parking prefix, который wrapper добавит позже. Поле запрошено у владельца router.
- После сборки controls сортируются по общему расстоянию, stopPoint находится интерполяцией фактических assembled points, а не по продолжению касательной.

AL-022: `parking-crosswalk-21`, центр `(217.3,219.25)`, проверен отдельно. В этом fixture он не пересекает ни центр, ни полный кузов на парковочных путях: 1190 близких положений кузова, 0 касаний. На самой служебной улице присутствуют `lane-edge-775` и `lane-edge-776`; оба канонических controls запрещают движение при занятом crossing ID. Для AL-022 новый driveway control в этом наборе не требуется.

Предел: финальный worker после independent parking augment может добавить подъезды; этот аудит следует повторить по его snapshot. Проверка и подключение нового API принадлежат владельцам router/wrapper. Производительность общей игровой сцены этим CPU-аудитом не измерялась.

## Повтор после подключения API владельцами

После CPU release Координатора 17 аудит обновлён и выполнен повторно: **PASS**, 0 ошибок, ~1922 мс. Теперь adapter использует настоящий `createDirectedLaneRouter`, его `registerExternalPathControls` и `evaluateControl`; изолирован только выбор graph journey, чтобы не пересобирать весь город ради теста wrapper.

- Все шесть фактических crossing hits зарегистрированы канонически. Свободный переход разрешён, занятый запрещён; поддельный control ID отвергается, замена переданного `crosswalkIds` на пустой массив не обходит канонический registry.
- На трёх настоящих entry tails wrapper теперь возвращает по одному нужному control вместо прежнего `controls=[]`. Проверен и круговой вызов `query(mode:'road-rules')` с native stop coordinates: occupied запрещает, clear разрешает.
- Точка остановки и `startInsideApproach` соответствуют полному assembled route.
- Две явно обозначенные проверки сборки используют маленькие синтетические graph sections: negative stop настоящего oldtown010 tail переносится через угол на предшествующий segment; отрицательный graph `requestedDistanceM` переносится в parking prefix, получая `distanceM=5.7` и точку `(17.7,0)`. Они проверяют контракт интерполяции, а не физическую проходимость выдуманной улицы.

`driveway_crossing_control_audit.json` больше не устанавливает GAP по самому наличию пересечений: итог определяется отсутствием канонических controls, фактическими решениями occupancy и ошибками stop projection. Полный новый worker snapshot после augment всё ещё требует отдельного повторения.
