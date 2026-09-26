extends SceneTree
## Independent runtime checks against executed JavaScript source, not Dive helpers.
const Player = preload("res://scripts/preview_player.gd")
const Dive = preload("res://scripts/preview_dive.gd")
const SOURCE_ORACLE_JS = """
import {pathToFileURL} from 'node:url';
import {join} from 'node:path';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const root=process.argv[1];
const jump=await import(pathToFileURL(join(root,'hero_jump.mjs')));
const surface=await import(pathToFileURL(join(root,'surface_motion.mjs')));
function frames(kind, deltas){
 let s={...jump.launchJump({x:0,z:0},kind==='ceiling'?{x:0,z:0}:{x:1,z:0},{startedAt:1000}),baseY:0},y=0,motion=null,rows=[];
 const floor=x=>kind==='edge'&&x>.6?-10:0;
 for(let frame=0;frame<deltas.length;frame++){
  const dt=deltas[frame];
  if(kind==='delayed'&&frame===6)s=jump.tryDiveJump(s,{x:1,z:0},1100);
  if(motion){const r=motion.update({x:s.x,z:s.z,dt,floorHeight:floor});y=r.y;rows.push({y,velocity:r.velocityY,grounded:r.grounded,after:true});continue;}
  if(Number.isFinite(dt)&&dt>0&&dt<=1){
   let remaining=Math.min(dt,.25);
   for(let sub=0;sub<7&&remaining>1e-9;sub++){
    const d=Math.min(.04,remaining);remaining-=d;
    s=jump.stepJump(s,d,()=>true);
    s=surface.resolveJumpSurface(s,{floor:floor(s.x),ceiling:kind==='ceiling'?2.4:Infinity,bodyHeight:1.9,previousY:y,dt:d});y=s.worldY;
    if(s.done){motion=surface.createSurfaceMotion();motion.reset({x:s.x,y,z:s.z},{grounded:y<=floor(s.x)+.02,velocityY:s.falling?s.fallVelocity:0});break;}
   }
  }
  rows.push({x:s.x,y,elapsed:s.elapsed,progress:s.progress,blend:s.diveBlend??0,falling:!!s.falling,ceilingHit:!!s.ceilingHit,velocity:s.fallVelocity??0,done:s.done,after:false});
 }
 return rows;
}
const clock=[.03,.2,.35,1.001,0,-.1,.1,.25];
const cases={normal:frames('normal',Array(75).fill(1/60)),delayed:frames('delayed',Array(75).fill(1/60)),ceiling:frames('ceiling',Array(100).fill(1/60)),edge:frames('edge',[...Array(77).fill(1/60),.2,...Array(90).fill(1/60)]),clock:frames('clock',clock)};
// Independent analytic user design. Does not import the Godot runtime profile.
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x)};
function cinematicY(t,t0=.1){
 if(t<=t0)return 4*1.05*(t/.8)*(1-t/.8);
 if(t>=1.25)return 0;
 const y0=4*1.05*(t0/.8)*(1-t0/.8),v0=5.25*(1-2*t0/.8),H=Math.max(y0,.82+.23*smooth(t0/.2));
 const ascent=3*(H-y0)/v0,age=t-t0;
 if(age<=ascent){const u=age/ascent;return y0+v0*ascent*(u-u*u+u*u*u/3)}
 const u=(age-ascent)/(1.25-t0-ascent);return H*(2*u*u*u-3*u*u+1);
}
cases.cinematic=Array.from({length:130},(_,i)=>{const t=(i+1)/60;return {elapsed:t,y:cinematicY(t),x:3.5*Math.min(t,.1)+4.2*Math.max(0,Math.min(t,1.25)-.1)}});
const hashes={};for(const f of ['hero_jump.mjs','surface_motion.mjs','walk_preview.mjs','hero_walk.mjs'])hashes[f]=createHash('sha256').update(readFileSync(join(root,f))).digest('hex');
console.log(JSON.stringify({cases,hashes,clock}));
"""
var _player: Player
var _world: Node3D
var _floor: StaticBody3D
var _rig: Skeleton3D
var _rest: Array[Transform3D] = []
var _head_rest: Quaternion
var _oracle: Dictionary
var _errors: Array[String] = []
var _checks: int = 0
var _player_sha: String
var _dive_sha: String
var _metrics: Dictionary = {}
var _max_visual_q_error: float = 0.0
var _max_bone_q_error: float = 0.0
var _max_head_q_error: float = 0.0
var _max_clock_error: float = 0.0
var _skin_geometry: Array[Dictionary] = []
var _skin_min_error: float = 0.0
var _skin_samples: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_player_sha = FileAccess.get_sha256("res://scripts/preview_player.gd")
	_dive_sha = FileAccess.get_sha256("res://scripts/preview_dive.gd")
	var output: Array = []
	var code: int = OS.execute("node", ["--input-type=module", "--eval", SOURCE_ORACLE_JS, ProjectSettings.globalize_path("res://../../assets/maps/city_rebuild_v1")], output, true)
	_check(code == 0 and not output.is_empty(), "actual JavaScript source oracle executes")
	if code != 0 or output.is_empty():
		_finish()
		return
	var parsed: Variant = JSON.parse_string(str(output[0]))
	_check(parsed is Dictionary and parsed.has("cases"), "source oracle JSON contains trajectories")
	if not parsed is Dictionary:
		_finish()
		return
	_oracle = parsed
	_world = Node3D.new()
	root.add_child(_world)
	_floor = _box(Vector3(0,-.5,0), Vector3(100,1,100))
	_player = Player.new()
	_world.add_child(_player)
	_rig = _player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i: int in range(_rig.get_bone_count()):
		_rest.append(_rig.get_bone_pose(i))
	var motion: Node3D = _player.get_node("VisualHeading/LocomotionOffset")
	_head_rest = (motion.global_transform.affine_inverse() * _rig.global_transform * _rig.get_bone_global_pose(_rig.find_bone("head"))).basis.get_rotation_quaternion()
	_collect_skin()
	await _reset()
	# Keep the source proposal profile as an explicit baseline after the user
	# requested a separate, longer cinematic runtime dive.
	var pure: Dictionary = {"elapsed":0.0,"startedAt":1000.0,"mode":"normal","direction":Vector2.RIGHT}
	var pure_x: float = 0.0
	var pure_error: float = 0.0
	for frame: int in range(75):
		if frame == 6:
			pure = Dive.upgrade(pure,Vector2.RIGHT,1100.0)
		var step: Dictionary = Dive.proposal(pure,1.0/60.0)
		pure.merge(step,true)
		pure_x += float(step.travel)
		var expected: Dictionary = _oracle.cases.delayed[frame]
		pure_error = maxf(pure_error,absf(pure_x-float(expected.x)))
		pure_error = maxf(pure_error,absf(float(step.arc_y)-float(expected.y)))
	_check(pure_error < .00001,"pure source profile remains equal to executed hero_jump baseline")
	_metrics["pure_source_proposal_max_error"] = pure_error
	Input.action_press(_player.ACTION_RIGHT)
	_space(true)
	_space(false)
	var ordinary_error: float = 0.0
	for frame: int in range(75):
		await _frame()
		var expected: Dictionary = _oracle.cases.normal[frame]
		ordinary_error = maxf(ordinary_error,absf(_player.position.x-float(expected.x)))
		ordinary_error = maxf(ordinary_error,absf(_player.position.y-float(expected.y)))
	_check(ordinary_error < .005,"ordinary runtime jump remains equal to executed source")
	_metrics["ordinary_source_position_max_error_m"] = ordinary_error
	# Eight actual physics/event runs at a non-cardinal camera yaw. The authored
	# bank and final gaze are recomputed directly from hero_walk coefficients.
	var cinematic_rows: Array = []
	for axes: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
		await _reset()
		_player.set("_camera_yaw", .37)
		_player.set("_camera_pitch", .24)
		_player.call("_update_camera_rotation")
		_direction(axes)
		var start: Vector3 = _player.global_position
		_space(true)
		_space(false)
		var expected_dir: Vector2 = Vector2(axes.x*cos(.37)+axes.y*sin(.37), -axes.x*sin(.37)+axes.y*cos(.37)).normalized()
		_check((_player.get("_jump") as Dictionary).direction.distance_to(expected_dir) < .00001, "input direction follows non-cardinal camera without diagonal boost")
		var max_y_error: float = 0.0
		var max_elapsed_error: float = 0.0
		var pose_frames: int = 0
		var max_height: float = 0.0
		var first_floor_frame: int = -1
		var hold_frames: int = 0
		var hold_error: float = 0.0
		var premature_recovery: Array = []
		for frame: int in range(130):
			if frame == 6:
				var elapsed: float = (_player.get("_jump") as Dictionary).elapsed
				_space(true)
				_space(false)
				_check((_player.get("_jump") as Dictionary).mode == "dive" and (_player.get("_jump") as Dictionary).elapsed == elapsed, "actual second press changes mode without resetting elapsed")
			await _frame()
			var state: Dictionary = _player.get("_jump_pose")
			var expected: Dictionary = _oracle.cases.cinematic[frame]
			if state.is_empty():
				_check(frame >= 100 and frame <= 105,"cinematic source pose completes after 1.25s flight and .45s recovery")
				break
			pose_frames += 1
			max_height = maxf(max_height,_player.position.y)
			if frame > 10 and _player.is_on_floor() and first_floor_frame < 0:
				first_floor_frame = frame
			if float(state.elapsed) >= .95 and first_floor_frame < 0:
				hold_frames += 1
				hold_error = maxf(hold_error,absf(float(state.progress)-.72))
				if absf(float(state.progress)-.72) >= .00001:
					premature_recovery.append({"frame":frame,"elapsed":state.elapsed,"progress":state.progress,"contact_elapsed":state.get("contact_elapsed",-1.0),"body_y":_player.position.y,"is_on_floor":_player.is_on_floor()})
			max_y_error = maxf(max_y_error, absf(_player.position.y - float(expected.y)))
			if frame < 74:
				max_elapsed_error = maxf(max_elapsed_error, absf(float(state.elapsed) - float(expected.elapsed)))
			_verify_pose(state)
			if frame in [0,6,12,24,40,60,74]:
				_verify_skin_floor()
			if (_player.get("_jump") as Dictionary).is_empty():
				_release() # Do not include a subsequent grounded walking step.
		_release()
		var actual: Vector2 = Vector2(_player.position.x-start.x,_player.position.z-start.z)
		cinematic_rows.append({"axes":[axes.x,axes.y],"distance_m":actual.length(),"apex_m":max_height,"first_floor_frame":first_floor_frame,"pose_frames":pose_frames,"path_max_error_m":max_y_error,"hold_frames":hold_frames,"premature_recovery":premature_recovery})
		_check(actual.distance_to(expected_dir*5.18) < .01, "non-cardinal eight-direction delayed-dive distance matches user profile 5.18m")
		_check(max_y_error < .005 and max_elapsed_error < .00001, "real cinematic physics agrees with independent continuous analytic path")
		_check(first_floor_frame >= 72 and first_floor_frame <= 75 and max_height > .93 and max_height < .94,"delayed cinematic apex and actual 1.25s landing meet profile")
		_check(pose_frames >= 100 and pose_frames <= 105,"cinematic recovery remains bounded")
		_check(hold_frames >= 12 and hold_error < .00001,"side contact pose waits for actual floor before standing recovery")
		_check(_qerror(motion.quaternion, Quaternion.IDENTITY) < .00001, "actual final visual rotation upright")
		_max_clock_error = maxf(_max_clock_error, max_elapsed_error)
	_metrics["cinematic_eight_direction_runs"] = cinematic_rows
	_check(_max_visual_q_error < .00001, "all actual applied visual quaternions match independent source coefficient composition")
	_check(_max_bone_q_error < .00001, "actual chest/limb quaternions match independent source local rotations")
	_check(_max_head_q_error < .00001, "actual world head orientation follows source gaze across all travel directions")
	_check(_skin_min_error < .001, "actual complete imported skin minimum lies on source body foot plane")
	# Mixed elapsed time uses actual sourceJS updateJump substeps/caps, then body
	# sweeps. Not a call to the production frame_steps/proposal implementation.
	await _reset()
	_player.set_physics_process(false)
	Input.action_press(_player.ACTION_RIGHT)
	_player.call("_request_preview_jump", 1000.0)
	var clock_error: float = 0.0
	for i: int in range(_oracle.clock.size()):
		_player.call("_physics_process", float(_oracle.clock[i]))
		var actual_state: Dictionary = _player.get("_jump")
		var expected: Dictionary = _oracle.cases.clock[i]
		clock_error = maxf(clock_error, absf(float(actual_state.elapsed)-float(expected.elapsed)))
		_check(absf(_player.position.x-float(expected.x)) < .005 and absf(_player.position.y-float(expected.y)) < .005, "mixed visible clock actual displacement agrees with source")
	_check(clock_error < .00001, "mixed clock caps .25 and discards invalid/long gap without debt")
	# Upgrade on the descending side: preserve the existing downward velocity,
	# never bounce upward just to reach the longer profile's usual apex.
	await _reset()
	_player.set_physics_process(false)
	Input.action_press(_player.ACTION_RIGHT)
	_player.call("_request_preview_jump",1000.0)
	for i: int in range(49):
		_player.call("_physics_process",.01)
	var descending_start: Vector3 = _player.position
	var descending_elapsed: float = (_player.get("_jump") as Dictionary).elapsed
	var descending_y: float = 4.0*1.05*(.49/.8)*(1.0-.49/.8)
	var descending_v: float = 5.25*(1.0-2.0*.49/.8)
	_player.call("_request_preview_jump",1490.0)
	_check(_player.position == descending_start and absf(float((_player.get("_jump") as Dictionary).elapsed)-descending_elapsed) < .000001,"late descending upgrade has no position or elapsed discontinuity")
	var descending_error: float = 0.0
	var descending_rise: float = 0.0
	var previous_y: float = _player.position.y
	for i: int in range(76):
		_player.call("_physics_process",.01)
		var u: float = float(i+1)/76.0
		var expected_y: float = (2.0*u*u*u-3.0*u*u+1.0)*descending_y+(u*u*u-2.0*u*u+u)*.76*descending_v
		descending_error = maxf(descending_error,absf(_player.position.y-expected_y))
		descending_rise = maxf(descending_rise,_player.position.y-previous_y)
		previous_y = _player.position.y
	_check(descending_error < .005 and descending_rise < .00001,"descending upgrade follows independent C1 continuation without a second upward impulse")
	_metrics["descending_upgrade_path_max_error_m"] = descending_error
	_metrics["descending_upgrade_max_upward_step_m"] = descending_rise
	# Low ceiling with real physical collider: source reserve is exactly .04m.
	await _reset()
	var ceiling: StaticBody3D = _box(Vector3(0,2.45,0), Vector3(20,.1,20))
	await _frames(3)
	_space(true)
	_space(false)
	var ceiling_error: float = 0.0
	var ceiling_seen: bool = false
	for frame: int in range(70):
		await _frame()
		var expected: Dictionary = _oracle.cases.ceiling[frame]
		ceiling_error = maxf(ceiling_error, absf(_player.position.y-float(expected.y)))
		var state: Dictionary = _player.get("_jump_pose")
		if not state.is_empty():
			ceiling_seen = ceiling_seen or bool(state.ceilingHit)
	_check(ceiling_seen and ceiling_error < .005, "actual .04m ceiling reserve and immediate gravity18 follow source oracle")
	ceiling.free()
	_metrics["ceiling_max_position_error_m"] = ceiling_error
	# Ownership/capture edge cases: no movement/pose writer after handoff;
	# visible focus loss releases controls but does not create hidden-time debt.
	await _reset()
	_space(true)
	_space(false)
	await _frames(6)
	_space(true)
	_space(false)
	await _frames(8)
	_player.set_preview_pose_authority(&"vehicle")
	var held: Transform3D = _player.transform
	var epoch: int = _player.get_preview_status().pose_epoch
	var bones: Array[Transform3D] = _capture()
	var visual: Transform3D = motion.transform
	await _frames(10)
	_check(_player.transform == held and _capture() == bones and motion.transform == visual, "external authority receives stable body and pose without later writer")
	_check((_player.get("_jump") as Dictionary).is_empty() and (_player.get("_jump_pose") as Dictionary).is_empty(), "handoff cancels trajectory and pending pose")
	_player.set_preview_pose_authority(&"on_foot", true)
	_check(_player.get_preview_status().pose_epoch == epoch+1, "new actor lifetime changes sampler epoch")
	await _reset()
	_space(true)
	_space(false)
	await _frames(3)
	var age: float = (_player.get("_jump") as Dictionary).elapsed
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(3)
	_check(float((_player.get("_jump") as Dictionary).elapsed) > age and not _player.get_preview_status().free_mouse_look, "visible unfocused jump continues while pointer capture releases")
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	# Physical edge: exact executed source fall, including post-flight .2s call
	# where createSurfaceMotion clamps dt to .1. Any mismatch is a real finding.
	await _reset()
	_floor.free()
	_box(Vector3(0,-.5,0), Vector3(1.2,1,10))
	_box(Vector3(4,-10.5,0), Vector3(20,1,20))
	await _frames(3)
	_player.set_physics_process(false)
	Input.action_press(_player.ACTION_RIGHT)
	_player.call("_request_preview_jump", 1000.0)
	var edge_error: float = 0.0
	var post_gap_error: float = 0.0
	var before_gap_error: float = 0.0
	var edge_trace: Array = []
	for frame: int in range(_oracle.cases.edge.size()):
		if (_player.get("_jump") as Dictionary).is_empty():
			_release()
		var dt: float = .2 if frame == 77 else 1.0/60.0
		_player.call("_physics_process", dt)
		var expected: Dictionary = _oracle.cases.edge[frame]
		edge_error = maxf(edge_error, absf(_player.position.y-float(expected.y)))
		if frame < 77:
			before_gap_error = maxf(before_gap_error, absf(_player.position.y-float(expected.y)))
		if frame >= 74 and frame <= 80:
			edge_trace.append({"frame":frame,"dt":dt,"actual_y":_player.position.y,"source_y":expected.y,"actual_velocity":_player.velocity.y,"source_velocity":expected.velocity})
		if frame == 76:
			var hidden_position: Vector3 = _player.position
			var hidden_velocity: Vector3 = _player.velocity
			_player.set("_jump_physics_visible",false)
			_player.call("_physics_process",.25)
			_check(_player.position == hidden_position and _player.velocity == hidden_velocity,"continued source fall honors explicit hidden-clock gate without debt")
			_player.set("_jump_physics_visible",true)
		if frame == 77:
			post_gap_error = absf(_player.position.y-float(expected.y))
	_metrics["edge_max_position_error_m"] = edge_error
	_metrics["postflight_long_step_error_m"] = post_gap_error
	_metrics["edge_before_long_step_error_m"] = before_gap_error
	_metrics["edge_trace"] = edge_trace
	_check(edge_error < .01, "edge fall and post-flight gravity18/time cap agree with executed surface_motion")
	_check(_player.is_on_floor() and absf(_player.position.y+10) < .01, "real lower floor catches fall")
	_check(FileAccess.get_sha256("res://scripts/preview_player.gd") == _player_sha and FileAccess.get_sha256("res://scripts/preview_dive.gd") == _dive_sha, "reviewed production sources frozen during final run")
	_finish()

