# -*- coding: utf-8 -*-
"""
Заливает graphify.html (карта проекта) на GitHub Pages (slavaprivet/mafiozi-battle)
рядом с world.html + ВЕРИФИЦИРУЕТ по SHA.

Перед заливкой САМ перезапекает свежие данные из world.html / mafiozi_bot.py
(вызывает gen_graphify.py), чтобы карта всегда соответствовала коду.

Запуск:  python github_upload_graphify.py
Pages-URL после заливки: https://slavaprivet.github.io/mafiozi-battle/graphify.html
"""
import urllib.request, urllib.error, json, base64, os, sys, hashlib, datetime, subprocess
import builtins as _builtins, sys as _sys, os as _os

def _maybe_input(prompt=""):
    if _os.environ.get("NO_PAUSE") or not _sys.stdin.isatty():
        return ""
    try: return _orig_input(prompt)
    except (EOFError, KeyboardInterrupt): return ""
_orig_input = _builtins.input
_builtins.input = _maybe_input

_HERE = os.path.dirname(os.path.abspath(__file__))
SRC   = os.path.join(_HERE, "graphify.html")
GEN   = os.path.join(_HERE, "gen_graphify.py")

REPO   = "slavaprivet/mafiozi-battle"
BRANCH = "main"
FILE   = "graphify.html"
stamp  = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _find_token():
    candidates = [
        os.path.join(_HERE, ".token"),
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


# ── [0] перезапекаем данные ─────────────────────────────────────────────────
if os.path.exists(GEN):
    print("[0] Перезапекаю данные: python gen_graphify.py ...")
    _env = dict(os.environ, PYTHONIOENCODING="utf-8")  # дочерний печатает utf-8 → совпадает с decode
    r = subprocess.run([sys.executable, GEN], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", env=_env)
    sys.stdout.write(r.stdout or "")
    if r.returncode != 0:
        print("[!] gen_graphify.py упал — заливка отменена:")
        sys.stdout.write(r.stderr or "")
        input("Press Enter to exit..."); sys.exit(3)
else:
    print("[i] gen_graphify.py рядом не найден — заливаю graphify.html как есть")

_TOKEN_FILE = _find_token()
if not _TOKEN_FILE:
    print("[!] Файл .token не найден ни рядом, ни в основном проекте")
    input("Press Enter to exit..."); sys.exit(1)
with open(_TOKEN_FILE, "r", encoding="utf-8") as _f:
    TOKEN = _f.read().strip()
if not TOKEN.startswith("ghp_"):
    print("[!] .token не похож на GitHub-токен (должен начинаться с 'ghp_')")
    input("Press Enter to exit..."); sys.exit(1)

print()
print("=" * 64)
print(" graphify.html (карта проекта)  ->  GitHub Pages  (с верификацией)")
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
markers = [(b'id="gx-data"', "запечённые данные"), (b"Graph", "заголовок"), (b"ghLink", "deep-ссылки")]
found = [name for sig, name in markers if sig in raw]
print(f"      Маркеры : {'OK -> ' + ', '.join(found) if found else '[!] подозрительно: маркеры не найдены'}")


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
payload = {"message": f"graphify.html build {stamp}", "content": content_b64, "branch": BRANCH}
if old_sha:
    payload["sha"] = old_sha

resp, code = gh("PUT", f"/repos/{REPO}/contents/{FILE}", payload)
if code not in (200, 201):
    print(f"[!] HTTP {code} - ЗАЛИВКА УПАЛА")
    print(f"    Ответ: {json.dumps(resp, ensure_ascii=False)[:500]}")
    input("Press Enter to exit..."); sys.exit(2)

content_sha = (resp.get("content") or {}).get("sha", "")
print(f"      HTTP {code} OK   content: {content_sha[:12]}")

print(f"\n[4/4] Подтверждаю через GitHub API...")
verified = False
info2, code2 = gh("GET", f"/repos/{REPO}/contents/{FILE}?ref={BRANCH}")
if code2 == 200 and info2.get("sha") == content_sha:
    print(f"      API подтвердил новый blob {content_sha[:12]} — файл в репо.")
    verified = True
else:
    print(f"      Не смог подтвердить (HTTP {code2}), но PUT уже прошёл.")

print()
print("=" * 64)
print(" UPLOAD OK" if verified else " PUT прошёл (контрольную проверку не прошли)")
print(f" Время     : {stamp}")
print(f" Pages-URL : https://slavaprivet.github.io/mafiozi-battle/{FILE}")
print(" (CDN GitHub Pages обновляется ~10-60 сек после коммита.)")
print("=" * 64)
input("\nPress Enter to exit...")
