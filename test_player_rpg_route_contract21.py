"""Read-only audit of actual player RPG packet branches and durable receipts.

Only an isolated temporary DB is mutated. Production WS branch bodies are
compiled unchanged inside a one-iteration loop so their `continue` guard works.
This verifies route authority; it is not a player AoE implementation or LIVE QA.
"""
import ast
import builtins
import copy
import io
import json
import os
from pathlib import Path
import socket
import sqlite3
import tempfile
import unittest
from unittest import mock

import aiosqlite

# mafiozi_bot writes env BOT_TOKEN to .bot-token at import. Audit code must not
# overwrite a user's local credential, including with a harmless fixture token.
_audit_open = builtins.open
_audit_io_open = io.open
_audit_os_open = os.open


def _read_only_bot_import_open(file, mode="r", *args, **kwargs):
    if any(flag in mode for flag in "wax+"):
        raise PermissionError("Read-only audit forbids import-time file writes")
    return _audit_open(file, mode, *args, **kwargs)


def _read_only_bot_import_io_open(file, mode="r", *args, **kwargs):
    if any(flag in mode for flag in "wax+"):
        raise PermissionError("Read-only audit forbids import-time file writes")
    return _audit_io_open(file, mode, *args, **kwargs)


def _read_only_bot_import_os_open(file, flags, *args, **kwargs):
    if flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND):
        raise PermissionError("Read-only audit forbids import-time file writes")
    return _audit_os_open(file, flags, *args, **kwargs)


def _forbid_import_io(*args, **kwargs):
    raise PermissionError("Read-only audit forbids import-time database/network access")


with (mock.patch.dict(os.environ, {"BOT_TOKEN": "0:player-rpg-route-audit21"}),
      mock.patch.object(builtins, "open", side_effect=_read_only_bot_import_open),
      mock.patch.object(io, "open", side_effect=_read_only_bot_import_io_open),
      mock.patch.object(os, "open", side_effect=_read_only_bot_import_os_open),
      mock.patch.object(sqlite3, "connect", side_effect=_forbid_import_io),
      mock.patch.object(aiosqlite, "connect", side_effect=_forbid_import_io),
      mock.patch.object(socket, "create_connection", side_effect=_forbid_import_io),
      mock.patch.object(socket.socket, "connect", side_effect=_forbid_import_io)):
    import mafiozi_bot as bot


SOURCE_TREE = ast.parse(Path(__file__).with_name("mafiozi_bot.py").read_text(encoding="utf-8"))


def production_packet_branch(kind):
    candidates = [node for node in ast.walk(SOURCE_TREE)
                  if isinstance(node, ast.If)
                  and isinstance(node.test, ast.Compare)
                  and isinstance(node.test.left, ast.Name)
                  and node.test.left.id == "t"
                  and len(node.test.comparators) == 1
                  and isinstance(node.test.comparators[0], ast.Constant)
                  and node.test.comparators[0].value == kind]
    assert len(candidates) == 1, (kind, len(candidates))
    wrapper = ast.parse("async def handle(world, ws, uid, d):\n"
                        "    npc_melee_result = None\n"
                        "    for audit_iteration in range(1):\n"
                        "        pass\n")
    wrapper.body[0].body[1].body = copy.deepcopy(candidates[0].body)
    scope = dict(vars(bot))
    exec(compile(ast.fix_missing_locations(wrapper), f"<actual-{kind}-branch>", "exec"), scope)
    return scope["handle"]


HANDLERS = {kind: production_packet_branch(kind) for kind in (
    "weapon_fire", "cop_shoot", "event_shoot", "mg_shoot", "aggro_shoot", "player_shoot")}


class CaptureSocket:
    def __init__(self):
        self.messages = []

    async def send_str(self, payload):
        self.messages.append(json.loads(payload))


