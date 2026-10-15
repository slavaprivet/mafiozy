extends "res://scripts/venues/npc_compact_service_site29.gd"
## A small residential shell on the accepted Palazzo ownership/support backend.
## All architecture and beds are owned rigid sections. Native terrain is external.
var residents58: Array[String] = []
var home_number58 := 1
var beds58: Array[Dictionary] = []
var floors58: Array[RigidBody3D] = []
var roofs58: Array[RigidBody3D] = []
var _habitable_frame58 := -1
var _habitable_cached58 := false
var _physical_pins58: Dictionary = {}

func _build_building() -> void:
	building = Node3D.new(); building.name = "HomeOwnedArchitecture58"; add_child(building)
	pieces.clear(); initial_transforms.clear(); batch_records.clear(); batch_nodes.clear()
	pooled_fragments.clear(); render_by_id.clear(); render_dirty.clear(); active_debris.clear()
	support_wakes.clear(); support_wake_ids.clear(); wall_panels.clear()
	_finished_errors.clear(); _finished_omitted_cells = 0
	beds58.clear(); floors58.clear(); roofs58.clear()
	_habitable_frame58 = -1
	_physical_pins58.clear()
	var colors: Array[Color] = [Color("c9b49a"), Color("b8c5ba"), Color("d3c6b4"), Color("b5bec8")]
	var wall_color: Color = colors[(home_number58 - 1) % colors.size()]
	for ix: int in range(3):
		for iz: int in range(2):
			var at := Vector3(-8.0 / 3.0 + float(ix) * 8.0 / 3.0, .12, -1.75 + float(iz) * 3.5)
			var floor_body: RigidBody3D = _section29("HomeFloor", Vector3(8.0 / 3.0, .24, 3.5), at, Color("bcb39d"))
			floor_body.set_meta("foundation_chunk", true); floors58.append(floor_body)
			roofs58.append(_section29("HomeRoof", Vector3(8.0 / 3.0, .22, 3.5), Vector3(at.x, 3.15, at.z), Color("7c756a")))
	var ramp_angle := atan2(.24, 1.4)
	var ramp: RigidBody3D = _section29("HomeEntranceRamp", Vector3(2.0, .08, sqrt(1.4 * 1.4 + .24 * .24) + .16), Vector3(0, .12 - .04 * cos(ramp_angle), 4.2 - .04 * sin(ramp_angle)), Color("bcb39d"))
	ramp.rotation.x = ramp_angle
	initial_transforms[ramp.get_instance_id()] = ramp.global_transform
	for height: float in [.94, 2.34]:
		for ix: int in range(4):
			_section29("HomeRear", Vector3(2.0, 1.4, .28), Vector3(-3.0 + float(ix) * 2.0, height, -3.5), wall_color)
		for side: float in [-1.0, 1.0]:
			for iz: int in range(4):
				_section29("HomeSide", Vector3(.28, 1.4, 1.75), Vector3(side * 4.0, height, -2.625 + float(iz) * 1.75), wall_color)
	for side: float in [-1.0, 1.0]:
		var wall: RigidBody3D = _section29("HomeWindow", Vector3(3.0, 2.8, .28), Vector3(side * 2.5, 1.64, 3.5), wall_color)
		window_on(wall, Vector3(0.0, .1, .17), 1.25, 1.55)
		wall_panels.append(wall)
		_section29("HomeDoorJamb", Vector3(.2, 2.5, .28), Vector3(side * .9, 1.49, 3.5), wall_color)
	var door: RigidBody3D = _section29("Entrance", Vector3(1.6, 2.5, .22), Vector3(0.0, 1.49, 3.5), Color("685642"))
	wall_panels.append(door)
	visual(door, Vector3(.055, .35, .08), Vector3(.65, 0.0, .15), BRASS, .6)
	_section29("HomeLintel", Vector3(2.0, .3, .28), Vector3(0.0, 2.89, 3.5), wall_color)
	for side: float in [-1.0, 1.0]:
		_section29("HomeCornice", Vector3(8.25, .16, .36), Vector3(0.0, 3.1, side * 3.5), TRIM)
		_section29("HomeCorniceSide", Vector3(.36, .16, 7.0), Vector3(side * 4.0, 3.1, 0.0), TRIM)
	var sign_body: RigidBody3D = _section29("HomeAddress", Vector3(.8, .38, .08), Vector3(1.4, 1.9, 3.7), DARK)
	var address := Label3D.new(); address.text = str(home_number58); address.font_size = 64
	address.pixel_size = .0048; address.modulate = Color("f1dfb1"); address.outline_size = 0
	sign_body.add_child(address); address.position.z = .05
	var xs: Array[float] = []
	xs.assign([-2.5, 0.0, 2.5] if residents58.size() == 3 else [-2.5, 2.5])
	if residents58.size() == 1: xs.assign([0.0])
	for index: int in residents58.size():
		var x: float = xs[index]
		var frame: RigidBody3D = _section29("HomeBedFrame", Vector3(1.25, .42, 2.1), Vector3(x, .45, -1.9), Color("796046"))
		_finished_box(frame, Vector3(1.25, .7, .10), Vector3(0, .35, -1.0), Color("796046"), 0.0, true, "headboard")
		var mattress: RigidBody3D = _section29("HomeBedMattress", Vector3(1.2, .16, 2.02), Vector3(x, .74, -1.9), Color("e3ddd0"))
		visual(mattress, Vector3(1.15, .04, 1.35), Vector3(0, .10, .25), Color("698482") if index % 2 == 0 else Color("978275"))
		visual(mattress, Vector3(.85, .12, .40), Vector3(0, .14, -.72), Color("eee9de"))
		var bed_id: String = source_id + ":bed:" + str(index + 1)
		frame.set_meta("home_bed58", bed_id); mattress.set_meta("home_bed58", bed_id)
		beds58.append({"source_id":residents58[index], "bed_id":bed_id, "bed_node":weakref(mattress), "bed_support":weakref(frame), "approach":Vector3(x, .24, 0), "surface":Vector3(x, .82, -1.9)})
	_body_budget29 = pieces.size(); _finished_initial_sections = pieces.size()
	for body: RigidBody3D in pieces:
		var shapes: Array[Dictionary] = []
		for child: Node in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				shapes.append({"node":weakref(child), "shape":child.shape, "size":child.shape.size, "frame":child.transform})
		_physical_pins58[body.get_instance_id()] = shapes
	if batched: _build_batches()
	if not rebuilding: _prepare_glazing()
	collapsing = false

