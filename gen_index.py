# -*- coding: utf-8 -*-
"""
Генератор индекса символов world.html → world_index.txt

Зачем: world.html ~30k строк / 1.5 МБ. Чтобы не перечитывать его целиком,
этот скрипт строит компактную карту «символ → строка + категория».
Поиск нужной функции: открыть world_index.txt, найти имя, прыгнуть на строку
(или Grep по имени для точной текущей строки, если файл правился после генерации).

Запуск:  python gen_index.py
После любых крупных правок world.html — перегенерировать.
"""
import re, sys, os

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "world.html")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "world_index.txt")

# Категоризация по префиксам/ключевым словам в имени функции
def categorize(name):
    n = name.lower()
    rules = [
        ("банк/интерьер",   ("bank", "vault", "_bint", "_drawbank", "heist", "rob")),
        ("тюрьма",          ("jail", "arrest", "citycop", "prison")),
        ("копы/розыск",     ("cop", "wanted", "snitch", "witness", "pursue", "worldcop")),
        ("стрельба/бой",    ("fire", "shoot", "bullet", "muzzle", "weapon", "hurt", "hit", "melee", "punch", "aim", "lock", "target", "impact", "damage")),
        ("машины/трафик",   ("car", "drive", "traffic", "vehicle", "bus", "drift", "park", "road", "fuel", "gta")),
        ("рендер/рисование",("draw", "render", "spawn", "sprite", "anim", "w2s", "iso", "cam", "shake", "flash")),
        ("npc/жители",      ("npc", "civilian", "ped", "beachgoer", "guard", "decor", "person")),
        ("сеть/ws",         ("ws", "send", "snap", "fetch", "connect", "input", "sync", "api")),
        ("ui/hud/меню",     ("hud", "btn", "modal", "menu", "toast", "banner", "overlay", "zone", "popover", "shop", "update")),
        ("карта/мир",       ("map", "build", "tile", "block", "passable", "world", "territory", "lair", "aggro")),
        ("игрок/состояние", ("player", "my", "respawn", "death", "heal", "hospital", "spawn")),
        ("звук",            ("sound", "audio", "haptic", "sfx", "play")),
    ]
    for cat, keys in rules:
        if any(k in n for k in keys):
            return cat
    return "прочее"

def main():
    with open(SRC, encoding="utf-8") as f:
        lines = f.readlines()

    funcs = []      # (line, name)
    arrows = []     # (line, name)
    handlers = []   # (line, kind)
    consts_big = [] # (line, name) — массивы/объекты состояния верхнего уровня

    re_func   = re.compile(r"^\s*(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(")
    re_arrow  = re.compile(r"^\s*(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*=>")
    re_const  = re.compile(r"^\s*(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:new\s+Map|new\s+Set|\[|\{)")
    re_kind   = re.compile(r"kind\s*===\s*'([^']+)'")

    for i, ln in enumerate(lines, 1):
        m = re_func.match(ln)
        if m: funcs.append((i, m.group(1))); continue
        m = re_arrow.match(ln)
        if m: arrows.append((i, m.group(1))); continue
        m = re_const.match(ln)
        if m: consts_big.append((i, m.group(1)))
        m = re_kind.search(ln)
        if m: handlers.append((i, m.group(1)))

    # Группируем функции (func + arrow) по категориям
    allfns = [(l, n, "fn") for l, n in funcs] + [(l, n, "=>") for l, n in arrows]
    by_cat = {}
    for l, n, kind in allfns:
        by_cat.setdefault(categorize(n), []).append((l, n, kind))

    out = []
    out.append("# ИНДЕКС world.html — символ → строка (категория)")
    out.append(f"# Сгенерировано gen_index.py. Всего строк: {len(lines)}, "
               f"функций: {len(funcs)}, стрелочных: {len(arrows)}, "
               f"ws-обработчиков: {len(handlers)}.")
    out.append("# ВАЖНО: строки могли сместиться после правок — для точной строки Grep по имени.")
    out.append("")

    for cat in sorted(by_cat):
        items = sorted(by_cat[cat], key=lambda x: x[1].lower())
        out.append(f"## {cat}  ({len(items)})")
        for l, n, kind in items:
            mark = "" if kind == "fn" else " (=>)"
            out.append(f"  {n}{mark}  :{l}")
        out.append("")

    out.append("## WS-обработчики (kind === '...')")
    for l, k in sorted(handlers, key=lambda x: x[1]):
        out.append(f"  '{k}'  :{l}")
    out.append("")

    out.append("## Глобальное состояние (Map/Set/массивы/объекты верхнего уровня)")
    for l, n in sorted(consts_big, key=lambda x: x[1].lower()):
        out.append(f"  {n}  :{l}")
    out.append("")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out))

    print(f"OK -> {OUT}")
    print(f"   функций: {len(funcs)}, стрелочных: {len(arrows)}, "
          f"ws: {len(handlers)}, состояние: {len(consts_big)}")

if __name__ == "__main__":
    main()