func _verify_pose(state: Dictionary) -> void:
	var p: float = state.progress
	var dive: float = state.diveBlend
	var launch: float = _smooth(p/.14)
	var normal_recover: float = _smooth((p-.64)/.36)
	var dive_recover: float = _smooth((p-.72)/.28)
	var air: float = launch*(1.0-lerpf(normal_recover,dive_recover,dive))
	var landing: float = _smooth((p-.5)/.14)*(1.0-_smooth((p-.72)/.28))
	var direction: Vector2 = state.direction
	var aim_yaw: float = float(_player.get("_camera_yaw"))+PI
	var travel_yaw: float = atan2(direction.x,direction.y)
	var relative: float = travel_yaw-aim_yaw
	var tilt: float = dive*launch*(1.0-dive_recover)*(1.2+.33*_smooth((p-.46)/.18))
	var visual: Node3D = _player.get_node("VisualHeading")
	var expected: Quaternion = Quaternion(Vector3.UP,aim_yaw-visual.global_rotation.y)*Quaternion(Vector3(cos(relative),0,-sin(relative)),tilt)
	_max_visual_q_error = maxf(_max_visual_q_error,_qerror(_player.get_node("VisualHeading/LocomotionOffset").quaternion,expected))
	_bone("chest",landing*(.35-.13*dive))
	for side: String in ["l","r"]:
		_bone("thigh_"+side,-air*(.65-.45*dive)-landing*(.8-.58*dive))
		_bone("shin_"+side,air*(.8-.4*dive)+landing*(.85-.55*dive))
		_bone("foot_"+side,-air*.14-landing*.15)
		_bone("upperarm_"+side,-air*(.65+.8*dive),(1.0 if side=="l" else -1.0)*air*.15)
		_bone("forearm_"+side,-air*(.8-.45*dive))
	var head_world: Quaternion = (_rig.global_transform*_rig.get_bone_global_pose(_rig.find_bone("head"))).basis.get_rotation_quaternion()
	var target: Quaternion = Quaternion(Vector3.UP,aim_yaw)*Quaternion(Vector3.RIGHT,-clampf(float(_player.get("_camera_pitch")),-1.28,1.28))*_head_rest
	_max_head_q_error = maxf(_max_head_q_error,_qerror(head_world,target))

