# Живой город — состояние одной сцены (14.10.2026)

Проект: `outputs/dsh_living_city_01/game`, сцена `res://scenes/main_city.tscn`.
Запуск обычный: `outputs/dsh_living_city_01/Играть_город.cmd`.
Всё ниже проверено headless-прогонами Godot 4.7.2 (`--headless --path <game> --import`, затем
`--headless --path <game> res://scenes/main_city.tscn -- <флаги>`), stderr = 0.

## Что уже подключено в сцену и работает

| подсистема | как включена | доказательство |
|---|---|---|
| 286 жителей, визиты shop/bank/hospital, навигация | базовая сцена | `CITY_BOOTSTRAP_READY`, `DSH_LIVES n=286` |
| Палаццо + C4 + стекло (единственное разрушаемое) | `main.gd` (`palazzo_host.gd`) | `PALAZZO_GEOMETRY`, release48-приёмка |
| Ближний бой (практика + контакт NPC) | `preview_melee_enabled = true` | `MELEE_PRACTICE_STATUS ground_practice_no_combat_targets` |
| Миникарта Walk (аддон + хост) | `preview_minimap_enabled = true` | `DSH_MINIMAP ready=true objects=234`, `MINIMAP_STATUS ready` |
| Разрушаемые ресторан/больница/банк (перенесены) | новые каталоги + инстанциаторы | `MODULAR_ISO_SUMMARY ok=3/3 total_prepare_ms=320.7` |

## Новые флаги (все default = прежнее поведение)

- `--city-town=1` — **режим мини-городка**: в сцену ставятся только здания из keep-набора,
  остальные НЕ инстанцируются (данные блока, его SHA и все 75 строк не тронуты).
  `--city-town-keep=assetId,assetId,...` (по умолчанию
  `hospital,bank_small_shell_v1,gun_shop,print_shop,old_town_narrow_townhouse_v1`).
  Печатает `CITY_TOWN built=<n> skipped=<m> keep=...`.
- `--city-nav-pump-budget-us=N` / `--city-nav-pump-admits=N` — бюджет очереди маршрутов
  на шаг города (по умолчанию 4000 мкс / 8 допусков). Печатает `DSH_NAVPUMP`.
- `--city-daily-min-per-frame=N` — нижняя граница числа опрашиваемых жителей за шаг
  (по умолчанию `ceil(286/96) = 3`).
- `--city-door-free-entry=1` — «свободный вход»: коллизии ОТКРЫТОГО полотна двери
  выключаются, квадратная проверка занятости уступает капсульному свипу, полуширина
  коридора 0.81 → 0.95. Доказано на типографии: `DSH_DOORFREE leaf key=public parked=true shapes=2`.
- `--city-site-door-physics=1` — привод обеих створок больницы/банка на каждом шаге.
- `--city-resident-detail=1` — **обязателен**, чтобы печатались `DSH_LIVES` и `DSH_ECON`
  (по умолчанию подробная диагностика жителей выключена).

## Что доказано прогонами (14.10)

- Обычный город, 286 жителей: `activity=0`, `completed={"bank":0,"drive":0,"hospital":0,"shop":0,"walk":0}`,
  `path_pending≈91`, `ready/s≈2`, `wait_ms_p50≈5.6 с` — жители стоят, дела не завершаются.
- **Режим городка, 286 жителей**: `activity` до **205**, `completed walk=191`, `hz≈60`, ошибок 0.
  То есть снос зданий снял голод маршрутов, и жители дошли до фазы визита.
- Остаток: визиты не закрываются — `act_not_released≈200`, `act_stuck60≈138`,
  `completed bank/hospital/shop = 0`. Это следующая цель.
- Миникарта: `objects=234` = 75 зданий + 159 декора, сцена доходит до `city_ready=true`.

## Открытые задачи (по приоритету)

1. **Закрытие визита**: почему активность не освобождается (`npc_daily_life.gd` ACTIVITY,
   `npc_city_daily.gd` `_visit.step()` / `_finish_activity`) и `bank/hospital/shop` не растут.
   Ранее зафиксировано («вечный APPROACH»): `VISIT_HANG_FINDINGS.md` в рабочей папке сессии.
2. **Вход жителей в здания**: правки `--city-door-free-entry` готовы, но маршрут входа
   больницы/банка в живом прогоне ещё не исполнялся. Вне зоны помощника остались:
   `npc_city_world_policy.gd:12,170,683` (квадрат → `DoorOpen.capsule_sweep`),
   `npc_local_printshop_route.gd:271,292,297-300`, `npc_hospital_geometry.gd:221-234`,
   `npc_bank_geometry.gd:222-235`, `npc_daily_hospital_visit.gd:289-306`, `main.gd:619-620`.
3. **Расстановка разрушаемых зданий рядом** (палаццо + ресторан + больница + банк + оружейный
   + modular30): инстанциаторы готовы (`scripts/destruction/{restaurant,hospital_site,bank_site}`,
   `modular_buildings/`), подсказки координат — в `modular_buildings/PLACEMENT_HINTS.json`.
   `modular30_host.gd` в город не годится: он требует SHA блока палаццо `1523f52e…`,
   а город грузит `city_block.json` — подключать prefab через загрузчик, не через хост.
4. **Население живое**: все 286 должны постоянно что-то делать (траты, банк при нехватке денег).
   Экономика наблюдаема через `DSH_ECON` (`cash`, `bank`, `spent`, `conserved`, `completed`).

## Правила, которые нельзя нарушать

- `scripts/npc_visual/npc_visual_loader.gd` и `npc_float_color_bridge.gd` НЕ редактировать:
  их SHA запинены во всех 287 рецептах.
- Один писатель на файл. Перед правкой: `Get-Process | Where-Object { $_.ProcessName -match 'Godot' }`.
- Замеры — по одному (полный город ≈ 8–9 ГБ RAM при 15.9 ГБ всего).
- Любая правка: идемпотентно, бэкап в `outputs/dsh_living_city_01/patches/`,
  семантика за флагом, дефолт = прежнее поведение.
