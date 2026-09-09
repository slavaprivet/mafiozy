import asyncio
import ast
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

import aiosqlite
from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

from weapon_transfers import WeaponTransfers, ensure_schema, live_exterior_actor


async def bump(db, uid):
    await db.execute('INSERT INTO weapon_ammo_versions VALUES(?,1) ON CONFLICT(telegram_id) DO UPDATE SET version=version+1', (uid,))
    return (await (await db.execute('SELECT version FROM weapon_ammo_versions WHERE telegram_id=?', (uid,))).fetchone())[0]


async def snapshot(db, uid):
    rows = await (await db.execute('SELECT * FROM weapon_ammo WHERE telegram_id=?', (uid,))).fetchall()
    reserve = await (await db.execute('SELECT * FROM ammo_reserve WHERE telegram_id=?', (uid,))).fetchall()
    version = await (await db.execute('SELECT version FROM weapon_ammo_versions WHERE telegram_id=?', (uid,))).fetchone()
    return {'mags': {r['weapon_key']: r['magazine'] for r in rows},
            'reserve': {r['ammo_type']: r['rounds'] for r in reserve},
            'reloads': {r['weapon_key']: {'id':r['reload_id'],'ready_at':r['reload_ready_at']} for r in rows if r['reload_id']},
            'ammo_version': version[0] if version else 0}