func _bone(name_value: String, x: float, z: float = 0.0) -> void:
	var bone: int = _rig.find_bone(name_value)
	var expected: Quaternion = _rest[bone].basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,x)*Quaternion(Vector3.BACK,z)
	_max_bone_q_error = maxf(_max_bone_q_error,_qerror(_rig.get_bone_pose_rotation(bone),expected))

func _qerror(a: Quaternion,b: Quaternion) -> float:
	return absf(1.0-absf(a.normalized().dot(b.normalized())))

func _collect_skin() -> void:
	var count: int = 0
	for node: Node in _player.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin == null: continue
		var binds: Array[Transform3D] = []
		var ids := PackedInt32Array()
		for at: int in range(mesh.skin.get_bind_count()):
			ids.append(_rig.find_bone(str(mesh.skin.get_bind_name(at))))
			binds.append(mesh.skin.get_bind_pose(at))
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			count += arrays[Mesh.ARRAY_VERTEX].size()
			_skin_geometry.append({"positions":arrays[Mesh.ARRAY_VERTEX],"joints":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS],"binds":binds,"ids":ids})
	_check(count == 8338,"independent support check covers all 8338 imported skin vertices")
	_metrics["full_skin_vertices"] = count

func _verify_skin_floor() -> void:
	var bones: Array[Transform3D] = []
	for bone: int in range(_rig.get_bone_count()):
		bones.append(_rig.get_bone_global_pose(bone))
	var minimum: float = INF
	for mesh: Dictionary in _skin_geometry:
		for vertex: int in range(mesh.positions.size()):
			var point := Vector3.ZERO
			for influence: int in range(4):
				var at: int = vertex*4+influence
				var weight: float = mesh.weights[at]
				if weight <= 0.0: continue
				var bind: int = mesh.joints[at]
				point += (bones[mesh.ids[bind]] * mesh.binds[bind] * mesh.positions[vertex])*weight
			minimum = minf(minimum, (_rig.global_transform*point).y-_player.global_position.y)
	_skin_min_error = maxf(_skin_min_error,absf(minimum))
	_skin_samples += 1

