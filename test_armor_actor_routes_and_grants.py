"""Runtime P0 contracts for actor-bound HP routes and post-start armor grants."""

import asyncio
import hashlib
import hmac
import json
import os
import tempfile
import time
import unittest
import urllib.parse
from pathlib import Path
from unittest import mock

import aiosqlite

os.environ.setdefault("BOT_TOKEN", "123456:armor-authority-tests")

import mafiozi_bot as bot


TEST_TOKEN = "123456:armor-authority-tests"
HUB_SOURCE = (Path(__file__).resolve().parent / "hub.html").read_text(
    encoding="utf-8")


def signed_init_data(uid: int, *, auth_date: int | None = None) -> str:
    fields = {
        "auth_date": str(int(time.time()) if auth_date is None else int(auth_date)),
        "query_id": f"route-test-{uid}",
        "user": json.dumps({"id": uid, "first_name": "Owner"}, separators=(",", ":")),
    }
    check = "\n".join(f"{key}={fields[key]}" for key in sorted(fields))
    secret = hmac.new(b"WebAppData", TEST_TOKEN.encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret, check.encode(), hashlib.sha256).hexdigest()
    return urllib.parse.urlencode(fields)


async def capture_production_app():
    """Build the real aiohttp app while replacing only its listening site."""
    from aiohttp import web

    captured = {}

    class CaptureRunner:
        def __init__(self, app):
            captured["app"] = app

        async def setup(self):
            return None

    class NoopSite:
        def __init__(self, runner, host, port):
            self.runner = runner

        async def start(self):
            return None

    with mock.patch.object(web, "AppRunner", CaptureRunner), mock.patch.object(
        web, "TCPSite", NoopSite
    ):
        await bot._coop_http_app()
    return captured["app"]


class ArmorActorRouteTests(unittest.IsolatedAsyncioTestCase):
    def test_hub_sends_actor_proof_to_protected_event_route(self):
        self.assertIn(
            "'X-Telegram-Init-Data': tg?.initData || ''", HUB_SOURCE)

    async def asyncSetUp(self):
        from aiohttp.test_utils import TestClient, TestServer

        self.temp = tempfile.TemporaryDirectory()
        self.old_db_path = bot.DB_PATH
        bot.DB_PATH = os.path.join(self.temp.name, "actor-routes.db")
        await bot.init_db()
        self.uid = 710_001
        async with aiosqlite.connect(bot.DB_PATH) as db:
            await db.execute(
                """INSERT INTO characters
                   (telegram_id,name,class,hp,max_hp,mana,max_mana,cash,combat_version)
                   VALUES(?,?,'fixer',100,100,50,50,500,0)""",
                (self.uid, "Route Owner"),
            )
            await db.commit()
        self.client = TestClient(TestServer(await capture_production_app()))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()
        bot.DB_PATH = self.old_db_path
        self.temp.cleanup()

    async def _event(self, init_data=None):
        headers = {}
        if init_data is not None:
            headers["X-Telegram-Init-Data"] = init_data
        return await self.client.post(
            f"/event/{self.uid}/tick", json={"post_battle": True}, headers=headers
        )

    async def test_event_route_rejects_missing_tampered_foreign_and_expired_actor(self):
        current = int(time.time())
        valid = signed_init_data(self.uid, auth_date=current)
        attempts = {
            "missing": None,
            "tampered": valid.replace("Owner", "Attacker"),
            "foreign": signed_init_data(self.uid + 1, auth_date=current),
            "expired": signed_init_data(self.uid, auth_date=current - 901),
        }
        with mock.patch.object(bot.random, "random", return_value=1.0):
            for label, init_data in attempts.items():
                with self.subTest(label=label):
                    response = await self._event(init_data)
                    self.assertEqual(response.status, 401, await response.text())
                    payload = await response.json()
                    self.assertFalse(payload["ok"])
                    self.assertEqual(payload["error"], "unauthorized")

    async def test_valid_owner_event_hp_is_durable_versioned_canonical_state(self):
        event = {
            "id": "route-authority-hit",
            "text": "Server event damage",
            "effects": {"hp": -10},
        }
        with mock.patch.object(bot.random, "random", return_value=0.0), mock.patch.object(
            bot, "pick_post_battle_event", return_value=event
        ):
            response = await self._event(signed_init_data(self.uid))
        self.assertEqual(response.status, 200, await response.text())
        payload = await response.json()
        state = payload["combat_state"]
        self.assertEqual(
            state,
            {
                "body": {"current": 90, "max": 100, "dead": False},
                "armor": {
                    "id": None,
                    "instance_id": None,
                    "current": 0,
                    "max": 0,
                    "version": 1,
                    "broken": False,
                },
                "combat_version": 1,
            },
        )
        async with aiosqlite.connect(bot.DB_PATH) as db:
            row = await (
                await db.execute(
                    "SELECT hp,combat_version FROM characters WHERE telegram_id=?",
                    (self.uid,),
                )
            ).fetchone()
        self.assertEqual(tuple(row), (90, 1))

    async def test_event_and_world_damage_serialize_without_lost_update(self):
        await asyncio.gather(
            bot.apply_damage_transaction(
                self.uid, "route-race:bullet", "bullet", 20),
            bot.apply_hub_event_effects_transaction(
                self.uid, {"hp": -10}, int(time.time())),
        )
        state = await bot.get_authoritative_combat_state(self.uid)
        self.assertEqual(state["body"]["current"], 70)
        self.assertEqual(state["combat_version"], 2)


class ArmorGrantTransactionTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.old_db_path = bot.DB_PATH
        bot.DB_PATH = os.path.join(self.temp.name, "armor-grants.db")
        await bot.init_db()
        self.owner, self.other = 720_001, 720_002
        async with aiosqlite.connect(bot.DB_PATH) as db:
            for uid in (self.owner, self.other):
                await db.execute(
                    """INSERT INTO characters
                       (telegram_id,name,class,hp,max_hp,cash,combat_version)
                       VALUES(?,?,'fixer',100,100,500,0)""",
                    (uid, f"Owner {uid}"),
                )
            await db.commit()

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_db_path
        self.temp.cleanup()

    async def _armor_row(self, uid):
        async with aiosqlite.connect(bot.DB_PATH) as db:
            return await (
                await db.execute(
                    """SELECT quantity,armor_hp,armor_max_hp,armor_version,
                              armor_instance_id
                         FROM inventory WHERE telegram_id=? AND item_id='bulletproof'""",
                    (uid,),
                )
            ).fetchone()

    async def test_post_start_armor_grant_creates_fresh_condition_generation(self):
        await bot.add_item(self.owner, "bulletproof")
        row = await self._armor_row(self.owner)
        self.assertIsNotNone(row)
        self.assertEqual(tuple(row[:4]), (1, 65, 65, 1))
        self.assertTrue(isinstance(row[4], str) and len(row[4]) >= 16)

    async def test_duplicate_armor_grant_is_idempotent_and_does_not_repair(self):
        await bot.add_item(self.owner, "bulletproof")
        before = await self._armor_row(self.owner)
        async with aiosqlite.connect(bot.DB_PATH) as db:
            await db.execute(
                """UPDATE inventory SET armor_hp=17,armor_version=4
                     WHERE telegram_id=? AND item_id='bulletproof'""",
                (self.owner,),
            )
            await db.commit()
        await bot.add_item(self.owner, "bulletproof")
        after = await self._armor_row(self.owner)
        self.assertEqual(after[0], 1)
        self.assertEqual(after[1], 17)
        self.assertEqual(after[2], 65)
        self.assertEqual(after[3], 4)
        self.assertEqual(after[4], before[4])

    async def test_grant_is_owner_isolated(self):
        await bot.add_item(self.owner, "bulletproof")
        self.assertIsNotNone(await self._armor_row(self.owner))
        self.assertIsNone(await self._armor_row(self.other))

    async def test_grant_rolls_back_failed_insert(self):
        async with aiosqlite.connect(bot.DB_PATH) as db:
            await db.execute(
                f"""CREATE TRIGGER fail_grant AFTER INSERT ON inventory
                    WHEN NEW.telegram_id={self.owner} AND NEW.item_id='bulletproof'
                    BEGIN SELECT RAISE(ABORT, 'forced armor grant rollback'); END"""
            )
            await db.commit()
        with self.assertRaises(aiosqlite.IntegrityError):
            await bot.add_item(self.owner, "bulletproof")
        self.assertIsNone(await self._armor_row(self.owner))


if __name__ == "__main__":
    unittest.main()
