import os
import pathlib
import tempfile
import unittest
from unittest import mock

os.environ["BOT_TOKEN"] = "0:npc-damage-authority"

import aiosqlite
import mafiozi_bot as bot


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
SERVER = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


class NpcPlayerDamageAuthorityTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        handle, self.path = tempfile.mkstemp(prefix="npc_damage_", suffix=".db")
        os.close(handle)
        self.old_db = bot.DB_PATH
        bot.DB_PATH = self.path
        await bot.init_db()
        self.uid = 8082331
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                """INSERT INTO characters
                   (telegram_id,name,class,hp,max_hp,cash,armor,combat_version)
                   VALUES(?,?,?,?,?,?,?,0)""",
                (self.uid, "NpcTarget", "killer", 100, 100, 1000, "bulletproof"),
            )
            await db.execute(
                """INSERT INTO inventory
                   (telegram_id,item_id,quantity,armor_hp,armor_max_hp,
                    armor_version,armor_instance_id)
                   VALUES(?,?,1,?,?,1,?)""",
                (self.uid, "bulletproof", 10,
                 bot.ARMOR_MAX_HP["bulletproof"], "npc-authority-armor"),
            )
            await db.commit()

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_db
        try:
            os.unlink(self.path)
        except FileNotFoundError:
            pass

    async def _world_with_target(self):
        world = bot.WorldSim()
        uid = str(self.uid)
        world.add_or_update(uid, "NpcTarget", {}, mode="pvp")
        target = world.players[uid]
        target.update(x=40.0, y=40.0, dead=False, _wanted=2.0,
                      _last_shot_t=999.0, _mode="pvp")
        target["_combat_state"] = await bot.get_authoritative_combat_state(self.uid)
        world._mirror_combat_state(target, target["_combat_state"])
        return world, target

    async def test_server_cop_tick_damages_armor_without_client_report(self):
        world, target = await self._world_with_target()
        cop = world.spawn_cop(45.0, 40.0, str(self.uid), "combat")
        cop["_shot_t"] = 0.0
        with (mock.patch.object(bot.WorldSim, "COP_COMBAT_COUNT", 1),
              mock.patch.object(bot.WorldSim, "COP_SHOOT_DMG", 14),
              mock.patch.object(bot.time, "time", return_value=1000.0),
              mock.patch.object(bot.random, "random", return_value=0.9),
              mock.patch.object(bot, "_world_los", return_value=True),
              mock.patch.object(bot, "_world_is_wall", return_value=False)):
            packets = await world._tick_cops_async(0.1)

        shot = next(packet for packet in packets if packet.get("kind") == "cop_shot")
        self.assertEqual(shot["target_uid"], str(self.uid))
        self.assertEqual(shot["dmg"], 14)
        state = await bot.get_authoritative_combat_state(self.uid)
        self.assertIsNone(state["armor"]["id"])
        self.assertEqual(state["body"]["current"], 96)
        self.assertEqual(state, target["_combat_state"])

        reconnect = await bot.get_authoritative_combat_state(self.uid)
        self.assertEqual(reconnect, state)

        with (mock.patch.object(bot.WorldSim, "COP_COMBAT_COUNT", 1),
              mock.patch.object(bot.time, "time", return_value=1000.2),
              mock.patch.object(bot.random, "random", return_value=0.9),
              mock.patch.object(bot, "_world_los", return_value=True),
              mock.patch.object(bot, "_world_is_wall", return_value=False)):
            cooldown_packets = await world._tick_cops_async(0.1)
        self.assertFalse(any(packet.get("kind") == "cop_shot" for packet in cooldown_packets))
        self.assertEqual(await bot.get_authoritative_combat_state(self.uid), state)

    async def test_range_and_los_reject_before_receipt(self):
        world, _target = await self._world_with_target()
        cop = world.spawn_cop(45.0, 40.0, str(self.uid), "combat")
        cop["_shot_t"] = 0.0
        with (mock.patch.object(bot.WorldSim, "COP_COMBAT_COUNT", 1),
              mock.patch.object(bot.time, "time", return_value=1000.0),
              mock.patch.object(bot.random, "random", return_value=0.9),
              mock.patch.object(bot, "_world_los", return_value=False),
              mock.patch.object(bot, "_world_is_wall", return_value=False)):
            packets = await world._tick_cops_async(0.1)
        self.assertFalse(any(packet.get("kind") == "cop_shot" for packet in packets))
        state = await bot.get_authoritative_combat_state(self.uid)
        self.assertEqual(state["armor"]["current"], 10)
        self.assertEqual(state["combat_version"], 0)

    def test_damage_identity_is_server_owned_and_restart_safe(self):
        first, second = bot.WorldSim(), bot.WorldSim()
        event_a = first._next_world_damage_event("cop", "cop2", str(self.uid))
        event_b = first._next_world_damage_event("cop", "cop2", str(self.uid))
        event_after_restart = second._next_world_damage_event("cop", "cop2", str(self.uid))
        self.assertEqual(len({event_a, event_b, event_after_restart}), 3)
        self.assertIn(first._combat_boot_id, event_a)
        self.assertIn(f":{self.uid}:", event_a)

    def test_client_local_actors_cannot_claim_authenticated_hits(self):
        self.assertNotIn("npc_melee_shoot", WORLD)
        self.assertNotIn("npc_melee_shoot", SERVER)
        hurt = WORLD.split("function _hurtLocal(dmg, by", 1)[1].split("let myKills", 1)[0]
        self.assertIn("if(!_LOCAL_PREVIEW&&!_worldDirectCombatDemo)return", hurt)
        self.assertIn(
            "function _localHostileCanResolveHit(){return _LOCAL_PREVIEW||_worldDirectCombatDemo;}",
            WORLD,
        )

    def test_server_projectile_binds_event_when_fired(self):
        world = bot.WorldSim()
        target = {"uid": str(self.uid)}
        world._enqueue_bot_shot(target=target, sx=1.0, sy=1.0, tx=2.0, ty=2.0,
                                weapon="pistol", bot_id="bot7", tid="street4")
        shot = world._pending_bot_shots[-1]
        self.assertIn("event_id", shot)
        self.assertIn(world._combat_boot_id, shot["event_id"])
        self.assertIn(str(self.uid), shot["event_id"])

    async def test_bound_projectile_survives_disconnect_exactly_once(self):
        world, _target = await self._world_with_target()
        world._enqueue_bot_shot(
            target=world.players[str(self.uid)], sx=39.0, sy=40.0,
            tx=40.0, ty=40.0, weapon="pistol", bot_id="bot9", tid="street9",
        )
        world._pending_bot_shots[-1]["apply_at"] = 0.0
        world.remove(str(self.uid))

        first = await world._tick_pending_bot_shots_async()
        self.assertEqual(len(first), 1)
        self.assertFalse(first[0]["miss"])
        state = await bot.get_authoritative_combat_state(self.uid)
        self.assertEqual(state["combat_version"], 1)
        self.assertLess(state["armor"]["current"], 10)

        second = await world._tick_pending_bot_shots_async()
        self.assertEqual(second, [])
        self.assertEqual(await bot.get_authoritative_combat_state(self.uid), state)

    async def test_offline_projectiles_do_not_damage_a_corpse_twice(self):
        world, target = await self._world_with_target()
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                "UPDATE characters SET hp=4,armor=NULL WHERE telegram_id=?",
                (self.uid,),
            )
            await db.execute("DELETE FROM inventory WHERE telegram_id=?", (self.uid,))
            await db.commit()
        for bot_id in ("lethal1", "lethal2"):
            world._enqueue_bot_shot(
                target=target, sx=39.0, sy=40.0, tx=40.0, ty=40.0,
                weapon="pistol", bot_id=bot_id, tid="street9",
            )
            world._pending_bot_shots[-1]["apply_at"] = 0.0
            world._pending_bot_shots[-1]["dmg"] = 14
        event_ids = [shot["event_id"] for shot in world._pending_bot_shots]
        world.remove(str(self.uid))

        packets = await world._tick_pending_bot_shots_async()
        self.assertEqual(sum(bool(packet["killed"]) for packet in packets), 1)
        state = await bot.get_authoritative_combat_state(self.uid)
        self.assertTrue(state["body"]["dead"])
        self.assertEqual(state["combat_version"], 1)
        self.assertIsNotNone(await bot.get_damage_event_receipt(self.uid, event_ids[0]))
        self.assertIsNone(await bot.get_damage_event_receipt(self.uid, event_ids[1]))

    def test_every_server_npc_family_uses_restart_safe_identity(self):
        self.assertNotIn('f"world:cop:{cop.get(\'id\')}:{self.tick_no}"', SERVER)
        self.assertNotIn('f"world:inkass:{e.get(\'id\')}:{actor.get(\'id\')}:{self.tick_no}"', SERVER)
        self.assertNotIn('f"world:michael:{g.get(\'id\')}:{self.tick_no}"', SERVER)
        self.assertIn("'inkass', f'{e.get(\"id\")}:{actor.get(\"id\")}'", SERVER)
        self.assertIn("'michael', g.get('id'), target.get('uid')", SERVER)


if __name__ == "__main__":
    unittest.main()
