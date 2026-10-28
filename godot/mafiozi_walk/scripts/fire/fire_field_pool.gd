extends Node3D
## Prewarmed fire fields for burning objects. Eight slots, each one MultiMesh of
## flames + smoke + embers and one shader, so a fire costs one draw call per kind of
## field instead of a particle system per plank.
##
## Budget: 8 fields x 52 quads = 416 quads, two shared lights, shader parameters
## pushed at 10 Hz, and a distance LOD that drops the smoke and ember instances of a
## fire the player is not standing next to.

const FireShader = preload("res://scripts/fire/fire_spread.gdshader")
const ScorchShader = preload("res://scripts/shop/throwable_scorch.gdshader")

const CAPACITY := 8
const FLAMES := 14
const FlameTexture = preload("res://assets/fire/flame.png")
const SMOKE := 0
const EMBERS := 8
const GLOW := 0
const FIELD_MAX_SCALE := 4.2
## The field is nudged out of the burning body towards the camera: a gate leaf's
## centre is inside a 1.1 m wall, and flames drawn there are buried in the wood. The
## push clears the wall so the fire is on the face the player is looking at.
const SURFACE_PUSH := 1.25
const UPDATE_INTERVAL := 0.1
const NEAR_DISTANCE := 26.0
const FAR_DISTANCE := 55.0

var _slots: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _quad: QuadMesh
var _ground: PlaneMesh
var _next_light := 0
var _ready := false
var _updates := 0


func configure(world: Node3D) -> bool:
	if _ready or not is_instance_valid(world) or not world.is_inside_tree():
		return false
	world.add_child(self)
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_ground = PlaneMesh.new()
	_ground.size = Vector2(1.0, 1.0)
	for index: int in CAPACITY:
		var slot := _build_slot(index)
		_slots.append(slot)
	for index: int in 2:
		var light := OmniLight3D.new()
		light.name = "FireLight%02d" % index
		light.shadow_enabled = false
		light.omni_range = 7.0
		light.light_color = Color("ff8a3c")
		light.light_energy = 0.0
		light.visible = false
		add_child(light)
		_lights.append({"node": light, "slot": -1})
	_ready = true
	return true


