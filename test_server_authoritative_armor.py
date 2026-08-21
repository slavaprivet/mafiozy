import asyncio
import json
import os
import tempfile
import unittest

os.environ.setdefault("BOT_TOKEN", "0:test")

import aiosqlite

import mafiozi_bot as bot


class ServerAuthoritativeArmorTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        handle, self.path = tempfile.mkstemp(prefix="armor_authority_", suffix=".db")
        os.close(handle)
        self.original_db_path = bot.DB_PATH
        bot.DB_PATH = self.path
        await bot.init_db()
        self._next_uid = 710000

    async def asyncTearDown(self):
        bot.DB_PATH = self.original_db_path
        try:
            os.unlink(self.path)
        except FileNotFoundError:
            pass

    async def add_player(self, *, hp=100, maximum=100, armor=None, armor_hp=None):
        self._next_uid += 1
        uid = self._next_uid
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                """INSERT INTO characters
                     (telegram_id,name,class,hp,max_hp,cash,armor,combat_version)
                     VALUES(?,?,?,?,?,?,?,0)""",
                (uid, f"P{uid}", "killer", hp, maximum, 1000, armor),
            )
            if armor:
                maximum_armor = bot.ARMOR_MAX_HP[armor]
                await db.execute(
                    """INSERT INTO inventory
                         (telegram_id,item_id,quantity,armor_hp,armor_max_hp,
                          armor_version,armor_instance_id)
                         VALUES(?,?,1,?,?,0,?)""",
                    (uid, armor, maximum_armor if armor_hp is None else armor_hp,
                     maximum_armor, f"test:{uid}:{armor}"),
                )
            await db.commit()
        return uid

    async def test_migration_backfills_legacy_armor_to_full(self):
        uid = await self.add_player(armor="kevlar_vest", armor_hp=17)
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                """UPDATE inventory
                      SET armor_hp=NULL,armor_max_hp=NULL,armor_instance_id=NULL
                    WHERE telegram_id=?""",
                (uid,),
            )
            await db.commit()
        await bot.init_db()
        state = await bot.get_authoritative_combat_state(uid)
        self.assertEqual(state["armor"]["current"], 80)
        self.assertEqual(state["armor"]["max"], 80)
        self.assertEqual(state["armor"]["instance_id"], f"legacy:{uid}:kevlar_vest")

    async def test_armor_absorbs_all_damage_before_body(self):
        uid = await self.add_player(armor="kevlar_vest")
        result = await bot.apply_damage_transaction(uid, "bullet-1", "bullet", 30)
        self.assertEqual(result["armor"]["absorbed"], 30)
        self.assertEqual(result["armor"]["current"], 50)
        self.assertEqual(result["body"]["current"], 100)
        self.assertEqual(result["body"]["damage"], 0)

    async def test_no_armor_damage_goes_to_body(self):
        uid = await self.add_player()
        result = await bot.apply_damage_transaction(uid, "bare-1", "bullet", 12)
        self.assertEqual(result["armor"]["absorbed"], 0)
        self.assertEqual(result["body"]["current"], 88)

    async def test_partial_spill_and_exact_break_are_atomic(self):
        uid = await self.add_player(armor="kevlar_vest", armor_hp=11)
        result = await bot.apply_damage_transaction(uid, "blast-1", "explosion", 18)
        self.assertEqual(result["armor"]["absorbed"], 11)
        self.assertTrue(result["armor"]["broken"])
        self.assertEqual(result["body"]["current"], 93)
        async with aiosqlite.connect(self.path) as db:
            async with db.execute(
                "SELECT armor FROM characters WHERE telegram_id=?", (uid,)
            ) as cur:
                self.assertIsNone((await cur.fetchone())[0])
            async with db.execute(
                "SELECT COUNT(*) FROM inventory WHERE telegram_id=? AND item_id='kevlar_vest'",
                (uid,),
            ) as cur:
                self.assertEqual((await cur.fetchone())[0], 0)

    async def test_exact_break_has_no_body_spill(self):
        uid = await self.add_player(armor="kevlar_vest", armor_hp=12)
        result = await bot.apply_damage_transaction(uid, "melee-1", "melee", 12)
        self.assertTrue(result["armor"]["broken"])
        self.assertEqual(result["body"]["current"], 100)

    async def test_retry_replays_without_second_wear(self):
        uid = await self.add_player(armor="kevlar_vest")
        first = await bot.apply_damage_transaction(uid, "retry-1", "bullet", 19)
        second = await bot.apply_damage_transaction(uid, "retry-1", "bullet", 19)
        state = await bot.get_authoritative_combat_state(uid)
        self.assertFalse(first["replayed"])
        self.assertTrue(second["replayed"])
        self.assertEqual(first["combat_version"], second["combat_version"])
        self.assertEqual(state["armor"]["current"], 61)
        self.assertEqual(state["body"]["current"], 100)

    async def test_simultaneous_hits_serialize(self):
        uid = await self.add_player(armor="kevlar_vest", armor_hp=10)
        results = await asyncio.gather(
            bot.apply_damage_transaction(uid, "sim-1", "bullet", 8),
            bot.apply_damage_transaction(uid, "sim-2", "bullet", 8),
        )
        state = await bot.get_authoritative_combat_state(uid)
        self.assertEqual(sum(r["armor"]["absorbed"] for r in results), 10)
        self.assertEqual(sum(r["body"]["damage"] for r in results), 6)
        self.assertEqual(state["body"]["current"], 94)
        self.assertIsNone(state["armor"]["id"])

    async def test_police_modifier_precedes_item_armor(self):
        uid = await self.add_player(armor="kevlar_vest", armor_hp=14)
        result = await bot.apply_damage_transaction(
            uid, "police-skill-1", "bullet", 20, pre_armor_multiplier=0.70
        )
        self.assertEqual(result["effective_damage"], 14)
        self.assertEqual(result["armor"]["absorbed"], 14)
        self.assertEqual(result["body"]["current"], 100)

    async def test_bullet_melee_explosion_and_reconnect(self):
        for kind in ("bullet", "melee", "explosion"):
            uid = await self.add_player(armor="leather_jacket", armor_hp=5)
            await bot.apply_damage_transaction(uid, f"{kind}-event", kind, 9)
            state = await bot.get_authoritative_combat_state(uid)
            self.assertEqual(state["body"]["current"], 96, kind)
            self.assertIsNone(state["armor"]["id"], kind)
            self.assertEqual(state["combat_version"], 1, kind)

    async def test_death_then_respawn_preserves_broken_armor(self):
        uid = await self.add_player(hp=6, armor="leather_jacket", armor_hp=3)
        lethal = await bot.apply_damage_transaction(uid, "lethal-1", "explosion", 20)
        self.assertTrue(lethal["body"]["dead"])
        async with aiosqlite.connect(self.path) as db:
            persisted_respawn = (await (await db.execute(
                "SELECT respawn_at FROM characters WHERE telegram_id=?", (uid,)
            )).fetchone())[0]
            self.assertGreater(persisted_respawn, 0)
            await db.execute(
                "UPDATE characters SET hp=max_hp,respawn_at=0,combat_version=combat_version+1 "
                "WHERE telegram_id=?",
                (uid,),
            )
            await db.commit()
        state = await bot.get_authoritative_combat_state(uid)
        self.assertEqual(state["body"]["current"], 100)
        self.assertIsNone(state["armor"]["id"])

    async def test_receipt_is_durable_json(self):
        uid = await self.add_player(armor="bulletproof")
        expected = await bot.apply_damage_transaction(uid, "receipt-1", "bullet", 7)
        async with aiosqlite.connect(self.path) as db:
            async with db.execute(
                "SELECT result_json FROM damage_events WHERE telegram_id=? AND event_id=?",
                (uid, "receipt-1"),
            ) as cur:
                stored = json.loads((await cur.fetchone())[0])
        self.assertEqual(stored["combat_version"], expected["combat_version"])
        self.assertEqual(stored["armor"]["current"], 58)

    async def test_twenty_concurrent_purchases_charge_once(self):
        uid = await self.add_player()
        results = await asyncio.gather(*(
            bot.purchase_armor_transaction(uid, "bulletproof")
            for _ in range(20)
        ))
        self.assertEqual(sum(bool(r.get("ok")) for r in results), 1)
        async with aiosqlite.connect(self.path) as db:
            cash = (await (await db.execute(
                "SELECT cash FROM characters WHERE telegram_id=?", (uid,)
            )).fetchone())[0]
            rows = (await (await db.execute(
                "SELECT COUNT(*) FROM inventory WHERE telegram_id=? AND item_id='bulletproof'",
                (uid,),
            )).fetchone())[0]
        self.assertEqual(cash, 800)
        self.assertEqual(rows, 1)

    async def test_purchase_rolls_back_charge_when_inventory_insert_fails(self):
        uid = await self.add_player()
        async with aiosqlite.connect(self.path) as db:
            await db.execute("""
                CREATE TRIGGER fail_armor_insert BEFORE INSERT ON inventory
                WHEN NEW.telegram_id=%d AND NEW.item_id='bulletproof'
                BEGIN SELECT RAISE(ABORT, 'forced rollback'); END
            """ % uid)
            await db.commit()
        with self.assertRaises(aiosqlite.IntegrityError):
            await bot.purchase_armor_transaction(uid, "bulletproof")
        async with aiosqlite.connect(self.path) as db:
            cash = (await (await db.execute(
                "SELECT cash FROM characters WHERE telegram_id=?", (uid,)
            )).fetchone())[0]
        self.assertEqual(cash, 1000)

    async def test_insufficient_funds_does_not_create_or_equip(self):
        uid = await self.add_player()
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                "UPDATE characters SET cash=0 WHERE telegram_id=?", (uid,))
            await db.commit()
        result = await bot.purchase_armor_transaction(uid, "bulletproof")
        self.assertEqual(result["error"], "no cash")
        state = await bot.get_authoritative_combat_state(uid)
        self.assertIsNone(state["armor"]["id"])

    async def test_body_respawn_transaction_preserves_unbroken_armor(self):
        uid = await self.add_player(hp=0, armor="kevlar_vest", armor_hp=11)
        state = await bot.set_authoritative_body_state(uid, 100)
        self.assertEqual(state["body"]["current"], 100)
        self.assertEqual(state["armor"]["current"], 11)
        self.assertEqual(state["armor"]["instance_id"], f"test:{uid}:kevlar_vest")

    async def test_equip_and_hit_serialize_without_dangling_or_body_damage(self):
        uid = await self.add_player(armor="kevlar_vest", armor_hp=10)
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                """INSERT INTO inventory
                   (telegram_id,item_id,quantity,armor_hp,armor_max_hp,
                    armor_version,armor_instance_id)
                   VALUES(?,?,1,?,?,1,?)""",
                (uid, "bulletproof", 65, 65, f"new:{uid}:bulletproof"))
            await db.commit()
        equip, hit = await asyncio.gather(
            bot.equip_item_transaction(uid, "bulletproof", "armor"),
            bot.apply_damage_transaction(uid, "equip-race", "bullet", 8),
        )
        self.assertTrue(equip["ok"])
        state = await bot.get_authoritative_combat_state(uid)
        self.assertEqual(state["body"]["current"], 100)
        self.assertEqual(state["armor"]["id"], "bulletproof")
        self.assertIn(state["armor"]["current"], (57, 65))
        self.assertEqual(hit["body"]["damage"], 0)

    async def test_profile_owner_mapping_isolated_from_foreign_actor(self):
        uid = await self.add_player()
        async with aiosqlite.connect(self.path) as db:
            await db.execute(
                """INSERT INTO account_characters
                   (account_id,character_id,slot,created_at) VALUES(?,?,1,0)""",
                (42, uid))
            await db.commit()
        self.assertTrue(await bot.actor_owns_character(42, uid))
        self.assertFalse(await bot.actor_owns_character(43, uid))

    async def test_old_event_replay_cannot_touch_repurchase_generation(self):
        uid = await self.add_player(armor="bulletproof", armor_hp=3)
        first = await bot.apply_damage_transaction(uid, "old-generation", "bullet", 3)
        self.assertTrue(first["armor"]["broken"])
        bought = await bot.purchase_armor_transaction(uid, "bulletproof")
        self.assertTrue(bought["ok"])
        replay = await bot.apply_damage_transaction(uid, "old-generation", "bullet", 3)
        state = await bot.get_authoritative_combat_state(uid)
        self.assertTrue(replay["replayed"])
        self.assertEqual(state["armor"]["instance_id"], bought["instance_id"])
        self.assertEqual(state["armor"]["current"], 65)

    async def test_runtime_armor_grant_creates_full_unique_generation(self):
        uid = await self.add_player()
        granted = await bot.add_item(uid, "bulletproof")
        self.assertTrue(granted["ok"])
        self.assertEqual(granted["current"], bot.ARMOR_MAX_HP["bulletproof"])
        self.assertTrue(granted["instance_id"])

        duplicate = await bot.add_item(uid, "bulletproof")
        self.assertFalse(duplicate["ok"])
        self.assertTrue(duplicate["duplicate"])
        async with aiosqlite.connect(self.path) as db:
            row = await (await db.execute(
                """SELECT quantity,armor_hp,armor_max_hp,armor_instance_id
                     FROM inventory WHERE telegram_id=? AND item_id=?""",
                (uid, "bulletproof"),
            )).fetchone()
        self.assertEqual(row[0], 1)
        self.assertEqual(row[1], bot.ARMOR_MAX_HP["bulletproof"])
        self.assertEqual(row[2], bot.ARMOR_MAX_HP["bulletproof"])
        self.assertEqual(row[3], granted["instance_id"])



if __name__ == "__main__":
    unittest.main()
