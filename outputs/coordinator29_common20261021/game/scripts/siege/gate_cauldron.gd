extends Node3D
## The oil cauldron above the gate. It is a real body on a wheeled hearth: the player
## pushes it across the hoarding, and at the edge it tips over the spout and pours.
## There is no lever and no key for it.
##
## The pot, its ironwork and the cart are merged into a few meshes. Fire, steam, the
## falling oil, the splash and the burning pool are GPU particles that are off until
## the pour actually starts; the oil surface is one small animated shader.

const Layout = preload("res://scripts/siege/gate_defense_layout.gd")
const Art = preload("res://scripts/siege/gate_defense_art.gd")

const MOVE_SPEED := 0.46
const TIP_TIME := 1.15
const POUR_TIME := 7.5

var _castle: Node3D
var _player: CharacterBody3D
var _world: Node3D

var _body: AnimatableBody3D
var _cradle: Node3D
var _pot_mesh: MeshInstance3D
var _oil_surface: MeshInstance3D
var _wheels: MultiMesh
var _wheels_node: MultiMeshInstance3D
var _wheel_centres: Array[Vector3] = []
var _wheel_spin := 0.0

var _fire: GPUParticles3D
var _steam: GPUParticles3D
var _pour: GPUParticles3D
var _splash: GPUParticles3D
var _pool_fire: GPUParticles3D
var _pool_smoke: GPUParticles3D
var _stream: MeshInstance3D
var _puddle: MeshInstance3D
var _fire_light: OmniLight3D

var _z := Layout.CAULDRON_START.z
var _tip := 0.0
var _oil := 1.0
var _pushing := 0.0
var _push_hold := 0.0
var _pouring := false
var _burning := false
var _pour_time := 0.0
var _puddle_radius := 0.0
var _heat_time := 0.0
var _moved_total := 0.0

var _sfx_pour: AudioStreamWAV
var _sfx_sizzle: AudioStreamWAV
var _pour_player: AudioStreamPlayer3D
var _dust_texture: ImageTexture
var _stats := {}


func install(castle: Node3D, player: CharacterBody3D, world: Node3D) -> Dictionary:
	_castle = castle
	_player = player
	_world = world
	name = "GateCauldron"
	_dust_texture = Art.soft_texture(64)
	_sfx_pour = Art.looped_sfx(1.6, 70.0, 0.92, 31)
	_sfx_sizzle = Art.sfx(1.4, 160.0, 0.95, 2.8, -0.35, 32)
	_build_hearth()
	_build_body()
	_build_cart()
	_build_pot()
	_build_fire()
	_build_pour()
	_stats = {"z": _z, "tip": 0.0, "oil": 1.0, "pouring": false, "burning": false}
	return {"ok": true, "stats": _stats}


func get_stats() -> Dictionary:
	var result := _stats.duplicate(true)
	result["z"] = _z
	result["tip"] = _tip
	result["oil"] = _oil
	result["pouring"] = _pouring
	result["burning"] = _burning
	result["push_hold"] = _push_hold
	result["moved_total"] = _moved_total
	result["puddle_radius"] = _puddle_radius
	result["stream_visible"] = is_instance_valid(_stream) and _stream.visible
	return result


## ------------------------------------------------------------------ build

func _build_hearth() -> void:
	var stone: Material = _castle.call("shared_material", "stone")
	var parts: Array[Dictionary] = [
		Art.box(Vector3(Layout.CAULDRON_START.x, Layout.FLOOR_Y + 0.02,
			(Layout.CAULDRON_START.z + Layout.CAULDRON_END_Z) * 0.5 + 0.10),
			Vector3(1.95, 0.10, 1.75), Color(0.50, 0.48, 0.43)),
		Art.box(Vector3(Layout.CAULDRON_START.x, Layout.FLOOR_Y + 0.075,
			Layout.CAULDRON_START.z - 0.56), Vector3(1.95, 0.05, 0.16),
			Color(0.44, 0.42, 0.38))]
	var mesh := Art.box_batch(parts, stone)
	mesh.name = "CauldronHearth"
	add_child(mesh)
	# The slab is a real 7 cm step, so the player's boots do not sink into it.
	var body := StaticBody3D.new()
	body.name = "CauldronHearthCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.95, 0.10, 1.75)
	shape.shape = box
	shape.position = Vector3(Layout.CAULDRON_START.x, Layout.FLOOR_Y + 0.02,
		(Layout.CAULDRON_START.z + Layout.CAULDRON_END_Z) * 0.5 + 0.10)
	body.add_child(shape)


