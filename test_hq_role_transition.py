"""Focused regression test for HQ sale and faction-role transitions."""

import asyncio
import json
import os
import tempfile
from pathlib import Path

os.environ.setdefault("BOT_TOKEN", "123456:hq-role-regression")

import aiosqlite
from aiohttp import ClientSession

import mafiozi_bot as game
import _preview_ws_server as preview


class PreviewRequest:
    def __init__(self, uid: str, body: dict):
        self.match_info = {"uid": uid}
        self._body = body

    async def json(self):
        return self._body


async def seed_character(uid: int) -> None:
    async with aiosqlite.connect(game.DB_PATH) as db:
        await db.execute(
            "INSERT INTO characters(telegram_id,username,name,class,cash,mafia_family) "
            "VALUES(?,?,?,?,?,?)",
            (uid, f"user{uid}", "Владелец", "civilian", 100000, ""),
        )
        await db.commit()


async def run() -> None:
    with tempfile.TemporaryDirectory(prefix="mafiozi-hq-role-") as temp_dir:
        game.DB_PATH = str(Path(temp_dir) / "hq-role.db")
        await game.init_db()
        await game.ensure_apartment_tables()
        await seed_character(93001)
        async with aiosqlite.connect(game.DB_PATH) as db:
            await db.execute(
                "INSERT INTO apartments_owned(telegram_id,apt_key,price,bought_at) "
                "VALUES(?,?,?,1)",
                (93001, "tile:16,16", game.apartment_price_for_key("tile:16,16")),
            )
            await db.commit()

        created = await game.create_custom_gang_db(
            93001, "tile:16,16", "Штаб тест",
            game.normalize_custom_gang_flag(None, None, None), [],
        )
        assert created["ok"]
        gang = await game.get_custom_gang_for_user(93001)
        world = game.WorldSim()
        world.players["93001"] = {"uid": "93001", "x": 16.0, "y": 16.0}
        game.apply_custom_gang_to_player(world.players["93001"], gang)

        world.apply_input("93001", {
            "x": 16, "y": 16, "police": False,
            "mafia": True, "mafia_family": "bellini",
        })
        player = world.players["93001"]
        assert not player.get("_mafia")
        assert player.get("_mafia_join_denied") == "custom_gang_owner"
        assert player.get("_crew_id") == f"cg:{gang['id']}"

        game._WORLD = world
        os.environ["PORT"] = "18793"
        await game._coop_http_app()
        async with ClientSession() as session:
            async with session.post(
                "http://127.0.0.1:18793/apartment/93001/sell",
                json={"apt_key": "tile:16,16"},
            ) as response:
                sale = await response.json()
                assert response.status == 200 and sale["ok"]
                assert sale["gang"] is None and sale["headquarters"] == []
                assert sale["role_status"] == "civilian"
        assert await game.get_custom_gang_for_user(93001) is None
        assert not player.get("_custom_gang_id") and not player.get("_crew_id")
        world.apply_input("93001", {
            "x": 16, "y": 16, "police": False,
            "mafia": True, "mafia_family": "moretti",
        })
        assert player.get("_mafia") and player.get("_mafia_family") == "moretti"

        preview.preview_custom_gangs.clear()
        preview.preview_custom_gang_by_uid.clear()
        preview.preview_apartments.clear()
        preview.preview_custom_gang_seq = 0
        preview.preview_apartments["93002"] = {
            "tile:26,26": {"price": 5000, "bought_at": 1},
        }
        made = await preview.custom_gang_create(PreviewRequest("93002", {
            "apt_key": "tile:26,26", "name": "Превью штаб", "flag": {},
        }))
        assert made.status == 200
        sold = await preview.apartment_sell(PreviewRequest("93002", {
            "apt_key": "tile:26,26",
        }))
        payload = json.loads(sold.text)
        assert sold.status == 200 and payload["gang"] is None
        assert payload["role_status"] == "civilian" and payload["headquarters"] == []

    print("HQ_ROLE_TRANSITION_OK")


if __name__ == "__main__":
    asyncio.run(run())