class PlayerRpgRouteContract21(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        fd, self.path = tempfile.mkstemp(prefix="player_rpg_route21_", suffix=".db")
        os.close(fd)
        self.old_db = bot.DB_PATH
        bot.DB_PATH = self.path
        await bot.init_db()
        self.uid, self.target_uid = "9122101", "9122102"
        async with aiosqlite.connect(self.path) as db:
            for uid in (self.uid, self.target_uid):
                await db.execute("""INSERT INTO characters
                    (telegram_id,name,class,hp,max_hp,cash,combat_version)
                    VALUES(?,?,?,100,100,1000,0)""", (int(uid), f"RpgAudit{uid}", "killer"))
            await db.execute("""INSERT INTO weapon_ammo
                (telegram_id,weapon_key,magazine,version) VALUES(?,'rpg',1,1)""", (int(self.uid),))
            await db.commit()
        self.world = bot.WorldSim()
        for index, uid in enumerate((self.uid, self.target_uid)):
            self.world.add_or_update(uid, f"Audit{uid}", {}, mode="pvp")
            self.world.players[uid].update(x=50.0 + index * .1, y=26.0,
                dead=False, _mode="pvp", _weapon_classes={"rpg"})
        self.world.cops = [dict(id=f"cop{index}", x=50.2 + index * .1, y=26., hp=500,
                               alive=True) for index in range(2)]
        self.ws = CaptureSocket()
        self.world.connections[self.uid] = self.ws
        self.random_patch = mock.patch.object(bot.random, "random", return_value=.9)
        self.los_patch = mock.patch.object(bot, "_world_los", return_value=True)
        self.random_patch.start()
        self.los_patch.start()

    async def asyncTearDown(self):
        self.los_patch.stop()
        self.random_patch.stop()
        bot.DB_PATH = self.old_db
        os.unlink(self.path)

    async def packet(self, kind, shot_id="rpg21", **data):
        self.ws.messages.clear()
        await HANDLERS[kind](self.world, self.ws, self.uid,
                             {"shot_id": shot_id, "weapon": "rpg", **data})
        return [message["d"] for message in self.ws.messages]

    async def magazine(self):
        return (await bot.get_authoritative_ammo_state(int(self.uid)))["mags"]["rpg"]

    async def test_launch_world_route_blocks_every_remote_route(self):
        launch = await self.packet("weapon_fire", route="rpg_world")
        self.assertTrue(launch[0]["ok"])
        self.assertEqual((launch[0]["target_kind"], launch[0]["target_id"]), ("world", "rpg_world"))
        self.assertEqual(await self.magazine(), 0)
        for kind, data in (("cop_shoot", {"target": "cop0"}),
                           ("event_shoot", {"target": "b"}),
                           ("mg_shoot", {"target": "mg0"}),
                           ("aggro_shoot", {"target": "gbot0"}),
                           ("player_shoot", {"target_uid": self.target_uid})):
            reply = await self.packet(kind, **data)
            self.assertEqual(reply[0]["error"], "shot_conflict", kind)
        self.assertEqual([cop["hp"] for cop in self.world.cops], [500, 500])
        self.assertEqual((await bot.get_authoritative_combat_state(int(self.target_uid)))["body"]["current"], 100)
        self.assertEqual(await self.magazine(), 0)

    async def test_exact_launch_replay_consumes_only_one_round(self):
        first = await self.packet("weapon_fire", route="rpg_world")
        replay = await self.packet("weapon_fire", route="rpg_world")
        self.assertFalse(first[0]["replayed"])
        self.assertTrue(replay[0]["replayed"])
        self.assertEqual(await self.magazine(), 0)
        async with aiosqlite.connect(self.path) as db:
            row = await (await db.execute("SELECT COUNT(*) FROM weapon_shots WHERE shooter_uid=?",
                                         (int(self.uid),))).fetchone()
        self.assertEqual(row[0], 1)

    async def test_impact_only_remote_route_hits_once_without_aoe(self):
        first = await self.packet("cop_shoot", target="cop0")
        self.assertTrue(first[0]["ok"])
        self.assertEqual(first[1]["kind"], "cop_hit")
        self.assertEqual(first[1]["dmg"], 160)
        self.assertEqual(first[1]["shot_id"], "rpg21")
        self.assertEqual([cop["hp"] for cop in self.world.cops], [340, 500])
        replay = await self.packet("cop_shoot", target="cop0")
        self.assertEqual(len(replay), 1)
        self.assertTrue(replay[0]["replayed"])
        conflict = await self.packet("cop_shoot", target="cop1")
        self.assertEqual(conflict[0]["error"], "shot_conflict")
        fallback = await self.packet("weapon_fire", route="rpg_world")
        self.assertEqual(fallback[0]["error"], "shot_conflict")
        self.assertEqual([cop["hp"] for cop in self.world.cops], [340, 500])
        self.assertEqual(await self.magazine(), 0)

    async def test_local_world_route_does_not_damage_nearby_server_npcs(self):
        await self.packet("weapon_fire", route="rpg_world", r=26., c=50.2, damage=999999)
        self.assertEqual([cop["hp"] for cop in self.world.cops], [500, 500])
        self.assertEqual((await bot.get_authoritative_combat_state(int(self.target_uid)))["body"]["current"], 100)

    async def test_ownership_and_no_round_still_gate_claim(self):
        self.world.players[self.uid]["_weapon_classes"] = {"pistol"}
        unowned = await self.packet("weapon_fire", route="rpg_world")
        self.assertEqual(unowned[0]["error"], "weapon_denied")
        self.assertEqual(await self.magazine(), 1)
        self.world.players[self.uid]["_weapon_classes"] = {"rpg"}
        await self.packet("weapon_fire", route="rpg_world")
        self.world.players[self.uid]["_weapon_shot_t"] = 0
        empty = await self.packet("weapon_fire", shot_id="empty21", route="rpg_world")
        self.assertEqual(empty[0]["error"], "no_round")


if __name__ == "__main__":
    unittest.main()
