extends "res://scripts/destruction/palazzo/palazzo_structural_site.gd"
## New compact architecture, inherited current Palazzo damage/support lifecycle.
## No duplicated showcase, immovable building core, fake receipts or pooled5000 nodes.
const Swing29 = preload("res://scripts/city/runtime/npc_city_clone_door_swing.gd")
const CompactGlazing29 = preload("npc_compact_glazing29.gd")
var service_kind := "shop"
var service_sign := "МАГАЗИН"
var native_ground29: Array[StaticBody3D] = []
var _swing29: Node3D
var _world29: WeakRef
var _catalog_sign29: Label3D
var _body_budget29 := 0

func _ready() -> void:
	set_meta("throwable_bounds_radius",6.4)
	super._ready()

func _build_site() -> void:
	# Existing native dry terrain is the structural anchor. No new ground is made.
	flash = OmniLight3D.new(); flash.name = "CompactBlastFlash29"
	flash.light_color = Color("ffb76b"); flash.light_energy = 0.0; flash.omni_range = 9.0
	add_child(flash)

func _build_building() -> void:
	building = Node3D.new(); building.name = "CompactOwnedArchitecture29"; add_child(building)
	pieces.clear(); initial_transforms.clear(); batch_records.clear(); batch_nodes.clear()
	pooled_fragments.clear(); render_by_id.clear(); render_dirty.clear(); active_debris.clear()
	support_wakes.clear(); support_wake_ids.clear(); wall_panels.clear()
	_finished_errors.clear(); _finished_omitted_cells = 0
	var wall_color := Color("c4baa5")
	if service_kind == "hospital": wall_color = Color("d7dfd3")
	elif service_kind == "bank": wall_color = Color("b9b7aa")
	elif service_kind == "restaurant": wall_color = Color("c5a995")
	elif bool(get_meta("player_weapon_shop", false)): wall_color = Color("8b7568")
	# Six independently owned foundation/floor slabs, top .24m above native ground.
	for ix: int in range(3):
		for iz: int in range(2):
			var at := Vector3(-8.0 / 3.0 + float(ix) * 8.0 / 3.0, .12, -1.75 + float(iz) * 3.5)
			var floor_body: RigidBody3D = _section29("ServiceFloor", Vector3(8.0 / 3.0, .24, 3.5), at, Color("bcb39d"))
			floor_body.set_meta("foundation_chunk", true)
			_section29("ServiceRoof", Vector3(8.0 / 3.0, .22, 3.5), Vector3(at.x, 3.15, at.z), Color("727e76"))
	# The .24m owned floor needs a real sloped transition for the entire capsule.
	# No step exemption: the same floor/standing/sweep checks traverse this piece.
	var ramp_angle := atan2(.24, 1.4)
	var ramp: RigidBody3D = _section29("ServiceEntranceRamp", Vector3(2.0, .08, sqrt(1.4 * 1.4 + .24 * .24) + .16), Vector3(0, .12 - .04 * cos(ramp_angle), 4.2 - .04 * sin(ramp_angle)), Color("bcb39d"))
	ramp.rotation.x = ramp_angle
	initial_transforms[ramp.get_instance_id()] = ramp.transform
	# Rear and side wall chunks are already separate owned sections; a blast
	# releases physical chunks rather than enabling a giant preallocated tile pool.
	for height: float in [.94, 2.34]:
		for ix: int in range(4):
			_section29("ServiceRear", Vector3(2.0, 1.4, .28), Vector3(-3.0 + float(ix) * 2.0, height, -3.5), wall_color)
		for side: float in [-1.0, 1.0]:
			for iz: int in range(4):
				_section29("ServiceSide", Vector3(.28, 1.4, 1.75), Vector3(side * 4.0, height, -2.625 + float(iz) * 1.75), wall_color)
	for side: float in [-1.0, 1.0]:
		var wall: RigidBody3D = _section29("ServiceWindow", Vector3(3.0, 2.8, .28), Vector3(side * 2.5, 1.64, 3.5), wall_color)
		# Accepted compound ring + real Walk glass; whole small ring is its chunk.
		window_on(wall, Vector3(0.0, .1, .17), 1.25, 1.55)
		wall_panels.append(wall)
	# 1.6m opening fits the .72m capsule and keeps the inward leaf clear of the
	# first registered room row (2.2m beyond the doorway); jambs fill the facade.
	for side: float in [-1.0, 1.0]: _section29("ServiceDoorJamb", Vector3(.2, 2.5, .28), Vector3(side * .9, 1.49, 3.5), wall_color)
	var door: RigidBody3D = _section29("Entrance", Vector3(1.6, 2.5, .22), Vector3(0.0, 1.49, 3.5), DARK)
	wall_panels.append(door)
	visual(door, Vector3(.055, .35, .08), Vector3(.65, 0.0, .15), BRASS, .6)
	_section29("ServiceLintel", Vector3(2.0, .3, .28), Vector3(0.0, 2.89, 3.5), wall_color)
	for side: float in [-1.0, 1.0]:
		_section29("ServiceCornice", Vector3(8.25, .16, .36), Vector3(0.0, 3.1, side * 3.5), TRIM)
		_section29("ServiceCorniceSide", Vector3(.36, .16, 7.0), Vector3(side * 4.0, 3.1, 0.0), TRIM)
	var sign_body: RigidBody3D = _section29("ServiceSign", Vector3(4.4, .45, .18), Vector3(0.0, 3.4, 3.57), DARK)
	var lettering := Label3D.new(); lettering.text = service_sign; lettering.font_size = 64
	lettering.pixel_size = .0052; lettering.modulate = Color("f1dfb1"); lettering.outline_size = 3
	sign_body.add_child(lettering); lettering.position.z = .10
	# Furnishings are owned physical boxes supported by floor, away from six slots.
	_section29("ServiceCounter", Vector3(2.2, .9, .65), Vector3(0.0, .69, -1.5), Color("826951"))
	if bool(get_meta("player_weapon_shop", false)):
		# This display belongs to the same destructible sections as the shell.
		var rack: RigidBody3D = _section29("WeaponRack", Vector3(2.8, 1.2, .14), Vector3(0, 1.65, -3.15), Color("493d38"))
		for x: float in [-.9, 0.0, .9]:
			visual(rack, Vector3(.58, .12, .08), Vector3(x, .23, .12), Color("302f2f"), .25)
			visual(rack, Vector3(.14, .34, .08), Vector3(x - .2, .04, .12), Color("302f2f"), .25)
	if service_kind == "hospital":
		for side: float in [-1.0, 1.0]: _section29("ServiceBed", Vector3(1.3, .58, 2.0), Vector3(side * 2.9, .53, -.6), Color("e5ece2"))
	elif service_kind == "bank":
		for side: float in [-1.0, 1.0]: _section29("ServiceSafe", Vector3(.9, 1.65, .65), Vector3(side * 2.9, 1.065, -2.7), Color("515e60"))
	elif service_kind == "restaurant":
		for side: float in [-1.0, 1.0]: _section29("ServiceTable", Vector3(.85, .78, 1.15), Vector3(side * 3.15, .63, -.1), Color("946f52"))
	else:
		for side: float in [-1.0, 1.0]: _section29("ServiceShelf", Vector3(.6, 1.6, 2.0), Vector3(side * 3.5, 1.04, -.6), Color("917252"))
	_body_budget29 = pieces.size(); _finished_initial_sections = pieces.size()
	if batched: _build_batches()
	if not rebuilding: _prepare_glazing()
	collapsing = false

