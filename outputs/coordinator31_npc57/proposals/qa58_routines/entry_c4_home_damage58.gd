extends "entry_geometry58_v3.gd"
## Uses actual C4 selection, Input singleton LMB hold, physical item and remote.
## One cold PLAYER fixture placement only; no NPC/body/route substitutions.
var finished_c4 := false
var player58: CharacterBody3D
var camera58: Camera3D
var target58:=Vector3.ZERO
var tracking58:=false
var aim_frame58:=-1

func finish() -> void:
	var valid:=true
	for row: Dictionary in checks:
		if not row.ok:valid=false
	if valid and is_instance_valid(current_scene) and not finished_c4:
		finished_c4=true
		evidence.scope="VFS homes/native30s stability + actual3s C4 item/remote/destruction/reset. Sleep not tested."
		await c4_case(current_scene)
	tracking58=false
	super.finish()

func step58(count: int=1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func key58(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func mouse58(pressed: bool, at: Vector2=Vector2(-1,-1)) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	event.position=root.get_visible_rect().size*.5 if at.x<0 else at;event.global_position=event.position
	event.button_mask=Input.get_mouse_button_mask()
	if at.x<0:Input.parse_input_event(event)
	else:root.push_input(event,true)
func _process(_delta: float) -> bool:
	if tracking58 and Engine.get_physics_frames()!=aim_frame58:
		aim_frame58=Engine.get_physics_frames()
		var direction: Vector3=(target58-camera58.global_position).normalized()
		var yaw: float=atan2(-direction.x,-direction.z);var pitch: float=asin(clampf(direction.y,-.98,.98))
		var correction:=Vector2(clampf(wrapf(yaw-player58._camera_yaw,-PI,PI)*.35,-.045,.045),clampf((pitch-player58._camera_pitch)*.35,-.045,.045))
		var event:=InputEventMouseMotion.new();event.position=root.get_visible_rect().size*.5;event.global_position=event.position;event.button_mask=Input.get_mouse_button_mask()
		event.relative=-correction/player58.mouse_sensitivity;root.push_input(event,true)
	return false
func c4_case(scene: Node3D) -> void:
	var homes: Node=scene.preview_homes58
	var house: Node3D=homes.registry58.assigned("resident_3").house.get_ref()
	var wall: RigidBody3D
	for body: RigidBody3D in house.pieces:
		if str(body.name).begins_with("HomeRear") and body.position.distance_to(Vector3(-3,.94,-3.5))<.01:wall=body;break
	if not check(is_instance_valid(wall),"actual home rear wall found"):return
	var equipment: Node=scene.preview_c4
	var weapons: Node=scene.preview_weapons
	player58=scene._player;camera58=player58.get_preview_camera()
	# Cold independent fixture arrangement before input; all subsequent retreat is
	# real native S movement. House/NPC/physics/masks are never repositioned.
	player58.global_position=house.to_global(Vector3(-3,.12,-4.65));player58.velocity=Vector3.ZERO
	player58._camera_yaw=house.global_rotation.y+PI;player58._camera_pitch=-.08;player58._update_camera_rotation()
	await step58(30)
	if not player58._free_mouse_look:mouse58(true);await step58();mouse58(false);await step58(3)
	if not check(player58._free_mouse_look and player58.is_on_floor(),"cold player settled on actual ground"):return
	key58(KEY_Q,true);await step58();key58(KEY_Q,false);await step58(2)
	if not check(weapons.menu_open,"native Q arsenal opens"):return
	weapons._walk_ui.scroll.ensure_control_visible(equipment._button);await step58(3)
	var at: Vector2=equipment._button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true)
	mouse58(true,at);await step58();mouse58(false,at);await step58(4)
	if not check(not weapons.menu_open and equipment.snapshot().mode=="place","native Q button selects actual C4"):return
	target58=wall.to_global(Vector3(0,0,-.15));tracking58=true
	for frame: int in 180:
		await step58()
		var aim: Dictionary=equipment._target()
		if not aim.is_empty() and aim.body==wall and aim.point.distance_to(target58)<.015:break
	tracking58=false;await step58(8)
	var selected: Dictionary=equipment._target()
	evidence.c4_aim={"target":target58,"player":player58.global_position,"camera":camera58.global_transform,"actual_target":str(selected.get("body")),"diagnostic":equipment._target_query45.snapshot()}
	if not check(not selected.is_empty() and selected.body==wall,"actual native C4 query selects home wall",evidence.c4_aim):return
	var original_slot: Dictionary=homes.registry58.assigned(str(house.residents58[0]))
	var mattress: RigidBody3D=original_slot.bed_node.get_ref()
	var support: RigidBody3D=original_slot.bed_support.get_ref()
	var bed_start: Vector3=mattress.global_position
	var begin: int=Engine.get_physics_frames();var before_pos: Vector3=player58.global_position
	mouse58(true);await create_timer(3.2,false,true).timeout
	var held: bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	mouse58(false);await step58(3)
	var placed: Dictionary=equipment.snapshot()
	evidence.c4_placed={"real_lmb":held,"physics_frames":Engine.get_physics_frames()-begin,"actor_drift_m":player58.global_position.distance_to(before_pos),"snapshot":placed}
	if not check(held and placed.placed.size()==1 and placed.mode=="remote","native3s hold creates one physical charge",evidence.c4_placed):return
	var charge: Node3D=equipment._charges.values()[0].node.get_ref()
	if not check(is_instance_valid(charge) and charge.get_parent()==wall,"charge attached to owned home wall"):return
	var charge_position: Vector3=charge.global_position
	key58(KEY_S,true)
	for index: int in 150:
		await step58()
		if player58.global_position.distance_to(charge_position)>5.0:break
	key58(KEY_S,false);await step58(8)
	if not check(player58.global_position.distance_to(charge_position)>3.5,"native S retreat before remote",player58.global_position.distance_to(charge_position)):return
	var events_before: int=scene.preview_c4_blast._events.size()
	if has_method("mark_damage58"):call("mark_damage58")
	mouse58(true);mouse58(false);await step58(2)
	check(equipment.snapshot().placed.is_empty(),"remote consumed actual planted item")
	var max_bed_travel:=0.0
	var native_unfrozen: bool=not mattress.freeze
	for frame: int in 480:
		await physics_frame
		max_bed_travel=maxf(max_bed_travel,mattress.global_position.distance_to(bed_start))
		native_unfrozen=native_unfrozen or not mattress.freeze
	var snap: Dictionary=scene.preview_c4_blast.snapshot()
	evidence.c4_blast={"snapshot":snap,"bed_unfrozen_observed":native_unfrozen,"bed_travel_m":max_bed_travel,"bed_layer":mattress.collision_layer,"bed_detached":mattress.get_meta("detached",false),"bed_support_detached":support.get_meta("detached",false),"slot_current":homes.registry58.current(original_slot),"house_habitable":house.habitable58()}
	check(snap.events.size()==events_before+1,"one authentic C4 blast committed",snap)
	check(not homes.registry58.current(original_slot),"partial destruction invalidates original assigned bed")
	check(mattress.get_meta("detached",false) and native_unfrozen and max_bed_travel>.10,"mattress becomes moving native rubble",evidence.c4_blast)
	check(not house.habitable58(),"damaged house cannot certify sleep")
	if has_method("wait_exit58"):await call("wait_exit58")
	var generation: int=house.rebuild_generation
	await house.reset_building();await step58(180)
	var replacement: Dictionary=homes.registry58.assigned(str(house.residents58[0]))
	check(house.rebuild_generation==generation+1 and not replacement.is_empty() and homes.registry58.current(replacement),"real reset rebuilds valid new-generation bed")
	check(not homes.registry58.current(original_slot),"old slot stays invalid after rebuild")
	evidence.c4_after_reset=homes.registry58.snapshot()