class Transfers(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        handle, self.path = tempfile.mkstemp(prefix='weapon_transfers_',suffix='.db')
        os.close(handle)
        self.now=1000.0
        self.actors={uid:{'ok':True,'r':8.,'c':9.,'elevation':0.,'space':'world','layer':'ground'} for uid in [1,2,3]}
        self.service=WeaponTransfers(db_path=self.path,
            items={k:{'type':'weapon'} for k in ['ak74','m16','uzi','tt']},
            item_classes={'ak74':'rifle','m16':'rifle','uzi':'smg','tt':'pistol'},
            mag_sizes={'rifle':30,'smg':30,'pistol':12},ammo_types={'rifle':'rifle','smg':'9mm','pistol':'9mm'},
            ammo_limits={'rifle':180,'9mm':240},ammo_snapshot=snapshot,bump_ammo_version=bump,
            actor_provider=lambda uid,now:self.actors.get(uid),clock=lambda:self.now)
        async with aiosqlite.connect(self.path) as db:
            await db.executescript('''CREATE TABLE characters(telegram_id INTEGER PRIMARY KEY,hp INTEGER,weapon TEXT,jail_until REAL DEFAULT 0,combat_version INTEGER DEFAULT 0);
              CREATE TABLE inventory(id INTEGER PRIMARY KEY,telegram_id INTEGER,item_id TEXT,quantity INTEGER,UNIQUE(telegram_id,item_id));
              CREATE TABLE weapon_ammo(telegram_id INTEGER,weapon_key TEXT,magazine INTEGER DEFAULT 0,next_fire_at REAL DEFAULT 0,reload_id TEXT DEFAULT '',reload_ready_at REAL DEFAULT 0,version INTEGER DEFAULT 0,PRIMARY KEY(telegram_id,weapon_key));
              CREATE TABLE ammo_reserve(telegram_id INTEGER,ammo_type TEXT,rounds INTEGER,version INTEGER DEFAULT 0,PRIMARY KEY(telegram_id,ammo_type));
              CREATE TABLE weapon_ammo_versions(telegram_id INTEGER PRIMARY KEY,version INTEGER DEFAULT 0);''')
            await ensure_schema(db)
            for uid in [1,2,3]:
                await db.execute('INSERT INTO characters(telegram_id,hp,weapon) VALUES(?,100,?)',(uid,'ak74' if uid==1 else 'tt'))
            await db.execute("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(1,'ak74',1),(2,'tt',1),(3,'tt',1)")
            await db.execute("INSERT INTO weapon_ammo(telegram_id,weapon_key,magazine,next_fire_at) VALUES(1,'rifle',17,1001),(2,'pistol',4,0)")
            await db.execute("INSERT INTO ammo_reserve(telegram_id,ammo_type,rounds) VALUES(1,'rifle',55),(2,'rifle',8)")
            await db.commit()

    async def asyncTearDown(self):
        os.unlink(self.path)

    async def sql(self, sql, args=()):
        async with aiosqlite.connect(self.path) as db:
            rows=await (await db.execute(sql,args)).fetchall()
            await db.commit()
            return rows

    async def test_drop_pickup_never_equips_and_preserves_total_ammo(self):
        drop=await self.service.drop(1,'drop-1','ak74')
        self.assertTrue(drop['ok'])
        self.assertEqual(drop['drop']['expires_at'],1300)
        self.assertEqual(drop['drop']['magazine'],17)
        self.assertEqual(drop['ammo_state']['mags']['rifle'],0)
        self.assertEqual(drop['ammo_state']['reserve']['rifle'],55)
        self.assertIsNone(drop['equipped_weapon'])
        pickup=await self.service.pickup(2,'pickup-1',drop['drop']['drop_id'])
        self.assertEqual(pickup['equipped_weapon'],'tt')
        self.assertEqual(pickup['ammo_state']['mags'],{'rifle':17,'pistol':4})
        self.assertEqual(pickup['ammo_state']['reserve']['rifle'],8)
        self.assertEqual(await self.sql('SELECT next_fire_at FROM weapon_ammo WHERE telegram_id=2 AND weapon_key=\'rifle\''),[(1001.,)])
        self.assertEqual((await self.service.ground(2))['drops'],[])

    async def test_race_and_receipts_exactly_once_and_current_state_on_replay(self):
        outcomes=await asyncio.gather(*(self.service.drop(1,'duplicate','ak74') for _ in range(12)))
        self.assertTrue(all(x['ok'] for x in outcomes))
        self.assertEqual(sum(not x.get('replayed') for x in outcomes),1)
        drop_id=outcomes[0]['drop']['drop_id']
        a,b=await asyncio.gather(self.service.pickup(2,'race-2',drop_id),self.service.pickup(3,'race-3',drop_id))
        self.assertEqual(sum(x['ok'] for x in [a,b]),1)
        winner=2 if a['ok'] else 3
        await self.sql('UPDATE characters SET weapon=NULL WHERE telegram_id=?',(winner,))
        replay=await self.service.pickup(winner,f'race-{winner}',drop_id)
        self.assertTrue(replay['replayed'])
        self.assertIsNone(replay['equipped_weapon'])
        conflict=await self.service.drop(1,'duplicate','m16')
        self.assertEqual(conflict['error'],'request_conflict')

    async def test_expiry_reset_and_reconnect(self):
        first=await self.service.drop(1,'first')
        self.now=1299
        picked=await self.service.pickup(1,'pick',first['drop']['drop_id'])
        self.assertTrue(picked['ok'])
        await self.sql("UPDATE characters SET weapon='ak74' WHERE telegram_id=1")
        second=await self.service.drop(1,'second')
        self.assertEqual(second['drop']['expires_at'],1599)
        self.now=1301
        self.assertEqual(len((await self.service.ground(1))['drops']),1)
        self.now=1599
        self.assertEqual((await self.service.ground(1))['drops'],[])
        self.assertEqual((await self.service.pickup(2,'late',second['drop']['drop_id']))['error'],'drop_unavailable')
        replay=await self.service.drop(1,'second')
        self.assertTrue(replay['replayed'])
        self.assertEqual((await self.service.ground(1))['drops'],[])

    async def test_duplicate_family_never_duplicates_shared_magazine(self):
        await self.sql("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(1,'m16',1)")
        first=await self.service.drop(1,'first')
        self.assertEqual(first['drop']['magazine'],0)
        self.assertEqual(first['ammo_state']['mags']['rifle'],17)
        await self.sql("UPDATE characters SET weapon='m16' WHERE telegram_id=1")
        second=await self.service.drop(1,'second')
        self.assertEqual(second['drop']['magazine'],17)
        self.assertEqual(second['ammo_state']['mags']['rifle'],0)

    async def test_pickup_same_family_keeps_held_mag_reload_and_reserve_conservation(self):
        await self.sql("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(2,'m16',1)")
        await self.sql("INSERT INTO weapon_ammo(telegram_id,weapon_key,magazine,reload_id,reload_ready_at) VALUES(2,'rifle',3,'busy',1010)")
        await self.sql("UPDATE characters SET weapon='m16' WHERE telegram_id=2")
        drop=await self.service.drop(1,'drop')
        pick=await self.service.pickup(2,'pick',drop['drop']['drop_id'])
        self.assertEqual(pick['equipped_weapon'],'m16')
        self.assertEqual(pick['ammo_state']['mags']['rifle'],3)
        self.assertEqual(pick['ammo_state']['reserve']['rifle'],25)
        self.assertEqual(pick['ammo_state']['reloads']['rifle']['id'],'busy')

    async def test_range_surface_death_and_reserve_full_fail_without_mutation(self):
        drop=await self.service.drop(1,'drop')
        drop_id=drop['drop']['drop_id']
        self.actors[2]['c']=9.6  # 2.46 metres; world cells are not metres.
        self.assertEqual((await self.service.pickup(2,'far',drop_id))['error'],'out_of_reach')
        self.actors[2]['c']=9.
        self.actors[2]['layer']='floor:2'
        self.assertEqual((await self.service.pickup(2,'floor',drop_id))['error'],'different_surface')
        self.actors[2]['layer']='ground'
        await self.sql('UPDATE characters SET hp=0 WHERE telegram_id=2')
        self.assertEqual((await self.service.pickup(2,'dead',drop_id))['error'],'dead_or_jailed')
        await self.sql('UPDATE characters SET hp=100 WHERE telegram_id=2')
        await self.sql("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(2,'m16',1)")
        await self.sql("UPDATE ammo_reserve SET rounds=180 WHERE telegram_id=2 AND ammo_type='rifle'")
        self.assertEqual((await self.service.pickup(2,'full',drop_id))['error'],'ammo_full')
        self.assertEqual(len((await self.service.ground(1))['drops']),1)
        self.assertEqual(await self.sql("SELECT quantity FROM inventory WHERE telegram_id=2 AND item_id='ak74'"),[])

    async def test_storage_failure_rolls_back_all_mutations(self):
        await self.sql("CREATE TRIGGER fail_receipt BEFORE INSERT ON weapon_transfer_receipts BEGIN SELECT RAISE(ABORT,'forced failure'); END")
        with self.assertRaises(aiosqlite.IntegrityError):
            await self.service.drop(1,'failure')
        self.assertEqual(await self.sql("SELECT weapon FROM characters WHERE telegram_id=1"),[('ak74',)])
        self.assertEqual(await self.sql("SELECT magazine FROM weapon_ammo WHERE telegram_id=1"),[(17,)])
        self.assertEqual(await self.sql('SELECT * FROM weapon_ground_drops'),[])

    async def test_actual_owner_loadout_does_not_mint_intentionally_dropped_weapon(self):
        source=ast.parse(Path(__file__).with_name('mafiozi_bot.py').read_text(encoding='utf-8-sig'))
        node=next(n for n in source.body if isinstance(n,ast.AsyncFunctionDef) and n.name=='ensure_owner_entry_loadout')
        env={'aiosqlite':aiosqlite,'DB_PATH':self.path,'OWNER_LOADOUT_UID':1,
             'OWNER_LOADOUT_CASH':1000,'OWNER_LOADOUT_ITEMS':{'ak74':1,'m16':1}}
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<actual-owner-loadout>','exec'),env)
        await self.sql('ALTER TABLE characters ADD COLUMN cash INTEGER DEFAULT 0')
        drop=await self.service.drop(1,'owner-drop')
        self.assertTrue(drop['ok'])
        await env['ensure_owner_entry_loadout'](1)
        self.assertEqual(await self.sql("SELECT quantity FROM inventory WHERE telegram_id=1 AND item_id='ak74'"),[(0,)])
        self.assertEqual(await self.sql("SELECT quantity FROM inventory WHERE telegram_id=1 AND item_id='m16'"),[(1,)])
        self.assertEqual(len((await self.service.ground(1))['drops']),1)

    async def test_actual_http_handler_auth_binding_and_untrusted_coordinates(self):
        # Compile actual production closures, never import bot credentials/server.
        source=ast.parse(Path(__file__).with_name('mafiozi_bot.py').read_text(encoding='utf-8-sig'))
        app_func=next(n for n in source.body if isinstance(n,ast.AsyncFunctionDef) and n.name=='_coop_http_app')
        names={'_cors','_actor_binding','h_inv_weapon_ground','_h_inv_weapon_transfer','h_inv_weapon_drop','h_inv_weapon_pickup'}
        nodes=[n for n in app_func.body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name in names]
        nodes.insert(0,next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='_requires_actor_binding'))
        async def resolve(headers,expected_character='',**kwargs):
            if headers.get('Authorization') != f'Bearer test-{expected_character}':
                raise ValueError('actor mismatch')
            return {'character_uid':expected_character}
        env={'web':web,'resolve_request_identity':resolve,'weapon_transfer_service':lambda:self.service,
             'mirror_weapon_transfer':lambda *args:None,'_WORLD':None}
        exec(compile(ast.Module(body=nodes,type_ignores=[]),'<actual-transfer-handlers>','exec'),env)
        app=web.Application(middlewares=[env['_actor_binding']])
        app.router.add_post('/inv/{uid}/weapon-drop',env['h_inv_weapon_drop'])
        app.router.add_post('/inv/{uid}/weapon-pickup',env['h_inv_weapon_pickup'])
        app.router.add_get('/inv/{uid}/weapon-ground',env['h_inv_weapon_ground'])
        async with TestClient(TestServer(app)) as client:
            denied=await client.post('/inv/1/weapon-drop',json={'request_id':'http'})
            self.assertEqual(denied.status,401)
            mismatch=await client.post('/inv/1/weapon-drop',headers={'Authorization':'Bearer test-2'},json={'request_id':'http'})
            self.assertEqual(mismatch.status,401)
            good=await client.post('/inv/1/weapon-drop',headers={'Authorization':'Bearer test-1'},json={'request_id':'http','r':1000,'c':1000,'elevation':800,'uid':2})
            data=await good.json()
            self.assertEqual(good.status,200)
            self.assertEqual((data['drop']['r'],data['drop']['c'],data['drop']['elevation']),(8.,9.,0.))


class ServerActor(unittest.TestCase):
    def test_runtime_geometry_transport_and_lock_guards(self):
        p={'x':3,'y':4,'hp':100,'last_seen':1000}
        world=SimpleNamespace(players={'1':p},quest_cars={})
        self.assertEqual(live_exterior_actor(world,1,1000)['r'],4)
        for key,value in [('dead',True),('_in_interior',True),('_police_cuffed_by','2'),('_walk_elevation',4),('_swimming',True)]:
            p[key]=value
            self.assertFalse(live_exterior_actor(world,1,1000)['ok'],key)
            p.pop(key)
        world.quest_cars={'x':{'passenger_uids':['1']}}
        self.assertEqual(live_exterior_actor(world,1,1000)['error'],'transport')
        world.quest_cars={}
        self.assertEqual(live_exterior_actor(world,1,1011)['error'],'player_position_stale')


if __name__=='__main__':
    unittest.main()