func _build_slot(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "FireField%02d" % index
	add_child(root)
	var count := FLAMES + SMOKE + EMBERS + GLOW
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = count
	multimesh.custom_aabb = AABB(Vector3(-12.0, -2.0, -12.0), Vector3(24.0, 20.0, 24.0))
	for particle: int in count:
		var seed := fposmod(float(particle + 1) * 0.61803398875 + float(index) * 0.137, 1.0)
		var variant := fposmod(float(particle + 1) * 0.41421356237 + float(index) * 0.217, 1.0)
		var kind := 0 if particle < FLAMES else (1 if particle < FLAMES + SMOKE else (2 if particle < FLAMES + SMOKE + EMBERS else 3))
		# Flames live inside the field radius; smoke and embers start from the middle,
		# the glow hugs the ground under the fire.
		var radius: float = sqrt(variant) * 0.90 if kind == 0 else 0.25 * variant if kind == 1 else 0.10 if kind == 2 else 0.45 * variant
		var angle := TAU * seed
		var height: float = 0.08 if kind == 0 else 0.55 + variant * 0.45 if kind == 1 else 0.12 if kind == 2 else 0.05
		multimesh.set_instance_transform(particle,
			Transform3D(Basis.IDENTITY, Vector3(cos(angle) * radius, height, sin(angle) * radius)))
		multimesh.set_instance_custom_data(particle, Color(seed, float(kind), variant, 1.0))
	var material := ShaderMaterial.new()
	material.shader = FireShader
	material.set_shader_parameter("flame_texture", FlameTexture)
	var flames := MultiMeshInstance3D.new()
	flames.name = "Flames"
	flames.multimesh = multimesh
	flames.material_override = material
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	root.add_child(flames)
	var scorch_material := ShaderMaterial.new()
	scorch_material.shader = ScorchShader
	var scorch := MeshInstance3D.new()
	scorch.name = "Scorch"
	scorch.mesh = _ground
	scorch.material_override = scorch_material
	scorch.position.y = 0.02
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(scorch)
	root.visible = false
	return {"root": root, "material": material, "scorch_material": scorch_material,
		"multimesh": multimesh, "flames": flames, "scorch": scorch,
		"active": false, "last_age": -1.0, "intensity": 1.0, "scale": 2.4, "far": false}


## Light a field at a world point. `scale_m` is the width of the fire in metres: a
## gate leaf gets 2–3, a siege tower 6–7.
func ignite(at: Vector3, scale_m: float = 2.4) -> int:
	if not _ready:
		return -1
	for index: int in _slots.size():
		var slot: Dictionary = _slots[index]
		if bool(slot["active"]):
			continue
		slot["active"] = true
		slot["last_age"] = -1.0
		slot["intensity"] = 1.0
		slot["scale"] = clampf(scale_m, 1.2, FIELD_MAX_SCALE)
		slot["anchor"] = at
		var root := slot["root"] as Node3D
		root.global_position = at
		root.visible = true
		var scorch := slot["scorch"] as MeshInstance3D
		scorch.scale = Vector3.ONE * slot["scale"] * 0.55
		(slot["multimesh"] as MultiMesh).visible_instance_count = FLAMES + SMOKE + EMBERS + GLOW
		_apply_material(slot, 0.0)
		var light: Dictionary = _lights[_next_light % _lights.size()]
		_next_light += 1
		light["slot"] = index
		var node := light["node"] as OmniLight3D
		node.global_position = at + Vector3.UP * (0.6 + slot["scale"] * 0.25)
		node.omni_range = 4.0 + slot["scale"] * 1.6
		node.light_energy = 2.4
		node.visible = true
		return index
	return -1


func _apply_material(slot: Dictionary, age: float) -> void:
	var material := slot["material"] as ShaderMaterial
	material.set_shader_parameter("age_seconds", age)
	material.set_shader_parameter("intensity", slot["intensity"])
	material.set_shader_parameter("field_scale", slot["scale"])
	(slot["scorch_material"] as ShaderMaterial).set_shader_parameter("age_seconds", age)


func update_field(index: int, age: float, intensity: float, camera_position: Vector3 = Vector3.INF) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: Dictionary = _slots[index]
	if not bool(slot["active"]):
		return
	slot["intensity"] = clampf(intensity, 0.0, 1.0)
	# Shader parameters are pushed at 10 Hz: the shader animates in TIME, so a higher
	# rate only costs uniform uploads.
	if age - float(slot["last_age"]) >= UPDATE_INTERVAL:
		slot["last_age"] = age
		_apply_material(slot, age)
		_updates += 1
	var multimesh := slot["multimesh"] as MultiMesh
	if camera_position.is_finite():
		var root := slot["root"] as Node3D
		# Keep the flames on the side of the burning body the player is looking at.
		var anchor: Vector3 = slot.get("anchor", root.global_position)
		var push := camera_position - anchor
		if push.length_squared() > 0.04:
			root.global_position = anchor + push.normalized() * SURFACE_PUSH
		var distance := root.global_position.distance_squared_to(camera_position)
		var far := distance > NEAR_DISTANCE * NEAR_DISTANCE
		slot["far"] = far
		if distance > FAR_DISTANCE * FAR_DISTANCE:
			multimesh.visible_instance_count = FLAMES
		elif far:
			multimesh.visible_instance_count = FLAMES + SMOKE
		else:
			multimesh.visible_instance_count = FLAMES + SMOKE + EMBERS + GLOW
		for light: Dictionary in _lights:
			if int(light["slot"]) != index:
				continue
			var node := light["node"] as OmniLight3D
			# The light fades with the fuel and flickers: two sines, not a random call.
			# It is deliberately softer than the flames: a bald orange lamp on the wall
			# reads as a bug, the flames themselves must carry the fire.
			node.light_energy = 1.85 * slot["intensity"] * (0.88 + 0.12 * sin(age * 17.0 + float(index)))
			node.visible = not far


func stop_field(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: Dictionary = _slots[index]
	slot["active"] = false
	(slot["root"] as Node3D).visible = false
	for light: Dictionary in _lights:
		if int(light["slot"]) == index:
			light["slot"] = -1
			var node := light["node"] as OmniLight3D
			node.visible = false
			node.light_energy = 0.0


func active_count() -> int:
	var count := 0
	for slot: Dictionary in _slots:
		if bool(slot["active"]):
			count += 1
	return count


func snapshot() -> Dictionary:
	return {"ready": _ready, "active": active_count(), "capacity": CAPACITY,
		"quads_per_field": FLAMES + SMOKE + EMBERS + GLOW,
		"maximum_quads": CAPACITY * (FLAMES + SMOKE + EMBERS + GLOW),
		"draw_batches": CAPACITY * 2, "shared_lights": _lights.size(),
		"shadowed_lights": 0, "shader_updates": _updates}


func dispose() -> void:
	for index: int in _slots.size():
		stop_field(index)
	_ready = false
	_slots.clear()
	_lights.clear()
	if is_inside_tree():
		queue_free()
