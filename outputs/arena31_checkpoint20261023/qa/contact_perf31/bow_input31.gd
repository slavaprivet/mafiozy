extends SceneTree
var out:String
var tier:="none"
var shot_count:=1
var aim_up:=0.0
var plate_target31:=false
var target_point31:=Vector3.INF
var tissue_impacts31:Array=[]
var rebound_geometry31:Array=[]
var checks:Dictionary={}
var rows:Array=[]
var scene:Node
var player:CharacterBody3D
var host:Node
var bow:Node
func _initialize():
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--tier="):tier=arg.trim_prefix("--tier=")
		if arg.begins_with("--shots="):shot_count=int(arg.trim_prefix("--shots="))
		if arg.begins_with("--aim-up="):aim_up=float(arg.trim_prefix("--aim-up="))
		if arg=="--plate":plate_target31=true
	run.call_deferred()
func ticks(n:int):
	for i in n:await physics_frame;await create_timer(0).timeout
func mouse(button:int,down:bool):
	var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func key(code:int):
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func aim():
	for i in 18:
		var rig:Skeleton3D=host._npc_rig
		var target:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin+Vector3.UP*aim_up
		if target_point31.is_finite():target=target_point31
		var camera:Camera3D=player.get_preview_camera()
		var direction:Vector3=(target-camera.global_position).normalized()
		var yaw:=atan2(-direction.x,-direction.z)
		var pitch:=asin(direction.y)
		var e:=InputEventMouseMotion.new()
		e.relative=Vector2(clampf(wrapf(player._camera_yaw-yaw,-PI,PI)/player.mouse_sensitivity,-25,25),clampf((player._camera_pitch-pitch)/player.mouse_sensitivity,-25,25));e.screen_relative=e.relative
		Input.parse_input_event(e);Input.flush_buffered_events();await ticks(1)
