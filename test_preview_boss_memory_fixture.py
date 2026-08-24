"""Focused live-fixture contract for production-backed boss memory preview."""

import asyncio
import hashlib
import os
from pathlib import Path
import re

from aiohttp.test_utils import TestClient, TestServer

import _preview_ws_server as preview


UID = 919101


async def run():
    root = Path("D:/CodexTemp/mafiozi_preview_boss_memory_focused")
    os.environ["MAFIOZI_PREVIEW_FIXTURE_ROOT"] = str(root)
    world_path = Path("world.html")
    world_before = hashlib.sha256(world_path.read_bytes()).hexdigest()
    passed = []
    client = TestClient(TestServer(preview.app))
    await client.start_server()
    origin = str(client.make_url("/")).rstrip("/")
    nav_headers = {"Sec-Fetch-Site": "none"}
    try:
        ordinary = await client.get(f"/preview/world.html?uid={UID}")
        ordinary_html = await ordinary.text()
        assert ordinary.status == 200 and "__previewBossMemoryToken=" not in ordinary_html
        passed.append("default-off")

        bad = await client.get(f"/preview/world.html?uid={UID}&previewbossmemory=true")
        assert bad.status == 400
        repeated = await client.get(
            f"/preview/world.html?uid={UID}&previewbossmemory=1&previewbossmemory=1")
        ambiguous_navigation = await client.get(
            f"/preview/world.html?uid={UID}&previewbossmemory=1")
        assert repeated.status == 400 and ambiguous_navigation.status == 403
        passed.append("exact-opt-in")

        missing_uid = await client.get(
            "/preview/world.html?previewbossmemory=1", headers=nav_headers)
        assert missing_uid.status == 400
        passed.append("uid-required")

        foreign = await client.get(
            f"/preview/world.html?uid={UID}&previewbossmemory=1",
            headers={**nav_headers, "Origin": "https://attacker.invalid"})
        assert foreign.status == 403
        passed.append("origin-guard")

        activated = await client.get(
            f"/preview/world.html?uid={UID}&previewbossmemory=1", headers=nav_headers)
        html = await activated.text()
        token_match = re.search(r'__previewBossMemoryToken="([A-Za-z0-9_-]+)"', html)
        assert activated.status == 200 and token_match
        token = token_match.group(1)
        assert token not in str(activated.url)
        assert activated.headers["Cache-Control"] == "no-store, max-age=0"
        assert activated.headers["Referrer-Policy"] == "same-origin"
        passed.append("ephemeral-header-token")

        assert hashlib.sha256(world_path.read_bytes()).hexdigest() == world_before
        passed.append("served-copy-only")

        headers = {
            "X-Mafiosi-Preview-Fixture": token,
            "Sec-Fetch-Site": "same-origin",
            "Referer": f"{origin}/preview/world.html?uid={UID}&previewbossmemory=1",
        }
        state_response = await client.get(f"/npc-empires/{UID}/state", headers=headers)
        state = await state_response.json()
        leila = next(item for item in state["empires"] if item["leader_id"] == "leila")
        assert state_response.status == 200 and state["ok"]
        assert leila["pact"] == "war" and leila["relation"] == -100
        assert leila["activity"]["kind"] == "recover"
        assert leila["activity"]["phase"] == "regroup"
        assert "target_id" not in leila["activity"]
        assert leila["war_pressure"]["recovery"]["state"] == "regrouping"
        assert not state["interior_raids"]
        passed.append("production-memory-state")

        profile = preview.preview_boss_memory_profiles[UID]
        assert Path(profile["path"]).is_file() and str(profile["path"]).upper().startswith("D:")
        passed.append("retained-d-db")

        reload_page = await client.get(
            f"/preview/world.html?uid={UID}&previewbossmemory=1", headers=nav_headers)
        reload_html = await reload_page.text()
        reload_token = re.search(
            r'__previewBossMemoryToken="([A-Za-z0-9_-]+)"', reload_html).group(1)
        assert reload_token != token
        assert preview.preview_boss_memory_profiles[UID]["path"] == profile["path"]
        revoked = await client.get(f"/npc-empires/{UID}/state", headers=headers)
        assert revoked.status == 403
        headers = {**headers, "X-Mafiosi-Preview-Fixture": reload_token}
        active_reload = await client.get(f"/npc-empires/{UID}/state", headers=headers)
        assert active_reload.status == 200
        passed.append("reload-revokes-old-token")

        wrong_uid = await client.get(
            f"/npc-empires/{UID + 1}/state", headers=headers)
        assert wrong_uid.status == 403
        invalid = await client.get(
            f"/npc-empires/{UID}/state",
            headers={**headers, "X-Mafiosi-Preview-Fixture": "x" * 48})
        assert invalid.status == 403
        passed.append("capability-isolation")

        missing_referer = await client.get(
            f"/npc-empires/{UID}/state",
            headers={"X-Mafiosi-Preview-Fixture": reload_token,
                     "Sec-Fetch-Site": "same-origin"})
        malformed_referer = await client.get(
            f"/npc-empires/{UID}/state",
            headers={**headers, "Referer": f"{origin}/preview/world.htmlevil"})
        assert missing_referer.status == 403 and malformed_referer.status == 403
        passed.append("strict-state-referer")

        concurrent = await asyncio.gather(*[
            client.get(f"/npc-empires/{UID}/state", headers=headers) for _ in range(8)
        ])
        snapshots = [await item.json() for item in concurrent]
        facts = [(
            next(emp for emp in item["empires"] if emp["leader_id"] == "leila")
            ["activity"]["kind"],
            next(emp for emp in item["empires"] if emp["leader_id"] == "leila")
            ["war_pressure"]["recovery"]["state"],
        ) for item in snapshots]
        assert facts == [("recover", "regrouping")] * 8
        passed.append("concurrent-stable")

        preview.preview_boss_memory_sessions[reload_token]["expires_at"] = 1
        expired = await client.get(f"/npc-empires/{UID}/state", headers=headers)
        assert expired.status == 410
        assert reload_token not in preview.preview_boss_memory_sessions
        passed.append("expiry-sweep")

        default_state = await client.get(f"/npc-empires/{UID}/state")
        default_payload = await default_state.json()
        default_leila = next(
            item for item in default_payload["empires"] if item["leader_id"] == "leila")
        assert default_state.status == 200
        assert default_leila["memory"] == [] and default_leila["war_pressure"] is None
        passed.append("ordinary-state-unchanged")

        assert len(passed) == 14, passed
        print("preview boss memory fixture: 14/14 gates OK — " + ", ".join(passed))
        print(f"retained fixture DB: {profile['path']}")
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(run())
