import asyncio
import json
import os
import re
import sqlite3
import unittest
from pathlib import Path
from unittest import mock

from aiohttp.test_utils import TestClient, TestServer

import _preview_ws_server as game


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


class PreviewC4SabotageFixtureTests(unittest.TestCase):
    def test_fixture_root_rejects_non_d_drive(self):
        with mock.patch.dict(os.environ, {"MAFIOZI_PREVIEW_C4_ROOT": "C:/preview-c4"}):
            with self.assertRaisesRegex(RuntimeError, "must be on D"):
                game._preview_c4_root()

    def test_world_uses_authenticated_authoritative_fuse(self):
        fuse = WORLD.split("async function _finalizeNpcBuildingSabotage", 1)[1].split(
            "function _npcBuildingActionDialog", 1)[0]
        self.assertIn("X-Mafiosi-Preview-Fixture", WORLD)
        self.assertIn("_previewC4ApiAllowed(url)", WORLD)
        self.assertIn("parsed.origin===location.origin", WORLD)
        self.assertIn("base=`/npc-empires/${encodeURIComponent(QP.uid)}`", WORLD)
        self.assertIn("_npcBuildingSabotageRequestKeys.delete", fuse)
        self.assertIn("Math.min(4000,500*2**", fuse)
        self.assertIn("_apiRequest(`${QP.api.replace", WORLD)
        self.assertIn("previewc4sabotage", WORLD)
        self.assertIn("await loadNpcEmpireState()", fuse)
        self.assertIn("holding?.building_status==='closed'", fuse)
        self.assertNotIn("performance.now()+3000", fuse)

    def test_real_db_fixture_security_reload_and_replay(self):
        asyncio.run(self._roundtrip())

    async def _roundtrip(self):
        game.preview_c4_profiles.clear()
        game.preview_c4_sessions.clear()
        game.preview_c4_uid_locks.clear()
        game.preview_c4_failures.clear()
        game.preview_c4_pending.clear()
        await self._cancellation_handoff_is_serialized()
        game.preview_c4_profiles.clear()
        game.preview_c4_uid_locks.clear()
        game.preview_c4_failures.clear()
        game.preview_c4_pending.clear()
        server = TestServer(game.app)
        client = TestClient(server)
        await client.start_server()
        uid = 910101
        origin = str(client.make_url("/")).rstrip("/")
        page_headers = {"Sec-Fetch-Dest": "document", "Sec-Fetch-Site": "none"}
        try:
            page = await client.get(
                f"/preview/world.html?uid={uid}&previewc4sabotage=1",
                headers=page_headers)
            self.assertEqual(page.status, 200)
            html = await page.text()
            token = re.search(r'__previewC4SabotageToken="([0-9a-f]{48})"', html).group(1)
            self.assertEqual(page.headers.get("Cache-Control"), "no-store, max-age=0")
            self.assertEqual(page.headers.get("Referrer-Policy"), "same-origin")

            duplicate_query = await client.get(
                f"/preview/world.html?uid={uid}&previewc4sabotage=1&previewc4sabotage=1",
                headers=page_headers)
            self.assertEqual(duplicate_query.status, 400)
            mixed_query = await client.get(
                f"/preview/world.html?uid={uid}&previewc4sabotage=1&previewbossmemory=1",
                headers=page_headers)
            self.assertEqual(mixed_query.status, 400)
            signed_uid = await client.get(
                "/preview/world.html?uid=%2B910102&previewc4sabotage=1",
                headers=page_headers)
            self.assertEqual(signed_uid.status, 400)

            denied = await client.get(f"/npc-empires/{uid}/state", headers={
                "X-Mafiosi-Preview-Fixture": "0" * 48,
                "Origin": origin,
                "Referer": origin + "/preview/world.html",
                "Sec-Fetch-Site": "same-origin",
            })
            self.assertEqual(denied.status, 403)

            bad_referer = await client.get(f"/npc-empires/{uid}/state", headers={
                "X-Mafiosi-Preview-Fixture": token,
                "Referer": origin + "/preview/world.htmlevil",
                "Sec-Fetch-Site": "same-origin",
            })
            self.assertEqual(bad_referer.status, 403)
            alias_origin = await client.get(f"/npc-empires/{uid}/state", headers={
                "Host": origin.replace("http://", "").replace("127.0.0.1", "localhost"),
                "X-Mafiosi-Preview-Fixture": token,
                "Referer": origin.replace("127.0.0.1", "localhost") + "/preview/world.html",
                "Sec-Fetch-Site": "same-origin",
            })
            self.assertEqual(alias_origin.status, 403)
            signed_route_uid = await client.get(f"/npc-empires/+{uid}/state", headers={
                "X-Mafiosi-Preview-Fixture": token,
                "Referer": origin + "/preview/world.html",
                "Sec-Fetch-Site": "same-origin",
            })
            self.assertEqual(signed_route_uid.status, 403)

            api_headers = {
                "X-Mafiosi-Preview-Fixture": token,
                "Origin": origin,
                "Referer": origin + "/preview/world.html?previewc4sabotage=1",
                "Sec-Fetch-Site": "same-origin",
            }
            get_headers = {key: value for key, value in api_headers.items()
                           if key != "Origin"}
            state = await (await client.get(
                f"/npc-empires/{uid}/state", headers=get_headers)).json()
            self.assertTrue(state["ok"])
            leila = next(item for item in state["empires"] if item["leader_id"] == "leila")
            holding = next(item for item in leila["holdings"] if item["holding_id"] == "0,5")
            self.assertEqual(holding["building_status"], "open")

            request_key = "preview-c4-roundtrip-0001"
            action = {"leader_id": "leila", "holding_id": "0,5",
                      "action": "sabotage", "request_key": request_key}
            encoded = json.dumps(action).encode("utf-8")

            async def oversized_chunks():
                yield encoded
                await asyncio.sleep(0)
                yield b" " * (513 - len(encoded))

            oversized = await client.post(
                f"/npc-empires/{uid}/building/action", data=oversized_chunks(),
                headers={**api_headers, "Content-Type": "application/json"})
            self.assertEqual(oversized.status, 413)
            armed_response = await client.post(
                f"/npc-empires/{uid}/building/action", json=action,
                headers=api_headers)
            armed = await armed_response.json()
            self.assertEqual(armed_response.status, 200)
            self.assertTrue(armed["armed"])
            self.assertFalse(armed["duplicate"])
            self.assertEqual(armed["c4_left"], 1)

            replay = await (await client.post(
                f"/npc-empires/{uid}/building/action", json=action,
                headers=api_headers)).json()
            self.assertTrue(replay["duplicate"])
            self.assertEqual(replay["request_key"], request_key)
            self.assertEqual(replay["c4_left"], 1)

            profile = game.preview_c4_profiles[uid]
            with sqlite3.connect(profile["path"]) as db:
                self.assertEqual(db.execute(
                    "SELECT quantity FROM inventory WHERE telegram_id=? AND item_id='c4'",
                    (uid,)).fetchone()[0], 1)
                self.assertEqual(db.execute(
                    "SELECT COUNT(*) FROM npc_empire_events WHERE kind='building_sabotaged'"
                ).fetchone()[0], 1)

            second_page = await client.get(
                f"/preview/world.html?uid={uid}&previewc4sabotage=1",
                headers=page_headers)
            second_html = await second_page.text()
            second_token = re.search(
                r'__previewC4SabotageToken="([0-9a-f]{48})"', second_html).group(1)
            self.assertNotEqual(second_token, token)
            stale = await client.get(f"/npc-empires/{uid}/state", headers=api_headers)
            self.assertEqual(stale.status, 403)

            api_headers["X-Mafiosi-Preview-Fixture"] = second_token
            armed_state = await (await client.get(
                f"/npc-empires/{uid}/state", headers=api_headers)).json()
            armed_holding = next(item for item in next(
                empire for empire in armed_state["empires"]
                if empire["leader_id"] == "leila")["holdings"]
                if item["holding_id"] == "0,5")
            self.assertEqual(armed_holding["building_status"], "armed")
            self.assertEqual(armed_holding["sabotage_action_id"], request_key)

            await asyncio.sleep(3.2)
            closed_state = await (await client.get(
                f"/npc-empires/{uid}/state", headers=api_headers)).json()
            closed_holding = next(item for item in next(
                empire for empire in closed_state["empires"]
                if empire["leader_id"] == "leila")["holdings"]
                if item["holding_id"] == "0,5")
            self.assertEqual(closed_holding["building_status"], "closed")
            self.assertEqual(closed_holding["sabotage_action_id"], request_key)
        finally:
            await client.close()

    async def _cancellation_handoff_is_serialized(self):
        uid = 919919
        original_seed = game._preview_c4_seed
        started = asyncio.Event()
        release = asyncio.Event()
        calls = 0

        async def controlled_seed(seed_uid):
            nonlocal calls
            calls += 1
            started.set()
            await release.wait()
            return {"uid": seed_uid, "path": "D:/fixture.sqlite3",
                    "generation": "g", "leader_id": "leila", "holding_id": "0,5"}

        game._preview_c4_seed = controlled_seed
        try:
            owner = asyncio.create_task(game._preview_c4_profile(uid))
            await started.wait()
            waiter = asyncio.create_task(game._preview_c4_profile(uid))
            owner.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await owner
            racer = asyncio.create_task(game._preview_c4_profile(uid))
            release.set()
            left, right = await asyncio.gather(waiter, racer)
            self.assertIs(left, right)
            self.assertEqual(calls, 2)
        finally:
            game._preview_c4_seed = original_seed


if __name__ == "__main__":
    unittest.main()
