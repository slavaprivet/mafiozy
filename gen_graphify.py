# -*- coding: utf-8 -*-
"""
Генератор данных для graphify.html — единый «сервис-карта» проекта Мафиози.

Зачем: world.html (~30k строк) и mafiozi_bot.py (~19k строк) — монолиты. Чтобы
работать НЕ перечитывая код, скрипт парсит оба файла (как gen_index.py /
gen_index_bot.py) И СТРОИТ ГРАФ ВЫЗОВОВ (кто кого вызывает), затем:
  • ЗАПЕКАЕТ компактный JSON в <script id="gx-data"> внутри graphify.html
    (страница self-contained: функции по категориям, WS, граф вызовов, клик →
     точная строка на GitHub);
  • пишет graphify.json — тот же граф одним машинно-читаемым файлом (удобно читать
    целиком за один заход вместо грепов).

Граф вызовов — ЭВРИСТИКА по regex: тело функции = строки от её объявления до
следующего объявления; в теле ищем вызовы `имя(` среди известных имён. Не 100%
точно (вложенность, top-level код, одноимённые методы разных классов
конфлируются), но даёт «соседей» функции без чтения файла.

Запуск:  python gen_graphify.py
После крупных правок world.html / mafiozi_bot.py — перегенерировать (и залить
github_upload_graphify.py).
"""
import re, os, json, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT_SRC = os.path.join(HERE, "world.html")
SERVER_SRC = os.path.join(HERE, "mafiozi_bot.py")
PAGE = os.path.join(HERE, "graphify.html")
JSON_OUT = os.path.join(HERE, "graphify.json")

# Репозитории для deep-ссылок (клиент и сервер живут в РАЗНЫХ репо).
CLIENT_REPO, CLIENT_BRANCH, CLIENT_FILE = "slavaprivet/mafiozi-battle", "main", "world.html"
SERVER_REPO, SERVER_BRANCH, SERVER_FILE = "slavaprivet/mafiozy", "main", "mafiozi_bot.py"


# ── Категоризация (синхронно с gen_index.py / gen_index_bot.py) ──────────────
def cat_client(name):
    n = name.lower()
    rules = [
        ("банк/интерьер",    ("bank", "vault", "_bint", "_drawbank", "heist", "rob")),
        ("тюрьма",           ("jail", "arrest", "citycop", "prison")),
        ("копы/розыск",      ("cop", "wanted", "snitch", "witness", "pursue", "worldcop")),
        ("стрельба/бой",     ("fire", "shoot", "bullet", "muzzle", "weapon", "hurt", "hit", "melee", "punch", "aim", "lock", "target", "impact", "damage")),
        ("машины/трафик",    ("car", "drive", "traffic", "vehicle", "bus", "drift", "park", "road", "fuel", "gta")),
        ("рендер/рисование", ("draw", "render", "spawn", "sprite", "anim", "w2s", "iso", "cam", "shake", "flash")),
        ("npc/жители",       ("npc", "civilian", "ped", "beachgoer", "guard", "decor", "person")),
        ("сеть/ws",          ("ws", "send", "snap", "fetch", "connect", "input", "sync", "api")),
        ("ui/hud/меню",      ("hud", "btn", "modal", "menu", "toast", "banner", "overlay", "zone", "popover", "shop", "update")),
        ("карта/мир",        ("map", "build", "tile", "block", "passable", "world", "territory", "lair", "aggro")),
        ("игрок/состояние",  ("player", "my", "respawn", "death", "heal", "hospital", "spawn")),
        ("звук",             ("sound", "audio", "haptic", "sfx", "play")),
    ]
    for cat, keys in rules:
        if any(k in n for k in keys):
            return cat
    return "прочее"


def cat_server(name):
    n = name.lower()
    rules = [
        ("банк/ограбление",  ("bank", "vault", "heist", "rob")),
        ("тюрьма/арест",     ("jail", "arrest", "citycop", "prison", "release")),
        ("копы/розыск",      ("cop", "wanted", "snitch", "witness", "pursue", "patrol")),
        ("бой/урон/смерть",  ("hp", "damage", "hit", "shoot", "kill", "death", "die", "dead", "respawn", "heal", "combat", "fire", "weapon")),
        ("снапшот/сеть",     ("snap", "broadcast", "send", "input", "sync", "serialize", "payload", "ws", "socket", "packet", "pkt")),
        ("машины/трафик",    ("car", "drive", "traffic", "vehicle", "bus", "convoy")),
        ("игрок/профиль",    ("player", "user", "profile", "uid", "session", "spawn", "look")),
        ("экономика",        ("cash", "money", "reward", "pay", "buy", "sell", "business", "biz", "shop", "price")),
        ("территории/банды", ("territory", "gang", "aggro", "lair", "capture", "contract", "brigadir")),
        ("события/мир",      ("event", "world", "tick", "loop", "encash", "boss", "michael")),
        ("бд/хранение",      ("db", "save", "load", "sql", "redis", "store", "persist", "commit")),
        ("телеграм/команды", ("tg", "telegram", "command", "/start", "webapp", "handler_", "cmd")),
    ]
    for cat, keys in rules:
        if any(k in n for k in keys):
            return cat
    return "прочее"


