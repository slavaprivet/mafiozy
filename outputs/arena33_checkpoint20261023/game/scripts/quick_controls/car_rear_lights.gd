extends Node
## Reads accepted controls after the transport tick; never submits physics input.
## The frozen hatchback export has empty Taillamp nodes. Restore the authored
## lens size on its existing corner mounts, preserving their transforms.
const LENS_SIZE := Vector3(0.19488, 0.15, 0.075)
const RED := Color(1.0, 0.018, 0.006)
var ready_for_play := false
var braking := false
var reversing := false
var tail_on := false
var lenses: Array[MeshInstance3D] = []
var reverse_lenses: Array[MeshInstance3D] = []
var reverse_beam: SpotLight3D
var _mounts: Array[Node3D] = []
var _red: StandardMaterial3D
var _white: StandardMaterial3D
var _world: Node
var _transport: Node
var _body: RigidBody3D
var _generation := -1
var state_changes := 0

func configure(world: Node, transport: Node) -> bool:
	_clear()
	_world = world
	_transport = transport
	set_process(false)
	set_physics_process(false)
	if not is_instance_valid(transport) or not is_instance_valid(transport.body) or not is_instance_valid(transport.visual): return false
	# This bounded restoration is for the actual delivered car, not a guessed fleet fit.
	if transport.visual.profile_id != "city_hatchback": return false
	_body = transport.body
	_generation = int(_body.get_meta("life_generation", -1))
	for candidate: Variant in transport.visual.nodes.values():
		if candidate is MeshInstance3D and str(candidate.get_meta("source_name", "")).begins_with("Rear_corner_lamp_mount_"):
			_mounts.append(candidate)
	if _mounts.size() != 2:
		_clear(); return false
	_red = StandardMaterial3D.new()
	_red.albedo_color = Color(0.38, 0.014, 0.006)
	_red.roughness = 0.28
	_red.emission = RED
	_red.emission_enabled = true
	_red.emission_energy_multiplier = 0.0
	_white = StandardMaterial3D.new()
	_white.albedo_color = Color(0.64, 0.69, 0.72)
	_white.roughness = 0.28
	_white.emission = Color(0.92, 0.95, 1.0)
	_white.emission_enabled = true
	_white.emission_energy_multiplier = 0.0
	var lens_mesh := BoxMesh.new()
	lens_mesh.size = LENS_SIZE
	lens_mesh.material = _red
	var reverse_mesh := BoxMesh.new()
	reverse_mesh.size = Vector3(LENS_SIZE.x * 0.82, 0.043, 0.008)
	reverse_mesh.material = _white
	var rear_center := Vector3.ZERO
	for mount: Node3D in _mounts:
		var body_from_mount: Transform3D = _body.global_transform.affine_inverse() * mount.global_transform
		var bounds: AABB = body_from_mount * mount.get_aabb()
		var center := Vector3(bounds.get_center().x, bounds.end.y - 0.11, bounds.end.z + 0.002)
		var lens := MeshInstance3D.new()
		lens.name = "RestoredRearLens"
		lens.mesh = lens_mesh
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.transform = body_from_mount.affine_inverse() * Transform3D(Basis.IDENTITY, center)
		mount.add_child(lens)
		lenses.append(lens)
		var white := MeshInstance3D.new()
		white.name = "ReverseLens"
		white.mesh = reverse_mesh
		white.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		white.position = Vector3(0.0, -0.044, LENS_SIZE.z * 0.5 + 0.003)
		lens.add_child(white)
		reverse_lenses.append(white)
		rear_center += center * 0.5
	reverse_beam = SpotLight3D.new()
	reverse_beam.name = "ReverseRoadLight"
	reverse_beam.position = rear_center + Vector3(0.0, 0.0, 0.09)
	reverse_beam.rotation = Vector3(-0.22, PI, 0.0)
	reverse_beam.light_color = Color(0.92, 0.95, 1.0)
	reverse_beam.light_energy = 2.2
	reverse_beam.spot_range = 5.0
	reverse_beam.spot_angle = 55.0
	reverse_beam.spot_attenuation = 1.2
	reverse_beam.shadow_enabled = false
	reverse_beam.light_bake_mode = Light3D.BAKE_DISABLED
	reverse_beam.visible = false
	_body.add_child(reverse_beam)
	ready_for_play = true
	return true

func update_lights(tail_enabled: bool) -> void:
	if not ready_for_play: return
	if not is_instance_valid(_body) or not _body.is_inside_tree() or not is_instance_valid(_transport) or _transport.body != _body or int(_body.get_meta("life_generation", -1)) != _generation:
		_clear(); return
	for entry: Variant in _mounts:
		if not is_instance_valid(entry) or not entry.is_visible_in_tree():
			_set_state(false, false, false); return
	var live: bool = is_instance_valid(_world) and not _world.preview_dead and not _world.preview_physics_fault
	var driving: bool = live and _transport.ready_for_play and _transport.phase == "SEATED" and _transport.active_seat == "front_left"
	var brake := false
	var reverse := false
	if driving:
		var pedal: float = _body._throttle
		var speed: float = _body.linear_velocity.dot(-_body.global_basis.z.normalized())
		var opposite := pedal * speed < -0.02
		brake = _body._brake > 0.0001 or _body._handbrake or opposite
		reverse = pedal < -0.0001 and not opposite
	_set_state(brake, reverse, live and tail_enabled)

func _set_state(brake: bool, reverse: bool, tail: bool) -> void:
	if braking == brake and reversing == reverse and tail_on == tail: return
	braking = brake
	reversing = reverse
	tail_on = tail
	state_changes += 1
	# Keep one warmed material variant; state changes only adjust scalar energy.
	_red.emission_energy_multiplier = 2.7 if brake else (0.5 if tail else 0.0)
	_white.emission_energy_multiplier = 2.0 if reverse else 0.0
	if is_instance_valid(reverse_beam): reverse_beam.visible = reverse

func _clear() -> void:
	ready_for_play = false
	braking = false
	reversing = false
	tail_on = false
	if is_instance_valid(reverse_beam):
		reverse_beam.visible = false
		reverse_beam.queue_free()
	reverse_beam = null
	for entry: Variant in lenses:
		if is_instance_valid(entry):
			entry.visible = false
			entry.queue_free()
	lenses.clear()
	reverse_lenses.clear()
	_mounts.clear()
	_body = null

func _exit_tree() -> void:
	_clear()