func _smooth(value: float) -> float:
	var t: float = clampf(value,0,1)
	return t*t*(3.0-2.0*t)

func _reset() -> void:
	_release()
	_space(false)
	_player.set_preview_pose_authority(&"on_foot",true)
	_player.global_position = Vector3(0,.02,0)
	_player.set("_camera_yaw",0.0)
	_player.set("_camera_pitch",0.0)
	_player.set("_jump_physics_visible",true)
	_player.set_mouse_captured(true)
	_player.set_physics_process(true)
	await _frames(12)

func _direction(axes: Vector2) -> void:
	if axes.x < 0: Input.action_press(_player.ACTION_LEFT)
	if axes.x > 0: Input.action_press(_player.ACTION_RIGHT)
	if axes.y < 0: Input.action_press(_player.ACTION_FORWARD)
	if axes.y > 0: Input.action_press(_player.ACTION_BACK)

func _space(pressed: bool) -> void:
	if _player == null: return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	root.push_input(event)

func _release() -> void:
	if _player == null: return
	for action: StringName in [_player.ACTION_LEFT,_player.ACTION_RIGHT,_player.ACTION_FORWARD,_player.ACTION_BACK,_player.ACTION_JUMP,_player.ACTION_RUN]:
		Input.action_release(action)

func _capture() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone: int in range(_rig.get_bone_count()): result.append(_rig.get_bone_pose(bone))
	return result

