from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]; OUT=Path(__file__).resolve().parent
src=ROOT/'outputs/coordinator23_marks_fix10'
(OUT/'frozen_actual_input.gd').write_bytes((src/'frozen_actual_input.gd').read_bytes())
s=(src/'capture_exposed.gd').read_text()
s=s.replace('var raw_hits:Array[Dictionary]=[]','''var raw_hits:Array[Dictionary]=[]
var head_local_target:=Vector3.ZERO
var head_target_selected:=false
var fixtures:Array[Dictionary]=[]
var headless_qa:=false
var extra_delay_frames:=0''')
s=s.replace('if arg.begins_with("--qa-pack-sha="):pack_sha=arg.trim_prefix("--qa-pack-sha=")','''if arg.begins_with("--qa-pack-sha="):pack_sha=arg.trim_prefix("--qa-pack-sha=")
		if arg=="--qa-headless":headless_qa=true
		if arg.begins_with("--qa-delay-frames="):extra_delay_frames=int(arg.trim_prefix("--qa-delay-frames="))''')
s=s.replace('or DisplayServer.get_name()=="headless":quit(2);return','or (DisplayServer.get_name()=="headless" and not headless_qa):quit(2);return')
s=s.replace('if aim_head:\n\t\treturn head_frame()', 'if aim_head:\n\t\tif head_target_selected:return head_frame()*head_local_target\n\t\treturn head_frame()')
s=s.replace('func capture(label:String)->void:\n\tif done:return','''func capture(label:String)->void:
	if done:return
	if headless_qa:
		var geometry:=mark_geometry(label=="01_clothing_wound")
		if label in ["01_clothing_wound","02_head_skin_wound"]:check(not geometry.is_empty(),"real_bound_surface_mark:"+label)
		var physical:RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
		picture_proofs.append({"label":label,"hp":owner._row.hp,"geometry":geometry,"eyes_closed":physical._eyes.closed,"head_proof":owner.last_head_zone.duplicate(true)})
		return''')
s=s.replace('"s01-20260930-quality23f","exact23f_runtime"','"s01-20260930-quality23g","exact23g_runtime"')
start=s.index('\taim_head=true;found=false\n');end=s.index('\tcheck(found,"real_muzzle_ray_reaches_anatomical_head")',start)
s=s[:start]+'''	aim_head=true
	await sync(extra_delay_frames)
	found=await place_for_exposed_face()
'''+s[end:]
s=s.replace('"raw_native_impacts":raw_hits,"shots":shots,','"raw_native_impacts":raw_hits,"shots":shots,"fixtures":fixtures,')
insertion='''func aim()->void:
	if not is_instance_valid(player) or owner==null:return
	if not head_target_selected:super.aim();return
	var camera:Camera3D=player.get_preview_camera()
	camera.top_level=true
	camera.global_position=player.global_position+Vector3.UP*1.65
	camera.look_at(target_point(),Vector3.UP)

func original_face_candidates()->Array[Dictionary]:
	# QA read-only original rigid head triangles. No semantic height damage rule:
	# these positions merely propose views, native receipt still proves the hit.
	var zone:RefCounted=owner._head_zone
	var center:Vector3=(zone._head_min+zone._head_max)*.5
	var height:float=zone._head_max.y-zone._head_min.y
	var sectors:Dictionary={}
	var vertices:PackedVector3Array=zone._head_triangles
	for i in range(0,vertices.size(),3):
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		var point:Vector3=(a+b+c)/3.0
		var fraction:float=(point.y-zone._head_min.y)/height
		if fraction<.24 or fraction>.64:continue
		var cross:Vector3=(b-a).cross(c-a)
		if cross.length_squared()<1e-12:continue
		var normal:=cross.normalized()
		if normal.dot(point-center)<0:normal=-normal
		if absf(normal.y)>.6:continue
		var sector:=posmod(roundi(atan2(normal.x,normal.z)/TAU*8.0),8)
		var band:=0 if fraction<.44 else 1
		var key:=Vector2i(sector,band)
		var score:=cross.length()/(.25+absf(fraction-.43))
		if not sectors.has(key) or score>float(sectors[key].score):sectors[key]={"local_point":point,"local_normal":normal,"score":score,"triangle":i/3,"fraction":fraction}
	var result:Array[Dictionary]=[]
	for row:Dictionary in sectors.values():result.append(row)
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.score>b.score)
	return result

func place_for_exposed_face()->bool:
	var candidates:=original_face_candidates()
	var capsule:CollisionShape3D=player.get_node("PlayerCapsule")
	var space:=scene.get_world_3d().direct_space_state
	for candidate:Dictionary in candidates:
		if done:return false
		var frame:=head_frame();var point:Vector3=frame*candidate.local_point
		var normal:Vector3=(frame.basis.inverse().transposed()*candidate.local_normal).normalized()
		var outward:=Vector3(normal.x,0,normal.z).normalized()
		var position:Vector3=point+outward*2.8
		var floor:=space.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*2,position-Vector3.UP*4,1,[player.get_rid()]))
		if floor.is_empty() or floor.normal.y<.8 or not floor.collider is StaticBody3D:continue
		position.y=floor.position.y+.004
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape
		query.transform=Transform3D(capsule.global_basis,position+capsule.global_position-player.global_position)
		query.collision_mask=261;query.exclude=[player.get_rid()];query.margin=.001
		if not space.intersect_shape(query,1).is_empty():continue
		head_local_target=candidate.local_point;head_target_selected=true
		player.global_position=position;player.velocity=Vector3.ZERO;aim()
		await sync(8)
		var reachable:bool=player.is_on_floor() and real_sight().ok and finishing_sight()
		fixtures.append({"player_position":player.global_position,"floor":floor.position,"original_head_triangle":candidate.triangle,"local_target":head_local_target,"outward":outward,"reachable_exposed_skin":reachable,"normal_scheduled_physics":player.is_physics_processing(),"only_player_placed":true})
		if reachable:return true
	return false

'''
s=s.replace('func finishing_sight()->bool:',insertion+'func finishing_sight()->bool:')
(OUT/'capture.gd').write_text(s,encoding='utf8')
pins={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'capture.gd',OUT/'frozen_actual_input.gd']}
(OUT/'HARNESS_PINS.json').write_text(json.dumps(pins,indent=2),encoding='utf8')
print(pins)
