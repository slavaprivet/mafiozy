import urllib.request, json, base64, os, sys

_HERE = os.path.dirname(os.path.abspath(__file__))

# Если запущено двойным кликом — ждём Enter перед закрытием окна.
# Если из bat (NO_PAUSE=1) или через pipe — выходим сразу.
def _wait_for_enter():
    import sys as _s, os as _o
    if _o.environ.get("NO_PAUSE") or not _s.stdin.isatty():
        return
    try: input("Press Enter to exit...")
    except (EOFError, KeyboardInterrupt): pass

_TOKEN_FILE = os.path.join(_HERE, ".token")
try:
    with open(_TOKEN_FILE, "r", encoding="utf-8") as _f:
        TOKEN = _f.read().strip()
    if not TOKEN.startswith("ghp_"):
        print("[!] .token не похож на GitHub-токен (должен начинаться с 'ghp_')")
        _wait_for_enter(); sys.exit(1)
except FileNotFoundError:
    print(f"[!] Файл .token не найден: {_TOKEN_FILE}")
    print("    Создай его и впиши туда свой GitHub-токен одной строкой.")
    _wait_for_enter(); sys.exit(1)

REPO   = "slavaprivet/mafiozi-battle"
SRC    = os.path.join(_HERE, "creator.html")
TARGET = "creator.html"

print("[1] Reading creator.html...")
with open(SRC, "rb") as f:
    c = base64.b64encode(f.read()).decode()
print(f"    Size: {len(c)//1024} KB")

def api(m, p, d=None):
    req = urllib.request.Request(
        "https://api.github.com" + p,
        json.dumps(d).encode() if d else None,
        method=m
    )
    req.add_header("Authorization", "token " + TOKEN)
    req.add_header("Accept", "application/vnd.github.v3+json")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        return json.loads(e.read()), e.code

print(f"\n[2] Getting SHA for {TARGET}...")
i, s = api("GET", f"/repos/{REPO}/contents/{TARGET}")
sha = i.get("sha") if s == 200 else None
print("    SHA:", sha[:12] if sha else "new file")

print(f"[3] Uploading as {TARGET}...")
pl = {"message": "Add creator.html - gangster appearance editor", "content": c}
if sha:
    pl["sha"] = sha

r, code = api("PUT", f"/repos/{REPO}/contents/{TARGET}", pl)
print(f"    HTTP {code} — {'OK' if code in (200,201) else r.get('message','ERR')}")

print()
print("=" * 52)
print(" Done! Check in ~1 min:")
print(f" https://slavaprivet.github.io/mafiozi-battle/{TARGET}")
print("=" * 52)
input("\nPress Enter to exit...")
