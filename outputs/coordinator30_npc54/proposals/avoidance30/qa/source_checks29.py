"""Source/ownership assertions; native semantic fixtures remain authoritative."""
from pathlib import Path
import hashlib,json,re,sys
OUT=Path(__file__).resolve().parents[1]
ROOT=OUT.parents[3]
sys.path.insert(0,str(OUT.parent/'navigation29/.tooling'))
from gdtoolkit.parser import parser
checks=[]
def check(name,value):
    checks.append({'name':name,'passed':bool(value)})
def function(text,name):
    match=re.search(r'^func '+re.escape(name)+r'\(.*?(?=^func |\Z)',text,re.M|re.S)
    return match.group(0) if match else ''
def apply(base,diff):
    rows=base.splitlines(keepends=True); out=[]; cursor=0; lines=diff.splitlines(keepends=True); i=2
    while i<len(lines):
        m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',lines[i]); assert m,lines[i]
        start=int(m[1])-1;out+=rows[cursor:start];cursor=start;i+=1
        while i<len(lines) and not lines[i].startswith('@@ '):
            op=lines[i][0]; content=lines[i][1:]
            if op in ' -':assert rows[cursor]==content;cursor+=1
            if op in ' +':out.append(content)
            i+=1
    return ''.join(out+rows[cursor:])
base=(OUT/'baseline/scripts/hospital/npc_simple_hospital.gd').read_text(encoding='utf-8')
candidate=(OUT/'scripts/hospital/npc_simple_hospital.gd').read_text(encoding='utf-8')
patch=(OUT/'patches/simple_avoidance29.patch').read_text(encoding='utf-8')
check('exact_simple_patch_roundtrip',apply(base,patch)==candidate)
for name in ['attention_pause29','attention_resume29','attention_hold29','cancel','_finish_step','_door_tick']:
    check('preserved_'+name,function(base,name)==function(candidate,name))
check('full_capsule_and_water_implementation_unchanged',hashlib.sha256((OUT/'baseline/scripts/hospital/npc_physical_route51.gd').read_bytes()).hexdigest()=='6cf3bb96c1ad9875fb3e66313db9b04a518043b4977e1db4420b316d8813b761')
check('live_movement_guard_retained','var ahead: Vector3=current+direction*minf(.4,remaining)' in candidate and '_route.move(direction,distance,delta)' in candidate)
pop=(OUT/'baseline/scripts/npc_city_population.gd').read_text(encoding='utf-8')
popnew=apply(pop,(OUT/'patches/population_snapshot29.patch').read_text(encoding='utf-8'))
check('known_scene_weakref','var _scene_ref: WeakRef' in pop and 'Avoidance29.refresh_scene(_scene_ref.get_ref() as Node3D)' in popnew)
check('snapshot_before_daily',popnew.index('Avoidance29.refresh_scene')<popnew.index('daily.step(delta)'))
world=(OUT/'scripts/navigation/npc_avoidance_world29.gd').read_text(encoding='utf-8')
check('only_readonly_venue_hint','registry.doorway_state29(actor)' in world and all(x not in world for x in ['portal_request(', 'portal_release(', 'release(', 'reject_path(', 'touch(']))
check('weak_body_and_shape_cache','entry.body=weakref(actor);entry.shape=weakref(shape)' in world)
check('life_generation_in_key',':life:' in world and 'entry.generation!=generation' in world)
core=(OUT/'scripts/navigation/npc_local_avoidance29.gd').read_text(encoding='utf-8')
check('no_crowd_sort','.sort' not in core)
check('hard_population_bound','rows.size()>MAX_ACTORS' in core and 'MAX_ACTORS := 384' in core)
check('no_physics_ownership_in_core',all(x not in core for x in ['CharacterBody3D','move_and_slide','collision_mask','intersect_shape','weakref']))
for f in list((OUT/'scripts').rglob('*.gd'))+list((OUT/'qa').glob('*.gd')):
    parser.parse(f.read_text(encoding='utf-8'));check('grammar_'+str(f.relative_to(OUT)),True)
parser.parse(popnew);check('population_patch_grammar',True)
report={'passed':all(x['passed'] for x in checks),'count':len(checks),'checks':checks,'native_not_implied':True}
(OUT/'CPU_CHECKS.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report));sys.exit(0 if report['passed'] else 1)
