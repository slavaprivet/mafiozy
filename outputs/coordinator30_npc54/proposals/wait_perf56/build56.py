from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'outputs/coordinator30_release55/game'
changes=[]
def add(file,before,after):
    assert (BASE/file).read_text(encoding='utf-8-sig').count(before)==1,(file,before[:80])
    changes.append(dict(file=file,before=before,after=after))
daily='scripts/npc_city_daily.gd'
add(daily,'var _physical_peak_us30 := 0',
    'var _physical_peak_us30 := 0\nconst WaitCohort56=preload("res://scripts/city/runtime/npc_wait_cohort56.gd")\nvar _wait_cohort56: RefCounted=WaitCohort56.new()')
add(daily,'func wake_physical30(id: String) -> bool:\n\tif _disposed or not _physical_on30() or not _lives.has(id):return false',
    'func wake_physical30(id: String) -> bool:\n\tif _disposed or not _physical_on30() or not _lives.has(id):return false\n\t_wait_cohort56.forget(id)')
add(daily,'func forget_physical30(id: String, exact_life: RefCounted) -> bool:\n\tif not _physical_lives30.has(id):return true',
    'func forget_physical30(id: String, exact_life: RefCounted) -> bool:\n\t_wait_cohort56.forget(id,exact_life)\n\tif not _physical_lives30.has(id):return true')
add(daily,'\tvar started30: int=Time.get_ticks_usec();var frame30: int=Engine.get_physics_frames()\n\t# Bounded by the original288 resident catalogue. Never skip a moving body\'s',
    '\tvar started30: int=Time.get_ticks_usec();var frame30: int=Engine.get_physics_frames()\n'
    '\tvar now56: int=Time.get_ticks_msec()\n'
    '\tvar scene56: Node3D=_scene.get_ref() as Node3D if _scene!=null else null\n'
    '\tvar player56: Node3D=scene56.get("_player") as Node3D if is_instance_valid(scene56) else null\n'
    '\tvar camera56: Camera3D=scene56.get_viewport().get_camera_3d() if is_instance_valid(scene56) else null\n'
    '\tvar player_position56: Vector3=player56.global_position if is_instance_valid(player56) else Vector3.INF\n'
    '\tvar camera_position56: Vector3=camera56.global_position if is_instance_valid(camera56) else Vector3.INF\n'
    '\t_wait_cohort56.begin_frame()\n'
    '\t# Bounded by the original288 resident catalogue. Never skip a moving body\'s')
add(daily,'\t\tif life._frame!=frame30:\n\t\t\t_life_clock30(life)',
    '\t\tif life._frame!=frame30:\n'
    '\t\t\tif _wait_cohort56.skip(life,delta,frame30,now56,player_position56,camera_position56):continue\n'
    '\t\t\t_life_clock30(life)')
add(daily,'\t\t\tlife.step(delta);_physical_steps30+=1\n\t\t_physical_refresh30(id)',
    '\t\t\tlife.step(delta);_physical_steps30+=1\n'
    '\t\t_wait_cohort56.note_full(life,frame30,now56,player_position56,camera_position56)\n'
    '\t\t_physical_refresh30(id)')
add(daily,'"physical_delta_not_scaled":true}', '"physical_delta_not_scaled":true,"wait_cohort56":_wait_cohort56.snapshot()}')
# Cleanup on both orderly dispose and scene teardown, using their unique full statements.
for name in ['dispose','_retire_scene']:
    text=(BASE/daily).read_text(encoding='utf-8-sig');start=text.index('func '+name+'(')
    end=text.find('\nfunc ',start+5);block=text[start:end if end>=0 else len(text)]
    target='\t_physical_lives30.clear();_physical_ids30.clear();_physical_dirty30=false'
    assert block.count(target)==1
    add(daily,block,block.replace(target,target+'\n\t_wait_cohort56.clear()'))
add('scripts/hospital/npc_simple_hospital.gd','func step(delta: float) -> String:',
    '## Called only for a skipped stationary planning wait; no movement/arrival occurs.\n'
    'func wait_clock56(delta: float) -> void:\n'
    '\tif not _active or _attention_paused29 or not is_finite(delta) or delta<=0.0:return\n'
    '\t_replan_s+=delta\n'
    '\tif not _service_watch30.is_empty() and _guide!=null and _guide.status=="ready":\n'
    '\t\t_service_watch30.local_wait_ms=float(_service_watch30.local_wait_ms)+delta*1000.0\n\n'
    'func step(delta: float) -> String:')
files=sorted(set(c['file'] for c in changes))
helper=HERE/'patch/scripts/city/runtime/npc_wait_cohort56.gd'
spec={'schema':'wait_perf56/exact-hunks-v1','baseline':str(BASE),'changes':changes,'helpers':{'scripts/city/runtime/npc_wait_cohort56.gd':hashlib.sha256(helper.read_bytes()).hexdigest()},'baseline_sha256':{f:hashlib.sha256((BASE/f).read_bytes()).hexdigest() for f in files}}
(HERE/'PATCH56.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2),encoding='utf-8')
for f in files:
    text=(BASE/f).read_text(encoding='utf-8-sig')
    for c in changes:
        if c['file']==f:text=text.replace(c['before'],c['after'],1)
    dest=HERE/'patch'/f;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text,encoding='utf-8')
print(json.dumps({'hunks':len(changes),'files':files,'helper_sha256':spec['helpers']}))
