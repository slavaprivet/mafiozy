# NPC blocked-route lifetime — 23 сентября 2026

READY, применено по точному разрешению Координатора20 до checkpoint.
Дальнейшие production-правки транспорта заморожены.

## Дефект и исправление

`_civilianTripTickCar` при длительном физическом препятствии переводил поездку
из drive в planning и удалял `car._civilianNativePlan`, не отменяя lane job.
Потерянный requestId нельзя было очистить даже при последующем завершении
поездки. Старый ready result оставался до вытеснения или TTL (по умолчанию
64 результата, 300 секунд), занимая место других поездок.

Добавлен один вызов `_civilianTripCancelLane(car._civilianNativePlan)` перед
удалением плана, строго в blocked-replan branch. Два одинаковых изменения:

- `assets/maps/city_rebuild_v1/civilian_parking_trip_source.js`
- `world.html`, зеркало `_civilianTripTickCar`

Seat ownership, squad transport, физика машины, collision clearance, позы,
road controls и сроки ожидания не изменены. Это исправление ограниченной
утечки реестра, не доказательство устранения всех LIVE остановок NPC.

## Проверка

`assets/maps/city_rebuild_v1/test_transport_blocked_route_lifetime23.mjs`
исполняет actual source TickCar и настоящий `createLaneRouteJobs`. Пешеход
физически блокирует source sweep, машина остаётся на месте, после 12 секунд
срабатывает штатное перестроение. Worker отвечает детерминированным маршрутом:
проверяется lifetime, а не достоверность авторской дорожной геометрии.

- Старый HEAD helper проваливает новый invariant: cancel count 0 вместо 1.
- До исправления abandoned route остаётся ready после полного release.
- После исправления cancel ровно один, включая последующий release;
  abandoned route отсутствует, другая ready поездка сохраняется.
- При capacity 2 добавление третьей поездки до исправления вытесняет более
  старый живой маршрут из-за orphan; после исправления он остаётся ready.
- `test_civilian_parking_lease23.mjs` PASS.
- `test_civilian_route_progress_controls.mjs` PASS.
- Синтаксис helper PASS; функция TickCar в helper/world совпадает полностью.

Отчёты: `outputs/transport_blocked_route_lifetime23_baseline.json` и
`outputs/transport_blocked_route_lifetime23_fixed.json`.
Новый вызов выполняется один раз при отказе, не на каждом кадре; удаляет
существующие записи Map реестра. **Производительность общей сцены не проверена**:
LIVE/GPU замер и итоговый checkpoint принадлежат Координатору20.

## Другие read-only результаты этого аудита

`audit_npc_parking_egress23.mjs`: у compact sedan все 59 мест pinned authored
static fixture имеют clear car hull и driver exit. Гипотеза постоянной
статической блокировки двери назначения не подтвердилась. Это не весь LIVE
город с движущимися машинами, железной дорогой и текущим streaming.

Trip17: дополнительный `--approach-audit` показывает исходного resident2
внутри blocked static geometry fixture; первый шаг и все пять body probes
запрещены даже с own-vehicle ignore. Штатный approach-blocked release чистит
реестр/бронь. Это не доказанный дефект route lifetime и не повод обходить
коллизии; фактический LIVE car profile прошлого capture неизвестен.

Squad transport ранее принят Координатором20 в LIVE: три разных пассажирских
места, 17.7896 м движения, peak 14.04 м/с, три физических выхода по E .7 с и
повторная посадка, Surface errors 0. Его evidence —
`docs/ai/SQUAD_CATCHUP_TRANSPORT_LIVE23.md`. Этот новый fix пассажиров не меняет.