func intact58(body: Variant) -> bool:
	if not body is RigidBody3D or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	if not owns_collider(body) or not body.freeze or not body.visible or (body.collision_layer & 1) == 0: return false
	if body.get_meta("detached", false) or body.get_meta("fracture_active", false): return false
	var initial: Variant = initial_transforms.get(body.get_instance_id())
	if not initial is Transform3D or not body.global_transform.is_equal_approx(initial): return false
	var pins: Array = _physical_pins58.get(body.get_instance_id(), [])
	if pins.is_empty(): return false
	var shape_count := 0
	for child: Node in body.get_children():
		if child is CollisionShape3D: shape_count += 1
	if shape_count != pins.size(): return false
	for pin: Dictionary in pins:
		var shape: Variant = pin.node.get_ref()
		if not is_instance_valid(shape) or shape.get_parent() != body or shape.disabled: return false
		if shape.shape != pin.shape or not shape.shape is BoxShape3D or shape.shape.size != pin.size or shape.transform != pin.frame: return false
	return true

func habitable58() -> bool:
	if not site_ready or rebuilding or collapsing or bool(get_meta("venue_closed29", true)): return false
	var frame: int = Engine.get_physics_frames()
	if _habitable_frame58 == frame: return _habitable_cached58
	_habitable_frame58 = frame; _habitable_cached58 = false
	# Structural damage retires this dwelling for this generation. Rebuilding is
	# the explicit path back; a floating roof or a hole is never a sleeping room.
	for floor_body: RigidBody3D in floors58:
		if not intact58(floor_body): return false
	for roof_body: RigidBody3D in roofs58:
		if not intact58(roof_body): return false
	_habitable_cached58 = true
	return true

func _release(body: RigidBody3D, at: Vector3, power: float, exit_direction: Vector3 = Vector3.ZERO) -> void:
	_habitable_frame58 = -1
	super._release(body, at, power, exit_direction)

func get_stats() -> Dictionary:
	var result: Dictionary = super.get_stats()
	result.erase("compact_service29")
	result.home58 = {"number":home_number58, "residents":residents58, "beds":beds58.size(), "habitable":habitable58(), "owned_sections":_body_budget29, "all_architecture_owned":true, "native_ground_only":true}
	return result
