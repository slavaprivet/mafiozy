"""Real temporary-DB checks for server-owned NPC RPG arrival damage."""
import os
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault('BOT_TOKEN', '0:test-explosion')
import aiosqlite
import mafiozi_bot as bot


class WorldExplosionDamageTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        handle, self.path = tempfile.mkstemp(prefix='world_explosion_', suffix='.db')
        os.close(handle)
        self.old_path = bot.DB_PATH
        bot.DB_PATH = self.path
        await bot.init_db()
        self.world = bot.WorldSim()
        self.uid = '8082991'
        await self.add_player(self.uid, 40, 40, armor=10)

    async def asyncTearDown(self):
        bot.DB_PATH = self.old_path
        os.unlink(self.path)

    async def add_player(self, uid, x, y, *, armor=0, hp=100, **flags):
        async with aiosqlite.connect(self.path) as db:
            await db.execute('INSERT INTO characters '
                '(telegram_id,name,class,hp,max_hp,cash,armor,combat_version) '
                'VALUES(?,?,?,?,100,0,?,0)',
                (int(uid), 'BlastTarget', 'killer', hp, 'bulletproof' if armor else None))
            if armor:
                await db.execute('INSERT INTO inventory '
                    '(telegram_id,item_id,quantity,armor_hp,armor_max_hp,armor_version,armor_instance_id) '
                    'VALUES(?,?,1,?,?,1,?)', (int(uid), 'bulletproof', armor,
                    bot.ARMOR_MAX_HP['bulletproof'], 'blast-test-'+uid))
            await db.commit()
        self.world.add_or_update(uid, 'BlastTarget', {}, mode='pvp')
        target = self.world.players[uid]
        target.update(x=x, y=y, **flags)
        self.world._mirror_combat_state(target, await bot.get_authoritative_combat_state(int(uid)))
        return target

    def launch(self):
        self.world._enqueue_bot_shot(target=self.world.players[self.uid],
            sx=36, sy=40, tx=40, ty=40, weapon='rpg', bot_id='rocket-bot', tid='street')
        return self.world._pending_bot_shots[-1]

    async def state(self, uid=None):
        return await bot.get_authoritative_combat_state(int(uid or self.uid))

    async def test_arrival_armor_falloff_and_replay(self):
        await self.add_player('8082992', 41.35, 40)
        shot = self.launch()
        shot['apply_at'] = 10**12
        self.assertEqual(await self.world._tick_pending_bot_shots_async(), [])
        self.assertEqual((await self.state())['combat_version'], 0)
        shot['apply_at'] = 0
        with patch.object(bot, '_world_los', return_value=True):
            packets = await self.world._tick_pending_bot_shots_async()
            before = await self.state()
            self.world._pending_bot_shots.append(dict(shot))
            self.assertEqual(await self.world._tick_pending_bot_shots_async(), [])
        self.assertEqual(len(packets), 2)
        self.assertTrue(all(p['damage_kind'] == 'explosion' for p in packets))
        self.assertEqual(before['armor']['current'], 0)
        self.assertEqual(before['body']['current'], 100-(shot['dmg']-10))
        self.assertEqual((await self.state('8082992'))['body']['current'], 100-round(shot['dmg']/2))
        self.assertEqual(await self.state(), before)
        self.assertEqual(before['combat_version'], 1)  # No extra direct bullet hit.

    async def test_escape_and_protected_players(self):
        await self.add_player('8082992', 40, 40, _mode='pve')
        await self.add_player('8082993', 40, 40, _in_interior=True)
        await self.add_player('8082994', 40, 40, _police_cuffed_by='cop')
        shot = self.launch()
        shot['apply_at'] = 0
        self.world.players[self.uid]['x'] = 42.71
        with patch.object(bot, '_world_los', return_value=True):
            self.assertEqual(await self.world._tick_pending_bot_shots_async(), [])
        for uid in self.world.players:
            self.assertEqual((await self.state(uid))['combat_version'], 0)

    async def test_los_and_invalid_geometry_reject_before_damage(self):
        shot = self.launch()
        with patch.object(bot, '_world_los', return_value=False):
            self.assertEqual(await self.world._apply_server_npc_rpg_arrival(shot), [])
        for invalid in ({'tx': float('nan')}, {'tx': 70}, {'sx': float('inf')}):
            with patch.object(bot, '_world_los', return_value=True):
                self.assertEqual(await self.world._apply_server_npc_rpg_arrival({**shot, **invalid}), [])
        # Clear launch segment, but a wall between impact and victim blocks splash.
        self.world.players[self.uid]['x'] = 41
        with patch.object(bot, '_world_los', side_effect=lambda x,y,tx,ty: x == 36):
            self.assertEqual(await self.world._apply_server_npc_rpg_arrival(shot), [])
        self.assertEqual((await self.state())['combat_version'], 0)

    async def test_dead_original_target_does_not_cancel_nearby_blast(self):
        await self.add_player('8082992', 40, 40, hp=5)
        shot = self.launch()
        self.world.players[self.uid]['dead'] = True
        shot['apply_at'] = 0
        with patch.object(bot, '_world_los', return_value=True):
            packets = await self.world._tick_pending_bot_shots_async()
        self.assertEqual(len(packets), 1)
        self.assertTrue(packets[0]['killed'])
        victim = self.world.players['8082992']
        self.assertTrue(victim['dead'])
        self.assertGreater(victim['_respawn_at'], 0)
        self.assertEqual(victim['deaths'], 1)

    async def test_bound_target_disconnect_still_damages_once(self):
        shot = self.launch()
        self.world.remove(self.uid)
        with patch.object(bot, '_world_los', return_value=True):
            self.assertEqual(len(await self.world._apply_server_npc_rpg_arrival(shot)), 1)
            before = await self.state()
            self.assertEqual(await self.world._apply_server_npc_rpg_arrival(shot), [])
        self.assertEqual(await self.state(), before)
        self.assertEqual(before['combat_version'], 1)

    async def test_existing_c4_stays_lethal_and_skips_pve(self):
        await self.add_player('8082992', 40, 40, _mode='pve')
        self.world.world_c4['audit-charge'] = {'x': 40, 'y': 40, 'explode_at': 1,
            'owner_uid': self.uid, 'owner_name': 'Test'}
        packets = await self.world._tick_world_c4_async()
        self.assertEqual(packets[0]['kind'], 'world_c4_exploded')
        self.assertTrue((await self.state())['body']['dead'])
        self.assertEqual((await self.state('8082992'))['combat_version'], 0)
        self.assertEqual(await self.world._tick_world_c4_async(), [])


if __name__ == '__main__':
    unittest.main()
