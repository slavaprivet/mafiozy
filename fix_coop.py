import sqlite3

db = "mafiozi.db"
conn = sqlite3.connect(db)
cur = conn.cursor()
cur.execute("UPDATE coop_sessions SET status='cancelled' WHERE status IN ('active','pending')")
conn.commit()
print("Очищено зависших co-op сессий:", cur.rowcount)
conn.close()
print("Готово! Теперь запускай бота.")
input("\nНажми Enter для выхода")
