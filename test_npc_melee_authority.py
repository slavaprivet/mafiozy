"""Real NPC damage routes + melee admission; no running service or fake NPC HP."""
import asyncio
import ast
import json
import math
import os
import re
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault('BOT_TOKEN', '123456:npc-melee-authority-test')
import mafiozi_bot as game

CLOCK = [2_005_000_000.0]

def fixture(route='cop', hp=100):
    world = game.WorldSim()
    world.add_or_update('7', 'Melee test', {})
    shooter = world.players['7']
    shooter.update(x=0., y=0., dead=False, _weapon='fists', _mode='pvp',
                   _weapon_classes=set(), _melee_attack_t=0., _melee_charge_t=0.,
                   _weapon_shot_t=123., _wanted=0.)
    target = {'id': 'target', 'x': 1., 'y': 0., 'ang': math.pi, 'hp': hp, 'alive': True}
    world.cops = []
    world.aggro = {}
    world.city_gangs = []
    world.gang_nests = []
    world.michael_guards = []
    world.event = None
    if route == 'cop': world.cops = [target]
    elif route == 'mg': world.michael_guards = [target]
    elif route == 'aggro': world.aggro = {'melee_test': {'bots': [target], 'in_combat_uids': set()}}
    elif route == 'city_gang': world.city_gangs = [{'id': 'city', 'bots': [target]}]
    elif route == 'nest': world.gang_nests = [{'id': 'nest', 'bots': [target], '_combat_uids': set()}]
    elif route == 'event':
        target['id'] = 'b'
        world.event = {'id': 'evt', 'boss': target, 'guards': [], 'reward': 100}
    return world, shooter, target, ('aggro' if route in ('city_gang', 'nest') else route)

def hit(world, kind, target, identity='attack1', heavy=False):
    return world.apply_npc_melee('7', kind, target['id'], identity, heavy)

async def check_socket_tail(world, kind, target):
    # Execute the actual protocol preprocessor + selected existing WS tail.
    # No reward mock: this nonlethal case reaches normal broadcast and never
    # invokes the unchanged database reward branches.
    source = Path(game.__file__).read_text(encoding='utf-8')
    start = source.index('                    npc_melee_result = None')
    pre = source[start:source.index("                    if t == 'melee_block':", start)]
    route = {'cop':'cop_shoot', 'mg':'mg_shoot', 'aggro':'aggro_shoot', 'event':'event_shoot'}[kind]
    start = source.index("                    elif t == '" + route + "':")
    boundary = re.search(r'\n {20}elif ', source[start+24:])
    assert boundary
    tail = source[start:start+24+boundary.start()]
    lines = pre.splitlines() + tail.replace('elif t == ', 'if t == ', 1).splitlines()
    code = 'async def exercise():\n t,d=initial_t,dict(initial_d)\n for _ in range(1):\n' + '\n'.join('  '+line[20:] for line in lines)
    messages = []
    class Socket:
        async def send_str(self, text): messages.append(json.loads(text)['d'])
    ws = Socket()
    world.connections['7'] = ws
    scope = dict(game.__dict__)
    scope.update(world=world, ws=ws, uid='7', initial_t='melee_hit',
                 initial_d={'kind':kind, 'id':target['id'], 'attack_id':'socket:1',
                    'dmg':999999, 'x':9999, 'y':9999, 'heavy':False})
    exec(compile(code, '<actual-melee-ws-tail:'+route+'>', 'exec'), scope)
    await scope['exercise']()
    assert target['hp'] == 88
    assert len(messages) == 1 and messages[0]['melee'] and messages[0]['dmg'] == 12
    assert messages[0]['attack_id'] == 'socket:1'
    assert not any(m.get('kind') == 'weapon_shot_reply' for m in messages)
    # Replay takes only the requester path, skips resolver and reward tail.
    await scope['exercise']()
    assert target['hp'] == 88 and len(messages) == 2 and messages[-1]['replayed']

