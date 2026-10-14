import asyncio
import importlib.util
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

ROOT = Path(__file__).resolve().parent
BOT_SOURCE = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
_IMPORT_SANDBOX = tempfile.TemporaryDirectory(
    prefix="mafiozi-vehicle-explosion-test-")
_IMPORT_ROOT = Path(_IMPORT_SANDBOX.name)
_IMPORT_SOURCE = _IMPORT_ROOT / "mafiozi_bot.py"
shutil.copy2(ROOT / "mafiozi_bot.py", _IMPORT_SOURCE)
_SPEC = importlib.util.spec_from_file_location(
    "mafiozi_bot_vehicle_explosion_test", _IMPORT_SOURCE)
if _SPEC is None or _SPEC.loader is None:
    raise RuntimeError("cannot load isolated mafiozi_bot test module")
game = importlib.util.module_from_spec(_SPEC)
_ENV_BEFORE_IMPORT = {
    key: os.environ.get(key) for key in ("BOT_TOKEN", "DB_DIR")
}
with patch.dict(os.environ, {
        "BOT_TOKEN": "123456:vehicle-explosion-test",
        "DB_DIR": str(_IMPORT_ROOT),
}, clear=False):
    _SPEC.loader.exec_module(game)
if {key: os.environ.get(key) for key in _ENV_BEFORE_IMPORT} != _ENV_BEFORE_IMPORT:
    raise RuntimeError("isolated mafiozi_bot import leaked environment")


def tearDownModule():
    _IMPORT_SANDBOX.cleanup()


def _world():
    world = game.WorldSim()
    for uid in ("101", "202", "303", "999"):
        world.add_or_update(uid, f"Player {uid}", {})
        world.players[uid].update(hp=100, max_hp=100, dead=False)
    world.quest_cars["car-7"] = {
        "id": "car-7", "owner_uid": "101", "driver_uid": "101",
        "passenger_uids": ["202", "303"], "hp": 40, "max_hp": 40,
        "x": 12.0, "y": 18.0, "vx": 3.0, "vy": 0.0,
        "state": "drive", "wrecked": False,
    }
    return world


