# АЗС: минимальный fix20 — production READY

20 сентября 2026. После review Координатора20 и явного release19 exact patch
применён. Production gas+extension+source **12/12 PASS**, включая inline syntax.
Новый `test_gas_station20.mjs` больше не имеет candidate bypass и всегда
исполняет actual world. Старый audit assertion, требовавший ReferenceError,
заменён проверкой успешного однократного завершения. World scope освобождён.

SHA256 world на передаче: `b033bb03634e8259034fdb27c1e363c4099ccd126cc76acd4d3bd6b52c17fec8`;
`test_gas_station20.mjs`: `2fef8323afbede64cb83fe39a7b9bd429987b7533354caaa3718e914963a64fa`.
Ниже сохранены доказательство и история review.

## Доказанная причина и точный patch

`git log -S 'if(!bi.businessInteriorRaid)for (const gm of _myGang)' -- world.html`
находит commit **a0e6b1e**, `Add roster-backed interior business assaults`.
`git show a0e6b1e -- world.html` показывает конкретный hunk в
`_explodeGasStation`: существующий `for (const gm of _myGang)` был ошибочно
заменён на raid guard с `bi`. В parent commit `a0e6b1e^` исходный цикл без условия.
В функции АЗС нет ни параметра bi, ни локального объявления bi.

Предлагаемый runtime patch:

```diff
-  // During a property raid, only the server-assigned roster is materialized
-  // above. The general following crew must not duplicate unassigned fighters.
-  if(!bi.businessInteriorRaid)for (const gm of _myGang) {
+  for (const gm of _myGang) {
```

Другие backend comments в этой области не чистить попутно. Все строки damage,
falloff, recipient filters, `_saveGang`, CARS loop, panic остаются буквальными.
Не заменять на optional `bi?.` или `_buildingInt`: это вводило бы новое условие
подавления урона, которого в исходном поведении АЗС не было.

Ошибка уже воспроизведена actual source: ReferenceError после NPC/citycop damage,
с уже выставленным `_blastApplied=true`; retry рано возвращается и не доходит
до gang damage/save/car chain/panic.

## Prepared actual-source regression

Новый `test_gas_station20.mjs` по умолчанию исполняет **неизменённый production
source** и проверяет успешное поведение после fix. Во время freeze явный
`NPC_GAS20_CANDIDATE=1` заменяет только ошибочный guard внутри памяти теста.
Этот режим отмечен `REVIEW CANDIDATE`; не выдавать его за production PASS.

Review candidate: **2/2 PASS**, около131мс CPU. Сценарий использует настоящую
`_gasBlastDamageAt`, радиус6, damage105 в центре/53 на половине, zero на границе.
Проверяет прежние NPC/cop/gang recipients и исключения dead/downed/outside/null,
car radius5.2 inclusive и wreck/towed exclusions, gang save перед car chain,
выход из уничтоженной машины, финальный panic, `_blastApplied` идемпотентность,
непротекающую АЗС и уже мёртвого игрока. Damage handlers в fixture — spies,
так что тест проверяет вызовы/получателей и не объявляет end-to-end damage API.

После разрешения:

1. Применить ровно hunk выше.
2. Заменить прошлый audit assertion `gas station actual function throws...` в
   `test_npc_local_death_extension20.mjs` на успешное завершение либо убрать его
   в пользу нового подробного regression. Не оставлять тест, требующий bug.
3. Запустить новый тест **без** candidate env, source/extension suites и syntax.

Новых GPU вкладок/запусков нет. Это исправление source exception, а не переделка
взрывов или новые fatal producers. Общая производительность сцены не проверена.
