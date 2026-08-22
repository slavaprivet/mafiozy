import asyncio
import os
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest import mock


os.environ.setdefault("BOT_TOKEN", "123456:test-token")
import aiosqlite
import mafiozi_bot as bot


ROOT = Path(__file__).resolve().parent


class SteamIdentityRuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        retained = os.environ.get("CODEX_RETAIN_TEST_ARTIFACTS") == "1"
        root = Path(os.environ.get("CODEX_TEST_ARTIFACT_ROOT", tempfile.gettempdir()))
        root.mkdir(parents=True, exist_ok=True)
        self.temp = Path(tempfile.mkdtemp(prefix="steam_identity_", dir=root))
        self.db_path = str(self.temp / "steam.db")
        self.old_db = bot.DB_PATH
        bot.DB_PATH = self.db_path
        self.retained = retained
        async with aiosqlite.connect(self.db_path) as db:
            await db.executescript("""
                CREATE TABLE characters (
                    telegram_id INTEGER PRIMARY KEY,
                    name TEXT DEFAULT 'QA'
                );
                CREATE TABLE account_characters (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    account_id INTEGER NOT NULL,
                    character_id INTEGER UNIQUE,
                    slot INTEGER NOT NULL,
                    created_at INTEGER NOT NULL DEFAULT 0,
                    creation_token TEXT DEFAULT NULL,
                    UNIQUE(account_id,slot)
                );
                CREATE TABLE identity_account_sequence (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    created_at INTEGER NOT NULL
                );
                CREATE TABLE account_identities (
                    provider TEXT NOT NULL,
                    provider_subject TEXT NOT NULL,
                    account_id INTEGER NOT NULL UNIQUE,
                    created_at INTEGER NOT NULL,
                    PRIMARY KEY(provider,provider_subject)
                );
                CREATE TABLE auth_sessions (
                    token_hash TEXT PRIMARY KEY,
                    account_id INTEGER NOT NULL,
                    provider TEXT NOT NULL,
                    selected_character_id INTEGER NOT NULL DEFAULT 0,
                    created_at INTEGER NOT NULL,
                    expires_at INTEGER NOT NULL
                );
                CREATE TABLE ws_auth_tickets (
                    ticket_hash TEXT PRIMARY KEY,
                    account_id INTEGER NOT NULL,
                    character_id INTEGER NOT NULL,
                    created_at INTEGER NOT NULL,
                    expires_at INTEGER NOT NULL,
                    consumed_at INTEGER DEFAULT NULL
                );
            """)
            await db.commit()

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_db
        if not self.retained:
            for path in self.temp.iterdir():
                path.unlink()
            self.temp.rmdir()

    def rows(self, sql, params=()):
        with closing(sqlite3.connect(self.db_path)) as db:
            return db.execute(sql, params).fetchall()

    async def bind_character(self, account_id, character_id):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("INSERT INTO characters(telegram_id) VALUES(?)", (character_id,))
            await db.execute(
                "INSERT INTO account_characters(account_id,character_id,slot) VALUES(?,?,1)",
                (account_id, character_id))
            await db.commit()

    async def test_server_validates_mocked_steam_ticket(self):
        payload = {"response": {"params": {
            "steamid": "76561198000000001", "ownersteamid": "76561198000000001",
            "vacbanned": False, "publisherbanned": False,
        }}}
        with mock.patch.object(bot, "_steam_ticket_request", return_value=payload) as request:
            identity = await bot.validate_steam_ticket("A" * 64)
        self.assertEqual(identity, {"provider": "steam", "subject": "76561198000000001"})
        request.assert_called_once_with("A" * 64)
        payload["response"]["params"]["ownersteamid"] = "76561198000000002"
        with mock.patch.object(bot, "_steam_ticket_request", return_value=payload):
            with self.assertRaisesRegex(ValueError, "rejected"):
                await bot.validate_steam_ticket("B" * 64)

    async def test_stable_mapping_creates_no_character(self):
        first = await bot.resolve_provider_account("steam", "76561198000000003")
        second = await bot.resolve_provider_account("steam", "76561198000000003")
        self.assertEqual(first, second)
        self.assertGreaterEqual(first, bot.STEAM_ACCOUNT_ID_BASE + 1)
        self.assertEqual(self.rows("SELECT COUNT(*) FROM characters"), [(0,)])
        self.assertEqual(self.rows("SELECT COUNT(*) FROM account_characters"), [(0,)])

    async def test_concurrent_mapping_converges_without_character_creation(self):
        accounts = await asyncio.gather(*(
            bot.resolve_provider_account("steam", "76561198000000009")
            for _ in range(10)))
        self.assertEqual(len(set(accounts)), 1)
        self.assertEqual(self.rows("SELECT COUNT(*) FROM account_identities"), [(1,)])
        self.assertEqual(self.rows("SELECT COUNT(*) FROM characters"), [(0,)])

    async def test_bearer_session_is_hashed_and_character_bound(self):
        account = await bot.resolve_provider_account("steam", "76561198000000004")
        await self.bind_character(account, 800000000001004)
        with mock.patch.object(bot, "validate_steam_ticket", return_value={
                "provider": "steam", "subject": "76561198000000004"}):
            session = await bot.create_steam_bearer_session(
                "C" * 64, 800000000001004, now=100)
        stored = self.rows("SELECT token_hash,selected_character_id FROM auth_sessions")[0]
        self.assertNotEqual(stored[0], session["bearer"])
        self.assertEqual(len(stored[0]), 64)
        self.assertEqual(stored[1], 800000000001004)
        verified = await bot.verify_bearer_session(
            "Bearer " + session["bearer"], now=101)
        self.assertEqual(verified["account_id"], account)
        with self.assertRaisesRegex(ValueError, "expired"):
            await bot.verify_bearer_session(
                "Bearer " + session["bearer"], now=100 + bot.STEAM_SESSION_TTL)

    async def test_provider_disagreement_and_raw_uid_fallback_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing authenticated"):
            await bot.resolve_request_identity({}, expected_account=123)
        steam = {"account_id": 123, "provider": "steam", "selected_character_id": 0}
        with (mock.patch.object(bot, "verify_bearer_session", return_value=steam),
              mock.patch.object(bot, "verified_profile_account", return_value=456)):
            with self.assertRaisesRegex(ValueError, "disagreement"):
                await bot.resolve_request_identity({
                    "Authorization": "Bearer " + "x" * 48,
                    "X-Telegram-Init-Data": "signed",
                }, expected_account=123)

    async def test_ws_ticket_is_atomic_one_use_bound_and_expires(self):
        account = await bot.resolve_provider_account("steam", "76561198000000005")
        uid = 800000000001005
        await self.bind_character(account, uid)
        issued = await bot.issue_steam_ws_ticket(account, uid, now=200)
        claims = await bot.consume_steam_ws_ticket(issued["ws_ticket"], uid, now=201)
        self.assertEqual((claims["account_id"], claims["character_id"]), (account, uid))
        with self.assertRaisesRegex(ValueError, "invalid websocket"):
            await bot.consume_steam_ws_ticket(issued["ws_ticket"], uid, now=202)

        mismatch = await bot.issue_steam_ws_ticket(account, uid, now=300)
        with self.assertRaisesRegex(ValueError, "invalid websocket"):
            await bot.consume_steam_ws_ticket(mismatch["ws_ticket"], uid + 1, now=301)
        expired = await bot.issue_steam_ws_ticket(account, uid, now=400)
        with self.assertRaisesRegex(ValueError, "invalid websocket"):
            await bot.consume_steam_ws_ticket(
                expired["ws_ticket"], uid, now=400 + bot.STEAM_WS_TICKET_TTL)

    async def test_ws_ticket_concurrency_has_exactly_one_winner(self):
        account = await bot.resolve_provider_account("steam", "76561198000000006")
        uid = 800000000001006
        await self.bind_character(account, uid)
        issued = await bot.issue_steam_ws_ticket(account, uid, now=500)

        async def consume():
            try:
                await bot.consume_steam_ws_ticket(issued["ws_ticket"], uid, now=501)
                return True
            except ValueError:
                return False

        results = await asyncio.gather(*(consume() for _ in range(12)))
        self.assertEqual(sum(results), 1)

    def test_source_contract_preserves_telegram_starter_and_client_paths(self):
        backend = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
        world = (ROOT / "world.html").read_text(encoding="utf-8")
        self.assertIn("verified_profile_account(init_data, expected_account)", backend)
        self.assertIn("steam_creator_handoff_required", backend)
        self.assertIn("creation_token", backend)
        self.assertIn("PROFILE_STARTER_WEAPON", backend)
        self.assertIn("Authorization", backend)
        self.assertIn("consume_steam_ws_ticket(steam_ticket, uid_int)", backend)
        self.assertIn("verify_world_token(world_token, expected_uid=uid)", backend)
        self.assertIn("_ensureSteamSession(true)", world)
        self.assertIn("headers.Authorization=`Bearer ${_steamSession.bearer}`", world)
        self.assertIn("params.set('ws_ticket'", world)
        self.assertIn("params.set('world_token'", world)
        self.assertIn("startDirectWorldCombatDemo()", world)
        self.assertNotIn("localStorage.setItem(_steamSessionKey", world)


if __name__ == "__main__":
    unittest.main()