func _build_body() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "CauldronBody"
	_body.sync_to_physics = true
	_body.collision_layer = 1
	_body.collision_mask = 1
	_body.position = Vector3(Layout.CAULDRON_START.x, Layout.FLOOR_Y + 0.075, _z)
	add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.45, 1.55, 1.30)
	shape.shape = box
	shape.position = Vector3(0.0, 0.78, 0.0)
	_body.add_child(shape)


func _build_cart() -> void:
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.94, 0.0, true)
	var iron: Material = _castle.call("shared_material", "iron")
	var parts: Array[Dictionary] = []
	parts.append(Art.box(Vector3(0.0, 0.42, 0.0), Vector3(1.35, 0.08, 1.20),
		Color(0.36, 0.235, 0.135)))
	for side: float in [-1.0, 1.0]:
		parts.append(Art.box(Vector3(side * 0.56, 0.29, 0.0), Vector3(0.12, 0.17, 1.22),
			Color(0.30, 0.19, 0.11)))
		parts.append(Art.box(Vector3(side * 0.52, 0.70, -0.66), Vector3(0.08, 0.42, 0.08),
			Color(0.32, 0.20, 0.115)))
	for z: float in [-0.40, 0.40]:
		parts.append(Art.box(Vector3(0.0, 0.29, z), Vector3(1.30, 0.15, 0.12),
			Color(0.30, 0.19, 0.11)))
	parts.append(Art.box(Vector3(0.0, 0.92, -0.66), Vector3(1.16, 0.07, 0.09),
		Color(0.36, 0.235, 0.135)))
	# Deck seams and iron corner plates: a cart, not a crate.
	for i: int in 6:
		var x: float = -0.50 + float(i) * 0.20
		parts.append(Art.box(Vector3(x, 0.472, 0.0), Vector3(0.018, 0.012, 1.16),
			Color(0.20, 0.125, 0.070)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append(Art.box(Vector3(sx * 0.61, 0.47, sz * 0.54),
				Vector3(0.18, 0.035, 0.18), Color(0.24, 0.255, 0.28)))
	var cart := Art.box_batch(parts, wood)
	cart.name = "CauldronCart"
	_body.add_child(cart)
	var iron_parts: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.48, 0.48]:
			iron_parts.append(Art.box(Vector3(side * 0.66, 0.24, z),
				Vector3(0.18, 0.18, 0.18), Color(0.29, 0.30, 0.33)))
	iron_parts.append(Art.box(Vector3(0.0, 0.885, -0.66), Vector3(1.16, 0.045, 0.13),
		Color(0.26, 0.275, 0.30)))
	var fittings := Art.box_batch(iron_parts, iron)
	fittings.name = "CauldronCartIron"
	_body.add_child(fittings)
	# Four wheels, one MultiMesh: they spin as the cart rolls.
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.215
	wheel_mesh.bottom_radius = 0.215
	wheel_mesh.height = 0.12
	wheel_mesh.radial_segments = 18
	_wheels = MultiMesh.new()
	_wheels.transform_format = MultiMesh.TRANSFORM_3D
	_wheels.mesh = wheel_mesh
	_wheels.instance_count = 4
	_wheels_node = MultiMeshInstance3D.new()
	_wheels_node.name = "CauldronWheels"
	_wheels_node.multimesh = _wheels
	_wheels_node.material_override = Art.tinted(Color(0.24, 0.20, 0.15), 0.9)
	_body.add_child(_wheels_node)
	var index := 0
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.40, 0.40]:
			_wheel_centres.append(Vector3(side * 0.56, 0.22, z))
			_wheels.set_instance_transform(index, Transform3D(
				Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(side * 0.56, 0.22, z)))
			index += 1


