# Walk: повторная посадка блокируется после выхода

23 сентября 2026. Read-only production audit для Координатора20. Изменены
только этот отчёт и новый actual-function тест. Браузер не открывался.

## Доказанный дефект

В `assets/maps/city_rebuild_v1/walk_preview.mjs`, функция
`updateCarInteraction()` (исходная строка 930), `sourceVehicleAccess.poll()`
вызывается только если `sourceVehicleActive()` возвращает true.

Source завершает выход и становится inactive. Последнее состояние adapter
остаётся `operation.pending=true`, потому что итоговый source receipt ещё
не прочитан. `world_vehicle_player_access.mjs:findEntry()` на pending
возвращает null для любой машины. Пешая ветка host больше не вызывает poll.
Игрок может ходить, но следующая посадка не появляется до reload.
Та же последовательность возникает при прерывании посадки.

## Проверка реального кода

`assets/maps/city_rebuild_v1/test_vehicle_entry_pending23_audit.mjs` выполняет:

- actual `NPC_VEHICLE_HIJACK_START..END` из текущего `world.html`;
- настоящий `createWorldVehiclePlayerAccess`, без разрешающей подмены adapter;
- actual `updateCarInteraction()` из текущего Walk, с простыми заменами DOM;
- offline exit, online exit с успешным ACK, interrupted entry.

Во всех трёх случаях после 30 пеших кадров текущий host оставляет pending=true
и `findEntry=null`. Сам source уже завершил операцию. Обычный вызов poll читает
реальное решение и возвращает допустимую дверь.

In-memory кандидат: перенести существующий единственный poll на начало
`updateCarInteraction`, перед проверкой active. Во всех 3 случаях pending=false,
дверь снова доступна. Никакие lock/occupied/authority/HP/seat правила не меняются.
Нужен scoped production patch от владельца Walk/transport; здесь он не внесён.

Команды:

```
node assets/maps/city_rebuild_v1/test_vehicle_entry_pending23_audit.mjs
node assets/maps/city_rebuild_v1/test_vehicle_entry_pending23_audit.mjs --require-fixed
```

Первая показывает доказанный baseline и кандидат; вторая после интеграции
требует, чтобы production host сам исправлял все три сценария.

## Другие установленные ограничения, не объявленные дефектами

Source `_getWalkVehicleAccess()` (world.html:31923) разрешает обычной source
машине только front_left. Передний пассажир доступен лишь у quest car с другим
driver_uid, задние два места всегда server-seat-unavailable. В fleet/local
режиме доступны четыре авторские двери. Нельзя молча расширять права source
машин или обещать полный four-seat server контракт на основании local теста.

`frame()` передаёт `dt=min(rawDt,.04)` в `updateCarInteraction`; hold .3 секунды
поэтому требует 8 кадров. При 7 FPS это примерно 1.14 секунды реального времени,
при 60 FPS — около .3 секунды. Это возможное ощущение отказа на коротком E в
лагающей сцене, но не причина вечной блокировки. Отдельно менять общую физику
или frame dt ради этого не следует.

## LIVE после интеграции

В единственной согласованной игре: подойти к водительской двери, удержать E,
сесть, остановиться, выйти, повторно сесть в ту же машину и затем в другую.
Отдельно прервать source посадку и повторить. Проверить сохранение запрета
занятых/запертых мест и отсутствие самовольного получения водительских прав.
CPU PASS не заменяет этот прогон; производительность общей сцены не проверена.
