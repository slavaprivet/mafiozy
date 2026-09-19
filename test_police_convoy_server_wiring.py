"""Execute the real WS branch and arrest-contact helper without importing backend."""
import ast, asyncio, json, textwrap, time, math
from pathlib import Path
from types import SimpleNamespace, MethodType
import police_convoy
source=Path('mafiozi_bot.py').read_text(encoding='utf-8-sig');tree=ast.parse(source)
worldnode=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='WorldSim')
ns=dict(math=math,time=SimpleNamespace(time=lambda:100.),_world_los=lambda *a:True,police_convoy=police_convoy)
for name in ('validate_citycop_arrest','gta_enter'):
 node=next(n for n in worldnode.body if isinstance(n,ast.FunctionDef) and n.name==name)
 exec(compile(ast.Module(body=[node],type_ignores=[]),'real_'+name,'exec'),ns)
class Socket:
 def __init__(self):self.packets=[]
 async def send_str(self,s):self.packets.append(json.loads(s))
async def check():
 writes=[]
 async def update(*args,**kw):writes.append((args,kw))
 w=SimpleNamespace(players={'1':dict(x=10,y=10,hp=100,_wanted=3,uid='1')},cops=[dict(id='cop',x=10.4,y=10,ang=0,hp=100,alive=True,target_uid='1',kind='combat')],_police_convoys={},quest_cars={},CITYCOP_ARREST_CONFIRM_R=2.5,prison_alarm={},_in_lair_zone=lambda *a:False)
 w.validate_citycop_arrest=MethodType(ns['validate_citycop_arrest'],w)
 assert w.validate_citycop_arrest('1')['ok']
 w.cops[0]['target_uid']='other';assert not w.validate_citycop_arrest('1')['ok'];w.cops[0]['target_uid']='1'
 # Execute exact production arrest handler including staged continue and DB path.
 chunk=source.split("                    elif t == 'citycop_arrest':",1)[1].split("                    elif t == 'prison_alarm':",1)[0]
 program='async def handle():\n    for _ in [0]:\n'+textwrap.indent(textwrap.dedent(chunk),'        ')
 sock=Socket();env=dict(ns,world=w,uid='1',d=dict(response_vehicle='service-local',x=10,y=10,ang=0),ws=sock,json=json,update_character=update,_world_is_wall=lambda *a:False)
 exec(program,env);await env['handle']();ack=sock.packets[-1]['d'];assert ack['ok'] and ack['staged'];assert not writes and not w.players['1'].get('_jail_until');assert w.players['1']['_wanted']==3
 # A client cannot bypass staged booking by reusing the old booking flag.
 env['d']=dict(booking=True,response_vehicle='service-local');await env['handle']();assert sock.packets[-1]['d']['reason']=='requires_convoy_booking';assert not writes
 # Canonical custody vehicle cannot be hijacked via the ordinary GTA enter path.
 out=ns['gta_enter'](w,'1',ack['vehicle_id']);assert out['reason']=='police_custody'
 # Real shooting-loop guards prevent both the capturing cop and other cops firing.
 loop=source.split('        for cop in list(self.cops):',1)[1].split('            # Цель уже в тюрьме',1)[0]
 guard='for cop in list(self.cops):\n'+textwrap.indent(textwrap.dedent(loop),'    ')+'    shots.append(cop["id"])\n'
 w.cops.append(dict(id='other',target_uid='1',alive=True,hp=100))
 scope=dict(ns,self=w,shots=[],pkts=[]);exec(guard,scope);assert scope['shots']==[]
 w.players['1'].pop('_npc_convoy_id');w._police_convoys.clear();w.cops[0].pop('_convoy_owner_uid',None)
 scope['shots']=[];exec(guard,scope);assert len(scope['shots'])==2
 # Repeat the production handler as an early foot capture, no car is created.
 w.quest_cars.clear();env['d']=dict(capture=True);await env['handle']();capture=sock.packets[-1]['d'];assert capture['ok'] and capture['phase']=='escort';assert not w.quest_cars and not writes
 scope['shots']=[];exec(guard,scope);assert scope['shots']==[]
 # Lethal server police damage keeps durable death and never starts an early sentence.
 node=next(n for n in worldnode.body if isinstance(n,ast.AsyncFunctionDef) and n.name=='_tick_cops_async');body=ast.get_source_segment(source,node)
 lethal=body.split("if target['hp'] <= 0:",1)[1].split('pkts.append',1)[0]
 assert "['_jail_until']" not in lethal and "['_wanted']" not in lethal
 w.players['1']['dead']=True;events=police_convoy.tick(w,101);assert events[0]['phase']=='dead';assert police_convoy.active(w,'1') is None;assert w.players['1']['dead']
 print('PASS real server WS/contact/GTA: validated server identity, staged no DB jail, legacy booking bypass blocked, no custody hijack, true death owns interruption')
asyncio.run(check())
