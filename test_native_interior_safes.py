import asyncio
from contextlib import closing
from dataclasses import replace
import json
from pathlib import Path
import sqlite3
import tempfile
import time
import unittest

from native_interior_safes import (NativeInteriorSafeService, NativeSafeAuthority,
                                   canonical_safe_id, default_safe_reward, load_safe_registry)


BUILDING = "hotel_01"
ROOM = BUILDING + ":floor:1:room:0"
SAFE = "interior-safe:" + ROOM
MANIFEST = {"version": 1, "safes": [{"id": SAFE, "buildingId": BUILDING,
    "roomId": ROOM, "purpose": "hotel", "position": [10, 3.4, 20], "reward": 57}]}


class NativeInteriorSafeTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "state.db"
        with closing(sqlite3.connect(self.db_path)) as db, db:
            db.execute("CREATE TABLE characters (telegram_id INTEGER PRIMARY KEY, cash INTEGER)")
            db.executemany("INSERT INTO characters VALUES(?,?)", [(111, 100), (222, 250)])
        self.registry = load_safe_registry(MANIFEST)

    def tearDown(self):
        self.temp.cleanup()

    def authority(self, uid, safe):
        return NativeSafeAuthority(uid, True, (10, 3.4, 22), "merc:owned", True, True,
            "safecracker", (10, 3.4, 21), BUILDING, ROOM, True, time.time())

    def service(self, authority=None):
        return NativeInteriorSafeService(self.db_path, registry=self.registry,
                                         resolve_authority=authority)

    async def unlock(self, service, uid="111", **extra):
        return await service.unlock(uid, safe_id=SAFE, building_id=BUILDING,
            room_id=ROOM, request_id=SAFE + ":unlock", **extra)

    def balances(self):
        with closing(sqlite3.connect(self.db_path)) as db, db:
            return dict(db.execute("SELECT telegram_id,cash FROM characters"))

    async def test_atomic_global_first_award_replay_and_restart(self):
        service = self.service(self.authority)
        before = await service.hydrate("111", safe_ids=[SAFE])
        self.assertFalse(before["safes"][0]["opened"])
        first = await self.unlock(service)
        self.assertTrue(first["ok"])
        self.assertTrue(first["opened"])
        self.assertTrue(first["collected"])
        self.assertEqual(first["gained"], 57)
        self.assertEqual(first["cash"], 157)
        restored = self.service()  # Replays do not need a second profession action.
        second = await self.unlock(restored)
        other = await self.unlock(restored, "222")
        self.assertTrue(second["duplicate"])
        self.assertEqual(second["gained"], 0)
        self.assertEqual(other["gained"], 0)
        self.assertEqual(other["cash"], 250)
        self.assertEqual(self.balances(), {111: 157, 222: 250})
        states = await restored.hydrate("222", safe_ids=[SAFE])
        self.assertTrue(states["safes"][0]["collected"])
        self.assertNotIn("cash", states["safes"][0])
        with closing(sqlite3.connect(self.db_path)) as db, db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM native_interior_safe_rewards").fetchone()[0], 1)

    async def test_parallel_instances_and_users_cannot_double_pay(self):
        services = [self.service(self.authority) for _ in range(8)]
        receipts = await asyncio.gather(*(self.unlock(s, "111" if i % 2 else "222")
                                         for i, s in enumerate(services)))
        self.assertTrue(all(r["ok"] for r in receipts))
        self.assertEqual(sum(r["gained"] for r in receipts), 57)
        self.assertEqual(sum(not r["duplicate"] for r in receipts), 1)
        self.assertEqual(sum(self.balances().values()), 407)

    async def test_client_claims_never_authorize_profession_position_or_money(self):
        service = self.service()
        forged = {"action": "unlock", "safeId": SAFE, "buildingId": BUILDING,
            "roomId": ROOM, "requestId": SAFE + ":unlock", "profession": "safecracker",
            "mercenary_authorized": True, "cash": 100000, "reward": 100000,
            "position": [10, 3.4, 20], "now": time.time(), "registry": MANIFEST}
        reply = await service.handle("111", forged)
        self.assertEqual(reply["reason"], "mercenary_not_authorized")
        self.assertEqual(self.balances(), {111: 100, 222: 250})
        dict_authority = self.service(lambda *_: {"user_id": "111", "mercenary_authorized": True})
        self.assertEqual((await self.unlock(dict_authority))["reason"], "mercenary_not_authorized")

    async def test_authority_checks_freshness_life_profession_room_path_and_elevation(self):
        cases = [({"user_id": "222"}, "mercenary_not_authorized"),
            ({"mercenary_authorized": False}, "mercenary_not_authorized"),
            ({"mercenary_profession": "medic"}, "mercenary_not_authorized"),
            ({"player_alive": False}, "actor_unavailable"),
            ({"mercenary_alive": False}, "actor_unavailable"),
            ({"observed_at": time.time() - 10}, "stale_authority"),
            ({"mercenary_room_id": "wrong"}, "safe_not_reachable"),
            ({"clear_path": False}, "safe_not_reachable"),
            ({"mercenary_position": (10, 0, 20)}, "too_far"),
            ({"mercenary_position": (15, 3.4, 20)}, "too_far"),
            ({"player_position": (30, 3.4, 20)}, "too_far"),
            ({"mercenary_position": (float("nan"), 3.4, 20)}, "position_not_authorized")]
        for changes, reason in cases:
            with self.subTest(changes=changes):
                service = self.service(lambda uid, safe: replace(self.authority(uid, safe), **changes))
                self.assertEqual((await self.unlock(service))["reason"], reason)
        self.assertEqual(self.balances(), {111: 100, 222: 250})

    async def test_database_failure_rolls_back_open_state_and_reward(self):
        service = self.service(self.authority)
        await service.hydrate("111", safe_ids=[SAFE])
        with closing(sqlite3.connect(self.db_path)) as db, db:
            db.execute("CREATE TRIGGER reject_cash BEFORE UPDATE OF cash ON characters BEGIN SELECT RAISE(ABORT, 'test failure'); END")
        with self.assertRaises(sqlite3.IntegrityError):
            await self.unlock(service)
        state = await service.hydrate("111", safe_ids=[SAFE])
        self.assertFalse(state["safes"][0]["opened"])
        with closing(sqlite3.connect(self.db_path)) as db, db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM native_interior_safe_rewards").fetchone()[0], 0)
            db.execute("DROP TRIGGER reject_cash")
        self.assertTrue((await self.unlock(service))["ok"])

    async def test_collect_is_already_paid_and_duplicate_cash_is_current(self):
        service = self.service(self.authority)
        request = dict(safe_id=SAFE, building_id=BUILDING, room_id=ROOM, request_id=SAFE + ":collect")
        self.assertEqual((await service.collect("111", **request))["reason"], "locked")
        await self.unlock(service)
        with closing(sqlite3.connect(self.db_path)) as db, db:
            db.execute("UPDATE characters SET cash=cash+12 WHERE telegram_id=111")
        result = await service.collect("111", **request)
        self.assertEqual(result["cash"], 169)
        self.assertEqual(result["gained"], 0)
        self.assertTrue(result["duplicate"])

    async def test_unknown_ids_bad_identity_and_request_keys_do_not_mutate(self):
        service = self.service(self.authority)
        for uid in ["0", "-1", "not-authenticated"]:
            self.assertEqual((await self.unlock(service, uid))["reason"], "unauthorized")
        self.assertEqual((await self.unlock(service, "333"))["reason"], "no_character")
        self.assertEqual((await service.handle("111", {"action": "unlock", "safeId": "invented"}))["reason"], "unknown_safe")
        self.assertEqual((await service.unlock("111", safe_id=SAFE, building_id=BUILDING,
            room_id=ROOM, request_id="arbitrary"))["reason"], "invalid_request_id")
        self.assertEqual((await service.hydrate("111", safe_ids=[SAFE] * 129))["reason"], "unknown_safe")

    def test_manifest_ids_positions_and_reward_are_canonical(self):
        self.assertEqual(canonical_safe_id(BUILDING, ROOM), SAFE)
        self.assertEqual(self.registry[SAFE].reward, 57)
        self.assertEqual(default_safe_reward(SAFE), 80)  # Shared JS/Python fixture.
        for mutate in [lambda r: r.update(id="fake"), lambda r: r.update(roomId="wrong"),
                       lambda r: r.update(position=[10, float("nan"), 20]),
                       lambda r: r.update(reward=-1), lambda r: r.update(purpose="fake")]:
            manifest = json.loads(json.dumps(MANIFEST))
            mutate(manifest["safes"][0])
            with self.assertRaises(ValueError):
                load_safe_registry(manifest)
        with self.assertRaises(ValueError):
            load_safe_registry({"version": 1, "safes": MANIFEST["safes"] * 2})


if __name__ == "__main__":
    unittest.main()
