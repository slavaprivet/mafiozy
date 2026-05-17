"""
Одноразовая выдача: 100 гранат для @deadblog1 (и для подстраховки — 30 молотовых,
чтоб игрок мог проверить переключатель граната↔молотов).

Запускать из той же папки, где лежит mafiozi.db. Скрипт сам ищет ID по
username в таблице characters и обновляет inventory.
"""
import os
import sqlite3
import sys

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mafiozi.db")

TARGETS = [
    ("grenade", 100),
    ("molotov", 30),
]
USERNAME = "deadblog1"

if not os.path.exists(DB):
    print(f"[!] Не найден {DB}. Запускай из папки проекта.")
    sys.exit(1)

con = sqlite3.connect(DB)
cur = con.cursor()
row = cur.execute(
    "SELECT telegram_id, name FROM characters WHERE LOWER(username)=LOWER(?)",
    (USERNAME,),
).fetchone()
if not row:
    print(f"[!] @{USERNAME} не найден в characters. Сначала запусти /start в боте этим аккаунтом.")
    sys.exit(2)
uid, name = row
print(f"[OK] Найден игрок: {name} (uid={uid})")

for item_id, qty in TARGETS:
    cur.execute(
        "SELECT quantity FROM inventory WHERE telegram_id=? AND item_id=?",
        (uid, item_id),
    )
    have = cur.fetchone()
    if have:
        new_q = have[0] + qty
        cur.execute(
            "UPDATE inventory SET quantity=? WHERE telegram_id=? AND item_id=?",
            (new_q, uid, item_id),
        )
        print(f"   +{qty} {item_id}: было {have[0]} → стало {new_q}")
    else:
        cur.execute(
            "INSERT INTO inventory (telegram_id, item_id, quantity) VALUES (?, ?, ?)",
            (uid, item_id, qty),
        )
        print(f"   +{qty} {item_id}: было 0 → стало {qty}")

con.commit()
con.close()
print("[OK] Готово. Перезайди в бота — увидишь обновлённый инвентарь.")
