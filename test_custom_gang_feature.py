"""Server-authoritative regression test for player gangs and apartment HQs."""

import asyncio
import math
import os
import tempfile
import time
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


class IdentityRequest:
    def __init__(self, token: str = "", query: dict | None = None):
        self.headers = {"Authorization": f"Bearer {token}"} if token else {}
        self.query = query or {}


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

        # SteamID64 is mapped to the existing internal player id. Only a hash
        # of our own bearer token is persisted; a forged URL uid is rejected.
        assert not (await game.authenticate_steam_ticket("not-hex"))["ok"]
        steam_id = "76561198000071001"
        steam_session = await game.issue_steam_session(steam_id, "Steam Player")
        assert steam_session["ok"] and steam_session["player_id"] == steam_id
        identity_request = IdentityRequest(steam_session["session"])
        assert await game.resolve_request_player(identity_request, steam_id) == int(steam_id)
        assert await game.resolve_request_player(identity_request, "71001") is None
        assert (await game.get_character(int(steam_id)))["name"] == "Steam Player"
        ws_ticket = await game.issue_world_ws_ticket(int(steam_id))
        ws_request = IdentityRequest(query={"ws_ticket": ws_ticket["ticket"]})
        assert await game.resolve_request_player(ws_request, steam_id) == int(steam_id)
        assert await game.resolve_request_player(ws_request, steam_id) is None

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

        hire_world = game.WorldSim()
        hire_world.city_gangs.clear(); hire_world.gang_nests.clear()
        hire_world.players["71001"] = {
            "uid": "71001", "x": 16.0, "y": 16.0, "_custom_gang_id": leader["id"],
            "_custom_gang_name": leader["name"], "_custom_gang_flag": leader["flag"],
            "_cash": 100000,
        }
        street_bot = {"id": "paid-hire", "x": 16.5, "y": 16.0, "alive": True,
                      "hp": 90, "max_hp": 90, "level": 3, "kind": "street",
                      "weapon": "smg", "look": {"skin": 1}}
        hire_world.city_gangs.append({"faction": "purple", "bots": [street_bot]})
        cash_before_hire = (await game.get_character(71001))["cash"]
        paid_hire = await hire_world.hire_city_gang_bot("71001", "paid-hire")
        assert paid_hire["ok"] and paid_hire["cost"] == 500 and not street_bot["alive"]
        assert (await game.get_character(71001))["cash"] == cash_before_hire - 500

        # Hiring is role-driven in the Steam game: police and civilians are
        # rejected, while either mafia family may hire even a high-level bot.
        hire_world.players["71003"] = {"uid": "71003", "x": 20.0, "y": 20.0, "_cash": 50000}
        role_bot = {"id": "role-hire", "x": 20.0, "y": 24.2, "alive": True,
                    "hp": 160, "max_hp": 160, "level": 25, "kind": "street",
                    "weapon": "rifle", "look": {"skin": 2}}
        hire_world.city_gangs.append({"faction": "yellow", "bots": [role_bot]})
        civilian_denied = await hire_world.hire_city_gang_bot("71003", "role-hire")
        assert not civilian_denied["ok"] and civilian_denied["reason"] == "not_mafia"
        hire_world.players["71003"]["_police"] = True
        police_denied = await hire_world.hire_city_gang_bot("71003", "role-hire")
        assert not police_denied["ok"] and police_denied["reason"] == "police_service"
        hire_world.players["71004"] = {"uid": "71004", "x": 20.0, "y": 20.0,
                                          "_mafia": True, "_mafia_xp": 0, "_cash": 50000}
        mafia_hire = await hire_world.hire_city_gang_bot("71004", "role-hire")
        assert mafia_hire["ok"] and mafia_hire["level"] == 25 and not role_bot["alive"]

        # Enemy street gangs and district bosses share the player's squad
        # combat fundamentals: predicted throwable dodge, magazines/reload,
        # cover movement and friendly-fire lane protection.
        combat_world = game.WorldSim()
        combat_world.city_gangs.clear()
        combat_world._city_gang_next_spawn_at = time.time() + 3600
        combat_world.players["enemy-ai-target"] = {
            "uid":"enemy-ai-target", "x":40.0, "y":120.0,
            "hp":100, "max_hp":100, "dead":False, "_mode":"pvp",
        }
        enemy = {"id":"enemy-ai-1", "x":44.0, "y":120.0, "ang":0.0,
                 "hp":100, "max_hp":100, "level":8, "alive":True,
                 "kind":"aggro_grunt", "weapon":"pistol", "_shot_t":0.0,
                 "_act":"walk", "_act_until":time.time()+30}
        blocker = {"id":"enemy-ai-2", "x":42.0, "y":120.0, "ang":0.0,
                   "hp":100, "max_hp":100, "level":8, "alive":True,
                   "kind":"aggro_grunt", "weapon":"pistol", "_shot_t":0.0,
                   "_act":"walk", "_act_until":time.time()+30}
        hostile_gang = {
            "id":"enemy-ai-gang", "bots":[enemy, blocker], "state":"hostile",
            "_spawned_at":time.time(), "_hostile_until":time.time()+30,
            "_target_uid":"enemy-ai-target", "_threat_t":{},
            "_patrol_wp":(44.0,120.0), "_patrol_route":[], "_patrol_route_i":0,
            "_patrol_wp_until":time.time()+60, "_cops_dispatched":True,
            "faction":"purple",
        }
        combat_world.city_gangs.append(hostile_gang)
        assert not combat_world._city_gang_shot_safe(
            hostile_gang, enemy, 40.0, 120.0)
        blocker["y"] = 122.0
        assert combat_world._city_gang_shot_safe(
            hostile_gang, enemy, 40.0, 120.0)
        throw_event = combat_world.register_gang_throwable("enemy-ai-target", {
            "kind":"grenade", "from_x":40.0, "from_y":120.0,
            "to_x":44.0, "to_y":120.0,
        })
        assert throw_event and throw_event["kind"] == "gang_throwable"
        before_dodge = (enemy["x"], enemy["y"])
        combat_world.tick_city_gangs(.12)
        assert enemy.get("_dodge_kind") == "grenade"
        assert math.hypot(enemy["x"]-44.0, enemy["y"]-120.0) > math.hypot(
            before_dodge[0]-44.0, before_dodge[1]-120.0)
        combat_world._gang_throwables.clear()
        enemy["kind"] = "district_boss"
        combat_world.players["enemy-ai-target"]["_gang_throw_at"] = 0
        molotov_event = combat_world.register_gang_throwable("enemy-ai-target", {
            "kind":"molotov", "from_x":40.0, "from_y":120.0,
            "to_x":enemy["x"], "to_y":enemy["y"],
        })
        assert molotov_event and molotov_event["throw_kind"] == "molotov"
        combat_world.tick_city_gangs(.12)
        assert enemy.get("_dodge_kind") == "molotov"
        combat_world._gang_throwables.clear()
        enemy["_mag"] = 0
        combat_world.tick_city_gangs(.12)
        assert enemy.get("_reload_until", 0) > time.time()
        assert enemy.get("_combat_state") in ("reload", "cover")
        enemy_payload = combat_world.snapshot_for("enemy-ai-target")["d"]["aggro"][
            hostile_gang["id"]]["bots"]
        enemy_snapshot = next(row for row in enemy_payload if row["id"] == enemy["id"])
        assert enemy_snapshot["reloading"] and "reloadProgress" in enemy_snapshot
        assert all(key in enemy_snapshot for key in (
            "shooting", "aiming", "dodging", "takingCover", "combatState"))
        cover = combat_world._city_gang_cover_point(
            hostile_gang, enemy, 40.0, 120.0)
        assert cover is None or len(cover) == 2
        enemy["_reload_until"] = 0
        enemy["_dodging_until"] = 0
        enemy["_mag"] = 2
        enemy["_shot_t"] = 0
        combat_world.cops.append({
            "id":"enemy-ai-cop", "x":enemy["x"]-1.0, "y":enemy["y"],
            "hp":80, "max_hp":80, "alive":True,
            "target_gang_id":hostile_gang["id"],
        })
        cop_return_fire = combat_world._city_gang_fire_on_cops(
            hostile_gang, [enemy], time.time())
        assert cop_return_fire and cop_return_fire[0]["kind"] == "gang_shot_cop"

        deposited = await game.custom_gang_treasury_db(71002, 2000)
        assert deposited["ok"] and deposited["treasury"] == 2000
        withdrawn = await game.custom_gang_treasury_db(71001, -500)
        assert withdrawn["ok"] and withdrawn["treasury"] == 1500
        edited = await game.edit_custom_gang_db(
            71001, "Северный синдикат",
            game.normalize_custom_gang_flag("#6438a8", "#e0b83e", "star"),
        )
        assert edited["ok"]
        leader = await game.get_custom_gang_for_user(71001)
        assert leader["name"] == "Северный синдикат" and leader["treasury"] == 500
        assert leader["history"][0]["action"] == "edit"

        npc = await game.persist_custom_gang_npc(71002, {
            "ok": True, "bot_id": "street-test-1", "look": {"skin": 2},
            "weapon": "smg", "faction": "purple", "level": 7, "max_hp": 130,
        })
        assert npc and npc["owner_uid"] == "71002" and npc["weapon"] == "smg"
        synced = await game.sync_custom_gang_npcs_db(71002, [{
            "id": npc["id"], "hp": 91, "max_hp": 130, "level": 8,
            "fighterXp": 777, "kills": 3, "damageDone": 900,
        }])
        assert synced["ok"] and synced["npcs"][0]["hp"] == 91

        live = {"_crew_id": "71001"}
        game.apply_custom_gang_to_player(live, member)
        assert live["_crew_id"] == f"cg:{leader['id']}" and live["_custom_gang_name"] == "Волки Севера"
        game.apply_custom_gang_to_player(live, None)
        assert not any(key.startswith("_custom_gang") for key in live) and "_crew_id" not in live

        duplicate_case = await game.create_custom_gang_db(
            71003,
            "tile:26,26",
            "СЕВЕРНЫЙ СИНДИКАТ",
            game.normalize_custom_gang_flag("#287f55", "#e0b83e", "eagle"),
            [],
        )
        assert duplicate_case == {"ok": False, "error": "name taken"}

        joined = await game.join_custom_gang_db(leader["id"], 71003, 71001)
        assert joined["ok"]
        assert (await game.join_custom_gang_db(leader["id"], 71003, 71001))["error"] == "already in gang"
        assert (await game.join_custom_gang_db(leader["id"], 71004, 71001))["error"] == "mafia conflict"
        transferred = await game.transfer_custom_gang_leadership_db(71001, 71002)
        assert transferred["ok"] and (await game.get_custom_gang_for_user(71002))["role"] == "leader"
        assert (await game.transfer_custom_gang_leadership_db(71002, 71001))["ok"]
        kicked = await game.kick_custom_gang_member_db(71001, 71003)
        assert kicked["ok"] and await game.get_custom_gang_for_user(71003) is None
        assert (await game.join_custom_gang_db(leader["id"], 71003, 71001))["ok"]
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
            os.environ["STEAM_AUTH_REQUIRED"] = "1"
            async with session.get(f"{base}/custom-gang/71001/state") as response:
                assert response.status == 401
            steam_headers = {"Authorization": f"Bearer {steam_session['session']}"}
            async with session.get(
                f"{base}/custom-gang/{steam_id}/state", headers=steam_headers
            ) as response:
                assert response.status == 200 and (await response.json())["ok"]
            async with session.get(
                f"{base}/custom-gang/71001/state", headers=steam_headers
            ) as response:
                assert response.status == 401
            async with session.post(
                f"{base}/auth/steam/ws-ticket", headers=steam_headers
            ) as response:
                ws_auth = await response.json()
                assert response.status == 200 and ws_auth["ok"] and ws_auth["ticket"]
            os.environ.pop("STEAM_AUTH_REQUIRED", None)

            original_authenticate = game.authenticate_steam_ticket
            async def fake_authenticate(ticket):
                assert ticket == "aabb"
                return {"ok": True, "steam_id": "76561198000071002"}
            game.authenticate_steam_ticket = fake_authenticate
            async with session.post(
                f"{base}/auth/steam/session",
                json={"ticket": "aabb", "display_name": "Steam Login"},
            ) as response:
                auth_json = await response.json()
                assert response.status == 200 and auth_json["provider"] == "steam"
            game.authenticate_steam_ticket = original_authenticate

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
                f"{base}/custom-gang/71001/treasury", json={"amount": 1500}
            ) as response:
                treasury_http = await response.json()
                assert response.status == 200 and treasury_http["gang"]["treasury"] == 1500
            async with session.post(
                f"{base}/custom-gang/71001/edit",
                json={
                    "name": "Лисы Steam",
                    "flag": {"primary": "#2386a8", "secondary": "#ece5d5", "emblem": "eagle"},
                },
            ) as response:
                edit_http = await response.json()
                assert response.status == 200 and edit_http["gang"]["name"] == "Лисы Steam"
                assert edit_http["gang"]["treasury"] == 500
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

            # Exercise the complete online hire path used by the 3D client:
            # WebSocket request -> authoritative payment -> street NPC removal
            # -> persistent custom-gang companion returned to the client.
            online_gang = await game.get_custom_gang_for_user(71001)
            game.apply_custom_gang_to_player(
                game._WORLD.players["71001"], online_gang)
            game._WORLD.players["71001"].update({
                "x": 20.0, "y": 20.0,
                "_cash": int((await game.get_character(71001))["cash"]),
            })
            online_bot = {
                "id": "ws-paid-hire", "x": 20.7, "y": 20.0,
                "alive": True, "hp": 115, "max_hp": 115,
                "level": 6, "kind": "street", "weapon": "smg",
                "look": {"skin": 3, "coat": "dark"},
            }
            game._WORLD.city_gangs.append({
                "id": "ws-hire-gang", "faction": "purple",
                "bots": [online_bot],
            })
            cash_before_online_hire = int(
                (await game.get_character(71001))["cash"])
            await ws1.send_json({
                "t": "gang_hire_bot", "d": {"bot_id": "ws-paid-hire"},
            })
            online_hire = await receive_event(ws1, "gang_hire_reply")
            assert online_hire["ok"] and online_hire["cost"] == 500
            assert online_hire["cash"] == cash_before_online_hire - 500
            assert online_hire["npc"]["owner_uid"] == "71001"
            assert online_hire["npc"]["weapon"] == "smg"
            assert not online_bot["alive"] and online_bot["hired_by"] == "71001"
            assert int((await game.get_character(71001))["cash"]) == cash_before_online_hire - 500
            persisted_after_hire = await game.get_custom_gang_for_user(71001)
            persisted_npc = next(
                npc for npc in persisted_after_hire["npcs"]
                if npc["id"] == online_hire["npc"]["id"])
            assert persisted_npc["owner_uid"] == "71001"
            assert persisted_npc["source_bot_id"] == "ws-paid-hire"
            assert persisted_npc["look"] == {"skin": 3, "coat": "dark"}

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

            async with session.post(
                f"{base}/custom-gang/71001/transfer", json={"target_uid": "71002"}
            ) as response:
                assert response.status == 200 and (await response.json())["ok"]
            async with session.post(
                f"{base}/custom-gang/71002/transfer", json={"target_uid": "71001"}
            ) as response:
                assert response.status == 200 and (await response.json())["ok"]
            async with session.post(
                f"{base}/custom-gang/71001/kick", json={"target_uid": "71003"}
            ) as response:
                assert response.status == 200 and (await response.json())["ok"]
            assert await game.get_custom_gang_for_user(71003) is None

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
        server_source = (root / "mafiozi_bot.py").read_text(encoding="utf-8")
        for witness in (
            'id="cgPrimaryColors"', 'id="cgSecondaryColors"',
            "data-aptctl-gang", "Название банды", "drawCustomGangHeadquarters",
            "flag:{primary:m.dataset.primary,secondary:m.dataset.secondary,emblem:m.dataset.emblem}",
            "function _gangHireEligibility", "function _gangMovementBlocked",
            "function _gangLineClear", "hireSelectedGangNpc()",
            "const activeCombatSpace=_gangSpaceKey()", "allied:true",
            "fxNow-(+g._shotAt||0)<240",
            "else if(crewCombat.length)npcSource=[...crewCombat,...npcSource]",
            "const GANG_ORDER_LABELS", "function _setGangOrder",
            "function _gangPathfind", "function _gangFindCover",
            "function _gangShotSafe", "function _gangVehicleTick",
            "const GANG_BLEEDOUT_MS", "function _gangEnterDowned",
            "const atHospital=", "function _gangPlayerFriendly",
            "reloading,reloadProgress", "dodging:fxNow<",
            "kind === 'gang_throwable'", "bot.reloading", "bot.dodging",
        ):
            assert witness in world_source, f"missing UI witness: {witness}"
        for witness in (
            "customGangFlagTexture", "flag.emblem", "THREE.CanvasTexture",
            "disposeTransientObjectTree", "gangHirePrompt", "gangHireInteraction",
            "crewBadgeProfile", "src.allied?0x35ff78", "activeState=shooting?'shoot'",
            "else if(reloading)", "reloading?'reload'", "takingCover",
            "boarding", "gettingUp", "reloadPose=pose.reloading",
            "squadAnimationStates",
        ):
            assert witness in three_source, f"missing 3D witness: {witness}"
        for witness in (
            "def register_gang_throwable", "def _tick_city_gang_throwable_dodge",
            "def _city_gang_shot_safe", "def _city_gang_cover_point",
            "CITY_GANG_GRENADE_NOTICE_R", "'reloadProgress':",
            "elif t == 'grenade':",
        ):
            assert witness in server_source, f"missing enemy AI witness: {witness}"

        print(f"OK: {combinations} flags, Steam session, allied and hostile 3D gang AI, throwable dodge, cover/reload/friendly-fire safety, HTTP, WS, preview, UI and 3D")


if __name__ == "__main__":
    asyncio.run(run())
