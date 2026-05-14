import urllib.request, json, base64, os, sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_TOKEN_FILE = os.path.join(_HERE, ".token")
try:
    with open(_TOKEN_FILE, "r", encoding="utf-8") as _f:
        TOKEN = _f.read().strip()
    if not TOKEN.startswith("ghp_"):
        print(f"[!] .token не похож на GitHub-токен (должен начинаться с 'ghp_')")
        input("Press Enter to exit..."); sys.exit(1)
except FileNotFoundError:
    print(f"[!] Файл .token не найден: {_TOKEN_FILE}")
    print(f"    Создай его и впиши туда свой GitHub-токен одной строкой.")
    input("Press Enter to exit..."); sys.exit(1)

REPO  = "slavaprivet/mafiozi-battle"
SRC   = os.path.join(_HERE, "battle.html")

# Загружаем под обоими именами — index.html (основной) и battle.html
TARGETS = ["index.html", "battle.html"]

print("[1] Reading battle.html...")
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

for FILE in TARGETS:
    print(f"\n[2] Getting SHA for {FILE}...")
    i, s = api("GET", f"/repos/{REPO}/contents/{FILE}")
    sha = i.get("sha") if s == 200 else None
    print("    SHA:", sha[:12] if sha else "new file")

    print(f"[3] Uploading as {FILE}...")
    pl = {"message": f"Fix {FILE} - endBattle partyAct doFlee taunts grenades", "content": c}
    if sha:
        pl["sha"] = sha

    r, code = api("PUT", f"/repos/{REPO}/contents/{FILE}", pl)
    print(f"    HTTP {code} — {'OK' if code in (200,201) else r.get('message','ERR')}")

print()
print("=" * 44)
print(" Done! Check in ~1 min:")
print(" https://slavaprivet.github.io/mafiozi-battle/")
print("=" * 44)
input("\nPress Enter to exit...")
