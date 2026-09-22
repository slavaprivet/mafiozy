# Автомобили — продолжение 3, 23 сентября 2026

## Новый приоритет — транспорт банды

Пользователь через coordinator20 переключил на squad boarding/free seats/
ride/exit/fire. Trip17 test-only передан в
`docs/ai/TRANSPORT_TRIP17_LIFECYCLE23_PAUSED.md`: actual worker READY1763,
затем approach-blocked release, no teleport, slot/registry освобождены;
полная requested matrix не завершена. Runtimefreeze сохраняется до rootSHA.
Общий mercworld не редактировать до точного lock; safeplacement/teleport у child.

## QA history candidate — runtime freeze

`docs/ai/TRANSPORT_LANE_QA23_CANDIDATE_HANDOFF.md`: готов неприменённый кандидат
истории первого actual lane rejection до перезаписи trace. Только npcqa/
npctransportqa, max16, exact validated shape без новых geometrycalls, штатный
JSON download. 18 actual producer/cache/roundtrip checks PASS; five-file patch
и SHA256 manifest в outputs/transport_lane_qa23_candidate*. Runtime НЕ менялся.
Применение только после нового опубликованного root SHA и сверки кандидата.

## После общего reload — read-only аудит

`docs/ai/TRANSPORT_TRIP17_RETRY23_AUDIT.md`: выбран реальный resident2/car17.
В LIVE125260ms: planning52.007s, текущий fallback request лишь2.1727s,
expanded7/pending — не terminal failure. Actual producer audit: один NPC/одна
поездка может породить48failed jobs;100polls одного retainedjob даютfailed1.
Exactfrom — perpendicular bay1 woodland_crosswing; static с двумя явно
неподтверждёнными LIVE профилями: exit645/lane1763READY, fallbackblocked11.
Исходная LIVE lane-rejection причина/shape/lotIds ещё отсутствуют. Точный
следующий capture-сценарий сохранён; runtime после reload НЕ расширялся.

## Результат первого scoped patch

Второй patch по свежему LIVE export: `docs/ai/TRANSPORT_EXIT_RESUME23_HANDOFF.md`.
Точная поза car18 — середина авторского reverse exit. Исправлен отказ
`parking_exit_unavailable` при его продолжении: теперь 43 оставшиеся точки,
full hull + gear + route ID сохранены. Actual regression FAIL→PASS, начало/
середина/конец/барьер/чужая позиция проверены. Подробности и пределы — в передаче.
Полный actual-source async цикл с этой точной стартовой позы: PASS287.336м,
подход/посадка/reverseвыезд/поездка/парковка/выход/визит/следующеезанятие.
Оба transport patches READY для единого reload координатора20; LIVE ещё нет.

Передача: `docs/ai/TRANSPORT_PARKING_LEASE23_HANDOFF.md`.
Исправлена потерянная бронь парковки при истечении lease и перестроении
маршрута; actual source regression до FAIL / после PASS. Геометрические циклы
248.413 м и 901.275 м (async worker + остановка перед другой машиной) PASS.
World/helper изменены только в `_civilianTripMaintainLane`. LIVE у координатора20,
off-road причина отдельно не установлена; запрошены отсутствующие route diagnostics.
Производительность общей сцены не проверена. Подробные цифры и ограничения —
в передаче выше. Ниже исходное поручение, сохранено для продолжения.

Пользователь попросил заменить зависшие Автомобили — продолжение2
(01a0cb0a-d013-79b1-a979-1612fdaa27bc). Старую задачу архивировали, не будить.
Это чистая задача с короткой передачей, не fork огромной истории.

Общий каталог C:/Users/Слава/Desktop/Мафиози. Main31f8ea6c6e52c44e1c545b1fecef843355415c94
опубликован координатором20 (01a0bc08-cb3e-7181-be11-a53aaee54535).
Работать прямо с текущей общей сборкой, не reset/clean/stash/add-all.
Читать актуальную шапку COORDINATOR_20_MEMORY.md, NPC19_TEAM_BOARD.md,
AMBULANCE_LOADING_OWNERSHIP20.md, NPC_VEHICLE_DOOR_FLEET20.md,
VEHICLE_ENTRY23_READONLY_AUDIT.md. Исторические рекомендации сверять с кодом.

Первая конкретная задача: один end-to-end NPC trip: подход к машине →
посадка → реальное движение → парковка → выход → следующее занятие.
В root actual export .git/ai-pipeline-local/live23/npc-inspection-checkpoint23.json
у car4 startBlocked off-road, 27 jobs/1 completed/20failed. Позднее LIVE:
64jobs/5completed/180failed, local_vehicle_23 startBlocked off-road
(r14.78486 c153.69443) и pending ambulance. Это счётчики, не доказательство
конкретной причины. Разобрать actual parking access/route producer и lifecycle,
выбрать один воспроизводимый отказ, узко исправить и измерить стоимость.
Не обходить коллизии, не телепортировать машину и не выдавать дорогу на карте
за подключённый AI. Сохранять владельцев, места в машине, source IDs.

Посадка/выход игрока — удержание E0.3с, четыре двери/места, левый руль.
Root исправил poll sourceVehicleAccess перед active-gate: pending после
exit/interrupt больше не застревает; CPU3casesPASS, LIVE цикл ещё требуется.
Holdclock23 отдельный кандидат не интегрирован. Astra6 пакет door/boarding
у Проверщика2 — сначала согласовать пересечение.

Твои файлы: civilian_parking_trip_source.js и соответствующий world block,
npc_vehicle_hijack_source.js, ambulance_transport.js, vehicle access/pose,
native driving/parking routing. Перед общим world/walk edit — сообщить root
точный блок. Не переписывать общие файлы целиком и не трогать чужие hunks.

Координатор сейчас владеет water-follow и moving intimidation (уже WIP),
mercenary_world/core/pose, телефон его субагент. Художник21 — NPC agenda/nav.
Весь perf и8Астра — Проверщик ЧАТОВ2 01a0bbdc-edb1-7cc3-9cda-1160f3bc057b;
не дублировать optimization diff. Новую игровую вкладку не открывать:
единственная18538 у root. Согласовать конкретный LIVE сценарий и дождаться
его evidence, параллельно проводить actual source regression.

Первое сообщение: коротко подтвердить старт и назвать выбранный bounded
дефект/файлы. При технической блокировке сразу сообщить её root. После
каждого patch сохранять handoff: механизм, проверки, CPU стоимость,
LIVE ограничения. Не объявлять город живым без настоящего браузерного прогона.
