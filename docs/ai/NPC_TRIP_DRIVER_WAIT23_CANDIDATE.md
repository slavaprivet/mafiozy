# Ordinary NPC trip: бесконечное ожидание водителя у границы маршрута

23 сентября 2026. READ-ONLY READY. Кандидат НЕ применён в production.
Координатор20 сохраняет freeze до exact checkpoint push. GPU не запускался.

## Подтверждённый отказ

`_civilianTripTickCar` требует подтверждённого видимого/логического водителя
до обработки текущей точки маршрута. Это правильное ограничение.
`_civilianTripWatchProgress` при этом безусловно пропускает таймаут для двух
случаев: машина почти совпадает с текущей точкой (`settling`), либо точки уже
закончились, а phase ещё `drive`.

Если в этот момент отсутствует близкий NPC presentation actor,
`createNpcLogicalVehicleBinding.driver` законно отвечает
`{ready:false,mode:'visible'}`. TickCar не продвигает индекс и не паркует,
watchdog бесконечно считает положение завершаемым. Поездка и agenda `drive`
удерживаются без физического прогресса. Такой путь может занять ограничение
16 поездок; его массовость в текущем LIVE не установлена.

## Минимальный кандидат

Только условие в `_civilianTripWatchProgress`, helper + mirror world:

```js
// До, часть существующего условия:
trip.phase==='drive'&&!driveTarget||settling||
// После:
(trip.phase==='drive'&&!driveTarget||settling)&&!car._civilianDriverNotReady||
```

При подтверждённом водителе прежние исключения сохраняются. При отказе
действует существующий 90-секундный no-progress recovery: машина стоит,
дверной путь проверяется, NPC физически выходит, затем завершается agenda.
При заблокированной двери существующий recovery продолжает ждать безопасного
выхода: таймаут не телепортирует NPC и не обходит collision/readiness gate.

Production scope после разрешения: только
`assets/maps/city_rebuild_v1/civilian_parking_trip_source.js` и соответствующая
строка `_civilianTripWatchProgress` в `world.html`. Squad/pose/fire/driver
binding не менять. Кандидат: `outputs/npc_trip_driver_wait23_candidate.patch`;
исходные SHA256 и HEAD: `outputs/npc_trip_driver_wait23_candidate_manifest.json`.
Перед применением обязательно сверить текущие scoped строки после checkpoint.

## Actual-source regression

`assets/maps/city_rebuild_v1/test_npc_trip_driver_wait23.mjs` запускает настоящий
agenda reservation, helper, native road/parking/navigation, compact sedan GLB,
static authored scene и `createNpcLogicalVehicleBinding`. Для воспроизведения
удаляется только stand-in NPC Object3D после завершённой посадки; это проверяет
наличие presentation actor, не его skinning. Source identity остаётся той же.
Кандидат переопределяет только watchdog в VM, production файлы не записывает.

| Сценарий | Исходный код | Кандидат |
| --- | --- | --- |
| Actor пропал у первой точки, совпадающей со стартом | После 110 с всё ещё drive, 0 м, completed 0 | Физический exit и release в 91.35 с от начала сценария, 0 м, следующая agenda walk |
| Actor восстановлен через 10 с | Отдельно не сравнивался | 248.413 м, parked → exit → arrived, 185.45 с |
| Actor пропал после последней точки, до phase parked | После 110 с ожидания всё ещё drive | Exit/release через 90.55 с после потери actor; итог 248.413 м |

Все пять прогонов PASS. Ни машина, ни NPC не телепортируются; максимальный
шаг NPC за 50 мс 0.14614 м. При отсутствии водителя машина после потери actor
не двигается. Отчёт `outputs/npc_trip_driver_wait23.json`.

CPU source NPC+car tick p50/p95 в сопоставимом ожидании у первой точки:
baseline 0.0110/0.0265 мс, candidate 0.0112/0.0257 мс. Это малый изолированный
CPU замер; **производительность общей сцены не проверена**, LIVE/FPS у
Координатора20. Добавленное условие не создаёт объектов и не делает новых
navigation queries в обычном кадре.

## Остальные границы полного цикла

- Pending planning и blocked approach уже ограничиваются существующим
  watchdog; исходный Trip17 blocked start не обходить.
- Постоянно blocked физическая дверь может законно удерживать выход:
  отпускать занятую поездку через препятствие нельзя.
- Ordinary completed journey и transient readiness delay проходят
  agenda → car reservation → board → drive → park → exit.
- Причина невидимости конкретного NPC в LIVE данным тестом не установлена.
  Кандидат ограничивает ожидание; не объявляет presentation проблему решённой.
