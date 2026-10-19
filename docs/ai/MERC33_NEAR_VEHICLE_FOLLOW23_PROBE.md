# Merc33 near-vehicle follow probe — 23 сентября 2026

READ-ONLY LIVE observation. Production не изменён; общие коллизии и радиусы
не ослаблялись. Исходный факт также сохранён в
`docs/ai/SQUAD_CATCHUP_TRANSPORT_LIVE23.md`.

## Наблюдение

После третьей LIVE поездки Kingswell машина остановлена в
`x=613.626275, z=82.400648, yaw=0.300029`, затем герой и три пассажира
завершили штатный E-exit. Все пять бойцов имели `bodyDepth=0`, четыре дошли
до своих follow positions. Merc33 остался с `moveReason=source_blocked`:

- merc33: `r=19.330072, c=149.531785`;
- short follow goal: `r=19.261728, c=150.300650`;
- hero: `r=19.921885, c=150.109520`;
- машина в source units: `r=20.097719, c=149.664945`.

Расстояния: merc33→goal `3.1648 м`, merc33→hero `3.3909 м`,
merc33→car center `3.1944 м`, hero→car center `1.9601 м`, goal→car center
`4.3060 м`. Поэтому неподвижная машина рядом с коротким follow corridor —
правдоподобный blocker, но один snapshot не доказывает, что именно её hull
отклоняет каждый пробный шаг. Это не плохой catch-up teleport: merc33 уже
физически вышел, оказался на проходимой точке с `bodyDepth=0` и остался
примерно в трёх метрах от героя.

## Что проверять в следующем LIVE окне

1. Сохранить тот же кадр до изменения позиции машины: записать все turn probes
   из `move()` и результат source `_npcPathPassable` по каждому короткому шагу.
2. Для отклонённой точки сравнить обычный source query и диагностический query
   с ignore только exact vehicle ID. Второй запрос read-only; он не должен
   управлять движением.
3. Убрать машину штатным проездом, не изменяя merc33/goal, и проверить,
   возобновится ли движение на следующем обновлении follow goal.
4. Если блок остаётся, записать точный static body/surface blocker и соседних
   бойцов. `source_blocked` возникает до crew/native checks, поэтому
   `crew_blocked` и `native_blocked` в этом snapshot не подтверждены.

Минимальный production fix пока не предлагается. Нельзя уменьшать нулевой или
общий pedestrian collision radius, пропускать source collision либо переносить
merc33 к цели: эти действия скрыли бы фактический blocker и могли бы вернуть
пересечения с машиной. Допустимое дальнейшее исправление зависит от нового
probe: либо корректный exact-own/recent-exit vehicle ignore в коротком corridor,
либо обновление follow goal вокруг подтверждённого неподвижного hull. Оба
варианта требуют отдельной actual-source regression и сравнения с обычными
стенами, чужими машинами и остальными бойцами.

Пределы: один LIVE snapshot после выхода, без повторного движения машины и без
per-probe blocker identity. Это остаточная диагностическая задача, а не провал
принятого board→drive→exit/reboard transport цикла.
