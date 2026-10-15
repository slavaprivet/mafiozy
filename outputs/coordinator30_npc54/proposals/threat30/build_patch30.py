"""Create exact integration hunks and a small dependency-only native fixture project.
Never writes shared game54, older releases or any existing acceptance receipts.
"""
import hashlib,json,pathlib,re,sys
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
SOURCE=ROOT/'outputs/coordinator30_npc54/game'
PATCH=OUT/'patch'
changes=[]
def add(file,before,after):
    changes.append({'file':file,'before':before,'after':after})

add('scripts/npc_daily_life.gd','extends RefCounted\n','extends RefCounted\nconst ThreatLife30 = preload("res://scripts/city/runtime/npc_threat_life30.gd")\nvar _threat30: RefCounted\n')
add('scripts/npc_daily_life.gd','\t_now=_health._now()\n\tif _attention29.step(self, delta, row):','\t_now=_health._now()\n\tif _threat30 != null and _threat30.step(delta,row):\n\t\t_busy=false; return\n\tif _attention29.step(self, delta, row):')
add('scripts/npc_daily_life.gd','func dsh_notice_damage() -> Dictionary:\n\t_attention29.clear()','func dsh_notice_damage() -> Dictionary:\n\tvar scene30: Node3D = _dsh_life_scene()\n\tif is_instance_valid(scene30):\n\t\tvar world30: RefCounted = scene30.get_meta("npc_threat_world30",null)\n\t\tif world30 != null: world30.confirmed_hit(self)\n\t_attention29.clear()')
add('scripts/npc_daily_life.gd','func _end_life() -> void:\n','func _end_life() -> void:\n\tif _threat30 != null: _threat30.cancel("death"); _threat30=null\n')
add('scripts/npc_daily_life.gd','func incident_can_hear(owner: RefCounted) -> bool:\n','func threat_physics_active30() -> bool:\n\treturn _threat30 != null and _threat30.active()\n\nfunc threat_event30(event: Dictionary, world: RefCounted) -> Dictionary:\n\tif _disposed or not Thread.is_main_thread(): return {"accepted":false,"reason":"life_retired"}\n\tif _threat30 == null: _threat30=ThreatLife30.new()\n\treturn _threat30.accept(self,event,world)\n\nfunc incident_can_hear(owner: RefCounted) -> bool:\n')
add('scripts/npc_visual/npc_attention29.gd','\t\tallowed = allowed and life._phase != "INCIDENT_REACTING"','\t\tallowed = allowed and (life._threat30 == null or not life._threat30.active())\n\t\tallowed = allowed and life._phase != "INCIDENT_REACTING"')
add('scripts/npc_city_population.gd','const IncidentDispatcher = preload("res://scripts/city/runtime/npc_incident_dispatcher.gd")','const IncidentDispatcher = preload("res://scripts/city/runtime/npc_incident_dispatcher.gd")\nconst ThreatWorld30 = preload("res://scripts/city/runtime/npc_threat_world30.gd")')
add('scripts/npc_city_population.gd','\tvar dispatcher: RefCounted=IncidentDispatcher.new()\n\tvar configured: Dictionary=dispatcher.configure(weapons,self)','\tvar threats30: bool = OS.get_cmdline_user_args().has("--city-threat30=1")\n\tvar dispatcher: RefCounted=ThreatWorld30.new() if threats30 else IncidentDispatcher.new()\n\tvar configured: Dictionary=dispatcher.configure(weapons,self,scene.get_meta("npc_police_report30",Callable())) if threats30 else dispatcher.configure(weapons,self)')
add('scripts/npc_ambient/ambient_pose28.gd','or str(value.get("kind", "")) not in KINDS: return {}','or (str(value.get("kind", "")) not in KINDS and value.get("kind") != "police_phone30"): return {}')
add('scripts/npc_ambient/ambient_pose28.gd','\tif kind not in KINDS: return selected','\tif kind not in KINDS and kind != "police_phone30": return selected')
add('scripts/npc_ambient/ambient_pose28.gd','\t\t"phone":\n\t\t\tvar phone30:', '\t\t"police_phone30":\n\t\t\tvar ear30: Vector3 = head+(-_right*.27+_up*.04+_forward*.07)*_reach\n\t\t\t_palm30("l",ear30-_up*_reach*.09,_up)\n\t\t\t_palm30("r",_p(shoulders,-.08,-.25,.38),-_right*.7+_up*.3)\n\t\t\t_turn_global("head",_forward,-.06); _turn_global("chest",_up,slow*.025)\n\t\t"phone":\n\t\t\tvar phone30:')
add('scripts/npc_ambient/ambient_props28.gd','if kind not in ["book", "newspaper", "camera", "phone"]','if kind not in ["book", "newspaper", "camera", "phone", "police_phone30"]')
add('scripts/npc_ambient/ambient_props28.gd','\t\t"phone":','\t\t"phone", "police_phone30":')
add('scripts/npc_ambient/ambient_props28.gd','\tif kind == "phone":','\tif kind in ["phone", "police_phone30"]:')
add('scripts/npc_ambient/ambient_props28.gd','\t\t_root.global_transform = Transform3D(frame30.orthonormalized()*Basis(Vector3.RIGHT,-.22),rig.to_global(center30))','\t\tif kind == "police_phone30":\n\t\t\tcenter30 = rig.get_bone_global_pose(palm).origin+up30*reach30*.09\n\t\t\tframe30 = rig.global_basis*Basis(forward30,up30,-side30)\n\t\t\t_root.global_transform = Transform3D(frame30.orthonormalized(),rig.to_global(center30))\n\t\telse:\n\t\t\t_root.global_transform = Transform3D(frame30.orthonormalized()*Basis(Vector3.RIGHT,-.22),rig.to_global(center30))')

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if __name__=='__main__':
    projected={};pins={}
    for change in changes:
        rel=change['file']
        if rel not in projected:
            projected[rel]=(SOURCE/rel).read_text(encoding='utf-8-sig');pins[rel]=sha(SOURCE/rel)
        assert projected[rel].count(change['before'])==1,(rel,change['before'])
        projected[rel]=projected[rel].replace(change['before'],change['after'],1)
    (OUT/'INTEGRATION_HUNKS.json').write_text(json.dumps({'source_pins':pins,'changes':changes,'note':'Apply these exact hunks after population30. Never replace peer full files.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Pose/props are private patched sources; daily/population remain hunks only.
    for rel in ['scripts/npc_ambient/ambient_pose28.gd','scripts/npc_ambient/ambient_props28.gd']:
        target=PATCH/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(projected[rel],encoding='utf-8')
    with Lease('headless',OUT/'native_project','write',30):
        fixture=OUT/'native_project';fixture.mkdir(exist_ok=True)
        (fixture/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Threat30 bounded native fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        queue=[p.relative_to(PATCH).as_posix() for p in PATCH.rglob('*.gd')];copied={}
        while queue:
            rel=queue.pop()
            if rel in copied:continue
            src=PATCH/rel if (PATCH/rel).exists() else SOURCE/rel
            content=src.read_text(encoding='utf-8-sig');dest=fixture/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(content,encoding='utf-8')
            copied[rel]=sha(dest)
            queue.extend(re.findall(r'res://([^"\s]+\.gd)',content))
        (OUT/'FIXTURE_SOURCE_PINS.json').write_text(json.dumps(copied,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'hunks':len(changes),'fixture_scripts':len(copied),'shared_game_written':False}))
