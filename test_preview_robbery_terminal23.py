"""Run only two actual preview branches, never import the preview/backend."""

import ast
import copy
import json
from pathlib import Path
from types import SimpleNamespace
import unittest


SOURCE_PATH = Path(__file__).with_name('_preview_ws_server.py')
TREE = ast.parse(SOURCE_PATH.read_text(encoding='utf-8-sig'), filename=str(SOURCE_PATH))


def actual_branch(action):
    matches = []
    for node in ast.walk(TREE):
        if not isinstance(node, ast.If):
            continue
        test = node.test
        if (isinstance(test, ast.Compare) and isinstance(test.left, ast.Name)
                and test.left.id == 't' and len(test.ops) == 1
                and isinstance(test.ops[0], ast.Eq) and len(test.comparators) == 1
                and isinstance(test.comparators[0], ast.Constant)
                and test.comparators[0].value == action):
            matches.append(node)
    if len(matches) != 1:
        raise AssertionError(f'Expected one actual preview branch for {action}, found {len(matches)}')
    # Wrap the unchanged branch body in an async function. No module top-level
    # code, imported server, sockets, credentials, real DB, or background tasks.
    function = ast.parse('async def dispatch(d, uid, ws):\n    pass\n').body[0]
    function.body = copy.deepcopy(matches[0].body)
    module = ast.Module(body=[function], type_ignores=[])
    ast.fix_missing_locations(module)
    if any(isinstance(node, (ast.Import, ast.ImportFrom)) for node in ast.walk(module)):
        raise AssertionError('Terminal branch unexpectedly imports application code')
    return compile(module, str(SOURCE_PATH), 'exec')


BRANCHES = {action: actual_branch(action) for action in
            ('npc_robbery_resolve', 'npc_robbery_confiscate')}


class FakeWs:
    def __init__(self):
        self.messages = []

    async def send_str(self, value):
        self.messages.append(json.loads(value))


class Fixture:
    def __init__(self, status='active', *, outstanding=True,
                 interrogation_arrest=False, cash=40, wanted=3):
        self.uid = 'fixture-user'
        self.rid = 'robbery-23'
        self.now = 1000
        self.account = {'cash': cash, 'wanted': wanted}
        self.players = {self.uid: {'wanted': wanted, 'x': 99, 'y': 88}}
        receipt = {'robbery_id': self.rid, 'npc_id': 'resident-original',
                   'amount': 7, 'status': status, 'created_at': 100,
                   'resolved_at': 0, 'crime_r': 5, 'crime_c': 6,
                   'interrogation_arrest': interrogation_arrest}
        self.state = {'meta': {self.rid: receipt},
                      'outstanding': {self.rid: 7} if outstanding else {},
                      'unreported': {self.rid: 7} if status == 'unreported' else {},
                      'cooldowns': {'resident-original': 3700}}
        self.all_states = {self.uid: self.state}
        self.ws = FakeWs()
        self.env = {'json': json, 'time': SimpleNamespace(time=lambda: self.now),
                    'preview_account': self.get_account, 'players': self.players,
                    'preview_npc_robberies': self.all_states}
        self.handlers = {}
        for action, code in BRANCHES.items():
            exec(code, self.env)
            self.handlers[action] = self.env['dispatch']

    def get_account(self, uid):
        assert uid == self.uid
        return self.account

    def snapshot(self):
        return copy.deepcopy((self.account, self.players, self.all_states))

    async def send(self, action, data):
        before = len(self.ws.messages)
        await self.handlers[action](data, self.uid, self.ws)
        assert len(self.ws.messages) == before + 1, 'one request sends one reply'
        envelope = self.ws.messages[-1]
        assert envelope['t'] == 'event'
        assert envelope['d']['kind'] == action + '_reply'
        return envelope['d']

    async def release(self, **overrides):
        return await self.send('npc_robbery_resolve',
                               {'robbery_id': self.rid, 'outcome': 'released', **overrides})

    async def confiscate(self, **overrides):
        return await self.send('npc_robbery_confiscate', {'robbery_id': self.rid, **overrides})


