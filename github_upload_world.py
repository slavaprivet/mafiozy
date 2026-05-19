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

_TOKEN_FILE = os.path.join(_HERE, ".token")
try:
    with open(_TOKEN_FILE, "r", encoding="utf-8") as _f:
        TOKEN = _f.read().strip()
    if not TOKEN.startswith("ghp_"):
        print("[!] .token не похож на GitHub-токен (должен начинаться с 'ghp_')")
        input("Press Enter to exit..."); sys.exit(1)
except FileNotFoundError:
    print(f"[!] Файл .token не найден: {_TOKEN_FILE}")
    input("Press Enter to exit..."); sys.exit(1)

REPO   = "slavaprivet/mafiozi-battle"
BRANCH = "main"
SRC    = os.path.join(_HERE, "world.html")
FILE   = "world.html"
stamp  = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

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

print(f"\n[4/4] Качаю обратно с raw.githubusercontent.com и сверяю SHA...")
raw_url = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/{FILE}"
verified = False
for attempt in range(1, 7):
    try:
        req = urllib.request.Request(raw_url)
        req.add_header("Cache-Control", "no-cache")
        req.add_header("Pragma", "no-cache")
        with urllib.request.urlopen(req, timeout=30) as r:
            remote_raw = r.read()
        remote_sha = hashlib.sha256(remote_raw).hexdigest()
        if remote_sha == local_sha:
            print(f"      Попытка {attempt}: SHA совпали ({remote_sha[:16]}...)   OK")
            verified = True
            break
        print(f"      Попытка {attempt}: пока старая версия ({remote_sha[:16]}...), жду 3 сек...")
        time.sleep(3)
    except Exception as e:
        print(f"      Попытка {attempt}: {e}, жду 3 сек...")
        time.sleep(3)

print()
print("=" * 64)
if verified:
    print(" UPLOAD OK И ПРОВЕРЕН")
    print(f" Время       : {stamp}")
    print(f" Pages-URL   : https://slavaprivet.github.io/mafiozi-battle/{FILE}")
    print(f" Raw-URL     : {raw_url}")
    print()
    print(" Дальше: в Telegram нажми «Город онлайн» в главном меню.")
else:
    print(" UPLOAD ПРОШЁЛ, НО ВЕРИФИКАЦИЯ НЕ ДОЖДАЛАСЬ ОБНОВЛЕНИЯ.")
    print(" Открой ссылку ниже в браузере (Ctrl+F5) — должна быть свежая версия:")
    print(f"   {raw_url}")
print("=" * 64)
input("\nPress Enter to exit...")
