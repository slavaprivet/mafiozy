"""Actual source functions, isolated AST and temporary DB; never import/start bot."""
import ast
import asyncio
import json
from pathlib import Path
import tempfile
import time
from types import SimpleNamespace
import unittest

import aiosqlite
from aiohttp import web

TREE = ast.parse(Path(__file__).with_name('mafiozi_bot.py').read_text(encoding='utf-8-sig'))


def functions(*names):
    nodes = [next(node for node in ast.walk(TREE) if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name) for name in names]
    return compile(ast.Module(body=nodes, type_ignores=[]), '<actual-gang-source>', 'exec')


class GangPermissions(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='gang_permission_test_')
        self.path = str(Path(self.temp.name) / 'isolated.db')
        self.env = dict(aiosqlite=aiosqlite, DB_PATH=self.path, time=time, json=json, CUSTOM_GANG_MAX_MEMBERS=12, web=web)
        exec(functions('_custom_gang_audit', 'kick_custom_gang_member_db', 'apply_custom_gang_to_player', 'custom_gang_player_payload', 'h_custom_gang_kick', '_requires_actor_binding'), self.env)
        async with aiosqlite.connect(self.path) as db:
            await db.executescript('''CREATE TABLE custom_gangs(id INTEGER PRIMARY KEY,leader_uid INTEGER);
              CREATE TABLE custom_gang_members(gang_id INTEGER,telegram_id INTEGER,role TEXT);
              CREATE TABLE custom_gang_npcs(gang_id INTEGER,owner_uid INTEGER);
              CREATE TABLE custom_gang_audit(gang_id INTEGER,actor_uid INTEGER,action TEXT,details_json TEXT,created_at INTEGER);
              INSERT INTO custom_gangs VALUES(7,1),(8,4);
              INSERT INTO custom_gang_members VALUES(7,1,'leader'),(7,2,'member'),(7,3,'member'),(8,4,'leader');
              INSERT INTO custom_gang_npcs VALUES(7,1),(7,2),(7,3);''')
            await db.commit()

    async def asyncTearDown(self):
        self.temp.cleanup()

    async def rows(self, query):
        async with aiosqlite.connect(self.path) as db:
            return await (await db.execute(query)).fetchall()

    async def test_kick_permissions_and_full_notification_targets(self):
        kick = self.env['kick_custom_gang_member_db']
        for actor, target in [(2, 3), (2, 1), (1, 1), (1, 4), (4, 2)]:
            self.assertFalse((await kick(actor, target))['ok'])
        self.assertEqual(len(await self.rows('SELECT * FROM custom_gang_members')), 4)
        result = await kick(1, 2)
        self.assertTrue(result['ok'])
        self.assertEqual(set(result['member_uids']), {'1', '2', '3'})
        self.assertEqual(await self.rows('SELECT owner_uid FROM custom_gang_npcs WHERE gang_id=7 ORDER BY owner_uid'), [(1,), (3,)])
        self.assertEqual(len(await self.rows('SELECT * FROM custom_gang_audit')), 1)
        self.assertFalse((await kick(1, 2))['ok'])

    def test_invitation_shared_roster_keeps_each_recipients_role(self):
        gang = dict(id=7, name='Волки', role='member', flag={}, hq_apt_key='hq', members=[{'telegram_id':'1','role':'leader'}, {'telegram_id':'2','role':'member'}, {'telegram_id':'3','role':'member'}])
        apply = self.env['apply_custom_gang_to_player']
        for uid, expected in [('1', 'leader'), ('2', 'member'), ('3', 'member')]:
            player = {'uid': uid}
            apply(player, gang)
            self.assertEqual(player['_custom_gang_role'], expected)
            self.assertEqual(self.env['custom_gang_player_payload'](player)['role'], expected)
        # Leadership transfer must use the current roster, not original creator.
        gang['members'][0]['role'] = 'member'; gang['members'][1]['role'] = 'leader'
        player = {'uid':'2'}; apply(player, gang)
        self.assertEqual(player['_custom_gang_role'], 'leader')

    async def test_http_kick_refreshes_every_remaining_online_member(self):
        players = {str(uid): {'uid': str(uid)} for uid in [1,2,3]}
        notified = []
        async def get_gang(uid):
            rows = await self.rows('SELECT telegram_id,role FROM custom_gang_members WHERE gang_id=7')
            role = next((role for member,role in rows if member == uid), None)
            return None if role is None else dict(id=7,name='Волки',role=role,flag={},hq_apt_key='hq',members=[dict(telegram_id=str(member),role=role) for member,role in rows])
        async def cors(response): return response
        async def headquarters(): return []
        async def notify(uids): notified.extend(uids)
        async def body(): return {'target_uid':2}
        self.env.update(_WORLD=SimpleNamespace(players=players),get_custom_gang_for_user=get_gang,_cors=cors,get_custom_gang_headquarters=headquarters,notify_custom_gang_state=notify)
        response = await self.env['h_custom_gang_kick'](SimpleNamespace(match_info={'uid':'1'},json=body))
        self.assertEqual(response.status, 200)
        self.assertEqual(set(notified), {'1','2','3'})
        self.assertNotIn('_custom_gang_id', players['2'])
        for uid in ['1','3']:
            self.assertEqual([m['telegram_id'] for m in players[uid]['_custom_gang_members']], ['1','3'])
        self.assertTrue(self.env['_requires_actor_binding']('/custom-gang/1/kick'))

    def test_actual_ws_party_branch_creator_only_and_self_leave(self):
        branch = next(node for node in ast.walk(TREE) if isinstance(node, ast.If) and ast.unparse(node.test) == "t in ('gang_player_leave', 'gang_player_kick')")
        code = compile(ast.Module(body=branch.body, type_ignores=[]), '<actual-party-branch>', 'exec')
        def act(actor, target, action='gang_player_kick', crew='1'):
            players = {str(uid): {'uid':str(uid),'_crew_id':crew} for uid in [1,2,3,4]}
            env = dict(world=SimpleNamespace(players=players), uid=str(actor), t=action, d={'target_uid':str(target)})
            exec(code, env)
            return players
        self.assertIn('_crew_id', act(2,3)['3'])
        self.assertIn('_crew_id', act(2,1)['1'])
        self.assertIn('_crew_id', act(1,1)['1'])
        self.assertNotIn('_crew_id', act(1,3)['3'])
        self.assertNotIn('_crew_id', act(2,2,'gang_player_leave')['2'])
        self.assertIn('_crew_id', act(1,3,crew='cg:7')['3'])
        # Existing policy: leaving creator does not silently confer leadership.
        self.assertEqual(act(1,1,'gang_player_leave')['2']['_crew_id'], '1')


if __name__ == '__main__':
    unittest.main()
