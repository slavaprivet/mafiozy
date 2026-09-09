"""Run isolated real receipt helper/convoy damage branch without server startup."""
import ast
from pathlib import Path
from types import SimpleNamespace, MethodType

source = Path(__file__).with_name('mafiozi_bot.py').read_text(encoding='utf-8')
tree = ast.parse(source)
helper = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == '_attach_world_hit_shot_id')
world_class = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'WorldSim')
convoy = next(n for n in world_class.body if isinstance(n, ast.FunctionDef) and n.name == 'apply_event_shoot')
scope = {'_world_los': lambda *args: True, 'time': SimpleNamespace(time=lambda: 1000)}
exec(compile(ast.Module(body=[helper, convoy], type_ignores=[]), '<real-source-receipts>', 'exec'), scope)
attach = scope['_attach_world_hit_shot_id']
base = {'kind': 'cop_hit', 'cop_id': 'c1', 'shooter_uid': '7', 'dmg': 10}
claim = {'ok': True, 'shot_id': 'shot_1'}
packet = dict(base)
assert attach(packet, 'shot_1', claim, '7', 'cop_id', 'c1') is packet
assert packet['shot_id'] == 'shot_1'
assert {k: v for k, v in packet.items() if k != 'shot_id'} == base
for raw, auth, actor, target, changes in [
    ('shot_1', {'ok': False}, '7', 'c1', {}),
    ('shot_1', {**claim, 'replayed': True}, '7', 'c1', {}),
    ('another', claim, '7', 'c1', {}),
    ('shot_1', claim, '8', 'c1', {}),
    ('shot_1', claim, '7', 'c2', {}),
    (['shot_1'], claim, '7', 'c1', {}),
    ('x' * 97, claim, '7', 'c1', {}),
    ('shot_1', claim, '7', 'c1', {'dmg': 0}),
    ('shot_1', claim, '7', 'c1', {'ok': False}),
    ('shot_1', claim, '7', 'c1', {'kind': 'weapon_shot_reply'}),
]:
    packet = {**base, **changes}
    attach(packet, raw, auth, actor, 'cop_id', target)
    assert 'shot_id' not in packet, (raw, auth, actor, target, changes)

def simulation():
    sim = SimpleNamespace(event={'id': 'event1', 'boss': {'id': 'b', 'x': 2, 'y': 0, 'hp': 100, 'alive': True}, 'guards': [], 'reward': 10},
                          players={'7': {'x': 0, 'y': 0}}, EVENT_INTERVAL=300)
    sim._weapon_damage = lambda *args: 10
    sim._authorize_weapon_shot = lambda *args: None
    sim.apply_event_shoot = MethodType(scope['apply_event_shoot'], sim)
    return sim

sim = simulation()
receipt = {}
assert sim.apply_event_shoot('7', 'b', 'pistol', {'range': 8}, None, receipt) is None
assert sim.event['boss']['hp'] == 90
assert receipt == {'confirmed_hit': True, 'dmg': 10, 'killed': False, 'event_id': 'event1'}
trace = {'kind': 'player_shot', 'shooter_uid': '7', 'target': 'b', **receipt}
attach(trace, 'shot_1', claim, '7', 'target', 'b')
assert trace['shot_id'] == 'shot_1'
for reject in ['range', 'dead', 'observer', 'wall', 'weapon']:
    sim = simulation()
    profile = {'range': 8}
    scope['_world_los'] = lambda *args: True
    if reject == 'range': sim.event['boss']['x'] = 99
    if reject == 'dead': sim.event['boss']['alive'] = False
    if reject == 'observer': sim.players['7']['_mode'] = 'pve'
    if reject == 'wall': scope['_world_los'] = lambda *args: False
    if reject == 'weapon': profile = None
    receipt = {}
    sim.apply_event_shoot('7', 'b', 'pistol', profile, None, receipt)
    assert not receipt, reject
    assert sim.event['boss']['hp'] == 100, reject
assert source.count('_attach_world_hit_shot_id(') == 6
print('PASS server shot receipts: real accepted damage, blocked shot has no receipt, replay/type/length/shooter/target validation, no damage changes')
