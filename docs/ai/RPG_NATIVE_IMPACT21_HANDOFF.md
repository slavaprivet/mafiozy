# RPG: native impact → existing source damage

21 сентября 2026. Координатор20, source scope `rpg_source_impact21`.
Статус: IMPLEMENTED + CPU TESTED. LIVE/GPU — Художник19, здесь не выполнены.

## Исправленный путь

В `world.html` принятый `fireWalkShot` с `nativeRpgImpact:true` создаёт один
неизменяемый `ctx.rpgFlight` внутри существующего pending shot. Сохранены точные
muzzle XYZ (метры), конечные angle/pitch после convergence/spread, source range,
shot time, weapon, remote target snapshot и ссылки текущего bank/building space.
В receipt добавлены `nativeRpgImpact`, `pitch`; `range` остаётся в source tiles.

Такой RPG не обрезается старой 2D сеткой и не назначает старый таймер взрыва.
Его dispatch идёт до direct gun handlers бензоколонки и машины. Отдельная
native collision теперь должна прийти через bridge `impactWalkRpg({shotId,
point:{x,y,z}})`. Root подключает вызов к `weapon_effects.mjs`, включая endpoint
при исчерпании дальности. Обычный 2D RPG и старые Walk callers без opt-in
сохраняют прежний путь.

Bridge проверяет существующий принятый RPG, отсутствие повторного impact,
возраст 0–15000 ms, тот же source space, конечные XYZ, дальность <= range×4.1
+0.1 m, направление вперёд >=−0.01 m и отклонение от луча <=0.08 m + distance×1e−5.
Некорректная заявка не меняет HP и не расходует flight. Принятая расходует его
до вызова resolver, поэтому исключение/повтор не вызывает второй взрыв.
`_walkShotContext` временно очищен для полного списка local area recipients;
контекст и `_authoritativeShotId` восстановлены в `finally`.

Удержание pending receipts ограничено 512 записями, TTL 15 s. Операций на кадр
нет: проверка/очистка выполняется только при выстреле или сообщении impact.

## Authority и неизменённые ограничения

- Местные патроны списываются прежним `fire()` при выстреле. Authenticated
  `_spendWeaponRound` лишь предсказывает: один существующий server hit claim
  либо `weapon_fire` остаётся на impact. Новый серверный launch контракт здесь
  не выдуман. При потере/истечении native callback server launch accounting
  по-прежнему отсутствует; это отдельная открытая задача.
- Данные damage/radius из impact не принимаются. Используются старый RPG
  профиль, falloff, local HP handlers и server-authoritative remote claim.
- Список server targets не расширен: remote остаётся одной принятой целью.
  Server-owned HP локально не записывается.
- Существующий `_spawnRpgExplosion` считает radius/falloff в плоскости R/C;
  Y проверяет траекторию, но не добавляет новый вертикальный blast/occlusion
  контракт. Это не доказательство корректной защиты этажами/стенами.
- Старые поздние critical globals не менялись. Синхронный anchored bullet
  receipt для каждого splash victim не создан; HP и визуальные реакции —
  отдельные проверки. Medical survivor обязан корректно отреагировать в
  следующем пакете владельца реакций.
- C4/автомобильные helper и Citycop/bleedout metadata не изменены.

## Проверки

`test_rpg_native_impact21.mjs`: 8/8 обычных actual-function сценариев PASS.
Реальные `_fireRpgRound`, bridge methods, `_walkImpactRpg`, `_spawnRpgExplosion`,
`_localBallisticTargets`, `hitNpc`, accounting helpers и блоки production `fire`:

- Native floor point без NPC contact уменьшает HP рядом, без legacy timer.
- Direct-contact constraint снят во время area damage: сосед тоже повреждён.
- Unknown/non-RPG/duplicate, NaN, отсутствующая точка, off-axis/backwards,
  слишком далеко, expiry/reversed clock и смена scene не меняют HP.
- Максимальная дальность и ровно 15 s приняты; mutable request/remote данные
  не меняют frozen flight; caller damage/radius игнорируются.
- Ошибка resolver не разрешает replay, контексты восстановлены.
- Authenticated local hit даёт один `weapon_fire`; remote даёт один `cop_shoot`,
  без лишнего запуска или второго server claim.
- Неправильный muzzle/pitch отклонён до ammo admission; карта ограничена512.
- Реальные fire-блоки пропускают legacy wall/pump/car только при native opt-in.

`test_rpg_source_route20_audit.mjs`: прежние 3/3 сценария PASS (2D parity).
Source death/blast record + gas station + blast presentation: 19/19 PASS.
`python check_world.py`: все семь inline script blocks PASS. Diff check PASS.

CPU cost, тот же actual resolver и 64 local recipients, 30 прогревов +130
измерений каждого пути, порядок чередуется, координаты/HP сбрасываются:

| Путь | p50 ms | p95 ms |
|---|---:|---:|
| Прямой прежний source resolver | 0.3724 | 0.5397 |
| Тот же resolver через новый bridge | 0.3788 | 0.5168 |

Небольшая стоимость проверки, шум p95 не является ускорением сцены. Повтор:
`RPG_IMPACT_COST=1` для нового test. Производительность общей сцены не проверена.

Приёмка19: одна текущая игра после общего reload, RPG в землю возле NPC,
прямое попадание, возле машины/колонки, максимум дальности, visible injury/death,
один взрыв/списание, сравнимые frame p50/p95. Не объявлять весь blast pipeline
готовым только по этим CPU результатам.
