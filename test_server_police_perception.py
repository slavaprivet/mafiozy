import ast
import math
import textwrap
import time
from types import SimpleNamespace
from pathlib import Path

def check():
    source=Path('mafiozi_bot.py').read_text(encoding='utf-8-sig');tree=ast.parse(source)
    ns={'math':math,'time':SimpleNamespace(time=lambda:100.),'_world_is_wall':lambda r,c:c==2}
    for name in ('_world_los','_world_observer_sees'):
        node=next((n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==name),None)
        if node:exec(compile(ast.Module(body=[node],type_ignores=[]),'server_'+name,'exec'),ns)
    branch=source.split("elif t == 'open_fire':",1)[1].split("elif t == 'taxi_ride':",1)[0]
    begin=branch.index('                                # Свидетели на стороне сервера')
    end=branch.index('                                has_witness',begin)
    block=textwrap.dedent(branch[begin:end])
    player={'x':4.,'y':0.,'ang':0.,'hp':80,'_wanted':2.}
    world=SimpleNamespace(cops=[{'alive':True,'x':0.,'y':0.,'ang':0.}],players={'self':player})
    env=dict(ns,world=world,p=player,px=4.,py=0.,uid='self');exec(block,env)
    assert env['cop_sees'] is False,'RED: server cop detects shooter through legacy wall'
    ns['_world_is_wall']=lambda r,c:False
    # Functions retain ns globals; all identity/pose values are server state.
    world.cops[0]['ang']=math.pi;env=dict(ns,world=world,p=player,px=4.,py=0.,uid='self');exec(block,env);assert not env['cop_sees']
    world.cops[0]['ang']=0;exec(block,env);assert env['cop_sees']
    world.players['other']={'x':0.,'y':0.,'ang':math.pi};exec(block,env);assert not env['player_sees']
    world.players['other']['ang']=0;exec(block,env);assert env['player_sees']
    world.players['other']['_jail_until']=200;exec(block,env);assert not env['player_sees']
    sees=ns['_world_observer_sees'];observer={'x':0.,'y':0.,'ang':0.,'alive':True}
    assert not sees(observer,{'x':15.,'y':0.},14,100)
    assert not sees({**observer,'ang':float('nan')},player,14,100)
    assert not sees({**observer,'dead':True},player,14,100)
    assert not sees({**observer,'_in_interior':True,'_in_interior_until':200},player,14,100)
    assert not sees(observer,{**player,'_in_interior':True,'_in_interior_until':200},14,100)
    ns['_world_is_wall']=lambda r,c:c==2;assert not sees(observer,player,14,100)
    assert player['hp']==80 and player['_wanted']==2,'Observation does not clear existing wanted or apply damage'
    assert "witness_npc" not in block and 'd.get' not in block,'Server observer claims do not use client witness boolean'
    assert "has_witness = (near_station or civilian" in branch,'Unrelated legacy reports preserved explicitly'
    actors=[{'x':float(i%9),'y':float(i//9),'ang':(i%4)*math.pi/2,'alive':True} for i in range(72)]
    def measure(probe):
        samples=[]
        for _ in range(1000):
            start=time.perf_counter_ns()
            for actor in actors:probe(actor)
            samples.append((time.perf_counter_ns()-start)/1e6)
        samples.sort();return {'p50_ms':round(samples[500],4),'p95_ms':round(samples[950],4)}
    before=measure(lambda actor:(actor['x']-4)**2+actor['y']**2<=196)
    after=measure(lambda actor:sees(actor,player,14,100))
    print('CPU 72 server observers/event (actual helper, test tile wall; not native LIVE):',{'before_radius_only':before,'after_fov_los':after})
    print('PASS actual open_fire observer assignments: server pose/FOV/LOS/range, no client witness in observer proof, jailed/dead/invalid/interior exclusion; existing wanted/damage unchanged')

if __name__=='__main__':check()

