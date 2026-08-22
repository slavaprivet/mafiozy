import asyncio
import os
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

import mafiozi_bot as bot


ROOT = Path(__file__).resolve().parent


class BuildingLootEconomyTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        fd, self.db_path = tempfile.mkstemp(prefix="mafiozi-loot-", suffix=".db")
        os.close(fd)
        self.old_db_path = bot.DB_PATH
        bot.DB_PATH = self.db_path
        with closing(sqlite3.connect(self.db_path)) as db:
            db.execute(
                """CREATE TABLE characters (
                    telegram_id INTEGER PRIMARY KEY,
                    cash INTEGER DEFAULT 0,
                    building_loot_at INTEGER DEFAULT 0,
                    building_loot_probe_at INTEGER DEFAULT 0,
                    building_loot_claim_token TEXT DEFAULT NULL,
                    building_loot_claim_amount INTEGER DEFAULT 0,
                    building_loot_claim_expires INTEGER DEFAULT 0,
                    building_loot_claimed_at INTEGER DEFAULT 0
                )"""
            )
            db.execute("INSERT INTO characters(telegram_id,cash) VALUES(?,?)", (101, 0))
            db.commit()

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_db_path
        for attempt in range(10):
            try:
                os.unlink(self.db_path)
                break
            except PermissionError:
                if attempt == 9:
                    raise
                await asyncio.sleep(0.05)

    async def test_probe_is_server_priced_and_survives_reload(self):
        first = await bot.probe_building_loot(
            101, now=1_000, chance_roll=lambda: 0.0,
            amount_roll=lambda low, high: 80, claim_token="claim-A",
        )
        self.assertEqual(
            {k: first[k] for k in ("ok", "found", "amount", "claim_token", "resumed")},
            {"ok": True, "found": True, "amount": 80,
             "claim_token": "claim-A", "resumed": False},
        )

        resumed = await bot.probe_building_loot(
            101, now=1_010, chance_roll=lambda: 0.99,
            amount_roll=lambda low, high: 15, claim_token="different",
        )
        self.assertTrue(resumed["resumed"])
        self.assertEqual(resumed["claim_token"], "claim-A")
        self.assertEqual(resumed["amount"], 80)

    async def test_parallel_and_reload_claims_credit_once(self):
        await bot.probe_building_loot(
            101, now=2_000, chance_roll=lambda: 0.0,
            amount_roll=lambda low, high: 80, claim_token="claim-B",
        )
        results = await asyncio.gather(
            bot.claim_building_loot(101, "claim-B", now=2_001),
            bot.claim_building_loot(101, "claim-B", now=2_001),
        )
        self.assertEqual(sorted(r["duplicate"] for r in results), [False, True])
        self.assertEqual({r["amount"] for r in results}, {80})
        self.assertEqual({r["cash"] for r in results}, {80})

        after_reload = await bot.claim_building_loot(101, "claim-B", now=2_002)
        self.assertTrue(after_reload["duplicate"])
        self.assertEqual(after_reload["cash"], 80)
        with closing(sqlite3.connect(self.db_path)) as db:
            self.assertEqual(db.execute(
                "SELECT cash FROM characters WHERE telegram_id=101").fetchone()[0], 80)

    async def test_invalid_expired_and_cooldown_paths_never_credit(self):
        await bot.probe_building_loot(
            101, now=3_000, chance_roll=lambda: 0.0,
            amount_roll=lambda low, high: 15, claim_token="claim-C",
        )
        invalid = await bot.claim_building_loot(101, "client-value", now=3_001)
        self.assertEqual(invalid, {"ok": False, "error": "invalid claim"})
        expired = await bot.claim_building_loot(
            101, "claim-C", now=3_000 + bot.BUILDING_LOOT_CLAIM_TTL_S + 1)
        self.assertEqual(expired, {"ok": False, "error": "expired claim"})
        with closing(sqlite3.connect(self.db_path)) as db:
            self.assertEqual(db.execute(
                "SELECT cash FROM characters WHERE telegram_id=101").fetchone()[0], 0)

        miss = await bot.probe_building_loot(
            101, now=3_000 + bot.BUILDING_LOOT_CLAIM_TTL_S + 2,
            chance_roll=lambda: 0.99,
        )
        self.assertFalse(miss["found"])
        cooldown = await bot.probe_building_loot(
            101, now=miss["next_probe_at"] - 1, chance_roll=lambda: 0.0)
        self.assertFalse(cooldown["found"])
        self.assertEqual(cooldown["cooldown"], 1)

    def test_world_client_has_no_optimistic_cash_or_client_amount(self):
        world = (ROOT / "world.html").read_text(encoding="utf-8")
        bot_source = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
        self.assertNotIn("JSON.stringify({ amount: lt.amount })", world)
        self.assertIn("JSON.stringify({action:'probe'})", world)
        self.assertIn("JSON.stringify({action:'claim',claim_token:lt.claimToken})", world)
        self.assertIn("path.startswith('/world/loot/')", bot_source)
        self.assertIn("player not in building", bot_source)


if __name__ == "__main__":
    unittest.main()
