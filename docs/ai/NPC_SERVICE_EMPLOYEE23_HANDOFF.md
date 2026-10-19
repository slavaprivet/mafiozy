# Живые сотрудники, кассы и возвращение из подсобки — isolated candidate

23 сентября2026, Художник21. Прямые поручения пользователя и поздняя поправка
про техническую дверь сохранены в NPC_PERSONAL_ECONOMY_NEEDS_20260923.md.
Координатор20 разрешил isolated employee lifecycle/actual-site audit и узкий
план подключения. Узкий passive commerce/geometry pilot разрешён; source activation отдельно согласуется с владельцем world/Walk Координатором20.

## Что готово отдельно

`npc_service_employee23_candidate.mjs` не создаёт NPC/деньги/товар, не двигает
корни или двери и не меняет HP/видимость. Он получает подтверждённый site layout
и постоянный source actor record, выдаёт намерения существующим исполнителям.

`createServiceEmployee23` требует building/station/room/door IDs, site revision,
employee ID/generation и пять world anchors: spawn, doorInside, doorOutside,
work, customer. Host validateLayout обязан проверить реальные геометрию,
коллизии, связность, рабочую/клиентскую сторону стойки и скрытый spawn в подсобке.
Возврат true в synthetic unit fixture не считается проверкой здания.

`stepServiceEmployee23`: подтверждённая смерть задаёт dueAt=deadAt+60000.
Cull/JSON/повторный кадр не меняют таймер. Положительный HP той же generation
не оживляет сотрудника. После срока закрытая безопасная подсобка даёт один
стабильный requestId на generation+1; повторные ticks ждут подтверждения.
Позднее5с ожидание явно просит подтверждение, не создаёт второго NPC.
Accepted spawn receipt обязан соответствовать сотруднику/зданию/revision,
requestId, новой generation, сроку и позиции внутри подсобки. Host проверяет
его authority. Идемпотентный повтор уже принятого receipt не запускает respawn.

Далее сотрудник физически приходит к внутренней стороне двери → требует
открыть её → ждёт реального fraction≥.95 → идёт наружу → ждёт свободной дуги
закрывания → закрывает дверь → возвращается к кассе. Намерение walk требует
existing swept executor. Только фактическая позиция продвигает стадии; helper
не считает запрос движения прибытием. Для двери нужен setter exact ID/state,
а не повторяющийся toggle. Door sweep должен учитывать всех живых акторов,
не только hero. Текущий interior door API защищает одну переданную капсулу:
адаптер динамического населения ещё предстоит согласовать.

Паника/бой/арест/медицина/обращение в полицию уступают существующим владельцам
поведения. Мирный работник возвращается на своё место, не принимает agenda
обычного гуляющего жителя. Его source actor должен быть обычным поражаемым NPC
с HP/crime/police hooks; постоянная stationary-service роль не invulnerable.

`serviceEligibility23` требует свежий source tick, живого сотрудника правильной
generation у рабочего места и живого покупателя у клиентского якоря с existing
service slot/visit. Проверку повторяют ВНУТРИ атомарной покупки непосредственно
перед списанием/выдачей товара. Ранее выданная eligibility не разрешает платёж
после смерти, ухода или замены продавца. Already committed receipt до смерти
потребляет ledger один раз; новые деньги/товар по позднему ответу не выдаются.

## Проверено / ограничения

`node test_npc_service_employee23.mjs`:43 contract checks PASS, включая смерть,
60с, cull/JSON, wrong building/generation/timestamp/position, duplicate receipt,
opening/blocked walk/closing sweep, сохранность source actor, crime holds,
покупателя вне кассы, смерть продавца между quote/commit и старый труп.
Координаты этих тестов synthetic. Actor renderer/animations не подключены.
75 работающих сотрудников,50 warm+400 measured batches: CPU baseline trivial
record read p50/p95 .0021/.0024мс; candidate step p50/p95 .0205/.0823мс.
Только стоимость pure helper с O(1) injected callbacks, без моделей/геометрии/
маршрутов/проверок authority. Вызывать через существующий source cadence,
не вводить дополнительный глобальный renderer update по всему населению.
**Производительность общей сцены не проверена.** GPU не запускался.