func _build_pot() -> void:
	_cradle = Node3D.new()
	_cradle.name = "CauldronCradle"
	_cradle.position = Vector3(0.0, 1.00, 0.42)
	_body.add_child(_cradle)
	var profile: Array[Vector2] = [
		Vector2(0.00, -0.48), Vector2(0.24, -0.46), Vector2(0.42, -0.37),
		Vector2(0.55, -0.21), Vector2(0.64, -0.01), Vector2(0.70, 0.18),
		Vector2(0.74, 0.33), Vector2(0.77, 0.44), Vector2(0.75, 0.51),
		Vector2(0.69, 0.51), Vector2(0.63, 0.37), Vector2(0.51, 0.08),
		Vector2(0.34, -0.21), Vector2(0.00, -0.27)]
	var colors: Array[Color] = []
	for ring: int in profile.size():
		var value: float = clampf(float(ring) / float(profile.size() - 1), 0.0, 1.0)
		colors.append(Color(0.10, 0.095, 0.09).lerp(Color(0.30, 0.30, 0.31), value))
	var iron_material := StandardMaterial3D.new()
	iron_material.vertex_color_use_as_albedo = true
	iron_material.metallic = 0.72
	iron_material.roughness = 0.46
	iron_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pot_mesh = MeshInstance3D.new()
	_pot_mesh.name = "CauldronPot"
	_pot_mesh.mesh = Art.lathe(profile, 26, colors)
	_pot_mesh.material_override = iron_material
	_cradle.add_child(_pot_mesh)
	# Iron bands and handles: one extra draw call.
	var bands: Array[Dictionary] = []
	for band: Vector3 in [Vector3(0.0, -0.12, 0.600), Vector3(0.0, 0.14, 0.682),
			Vector3(0.0, 0.38, 0.735)]:
		var torus := TorusMesh.new()
		torus.inner_radius = float(band.z) - 0.035
		torus.outer_radius = float(band.z) + 0.035
		torus.rings = 8
		torus.ring_segments = 22
		bands.append({"mesh": torus, "xf": Transform3D(Basis.IDENTITY,
			Vector3(0.0, band.y, 0.0))})
	for side: float in [-1.0, 1.0]:
		var handle := TorusMesh.new()
		handle.inner_radius = 0.09
		handle.outer_radius = 0.14
		handle.rings = 8
		handle.ring_segments = 14
		bands.append({"mesh": handle, "xf": Transform3D(
			Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(side * 0.78, 0.40, 0.0))})
	var spout := TorusMesh.new()
	spout.inner_radius = 0.16
	spout.outer_radius = 0.24
	spout.rings = 6
	spout.ring_segments = 14
	bands.append({"mesh": spout, "xf": Transform3D(
		Basis(Vector3(1, 0, 0), 0.55), Vector3(0.0, 0.42, 0.82))})
	# Hand-forged rivets: the same iron mesh, no extra draw call.
	var rivet := BoxMesh.new()
	rivet.size = Vector3(0.055, 0.045, 0.055)
	for i: int in 18:
		var angle := TAU * float(i) / 18.0
		bands.append({"mesh": rivet, "xf": Transform3D(
			Basis(Vector3(0, 1, 0), angle),
			Vector3(cos(angle) * 0.775, 0.47, sin(angle) * 0.775))})
	for i: int in 12:
		var angle := TAU * float(i) / 12.0
		bands.append({"mesh": rivet, "xf": Transform3D(
			Basis(Vector3(0, 1, 0), angle),
			Vector3(cos(angle) * 0.655, -0.10, sin(angle) * 0.655))})
	var band_mesh := Art.merge_meshes(bands, Art.tinted(Color(0.34, 0.345, 0.36), 0.44, 0.75))
	band_mesh.name = "CauldronIronwork"
	_cradle.add_child(band_mesh)
	# The oil surface: a small animated disc, not a liquid simulation.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float heat = 1.0;
