# Мафиози — карта систем и «грабли»

Краткий справочник, чтобы не вникать в монолиты заново. Подробная навигация —
в `world_index.txt` (клиент) и `bot_index.txt` (сервер). Регенерация индексов:
`python gen_index.py` и `python gen_index_bot.py`.

## Архитектура

```
Telegram WebApp
   │
   ├─ hub.html ──(open)──► world.html   ← КЛИЕНТ игры (изо-мир, ~30k строк)
   │                          │  WebSocket
   │                          ▼
   └────────────────►  mafiozi_bot.py   ← СЕРВЕР (Python, Railway, ~19k строк)
                              (авторитет: hp/смерть/тюрьма/wanted/worldCops/деньги/снапшоты)
```

- **world.html** — рендер, ввод, локальные NPC (cityCops, жители, охрана банка),
  клиентская физика. Шлёт серверу `input/shoot/bank_rob_*/citycop_arrest/open_fire`.
- **mafiozi_bot.py** — истина по hp/смерти/тюрьме/деньгам. Шлёт клиенту `snapshot`
  (`d.me.hp/dead/jail_in/...`), `cop_shot`, `cop_hit` и пр.
- Заливка клиента: `python github_upload_world.py` (из воркtри — сам берёт локальный
  world.html, проверяет синтаксис node'ом, заливает на Pages). Сервер деплоится отдельно.

## Системы координат (ГЛАВНАЯ ловушка)

- **Мировые координаты**: `player.r, player.c` в тайлах карты (0..MAP_ROWS/COLS).
- **Банк-интерьер**: пока `_bankInt` активен, `player.r/c` — ЛОКАЛЬНЫЕ координаты
  комнаты (0..W, 0..H), НЕ мировые. При входе мировая позиция сохраняется в
  `_bankInt.savedR/savedC`.
- ⚠️ **Нельзя слать серверу `player.r/c` пока в банке** — он решит что игрок
  телепортнулся в угол карты. `sendInput()` шлёт `savedC/savedR` пока `_bankInt`.
- ⚠️ Любая мировая логика (паника NPC, witness-chain, копы-преследование) по
  `player.r/c` в банке БЕССМЫСЛЕННА — гейтить через `!_bankInt`.

## Авторитет сервера vs локальные системы

- Снапшот сервера **перетирает** hp/dead/jail_in каждый тик.
- Локальный урон (охрана банка, cityCops) — через `_hurtLocal(dmg, by)`:
  ставит `myDead + _localDeath`, респаун ведём сами в больнице (сервер не знает).
- `_localHpHurtAt` — пока свежий (2.5с), снапшот НЕ поднимает hp обратно.
- **`_bankShield()`** = `_bankInt || (6с после выхода)`. Пока активен — ВСЕ серверные
  воздействия (hp/dead/jail_in/cop_shot) игнорируются. Закрывает баг «сервер убил
  worldCop'ами у входа, снап dead=true прилетел сразу после выхода».

## Протокол WS (основное)

Клиент → сервер: `input`(x,y,ang,w), `shoot`, `open_fire`, `citycop_arrest`,
`bank_rob_start/announce/bag_loaded/deliver`, `bank_bag_drop`, `npc_melee_shoot`,
`capture_try`, `chat`. (полный список — `bot_index.txt` → WS-обработчики)

Сервер → клиент: `snapshot`(d.me{hp,dead,jail_in,wanted,cash,...}, cops, others,
territories, event), `cop_shot`(killed,jailed,target_uid), `cop_hit`,
`citycop_arrest_reply`, `world_heal_reply`. (в world.html — поиск `kind === '...'`)

## Грабли (по горьким фиксам)

1. **Координаты банка утекают серверу** → ложная смерть/тюрьма. Гейт `!_bankInt`/`_bankShield()`.
2. **Серверный снапшот воскрешает/убивает** — при локальной смерти держим `_localDeath`.
3. **Тюрьма**: кламп движения в квадрат двора ±3 от `JAIL_CENTER` (76,76); центр —
   здание (раньше блокировал проход). Решётка рисуется R=4.3, не `JAIL_RADIUS_TILES=7`.
4. **render() в банке** уходит в `drawBankInteriorScene()` и НЕ доходит до мировых
   `drawBullets()` — боевые эффекты надо звать внутри банковского рендера.
5. **`npc_melee_shoot` от охраны банка серверу** = server-side arrest. Урон банка —
   только локальный `_hurtLocal`.
6. **Заливка**: `github_upload_world.py` берёт world.html рядом с собой (или argv[1]).
   `.token` — только в основном `Desktop\Мафиози`, скрипт ищет его вверх по дереву.

## Превью (локально)

- `.claude/launch.json` → `iso-demo`: `python -m http.server 8765`.
- WS-сервер локально недоступен → играть нельзя, но парсинг/логику функций
  проверяем через `preview_eval` (юнит-тесты в контексте страницы).
- Синтаксис перед заливкой: `python check_world.py` (node --check инлайн-JS).
