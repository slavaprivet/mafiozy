# Мафиози — AGENTS.md

## Проект
Telegram-бот с HTML5-играми. Игры отдаются как WebApp через ngrok/cloudflared-туннель.
Репо: https://github.com/slavaprivet/mafiozy (ветка main)
Заливка через `github_upload_world.py` и аналоги — не через git push напрямую.

## Ключевые файлы
- `world.html` — **главный файл**, открытый изометрический город. Всегда трогать его.
- `hub.html` — хаб/меню игрока
- `battle.html` — PvP-баттл
- `creator.html` — редактор персонажа
- `demo_isometric.html` — эталон физики пуль и HP-бара (не трогать, только смотреть)
- `mafiozi_bot.py` — Telegram-бот (Python + python-telegram-bot)
- `start_with_tunnel.py` — запуск бота + cloudflared-туннель

## Стек
- HTML5 Canvas, чистый JavaScript (без фреймворков)
- Изометрическая проекция (tile-based, BLOCK=10, карта 80×80)
- Python для бота (aiogram или python-telegram-bot)

## Архитектура world.html
Один большой HTML-файл. Всё в нём: карта, NPC, банды, физика пуль, UI.
- День/ночь, фонари (7–17 выключены)
- Захват районов (мульти-захват, мини-карта, доход каждые 10 мин)
- Логово — арена на юге (кулачные бои, контракты, цыганский лагерь)
- Тюрьма R=7, 10 точек спавна
- Бандитское гнездо в случайном здании
- weaponBar всегда виден, HP-бар как в demo_isometric

## Правила работы
- Отвечаем по-русски
- Перед правкой смотрим свежий коммит: `git log -1`
- Заливка: `python github_upload_world.py` (не git push)
- GitHub token хранится в `.token` (в .gitignore)
- Бот-помощник для этого проекта: `C:\Users\Слава\Desktop\game-dev-bot\`

## Связанный проект
`game-dev-bot` — Telegram-бот-помощник, который через телефон принимает идеи
и внедряет их в world.html через GitHub API. Код в отдельной папке, не смешивать.

---

## Ruflo — агентная оркестрация

Установлен Ruflo (ruvnet/ruflo) для координации агентов и памяти.

### Полезные команды Ruflo в Codex
- `/sparc` — 5-фазная методология разработки (spec → pseudocode → arch → refine → complete)
- `/swarm` — запустить нескольких агентов параллельно
- `/memory` — сохранить/найти что-то в векторной памяти
- `/testgen` — сгенерировать тесты для Python-файлов

### Задачи для агентов (приоритеты)
1. **world.html** — изометрический движок, физика пуль, NPC банды, захват районов
2. **mafiozi_bot.py** — Telegram WebApp интеграция, туннель, сессии игроков
3. **battle.html** — PvP система, балансировка
4. **hub.html / creator.html** — UI игрока

### Контекст для агентов
- Язык кода: JavaScript (Canvas) + Python (бот)
- Не использовать npm/node в игровом коде — только чистый JS
- Карта: изометрия, tile BLOCK=10, 80×80 клеток
- База данных: SQLite (mafiozi.db) через Python
- Деплой: cloudflared туннель + GitHub API (не git push)
- Токены в файлах `.token` и `.bot-token` — никогда не коммитить