func run():
	root.size=Vector2i(1280,900)
	change_scene_to_file("res://scenes/arena27.tscn")
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
	scene=current_scene;checks["startup"]=is_instance_valid(scene) and scene.get("lab_ready")==true
	if not checks.startup:finish();return
	player=scene.get("_player");host=scene.get("lab");bow=scene.get("preview_bow_prototype")
	host.lab_regrow=false
	var equipment:Dictionary={}
	if tier!="none":
		for slot:String in ["head","torso","hands","legs","feet"]:equipment[slot]=tier+"_"+slot
	host.lab_armored=tier!="none";host.lab_armor_tier30=tier;host.set_npc_armor31(equipment)
	player.global_position=Vector3(0,.05,2.5);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.1;player._update_camera_rotation();player.set_mouse_captured(true)
	await ticks(20)
	if plate_target31:
		var armor=load("res://scripts/combat/armor_damage31.gd")
		var rig:Skeleton3D=host._npc_rig
		var best:=INF
		for xi in range(-3,4):
			for yi in range(8,17):
				var from:=Vector3(float(xi)*.075,float(yi)*.10,-.8)
				var hits:Array[Dictionary]=host._solid_weapon29.skin_hits(host,from,from+Vector3.FORWARD*2.,"")
				if hits.is_empty():continue
				var hit:Dictionary=hits[0];var bone:=int(hit.bone)
				if bone<0:continue
				var part:=str(rig.get_bone_name(bone))
				if part.begins_with("spine"):part="chest"
				if part=="neck":part="head"
				var proxy:CollisionObject3D=null
				var anchor:=rig.get_node_or_null("Hit"+part)
				if anchor!=null:
					for child in anchor.get_children():
						if child is CollisionObject3D:proxy=child;break
				var incoming:=26.*(2. if part=="head" else 1.)
				var coverage:Dictionary=armor.resolve(equipment,part,"stab",incoming,host._armor_point31(rig,part,hit.point,proxy),1.)
				if str(coverage.region)!="plate" or armor.tissue_penetrates("plate","stab",float(coverage.damage)):continue
				var score:float=absf(float(xi))*.02+absf(float(yi)*.1-1.25)
				if score<best:best=score;target_point31=hit.point;rows.append({"phase":"plate_aim_candidate","point":hit.point,"part":part,"coverage":coverage})
		checks["actual_protected_plate_target"]=target_point31.is_finite()
	var arsenal:Node=scene.get("preview_weapons")
	key(KEY_Q);await ticks(3)
	var button:Button=arsenal.get("_buttons")["bow"]
	arsenal.get("_walk_ui").scroll.ensure_control_visible(button);await ticks(2)
	var point:=button.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await ticks(1)
	await ticks(15)
	checks["q_actual_bow"]=bow._selected and not bow._grounded and bow._bow.is_visible_in_tree()
	var shots_before:=int(bow._shots)
	mouse(MOUSE_BUTTON_RIGHT,true);await ticks(2);mouse(MOUSE_BUTTON_LEFT,true);mouse(MOUSE_BUTTON_LEFT,false);await ticks(2)
	checks["early_click_not_fired"]=int(bow._shots)==shots_before
	mouse(MOUSE_BUTTON_RIGHT,false);await ticks(4)
	checks["cancel_does_not_fire"]=int(bow._shots)==shots_before
	var hp_before:=float(host._npc_hp)
	for shot in shot_count:
		mouse(MOUSE_BUTTON_RIGHT,true)
		await aim()
		for i in 180:
			await ticks(1)
			if bow.ready_to_fire() and bow._draw_amount>=.98:break
		await aim()
		var ammo:=int(bow._arrows_left)
		checks["ready_%s"%shot]=bow.ready_to_fire()
		rows.append({"phase":"before_shot","camera":player.get_preview_camera().global_transform,"yaw":player._camera_yaw,"pitch":player._camera_pitch,"muzzle":bow._muzzle_point(),"direction":bow._aim_direction(),"sight":bow._sight_point})
		mouse(MOUSE_BUTTON_LEFT,true);await ticks(1);mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
		var recorded:=false
		for tick in 35:
			await ticks(1)
			var observed:Dictionary=bow.arrow_state(bow.last_fired_index())
			if not recorded and bool(observed.get("actual_skin",false)) and not observed.get("damage_result",{}).is_empty():
				tissue_impacts31.append(observed);recorded=true
				if plate_target31 and bool(observed.get("armor_rejected",false)):
					var item:Dictionary=bow._arrows[bow.last_fired_index()]
					var node:Node3D=item.node
					var normal:Vector3=item.get("rebound_normal31",Vector3.ZERO)
					var rebound_point:Vector3=item.get("rebound_point31",Vector3.ZERO)
					var lowest:=INF
					for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
						for vertex:Vector3 in mesh.mesh.get_faces():lowest=minf(lowest,(mesh.global_transform*vertex-rebound_point).dot(normal))
					rebound_geometry31.append({"basis":node.global_basis,"origin":node.global_position,"point":rebound_point,"normal":normal,"minimum_exterior_m":lowest,"stuck":item.get("stuck",false)})
			if plate_target31 and not rebound_geometry31.is_empty() and not rebound_geometry31[-1].has("following_axis_dot"):
				var item:Dictionary=bow._arrows[bow.last_fired_index()]
				if bool(item.get("stuck",false)) or item.node.global_position.distance_to(rebound_geometry31[-1].origin)>.001:
					rebound_geometry31[-1]["following_axis_dot"]=Basis(rebound_geometry31[-1].basis).z.dot(item.node.global_basis.z)
		checks["single_shot_%s"%shot]=int(bow._shots)==shots_before+shot+1 and int(bow._arrows_left)==ammo-1
		rows.append({"shot":shot,"arrow":bow.arrow_state(bow.last_fired_index()),"hp":host._npc_hp,"dead":host._npc_dead,"audio":host.melee_audio_report31()})
		await ticks(30)
	var actual:=false;var embedded:=false;var rejected:=false;var max_anchor_error:=0.0
	# A rejected arrow can subsequently hit the floor/wall. Preserve the observed
	# tissue collision instead of asking its later world collision to prove it.
	for impact:Dictionary in tissue_impacts31:
		actual=actual or bool(impact.get("actual_skin",false))
	for entry:Dictionary in bow._arrows:
		actual=actual or bool(entry.get("actual_skin31",false))
		embedded=embedded or (bool(entry.get("stuck",false)) and float(entry.get("embed_depth31",0))>0)
		rejected=rejected or bool(entry.get("armor_rejected31",false))
		var ref:WeakRef=entry.get("skin_rig31")
		if ref!=null and is_instance_valid(ref.get_ref()):
			var rig:Skeleton3D=ref.get_ref()
			var expected:Transform3D=rig.global_transform*rig.get_bone_global_pose(int(entry.skin_bone31))*Transform3D(entry.skin_local31)
			max_anchor_error=maxf(max_anchor_error,expected.origin.distance_to(entry.node.global_position))
	checks["actual_posed_skin_hit"]=actual
	checks["real_damage"]=float(host._npc_hp)<hp_before
	checks["finite_tissue_embed_or_armor_rejection"]=embedded or rejected
	checks["bone_anchor_follows"]=max_anchor_error<.001
	if plate_target31:
		var plate_rejected:=false
		for impact:Dictionary in tissue_impacts31:
			plate_rejected=plate_rejected or (str(impact.damage_result.get("region",""))=="plate" and bool(impact.armor_rejected) and not bool(impact.stuck))
		checks["actual_covered_plate_rejection"]=plate_rejected
	if plate_target31:
		var exterior:=not rebound_geometry31.is_empty();var continuous:=exterior;var world_stop:=false
		for event:Dictionary in rebound_geometry31:
			exterior=exterior and float(event.minimum_exterior_m)>=-.001
			continuous=continuous and float(event.get("following_axis_dot",0.0))>.99999
		for item:Dictionary in bow._arrows:world_stop=world_stop or bool(item.get("rebound_world_contact31",false))
		checks["rebound_shaft_exterior"]=exterior;checks["rebound_axis_continuous"]=continuous;checks["rebound_world_contact"]=world_stop
		rows.append({"rebound_geometry31":rebound_geometry31})
	rows.append({"tissue_impacts31":tissue_impacts31})
	rows.append({"final_dead":host._npc_dead,"max_anchor_error":max_anchor_error,"arrows":bow._arrows.size(),"rejected":rejected})
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/bow_result.png")
	finish()
func finish():
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows,"tier":tier},"  "))
	var old:Node=current_scene;current_scene=null
	if is_instance_valid(old):old.queue_free()
	await ticks(4);quit(0 if not checks.values().has(false) else 1)
