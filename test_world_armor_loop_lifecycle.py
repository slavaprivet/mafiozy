import asyncio
import inspect
import os
import tempfile
import unittest
from unittest import mock

os.environ.setdefault("BOT_TOKEN", "0:test")

import aiosqlite
import mafiozi_bot as bot


class WorldArmorLoopLifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        handle, self.path = tempfile.mkstemp(prefix="armor_loop_", suffix=".db")
        os.close(handle)
        self.original_db_path = bot.DB_PATH
        bot.DB_PATH = self.path
        await bot.init_db()

    async def asyncTearDown(self):
        bot.DB_PATH = self.original_db_path
        try:
            os.unlink(self.path)
        except FileNotFoundError:
            pass

    async def add_character(self, uid, *, armor=None, armor_hp=None):
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                """INSERT INTO characters
                   (telegram_id,name,class,hp,max_hp,cash,armor,combat_version)
                   VALUES(?,?,?,?,?,?,?,0)""",
                (uid, f"P{uid}", "killer", 100, 100, 1000, armor),
            )
            if armor:
                maximum = bot.ARMOR_MAX_HP[armor]
                await db.execute(
                    """INSERT INTO inventory
                       (telegram_id,item_id,quantity,armor_hp,armor_max_hp,
                        armor_version,armor_instance_id)
                       VALUES(?,?,1,?,?,1,?)""",
                    (uid, armor, armor_hp if armor_hp is not None else maximum,
                     maximum, f"loop:{uid}:{armor}"),
                )
            await db.commit()

    async def test_real_loop_recovers_on_same_cache_after_tick_failure(self):
        await self.add_character(8082001)
        world = bot.WorldSim()
        world.add_or_update("8082001", "LoopProbe", {}, mode="pvp")
        original_player = world.players["8082001"]
        recovered = asyncio.Event()
        calls = 0

        async def flaky_tick_event(_world, _dt):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise RuntimeError("forced transient tick failure")
            recovered.set()
            _world.alive = False
            return []

        with mock.patch.object(bot.WorldSim, "tick_event", new=flaky_tick_event):
            task = asyncio.create_task(bot._world_run_loop(world))
            await asyncio.wait_for(recovered.wait(), timeout=2)
            await asyncio.wait_for(task, timeout=2)

        self.assertEqual(calls, 2)
        self.assertIs(world.players["8082001"], original_player)

    async def test_convoy_spawn_does_not_poison_supervised_world_loop(self):
        source = inspect.getsource(bot.WorldSim.spawn_event)
        self.assertNotIn("float(bx)", source)
        self.assertNotIn("float(by)", source)
        await self.add_character(8082025)
        world = bot.WorldSim()
        world.add_or_update("8082025", "ConvoyProbe", {}, mode="pvp")
        original_player = world.players["8082025"]
        world.spawn_event()
        self.assertIsNotNone(world.event)
        boss = world.event["boss"]
        self.assertEqual(boss["_patrol_x"], float(world.INKASS_START_X))
        self.assertEqual(boss["_patrol_y"], float(world.INKASS_START_Y))

        original_tick_event = world.tick_event

        async def one_cycle(_world, _dt):
            packets = await original_tick_event(_dt)
            _world.alive = False
            return packets

        with mock.patch.object(bot.WorldSim, "tick_event", new=one_cycle):
            task = asyncio.create_task(bot._world_run_loop(world))
            task_identity = id(task)
            await asyncio.wait_for(task, timeout=8)

        self.assertGreater(world.tick_no, 0)
        self.assertEqual(id(task), task_identity)
        self.assertIs(world.players["8082025"], original_player)
        snapshot = world.snapshot_for("8082025")
        self.assertEqual(snapshot["t"], "snap")
        self.assertIsNotNone(snapshot["d"]["me"])
        self.assertIn("combat_state", snapshot["d"]["me"])

    async def test_world_get_fails_closed_instead_of_splitting_active_cache(self):
        old_world, old_task = bot._WORLD, bot._WORLD_TASK
        failed = bot.WorldSim()
        failed.alive = False
        failed.connections["8082001"] = object()
        bot._WORLD, bot._WORLD_TASK = failed, None
        try:
            with self.assertRaisesRegex(RuntimeError, "active connections"):
                bot._world_get()
            self.assertIs(bot._WORLD, failed)
        finally:
            bot._WORLD, bot._WORLD_TASK = old_world, old_task

    async def test_sqlite_busy_retries_same_event_exactly_once(self):
        await self.add_character(8082002, armor="bulletproof", armor_hp=20)
        locker = await aiosqlite.connect(self.path)
        await locker.execute("BEGIN IMMEDIATE")

        async def release_lock():
            await asyncio.sleep(0.12)
            await locker.commit()
            await locker.close()

        release = asyncio.create_task(release_lock())
        result = await bot.apply_damage_transaction(
            8082002, "busy:bullet:1", "bullet", 12)
        await release
        replay = await bot.apply_damage_transaction(
            8082002, "busy:bullet:1", "bullet", 12)

        self.assertEqual(result["armor"]["current"], 8)
        self.assertTrue(replay["replayed"])
        self.assertEqual(replay["combat_version"], result["combat_version"])

    async def test_pvp_same_shot_replays_before_weapon_cooldown(self):
        await self.add_character(8082010)
        await self.add_character(8082011)
        async with aiosqlite.connect(self.path) as db:
            await db.execute("INSERT INTO weapon_ammo(telegram_id,weapon_key,magazine,version) VALUES(8082010,'pistol',1,1)")
            await db.commit()
        world = bot.WorldSim()
        for index, uid in enumerate(("8082010", "8082011")):
            world.add_or_update(uid, f"P{uid}", {}, mode="pvp")
            player = world.players[uid]
            player["x"] = world.ARENA_C0 + 2 + index
            player["y"] = world.ARENA_R0 + 2
            player["_weapon_classes"] = {"pistol"}

        first = await world.apply_player_shoot(
            "8082010", "8082011", "pistol", "same-shot")
        replay = await world.apply_player_shoot(
            "8082010", "8082011", "pistol", "same-shot")

        self.assertIsNotNone(first)
        self.assertTrue(replay["replayed"])
        self.assertGreater(replay["dmg"], 0)
        self.assertEqual(replay["dmg"], first["dmg"])
        state = await bot.get_authoritative_combat_state(8082011)
        self.assertEqual(state["combat_version"], 1)

    async def test_stale_receipt_replay_never_rolls_live_state_backward(self):
        await self.add_character(8082020)
        await self.add_character(8082021)
        async with aiosqlite.connect(self.path) as db:
            await db.execute("INSERT INTO weapon_ammo(telegram_id,weapon_key,magazine,version) VALUES(8082020,'pistol',1,1)")
            await db.commit()
        world = bot.WorldSim()
        for index, uid in enumerate(("8082020", "8082021")):
            world.add_or_update(uid, f"P{uid}", {}, mode="pvp")
            player = world.players[uid]
            player["x"] = world.ARENA_C0 + 2 + index
            player["y"] = world.ARENA_R0 + 2
            player["_weapon_classes"] = {"pistol"}
            player["_combat_state"] = await bot.get_authoritative_combat_state(int(uid))

        first = await world.apply_player_shoot(
            "8082020", "8082021", "pistol", "old-shot")
        self.assertIsNotNone(first)
        await world.apply_authoritative_damage(
            "8082021", "later-hit", "bullet", 7)
        healed = await bot.set_authoritative_body_state(8082021, 100)
        world._mirror_combat_state(world.players["8082021"], healed)

        replay = await world.apply_player_shoot(
            "8082020", "8082021", "pistol", "old-shot")
        self.assertTrue(replay["replayed"])
        self.assertEqual(world.players["8082021"]["hp"], 100)
        self.assertEqual(replay["combat_state"], healed)

    async def test_exact_break_live_snapshot_matches_reconnect_shape(self):
        await self.add_character(8082022, armor="bulletproof", armor_hp=5)
        world = bot.WorldSim()
        world.add_or_update("8082022", "BreakProbe", {}, mode="pvp")
        player = world.players["8082022"]
        player["_combat_state"] = await bot.get_authoritative_combat_state(8082022)

        await world.apply_authoritative_damage(
            "8082022", "exact-break-live", "bullet", 5)
        reconnect = await bot.get_authoritative_combat_state(8082022)

        self.assertEqual(player["_combat_state"], reconnect)
        self.assertIsNone(reconnect["armor"]["id"])
        self.assertFalse(reconnect["armor"]["broken"])

    async def test_body_storage_failure_does_not_mutate_live_heal_mirror(self):
        await self.add_character(8082023)
        world = bot.WorldSim()
        world.add_or_update("8082023", "RollbackProbe", {}, mode="pvp")
        player = world.players["8082023"]
        player["hp"] = 40
        player["max_hp"] = 100
        player["x"], player["y"] = world.HOSPITAL_X, world.HOSPITAL_Y

        with mock.patch.object(
                bot, "set_authoritative_body_state",
                side_effect=RuntimeError("forced storage failure")):
            with self.assertRaisesRegex(RuntimeError, "forced storage failure"):
                await world.world_heal("8082023")

        self.assertEqual(player["hp"], 40)
        self.assertFalse(player["dead"])

    async def test_death_arrest_release_and_transport_are_durable(self):
        await self.add_character(8082024)
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                "UPDATE characters SET hp=0,respawn_at=? WHERE telegram_id=?",
                (1.0, 8082024))
            await db.commit()
        world = bot.WorldSim()
        world.add_or_update("8082024", "LifecycleProbe", {}, mode="pvp")
        player = world.players["8082024"]
        player["_combat_state"] = await bot.get_authoritative_combat_state(8082024)
        world._mirror_combat_state(player, player["_combat_state"])

        transport = await world.emergency_transport("8082024", True)
        self.assertTrue(transport["ok"])
        async with aiosqlite.connect(self.path) as db:
            persisted_hold = (await (await db.execute(
                "SELECT respawn_at FROM characters WHERE telegram_id=?",
                (8082024,))).fetchone())[0]
        self.assertAlmostEqual(persisted_hold, transport["hold_until"], delta=0.1)

        player["_police_cuffed_by"] = "cop"
        player["_police_death_arrest"] = True
        released = await world._release_online_arrest("8082024", "cop_left")
        self.assertTrue(released["death_arrest"])
        state = await bot.get_authoritative_combat_state(8082024)
        self.assertEqual(state["body"]["current"], 25)
        self.assertEqual(player["_combat_state"], state)


if __name__ == "__main__":
    unittest.main()
