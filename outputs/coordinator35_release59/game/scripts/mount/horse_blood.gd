extends RefCounted
## Cosmetic horse blood. One MultiMesh, one draw call, no per-hit nodes.
## Same readability profile as the resident blood (dark red, .95 alpha) but no
## skeleton is required: the burst is emitted in world space and falls to the
## ground height sampled once per hit.

const CAPACITY := 96
const LIGHT_BURST := 18
const HEAVY_BURST := 34

var mesh: MultiMeshInstance3D
var active := 0
var emitted := 0

var _life := PackedFloat32Array()
var _pos := PackedVector3Array()
var _velocity := PackedVector3Array()
var _floor := PackedFloat32Array()
var _buffer := PackedFloat32Array()
var _cursor := 0
var _has_particles := false

func configure(parent: Node3D) -> bool:
	if mesh != null or not is_instance_valid(parent):
		return false
	var sphere := SphereMesh.new()
	sphere.radius = 0.036
	sphere.height = 0.072
	sphere.radial_segments = 6
	sphere.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.055, 0.075, 0.95)
	material.roughness = 0.55
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = material
	_life.resize(CAPACITY)
	_pos.resize(CAPACITY)
	_velocity.resize(CAPACITY)
	_floor.resize(CAPACITY)
	_buffer.resize(CAPACITY * 12)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = sphere
	instances.instance_count = CAPACITY
	instances.visible_instance_count = 0
	mesh = MultiMeshInstance3D.new()
	mesh.name = "HorseBloodParticles"
	mesh.multimesh = instances
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.top_level = true
	mesh.global_transform = Transform3D.IDENTITY
	return true

## `floor_y` is the ground under the burst; drops stop there instead of falling
## through the world.
func burst(point: Vector3, normal: Vector3, heavy: bool, floor_y: float) -> void:
	if mesh == null or not point.is_finite() or not is_finite(floor_y):
		return
	var count := HEAVY_BURST if heavy else LIGHT_BURST
	if point.y - floor_y < 0.15:
		floor_y = point.y - 0.15
	for index: int in count:
		var slot := _cursor % CAPACITY
		_cursor += 1
		emitted += 1
		var angle := float(_cursor) * 2.399963
		var speed := 1.1 + float(index % 5) * 0.36
		_life[slot] = 0.55 + float(index % 4) * 0.1
		_pos[slot] = point
		_velocity[slot] = Vector3(sin(angle) * speed, 0.9 + float(index % 4) * 0.42, cos(angle) * speed)
		if normal.length_squared() > 0.0001:
			_velocity[slot] += normal.normalized() * 0.75
		_floor[slot] = floor_y
	_has_particles = true

func update(delta: float) -> void:
	if mesh == null:
		return
	if not _has_particles:
		active = 0
		return
	var dt := clampf(delta, 0.0, 0.12)
	active = 0
	for index: int in CAPACITY:
		if _life[index] <= 0.0:
			continue
		_life[index] -= dt
		if _life[index] <= 0.0:
			continue
		_velocity[index].y -= 9.8 * dt
		_pos[index] += _velocity[index] * dt
		if _pos[index].y < _floor[index]:
			_pos[index].y = _floor[index]
			_life[index] = 0.0
			continue
		var scale := Vector3(0.8, 1.4, 0.8) * minf(1.0, _life[index] * 7.0)
		var at := active * 12
		_buffer[at] = scale.x
		_buffer[at + 3] = _pos[index].x
		_buffer[at + 5] = scale.y
		_buffer[at + 7] = _pos[index].y
		_buffer[at + 10] = scale.z
		_buffer[at + 11] = _pos[index].z
		active += 1
	_has_particles = active > 0
	mesh.multimesh.buffer = _buffer
	mesh.multimesh.visible_instance_count = active

func clear() -> void:
	_life.fill(0.0)
	_has_particles = false
	active = 0
	if is_instance_valid(mesh):
		mesh.multimesh.visible_instance_count = 0

func dispose() -> void:
	clear()
	if is_instance_valid(mesh):
		mesh.free()
	mesh = null
