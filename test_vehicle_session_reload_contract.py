import asyncio
import json
import pathlib
import unittest

from aiohttp.test_utils import TestClient, TestServer

import _preview_ws_server as game


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
PREVIEW = (ROOT / "_preview_ws_server.py").read_text(encoding="utf-8")


async def recv_event(ws, kind, timeout=2.0):
    async def wait_for_kind():
        while True:
            msg = await ws.receive()
            packet = json.loads(msg.data)
            if packet.get("t") == "event" and packet.get("d", {}).get("kind") == kind:
                return packet["d"]
    return await asyncio.wait_for(wait_for_kind(), timeout)


async def recv_snap(ws, predicate, timeout=2.0):
    async def wait_for_snap():
        while True:
            msg = await ws.receive()
            packet = json.loads(msg.data)
            if packet.get("t") == "snap" and predicate(packet.get("d", {})):
                return packet["d"]
    return await asyncio.wait_for(wait_for_snap(), timeout)


class VehicleSessionReloadContractTests(unittest.TestCase):
    def test_client_recovers_authoritative_driver_once(self):
        block = WORLD.split("function applyQuestCarsSnapshot(arr) {", 1)[1].split(
            "// Убираем машины которые больше не приходят", 1
        )[0]
        self.assertIn("_vehicleSessionRecoveryPending", block)
        self.assertIn("String(c.driver_uid || '') === String(QP.uid || '')", block)
        self.assertIn("authoritativeSeats.length === 1", block)
        self.assertIn("recovered._locallyParkedUntil", block)
        self.assertIn("_recentlyExitedCarId === recovered.id", block)
        self.assertIn("myDrivingCarId = recovered.id", block)
        self.assertIn("player.c = recovered.x", block)
        self.assertIn("player.r = recovered.y", block)
        self.assertIn("_vehicleSessionRecoveryPending = false", block)

    def test_preview_has_bounded_reconnect_grace_and_owner_rebind(self):
        self.assertIn('car["_driver_disconnected_at"] = time.time()', PREVIEW)
        self.assertIn("now - disconnected_at > 8.0", PREVIEW)
        drive = PREVIEW.split('elif t == "gta_drive":', 1)[1].split(
            'elif t in ("gta_siren", "gta_tires_punctured"):', 1
        )[0]
        self.assertIn('str(car.get("owner_uid") or "") == str(uid)', drive)
        self.assertIn('car["driver_uid"] = uid', drive)

    def test_expired_preview_grace_parks_without_drive(self):
        car = game.make_race_car(game.RACE_SLOTS[0])
        car["driver_uid"] = "gone_driver"
        car["owner_uid"] = "gone_driver"
        car["state"] = "driving"
        car["_driver_disconnected_at"] = game.time.time() - 9.0
        game.quest_cars[car["id"]] = car
        game.tick_race_cars()
        self.assertIsNone(game.quest_cars[car["id"]]["driver_uid"])
        self.assertEqual(game.quest_cars[car["id"]]["state"], "idle")

    def test_reload_keeps_same_car_and_accepts_next_drive(self):
        asyncio.run(self._reload_roundtrip())

    async def _reload_roundtrip(self):
        game.players.clear()
        game.preview_connections.clear()
        game.reset_race_cars()
        server = TestServer(game.app)
        client = TestClient(server)
        await client.start_server()
        uid = "reload_driver"
        try:
            first = await client.ws_connect(f"/world/sim?uid={uid}")
            await first.receive()
            await first.send_json({"t": "civilian_carjack", "d": {
                "x": 45.0, "y": 80.0, "model": "corvette_c3"
            }})
            reply = await recv_event(first, "civilian_hijack_reply")
            car_id = reply["car_id"]
            await first.send_json({"t": "gta_drive", "d": {
                "car_id": car_id, "x": 46.0, "y": 81.0,
                "ang": 0.5, "vx": 2.0, "vy": 1.0,
            }})
            await asyncio.sleep(0.08)
            await first.close()
            await asyncio.sleep(0.08)
            self.assertEqual(str(game.quest_cars[car_id]["driver_uid"]), uid)
            self.assertIn("_driver_disconnected_at", game.quest_cars[car_id])

            second = await client.ws_connect(f"/world/sim?uid={uid}")
            await second.receive()
            snap = await recv_snap(second, lambda d: any(
                car.get("id") == car_id and str(car.get("driver_uid")) == uid
                for car in d.get("quest_cars", [])
            ))
            restored = next(car for car in snap["quest_cars"] if car["id"] == car_id)
            self.assertEqual((restored["x"], restored["y"]), (46.0, 81.0))
            await second.send_json({"t": "gta_drive", "d": {
                "car_id": car_id, "x": 47.0, "y": 82.0,
                "ang": 0.6, "vx": 2.0, "vy": 1.0,
            }})
            await asyncio.sleep(0.08)
            self.assertEqual(
                (game.quest_cars[car_id]["x"], game.quest_cars[car_id]["y"]),
                (47.0, 82.0),
            )
            self.assertNotIn("_driver_disconnected_at", game.quest_cars[car_id])
            await second.close()
        finally:
            await client.close()


if __name__ == "__main__":
    unittest.main()