## Actual-site read-only audit

`outputs/npc_service_sites23_readonly.json/.mjs` загружает реальные GLB,
действующие interior plans и static collision fixture для четырёх зданий:

- `REBUILD-VISUAL-print_shop-001`: stockroom на0этаже,6 проверенных свободных
  capsule candidates (.18source cell=.738м radius), но проход склада без двери.
- `REBUILD-VISUAL-gun_shop-001`: stockroom на0этаже,7 таких candidates,
  тоже нет полотна двери склада.
- `REBUILD-VISUAL-pawnshop-001`: stockroom на1этаже; cashier room на0этаже.
  Полный stairs/staff return маршрут ещё не проверен.
- `REBUILD-VISUAL-hospital-001`: treatment rooms, нет stockroom/служебной двери.

Existing display counters/reception часто поставлены у стены. Точка продавца
«сзади стойки» без геометрической проверки может попасть в стену: нельзя вывести
work/customer anchors просто из центра furniture bounds. Existing print_shop
не имеет подходящей кассы в публичном зале. Нужна scoped interior доработка.
Ни один кандидат пока НЕ certified hidden-spawn/work layout. Collision-free
capsule не доказывает визуальную скрытость, доступность всей дороги или LIVE.
Binding/transform всех13 текущих instances этих4 asset types сравнены с
buildings_placement.v1.json: совпадают с геометрическим snapshot fixture.

## Узкий первый integration slice после scope release

1. Типография: существующий ground stockroom, opaque служебная дверь с collider,
   реальные spawn/inside/outside/work/customer anchors и небольшая касса.
   Сохранить существующие стены/лестницы/мебель/двери и instance identity.
2. Один постоянный продавец через действующий NPC actor/health/crime pipeline,
   роль cashier, короткое idle/обращение к клиенту/выдача газеты. Никакого второго
   legacy `_spawnCashierAt` — он принадлежит текущему robbery сценарию.
3. Existing resident route/physical visit ведёт к customer anchor; existing
   reservation ограничивает обслуживание одним покупателем. Очередь и подходы
   не занимают служебный door sweep или обычный вход.
4. Existing commerce остаётся владельцем одного session cash/inventory debit.
   Needs mirror потребляет его receipt синхронно до следующего choose. На commit
   повторить seller/customer/slot/stock checks. Если receipt задержан, применять
   доказанный completed-before-cancellation контракт или authoritative sync.
5. Смерть во время обслуживания прерывает неоплаченный заказ, возвращение только
   через подсобку после60с с новой source generation. Старые wounds/receipts/HP
   трупа не переносятся. Старый труп принадлежит обычному corpse lifecycle.
6. Вариативность needs запускается existing decision событиями; минимальная
   длительность обычных work/rest/leisure задаётся реальным исполнителем,
   не фиктивными instant activity-complete receipts каждый кадр.
7. Local preview явно session. Near bank остаётся unsupported до finite ledger
   и реального executor. Hospital связывается только с actual accepted source
   treatment; receipt/snapshot порядок проверен в needs candidate. Никаких
   присвоений HP по proximity или заявлений о готовом online banking.
8. CPU actual NPC+building+dynamics, затем согласованный root LIVE: продавец
   видим, покупатель доходит, обе анимации совпадают, единственный платёж,
   смерть блокирует продажу, сотрудник возвращается через дверь, p50/p95/calls.

Дальше распространить room/station contract на остальные здания по прямому
поручению пользователя. Этот handoff не объявляет данный slice реализованным.

## Final review23

Independent reviewer4/4 actual-call checks PASS. Duplicate birth receipt compares
stable semantic fields independent of JSON key order and reverifies authority.
Verified birth followed by verified death before ACK delivery advances generation
and starts its own60s timer without reviving corpse; old-generation death rejected.
First physical pilot: NPC_STATIONARY_SERVICE_PILOT23_HANDOFF.md. Actual GLB/full
capsules/door/counter/10 staff+customer cycles PASS. Source employee actor,
hidden camera-safe spawn, renderer and LIVE/FPS remain unconnected/unverified.
