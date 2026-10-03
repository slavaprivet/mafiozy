"""Root-private C4 pose adapter on exact accepted48. No engine; fresh revisions only."""
from pathlib import Path
import argparse, difflib, hashlib, json, shutil, sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'outputs/coordinator27_release48/ASSEMBLY.json'
BASE_SHA = '513c9165b7f00be7e6cb8967470a5513e4d37e8fd8642f528d29ec36c08dd83c'
OWNER = ROOT / 'outputs/buildings3_c4_pose44'
PREFIX = 'scripts/destruction/palazzo/'

def sha(p):
    with Path(p).open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()

def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))

def replace(s, old, new):
    if s.count(old) != 1: raise RuntimeError('Ambiguous anchor: '+old[:100])
    return s.replace(old,new,1)

def write(p, data):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f: f.write(data if isinstance(data,bytes) else data.encode('utf-8'))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--stage',action='store_true');args=parser.parse_args()
    assert sha(BASE)==BASE_SHA
    base=read(BASE); source=Path(base['game']); pins=base['source_pins']; assert len(pins)==486
    assert all(sha(source/k)==h for k,h in pins.items())
    owner=read(OWNER/'MANIFEST.json')
    assert all(sha(OWNER/k)==h for k,h in owner['pins'].items())
    assert pins['scripts/preview_player.gd']==owner['base_player_sha256']
    assert pins[PREFIX+'c4_equipment.gd']=='11f9c4127d27a3349bc0e1242b3661fb9637e8f2bcd267217ade9db3c4e7cd29'
    before=(source/PREFIX/'c4_equipment.gd').read_text(encoding='utf-8-sig')
    eq=replace(before,'const Visuals45 =','const C4Pose44 = preload("c4_pose44.gd")\nconst Visuals45 =')
    eq=replace(eq,'var _elapsed := 0.0','var _elapsed := 0.0\nvar _presentation: RefCounted\nvar _last_placement_pose44: Dictionary={}\nvar _last_pose44_rejection := ""')
    eq=replace(eq,'\t_configured=true; process_priority=100; process_physics_priority=100','\t_presentation=C4Pose44.new()\n\tvar binding: Dictionary=_presentation.configure(actor)\n\tif not binding.get("ok",false):\n\t\tdispose(); return {"ok":false,"reason":"planting_pose_binding","detail":binding}\n\t_presentation.pose_applied.connect(_planting_pose_applied)\n\t_configured=true; process_priority=100; process_physics_priority=100')
    eq=replace(eq,'func _choose(mode: String) -> Dictionary:', 'func _planting_pose_applied(frame: Transform3D) -> void:\n\tif _current() and not _hold.is_empty() and _allowed() and frame.is_finite() and is_instance_valid(_held_root):\n\t\t_held_root.global_transform=frame\n\nfunc _choose(mode: String) -> Dictionary:')
    eq=replace(eq,'\t_hold=target; _hold.actor_position=', '\tvar admitted: Dictionary=_presentation.begin_hold()\n\tif not admitted.get("ok",false):\n\t\t_last_pose44_rejection=str(admitted.get("reason","pose_unavailable")); return\n\t_hold=target; _hold.pose_serial=admitted.request_serial; _hold.actor_position=')
    eq=replace(eq,'func _cancel_hold(show_notice: bool) -> void:\n','func _cancel_hold(show_notice: bool) -> void:\n\tif _presentation!=null: _presentation.cancel()\n')
    old='\t_elapsed+=delta\n\tif _elapsed>=HOLD_SECONDS:\n\t\t# Preserve the threshold frame for native committed-damage cancellation.\n\t\tif not _hold.has("completion_frame"): _hold.completion_frame=Engine.get_physics_frames()\n\t\telif Engine.get_physics_frames()>int(_hold.completion_frame): _place_charge()'
    new='\t# Consume the preceding final request after the real player writer, before replacing it.\n\tif _hold.has("completion_frame") and Engine.get_physics_frames()>int(_hold.completion_frame):\n\t\t_place_charge(); return\n\t_elapsed+=delta\n\tvar prepared: Dictionary=_presentation.prepare_hold(delta,minf(1,_elapsed/HOLD_SECONDS),_hold)\n\tif not prepared.get("ok",false): _reject_pose44(str(prepared.get("reason","pose_unavailable"))); return\n\tif _elapsed>=HOLD_SECONDS: _hold.completion_frame=Engine.get_physics_frames()'
    eq=replace(eq,old,new)
    eq=replace(eq,'func _place_charge() -> void:', 'func _reject_pose44(reason: String) -> void:\n\t_last_pose44_rejection=reason; _require_release=true\n\t_cancel_hold(true)\n\nfunc _place_charge() -> void:')
    eq=replace(eq,'\t_hold.point=current.point; _hold.normal=current.normal\n\t_sequence+=1','\t_hold.point=current.point; _hold.normal=current.normal\n\tvar completed: Dictionary=_presentation.consume_completion(_hold)\n\tif not completed.get("ok",false): _reject_pose44(str(completed.get("reason","post_writer_receipt_missing"))); return\n\t_last_placement_pose44=completed.duplicate(); _last_pose44_rejection=""\n\t_sequence+=1')
    eq=replace(eq,'\t\tvar socket: Transform3D=_rig.global_transform*_rig.get_bone_global_pose(_socket)\n\t\t_held_root.global_transform=Transform3D(socket.basis.orthonormalized(),socket.origin)','\t\tvar pose: Dictionary=_presentation.held_frame() if not _hold.is_empty() else {}\n\t\tif pose.get("ok",false): _held_root.global_transform=pose.frame\n\t\telse:\n\t\t\tvar socket: Transform3D=_rig.global_transform*_rig.get_bone_global_pose(_socket)\n\t\t\t_held_root.global_transform=Transform3D(socket.basis.orthonormalized(),socket.origin)')
    eq=replace(eq,'"hand_contact_animation":"pending_pose44_root_integration"','"hand_contact_animation":"private_native_bone_pose48_not_gpu_accepted","presentation":_presentation.snapshot() if _presentation!=null else {},"last_placement_pose44":_last_placement_pose44.duplicate(),"last_pose44_rejection":_last_pose44_rejection')
    eq=replace(eq,'\t_leave_mode(); _disposed=true;', '\t_leave_mode()\n\tif _presentation!=null: _presentation.dispose(); _presentation=null\n\t_disposed=true;')
    # Explicitly retain every current targeting/dispatch/shared-shape implementation.
    def function(s,name): return s.split('func '+name+'(',1)[1].split('\nfunc ',1)[0]
    preserved=['_allowed','_target','_owner_of_wall','_charge_current','_watch_charge_shape','_charge_shape_changed','_remove_charge','_detonate_all','consume_detonation','interrupt_for_damage']
    assert all(function(before,n)==function(eq,n) for n in preserved)
    patch={'scripts/preview_player.gd':(OWNER/'proposal/scripts/preview_player.gd').read_bytes(),PREFIX+'c4_equipment.gd':eq.encode('utf-8'),PREFIX+'c4_pose44.gd':(OWNER/'patch'/PREFIX/'c4_pose44.gd').read_bytes()}
    inherited=(OWNER/'patch'/PREFIX/'test_c4.gd').read_text(encoding='utf-8-sig')
    qa=inherited.split('func callback(',1)[0]+ 'func reacquire_wall('+inherited.split('func reacquire_wall(',1)[1].split('\nfunc await_generation(',1)[0]+'\n'
    qa=qa.replace('preload("c4_equipment.gd")','preload("res://'+PREFIX+'c4_equipment.gd")')
    # Base only supplies real viewport input, fixed cold setup/aim and observations.
    qa += '\nfunc run() -> void:\n\tpass\n\nfunc finish() -> void:\n\tpass\n'
    fixture=(OWNER/'patch'/PREFIX/'test_c4_pose44.gd').read_text(encoding='utf-8-sig').replace('extends "test_c4.gd"','extends "c4_base.gd"')
    fixture=fixture.replace('"source_author_started_engine":false','"adapter_native_headless":true')
    patch['tests/c4_pose48/c4_base.gd']=qa.encode('utf-8');patch['tests/c4_pose48/pose_test.gd']=fixture.encode('utf-8')
    if not args.stage:
        print(json.dumps({'status':'SOURCE_VERIFIED','base_pins':len(pins),'runtime_changed':2,'runtime_added':1,'qa_added':2,'preserved_functions':preserved}));return
    revision=HERE/'revision1';revision.mkdir(exist_ok=False)
    for k,v in patch.items():write(revision/'patch'/k,v)
    write(revision/'equipment.diff',''.join(difflib.unified_diff(before.splitlines(True),eq.splitlines(True),fromfile='accepted48/c4_equipment.gd',tofile='private/c4_equipment.gd')))
    write(revision/'player.diff',(OWNER/'proposal/root_player.diff').read_bytes())
    schedule=ROOT/'tools/godot/test_scheduler.py';assert sha(schedule)=='6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9'
    sys.path.insert(0,str(schedule.parent));from test_scheduler import Lease
    game=revision/'game'
    with Lease('headless',game,'write',wait_seconds=120):
        game.mkdir(exist_ok=False)
        for k,h in pins.items():write(game/k,patch.get(k,(source/k).read_bytes()))
        for k,v in patch.items():
            if k not in pins:write(game/k,v)
    result=dict(pins)
    for k,v in patch.items():result[k]=hashlib.sha256(v).hexdigest()
    manifest={'revision':'private-c4-pose48-r1','status':'STAGED_NOT_NATIVE_TESTED_NOT_PROMOTABLE','game':str(game),'base_assembly':str(BASE),'base_assembly_sha256':BASE_SHA,'base_source_pins':pins,'source_pins':result,'patch_pins':{k:result[k] for k in patch},'archive_manifest_sha256':sha(OWNER/'MANIFEST.json'),'archive_pins':owner['pins'],'preserved_current_equipment_functions':preserved,'production_promoted':False,'gpu_skin_accepted':False,'fullscene_perf_accepted':False,'compatibility_gate':'Any accepted48 target lost by arm reach blocks promotion; never relax reach/LOS/epoch/hand tolerances.'}
    write(revision/'ASSEMBLY.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'status':'STAGED','assembly':str(revision/'ASSEMBLY.json'),'sha256':sha(revision/'ASSEMBLY.json'),'pins':len(result)},ensure_ascii=False))

if __name__=='__main__':main()
