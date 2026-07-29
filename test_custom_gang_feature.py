"""Server-authoritative regression test for player gangs and apartment HQs."""

import asyncio
import os
import tempfile
from pathlib import Path

os.environ.setdefault("BOT_TOKEN", "123456:custom-gang-regression")

import aiosqlite
from aiohttp import ClientSession
import mafiozi_bot as game
import _preview_ws_server as preview


COLORS = sorted(game.CUSTOM_GANG_FLAG_COLORS)
EMBLEMS = sorted(game.CUSTOM_GANG_FLAG_EMBLEMS)


class PreviewRequest:
    def __init__(self, uid: str, body: dict):
        self.match_info = {"uid": uid}
        self._body = body

    async def json(self):
        return self._body


async def seed_character(uid: int, name: str, mafia_family: str = "") -> None:
    async with aiosqlite.connect(game.DB_PATH) as db:
        await db.execute(
            "INSERT INTO characters(telegram_id,username,name,class,cash,mafia_family) "
            "VALUES(?,?,?,?,?,?)",
            (uid, f"user{uid}", name, "civilian", 100000, mafia_family),
        )
        await db.commit()


async def own_apartment(uid: int, apt_key: str) -> None:
    async with aiosqlite.connect(game.DB_PATH) as db:
        await db.execute(
            "INSERT INTO apartments_owned(telegram_id,apt_key,price,bought_at) VALUES(?,?,?,1)",
            (uid, apt_key, game.apartment_price_for_key(apt_key)),
        )
        await db.commit()


async def receive_event(ws, kind: str) -> dict:
    async with asyncio.timeout(3):
        while True:
            message = await ws.receive_json()
            if message.get("t") == "event" and (message.get("d") or {}).get("kind") == kind:
                return message["d"]


