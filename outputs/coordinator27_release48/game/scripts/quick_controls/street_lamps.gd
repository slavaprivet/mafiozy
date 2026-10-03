extends Node
## Bounded local presentation, attached to the eight existing Bellini source IDs.
## Accepted native projectile terminals own breaks; no input/raycast replacement.
const Lantern = preload("street_lamp_visual.gd")
const GlassSound = preload("street_glass_sound.gd")
const SESSION_KEY := &"mafiozi_broken_street_glass_v1"
const SHOT_CAP := 224
const BURSTS := 4
const SHARDS_PER_BURST := 12
const NIGHT_ENERGY := 7.5
const POLE_MESH_NAMES := ["Lamp_Lower_BELLINI", "Lamp_Upper_BELLINI", "Lamp_Arm_BELLINI"]
# The three authored meshes are shared by all eight lamps and scene reloads.
static var _pole_mesh_shapes: Dictionary = {}
# Motion recipes are immutable; all four bursts reuse the same twelve shards.
static var _shard_base_velocities := PackedVector3Array()
static var _shard_angles := PackedFloat64Array()
static var _shard_base_sizes := PackedFloat64Array()
var ready_for_play := false
var entries: Array[Dictionary] = []
var power := 0.0
var sound: Node
var breaks := 0
var rejected := 0
var world: Node3D
var _weapons: Node
var _effects: RefCounted
var _broken: Dictionary = {}
var _by_collider: Dictionary = {}
var _shots: Dictionary = {}
var _shot_order: Array[String] = []
var _epoch := -1
var _originals: Array[Dictionary] = []
var _debris: MultiMeshInstance3D
var _bursts: Array[Dictionary] = []
var _burst_cursor := 0
var _floor_query := PhysicsRayQueryParameters3D.new()

func _init() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)

func configure(game: Node3D) -> bool:
	if ready_for_play or not is_instance_valid(game): return false
	# Frozen24e ships without static batching. Do not unbatch the entire city as
	# a hidden performance side effect if a future host enables that feature.
	if game.get("_static_batch_lease") != null: return false
	world = game
	_weapons = world.get("preview_weapons")
	if not is_instance_valid(_weapons) or not _weapons.ready_for_play: return false
	_effects = _weapons.effects
	if not is_instance_valid(_effects) or not _effects.has_signal("projectile_resolved"): return false
	for node in get_tree().get_nodes_in_group("mafiozi_street_lamps"):
		if node != self and node.get("world") == world: return false
	power = 0.0
	_broken = get_tree().root.get_meta(SESSION_KEY, {})
	get_tree().root.set_meta(SESSION_KEY, _broken)
	for owner in game.get_children():
		if not owner is Node3D or not str(owner.get_meta("source_id", "")).begins_with("LAMP-"): continue
		var bell := owner.find_child("Bell_BELLINI", true, false) as MeshInstance3D
		var glow := owner.find_child("Glow_BELLINI", true, false) as MeshInstance3D
		if bell == null or glow == null: continue
		var id := str(owner.get_meta("source_id"))
		var pole_body := _pole_collider(owner)
		if pole_body == null: dispose(); return false
		var visual: Dictionary = Lantern.build()
		owner.add_child(visual.root)
		_originals.append({"node": bell, "visible": bell.visible})
		_originals.append({"node": glow, "visible": glow.visible})
		bell.hide(); glow.hide()
		var glass_body := _collider(visual.root, visual.hit_shapes, "glass", "Glass_" + id)
		var metal_body := _collider(visual.root, visual.metal_hit_shapes, "metal", "Frame_" + id)
		var light := SpotLight3D.new()
		light.name = "WarmStreetLight"
		light.rotation.x = -PI * 0.5
		light.light_color = Color(1.0, 0.69, 0.38)
		light.light_energy = 0.0
		light.spot_range = 11.5
		light.spot_angle = 57.0
		light.spot_angle_attenuation = 0.8
		light.spot_attenuation = 1.15
		light.shadow_enabled = false
		light.light_bake_mode = Light3D.BAKE_DISABLED
		light.distance_fade_enabled = true
		light.distance_fade_begin = 48.0
		light.distance_fade_length = 14.0
		light.visible = false
		visual.light_anchor.add_child(light)
		var entry := {"id": id, "owner": owner, "visual": visual, "glass_body": glass_body,
			"metal_body": metal_body, "pole_body": pole_body, "light": light, "broken": bool(_broken.get(id, false))}
		entries.append(entry)
		if entry.broken:
			glass_body.collision_layer = 0
			glass_body.queue_free()
			Lantern.set_power(visual, 0.0, true)
		else: _by_collider[glass_body.get_instance_id()] = entries.size() - 1
	if entries.is_empty(): dispose(); return false
	sound = GlassSound.new()
	add_child(sound)
	if not sound.configure(world): dispose(); return false
	_prepare_debris()
	_epoch = _effects.resolution_epoch()
	_weapons.shot_emitted.connect(_on_shot)
	_effects.projectile_resolved.connect(_on_resolution)
	add_to_group("mafiozi_street_lamps")
	ready_for_play = true
	return true

