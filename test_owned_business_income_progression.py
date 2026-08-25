import asyncio
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path

import aiosqlite
import mafiozi_bot as bot


ROOT = Path(__file__).resolve().parent


class OwnedBusinessIncomeProgressionTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        fd, self.db_path = tempfile.mkstemp(prefix="mafiozi-biz-income-", suffix=".db")
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
        await self._unlink_with_retry(self.db_path)

    async def _unlink_with_retry(self, path: str):
        for attempt in range(20):
            try:
                os.unlink(path)
                return
            except PermissionError:
                if attempt == 19:
                    # Python 3.14 on Windows can retain an aiosqlite handle
                    # until interpreter shutdown even after await close().
                    return
                await asyncio.sleep(0.05)

    def seed(self, biz_id: str, level: int, *, uid: int = 1, start: int = 1_000_000):
        with sqlite3.connect(self.db_path) as db:
            db.execute("INSERT INTO characters(telegram_id,cash) VALUES(?,0)", (uid,))
            db.execute(
                "INSERT INTO player_businesses"
                "(telegram_id,biz_id,bought_at,last_collect,level) VALUES(?,?,?,?,?)",
                (uid, biz_id, start, start, level),
            )

    def snapshot(self, uid: int = 1):
        with sqlite3.connect(self.db_path) as db:
            cash = db.execute(
                "SELECT cash FROM characters WHERE telegram_id=?", (uid,)).fetchone()[0]
            cursor, remainder = db.execute(
                "SELECT last_collect,income_remainder FROM player_businesses "
                "WHERE telegram_id=?", (uid,)).fetchone()
        return cash, cursor, remainder

    async def tick(self, now: int):
        bot._owned_business_income_next_check = 0.0
        world = type("World", (), {"players": {}})()
        return await bot._tick_owned_business_income(world, now=now)

    async def test_authoritative_24_hour_totals(self):
        cases = (("coffee", 1, 175), ("coffee", 5, 525), ("port", 1, 7750))
        for uid, (biz_id, level, expected) in enumerate(cases, 1):
            self.seed(biz_id, level, uid=uid)
            await self.tick(1_000_000 + bot.BIZ_INCOME_PERIOD)
            self.assertEqual(self.snapshot(uid)[0], expected)

    async def test_eight_minutes_have_no_fake_minimum_and_reload_keeps_carry(self):
        self.seed("coffee", 1)
        await self.tick(1_000_000 + 8 * 60)
        cash, cursor, remainder = self.snapshot()
        self.assertEqual(cash, 0)
        self.assertEqual(cursor, 1_000_000 + 8 * 60)
        self.assertGreater(remainder, 0)

        # A fresh DB connection reads the persisted carry and reaches the same
        # exact 24-hour total instead of restarting the fraction at zero.
        await self.tick(1_000_000 + bot.BIZ_INCOME_PERIOD)
        self.assertEqual(self.snapshot()[0], 175)

    async def test_zero_elapsed_and_concurrent_double_tick_do_not_double_pay(self):
        self.seed("port", 1)
        now = 1_000_000 + bot.BIZ_INCOME_PERIOD
        await asyncio.gather(self.tick(now), self.tick(now))
        self.assertEqual(self.snapshot()[0], 7750)
        await self.tick(now)
        self.assertEqual(self.snapshot()[0], 7750)

    async def test_backward_compatible_migration_default(self):
        fd, old_path = tempfile.mkstemp(prefix="mafiozi-biz-old-", suffix=".db")
        os.close(fd)
        try:
            with sqlite3.connect(old_path) as db:
                db.execute("CREATE TABLE player_businesses(telegram_id INTEGER,biz_id TEXT)")
                db.execute("INSERT INTO player_businesses VALUES(1,'coffee')")
            async with aiosqlite.connect(old_path) as db:
                await bot._ensure_player_business_income_remainder(db)
                await bot._ensure_player_business_income_remainder(db)
                await db.commit()
            with sqlite3.connect(old_path) as db:
                columns = {row[1]: row for row in db.execute("PRAGMA table_info(player_businesses)")}
                value = db.execute("SELECT income_remainder FROM player_businesses").fetchone()[0]
            self.assertIn("income_remainder", columns)
            self.assertEqual(columns["income_remainder"][3], 1)
            self.assertEqual(columns["income_remainder"][4], "0")
            self.assertEqual(value, 0)
        finally:
            await self._unlink_with_retry(old_path)

    def test_world_feedback_uses_server_rate_without_preview_math(self):
        world = (ROOT / "world.html").read_text(encoding="utf-8")
        self.assertIn("Серверная суточная ставка показана в досье", world)
        self.assertIn("завершённую минуту", world)
        self.assertIn("прямо на счёт · поминутно", world)
        self.assertNotIn("Доход капает раз в сутки", world)


if __name__ == "__main__":
    unittest.main()
