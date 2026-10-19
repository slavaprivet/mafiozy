# Astra9 SeatRegistry — независимый source review

26 сентября 2026. Статус: **PROPOSAL / SOURCE_REVIEW_ONLY / GODOT_NOT_RUN / S07 NO_GO**.
Проверен полученный `outputs/astra21_a9_review/seat_registry.gd`, SHA256 `82e9afd8aca72ae0ad9d8c0a9aac9356d1a34b04da10e1ee63dc90f75b1286dc`, и `RECEIVED_MANIFEST.md`. Это computed local hash, не подтверждённый автором hash архивного оригинала. Полный package/vector/test/contract ещё не получен; сообщение обрезано сервером. Ни runtime, ни тесты, ни GPU не запускались и не изменялись.

## Что сохраняет текущий reducer

- `_busy` (`seat_registry.gd:64–69`) проверяет и occupant, и claim во всех креслах. Участник не может получить второе место даже на другом автомобиле; victim и attacker остаются отдельными refs при EXTRACTING. `board` переносит claim в occupant без сохранения второго claim (`223–229`).
- Vehicle generation проверяется до операций (`159–162`), actor generation — в `_actor` (`54–58`). Occupied actor ID нельзя повторно зарегистрировать. Token меняется на reserve/carjack/board/exit/settle с occupant, поэтому старые переходные команды не подходят новым token.
- Cancel RESERVED освобождает место; ENTERING/EXITING/EXTRACTING переводятся в RECOVERING без автоматического возврата/телепортации (`71–76,202–206`). `settle` требует отдельного trusted approval (`213–215,251–261`). После extract victim не восстанавливается при cancel.
- Death/disable отменяют driver authority и claim transition, но seated corpse остаётся occupant (`114–140`). Remove actor выдаёт DETACH; destroy/remove vehicle выдаёт DETACH каждому occupant и очищает seats. Это соответствует source разделению corpse/driver в `world.html:10486`, `32216`, `32285`.
- `driver` допускает только front_left, ACTIVE vehicle, OCCUPIED phase, живого/способного present actor и непросроченную drive lease (`266–272`). Seat occupancy самостоятельно не даёт право ехать.
- `allowed` — отдельный source-approved список: наличие четырёх seat anchors не открывает серверные места. Current source `world.html:32258–32263` явно закрывает rear seats; adapter `world_vehicle_player_access.mjs` сверяет receipt sourceCarId/seatId и явную presentation-ID замену.

## Findings и обязательные gates перед S07

### R1 — DETACH недостаточно определяет поколение машины / выдачу эффекта

`seat_registry.gd:78–82`: эффект содержит actor generation, но vehicle только строкой ID; отсутствуют vehicle generation, session, command seq и seat token. Если consumer отложит эффект destroy(V, gen1), затем V gen2 появится и тот же actor займёт его, старый DETACH нельзя отличить по собственным полям от актуального. Это не доказанный runtime bug — consumer ещё отсутствует, — но явный пробел контракта для асинхронной интеграции. Требуется либо generation/session/sequence envelope, либо документированное синхронное применение эффектов до любой следующей команды и before-source-rebind. Test: delayed old DETACH после vehicle reincarnation не снимает нового occupant; duplicate effects не исполняются дважды.

### R2 — lifetime capacity включает удалённые tombstones

`seat_registry.gd:103–110,114–124,143–157`: removed actor остаётся в `actors`, removed vehicle — в `vehicles`; ограничения 4096/256 считают все когда-либо зарегистрированные уникальные ID. Новые ID после 4096 полностью удалённых NPC получат CAPACITY при пустой сцене. Это допустимый bounded prototype, но не бесконечная городская симуляция со fresh-ID продавцами. Нужен явный lifetime-ID/reuse/generation контракт или безопасное retention правило с защитой от stale commands. Tests: 4097 distinct register/remove циклов; reuse того же ID с gen+1; старый gen не оживает. Простое удаление tombstone без защиты поколений не считается исправлением.

### R3 — revision/approval/clock остаются внешней authority

`seat_registry.gd:27–28,181–198,213–215`: `approved=true` — обычный bool; registry не хранит текущий source receipt, geometry/door revision или requester identity. ACTIVE `allowed` нельзя обновить отдельной командой при изменении source access. Это прямо объявленный author scope, не credential. Root должен сверять **каждую** approved enter/board/grant/exit/leave/extract/settle с текущими actor/car/seat/generation и физическим состоянием; reserve approval не может кэшироваться на весь переход. Driver lease действительна относительно `_data.now`, который меняется только через tick (`89–96`), а не wall clock. Задержка tick оставляет lease действующей. Нужны clock units/cadence и fail-closed source-revision gate. Tests: lock/access change после reserve, stale receipt после generation change, прекращение lease при остановке trusted clock/source, denied rear seats.

### R4 — стоимость команды и проверка времени

`seat_registry.gd:46`: вся data копируется глубоко на каждый admitted command; `_busy` дополнительно перебирает 4 × vehicles. Даже rejected command после valid envelope копирует состояние; `_seq` намеренно расходуется до reduce (`45`), что совпадает comment JS model. Это O(actors + 4×vehicles) allocation-heavy correctness prototype, не готовый per-frame host. `snapshot` также deep copy. До S07 нужны actual Godot p50/p95 на сопоставимых 4096 actors/256 vehicles, tick/reserve/death/destroy burst и измерение rejected commands; author MODEL timings/claims не заменяют этот gate. Retained tombstones увеличивают стоимость даже в пустой текущей сцене.

## GDScript parse / parity

**NOT_PARSED / NOT_RUN.** Source review не выдаёт parse PASS и не нашёл оснований объявлять подтверждённую синтаксическую ошибку. Обязательный реальный Godot4.7.2 этап: загрузка script, instantiation, ASCII/non-ASCII `_id` (включая `for ch in x`), Variant short-circuit type guards, `_integer` для bool/String/NaN/Infinity/целого float, branch scopes и Dictionary member mutation/alias isolation. Особенно сравнить Godot numeric equality с JS strict equality в carjack victim token (`192`) и session guard (`41`); один MODEL replay не доказывает одинаковые допустимые входы.

Полные recovered vectors должны покрывать malformed command каждого arity, snapshot/effects mutation isolation, denied envelope sequence progression, reserve expiry, expiry ENTERING/EXTRACTING → RECOVERING, death/remove обеих ролей на каждой фазе, extract→cancel без victim resurrection, vehicle generation replacement и unique-actor invariant после каждой команды. Эти tests сейчас **TESTS_NEEDED**, не выполненные результаты.

## Приёмка

Полученный reducer пригоден для дальнейшего staged review после полного package и устранения/закрытия gates. Он не переносит physics, doors, feet, контактный захват, carjack animation, server ownership или persistence. В root runtime сейчас не подключать. Полный перенос и LIVE остаются OPEN.
