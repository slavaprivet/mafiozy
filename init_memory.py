"""Инициализирует память Ruflo с контекстом проекта Мафиози"""
import subprocess, os, sys

os.chdir(os.path.dirname(os.path.abspath(__file__)))

def npx(cmd):
    full = f"npx --yes ruflo@latest {cmd}"
    print(f">>> {full}")
    r = subprocess.run(full, shell=True, capture_output=True, text=True)
    out = r.stdout.strip() or r.stderr.strip()
    if out: print(out)
    return r.returncode == 0

print("=" * 50)
print("  Инициализация памяти Ruflo для Мафиози")
print("=" * 50)

# Инициализируем память
print("\n[1/3] Инициализация memory DB...")
npx("memory init")

# Инициализируем swarm
print("\n[2/3] Инициализация swarm...")
npx("swarm init")

# Запускаем daemon
print("\n[3/3] Запуск daemon...")
npx("daemon start")

# Сохраняем ключевые факты о проекте
print("\n[4/4] Сохранение контекста проекта...")

memories = [
    "Проект: Telegram-бот Мафиози. HTML5-игра, изометрический город. Репо: github.com/slavaprivet/mafiozy",
    "Главный файл: world.html — изометрический город на Canvas. BLOCK=10, карта 80x80 тайлов",
    "Стек: чистый JS (без фреймворков) + Python для бота. НЕ использовать npm/node в игровом коде",
    "Деплой: python github_upload_world.py (НЕ git push). Токены в .token и .bot-token — не коммитить",
    "demo_isometric.html — эталон физики пуль и HP-бара. Смотреть, не трогать",
    "Захват районов: мульти-захват, мини-карта, доход каждые 10 мин. День/ночь, фонари 7-17",
    "Тюрьма R=7, 10 точек спавна. Логово на юге — арена кулачных боёв и контракты",
    "battle.html — PvP-баттл. hub.html — меню игрока. creator.html — редактор персонажа",
    "mafiozi_bot.py — Telegram-бот (python-telegram-bot). start_with_tunnel.py — cloudflared туннель",
    "SQLite база данных: mafiozi.db. Связанный проект game-dev-bot — отдельная папка, не смешивать",
]

for mem in memories:
    npx(f'memory store "{mem}"')

print("\n" + "=" * 50)
print("  ГОТОВО! Память инициализирована.")
print("  В Claude Code используй:")
print("  /memory search 'деплой' — найти что-то")
print("  /memory store 'идея' — сохранить идею")
print("=" * 50)
input("\nНажми Enter для выхода...")