async def run():
    territory = {'melee_test': {'aggro': True, 'r': 0, 'c': 0, 'radius': 9}}
    with patch.object(game.time, 'time', side_effect=lambda: CLOCK[0]), \
         patch.object(game.random, 'random', return_value=1.0), \
         patch.object(game, '_world_los', return_value=True), \
         patch.object(game.WorldSim, 'TERRITORIES_DEF', territory), \
         patch.object(game.WorldSim, '_authorize_weapon_shot', side_effect=AssertionError('Melee must not authorize a firearm')):
        for route in ('cop', 'mg', 'aggro', 'city_gang', 'nest', 'event'):
            world, shooter, target, kind = fixture(route)
            result = hit(world, kind, target)
            assert result['ok'] and result['packet']['melee'] and target['hp'] == 88, route
            assert result['packet']['dmg'] == 12 and result['packet']['shooter_uid'] == '7'
            assert shooter['_weapon_shot_t'] == 123 and shooter['_weapon_classes'] == set()
            assert hit(world, kind, target)['replayed'] and target['hp'] == 88
            assert world.apply_npc_melee('7', kind, 'changed', 'attack1', False)['error'] == 'attack_conflict'
            assert hit(world, kind, target, 'attack1', True)['error'] == 'attack_conflict'
            assert hit(world, kind, target, 'attack2')['error'] == 'cooldown'
            CLOCK[0] += .31
            assert hit(world, kind, target, 'attack2')['ok'] and target['hp'] == 76
            world, shooter, target, kind = fixture(route)
            await check_socket_tail(world, kind, target)

        for name, value in [('_weapon', 'rifle'), ('dead', True), ('_police_cuffed_by', 'cop'),
                            ('_police_downed_by', 'cop'), ('_melee_stunned_until', CLOCK[0]+5),
                            ('_stance', 'prone'), ('_mode', 'pve'), ('_jail_until', CLOCK[0]+5),
                            ('_in_interior', True), ('_business_interior', 'shop')]:
            world, shooter, target, kind = fixture()
            shooter[name] = value
            assert not hit(world, kind, target)['ok'] and target['hp'] == 100, name
        for name, value in [('x', 20.), ('x', float('nan')), ('dead', True), ('alive', False),
                            ('_custody_id', 'arrest'), ('_police_cuffed_by', 'cop')]:
            world, shooter, target, kind = fixture()
            target[name] = value
            assert not hit(world, kind, target)['ok'] and target['hp'] == 100, name
        world, shooter, target, kind = fixture()
        with patch.object(game, '_world_los', return_value=False):
            assert hit(world, kind, target)['error'] == 'range_or_wall'
        assert not world.apply_npc_melee('7', 'unknown', 'target', 'a', False)['ok']
        assert not world.apply_npc_melee('7', 'cop', 'target', 'x'*97, False)['ok']
        assert not world.apply_npc_melee('7', 'cop', 'target', 'a', 'true')['ok']
        assert hit(world, kind, target, heavy=True)['error'] == 'charge'
        shooter['_melee_charge_t'] = CLOCK[0] - 1.0
        assert hit(world, kind, target, heavy=True)['error'] == 'charge'
        shooter['_melee_charge_t'] = CLOCK[0] - 1.3
        result = hit(world, kind, target, heavy=True)
        assert result['ok'] and result['packet']['heavy'] and result['packet']['dmg'] == 18 and target['hp'] == 82
        assert shooter['_melee_charge_t'] == 0
        CLOCK[0] += .31
        assert hit(world, kind, target, 'next-heavy', True)['error'] == 'charge'
        world, shooter, target, kind = fixture()
        target['_melee_block'] = True
        shooter['_melee_charge_t'] = CLOCK[0] - 1.3
        result = hit(world, kind, target, heavy=True)
        assert result['packet']['blocked'] and result['packet']['dmg'] == 2
        assert not result['packet']['stunned'] and target['alive']
        world, shooter, target, kind = fixture('event', hp=10)
        result = hit(world, kind, target)
        assert result['kill_packet']['kind'] == 'inkassator_killed'
        assert result['kill_packet']['reward'] == 100 and world.event['finished']
        assert hit(world, kind, target)['replayed']
        assert len(world._npc_melee_receipts) == 1
        fresh, _, _, _ = fixture()
        assert not fresh._npc_melee_receipts, 'receipt lifetime matches a new NPC world'
    print('PASS NPC melee authority: all 6 real target routes/socket tails, no firearm/ammo, spoof fields ignored, replay/conflict/shared cadence, range/LOS/charge/unarmed/custody/block, convoy kill reward retained')

if __name__ == '__main__': asyncio.run(run())
