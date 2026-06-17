"""
Загружает world.html (общий онлайн-мир, Phase 10) на GitHub + ВЕРИФИЦИРУЕТ.
После заливки качает файл обратно с raw.githubusercontent.com и сверяет SHA-256.
"""
import urllib.request, urllib.error, json, base64, os, sys, hashlib, datetime, time
import builtins as _builtins, sys as _sys, os as _os
def _maybe_input(prompt=""):
    if _os.environ.get("NO_PAUSE") or not _sys.stdin.isatty():
        return ""
    try: return _orig_input(prompt)
    except (EOFError, KeyboardInterrupt): return ""
_orig_input = _builtins.input
_builtins.input = _maybe_input

_HERE = os.path.dirname(os.path.abspath(__file__))

# Источник: аргумент командной строки ИЛИ world.html рядом со скриптом.
# Это даёт заливать прямо из git-воркtри (python .../github_upload_world.py)
# без ручного копирования файла в основной путь.
SRC = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(_HERE, "world.html")

# .token ищем: рядом со скриптом → в основном проекте → вверх по дереву.
# (в git-воркtри .token обычно нет — он лежит в основном Desktop\Мафиози.)
def _find_token():
    candidates = [
        os.path.join(_HERE, ".token"),
        os.path.join(os.path.dirname(SRC), ".token"),
        r"C:\Users\Слава\Desktop\Мафиози\.token",
    ]
    d = _HERE
    for _ in range(6):
        candidates.append(os.path.join(d, ".token"))
        d = os.path.dirname(d)
    for c in candidates:
        if os.path.exists(c):
            return c
    return None

_TOKEN_FILE = _find_token()
if not _TOKEN_FILE:
    print("[!] Файл .token не найден ни рядом со скриптом, ни в основном проекте")
    input("Press Enter to exit..."); sys.exit(1)
with open(_TOKEN_FILE, "r", encoding="utf-8") as _f:
    TOKEN = _f.read().strip()
if not TOKEN.startswith("ghp_"):
    print("[!] .token не похож на GitHub-токен (должен начинаться с 'ghp_')")
    input("Press Enter to exit..."); sys.exit(1)

REPO   = "slavaprivet/mafiozi-battle"
BRANCH = "main"
FILE   = "world.html"
stamp  = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# ── Проверка синтаксиса JS ДО заливки (не дать залить «белый экран») ──
try:
    from check_world import check_html_js
    print("\n[0] Проверка синтаксиса JS (node --check)...")
    if check_html_js(SRC) != 0:
        print("[!] СИНТАКСИЧЕСКАЯ ОШИБКА — заливка отменена. Исправь и повтори.")
        input("Press Enter to exit..."); sys.exit(3)
except ImportError:
    print("[i] check_world.py рядом не найден — пропускаю проверку синтаксиса")

print()
print("=" * 64)
print(" world.html (Город онлайн)  ->  GitHub  (с верификацией)")
print("=" * 64)

print(f"\n[1/4] Читаю локальный {FILE}...")
try:
    with open(SRC, "rb") as f:
        raw = f.read()
except FileNotFoundError:
    print(f"[!] Не нашёл {SRC}")
    input("Press Enter to exit..."); sys.exit(1)

local_sha = hashlib.sha256(raw).hexdigest()
content_b64 = base64.b64encode(raw).decode()
print(f"      Размер  : {len(raw):,} байт")
print(f"      SHA-256 : {local_sha}")
markers = [
    (b"WorldSim",       "класс серверной симуляции"),
    (b"world/sim",      "WebSocket эндпоинт"),
    (b"drawPerson",     "рендер игроков"),
]
found = [name for sig, name in markers if sig in raw]
if found:
    print(f"      Маркеры : OK -> {', '.join(found)}")
else:
    print(f"      Маркеры : [!] не найдено НИ ОДНОГО маркера новой версии!")

def gh(method, path, body=None):
    req = urllib.request.Request(
        "https://api.github.com" + path,
        json.dumps(body).encode() if body else None,
        method=method,
    )
    req.add_header("Authorization", "token " + TOKEN)
    req.add_header("Accept", "application/vnd.github.v3+json")
    req.add_header("User-Agent", "mafiozi-uploader")
    if body:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read()), e.code
        except Exception:
            return {"message": str(e)}, e.code
    except Exception as e:
        return {"message": str(e)}, 0

print(f"\n[2/4] Получаю SHA текущего {FILE} в репо...")
info, code = gh("GET", f"/repos/{REPO}/contents/{FILE}?ref={BRANCH}")
old_sha = info.get("sha") if code == 200 else None
print(f"      HTTP {code}   remote-blob: {old_sha[:12] if old_sha else '(новый файл)'}")
if code not in (200, 404):
    print(f"[!] ОШИБКА: {info.get('message', info)}")
    input("Press Enter to exit..."); sys.exit(1)

print(f"\n[3/4] PUT {FILE} ...")
payload = {"message": f"world.html build {stamp}", "content": content_b64, "branch": BRANCH}
if old_sha:
    payload["sha"] = old_sha

resp, code = gh("PUT", f"/repos/{REPO}/contents/{FILE}", payload)
if code not in (200, 201):
    print(f"[!] HTTP {code} - ЗАЛИВКА УПАЛА")
    print(f"    Ответ: {json.dumps(resp, ensure_ascii=False)[:500]}")
    input("Press Enter to exit..."); sys.exit(2)

commit_sha  = (resp.get("commit") or {}).get("sha", "")
content_sha = (resp.get("content") or {}).get("sha", "")
print(f"      HTTP {code} OK")
print(f"      commit  : {commit_sha[:12]}")
print(f"      content : {content_sha[:12]}")

print(f"\n[4/4] Быстрая проверка через GitHub API (без CDN raw)...")
# CDN raw.githubusercontent.com кэширует на 1-3 минуты — раньше мы здесь
# зависали по 18+ сек впустую. Теперь делаем GET contents через API:
# он отдаёт АКТУАЛЬНЫЙ blob_sha сразу же.
verified = False
info2, code2 = gh("GET", f"/repos/{REPO}/contents/{FILE}?ref={BRANCH}")
if code2 == 200:
    new_blob = info2.get("sha") or ""
    if new_blob and new_blob == content_sha:
        print(f"      API подтвердил новый blob {new_blob[:12]} — файл в репо.")
        verified = True
    else:
        print(f"      API blob {new_blob[:12]} ≠ PUT content {content_sha[:12]} (странно)")
else:
    print(f"      API ответ HTTP {code2} — не смогли подтвердить, но PUT уже прошёл.")

print()
print("=" * 64)
if verified:
    print(" UPLOAD OK")
    print(f" Время       : {stamp}")
    print(f" Pages-URL   : https://slavaprivet.github.io/mafiozi-battle/{FILE}")
    print()
    print(" Дальше: в Telegram /start — мини-апп подхватит свежую версию.")
    print(" (CDN GitHub Pages обновляется ~10-60 сек после коммита.)")
else:
    print(" PUT прошёл, но контрольную проверку не прошли. Файл скорее всего")
    print(" уже залит — открой Pages-URL в браузере и проверь:")
    print(f"   https://slavaprivet.github.io/mafiozi-battle/{FILE}")
print("=" * 64)
input("\nPress Enter to exit...")