def build_edges(lines, symbols, ident):
    """Строит граф вызовов: каждому символу проставляет calls[] и calledBy[].
    lines — строки файла (0-индекс), symbols — список dict с 'n' и 'l' (1-индекс),
    ident — regex-строка с одной группой для токена вызова `имя(`."""
    name_set = set(s["n"] for s in symbols)
    starts = sorted(set(s["l"] for s in symbols))
    nxt = {ln: (starts[i + 1] if i + 1 < len(starts) else len(lines) + 1)
           for i, ln in enumerate(starts)}
    call_re = re.compile(ident)
    for s in symbols:
        a, b = s["l"], nxt[s["l"]]          # тело: строки ПОСЛЕ объявления до следующего
        body = "".join(lines[a:b - 1])
        found = {t for t in call_re.findall(body) if t in name_set and t != s["n"]}
        s["calls"] = sorted(found)
    rev = {}
    for s in symbols:
        for t in s["calls"]:
            rev.setdefault(t, set()).add(s["n"])
    for s in symbols:
        s["calledBy"] = sorted(rev.get(s["n"], ()))
    return symbols


def parse_client():
    with open(CLIENT_SRC, encoding="utf-8") as f:
        lines = f.readlines()
    re_func  = re.compile(r"^\s*(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(")
    re_arrow = re.compile(r"^\s*(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*=>")
    re_kind  = re.compile(r"kind\s*===\s*'([^']+)'")
    syms, ws, seen = [], [], set()
    for i, ln in enumerate(lines, 1):
        m = re_func.match(ln)
        if m:
            syms.append({"n": m.group(1), "l": i, "k": "fn", "cat": cat_client(m.group(1))}); continue
        m = re_arrow.match(ln)
        if m:
            syms.append({"n": m.group(1), "l": i, "k": "=>", "cat": cat_client(m.group(1))}); continue
        m = re_kind.search(ln)
        if m and m.group(1) not in seen:
            seen.add(m.group(1)); ws.append({"k": m.group(1), "l": i})
    build_edges(lines, syms, r"([A-Za-z_$][\w$]*)\s*\(")
    return len(lines), syms, ws


def parse_server():
    with open(SERVER_SRC, encoding="utf-8") as f:
        lines = f.readlines()
    re_def   = re.compile(r"^(\s*)(?:async\s+)?def\s+([A-Za-z_]\w*)\s*\(")
    re_class = re.compile(r"^\s*class\s+([A-Za-z_]\w*)")
    re_kind  = re.compile(r"""(?:^|\b)(?:elif|if)\s+t\s*==\s*['"]([^'"]+)['"]""")
    syms, ws, classes, seen = [], [], [], set()
    for i, ln in enumerate(lines, 1):
        m = re_class.match(ln)
        if m:
            classes.append({"n": m.group(1), "l": i}); continue
        m = re_def.match(ln)
        if m:
            method = len(m.group(1)) > 0
            syms.append({"n": m.group(2), "l": i, "k": "method" if method else "def",
                         "cat": cat_server(m.group(2))}); continue
        m = re_kind.search(ln)
        if m and m.group(1) not in seen:
            seen.add(m.group(1)); ws.append({"k": m.group(1), "l": i})
    build_edges(lines, syms, r"([A-Za-z_]\w*)\s*\(")
    return len(lines), syms, ws, classes


def main():
    c_lines, c_syms, c_ws = parse_client()
    s_lines, s_syms, s_ws, s_classes = parse_server()

    data = {
        "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "repos": {
            "client": {"repo": CLIENT_REPO, "branch": CLIENT_BRANCH, "file": CLIENT_FILE, "lines": c_lines},
            "server": {"repo": SERVER_REPO, "branch": SERVER_BRANCH, "file": SERVER_FILE, "lines": s_lines},
        },
        "client": {"symbols": c_syms, "ws": c_ws},
        "server": {"symbols": s_syms, "ws": s_ws, "classes": s_classes},
    }

    # graphify.json — читаемый машинный артефакт (для Claude: вся карта за один Read)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

    # запекаем компактную копию в страницу
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    with open(PAGE, encoding="utf-8") as f:
        html = f.read()
    new_html, n = re.subn(
        r'(<script id="gx-data" type="application/json">)(.*?)(</script>)',
        lambda m: m.group(1) + payload + m.group(3),
        html, count=1, flags=re.DOTALL,
    )
    if n != 1:
        raise SystemExit("[!] Не найден <script id=\"gx-data\"> в graphify.html — нечего запекать")
    with open(PAGE, "w", encoding="utf-8") as f:
        f.write(new_html)

    c_edges = sum(len(s["calls"]) for s in c_syms)
    s_edges = sum(len(s["calls"]) for s in s_syms)
    print(f"OK -> {PAGE}")
    print(f"OK -> {JSON_OUT}")
    print(f"   клиент: {len(c_syms)} символов, {c_edges} рёбер вызовов, {len(c_ws)} WS")
    print(f"   сервер: {len(s_syms)} символов, {s_edges} рёбер вызовов, {len(s_classes)} классов, {len(s_ws)} WS")


if __name__ == "__main__":
    main()