func _section29(label: String, size: Vector3, at: Vector3, color: Color) -> RigidBody3D:
	var body: RigidBody3D = piece(label, size, at, color)
	body.set_meta("pooled_fragments", [])
	body.set_meta("compact_service29", true)
	return body

func configure_structure(ground: Array[StaticBody3D] = []) -> Dictionary:
	return super.configure_structure(native_ground29 if ground.is_empty() else ground)

func _prepare_glazing() -> void:
	if rebuilding or not is_inside_tree() or is_instance_valid(_glazing): return
	var helper: Node3D = CompactGlazing29.new()
	if not helper.configure(self): helper.free(); _finished_errors.append("compact_glazing_configure"); return
	_glazing = helper
	for wall: RigidBody3D in wall_panels:
		if not wall.has_meta("finished_window"): continue
		var window: Dictionary = wall.get_meta("finished_window")
		var added: Dictionary = _glazing.add_pane(wall, Transform3D(Basis.IDENTITY, window.center), Vector2(window.width, window.height), wall)
		if not added.get("ok", false): _finished_errors.append("compact_glazing_pane:" + str(added.get("reason", "unknown")))
	if not _finished_errors.is_empty(): site_error = "compact_glazing:" + _finished_errors[0]

func bind_service(world: Node3D) -> Dictionary:
	if not site_ready or not support_setup.get("ok", false) or not is_instance_valid(world): return {"ok":false,"reason":"site_or_real_ground_not_ready"}
	_world29 = weakref(world)
	if not is_instance_valid(_catalog_sign29):
		_catalog_sign29 = Label3D.new(); _catalog_sign29.name = "TownCloneSign"
		_catalog_sign29.text = service_sign; _catalog_sign29.visible = false
		# Catalog text only. The visible sign is attached to the OWNED sign body.
		add_child(_catalog_sign29)
	if is_instance_valid(_swing29): _swing29.queue_free()
	_swing29 = Swing29.new(); _swing29.name = "CompactDoorSwing29"; add_child(_swing29)
	var door_ok: bool = _swing29.configure(world, source_id, self)
	set_meta("venue_closed29", not door_ok)
	return {"ok":door_ok,"source_id":source_id,"pieces":pieces.size(),"pool":pooled_fragments.size(),"structure":support_setup}

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# A released leaf remains a live RigidBody. It must still retire admission,
	# even though its Swing node has not exited the tree. Only reset reopens it.
	if site_ready and not rebuilding and not bool(get_meta("venue_closed29", true)) and (not _door_available() or not is_instance_valid(_swing29) or not _swing29._available()):
		set_meta("venue_closed29", true)

func collapse() -> void:
	set_meta("venue_closed29", true)
	super.collapse()

func reset_building() -> void:
	if rebuilding or not site_ready: return
	set_meta("venue_closed29", true)
	if is_instance_valid(_swing29):
		remove_child(_swing29); _swing29.queue_free(); _swing29 = null
	await super.reset_building()
	if is_inside_tree() and _world29 != null and is_instance_valid(_world29.get_ref()): bind_service(_world29.get_ref())

func get_stats() -> Dictionary:
	var result: Dictionary = super.get_stats()
	result.compact_service29 = {"kind":service_kind,"owned_sections":_body_budget29,"floor_owned":true,"showcase_duplicated":false,"coarse_sections_not_fine_fracture_pool":true,"native_scene_acceptance":"PENDING"}
	return result
