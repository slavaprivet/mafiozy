extends Node
## Local car lamps: two existing lens materials and two shadowless road lights.
## No update loop: body parenting keeps both beams attached while driving.
const LIGHT_RANGE_M := 22.0
const LIGHT_ENERGY := 24.0
const NIGHT_LIGHT_ENERGY := 7.0
var enabled := false
var lights: Array[SpotLight3D] = []
var lamps: Array[MeshInstance3D] = []
var lamp_materials: Array[StandardMaterial3D] = []
var _world: Node
var _player: Node
var _transport: Node
var _body: Node3D
var _original_overrides: Array[Dictionary] = []

func configure(world: Node, player: Node, transport: Node) -> bool:
	_clear()
	_world = world
	_player = player
	_transport = transport
	set_process(false)
	set_physics_process(false)
	if not is_instance_valid(_transport) or not is_instance_valid(_transport.body):
		return false
	_body = _transport.body
	if not _body.is_inside_tree() or not is_instance_valid(_transport.visual):
		return false
	# Source metadata survives the imported key names and the 180-degree wrapper.
	# Bind actual lens meshes, never the decorative Headlamp_housing meshes.
	for candidate: Variant in _transport.visual.nodes.values():
		if not candidate is MeshInstance3D:
			continue
		var source_name := str(candidate.get_meta("source_name", ""))
		if source_name.ends_with("_Headlamp_L") or source_name.ends_with("_Headlamp_R"):
			lamps.append(candidate)
	if lamps.size() != 2:
		_clear()
		return false
	for lamp: MeshInstance3D in lamps:
		if lamp.mesh == null:
			_clear()
			return false
		for surface: int in lamp.mesh.get_surface_count():
			var original := lamp.get_surface_override_material(surface)
			var source := lamp.get_active_material(surface) as StandardMaterial3D
			if source == null:
				_clear()
				return false
			var material := source.duplicate() as StandardMaterial3D
			_original_overrides.append({"lamp": lamp, "surface": surface, "material": original})
			lamp.set_surface_override_material(surface, material)
			material.emission = Color(1.0, 0.92, 0.72)
			material.emission_energy_multiplier = 2.2
			material.emission_enabled = false
			lamp_materials.append(material)
		var body_from_lamp: Transform3D = _body.global_transform.affine_inverse() * lamp.global_transform
		var bounds: AABB = body_from_lamp * lamp.get_aabb()
		var lens_center := bounds.get_center()
		var beam := SpotLight3D.new()
		beam.name = "RoadBeam_" + str(lamp.name)
		beam.position = Vector3(lens_center.x, lens_center.y, bounds.position.z - 0.015)
		beam.rotation.x = -0.12
		beam.light_color = Color(1.0, 0.92, 0.72)
		beam.light_energy = LIGHT_ENERGY
		beam.spot_range = LIGHT_RANGE_M
		beam.spot_angle = 32.0
		beam.spot_angle_attenuation = 1.5
		beam.spot_attenuation = 1.0
		beam.shadow_enabled = false
		beam.light_bake_mode = Light3D.BAKE_DISABLED
		beam.visible = false
		_body.add_child(beam)
		lights.append(beam)
	return true

func allowed() -> bool:
	if not is_inside_tree() or get_tree().paused or lights.size() != 2:
		return false
	if not is_instance_valid(_world) or not is_instance_valid(_player) or not is_instance_valid(_transport):
		return false
	if not is_instance_valid(_body) or _transport.body != _body or not _body.is_inside_tree():
		return false
	if _world.preview_dead or _world.preview_physics_fault:
		return false
	if not _transport.ready_for_play or _transport.phase != "SEATED" or _transport.active_seat != "front_left":
		return false
	if not _player._free_mouse_look:
		return false
	if DisplayServer.get_name() != "headless" and (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not get_window().has_focus()):
		return false
	if _player.has_method("_text_control_focused") and _player._text_control_focused():
		return false
	var weapons: Node = _player._weapon_host
	if is_instance_valid(weapons) and weapons.has_method("controls_blocked") and weapons.controls_blocked():
		return false
	return true

func toggle() -> bool:
	if not allowed():
		return false
	enabled = not enabled
	for entry: Variant in lights:
		if not is_instance_valid(entry): continue
		var beam: SpotLight3D = entry
		beam.visible = enabled
	for material: StandardMaterial3D in lamp_materials:
		material.emission_enabled = enabled
	return true

func set_daylight(daylight: float) -> void:
	if not is_finite(daylight): return
	var energy := lerpf(NIGHT_LIGHT_ENERGY, LIGHT_ENERGY, clampf(daylight, 0.0, 1.0))
	for entry: Variant in lights:
		if is_instance_valid(entry): entry.light_energy = energy

func _clear() -> void:
	enabled = false
	for entry: Variant in lights:
		if not is_instance_valid(entry): continue
		var beam: SpotLight3D = entry
		if is_instance_valid(beam):
			beam.visible = false
			beam.queue_free()
	lights.clear()
	for record: Dictionary in _original_overrides:
		if not is_instance_valid(record.get("lamp")):
			continue
		var lamp: MeshInstance3D = record.lamp
		if is_instance_valid(lamp):
			lamp.set_surface_override_material(record.surface, record.material)
	_original_overrides.clear()
	lamps.clear()
	lamp_materials.clear()
	_body = null

func _exit_tree() -> void:
	_clear()