async def run() -> None:
    with tempfile.TemporaryDirectory(prefix="mafiozi-custom-gang-") as temp_dir:
        game.DB_PATH = str(Path(temp_dir) / "gang-test.db")
        await game.init_db()
        await game.ensure_apartment_tables()

        assert game.normalize_custom_gang_name("  Северные   Волки ") == "Северные Волки"
        assert game.normalize_custom_gang_name("<script>") is None
        assert game.normalize_custom_gang_name("Я") is None
        assert game.normalize_custom_gang_name("А" * 25) is None

        combinations = 0
        for primary in COLORS:
            for secondary in COLORS:
                for emblem in EMBLEMS:
                    flag = game.normalize_custom_gang_flag(primary, secondary, emblem)
                    assert flag["primary"] in game.CUSTOM_GANG_FLAG_COLORS
                    assert flag["secondary"] in game.CUSTOM_GANG_FLAG_COLORS
                    assert flag["primary"] != flag["secondary"]
                    assert flag["emblem"] == emblem
                    combinations += 1
        fallback = game.normalize_custom_gang_flag("red", "javascript:1", "unknown")
        assert fallback == {"primary": "#9b1f2d", "secondary": "#e0b83e", "emblem": "crown"}

        for uid, name, family in (
            (71001, "Лидер", ""),
            (71002, "Напарник", ""),
            (71003, "Новобранец", ""),
            (71004, "Мафиози", "bellini"),
        ):
            await seed_character(uid, name, family)
        await own_apartment(71001, "tile:16,16")
        await own_apartment(71003, "tile:26,26")

        created = await game.create_custom_gang_db(
            71001,
            "tile:16,16",
            "Волки Севера",
            game.normalize_custom_gang_flag("#3154a5", "#ece5d5", "wolf"),
            [71002],
        )
        assert created["ok"] and created["member_uids"] == ["71001", "71002"]
        leader = await game.get_custom_gang_for_user(71001)
        member = await game.get_custom_gang_for_user(71002)
        assert leader and leader["role"] == "leader" and leader["member_count"] == 2
        assert member and member["role"] == "member" and member["id"] == leader["id"]
        assert leader["hq_apt_key"] == "tile:16,16"
        assert leader["flag"] == {"primary": "#3154a5", "secondary": "#ece5d5", "emblem": "wolf"}

        live = {"_crew_id": "71001"}
        game.apply_custom_gang_to_player(live, member)
        assert live["_crew_id"] == f"cg:{leader['id']}" and live["_custom_gang_name"] == "Волки Севера"
        game.apply_custom_gang_to_player(live, None)
        assert not any(key.startswith("_custom_gang") for key in live) and "_crew_id" not in live

        duplicate_case = await game.create_custom_gang_db(
            71003,
            "tile:26,26",
            "ВОЛКИ СЕВЕРА",
            game.normalize_custom_gang_flag("#287f55", "#e0b83e", "eagle"),
            [],
        )
        assert duplicate_case == {"ok": False, "error": "name taken"}

        joined = await game.join_custom_gang_db(leader["id"], 71003, 71001)
        assert joined["ok"]
        assert (await game.join_custom_gang_db(leader["id"], 71003, 71001))["error"] == "already in gang"
        assert (await game.join_custom_gang_db(leader["id"], 71004, 71001))["error"] == "mafia conflict"
        assert (await game.leave_custom_gang_db(71001))["error"] == "leader must disband"
        assert (await game.leave_custom_gang_db(71003))["ok"]
        assert await game.get_custom_gang_for_user(71003) is None

        too_many = await game.create_custom_gang_db(
            71003, "tile:26,26", "Большая пати",
            game.normalize_custom_gang_flag("#cf303d", "#151922", "star"),
            list(range(72000, 72012)),
        )
        assert too_many == {"ok": False, "error": "party too large"}

        headquarters = await game.get_custom_gang_headquarters()
        assert len(headquarters) == 1 and headquarters[0]["member_count"] == 2
        disbanded = await game.disband_custom_gang_db(71001)
        assert disbanded["ok"] and set(disbanded["member_uids"]) == {"71001", "71002"}
        assert await game.get_custom_gang_for_user(71001) is None
        assert await game.get_custom_gang_for_user(71002) is None
        assert await game.get_custom_gang_headquarters() == []

        # Exercise the real production HTTP handlers, not helper functions only.
        game._WORLD = game.WorldSim()
        game._WORLD.players["71001"] = {"name": "Лидер", "_crew_id": "71001", "x": 16.0, "y": 16.0}
        game._WORLD.players["71002"] = {"name": "Напарник", "_crew_id": "71001", "x": 16.5, "y": 16.0}
        os.environ["PORT"] = "18761"
        runner = await game._coop_http_app()
        base = "http://127.0.0.1:18761"
        async with ClientSession() as session:
            async with session.get(f"{base}/custom-gang/71001/state") as response:
                state = await response.json()
                assert response.status == 200 and state["ok"] and state["gang"] is None
            async with session.post(
                f"{base}/custom-gang/71002/create",
                json={"apt_key": "tile:26,26", "name": "Своя банда", "flag": {}},
            ) as response:
                denied = await response.json()
                assert response.status == 409 and denied["error"] == "party leader only"
            async with session.post(
                f"{base}/custom-gang/71001/create",
                json={"apt_key": "tile:16,16", "name": "<b>опасно</b>", "flag": {}},
            ) as response:
                invalid = await response.json()
                assert response.status == 400 and invalid["error"] == "bad name or hq"
            async with session.post(
                f"{base}/custom-gang/71001/create",
                json={
                    "apt_key": "tile:16,16", "name": "Красные лисы",
                    "flag": {"primary": "#cf303d", "secondary": "#151922", "emblem": "fox"},
                },
            ) as response:
                created_http = await response.json()
                assert response.status == 200 and created_http["ok"]
                assert created_http["gang"]["member_count"] == 2
                assert created_http["gang"]["flag"] == {
                    "primary": "#cf303d", "secondary": "#151922", "emblem": "crown"
                }
            async with session.post(
                f"{base}/apartment/71001/sell", json={"apt_key": "tile:16,16"}
            ) as response:
                blocked_sale = await response.json()
                assert response.status == 409 and blocked_sale["error"] == "hq active"
            async with session.post(f"{base}/custom-gang/71001/leave") as response:
                leader_leave = await response.json()
                assert response.status == 409 and leader_leave["error"] == "leader must disband"
            async with session.post(f"{base}/custom-gang/71001/disband") as response:
                removed_http = await response.json()
                assert response.status == 200 and removed_http["ok"] and removed_http["headquarters"] == []

            # Real WebSocket transitions: party authority and an invite whose
            # target changes faction while the confirmation dialog is open.
            ws1 = await session.ws_connect(f"{base}/world/sim?uid=71001")
            ws2 = await session.ws_connect(f"{base}/world/sim?uid=71002")
            ws3 = await session.ws_connect(f"{base}/world/sim?uid=71003")
            assert (await ws1.receive_json())["t"] == "hello"
            assert (await ws2.receive_json())["t"] == "hello"
            assert (await ws3.receive_json())["t"] == "hello"

            game._WORLD.players["71001"].update({"_crew_id": "71001", "x": 20.0, "y": 20.0})
            game._WORLD.players["71002"].update({"_crew_id": "71001", "x": 20.5, "y": 20.0})
            game._WORLD.players["71003"].update({"x": 21.0, "y": 20.0})
            await ws2.send_json({"t": "gang_player_kick", "d": {"target_uid": "71001"}})
            await asyncio.sleep(0.05)
            assert game._WORLD.players["71001"]["_crew_id"] == "71001"
            assert game._WORLD.players["71002"]["_crew_id"] == "71001"

            async with session.post(
                f"{base}/custom-gang/71001/create",
                json={
                    "apt_key": "tile:16,16", "name": "Ночная стража",
                    "flag": {"primary": "#6438a8", "secondary": "#e0b83e", "emblem": "star"},
                },
            ) as response:
                ws_created = await response.json()
                assert response.status == 200 and ws_created["gang"]["member_count"] == 2

            await ws1.send_json({"t": "custom_gang_player_invite", "d": {"target_uid": "71003"}})
            invite_reply = await receive_event(ws1, "custom_gang_player_reply")
            invite_notice = await receive_event(ws3, "custom_gang_player_invite")
            assert invite_reply["ok"] and invite_notice["gang_name"] == "Ночная стража"
            game._WORLD.players["71003"]["_police"] = True
            await ws3.send_json({"t": "custom_gang_player_answer", "d": {"accept": True}})
            conflict = await receive_event(ws3, "custom_gang_player_changed")
            await receive_event(ws1, "custom_gang_player_changed")
            assert not conflict["ok"] and conflict["error"] == "faction conflict"
            assert await game.get_custom_gang_for_user(71003) is None

            game._WORLD.players["71003"]["_police"] = False
            await ws1.send_json({"t": "custom_gang_player_invite", "d": {"target_uid": "71003"}})
            await receive_event(ws1, "custom_gang_player_reply")
            await receive_event(ws3, "custom_gang_player_invite")
            await ws3.send_json({"t": "custom_gang_player_answer", "d": {"accept": True}})
            accepted = await receive_event(ws3, "custom_gang_player_changed")
            await receive_event(ws1, "custom_gang_player_changed")
            assert accepted["ok"] and accepted["accepted"]
            assert (await game.get_custom_gang_for_user(71003))["role"] == "member"

            async with session.post(f"{base}/custom-gang/71001/disband") as response:
                assert (await response.json())["ok"]
            await ws1.close(); await ws2.close(); await ws3.close()
        await runner.cleanup()
        await asyncio.sleep(0.05)

        # Local preview mirrors production validation, so testing without a
        # Telegram id cannot create impossible flag data.
        preview.preview_custom_gangs.clear()
        preview.preview_custom_gang_by_uid.clear()
        preview.preview_apartments.clear()
        preview.preview_custom_gang_seq = 0
        preview.preview_apartments["81001"] = {
            "tile:16,16": {"price": 3500, "bought_at": 1}
        }
        preview_response = await preview.custom_gang_create(PreviewRequest("81001", {
            "apt_key": "tile:16,16", "name": "Тест превью",
            "flag": {"primary": "url(bad)", "secondary": "#9b1f2d", "emblem": "bad"},
        }))
        preview_json = __import__("json").loads(preview_response.text)
        assert preview_response.status == 200
        assert preview_json["gang"]["flag"] == {
            "primary": "#9b1f2d", "secondary": "#e0b83e", "emblem": "crown"
        }

        root = Path(__file__).resolve().parent
        world_source = (root / "world.html").read_text(encoding="utf-8")
        three_source = (root / "three_preview.js").read_text(encoding="utf-8")
        for witness in (
            'id="cgPrimaryColors"', 'id="cgSecondaryColors"',
            "data-aptctl-gang", "Название банды", "drawCustomGangHeadquarters",
            "flag:{primary:m.dataset.primary,secondary:m.dataset.secondary,emblem:m.dataset.emblem}",
        ):
            assert witness in world_source, f"missing UI witness: {witness}"
        for witness in ("customGangFlagTexture", "flag.emblem", "THREE.CanvasTexture", "o.material.map?.dispose"):
            assert witness in three_source, f"missing 3D witness: {witness}"

        print(f"OK: {combinations} flags, DB transitions, 7 HTTP, 5 WS, preview, UI and 3D witnesses")


if __name__ == "__main__":
    asyncio.run(run())