class PreviewRobberyTerminalTests(unittest.IsolatedAsyncioTestCase):
    async def test_release_is_once_and_terminal_receipt_stays_stable(self):
        f = Fixture()
        self.assertTrue((await f.release())['ok'])
        self.assertEqual(f.account, {'cash': 40, 'wanted': 2})
        self.assertEqual(f.players[f.uid]['wanted'], 2)
        self.assertNotIn(f.rid, f.state['outstanding'])
        self.assertEqual(f.state['meta'][f.rid]['status'], 'released')
        self.assertEqual(f.state['meta'][f.rid]['resolved_at'], 1000)
        self.assertEqual((f.state['meta'][f.rid]['crime_r'], f.state['meta'][f.rid]['crime_c']), (5, 6))
        after = f.snapshot()
        f.now = 2000
        self.assertFalse((await f.release())['ok'])
        self.assertEqual(f.snapshot(), after, 'retry cannot lower wanted or rewrite terminal timestamp')
        self.assertFalse((await f.confiscate())['ok'])
        self.assertEqual(f.snapshot(), after, 'cross-action retry cannot turn released into confiscated')

    async def test_release_rejects_all_non_active_states_before_mutation(self):
        for status in ('unreported', 'confiscated', 'bribed', 'released'):
            with self.subTest(status=status):
                f = Fixture(status, outstanding=True)
                before = f.snapshot()
                self.assertFalse((await f.release())['ok'])
                self.assertEqual(f.snapshot(), before)

    async def test_release_requires_exact_outcome(self):
        for outcome in (None, '', 'confiscated', 'Released', 'bribed', 1):
            with self.subTest(outcome=outcome):
                f = Fixture()
                before = f.snapshot()
                self.assertFalse((await f.release(outcome=outcome))['ok'])
                self.assertEqual(f.snapshot(), before)
        f = Fixture()
        before = f.snapshot()
        self.assertFalse((await f.send('npc_robbery_resolve', {'robbery_id': f.rid}))['ok'])
        self.assertEqual(f.snapshot(), before)

    async def test_release_preserves_interrogation_arrest_decision(self):
        f = Fixture(interrogation_arrest=True)
        before = f.snapshot()
        self.assertFalse((await f.release())['ok'])
        self.assertEqual(f.snapshot(), before)

    async def test_confiscation_is_once_and_terminal_receipt_stays_stable(self):
        f = Fixture()
        reply = await f.confiscate()
        self.assertTrue(reply['ok'])
        self.assertEqual(reply['amount'], 7)
        self.assertEqual(reply['cash'], 33)
        self.assertEqual(f.account, {'cash': 33, 'wanted': 3})
        self.assertEqual(f.state['meta'][f.rid]['status'], 'confiscated')
        self.assertEqual(f.state['meta'][f.rid]['resolved_at'], 1000)
        self.assertNotIn(f.rid, f.state['outstanding'])
        after = f.snapshot()
        f.now = 2000
        self.assertFalse((await f.confiscate())['ok'])
        self.assertEqual(f.snapshot(), after, 'retry cannot debit cash or rewrite terminal receipt')
        self.assertFalse((await f.release())['ok'])
        self.assertEqual(f.snapshot(), after, 'release cannot undo a confiscation')

    async def test_confiscation_requires_active_meta_even_with_outstanding_amount(self):
        for status in ('unreported', 'released', 'confiscated', 'bribed'):
            with self.subTest(status=status):
                f = Fixture(status, outstanding=True)
                before = f.snapshot()
                self.assertFalse((await f.confiscate())['ok'])
                self.assertEqual(f.snapshot(), before, 'rejection must not pop outstanding or alter status')

    async def test_confiscation_missing_meta_and_missing_amount_do_not_mutate(self):
        for missing in ('meta', 'amount'):
            with self.subTest(missing=missing):
                f = Fixture()
                f.state['meta' if missing == 'meta' else 'outstanding'].clear()
                before = f.snapshot()
                self.assertFalse((await f.confiscate())['ok'])
                self.assertEqual(f.snapshot(), before)

    async def test_missing_or_invalid_id_does_not_mutate_either_terminal_branch(self):
        for action in ('npc_robbery_resolve', 'npc_robbery_confiscate'):
            for robbery_id in ('unknown', '', None, 123):
                with self.subTest(action=action, robbery_id=robbery_id):
                    f = Fixture()
                    before = f.snapshot()
                    reply = await f.send(action, {'robbery_id': robbery_id, 'outcome': 'released'})
                    self.assertFalse(reply['ok'])
                    self.assertEqual(f.snapshot(), before)

    async def test_missing_outstanding_never_confiscates_unreported_cash(self):
        f = Fixture('unreported', outstanding=False)
        before = f.snapshot()
        self.assertFalse((await f.confiscate())['ok'])
        self.assertEqual(f.snapshot(), before)

    async def test_confiscation_cash_floor_and_retry(self):
        f = Fixture(cash=3)
        self.assertTrue((await f.confiscate())['ok'])
        self.assertEqual(f.account['cash'], 0)
        after = f.snapshot()
        self.assertFalse((await f.confiscate())['ok'])
        self.assertEqual(f.snapshot(), after)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(PreviewRobberyTerminalTests)
    result = unittest.TextTestRunner(verbosity=0).run(suite)
    if not result.wasSuccessful():
        raise SystemExit(1)
    print('PASS actual preview terminal branches: release/wanted once, confiscation/cash once, terminal stability, invalid/no-mutation; no server imports')