void fragment() {
	ALBEDO = vec3(0.030, 0.021, 0.009);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	EMISSION = vec3(0.0);
}
"""
	var oil_material := ShaderMaterial.new()
	oil_material.shader = shader
	oil_material.set_shader_parameter("heat", 1.0)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.60
	disc.bottom_radius = 0.60
	disc.height = 0.02
	disc.radial_segments = 24
	_oil_surface = MeshInstance3D.new()
	_oil_surface.name = "CauldronOil"
	_oil_surface.mesh = disc
	_oil_surface.material_override = oil_material
	_oil_surface.position = Vector3(0.0, 0.34, 0.0)
	_cradle.add_child(_oil_surface)
	# Small painted instruction on the push rail, facing the walkway.
	var hint := Label3D.new()
	hint.text = "ТОЛКНИ"
	hint.font_size = 30
	hint.pixel_size = 0.0026
	hint.modulate = Color(0.78, 0.64, 0.38)
	hint.outline_size = 6
	hint.outline_modulate = Color(0.10, 0.07, 0.04)
	hint.double_sided = true
	hint.position = Vector3(0.0, 0.72, -0.73)
	hint.rotation.y = PI
	_body.add_child(hint)


func _build_fire() -> void:
	var coals := CylinderMesh.new()
	coals.top_radius = 0.40
	coals.bottom_radius = 0.50
	coals.height = 0.09
	coals.radial_segments = 16
	var coal_mesh := MeshInstance3D.new()
	coal_mesh.name = "CauldronCoals"
	coal_mesh.mesh = coals
	var coal_material := StandardMaterial3D.new()
	coal_material.albedo_color = Color(0.10, 0.075, 0.06)
	coal_material.emission_enabled = true
	coal_material.emission = Color(0.95, 0.32, 0.06)
	coal_material.emission_energy_multiplier = 0.18
	coal_material.roughness = 0.95
	coal_mesh.material_override = coal_material
	coal_mesh.position = Vector3(0.0, 0.42, 0.0)
	_body.add_child(coal_mesh)
	_fire = Art.particles(18, 0.66, _dust_texture, true,
		[[0.0, Color(1.0, 0.85, 0.32, 0.0)], [0.12, Color(1.0, 0.62, 0.16, 0.85)],
		[0.55, Color(0.95, 0.26, 0.04, 0.55)], [1.0, Color(0.22, 0.05, 0.01, 0.0)]],
		Vector2(0.4, 1.0), 38.0, Vector3(0.0, 0.8, 0.0), Vector2(0.18, 0.46),
		false, true, 0.30)
	_fire.name = "CauldronFlame"
	_fire.position = Vector3(0.0, 0.44, 0.0)
	_body.add_child(_fire)
	# A second small flame at the open front of the hearth, where the fire can be seen
	# licking past the pot instead of being hidden under it.
	var front_flame := Art.particles(10, 0.58, _dust_texture, true,
		[[0.0, Color(1.0, 0.86, 0.34, 0.0)], [0.14, Color(1.0, 0.58, 0.14, 0.8)],
		[0.55, Color(0.92, 0.22, 0.03, 0.45)], [1.0, Color(0.20, 0.04, 0.0, 0.0)]],
		Vector2(0.35, 0.8), 30.0, Vector3(0.0, 0.5, 0.0), Vector2(0.16, 0.38),
		false, true, 0.18)
	front_flame.name = "CauldronFrontFlame"
	front_flame.position = Vector3(0.0, 0.42, 0.98)
	_body.add_child(front_flame)
	_steam = Art.particles(8, 2.2, _dust_texture, false,
		[[0.0, Color(0.86, 0.84, 0.80, 0.0)], [0.25, Color(0.86, 0.84, 0.80, 0.14)],
		[1.0, Color(0.80, 0.80, 0.78, 0.0)]],
		Vector2(0.15, 0.45), 22.0, Vector3(0.0, 0.30, 0.0), Vector2(0.22, 0.52),
		false, true, 0.26)
	_steam.name = "CauldronSteam"
	_steam.position = Vector3(0.0, 1.38, 0.0)
	_body.add_child(_steam)
	_fire_light = OmniLight3D.new()
	_fire_light.name = "CauldronFireLight"
	_fire_light.light_color = Color(1.0, 0.55, 0.20)
	_fire_light.light_energy = 1.05
	_fire_light.omni_range = 3.4
	_fire_light.position = Vector3(0.0, 0.62, 0.0)
	_body.add_child(_fire_light)


func _build_pour() -> void:
	_pour = Art.particles(72, 1.9, _dust_texture, false,
		[[0.0, Color(0.14, 0.095, 0.035, 0.0)], [0.08, Color(0.16, 0.105, 0.038, 0.95)],
		[0.75, Color(0.10, 0.065, 0.022, 0.9)], [1.0, Color(0.05, 0.035, 0.012, 0.0)]],
		Vector2(2.6, 4.4), 6.0, Vector3(0.25, -9.8, 0.55), Vector2(0.10, 0.24),
		false, false, 0.08)
	_pour.name = "CauldronPour"
	var pour_process := _pour.process_material as ParticleProcessMaterial
	if pour_process != null:
		pour_process.direction = Vector3(0.10, -1.0, 0.34).normalized()
	_pour.position = Layout.OIL_SPOUT
	add_child(_pour)
	_splash = Art.particles(26, 0.62, _dust_texture, false,
		[[0.0, Color(0.18, 0.12, 0.045, 0.0)], [0.2, Color(0.20, 0.135, 0.05, 0.75)],
		[1.0, Color(0.08, 0.05, 0.015, 0.0)]],
		Vector2(1.0, 3.0), 68.0, Vector3(0.0, -6.0, 0.0), Vector2(0.08, 0.20),
		false, false, 0.10)
	_splash.name = "CauldronSplash"
	_splash.position = Layout.OIL_IMPACT
	add_child(_splash)
	_stream = MeshInstance3D.new()
	_stream.name = "CauldronStream"
	var stream_mesh := CylinderMesh.new()
	stream_mesh.top_radius = 0.055
	stream_mesh.bottom_radius = 0.085
	stream_mesh.height = 1.0
	stream_mesh.radial_segments = 8
	_stream.mesh = stream_mesh
	var stream_material := StandardMaterial3D.new()
	stream_material.albedo_color = Color(0.115, 0.075, 0.025)
	stream_material.roughness = 0.15
	stream_material.metallic = 0.05
	_stream.material_override = stream_material
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stream.visible = false
	add_child(_stream)
	_puddle = MeshInstance3D.new()
	_puddle.name = "CauldronPuddle"
	var puddle_mesh := CylinderMesh.new()
	puddle_mesh.top_radius = 1.0
	puddle_mesh.bottom_radius = 1.0
	puddle_mesh.height = 0.02
	puddle_mesh.radial_segments = 28
	_puddle.mesh = puddle_mesh
	var puddle_material := StandardMaterial3D.new()
	puddle_material.albedo_color = Color(0.040, 0.030, 0.018)
	puddle_material.roughness = 0.12
	puddle_material.metallic = 0.0
	_puddle.material_override = puddle_material
	_puddle.position = Layout.OIL_IMPACT + Vector3.UP * 0.02
	_puddle.scale = Vector3(0.1, 1.0, 0.1)
	_puddle.visible = false
	add_child(_puddle)
	_pool_fire = Art.particles(34, 1.1, _dust_texture, true,
		[[0.0, Color(1.0, 0.80, 0.25, 0.0)], [0.16, Color(1.0, 0.52, 0.10, 0.9)],
		[0.6, Color(0.9, 0.20, 0.02, 0.6)], [1.0, Color(0.18, 0.03, 0.0, 0.0)]],
		Vector2(0.8, 2.2), 45.0, Vector3(0.0, 1.4, 0.0), Vector2(0.5, 1.3),
		false, false, 0.55)
	_pool_fire.name = "CauldronPoolFire"
	_pool_fire.position = Layout.OIL_IMPACT + Vector3.UP * 0.08
	add_child(_pool_fire)
	_pool_smoke = Art.particles(14, 2.8, _dust_texture, false,
		[[0.0, Color(0.16, 0.15, 0.14, 0.0)], [0.3, Color(0.18, 0.17, 0.16, 0.35)],
		[1.0, Color(0.10, 0.10, 0.10, 0.0)]],
		Vector2(0.5, 1.2), 32.0, Vector3(0.0, 0.8, 0.0), Vector2(0.8, 1.8),
		false, false, 0.55)
	_pool_smoke.name = "CauldronPoolSmoke"
	_pool_smoke.position = Layout.OIL_IMPACT + Vector3.UP * 0.55
	add_child(_pool_smoke)


## ------------------------------------------------------------------ movement

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_body):
		return
	var local := to_local(_player.global_position)
	var back := Vector3(Layout.CAULDRON_START.x, Layout.FLOOR_Y + 0.85, _z - 0.86)
	var pushing_now := local.distance_to(back) < 1.55 and local.z < _z - 0.35 \
		and _player.velocity.z > 0.12
	_pushing = 1.0 if pushing_now else 0.0
	if not _pouring and _z < Layout.CAULDRON_END_Z - 0.01 and pushing_now:
		var speed := MOVE_SPEED * clampf(_player.velocity.z / 2.2, 0.35, 1.0)
		var step := minf(speed * delta, Layout.CAULDRON_END_Z - _z)
		if _can_move_to(_z + step):
			_z += step
			_moved_total += step
			_wheel_spin += step / 0.245
			_body.position.z = _z
	if _z >= Layout.CAULDRON_END_Z - 0.02 and pushing_now and _tip < 0.02:
		_push_hold += delta
		if _push_hold > 0.48:
			_start_pour()
	else:
		_push_hold = maxf(0.0, _push_hold - delta * 0.7)
	if _tip > 0.0:
		_tip = move_toward(_tip, 1.0, delta / TIP_TIME)
		_cradle.rotation.x = -1.72 * smoothstep(0.0, 1.0, _tip)


## The cauldron is a physical body, but it is driven along its hearth. Before every
## step the destination is queried with the body's own footprint, raised above the deck
## so the floor is not counted. A rail, a merlon or a body in the way stops the push
## instead of letting the pot pass through it.
func _can_move_to(next_z: float) -> bool:
	if not is_instance_valid(_body):
		return false
	var space := _body.get_world_3d().direct_space_state
	if space == null:
		return true
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.50, 1.05, 1.20)
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, _body.global_position + Vector3(
		0.0, 0.98, next_z - _z))
	params.exclude = [_body.get_rid()]
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return space.intersect_shape(params, 8).is_empty()


func _start_pour() -> void:
	if _pouring:
		return
	_pouring = true
	_tip = maxf(_tip, 0.02)
	_oil_surface.visible = true
	_pour.emitting = true
	_splash.emitting = true
	_stream.visible = true
	_puddle.visible = true
	if _pour_player == null:
		_pour_player = Art.play_3d(self, _sfx_pour,
			to_global(Layout.OIL_IMPACT + Vector3.UP * 1.5), -4.0, 0.9, 70.0)


func _process(delta: float) -> void:
	_heat_time += delta
	if is_instance_valid(_fire_light):
		_fire_light.light_energy = 2.05 + sin(_heat_time * 16.0) * 0.30 \
			+ sin(_heat_time * 27.0 + 1.3) * 0.15
	if _moved_total > 0.001:
		_update_wheels()
		_moved_total = 0.0
	if not _pouring:
		return
	_oil = maxf(0.0, _oil - delta / POUR_TIME)
	_pour_time += delta
	_puddle_radius = minf(2.35, 0.18 + _pour_time * 0.42)
	_puddle.scale = Vector3(_puddle_radius, 1.0, _puddle_radius)
	if _oil <= 0.0:
		_pour.emitting = false
		_splash.emitting = false
		_stream.visible = false
		_oil_surface.visible = false
		if _pour_player != null and _pour_player.playing:
			_pour_player.stop()
	if _pour_time > 0.9 and not _burning:
		_burning = true
		_pool_fire.emitting = true
		_pool_smoke.emitting = true
		Art.play_3d(self, _sfx_sizzle, to_global(Layout.OIL_IMPACT + Vector3.UP * 0.5),
			0.0, 1.0, 60.0)
		var fire_light := OmniLight3D.new()
		fire_light.name = "OilFireLight"
		fire_light.light_color = Color(1.0, 0.48, 0.14)
		fire_light.light_energy = 2.4
		fire_light.omni_range = 8.0
		fire_light.position = Layout.OIL_IMPACT + Vector3.UP * 1.0
		add_child(fire_light)
	_update_stream()


func _update_wheels() -> void:
	if _wheels == null:
		return
	for index: int in _wheel_centres.size():
		var centre: Vector3 = _wheel_centres[index]
		_wheels.set_instance_transform(index, Transform3D(
			Basis(Vector3(1, 0, 0), -_wheel_spin) * Basis(Vector3(0, 0, 1), PI * 0.5),
			centre))


func _update_stream() -> void:
	if not _stream.visible:
		return
	# The pot is tipped, so the spout itself moves: use its actual transform.
	var spout_local := Vector3(0.0, 0.42, 0.82)
	var to: Vector3 = _body.to_global(_cradle.position + _cradle.basis * spout_local)
	var fall := Vector3(0.10, -1.0, 0.30).normalized()
	var end: Vector3 = Vector3(to.x + fall.x * 3.2, maxf(0.06, to.y - 3.2), to.z + fall.z * 3.2)
	var direction := end - to
	var length := maxf(0.1, direction.length())
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
	_stream.global_transform = Transform3D(basis, (to + end) * 0.5)
	_stream.scale = Vector3(1.0, length, 1.0)
	_pour.global_position = to


## ------------------------------------------------------------------ response

func is_tipping() -> bool:
	return _tip > 0.01
