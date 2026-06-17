# -*- coding: utf-8 -*-
"""
Генератор индекса символов mafiozi_bot.py (СЕРВЕР) → bot_index.txt

Зачем: сервер ~19k строк, монолит. Авторитативная логика (hp/смерть/тюрьма/
wanted/worldCops/снапшоты) живёт тут. Серверные баги (напр. смерть игрока в
банке) чинятся именно здесь. Индекс: «def/class/WS-обработчик → строка + категория».

Запуск:  python gen_index_bot.py
"""
import re, os

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mafiozi_bot.py")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bot_index.txt")

def categorize(name):
    n = name.lower()
    rules = [
        ("банк/ограбление", ("bank", "vault", "heist", "rob")),
        ("тюрьма/арест",    ("jail", "arrest", "citycop", "prison", "release")),
        ("копы/розыск",     ("cop", "wanted", "snitch", "witness", "pursue", "patrol")),
        ("бой/урон/смерть", ("hp", "damage", "hit", "shoot", "kill", "death", "die", "dead", "respawn", "heal", "combat", "fire", "weapon")),
        ("снапшот/сеть",    ("snap", "broadcast", "send", "input", "sync", "serialize", "payload", "ws", "socket", "packet", "pkt")),
        ("машины/трафик",   ("car", "drive", "traffic", "vehicle", "bus", "convoy")),
        ("игрок/профиль",   ("player", "user", "profile", "uid", "session", "spawn", "look")),
        ("экономика",       ("cash", "money", "reward", "pay", "buy", "sell", "business", "biz", "shop", "price")),
        ("территории/банды",("territory", "gang", "aggro", "lair", "capture", "contract", "brigadir")),
        ("события/мир",     ("event", "world", "tick", "loop", "encash", "boss", "michael")),
        ("бд/хранение",     ("db", "save", "load", "sql", "redis", "store", "persist", "commit")),
        ("телеграм/команды",("tg", "telegram", "command", "/start", "webapp", "handler_", "cmd")),
    ]
    for cat, keys in rules:
        if any(k in n for k in keys):
            return cat
    return "прочее"

def main():
    with open(SRC, encoding="utf-8") as f:
        lines = f.readlines()

    defs, classes, handlers = [], [], []
    re_def   = re.compile(r"^(\s*)(?:async\s+)?def\s+([A-Za-z_]\w*)\s*\(")
    re_class = re.compile(r"^\s*class\s+([A-Za-z_]\w*)")
    re_kind  = re.compile(r"""(?:^|\b)(?:elif|if)\s+t\s*==\s*['"]([^'"]+)['"]""")

    for i, ln in enumerate(lines, 1):
        m = re_class.match(ln)
        if m: classes.append((i, m.group(1))); continue
        m = re_def.match(ln)
        if m:
            indent = len(m.group(1))
            defs.append((i, m.group(2), indent))
            continue
        m = re_kind.search(ln)
        if m: handlers.append((i, m.group(1)))

    by_cat = {}
    for l, n, indent in defs:
        tag = " (метод)" if indent > 0 else ""
        by_cat.setdefault(categorize(n), []).append((l, n, tag))

    out = []
    out.append("# ИНДЕКС mafiozi_bot.py (СЕРВЕР) — символ → строка (категория)")
    out.append(f"# Сгенерировано gen_index_bot.py. Строк: {len(lines)}, "
               f"def: {len(defs)}, class: {len(classes)}, WS-обработчиков t==: {len(handlers)}.")
    out.append("# ВАЖНО: строки могли сместиться — для точной строки Grep по имени.")
    out.append("")

    if classes:
        out.append(f"## Классы  ({len(classes)})")
        for l, n in sorted(classes, key=lambda x: x[1].lower()):
            out.append(f"  class {n}  :{l}")
        out.append("")

    for cat in sorted(by_cat):
        items = sorted(by_cat[cat], key=lambda x: x[1].lower())
        out.append(f"## {cat}  ({len(items)})")
        for l, n, tag in items:
            out.append(f"  {n}{tag}  :{l}")
        out.append("")

    out.append("## WS-обработчики (t == '...')")
    for l, k in sorted(handlers, key=lambda x: x[1]):
        out.append(f"  '{k}'  :{l}")
    out.append("")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out))

    print(f"OK -> {OUT}")
    print(f"   def: {len(defs)}, class: {len(classes)}, WS: {len(handlers)}")

if __name__ == "__main__":
    main()
