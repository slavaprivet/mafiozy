# READY20: bank / beach / local interior final-death metadata

20 сентября 2026. Разрешённый NPClead19/Координатором20 source slice после
снятия freeze. Runtime edits только `world.html`; helper/lifecycle/actor/surface,
damage amount, recipients, protections, server authority и AI не менялись.

## Собственные world anchors

- `_hitBankGuard:9248`: добавлен необязательный `acceptedImpact`; окончательная
  dead/deadAt ветка:9286 сохраняет record с `_threeNpcEntityId(actual npc)`.
- `_hitBeachgoer:19341`: такой же optional impact; final:19349 получает
  **`npc_beach_<b.id>`**, совпадающий с реальным wrapper bridge ID.
- `_localBallisticTargets:37071`: `Object.freeze({weapon:firedWeapon})` один раз
  на сбор списка, передан bank:37081 и beach:37101 callbacks. Если оружие сменилось
  до попадания, запись всё равно относится к принятому firedWeapon этого shot.
- `_hitInteriorNpc` local final:62847: record из явно переданного weapon. Если
  legacy caller опустил аргумент, cause=unknown, несмотря на default currentWeapon.
  Все ранние authority/protected/pressure returns остались перед этой веткой.

Номера строк shared могут двигаться; имена функций и final branches устойчивы.
Legacy bank/beach calls без optional impact честно unknown. Новый melee routing
не добавлен; старые hit windows, confirm contexts и server ACK не изменялись.
Кровь продолжает свой прежний path, здесь её поля не исправлялись.

## Projection

Существующий `getDynamicEntities` deathRecord projector применяется и на улице,
и внутри: его npcSource выбирает `_buildingInt.npcs` / `_bankInt.npcs`. Поэтому
никакой второй NPC population не создан. Source record id совпадает с фактическим
общим actor ID, exact deathAt epoch проходит нормализатор.

Отдельный `getInteriorState` отдаёт raw string/index row.id и использует
`interior:<biz/type>:<id>` только как death-cache key. Этот payload не переименован,
record туда автоматически не клонируется с другой targetId. Если отдельный
потребитель этого payload понадобится, alias/identity надо подключать явно.

## Проверки

Все четыре source/contract suites: **22/22 PASS**, около422мс CPU:

`node --test assets/maps/city_rebuild_v1/test_npc_death_profile20.mjs assets/maps/city_rebuild_v1/test_npc_death_record20_source.mjs assets/maps/city_rebuild_v1/test_npc_fatal_channels20_audit.mjs assets/maps/city_rebuild_v1/test_npc_local_death_extension20.mjs`

Новый extension test исполняет actual `_localBallisticTargets` callbacks и actual
final functions. Bank/beach/interior × rifle/rpg, смена currentWeapon→taser,
точная immutable epoch/identity, legacy unknown, nonfatal damage и protected/
server-owned early return. Audit тест обновлён: новый producer больше не ожидает
отсутствия record; empire остаётся непокрытым.

`node test_world_walk_shots.mjs`: PASS. Inline world syntax и diff-check PASS.
Новый GPU run не проводился, производительность общей сцены не проверена.

CPU microbenchmark фактического target-list builder: 30 NPCS +8beach +4cityCops,
20 000 warmup,15×20 000 вызовов. Baseline — та же текущая функция с удалёнными
только новым capture/argument в памяти теста (production не откатывался).
p50/p95 до21.11/24.18 мкс, после20.01/21.77 мкс за список. Это шум порядка
микросекунд, **не заявка на ускорение**. Новый один frozen object на shot-list,
никаких per-frame actor scans сверх существующего списка. Record creation —
только в окончательной смерти; projection по-прежнему возвращает ту же ссылку.

## Отдельный обнаруженный defect АЗС — НЕ исправлен этим пакетом

Actual `_explodeGasStation` падает на `if(!bi.businessInteriorRaid)`:
**ReferenceError: bi is not defined**. В этой функции bi не объявлен. Воспроизводится
даже с пустыми NPCS/cityCops/_myGang/CARS. До ошибки уже выставлено
`gs._blastApplied=true`, поэтому повторный вызов рано возвращается и не завершает
`_saveGang`, car explosion tail и `triggerNpcPanic`.

Последний тест `gas station actual function throws ... (audit only)` в новом
extension suite сознательно подтверждает текущий defect, а НЕ правильное
поведение. После scoped исправления владелец АЗС должен заменить assertion на
успешное завершение и сохранение получателей урона. Root/19 уведомлены; сам взрыв
в этом пакете не менялся.

## Manifest на момент передачи

- `world.html`: SHA256 `ddda5bd2b6fbf642b13ab422cbf1329281fd4026d398b90cf063f2c0080a1b5b`
- Новый `test_npc_local_death_extension20.mjs`: `ac2e6a53095c4b0a82da5c4d586cafbe3e507152d0873074f234c85788f479a5`
- Обновлённый `test_npc_fatal_channels20_audit.mjs`: `a39def2213332a5871a22cd6b3a02e77093ca1b8a6b9b03ea40cbe0e8951ecd4`

Shared world может дальше изменяться другими авторами. City cop corpse,
empire/server ACK, mercenary downed и расширение blast recipients этим пакетом
не объявляются готовыми. Они перечислены в `NPC_FATAL_CHANNELS20_AUDIT.md`.
