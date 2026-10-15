"""Create small new QA adapters only; preserve shop01/shop02 and production."""
from pathlib import Path
import hashlib, json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
OLD=HERE.parent/'service_threat31_extended'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(text, old, new):
    assert text.count(old)==1, old
    return text.replace(old,new,1)

def main():
    inputs={name:sha(OLD/name) for name in ['observer31.gd','observer_base31.gd','entry31.gd','run31.py']}
    assert inputs['observer31.gd']=='2dfb47b77addad9cbc6a78fb6959d38f5a8dd0dcac5fab52131ea645d7e27329'
    observer=(OLD/'observer31.gd').read_text(encoding='utf-8-sig')
    observer=replace(observer,'extends "observer_base31.gd"','extends "observer_base58.gd"')
    observer=replace(observer,'var shot_direction30:=Vector3.ZERO','var shot_direction30:=Vector3.ZERO\nvar miss_checks58:Dictionary={}\nvar fire_sent58:Dictionary={}')
    observer=observer.replace('Vector3(0,.7,-1).normalized()','Vector3(0,-.15,-1).normalized()')
    observer=replace(observer,'shot_direction30=(outward+Vector3.UP*.6).normalized()','shot_direction30=(outward-Vector3.UP*.15).normalized()')
    observer=replace(observer,'func _receipts30()->Array:', '''func _actor_hit58(collider:Variant)->bool:
	if not is_instance_valid(collider):return false
	# Character bodies cover staff and the live residents' physical capsules.
	if collider is CharacterBody3D:return collider!=_player
	for owner:RefCounted in _pop.hit_owners:
		if is_instance_valid(owner) and owner._owns_collider(collider):return true
	return false

func _terminal(receipt:Dictionary)->void:
	super._terminal(receipt)
	if _actor_hit58(receipt.get("collider")):violations30.append("native_miss_hit_actor")

func _miss_rays58()->bool:
	var muzzle:Dictionary=_weapons.presentation.current_muzzle()
	miss_checks58={"muzzle_ok":muzzle.get("ok",false),"frame":Engine.get_physics_frames()}
	if not muzzle.get("ok",false):return false
	var direction:Vector3=-_camera.global_basis.z
	var camera_hit:Dictionary=_weapons._projectile_ray({"origin":_camera.global_position,"direction":direction,"range":100.0})
	var aim_point:Vector3=camera_hit.get("point",_camera.global_position+direction*100.0)
	var along:Vector3=(aim_point-muzzle.origin).normalized()
	var muzzle_hit:Dictionary=_weapons._projectile_ray({"origin":muzzle.origin,"direction":along,"range":100.0})
	miss_checks58.merge({"camera_misses_actors":not _actor_hit58(camera_hit.get("collider")),"muzzle_misses_actors":not _actor_hit58(muzzle_hit.get("collider")),"camera_hit":str(camera_hit.get("collider")),"muzzle_hit":str(muzzle_hit.get("collider"))})
	return miss_checks58.camera_misses_actors and miss_checks58.muzzle_misses_actors

func _input_diagnostic58()->Dictionary:
	var limits:Vector2=_weapons.aim_camera.pitch_limits()
	return {"fired":_fired,"stable":_stable,"owner_current":_weapons._owner_current(),"pose_authority":str(_player._pose_authority),"free_mouse":_player._free_mouse_look,"muzzle":_weapons.presentation.current_muzzle(),"weapon":_weapons.fire_state.duplicate(true),"aim_error":(-_camera.global_basis.z).angle_to(shot_direction30) if shot_direction30.length_squared()>.5 else -1.0,"requested_pitch":asin(shot_direction30.y),"actual_pitch":_player._camera_pitch,"live_pitch_limits":limits,"aiming":_weapons._aiming,"miss_rays":miss_checks58.duplicate(true),"fire_sent":fire_sent58.duplicate(true)}

func _receipts30()->Array:''')
    observer=replace(observer,'\t\t_stable=_stable+1 if _look30(shot_direction30) else 0\n\t\tif _fired==0 and _stable>=5 and _weapons.presentation.current_muzzle().get("ok",false):_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired=1', '''		_stable=_stable+1 if _look30(shot_direction30) and _miss_rays58() else 0
		if _fired==0 and _stable>=5:
			if not service or not receipts.is_empty() or int(_life._account.snapshot().account.cash)!=cash30:
				_finish("qa_calibration_missed_unpaid_service_window");return
			fire_sent58={"frame":Engine.get_physics_frames(),"ms":now-_ready_ms,"service":service,"cash":cash30,"receipt_count":receipts.size(),"pitch":_player._camera_pitch,"miss_rays":miss_checks58.duplicate(true)}
			checks30.native_fire_inside_unpaid_service=true
			_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired=1''')
    old_diag='"input_diagnostic":{"fired":_fired,"stable":_stable,"owner_current":_weapons._owner_current(),"pose_authority":str(_player._pose_authority),"free_mouse":_player._free_mouse_look,"muzzle":_weapons.presentation.current_muzzle(),"weapon":_weapons.fire_state,"aim_error":(-_camera.global_basis.z).angle_to(shot_direction30) if shot_direction30.length_squared()>.5 else -1.0}'
    observer=replace(observer,old_diag,'"input_diagnostic":_input_diagnostic58()')
    observer=replace(observer,'required.append("population_preserved");required.append("other_nine_moved")','required.append("population_preserved");required.append("other_nine_moved")\n\tchecks30.single_native_miss=_shots.size()==1 and not _terminals.is_empty() and not _terminals.any(func(t:Dictionary)->bool:return t.owned)\n\trequired.append("single_native_miss");required.append("native_fire_inside_unpaid_service")')
    observer=replace(observer,'"performance_accepted":false}', '"performance_accepted":false,"fire_sent58":fire_sent58,"qa_calibration58":"reachable downward outward miss; native camera and muzzle actor guards"}')
    observer=observer.replace('SERVICE_THREAT31.json','SERVICE_THREAT58.json').replace('SERVICE_THREAT31_FINISH','SERVICE_THREAT58_FINISH')
    outputs={'observer58.gd':observer.encode('utf-8'),'observer_base58.gd':(OLD/'observer_base31.gd').read_bytes(),
             'entry58.gd':(OLD/'entry31.gd').read_bytes().replace(b'observer31.gd',b'observer58.gd')}
    for name,data in outputs.items():
        path=HERE/name
        assert not path.exists(), 'Preserve prior adapter'
        path.write_bytes(data)
    assert all(sha(OLD/name)==digest for name,digest in inputs.items())
    (HERE/'PREPARATION58.json').write_text(json.dumps({'status':'PREPARED_NOT_NATIVE_TESTED','old_input_pins':inputs,'new_output_pins':{name:sha(HERE/name) for name in outputs},'game_copied':False,'production_modified':False,'old_harness_changed':False,'engine_started':False},indent=2)+'\n',encoding='utf-8')
    print('Prepared3 small GDScript files; no engine/source changes.')

if __name__=='__main__':main()
