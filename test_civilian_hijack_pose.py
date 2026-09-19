"""CPU contract tests using actual production method and WS branch AST bodies.

Does not import/start the Telegram bot, restart a service, or render a scene.
"""
import ast
import asyncio
import copy
import json
import math
from pathlib import Path
import random
import re
import time
import types
import unittest

from civilian_hijack_pose import validate_civilian_hijack_pose

ROOT = Path(__file__).resolve().parent


def load_contract():
    tree = ast.parse((ROOT / 'mafiozi_bot.py').read_text(encoding='utf-8-sig'))
    nodes = list(ast.walk(tree))
    method = next(n for n in nodes if isinstance(n, ast.FunctionDef)
                  and n.name == 'civilian_hijack_start')
    normalizer = next(n for n in nodes if isinstance(n, ast.FunctionDef)
                      and n.name == '_normalize_vehicle_paint')
    models = next(n.value for n in nodes if isinstance(n, ast.Assign)
                  and any(isinstance(t, ast.Name) and t.id == 'CIVILIAN_HIJACK_MODELS'
                          for t in n.targets))
    branch = next(n for n in nodes if isinstance(n, ast.If)
                  and isinstance(n.test, ast.Compare)
                  and isinstance(n.test.left, ast.Name) and n.test.left.id == 't'
                  and any(isinstance(c, ast.Constant) and c.value == 'civilian_carjack'
                          for c in n.test.comparators))
    wrapper = ast.parse('async def dispatch(world, uid, d, ws):\n    pass').body[0]
    wrapper.body = branch.body
    ns = {'random': random, 'time': time, 're': re, 'json': json,
          'WORLD_MAP_COLS': 180, 'WORLD_MAP_ROWS': 200,
          'validate_civilian_hijack_pose': validate_civilian_hijack_pose}
    exec(compile(ast.fix_missing_locations(ast.Module(
        body=[normalizer, method, wrapper], type_ignores=[])),
        'actual_mafiozi_hijack_contract', 'exec'), ns)
    preview_tree = ast.parse((ROOT / '_preview_ws_server.py').read_text(encoding='utf-8-sig'))
    preview = next(n for n in preview_tree.body if isinstance(n, ast.FunctionDef)
                   and n.name == 'preview_civilian_carjack')
    exec(compile(ast.Module(body=[preview], type_ignores=[]), 'actual_preview_hijack', 'exec'), ns)
    return ns, ast.literal_eval(models)


class HijackPoseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ns, cls.models = load_contract()

    def world(self):
        world = types.SimpleNamespace(
            players={'u': {'x': 50., 'y': 60., 'ang': -.3}}, quest_cars={},
            _quest_car_next_id=10, CIVILIAN_HIJACK_MODELS=self.models,
            QUEST_CAR_MODELS={}, QUEST_CAR_HP=220, WANTED_PER_HIT=1.5,
            connections={}, cops=[], wanted=[])
        world._bump_wanted = lambda p, value: world.wanted.append(value)
        world.civilian_hijack_start = types.MethodType(self.ns['civilian_hijack_start'], world)
        return world

    def test_valid_pose_preserves_car_not_door_and_policy(self):
        w = self.world()
        player = copy.deepcopy(w.players['u'])
        reply = w.civilian_hijack_start('u', 'taxi',
            {'primary': '#ABCDEF', 'roof': 'invalid'}, {'x': 51.2, 'y': 60.4, 'ang': 1.2})
        self.assertTrue(reply['ok'])
        car = w.quest_cars[reply['car_id']]
        self.assertEqual((car['x'], car['y'], car['ang']), (51.2, 60.4, 1.2))
        self.assertEqual((reply['x'], reply['y'], reply['ang']), (51.2, 60.4, 1.2))
        self.assertEqual(w.players['u'], player)
        self.assertEqual((car['owner_uid'], car['driver_uid'], car['passenger_uids']), ('u', 'u', []))
        self.assertEqual((car['reward'], car['lock_lvl'], car['hp'], car['civilian']), (0, 0, 220, True))
        self.assertEqual(car['paint'], {'primary': '#abcdef'})
        self.assertNotIn('_gta_active_car_id', w.players['u'])

    def test_legacy_absent_pose_keeps_server_player_fallback(self):
        w = self.world()
        reply = w.civilian_hijack_start('u', 'untrusted_model')
        self.assertTrue(reply['ok'])
        self.assertIn(reply['model'], self.models)
        self.assertEqual((reply['x'], reply['y'], reply['ang']), (50., 60., -.3))

    def test_explicit_invalid_pose_has_no_side_effects(self):
        poses = [False, [], 'pose', {}, {'x': 51, 'y': 60},
                 {'x': 51, 'y': 60, 'ang': True},
                 {'x': '51', 'y': 60, 'ang': 0},
                 {'x': math.nan, 'y': 60, 'ang': 0},
                 {'x': 51, 'y': 60, 'ang': math.inf},
                 {'x': 10 ** 400, 'y': 60, 'ang': 0},
                 {'x': -.1, 'y': 60, 'ang': 0},
                 {'x': 180, 'y': 60, 'ang': 0},
                 {'x': 50, 'y': 200, 'ang': 0},
                 {'x': 52.5001, 'y': 60, 'ang': 0}]
        for pose in poses:
            with self.subTest(pose=str(pose)[:100]):
                w = self.world()
                before = copy.deepcopy(w.players)
                reply = w.civilian_hijack_start('u', 'taxi', requested_pose=pose)
                self.assertFalse(reply['ok'])
                self.assertEqual(w.quest_cars, {})
                self.assertEqual(w._quest_car_next_id, 10)
                self.assertEqual(w.players, before)

    def test_bounds_distance_and_wrapped_angle(self):
        w = self.world()
        reply = w.civilian_hijack_start('u', requested_pose={'x': 52.5, 'y': 60, 'ang': math.tau + .3})
        self.assertTrue(reply['ok'])
        self.assertAlmostEqual(reply['ang'], .3)
        for x, y in ((.5, .5), (179.5, 199.5)):
            w = self.world()
            w.players['u'].update(x=x, y=y)
            self.assertTrue(w.civilian_hijack_start('u', requested_pose={'x': x, 'y': y, 'ang': 0})['ok'])

    def test_canonical_occupied_empty_and_wreck_are_never_moved(self):
        for occupied, wrecked in ((True, False), (False, False), (False, True)):
            w = self.world()
            w.quest_cars['canonical'] = {'x': 51., 'y': 60., 'ang': .9,
                'driver_uid': 'other' if occupied else '', 'owner_uid': 'owner',
                'passenger_uids': ['friend'], 'lock_lvl': 4, 'wrecked': wrecked}
            before = copy.deepcopy(w.quest_cars)
            reply = w.civilian_hijack_start('u', requested_pose={'x': 51., 'y': 60., 'ang': 2})
            self.assertEqual(reply, {'ok': False, 'reason': 'car_pose_occupied'})
            self.assertEqual(w.quest_cars, before)
            self.assertEqual(w._quest_car_next_id, 10)

    def test_busy_and_missing_player_keep_previous_contract(self):
        w = self.world()
        self.assertEqual(w.civilian_hijack_start('missing')['reason'], 'no_player')
        w.quest_cars['existing'] = {'driver_uid': 'u'}
        self.assertEqual(w.civilian_hijack_start('u')['reason'], 'busy')

    def test_actual_ws_branch_reply_broadcast_wanted_and_rejection(self):
        async def scenario():
            w = self.world()
            packets, broadcast = [], []
            async def receive(text): packets.append(json.loads(text))
            async def observe(text): broadcast.append(json.loads(text))
            ws = types.SimpleNamespace(send_str=receive)
            w.connections['observer'] = types.SimpleNamespace(send_str=observe)
            request = {'model': 'taxi', 'witness': True,
                       'x': 99, 'y': 100,  # Legacy top fields never override validated pose.
                       'carPose': {'x': 51., 'y': 60.5, 'ang': 1.7}}
            await self.ns['dispatch'](w, 'u', request, ws)
            self.assertEqual(packets[-1]['d']['ang'], 1.7)
            self.assertEqual(broadcast[-1]['d']['ang'], 1.7)
            self.assertEqual(broadcast[-1]['d']['x'], 51.)
            self.assertEqual(w.wanted, [1.5])
            rejected = self.world()
            rejected.connections = w.connections
            count = len(broadcast)
            request['carPose']['x'] = 170
            await self.ns['dispatch'](rejected, 'u', request, ws)
            self.assertFalse(packets[-1]['d']['ok'])
            self.assertEqual(len(broadcast), count)
            self.assertEqual(rejected.wanted, [])
            self.assertEqual(rejected.quest_cars, {})
        asyncio.run(scenario())

    def test_actual_preview_new_pose_and_legacy_contract(self):
        ns = self.ns
        ns.update(players={'u': {'x': 50., 'y': 60., 'ang': -.3}},
                  quest_cars={}, next_civ_car_id=1, PREVIEW_START_X=50, PREVIEW_START_Y=60)
        reply = ns['preview_civilian_carjack']('u', {'model': 'taxi',
            'carPose': {'x': 51., 'y': 60., 'ang': 1.2}})
        self.assertEqual((reply['x'], reply['y'], reply['ang']), (51., 60., 1.2))
        before = copy.deepcopy(ns['quest_cars'])
        bad = ns['preview_civilian_carjack']('u', {'carPose': {'x': 170, 'y': 60, 'ang': 0}})
        self.assertFalse(bad['ok'])
        self.assertEqual(ns['quest_cars'], before)
        self.assertEqual(ns['next_civ_car_id'], 2)
        legacy = ns['preview_civilian_carjack']('u', {'x': 45, 'y': 80, 'model': 'corvette_c3'})
        self.assertEqual((legacy['x'], legacy['y']), (45, 80))


if __name__ == '__main__':
    unittest.main()
