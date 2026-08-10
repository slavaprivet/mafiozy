import urllib.request, json, base64, os, sys
import builtins as _builtins, sys as _sys, os as _os
def _maybe_input(prompt=""):
    # Если запущено из bat (NO_PAUSE=1) или stdin не от терминала — выходим.
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
    print("    Создай его и впиши туда свой GitHub-токен одной строкой.")
    input("Press Enter to exit..."); sys.exit(1)

REPO   = "slavaprivet/mafiozy"
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
print(f" https://slavaprivet.github.io/mafiozy/{TARGET}")
print("=" * 52)
input("\nPress Enter to exit...")