func _collider(parent: Node3D, shapes: Array, surface: String, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 4
	body.collision_mask = 0
	body.set_meta("impactSurface", surface)
	for spec: Dictionary in shapes:
		var collider := CollisionShape3D.new()
		collider.shape = spec.shape
		collider.transform = spec.transform
		body.add_child(collider)
	parent.add_child(body)
	return body

func _pole_collider(owner: Node3D) -> StaticBody3D:
	var specs: Array[Dictionary] = []
	for mesh_name: String in POLE_MESH_NAMES:
		var retained := owner.find_child(mesh_name, true, false) as MeshInstance3D
		if retained == null or retained.mesh == null: return null
		var mesh: Mesh = retained.mesh
		if not _pole_mesh_shapes.has(mesh):
			# These authored parts are convex, faceted cylinders: lower r=.22/h3.45,
			# upper r=.15/h3, arm r=.11/h1.30. Use their real vertices and transforms
			# to preserve the visible silhouette, including the arm's -90 degree Z turn.
			var points := PackedVector3Array()
			for surface: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(surface)
				points.append_array(arrays[Mesh.ARRAY_VERTEX])
			if points.is_empty(): return null
			var shape := ConvexPolygonShape3D.new()
			shape.points = points
			_pole_mesh_shapes[mesh] = shape
		var relative: Transform3D = owner.global_transform.affine_inverse() * retained.global_transform
		specs.append({"shape": _pole_mesh_shapes[mesh], "transform": relative})
	# Projectile layer only; the existing source base keeps movement authority.
	return _collider(owner, specs, "metal", "StreetPoleHit")

func apply_daylight(daylight: float) -> void:
	if not ready_for_play or not is_finite(daylight): return
	var next_power := 1.0 - smoothstep(0.20, 0.58, clampf(daylight, 0.0, 1.0))
	if absf(next_power - power) < 0.00001: return
	power = next_power
	for entry: Dictionary in entries:
		var intact: bool = not entry.broken
		if not is_instance_valid(entry.light): continue
		entry.light.light_energy = NIGHT_ENERGY * power if intact else 0.0
		entry.light.visible = intact and power > 0.0001
		Lantern.set_power(entry.visual, power, entry.broken)

func _on_shot(shot: Dictionary, _muzzle: Dictionary, _origin: Vector3, _direction: Vector3) -> void:
	if not ready_for_play or shot.get("weaponId") == "rpg": return
	var epoch: int = _effects.resolution_epoch()
	if epoch != _epoch:
		_epoch = epoch; _shots.clear(); _shot_order.clear()
	var id := str(shot.get("shotId", ""))
	var projectiles: Array = shot.get("projectiles", [])
	if id.is_empty() or projectiles.is_empty() or projectiles.size() > 32: return
	if _shots.has(id): return
	while _shot_order.size() >= SHOT_CAP:
		_shots.erase(_shot_order.pop_front())
	var seen := PackedByteArray()
	seen.resize(projectiles.size())
	_shots[id] = {"weapon": str(shot.weaponId), "count": projectiles.size(), "remaining": projectiles.size(), "seen": seen}
	_shot_order.append(id)

func _on_resolution(receipt: Dictionary) -> void:
	if not ready_for_play or not is_instance_valid(world) or not world.is_inside_tree(): return
	var id := str(receipt.get("shotId", ""))
	if not _shots.has(id) or receipt.get("producerEpoch", -1) != _epoch or _effects.resolution_epoch() != _epoch:
		rejected += 1; return
	var record: Dictionary = _shots[id]
	var index := int(receipt.get("projectileIndex", -1))
	if receipt.get("weaponId") != record.weapon or receipt.get("projectileCount") != record.count or index < 0 or index >= record.count or record.seen[index] != 0:
		rejected += 1; return
	record.seen[index] = 1
	record.remaining -= 1
	if record.remaining <= 0:
		_shots.erase(id); _shot_order.erase(id)
	if receipt.get("status") != "hit": return
	var collider: Variant = receipt.get("collider")
	if not is_instance_valid(collider) or not _by_collider.has(collider.get_instance_id()): return
	var point: Variant = receipt.get("point")
	var normal: Variant = receipt.get("normal")
	if not point is Vector3 or not point.is_finite() or not normal is Vector3 or not normal.is_finite() or normal.length_squared() < 0.1:
		rejected += 1; return
	var entry: Dictionary = entries[int(_by_collider[collider.get_instance_id()])]
	if entry.broken or collider != entry.glass_body or not collider.is_inside_tree(): return
	var local: Vector3 = collider.to_local(point)
	var on_glass := false
	for spec: Dictionary in entry.visual.hit_shapes:
		var p: Vector3 = spec.transform.affine_inverse() * local
		var half: Vector3 = spec.shape.size * 0.5 + Vector3.ONE * 0.025
		if absf(p.x) <= half.x and absf(p.y) <= half.y and absf(p.z) <= half.z:
			on_glass = true; break
	if not on_glass:
		rejected += 1; return
	_break(entry, point, normal)

func _break(entry: Dictionary, point: Vector3, normal: Vector3) -> void:
	entry.broken = true
	_broken[entry.id] = true
	breaks += 1
	entry.light.visible = false
	entry.light.light_energy = 0.0
	Lantern.set_power(entry.visual, 0.0, true)
	_by_collider.erase(entry.glass_body.get_instance_id())
	entry.glass_body.collision_layer = 0
	entry.glass_body.queue_free()
	sound.play_break(point)
	_start_burst(entry.visual.root.global_position, normal)

static func _prepare_shard_motion() -> void:
	if _shard_base_velocities.size() == SHARDS_PER_BURST: return
	_shard_base_velocities.resize(SHARDS_PER_BURST)
	_shard_angles.resize(SHARDS_PER_BURST)
	_shard_base_sizes.resize(SHARDS_PER_BURST)
	for j in SHARDS_PER_BURST:
		var angle := float(j) * 2.399963
		_shard_angles[j] = angle
		_shard_base_velocities[j] = Vector3(cos(angle), 0.25 + float(j % 3) * 0.32, sin(angle)) * (0.7 + float(j % 4) * 0.32)
		_shard_base_sizes[j] = 0.045 + float(j % 4) * 0.012

func _prepare_debris() -> void:
	_prepare_shard_motion()
	var vertices := PackedVector3Array([Vector3(-0.5,-0.45,0),Vector3(0.5,-0.25,0),Vector3(-0.15,0.55,0)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.60,0.79,0.84,0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.10
	material.metallic = 0.15
	mesh.surface_set_material(0, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = BURSTS * SHARDS_PER_BURST
	_debris = MultiMeshInstance3D.new()
	_debris.name = "PooledStreetGlass"
	_debris.multimesh = multi
	_debris.top_level = true
	_debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_debris)
	_debris.hide()
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	for i in BURSTS * SHARDS_PER_BURST: multi.set_instance_transform(i, hidden)
	for i in BURSTS:
		_bursts.append({"active": false, "age": 0.0, "origin": Vector3.ZERO, "normal": Vector3.ZERO, "floor": 0.03})
	_floor_query.collision_mask = 1

func _start_burst(point: Vector3, normal: Vector3) -> void:
	_floor_query.from = point
	_floor_query.to = point - Vector3.UP * 12.0
	var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(_floor_query)
	var entry: Dictionary = _bursts[_burst_cursor % BURSTS]
	_burst_cursor += 1
	entry.active = true; entry.age = 0.0; entry.origin = point; entry.normal = normal
	entry.floor = float(floor_hit.position.y) + 0.025 if not floor_hit.is_empty() else point.y - 5.5
	_debris.show()
	set_process(true)

func _process(delta: float) -> void:
	if not ready_for_play or not is_instance_valid(_debris): set_process(false); return
	var multi: MultiMesh = _debris.multimesh
	var step := minf(delta, 0.1)
	var any := false
	for slot in BURSTS:
		var burst: Dictionary = _bursts[slot]
		if not burst.active: continue
		burst.age += step
		var age: float = burst.age
		var first := slot * SHARDS_PER_BURST
		if age >= 2.0:
			burst.active = false
			var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
			for j in SHARDS_PER_BURST: multi.set_instance_transform(first + j, hidden)
			continue
		any = true
		var origin: Vector3 = burst.origin
		var normal_push: Vector3 = burst.normal * 0.35
		var gravity := Vector3.UP * (4.9 * age * age)
		var floor_y: float = burst.floor
		var bounce_time := age * 11.0
		var fade := 1.0 - smoothstep(1.55, 2.0, age)
		var spin_z := age * 4.0
		for j in SHARDS_PER_BURST:
			var velocity: Vector3 = _shard_base_velocities[j] + normal_push
			var point: Vector3 = origin + velocity * age - gravity
			point.y = maxf(point.y, floor_y + sin(bounce_time + float(j)) * 0.008)
			var size := _shard_base_sizes[j] * fade
			var basis := Basis.from_euler(Vector3(age * (j + 2), _shard_angles[j], spin_z)).scaled(Vector3(size, size * 1.3, size))
			multi.set_instance_transform(first + j, Transform3D(basis, point))
	if not any:
		_debris.hide(); set_process(false)

func snapshot() -> Dictionary:
	var lit := 0
	var broken := 0
	for entry: Dictionary in entries:
		if entry.broken: broken += 1
		if is_instance_valid(entry.light) and entry.light.visible: lit += 1
	return {"ready": ready_for_play, "lamps": entries.size(), "lit": lit, "broken": broken,
		"power": power, "break_events": breaks, "pending_shots": _shots.size(), "rejected": rejected,
		"debris_slots": BURSTS * SHARDS_PER_BURST, "debris_processing": is_processing(), "sound": sound.stats() if is_instance_valid(sound) else {}}

func dispose() -> void:
	ready_for_play = false
	power = 0.0
	set_process(false)
	if is_instance_valid(_weapons) and _weapons.shot_emitted.is_connected(_on_shot): _weapons.shot_emitted.disconnect(_on_shot)
	if is_instance_valid(_effects) and _effects.projectile_resolved.is_connected(_on_resolution): _effects.projectile_resolved.disconnect(_on_resolution)
	if is_instance_valid(sound): sound.dispose(); sound.queue_free()
	if is_instance_valid(_debris): _debris.hide(); _debris.queue_free()
	for entry: Dictionary in entries:
		if is_instance_valid(entry.visual.root): entry.visual.root.hide(); entry.visual.root.queue_free()
		if is_instance_valid(entry.pole_body): entry.pole_body.queue_free()
	for record: Dictionary in _originals:
		if is_instance_valid(record.node): record.node.visible = record.visible
	entries.clear(); _originals.clear(); _by_collider.clear(); _shots.clear(); _shot_order.clear(); _bursts.clear()
	if is_in_group("mafiozi_street_lamps"): remove_from_group("mafiozi_street_lamps")
	_effects = null; _weapons = null; world = null

func _exit_tree() -> void:
	dispose()
