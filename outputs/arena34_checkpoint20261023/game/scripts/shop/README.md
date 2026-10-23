# Оружейная лавка (модуль торговли)

Локальная торговая механика живого города: продавец у оружейного магазина,
окно лавки с разделами, покупка со списанием, патроны в стволы, надеваемая
броня, расходники в рюкзаке и инвентарь.

## Включение и клавиши

| | |
|---|---|
| Флаг | `--city-player-shop=1` (уже добавлен в `outputs/dsh_living_city_01/Играть_город.cmd`) |
| `E` | «Поговорить» у продавца оружейного магазина |
| `P` | лавка в любом месте (песочница/проверка) |
| `I` | инвентарь |
| `Tab` | раздел в лавке, `Enter` — купить, `Esc` — закрыть |
| Без флага | поведение прежнее: продавца нет, арсенал выдаёт все стволы |

## Что где лежит

| файл | роль |
|---|---|
| `player_shop_catalog.gd` | читает и валидирует `res://data/player_shop.json` (цены, тексты, разделы) |
| `player_shop_wallet.gd` | единственный владелец денег: списание, возврат |
| `player_shop_state.gd` | транзакция покупки: доступность → списание → выдача → чек (идемпотентно) |
| `player_shop_inventory.gd` | рюкзак: расходники со счётчиками, надетый жилет, поглощение урона |
| `player_armor_visual.gd` | жилет поверх одежды, следует за костью груди |
| `player_shop_panel.gd` | окно лавки: разделы, слот-сетка, карточка, покупка |
| `player_inventory_panel.gd` | окно инвентаря: те же карточки |
| `player_shop_dialog.gd` | диалог продавца и выбор «Товар» |
| `player_shopkeeper.gd` | НПС-продавец у двери магазина |
| `player_shop_host.gd` | связывает всё, ввод, телеметрия `DSH_SHOP` |
| `data/player_shop.json` | **цены, стартовая сумма, реплики — правятся без кода** |

## Правки в существующих файлах (все за флагом, дефолт не меняется)

| файл | что добавлено |
|---|---|
| `scripts/main.gd` | флаг, стартовый набор владения, установка модуля |
| `scripts/weapons/preview_weapons.gd` | необязательный `ownedIds` для арсенала |
| `scripts/weapons/weapon_inventory.gd` | `add_reserve(id, rounds)` — аддитивно, только для купленных стволов |
| `scripts/npc_visual/npc_melee_player_health.gd` | жилет первым принимает урон (через мету игрока) |
| `scripts/destruction/palazzo/c4_equipment.gd` | `set_charge_provider` — заряд C4 из рюкзака |
| `data/preview_updates.json` | строка «НОВОЕ · ПОПРОБУЙ» |

Все точки помечены `DSH_PLAYERSHOP`; без флага ни один путь не меняется.

## Проверки (headless, без окна)

```
<godot> --headless --path <game> --import
<godot> --headless --path <game> --script res://scripts/shop/tests/test_player_shop.gd
<godot> --headless --path <game> --script res://scripts/shop/tests/test_player_shop_ui.gd
<godot> --headless --path <game> --script res://scripts/shop/tests/test_player_shop_defaults.gd
```

Текущий результат: импорт 0 ошибок, модуль 109 проверок, интерфейс 95,
дефолт 24. Живой прогон города: 4 продавца, 34 товара, 0 ошибок.

## Перенос в другую сборку

```
python install_shop.py --target <путь>\game          # примерка, ничего не пишет
python install_shop.py --target <путь>\game --apply  # записать (создаёт бэкапы)
```

Примерка проверена на `outputs/coordinator30_npc54/game` (версия54) и
`outputs/coordinator29_release53a/game` (принятая 53a): все якоря совпадают.
Установщик не пишет ничего, если хотя бы один якорь не найден ровно один раз.
