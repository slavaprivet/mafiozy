import asyncio
import os
import tempfile
import unittest
from unittest import mock

os.environ["BOT_TOKEN"] = "0:server-authoritative-ammo"

import aiosqlite
import mafiozi_bot as bot


class ServerAuthoritativeAmmoTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        handle, self.path = tempfile.mkstemp(prefix="auth_ammo_", suffix=".db")
        os.close(handle)
        self.old_db = bot.DB_PATH
        bot.DB_PATH = self.path
        await bot.init_db()
        self.shooter, self.target_a, self.target_b = 8082601, 8082602, 8082603
        async with aiosqlite.connect(self.path) as db:
            for uid in (self.shooter, self.target_a, self.target_b):
                await db.execute("""INSERT INTO characters
                    (telegram_id,name,class,hp,max_hp,cash,combat_version)
                    VALUES(?,?,?,100,100,1000,0)""", (uid, f"QA{uid}", "killer"))
            await db.commit()

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_db
        try:
            os.unlink(self.path)
        except FileNotFoundError:
            pass

    async def _set_mag(self, rounds=1):
        async with aiosqlite.connect(self.path) as db:
            await db.execute("""INSERT INTO weapon_ammo
                (telegram_id,weapon_key,magazine,version) VALUES(?,?,?,1)""",
                (self.shooter, "pistol", rounds))
            await db.commit()

    async def _shoot(self, target, shot_id="shot-1"):
        return await bot.apply_authoritative_player_shot_transaction(
            self.shooter, target, shot_id, "pistol", "player", str(target),
            24, 0.38, "inventory:1")

    async def test_new_profile_state_is_explicit_zero(self):
        state = await bot.get_authoritative_ammo_state(self.shooter)
        self.assertEqual(state["mags"]["nagan"], 0)
        self.assertEqual(state["reserve"]["magnum"], 0)
        self.assertEqual(state["ammo_version"], 0)

    async def test_last_round_damage_replay_and_changed_target_conflict(self):
        await self._set_mag(1)
        first = await self._shoot(self.target_a)
        self.assertTrue(first["ok"])
        self.assertEqual(first["ammo_state"]["mags"]["pistol"], 0)
        self.assertEqual(first["damage"]["body"]["current"], 76)
        replay = await self._shoot(self.target_a)
        self.assertTrue(replay["replayed"])
        conflict = await self._shoot(self.target_b)
        self.assertEqual(conflict, {"ok": False, "error": "shot_conflict"})
        self.assertEqual((await bot.get_authoritative_combat_state(self.target_b))["body"]["current"], 100)

    async def test_zero_ammo_rejects_without_receipt(self):
        denied = await self._shoot(self.target_a, "empty")
        self.assertEqual(denied["error"], "no_round")
        async with aiosqlite.connect(self.path) as db:
            count = (await (await db.execute(
                "SELECT COUNT(*) FROM weapon_shots WHERE shooter_uid=?",
                (self.shooter,))).fetchone())[0]
        self.assertEqual(count, 0)

    async def test_concurrent_duplicate_consumes_and_damages_once(self):
        await self._set_mag(1)
        first, second = await asyncio.gather(
            self._shoot(self.target_a, "dupe"), self._shoot(self.target_a, "dupe"))
        self.assertEqual(sum(not result.get("replayed", False) for result in (first, second)), 1)
        self.assertEqual((await bot.get_authoritative_ammo_state(self.shooter))["mags"]["pistol"], 0)
        self.assertEqual((await bot.get_authoritative_combat_state(self.target_a))["body"]["current"], 76)

    async def test_twenty_concurrent_duplicates_serialize_once(self):
        await self._set_mag(1)
        results = await asyncio.gather(*(
            self._shoot(self.target_a, "dupe-20") for _ in range(20)))
        self.assertEqual(sum(not result.get("replayed", False)
                             for result in results), 1)
        self.assertTrue(all(result.get("ok") for result in results))
        self.assertEqual((await bot.get_authoritative_ammo_state(
            self.shooter))["mags"]["pistol"], 0)
        self.assertEqual((await bot.get_authoritative_combat_state(
            self.target_a))["body"]["current"], 76)

    async def test_twenty_concurrent_world_claims_consume_once(self):
        await self._set_mag(1)
        profile = dict(bot.WorldSim.WEAPON_PROFILE["pistol"])
        results = await asyncio.gather(*(
            bot.claim_authoritative_weapon_fire(
                self.shooter, "world-dupe-20", "pistol", "world", "miss",
                0, profile, "inventory:1") for _ in range(20)))
        self.assertEqual(sum(not result.get("replayed", False)
                             for result in results), 1)
        self.assertTrue(all(result.get("ok") for result in results))
        self.assertEqual((await bot.get_authoritative_ammo_state(
            self.shooter))["mags"]["pistol"], 0)

    async def test_storage_failure_rolls_back_ammo_and_damage(self):
        await self._set_mag(1)
        async with aiosqlite.connect(self.path) as db:
            await db.execute("""CREATE TRIGGER fail_shot BEFORE INSERT ON weapon_shots
                BEGIN SELECT RAISE(ABORT,'forced shot receipt failure'); END""")
            await db.commit()
        with self.assertRaises(aiosqlite.IntegrityError):
            await self._shoot(self.target_a, "rollback")
        self.assertEqual((await bot.get_authoritative_ammo_state(self.shooter))["mags"]["pistol"], 1)
        self.assertEqual((await bot.get_authoritative_combat_state(self.target_a))["body"]["current"], 100)

    async def test_purchase_reload_and_reconnect_are_durable(self):
        purchase = await bot.purchase_ammo_transaction(
            self.shooter, "ammo_magnum", "buy-1")
        self.assertTrue(purchase["ok"])
        self.assertEqual(purchase["ammo_state"]["reserve"]["magnum"], 24)
        purchase_version = purchase["ammo_state"]["ammo_version"]
        replay = await bot.purchase_ammo_transaction(
            self.shooter, "ammo_magnum", "buy-1")
        self.assertTrue(replay["replayed"])
        start = await bot.weapon_reload_transaction(
            self.shooter, "nagan", "reload-1", now=100.0)
        self.assertTrue(start["pending"])
        self.assertGreater(start["ammo_state"]["ammo_version"], purchase_version)
        early = await bot.weapon_reload_transaction(
            self.shooter, "nagan", "reload-1", now=100.1)
        self.assertTrue(early["pending"])
        done = await bot.weapon_reload_transaction(
            self.shooter, "nagan", "reload-1", now=101.0)
        self.assertFalse(done["pending"])
        self.assertGreater(done["ammo_state"]["ammo_version"],
                           start["ammo_state"]["ammo_version"])
        reconnect = await bot.get_authoritative_ammo_state(self.shooter)
        self.assertEqual(reconnect["mags"]["nagan"], 1)
        self.assertEqual(reconnect["reserve"]["magnum"], 23)

        duplicate_done = await bot.weapon_reload_transaction(
            self.shooter, "nagan", "reload-1", now=102.0)
        self.assertTrue(duplicate_done["replayed"])
        self.assertEqual(duplicate_done["ammo_state"], reconnect)

        second = await bot.purchase_ammo_transaction(
            self.shooter, "ammo_magnum", "buy-qty", qty=1)
        conflict = await bot.purchase_ammo_transaction(
            self.shooter, "ammo_magnum", "buy-qty", qty=2)
        self.assertTrue(second["ok"])
        self.assertEqual(conflict["error"], "purchase_conflict")

    async def test_reload_cancel_is_durable_and_idempotent(self):
        await bot.grant_ammo_transaction(self.shooter, "reload-loot", "9mm", 24)
        start = await bot.weapon_reload_transaction(
            self.shooter, "pistol", "cancel-me", now=100.0)
        self.assertTrue(start["pending"])
        cancel = await bot.cancel_weapon_reload_transaction(
            self.shooter, "cancel-me")
        replay = await bot.cancel_weapon_reload_transaction(
            self.shooter, "cancel-me")
        self.assertTrue(cancel["cancelled"])
        self.assertFalse(replay["cancelled"])
        self.assertEqual((await bot.get_authoritative_ammo_state(
            self.shooter))["reloads"], {})

    async def test_world_route_uses_same_ammo_and_damage_transaction(self):
        await self._set_mag(1)
        world = bot.WorldSim()
        for uid in (self.shooter, self.target_a, self.target_b):
            world.add_or_update(str(uid), f"QA{uid}", {}, mode="pvp")
            player = world.players[str(uid)]
            player.update(x=50.0 + (uid-self.shooter)*0.2, y=26.0,
                          dead=False, _mode="pvp", _weapon_classes={"pistol"})
            state = await bot.get_authoritative_combat_state(uid)
            world._mirror_combat_state(player, state)
        with (mock.patch.object(bot.random, "random", return_value=0.9),
              mock.patch.object(bot, "_world_los", return_value=True)):
            first = await world.apply_player_shoot(
                str(self.shooter), str(self.target_a), "pistol", "world-shot")
            replay = await world.apply_player_shoot(
                str(self.shooter), str(self.target_a), "pistol", "world-shot")
            conflict = await world.apply_player_shoot(
                str(self.shooter), str(self.target_b), "pistol", "world-shot")
        self.assertEqual(first["dmg"], 24)
        self.assertFalse(first.get("replayed", False))
        self.assertTrue(replay["replayed"])
        self.assertFalse(replay["killed"])
        self.assertEqual(conflict["error"], "shot_conflict")
        self.assertEqual((await bot.get_authoritative_combat_state(self.target_a))["body"]["current"], 76)
        self.assertEqual((await bot.get_authoritative_combat_state(self.target_b))["body"]["current"], 100)

    async def test_legacy_pack_migrates_once_but_ownership_never_grants_ammo(self):
        async with aiosqlite.connect(self.path) as db:
            await db.execute("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(?,?,1)",
                             (self.shooter, "nagan"))
            await db.commit()
        empty = await bot.get_authoritative_ammo_state(self.shooter)
        self.assertEqual(empty["reserve"]["magnum"], 0)
        async with aiosqlite.connect(self.path) as db:
            await db.execute("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(?,?,2)",
                             (self.shooter, "ammo_magnum"))
            await db.commit()
        migrated = await bot.get_authoritative_ammo_state(self.shooter)
        self.assertEqual(migrated["reserve"]["magnum"], 48)
        async with aiosqlite.connect(self.path) as db:
            await db.execute("UPDATE ammo_reserve SET rounds=0 WHERE telegram_id=? AND ammo_type='magnum'",
                             (self.shooter,))
            await db.commit()
        self.assertEqual((await bot.get_authoritative_ammo_state(self.shooter))["reserve"]["magnum"], 0)

    async def test_profile_delete_cleans_shooter_keyed_state(self):
        account = 60601
        async with aiosqlite.connect(self.path) as db:
            await db.execute("""INSERT INTO account_characters
                (account_id,character_id,slot,created_at) VALUES(?,?,1,1)""",
                (account, self.shooter))
            await db.execute("""INSERT INTO weapon_shots
                (shooter_uid,shot_id,weapon_key,weapon_generation,target_kind,
                 target_id,result_json,created_at) VALUES(?,?,?,?,?,?,?,?)""",
                (self.shooter, "cleanup", "pistol", "inventory:1", "player",
                 str(self.target_a), "{}", 1))
            await db.commit()
        self.assertTrue(await bot.delete_account_profile(account, self.shooter))
        async with aiosqlite.connect(self.path) as db:
            count = (await (await db.execute(
                "SELECT COUNT(*) FROM weapon_shots WHERE shooter_uid=?",
                (self.shooter,))).fetchone())[0]
        self.assertEqual(count, 0)

    async def test_route_switching_and_replay_cannot_spend_twice(self):
        await self._set_mag(2)
        profile = dict(bot.WorldSim.WEAPON_PROFILE["pistol"])
        first = await bot.claim_authoritative_weapon_fire(
            self.shooter, "route-1", "pistol", "cop", "cop7", 0,
            profile, "inventory:1")
        replay = await bot.claim_authoritative_weapon_fire(
            self.shooter, "route-1", "pistol", "cop", "cop7", 0,
            profile, "inventory:1")
        switched = await bot.claim_authoritative_weapon_fire(
            self.shooter, "route-1", "pistol", "aggro", "bot7", 0,
            profile, "inventory:1")
        self.assertTrue(first["ok"])
        self.assertTrue(replay["replayed"])
        self.assertEqual(switched["error"], "shot_conflict")
        self.assertEqual((await bot.get_authoritative_ammo_state(
            self.shooter))["mags"]["pistol"], 1)

    async def test_loot_grant_is_durable_capped_and_idempotent(self):
        first = await bot.grant_ammo_transaction(
            self.shooter, "loot-7", "9mm", 18)
        replay = await bot.grant_ammo_transaction(
            self.shooter, "loot-7", "9mm", 18)
        self.assertEqual(first["rounds_added"], 18)
        self.assertTrue(replay["replayed"])
        self.assertEqual(replay["ammo_state"]["reserve"]["9mm"], 18)

    async def test_world_source_threads_one_id_and_never_trusts_damage(self):
        with open("world.html", encoding="utf-8") as handle:
            source = handle.read()
        with open("mafiozi_bot.py", encoding="utf-8") as handle:
            backend = handle.read()
        self.assertIn("_authoritativeShotId = _newCombatEventId()", source)
        spend = source[source.index("function _spendWeaponRound"):
                       source.index("function addAmmoPack")]
        self.assertIn("if (_serverAuthoritativeAmmo) return true", spend)
        draw = source[source.index("function render()"):
                      source.index("function updateFloatTexts")]
        self.assertNotIn("_sendWorldWeaponFire", draw)
        self.assertNotIn("t:'player_shoot'", source[source.index("if (m.targetKind === 'bank_guard')"):
                                                       source.index("if(['bank_guard'", source.index("if (m.targetKind === 'bank_guard')"))])
        for packet in ("event_shoot", "cop_shoot", "aggro_shoot", "mg_shoot",
                       "player_shoot", "weapon_fire"):
            self.assertIn(packet, source)
        self.assertNotIn("d.get('dmg')", backend[backend.index("elif t == 'weapon_fire'"):
                                                  backend.index("elif t == 'player_shoot'")])
        self.assertIn("claim_player_weapon_fire", backend)
        casino_start = source.index("function _hitCasinoProp")
        casino = source[casino_start:casino_start + 1200]
        self.assertIn("shot_id:shotId", casino)
        empire = backend[backend.index("async def h_npc_empire_assault_hit"):
                         backend.index("async def h_npc_empire_assault_resolve")]
        self.assertIn("claim_player_weapon_fire", empire)
        self.assertIn("path.endswith('/assault/hit')", backend)
        street_start = source.index("if (npcPriority)")
        street_hit = source[street_start:
                            source.index("if (chosenConvoy)", street_start)]
        self.assertIn("if(!hitN.npc?._empireBoss)_sendWorldWeaponFire", street_hit)
        field_hit = source[source.index("function _queueNpcEmpireBossHit"):
                           source.index("function _installNpcEmpireFallbacks")]
        self.assertIn("shot_id:shotId", field_hit)
        self.assertIn("await _apiRequest", field_hit)
        self.assertIn("_reserveAuthoritativeTargetClaim(shotId)", field_hit)
        self.assertIn("empire_field_fallback", field_hit)
        self.assertIn("empire_field_dead',shotId,shotWeapon", field_hit)
        self.assertIn("empire_field_proof_dead',shotId,shotWeapon", field_hit)
        delayed = source[source.index("function _queuePlayerInteriorBallisticHit"):
                         source.index("function _majorInteriorLineClear")]
        self.assertIn("shotId=_authoritativeShotId", delayed)
        self.assertIn("_hitNpcEmpireAssaultNpc(npc, damage, weapon, shotId, claimReserved)", delayed)
        self.assertIn("interior_ballistic_fallback", delayed)
        self.assertIn("'major_guard',", backend)
        self.assertIn("'major_boss',", backend)
        self.assertIn("_sendWorldWeaponFire('rpg_world',shotId,firedWeapon)", source)
        self.assertIn("_spawnRpgExplosion(ir, ic, remote, firedWeapon,shotId)", source)
        self.assertIn("_reserveAuthoritativeTargetClaim", source)
        self.assertIn("firedWeapon = currentWeapon", source)


if __name__ == "__main__":
    unittest.main()
