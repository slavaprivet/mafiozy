# Осмысленный маршрут гражданского

2026-09-09. Владелец: Художник 14. Изменения в существующих source routines `world.html`, отдельная проверка `test_civilian_purposeful_plan.mjs`. Второй список гражданских, симулятор или таймер не создавался.

У мирных обычных жителей `resident_*` сохраняется `_civilianPlan`: `seek_shop → walk_to_shop → entering → browsing → walk_to_bench → rest → seek_shop`. Дверь выбирается стабильно по ID и циклу из `_residentBuildingDoors`, сохраняется при перепланировании. До двери идёт обычный физический маршрут. Последний отрезок к точному якорю проверяется `_npcPathPassable`; одного центра тайла недостаточно. У двери выдерживается открытие 420 мс, затем используются прежние `_residentEnterBuilding`/`RESIDENTS_INDOORS` и существующий выход через дверь.

`browsing` — пока состояние существующего скрытого indoor-жителя. Оно не является проверенной прогулкой по полкам в видимой комнате. Дверной source переход и ожидание сохранены; полноценное представление внутри магазина требует host interior binding.

После выхода выбирается настоящая скамейка. Одна скамейка резервируется одному исходному NPC; точка подхода находится в 0,6 м перед ней. Сам NPC идёт к подходу, без телепортации к seat. Время отдыха 6–12 секунд, затем следующий цикл. Резервации имеют срок и освобождаются при завершении, пропаже места или прерывании.

Bridge `setWalkCivilianPlaces({benches,buildings})`:

- `benches`: `{id,r,c,yaw,seatWorldY}`, стабильный ID реального объекта, r/c в native source units, yaw в радианах, абсолютная высота сиденья в world метрах.
- `buildings`: `{id,label}`, принимаются только совпадающие с настоящим door.id/sourceId. Геометрия не создаёт новых source дверей.
- Без registered benches берутся существующие `_beachDecor` с kind modern_bench; никакой случайной точки вместо скамейки.

Snapshot отдаёт `routinePlan:{phase,cycle,doorId,benchId,since,until}` и `seat:{id,r,c,yaw,height,phase:'sit',since}`. `height` — абсолютная world высота. Host использует seat для посадки модели, не меняет source маршрут и право собственности.

Паника, смерть, медицинское состояние, оглушение, арест, бой, помощь и разговор прерывают план. Именные боссы, гвардия, бандиты, empire crew/guards и специальные source роли не включаются. Захват и собственность не менялись.

## Автомобили — проверенный недостающий стык

Текущие `_parkingNpcs` появляются от припаркованного `CARS`, идут по прямой к точке, возвращаются и удаляются. Машина всё время остаётся parked. Это не поездка.

Parking-источники теперь включены в source 3D NPC snapshot collector через `_threeParkingNpcView`. Используется существующий объект человека и `_actionRef`; ID привязан к исходному объекту через уже действующий `_threeNpcEntityId`, не к индексу массива. При удалении соседнего человека ID остаётся тем же, новая source-сущность получает новый ID. Если объект уже есть в обычном NPC source, повторно не добавляется. Native target resolver также возвращает именно исходный parking-объект.

Поля snapshot: `parkingState`, `parkingCarId` (существующий render ID автомобиля, null после удаления/угона/разрушения), `parkingEntryProgress` (текущий source getting_in 400 мс), `visibilityAlpha` (прежнее затухание последних 1,5 сек). Walking_to/returning объявляют движение, idle_at/getting_in стоят. Sitting и истёкший life не показываются; после source удаления исчезает тот же actor. Это экспорт исходного lifecycle; он не добавляет поездку, новую машину или анимацию посадки сам по себе.

`_assignCarGoal`, `_planCarRoute`, `_updateCarRouteDirection`, `updateCars` уже обслуживают дорожные поездки. Но `_planCarRoute` отвергает parked; moving traffic допускается только на road/bridge AMBIENT_TRAFFIC, парковочные площадки не являются первой полосой. Нужен проверяемый unparking connector от конкретного слота до направленного дорожного узла и возвращение к реальному слоту, с сохранением car ref, owner/hijack checks, дверей и collision. Простое снятие parked отправит кузов в recovery/recycle и не должно выдаваться за поездку. Эти механики не переписаны в рамках пешеходного плана.

Проверки: actual-source VM `test_civilian_purposeful_plan.mjs` и `test_parking_npc_snapshot.mjs`; существующие NPC life system, incoming threat/traffic и world walk gateway — PASS. Живую привязку renderer anchors/посадки проверяет основной host-владелец.
