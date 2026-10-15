"""Prepare a new ten-resident service-interruption check from the preserved30 fixture."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE.parent / 'proposals/service_threat31_extended'
OLD = ROOT / 'outputs/coordinator30_npc54/proposals/service_threat30'


def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new)


if __name__ == '__main__':
    OUT.mkdir(exist_ok=False)
    observer = (OLD / 'observer30.gd').read_text(encoding='utf-8-sig')
    observer = replace_once(observer, 'extends "../injury30/observer_death28.gd"', 'extends "observer_base31.gd"')
    observer = replace_once(observer, 'var kind30:="shop"', '''var kind30:="shop"
var target31:="resident_1"
var resumed_route31:RefCounted
var roster31:Array[String]=[]
var other_positions31:Dictionary={}
var other_moved31:Dictionary={}
var population_drift31:=false''')
    observer = replace_once(observer,
        '\tif _pop.hit_owners.size()!=1:_finish("single_resident_required");return false\n\t_life=_pop.daily._lives.get("resident_1");_health=_pop.daily._health.get("resident_1")',
        '''\tif _pop.hit_owners.size()!=10 or scene.preview_venue_staff29._rows.size()!=12:_finish("ten_residents_twelve_staff_required");return false
\tfor argument:String in OS.get_cmdline_user_args():
\t\tif argument.begins_with("--qa-service-resident="):target31=argument.trim_prefix("--qa-service-resident=")
\tfor id:String in _pop.daily._lives:roster31.append(id)
\troster31.sort()
\tvar expected:Array[String]=[]
\tfor i:int in range(1,11):expected.append("resident_"+str(i))
\texpected.sort()
\tif roster31!=expected:_finish("original_roster_required");return false
\tfor id:String in roster31:
\t\tif id!=target31:
\t\t\tother_positions31[id]=_pop.daily._lives[id]._token.body.global_position
\t\t\tother_moved31[id]=0.0
\t_life=_pop.daily._lives.get(target31);_health=_pop.daily._health.get(target31)''')
    observer = replace_once(observer,
        '\tvar step_m:float=Vector2(_body.global_position.x-previous30.x,_body.global_position.z-previous30.z).length()',
        '''\tif _pop.hit_owners.size()!=10 or _pop.daily._lives.size()!=10 or get_tree().current_scene.preview_venue_staff29._rows.size()!=12:population_drift31=true
\tfor id:String in other_positions31:
\t\tvar peer:RefCounted=_pop.daily._lives.get(id)
\t\tif peer==null or not is_instance_valid(peer._token.body):population_drift31=true;continue
\t\tvar point:Vector3=peer._token.body.global_position
\t\tother_moved31[id]+=Vector2(point.x-other_positions31[id].x,point.z-other_positions31[id].z).length()
\t\tother_positions31[id]=point
\tif _phase=="resumed_purchase" and economy30._route!=null:resumed_route31=economy30._route
\tvar step_m:float=Vector2(_body.global_position.x-previous30.x,_body.global_position.z-previous30.z).length()''')
    observer = replace_once(observer,
        'checks30.resumed_purchase_completed=int(_life._completed.get(kind30,0))>=1 and registry30.ledger.requests.is_empty() and registry30._service29.keys.is_empty()',
        'checks30.resumed_purchase_completed=int(_life._completed.get(kind30,0))>=1 and resumed_route31!=null and resumed_route31.is_outside() and not registry30.ledger.requests.has(resumed_route31._key) and not registry30._service29.keys.has(resumed_route31._key)')
    observer = replace_once(observer,
        '\tvar passed:bool=reason=="complete" and violations30.is_empty()',
        '''\tchecks30.population_preserved=not population_drift31 and roster31.size()==10
\tchecks30.other_nine_moved=other_moved31.size()==9
\tfor id:String in other_moved31:checks30.other_nine_moved=checks30.other_nine_moved and float(other_moved31[id])>.25
\trequired.append("population_preserved");required.append("other_nine_moved")
\tvar passed:bool=reason=="complete" and violations30.is_empty()''')
    observer = replace_once(observer,
        '"setup":setup30,"service":service30',
        '"target":target31,"roster":roster31,"other_nine_distance_m":other_moved31,"setup":setup30,"service":service30')
    observer = observer.replace('SERVICE_THREAT30', 'SERVICE_THREAT31')
    (OUT / 'observer31.gd').write_text(observer, encoding='utf-8')
    (OUT / 'observer_base31.gd').write_bytes((OLD.parent / 'injury30/observer_death28.gd').read_bytes())
    entry = (OLD / 'entry30.gd').read_text(encoding='utf-8-sig').replace('observer30.gd', 'observer31.gd')
    (OUT / 'entry31.gd').write_text(entry, encoding='utf-8')
    runner = (OLD / 'run30.py').read_text(encoding='utf-8-sig')
    runner = runner.replace('coordinator30_npc54/game', 'coordinator31_release57/game')
    runner = replace_once(runner, "p.add_argument('--wait',type=int,default=30);a=p.parse_args()", "p.add_argument('--wait',type=int,default=30);p.add_argument('--resident',choices=['resident_'+str(i) for i in range(1,11)],default='resident_1');a=p.parse_args()")
    runner = replace_once(runner,
        "fixtures=[OUT/'entry30.gd',OUT/'observer30.gd',OUT/'run30.py',OUT.parent/'injury30/observer_death28.gd']",
        "fixtures=[OUT/'entry31.gd',OUT/'observer31.gd',OUT/'run31.py',OUT/'observer_base31.gd',ROOT/'outputs/coordinator31_release57/ASSEMBLY.json',ROOT/'tools/godot/test_scheduler.py']")
    runner = replace_once(runner,
        "            flags=read(OUT.parent/'staff30/runs/cycle03/FLAGS.json')\n            flags=[f for f in flags if not f.startswith(('--qa-','--city-hp=','--city-energy-start=','--city-wallet-start=','--city-clear-cache='))]\n            flags+=['--city-hp=100','--city-energy-start=100','--city-wallet-start=1000','--city-threat30=1','--city-physical-dispatch30=1','--city-local-avoidance29=1','--qa-service-kind='+a.case,'--qa-out='+str(run)]",
        """            assembly=read(ROOT/'outputs/coordinator31_release57/ASSEMBLY.json')
            assert before==assembly['source_pins'],'Exact frozen release57 required'
            flags=list(assembly['launch_arguments'])
            assert '--city-qa=10' in flags and '--city-venue-staff29=1' in flags
            assert not any(f.startswith(('--city-wallet-start=','--city-energy-start=','--city-sandbox-seed=')) for f in flags)
            flags+=['--qa-service-kind='+a.case,'--qa-service-resident='+a.resident,'--qa-out='+str(run)]""")
    runner = runner.replace("OUT/'entry30.gd'", "OUT/'entry31.gd'").replace('SERVICE_THREAT30', 'SERVICE_THREAT31')
    runner = runner.replace('READY_WAITING_ROOT_FINAL_SOURCE_GO', 'PREPARED_NOT_NATIVE_TESTED')
    runner = replace_once(runner, "                            time.sleep(.2)", "                            if sum(f.stat().st_size for f in run.rglob('*') if f.is_file())>64*1024*1024:raise RuntimeError('Output cap64MiB reached')\n                            time.sleep(.2)")
    (OUT / 'run31.py').write_text(runner, encoding='utf-8')
    compile(runner, str(OUT / 'run31.py'), 'exec')
    original = [OLD / name for name in ('run30.py', 'observer30.gd', 'entry30.gd')]
    original.append(OLD.parent / 'injury30/observer_death28.gd')
    (OUT / 'PREPARATION31.json').write_text(json.dumps({
        'schema': 'mafiozi.service-threat31-preparation/v1', 'native_tested': False,
        'base_sources': {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in original},
        'scope': 'Exact release57, original10+12 continuous; one local purchase agenda only. All native input/service/transactions/physical exits remain production. No NPC position, HP, cash, energy writes. Other nine movement tracked; claims checked for target only.',
        'known_limits': 'One selected actor per case, local agenda initialization is a fixture, not natural selection. No headless FPS claim.'
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'prepared': True, 'native_tested': False, 'folder': str(OUT)}, ensure_ascii=True))
