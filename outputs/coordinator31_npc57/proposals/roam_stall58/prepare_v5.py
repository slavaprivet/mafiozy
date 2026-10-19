"""Create a new component harness; preserve all earlier diagnostic versions."""
from pathlib import Path
import hashlib

p = Path(__file__).resolve().parent
def write(name, text):
    target = p / name
    assert not target.exists(), name
    target.write_text(text, encoding='utf-8')

patch = p.parent / 'roam_recovery58/patch/scripts/hospital/npc_simple_hospital.gd'
data = patch.read_bytes()
assert hashlib.sha256(data).hexdigest() == 'd1ea18fbf1740f2b0b029a28bec4b91bccb3e3506ad693b48324c71a98c0106a'
assert not (p / 'candidate_driver58.gd').exists()
(p / 'candidate_driver58.gd').write_bytes(data)
write('entry_v5.gd', (p / 'entry_v4.gd').read_text().replace('fixture_v4.gd', 'fixture_v5.gd'))
s = (p / 'fixture_v4.gd').read_text()
s = s.replace('const Drive=preload("res://scripts/hospital/npc_simple_hospital.gd")', 'var Drive:Script=preload("res://scripts/hospital/npc_simple_hospital.gd")\nvar insert_obstacle:=false\nvar obstacle_added:=false\nvar obstacle_record:Dictionary={}\nvar candidate_driver:=false')
s = s.replace('if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")', 'if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")\n\t\tif arg=="--qa-candidate-driver":candidate_driver=true;Drive=load(get_script().resource_path.get_base_dir().path_join("candidate_driver58.gd"))\n\t\tif arg=="--qa-insert-obstacle":insert_obstacle=true')
s = s.replace('var after:Vector3=actor.global_position', '''var after:Vector3=actor.global_position
	if insert_obstacle and not obstacle_added and drive._route.status=="ready":
		# Explicit component perturbation: a new physical world obstacle occludes
		# accepted waypoint5. No actor transform/force/route/goal is written.
		var box:=StaticBody3D.new();box.name="QA_StaleWaypointObstacle58"
		box.collision_layer=1;box.collision_mask=1
		var shape:=CollisionShape3D.new();var box_shape:=BoxShape3D.new()
		box_shape.size=Vector3(1.6,1.4,.6);shape.shape=box_shape;box.add_child(shape)
		scene.add_child(box);box.global_position=Vector3(135.018569946289,1.0,.296825021505356)
		obstacle_added=true
		obstacle_record={"frame":Engine.get_physics_frames(),"position":v(box.global_position),"size":v(box_shape.size),"layer":1,"mask":1,"path":str(box.get_path()),"accepted_route_ready_frame":drive._route._ready_frame}
		print("ROAM58_OBSTACLE_ADDED ",JSON.stringify(obstacle_record))''')
s = s.replace('"result":result,"drive_phase":drive._phase,"attempts":drive._attempts,', '"result":result,"drive_phase":drive._phase,"attempts":drive._attempts,"last_reason":drive._last_reason,"final_target":v(drive._target),')
s = s.replace('"schema":"mafiozi.roam58.native-diagnostic/v1"', '"schema":"mafiozi.roam58.native-diagnostic/v2","candidate_driver":candidate_driver,"controlled_new_obstacle":obstacle_record,"natural_failure_reproduction_claimed":false')
write('fixture_v5.gd', s)
s = (p / 'run_native58_v4.py').read_text()
s = s.replace("p.add_argument('name');a=p.parse_args()", "p.add_argument('name');p.add_argument('--candidate',action='store_true');p.add_argument('--obstacle',action='store_true');a=p.parse_args()")
s = s.replace("['entry_v4.gd','fixture_v4.gd','run_native58_v4.py','snapshot_adapter58_v4.gd']", "['entry_v5.gd','fixture_v5.gd','run_native58_v5.py','snapshot_adapter58_v4.gd','candidate_driver58.gd']")
s = s.replace("str(OUT/'entry_v4.gd')", "str(OUT/'entry_v5.gd')")
s = s.replace("record={'passed':False", "command += (['--qa-candidate-driver'] if a.candidate else []) + (['--qa-insert-obstacle'] if a.obstacle else [])\n    record={'candidate_driver':a.candidate,'controlled_obstacle':a.obstacle,'passed':False")
write('run_native58_v5.py', s)
print('v5 prepared; frozen v4 unchanged')
