import asyncio
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path

import aiosqlite
import mafiozi_bot as bot


ROOT = Path(__file__).resolve().parent


class BusinessBlockExpiryTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        fd, self.db_path = tempfile.mkstemp(
            prefix="mafiozi-business-block-", suffix=".db")
        os.close(fd)
        self.old_db_path = bot.DB_PATH
        bot.DB_PATH = self.db_path
        bot._owned_business_income_next_check = 0.0
        with sqlite3.connect(self.db_path) as db:
            db.executescript("""
                CREATE TABLE characters(
                    telegram_id INTEGER PRIMARY KEY,
                    cash INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE player_businesses(
                    telegram_id INTEGER NOT NULL,
                    biz_id TEXT NOT NULL,
                    bought_at INTEGER NOT NULL,
                    last_collect INTEGER NOT NULL,
                    status TEXT DEFAULT 'ok',
                    blocked_until INTEGER DEFAULT 0,
                    last_event_at INTEGER DEFAULT 0,
                    pending_notice TEXT DEFAULT NULL,
                    level INTEGER DEFAULT 1,
                    guards INTEGER DEFAULT 0,
                    npc_capture_cooldown_until INTEGER DEFAULT 0,
                    income_remainder INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY(telegram_id,biz_id)
                );
            """)

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_db_path
        bot._owned_business_income_next_check = 0.0
        for attempt in range(20):
            try:
                os.unlink(self.db_path)
                break
            except PermissionError:
                if attempt == 19:
                    break
                await asyncio.sleep(0.05)

    def seed(self, uid: int, blocked_until: int, *, status: str = "blocked"):
        with sqlite3.connect(self.db_path) as db:
            db.execute(
                "INSERT INTO characters(telegram_id,cash) VALUES(?,0)",
                (uid,))
            db.execute(
                "INSERT INTO player_businesses"
                "(telegram_id,biz_id,bought_at,last_collect,status,"
                "blocked_until,level) VALUES(?, 'port', 900000, 900000, "
                "?, ?, 1)", (uid, status, blocked_until))

    def snapshot(self, uid: int):
        with sqlite3.connect(self.db_path) as db:
            return db.execute(
                "SELECT c.cash,p.status,p.blocked_until,p.last_collect "
                "FROM characters c JOIN player_businesses p "
                "ON p.telegram_id=c.telegram_id WHERE c.telegram_id=?",
                (uid,)).fetchone()

    async def test_active_block_stops_income_and_expired_block_reopens(self):
        now = 1_000_000
        self.seed(1, now + 120)
        self.seed(2, now - 120)
        expected, _ = bot.business_elapsed_income(
            bot.get_business("port"), 1, 120, 0)

        world = type("World", (), {"players": {}})()
        events = await bot._tick_owned_business_income(world, now=now)

        self.assertEqual(self.snapshot(1), (0, "blocked", now + 120, 999960))
        self.assertEqual(self.snapshot(2), (expected, "ok", 0, now))
        self.assertEqual(
            [(event["owner_uid"], event["amount"]) for event in events],
            [("2", expected)])

    async def test_normalizer_does_not_touch_burned_status(self):
        now = 1_000_000
        self.seed(1, now - 120, status="burned")
        async with aiosqlite.connect(self.db_path) as db:
            changed = await bot._normalize_expired_business_blocks(db, now)
            await db.commit()
        self.assertEqual(changed, 0)
        self.assertEqual(self.snapshot(1), (0, "burned", now - 120, 900000))

    def test_world_renders_authoritative_block_timer(self):
        world = (ROOT / "world.html").read_text(encoding="utf-8")
        self.assertIn("blocked_until: +b.blocked_until || 0", world)
        self.assertIn("Доход не начисляется", world)
        self.assertIn("доход остановлен", world)


if __name__ == "__main__":
    unittest.main()