class VehicleExplosionOccupantServerTests(unittest.TestCase):
    def setUp(self):
        self._lethal_enabled = game.VEHICLE_EXPLOSION_OCCUPANT_LETHAL_ENABLED
        # Exercise the isolated candidate contract explicitly.  Production is
        # intentionally gated off until the server admits a physical event.
        game.VEHICLE_EXPLOSION_OCCUPANT_LETHAL_ENABLED = True

    def tearDown(self):
        game.VEHICLE_EXPLOSION_OCCUPANT_LETHAL_ENABLED = self._lethal_enabled

    def test_production_lethal_delivery_is_gated_without_physical_admission(self):
        async def scenario():
            world = _world()
            confirmed = world.gta_crash("101", "car-7", 100, "wall")
            game.VEHICLE_EXPLOSION_OCCUPANT_LETHAL_ENABLED = False
            damage = AsyncMock(return_value={"replayed": False})
            with patch.object(
                    game.WorldSim, "apply_authoritative_damage_bound_projectile",
                    damage):
                result = await world.deliver_vehicle_explosion_occupants(
                    "car-7", confirmed["explosion_event_id"])
            self.assertEqual(result, {
                "accepted": False,
                "reason": "server-physical-admission-required",
            })
            damage.assert_not_awaited()

        asyncio.run(scenario())

    def test_zero_hp_atomically_snapshots_server_seats_then_clears_them(self):
        world = _world()
        car = world.quest_cars["car-7"]
        car["passenger_uids"] = ["202", "101", "bad", None, "303"]

        result = world.gta_crash("101", "car-7", 100, "wall")

        self.assertTrue(result["destroyed"])
        self.assertEqual(result["explosion_occupant_count"], 3)
        self.assertEqual(car["_vehicle_explosion_occupants"],
                         ("101", "202", "303"))
        self.assertIsNone(car["driver_uid"])
        self.assertEqual(car["passenger_uids"], [])
        self.assertTrue(car["wrecked"])
        self.assertNotIn("occupant_uids", result)

    def test_nonlethal_crash_and_already_exited_passenger_are_not_promoted(self):
        world = _world()
        car = world.quest_cars["car-7"]
        car["passenger_uids"].remove("303")

        first = world.gta_crash("101", "car-7", 10, "wall")
        self.assertFalse(first["destroyed"])
        self.assertNotIn("_vehicle_explosion_occupants", car)
        self.assertEqual(car["driver_uid"], "101")

        second = world.gta_crash("101", "car-7", 100, "wall")
        self.assertTrue(second["destroyed"])
        self.assertEqual(car["_vehicle_explosion_occupants"], ("101", "202"))
        self.assertNotIn("303", car["_vehicle_explosion_occupants"])

    def test_delivery_retries_only_transient_failure_with_stable_receipt(self):
        async def scenario():
            world = _world()
            confirmed = world.gta_crash("101", "car-7", 100, "vehicle")
            calls = []
            failed_once = False

            async def damage(uid, event_id, kind, raw_damage):
                nonlocal failed_once
                calls.append((uid, event_id, kind, raw_damage))
                if uid == "303" and not failed_once:
                    failed_once = True
                    raise RuntimeError("transient backend failure")
                return {"replayed": False, "body": {"dead": True}}

            with patch.object(
                    game.WorldSim, "apply_authoritative_damage_bound_projectile",
                    side_effect=damage), patch.object(
                        game.asyncio, "sleep", AsyncMock()) as sleep:
                result = await world.deliver_vehicle_explosion_occupants(
                    "car-7", confirmed["explosion_event_id"])

            self.assertEqual((result["targets"], result["delivered"],
                              result["failed"]), (3, 3, 0))
            by_uid = {uid: [row for row in calls if row[0] == uid]
                      for uid in ("101", "202", "303")}
            self.assertEqual([len(by_uid[uid]) for uid in by_uid], [1, 1, 2])
            self.assertEqual(by_uid["303"][0][1], by_uid["303"][1][1])
            self.assertTrue(all(row[2:] == ("vehicle_explosion", 10000)
                                for row in calls))
            sleep.assert_awaited_once()

        asyncio.run(scenario())

    def test_invalid_or_forged_event_cannot_select_an_occupant(self):
        async def scenario():
            world = _world()
            confirmed = world.gta_crash("101", "car-7", 100, "wall")
            damage = AsyncMock(return_value={"replayed": False})
            with patch.object(
                    game.WorldSim, "apply_authoritative_damage_bound_projectile",
                    damage):
                rejected = await world.deliver_vehicle_explosion_occupants(
                    "car-7", "client-forged-event:999")
                self.assertFalse(rejected["accepted"])
                damage.assert_not_awaited()

                accepted = await world.deliver_vehicle_explosion_occupants(
                    "car-7", confirmed["explosion_event_id"])
                self.assertTrue(accepted["accepted"])
                self.assertEqual(
                    {call.args[0] for call in damage.await_args_list},
                    {"101", "202", "303"})
                self.assertNotIn("999", {call.args[0]
                                          for call in damage.await_args_list})

        asyncio.run(scenario())

    def test_already_dead_replay_and_persistent_failure_are_idempotent(self):
        async def scenario():
            world = _world()
            confirmed = world.gta_crash("101", "car-7", 100, "wall")

            async def mixed(uid, event_id, kind, raw_damage):
                if uid == "101":
                    return None
                if uid == "303":
                    raise RuntimeError("persistent outage")
                return {"replayed": True, "body": {"dead": True}}

            with patch.object(
                    game.WorldSim, "apply_authoritative_damage_bound_projectile",
                    side_effect=mixed) as damage, patch.object(
                        game.asyncio, "sleep", AsyncMock()):
                result = await world.deliver_vehicle_explosion_occupants(
                    "car-7", confirmed["explosion_event_id"])

            self.assertEqual(result["already_dead_or_missing"], 1)
            self.assertEqual(result["replayed"], 1)
            self.assertEqual(result["failed"], 1)
            calls_303 = [call for call in damage.await_args_list
                         if call.args[0] == "303"]
            self.assertEqual(len(calls_303), 3)
            self.assertEqual(len({call.args[1] for call in calls_303}), 1)

            # Even if the already-dead player later respawns, this old wreck
            # may retry only the occupant whose delivery actually failed.
            retry = AsyncMock(return_value={"replayed": False,
                                            "body": {"dead": True}})
            with patch.object(
                    game.WorldSim, "apply_authoritative_damage_bound_projectile",
                    retry):
                retried = await world.deliver_vehicle_explosion_occupants(
                    "car-7", confirmed["explosion_event_id"])
            self.assertEqual(retried["skipped_terminal"], 2)
            self.assertEqual(retried["delivered"], 1)
            self.assertEqual(retried["failed"], 0)
            retry.assert_awaited_once()
            self.assertEqual(retry.await_args.args[0], "303")

        asyncio.run(scenario())

    def test_websocket_orders_authority_before_visual_broadcast(self):
        start = BOT_SOURCE.index("                    elif t == 'gta_crash':")
        end = BOT_SOURCE.index("                    elif t == 'gta_exit':", start)
        handler = BOT_SOURCE[start:end]
        self.assertLess(handler.index("deliver_vehicle_explosion_occupants"),
                        handler.index("pkt = json.dumps"))
        self.assertNotIn("passenger_uids", handler)
        self.assertNotIn("driver_uid", handler)


if __name__ == "__main__":
    unittest.main()