func _box(at: Vector3,size_value: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.position = at
	body.add_child(collision)
	_world.add_child(body)
	return body

func _frame() -> void:
	await physics_frame
	await process_frame

func _frames(count: int) -> void:
	for frame: int in range(count): await _frame()

func _check(ok: bool,label: String) -> void:
	_checks += 1
	if not ok: _errors.append(label)

func _finish() -> void:
	_release()
	_metrics["visual_quaternion_1_abs_dot_max"] = _max_visual_q_error
	_metrics["bone_quaternion_1_abs_dot_max"] = _max_bone_q_error
	_metrics["head_world_quaternion_1_abs_dot_max"] = _max_head_q_error
	_metrics["source_elapsed_max_error_s"] = _max_clock_error
	_metrics["full_skin_floor_max_error_m"] = _skin_min_error
	_metrics["full_skin_samples"] = _skin_samples
	print(JSON.stringify({"passed":_errors.is_empty(),"checks":_checks,"errors":_errors,"metrics":_metrics,"player_sha256":_player_sha,"dive_sha256":_dive_sha,"source_receipts":_oracle.get("hashes",{}),"scope":"independent executed JS oracle + actual headless input/physics/full pose; no LIVE/FPS acceptance"}))
	quit(0 if _errors.is_empty() else 1)

func _finalize() -> void:
	_release()
