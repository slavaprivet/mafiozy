import asyncio
import json
import os
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest import mock

import aiosqlite

os.environ.setdefault("BOT_TOKEN", "123456:starter-nagan-tests")

import mafiozi_bot as bot


ROOT = Path(__file__).resolve().parent


class StarterNaganProfileTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        retained = os.environ.get("CODEX_RETAIN_TEST_ARTIFACTS") == "1"
        if retained:
            base = Path(os.environ.get("CODEX_TEST_ARTIFACT_ROOT", ROOT))
            base.mkdir(parents=True, exist_ok=True)
            self.temp_path = Path(tempfile.mkdtemp(prefix="starter-nagan-", dir=base))
        else:
            self.temp_dir = tempfile.TemporaryDirectory()
            self.addCleanup(self.temp_dir.cleanup)
            self.temp_path = Path(self.temp_dir.name)
        self.db_path = str(self.temp_path / "starter.db")
        self.old_db_path = bot.DB_PATH
        bot.DB_PATH = self.db_path
        self.addCleanup(setattr, bot, "DB_PATH", self.old_db_path)
        async with aiosqlite.connect(self.db_path) as db:
            await db.executescript("""
                CREATE TABLE characters (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    telegram_id INTEGER UNIQUE,
                    username TEXT,
                    name TEXT,
                    class TEXT,
                    hp INTEGER DEFAULT 100,
                    max_hp INTEGER DEFAULT 100,
                    mana INTEGER DEFAULT 50,
                    max_mana INTEGER DEFAULT 50,
                    attack INTEGER DEFAULT 10,
                    defense INTEGER DEFAULT 5,
                    cash INTEGER DEFAULT 0,
                    weapon TEXT DEFAULT NULL,
                    look_json TEXT DEFAULT NULL
                );
                CREATE TABLE account_characters (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    account_id INTEGER NOT NULL,
                    character_id INTEGER UNIQUE,
                    slot INTEGER NOT NULL CHECK(slot BETWEEN 1 AND 3),
                    created_at INTEGER NOT NULL DEFAULT 0,
                    creation_token TEXT DEFAULT NULL,
                    UNIQUE(account_id,slot)
                );
                CREATE UNIQUE INDEX ux_account_character_creation_token
                    ON account_characters(account_id,creation_token)
                    WHERE creation_token IS NOT NULL;
                CREATE TABLE inventory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    telegram_id INTEGER,
                    item_id TEXT,
                    quantity INTEGER DEFAULT 1
                );
                CREATE UNIQUE INDEX ux_inventory_owner_item
                    ON inventory(telegram_id,item_id);
                CREATE TABLE weapon_ammo (
                    telegram_id INTEGER NOT NULL,
                    weapon_key TEXT NOT NULL,
                    magazine INTEGER NOT NULL DEFAULT 0,
                    next_fire_at REAL NOT NULL DEFAULT 0,
                    reload_id TEXT NOT NULL DEFAULT '',
                    reload_ready_at REAL NOT NULL DEFAULT 0,
                    version INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY(telegram_id,weapon_key)
                );
                CREATE TABLE ammo_reserve (
                    telegram_id INTEGER NOT NULL,
                    ammo_type TEXT NOT NULL,
                    rounds INTEGER NOT NULL DEFAULT 0,
                    version INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY(telegram_id,ammo_type)
                );
                CREATE TABLE weapon_ammo_versions (
                    telegram_id INTEGER PRIMARY KEY,
                    version INTEGER NOT NULL DEFAULT 0
                );
            """)
            await db.commit()

    def rows(self, sql, params=()):
        with closing(sqlite3.connect(self.db_path)) as db:
            return db.execute(sql, params).fetchall()

    async def create(self, account=101, token="starter-create-token-0001"):
        return await bot.create_account_profile(
            account, "Лука", {"gender": 0, "skin": 2}, token)

    async def test_new_profile_gets_one_equipped_dry_nagan(self):
        created = await self.create()
        uid = int(created["character_id"])
        self.assertFalse(created["replayed"])
        self.assertEqual(created["starter_weapon"], "nagan")
        self.assertTrue(created["starter_equipped"])
        self.assertEqual(self.rows(
            "SELECT weapon FROM characters WHERE telegram_id=?", (uid,)), [("nagan",)])
        self.assertEqual(self.rows(
            "SELECT item_id,quantity FROM inventory WHERE telegram_id=?", (uid,)),
            [("nagan", 1)])
        self.assertEqual(self.rows(
            "SELECT weapon_key,magazine,reload_id FROM weapon_ammo WHERE telegram_id=?",
            (uid,)), [("nagan", 0, "")])
        self.assertEqual(self.rows(
            "SELECT ammo_type,rounds FROM ammo_reserve WHERE telegram_id=?",
            (uid,)), [("magnum", 0)])
        self.assertEqual(created["ammo_state"]["mags"]["nagan"], 0)
        self.assertEqual(created["ammo_state"]["reserve"]["magnum"], 0)
        self.assertEqual(created["ammo_state"]["reloads"], {})

    async def test_dry_starter_does_not_auto_reload_or_create_ammo(self):
        created = await self.create(111, "starter-dry-token-0001")
        uid = int(created["character_id"])
        result = await bot.weapon_reload_transaction(
            uid, "nagan", "manual-reload-without-ammo", now=1000.0)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "no_ammo")
        self.assertEqual(result["ammo_state"]["mags"]["nagan"], 0)
        self.assertEqual(result["ammo_state"]["reserve"]["magnum"], 0)
        self.assertEqual(self.rows(
            "SELECT magazine,reload_id FROM weapon_ammo WHERE telegram_id=?", (uid,)),
            [(0, "")])

    async def test_same_token_replays_without_duplicate_or_ammo(self):
        first = await self.create(202, "starter-replay-token-0002")
        replay = await bot.create_account_profile(
            202, "Подмена", {"gender": 1, "skin": 5}, "starter-replay-token-0002")
        self.assertEqual(replay["character_id"], first["character_id"])
        self.assertTrue(replay["replayed"])
        self.assertEqual(replay["name"], "Лука")
        self.assertEqual(replay["look"]["skin"], 2)
        self.assertEqual(self.rows(
            "SELECT COUNT(*) FROM account_characters WHERE account_id=202"), [(1,)])
        self.assertEqual(self.rows("SELECT item_id,quantity FROM inventory"), [("nagan", 1)])
        self.assertEqual(self.rows("SELECT magazine FROM weapon_ammo"), [(0,)])
        self.assertEqual(self.rows("SELECT rounds FROM ammo_reserve"), [(0,)])

    async def test_concurrent_same_token_converges_to_one_profile(self):
        token = "starter-concurrent-token-0003"
        results = await asyncio.gather(*[
            bot.create_account_profile(303, "Сонни", {"body": 2}, token)
            for _ in range(4)
        ])
        self.assertEqual(len({row["character_id"] for row in results}), 1)
        self.assertEqual(sum(not row["replayed"] for row in results), 1)
        self.assertEqual(self.rows("SELECT COUNT(*) FROM account_characters"), [(1,)])
        self.assertEqual(self.rows("SELECT item_id,quantity FROM inventory"), [("nagan", 1)])
        self.assertEqual(self.rows("SELECT COUNT(*) FROM weapon_ammo"), [(1,)])
        self.assertEqual(self.rows("SELECT COUNT(*) FROM ammo_reserve"), [(1,)])

    async def test_distinct_concurrent_creations_are_private(self):
        results = await asyncio.gather(
            bot.create_account_profile(404, "Том", {"face": 1}, "starter-distinct-token-0004"),
            bot.create_account_profile(404, "Пол", {"face": 2}, "starter-distinct-token-0005"),
        )
        self.assertEqual(len({row["character_id"] for row in results}), 2)
        self.assertEqual(self.rows(
            "SELECT item_id,quantity FROM inventory ORDER BY telegram_id"),
            [("nagan", 1), ("nagan", 1)])
        self.assertEqual(self.rows(
            "SELECT weapon_key,magazine FROM weapon_ammo ORDER BY telegram_id"),
            [("nagan", 0), ("nagan", 0)])

    async def test_inventory_failure_rolls_back_everything(self):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                CREATE TRIGGER fail_starter BEFORE INSERT ON inventory
                WHEN NEW.item_id='nagan'
                BEGIN SELECT RAISE(ABORT,'forced starter failure'); END
            """)
            await db.commit()
        with self.assertRaises(sqlite3.IntegrityError):
            await self.create(505, "starter-rollback-token-0006")
        for table in ("account_characters", "characters", "inventory",
                      "weapon_ammo", "ammo_reserve"):
            self.assertEqual(self.rows(f"SELECT COUNT(*) FROM {table}"), [(0,)])

    async def test_delete_removes_starter_and_authoritative_ammo_rows(self):
        created = await self.create(606, "starter-delete-token-0007")
        uid = int(created["character_id"])
        self.assertTrue(await bot.delete_account_profile(606, uid))
        for table in ("account_characters", "characters", "inventory",
                      "weapon_ammo", "ammo_reserve"):
            self.assertEqual(self.rows(f"SELECT COUNT(*) FROM {table}"), [(0,)])

    def test_profile_actor_must_match_authenticated_telegram_account(self):
        with mock.patch.object(
                bot, "verify_telegram_init_data", return_value={"id": 707}) as verify:
            self.assertEqual(bot.verified_profile_account("signed", "707"), 707)
            verify.assert_called_once_with("signed", expected_uid=707)
        with mock.patch.object(
                bot, "verify_telegram_init_data", side_effect=ValueError("mismatch")):
            with self.assertRaisesRegex(ValueError, "mismatch"):
                bot.verified_profile_account("wrong", "707")

    def test_client_catalog_and_schema_contract_is_explicit(self):
        creator = (ROOT / "creator.html").read_text(encoding="utf-8")
        world = (ROOT / "world.html").read_text(encoding="utf-8")
        backend = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
        self.assertIn("payload.creation_token = profileCreationToken()", creator)
        self.assertIn("result.profile?.starter_equipped", creator)
        self.assertIn("X-Telegram-Init-Data", creator)
        self.assertIn("mafiozi_profile_creation_confirmed_v1_", creator)
        self.assertIn("Стартовый Наган выдан и уже в руках", world)
        self.assertIn("j.equipped_weapon==='nagan'", world)
        self.assertIn("_applyAuthoritativeAmmoState(j.ammo_state)", world)
        self.assertIn("ux_account_character_creation_token", backend)
        self.assertIn("profile_route = path.startswith('/profiles/')", backend)
        self.assertIn("verified_profile_account(", backend)
        self.assertIn("if iid == PROFILE_STARTER_WEAPON", backend)
        self.assertIn("if item_id == PROFILE_STARTER_WEAPON", backend)
        self.assertIn("ammo_state = await get_authoritative_ammo_state(uid)", backend)
        self.assertIn("INSERT INTO weapon_ammo", backend)
        self.assertIn("INSERT INTO ammo_reserve", backend)
        self.assertNotIn("sell_price", bot.ITEMS["nagan"])
        self.assertIn("const response=await _apiRequest(`${QP.api}/profiles/", world)
        self.assertIn("localStorage.removeItem(receiptKey)", world)


if __name__ == "__main__":
    unittest.main()
