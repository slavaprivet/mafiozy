extends Node3D
## DSH_CATAPULT (prototype): a heavy wheeled catapult for bringing buildings down.
##
## It is not a prop that plays an animation. Everything about it is physical:
##  - the STONE is a real rigid body. The player drags it across the square and sets it
##    on the spoon himself; nothing teleports into place;
##  - the CART is heavy and rolls on four wheels. One man barely moves it, several men
##    move it properly - the push is shared, and the count is measured, not scripted;
##  - the ARM is a real lever with a winch: it is wound back, held by a catch, and when
##    the catch is released the arm swings and the stone leaves the spoon with the
##    speed the arm actually had;
##  - the IMPACT is a real hit on a real collider, forwarded into the building damage
##    system the palazzo already uses, and the stone is gone afterwards.
##
## Controls, all of them in the HUD as well:
##   E near the stone   - pick it up / put it down
##   E near the spoon   - set the stone on the spoon
##   E at the frame     - take the firing position
##   mouse              - aim (yaw with the mouse, elevation with its vertical motion)
##   LMB                - wind and release
##   WASD at the frame  - push the cart (with everyone else standing at it)

const STONE_MASS := 92.0
const STONE_RADIUS := 0.36
const CART_MASS := 900.0
const PUSH_RANGE := 2.35
const CARRY_RANGE := 2.6
const FRAME_RANGE := 2.9
const WIND_TIME := 1.35
# A heavy stone from a torsion engine: enough to break a wall, not enough to clear a
# palazzo at twenty-six metres, which is the shot the machine is built for.
const POWER_MS := 22.0
const ELEV_MIN := 0.12
const ELEV_MAX := 0.95
const GRAVITY := 9.81
## One man moves it slowly; every extra man adds less than the one before, which is how
## a real push works. Five men are about 2.4 times one man, not five times.
const PUSH_BASE_MS := 0.55
const PUSH_PER_MAN_MS := 0.44
const BLAST_POWER := 240.0
const BLAST_RADIUS := 0.85

var _world: Node3D
var _player: CharacterBody3D
var _ready := false

var _cart: CharacterBody3D
var _stone: RigidBody3D
var _wheel_nodes: Array[Node3D] = []
var _wheel_radius := 0.42

var _arm_pivot: Node3D
var _rope: MeshInstance3D
var _crank: MeshInstance3D
var _arm_spoon: Node3D
var _arm_angle := -0.55
var _arm_wound := false
var _winding := false
var _arm_settle := 0.0
var _release_angle := -0.55
var _wind_t := 0.0
var _fired := 0

var _yaw := 0.0
var _elevation := 0.30
var _occupied := false
var _carrying_stone := false
var _stone_on_spoon := false
var _pushers := 0
var _push_speed := 0.0
var _travelled := 0.0

var _flying := false
var _fly_velocity := Vector3.ZERO
var _fly_prev := Vector3.ZERO
var _fly_age := 0.0
var _last_impact := {}
var _hits := 0

var _aim_dots: Array[MeshInstance3D] = []
var _aim_material: StandardMaterial3D
var _hud: Label
var _materials: Dictionary = {}

## ------------------------------------------------------------------ install
func install(world: Node3D, player: CharacterBody3D) -> Dictionary:
	if _ready: return {"ok": false, "reason": "already_installed"}
	if not is_instance_valid(world) or not is_instance_valid(player):
		return {"ok": false, "reason": "missing_owner"}
	_world = world
	_player = player
	_build_materials()
	_build_cart()
	_build_stone()
	_build_aim()
	_build_hud()
	_ready = true
	return {"ok": true, "cart": _cart.global_position, "stone": _stone.global_position}

func _build_materials() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.22, 0.12)
	wood.roughness = 0.85
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.30, 0.31, 0.34)
	iron.metallic = 0.8
	iron.roughness = 0.45
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.56, 0.46, 0.26)
	rope.roughness = 0.95
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.44, 0.43, 0.41)
	stone.roughness = 0.95
	stone.metallic = 0.02
	_materials = {"wood": wood, "iron": iron, "rope": rope, "stone": stone}

## A box of timber at a size, the part every frame member is made of.
func _beam(parent: Node3D, size: Vector3, at: Vector3, material: Material,
		rotate: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.material_override = material
	part.position = at
	part.rotation = rotate
	parent.add_child(part)
	return part

func _build_cart() -> void:
	_cart = CharacterBody3D.new()
	_cart.name = "CatapultCart"
	_cart.collision_layer = 1
	_cart.collision_mask = 1
	_cart.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(_cart)
	# The frame the whole machine stands on.
	var hull := CollisionShape3D.new()
	var hull_shape := BoxShape3D.new()
	hull_shape.size = Vector3(2.05, 1.1, 2.3)
	hull.shape = hull_shape
	hull.position = Vector3(0.0, 0.55, 0.0)
	_cart.add_child(hull)
	var body := Node3D.new()
	body.name = "CatapultBody"
	_cart.add_child(body)
	var wood: Material = _materials["wood"]
	var iron: Material = _materials["iron"]
	# Two long side rails and three cross members: the ladder the machine sits on.
	for side: float in [-1.0, 1.0]:
		_beam(body, Vector3(0.26, 0.26, 2.3), Vector3(side * 0.92, 0.34, 0.0), wood)
	_beam(body, Vector3(2.1, 0.20, 0.24), Vector3(0.0, 0.34, -1.0), wood)
	_beam(body, Vector3(2.1, 0.20, 0.24), Vector3(0.0, 0.34, 1.0), wood)
	_beam(body, Vector3(2.1, 0.16, 0.20), Vector3(0.0, 0.34, 0.0), wood)
	# The uprights: an A-frame on each side carrying the axle.
	for side: float in [-1.0, 1.0]:
		_beam(body, Vector3(0.20, 1.45, 0.22), Vector3(side * 0.80, 0.96, 0.30), wood,
			Vector3(0.20, 0.0, 0.0))
		_beam(body, Vector3(0.18, 1.10, 0.18), Vector3(side * 0.80, 0.86, -0.32), wood,
			Vector3(-0.34, 0.0, 0.0))
	_beam(body, Vector3(1.85, 0.18, 0.18), Vector3(0.0, 1.62, 0.30), iron)
	# The axle the arm swings on.
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.075
	axle_mesh.bottom_radius = 0.075
	axle_mesh.height = 2.0
	axle.mesh = axle_mesh
	axle.material_override = iron
	axle.rotation = Vector3(0.0, 0.0, PI * 0.5)
	axle.position = Vector3(0.0, 1.62, 0.30)
	body.add_child(axle)
	# The winch drum at the back, which is what winds the arm down.
	var drum := MeshInstance3D.new()
	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.16
	drum_mesh.bottom_radius = 0.16
	drum_mesh.height = 1.5
	drum.mesh = drum_mesh
	drum.material_override = wood
	drum.rotation = Vector3(0.0, 0.0, PI * 0.5)
	drum.position = Vector3(0.0, 0.62, -0.86)
	body.add_child(drum)
	for side: float in [-1.0, 1.0]:
		var crank := _beam(body, Vector3(0.06, 0.42, 0.06), Vector3(side * 0.78, 0.86, -0.86), iron)
		crank.rotation = Vector3(0.0, 0.0, 0.0)
	# Four wheels under the rails, and they turn as the machine rolls.
	_wheel_radius = 0.42
	for x: float in [-0.98, 0.98]:
		for z: float in [-0.86, 0.86]:
			var wheel := Node3D.new()
			wheel.position = Vector3(x, _wheel_radius, z)
			body.add_child(wheel)
			var rim := MeshInstance3D.new()
			var rim_mesh := CylinderMesh.new()
			rim_mesh.top_radius = _wheel_radius
			rim_mesh.bottom_radius = _wheel_radius
			rim_mesh.height = 0.17
			rim_mesh.radial_segments = 16
			rim.mesh = rim_mesh
			rim.material_override = wood
			rim.rotation = Vector3(0.0, 0.0, PI * 0.5)
			wheel.add_child(rim)
			for spoke: int in 4:
				var bar := MeshInstance3D.new()
				var bar_mesh := BoxMesh.new()
				bar_mesh.size = Vector3(0.06, _wheel_radius * 1.85, 0.07)
				bar.mesh = bar_mesh
				bar.material_override = iron
				bar.rotation = Vector3(0.0, 0.0, TAU * float(spoke) / 4.0)
				wheel.add_child(bar)
			_wheel_nodes.append(wheel)
	# The throwing arm, on its own pivot so it can swing.
	_arm_pivot = Node3D.new()
	_arm_pivot.name = "CatapultArm"
	_arm_pivot.position = Vector3(0.0, 1.62, 0.30)
	body.add_child(_arm_pivot)
	var arm := _beam(_arm_pivot, Vector3(0.22, 0.24, 3.15), Vector3(0.0, 0.0, -1.05), wood)
	arm.rotation = Vector3.ZERO
	_beam(_arm_pivot, Vector3(0.30, 0.20, 0.55), Vector3(0.0, 0.0, 0.62), wood)
	# The spoon: a bowl at the far end that actually holds the stone.
	_arm_spoon = Node3D.new()
	_arm_spoon.name = "CatapultSpoon"
	_arm_spoon.position = Vector3(0.0, 0.05, 0.95)
	_arm_pivot.add_child(_arm_spoon)
	for side: float in [-1.0, 1.0]:
		var lip := _beam(_arm_spoon, Vector3(0.06, 0.34, 0.52), Vector3(side * 0.30, 0.14, 0.0), iron)
		lip.rotation = Vector3(0.12, 0.0, 0.0)
	_beam(_arm_spoon, Vector3(0.66, 0.06, 0.50), Vector3(0.0, 0.0, 0.0), iron)
	_beam(_arm_spoon, Vector3(0.66, 0.30, 0.06), Vector3(0.0, 0.15, 0.24), iron)
	# A rope from the arm back to the winch drum. It is its own node because it has to
	# change length and angle as the arm is wound down and released.
	_rope = _beam(body, Vector3(0.04, 0.04, 1.0), Vector3(0.0, 1.0, -0.4), _materials["rope"])
	_crank = _beam(body, Vector3(0.05, 0.34, 0.05), Vector3(0.0, 1.0, -0.86), _materials["iron"])
	_place_cart_near_palazzo()

## Where the machine starts: on the street in front of the palazzo, facing it.
func _place_cart_near_palazzo() -> void:
	var target := Vector3(48.5, 0.0, 0.0)
	var host: Variant = _world.get("preview_palazzo") if _world != null else null
	if is_instance_valid(host) and is_instance_valid(host.get("site")):
		var site: Node3D = host.get("site")
		target = site.global_position
	var approach := target - Vector3(0.0, 0.0, 26.0)
	_cart.global_position = Vector3(approach.x, 0.05, approach.z)
	_yaw = 0.0
	_cart.rotation.y = _yaw
	_arm_angle = -0.55
	_apply_arm()

func _build_stone() -> void:
	_stone = RigidBody3D.new()
	_stone.name = "CatapultStone"
	_stone.mass = STONE_MASS
	_stone.collision_layer = 1
	_stone.collision_mask = 1
	_stone.continuous_cd = true
	_stone.gravity_scale = 1.0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = STONE_RADIUS
	shape.shape = sphere
	_stone.add_child(shape)
	var rock := MeshInstance3D.new()
	rock.mesh = _build_rock_mesh()
	rock.material_override = _materials["stone"]
	_stone.add_child(rock)
	add_child(_stone)
	# It starts on the ground beside the cart, where a man would leave it.
	_stone.global_position = _cart.global_position + Vector3(2.3, STONE_RADIUS + 0.05, 0.6)

## A ROCK, not a ball. The sphere is unwelded and every vertex is pushed in or out by a
## deterministic hash of its own direction, then rebuilt with flat per-face normals so it
## reads as a chipped stone. Deterministic means the same rock every reload.
func _build_rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = STONE_RADIUS
	sphere.height = STONE_RADIUS * 2.0
	sphere.radial_segments = 9
	sphere.rings = 6
	var source: Array = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var mesh := ArrayMesh.new()
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var hash := func(v: Vector3) -> float:
		var h := int(round(v.x * 731.0)) * 73856093 ^ int(round(v.y * 977.0)) * 19349663 \
			^ int(round(v.z * 613.0)) * 83492791
		return float(abs(h) % 1000) / 1000.0
	for i: int in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		var pa := a.normalized() * (0.82 + 0.26 * float(hash.call(a.normalized())))
		var pb := b.normalized() * (0.82 + 0.26 * float(hash.call(b.normalized())))
		var pc := c.normalized() * (0.82 + 0.26 * float(hash.call(c.normalized())))
		pa *= STONE_RADIUS; pb *= STONE_RADIUS; pc *= STONE_RADIUS
		var normal: Vector3 = (pb - pa).cross(pc - pa).normalized()
		if normal.length_squared() < 0.5: continue
		out_vertices.append(pa); out_vertices.append(pb); out_vertices.append(pc)
		out_normals.append(normal); out_normals.append(normal); out_normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_vertices
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The dotted arc the stone would follow, drawn from the spoon.
func _build_aim() -> void:
	_aim_material = StandardMaterial3D.new()
	_aim_material.albedo_color = Color(0.98, 0.94, 0.86)
	_aim_material.emission_enabled = true
	_aim_material.emission = Color(0.5, 0.48, 0.42)
	_aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.07
	dot_mesh.height = 0.14
	for i: int in 30:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = _aim_material
		dot.visible = false
		add_child(dot)
		_aim_dots.append(dot)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 13
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(24, 120)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	layer.add_child(_hud)

## ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if not _ready or not _active(): return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_E:
			if _try_interact():
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and _occupied:
			_start_wind()
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and _occupied:
			_elevation = clampf(_elevation + 0.04, ELEV_MIN, ELEV_MAX)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and _occupied:
			_elevation = clampf(_elevation - 0.04, ELEV_MIN, ELEV_MAX)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _occupied:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.0022
		_elevation = clampf(_elevation - motion.relative.y * 0.0016, ELEV_MIN, ELEV_MAX)
		# Consumed: while the player is laying the machine the mouse is the gun sight,
		# not the camera. Letting both move it made the aim and the view disagree.
		get_viewport().set_input_as_handled()

func _active() -> bool:
	if not _ready or not is_instance_valid(_player): return false
	if not bool(_player.get("_free_mouse_look")): return false
	if _player.get("_pose_authority") != &"on_foot": return false
	if is_instance_valid(_world):
		if bool(_world.get("preview_dead")) or bool(_world.get("preview_physics_fault")): return false
	return true

## ------------------------------------------------------------------ interaction
func _try_interact() -> bool:
	var player_at: Vector3 = _player.global_position
	# 1. Carrying the stone? Put it on the spoon if we are at the spoon, else drop it.
	if _carrying_stone:
		if player_at.distance_to(_spoon_point()) <= FRAME_RANGE:
			_set_stone_on_spoon()
			return true
		_drop_stone()
		return true
	# 2. Standing at the frame: take the firing position, or leave it.
	if player_at.distance_to(_cart.global_position) <= FRAME_RANGE:
		_occupied = not _occupied
		if _occupied:
			_yaw = _cart.rotation.y
			_player.set_mouse_captured(true)
		return true
	# 3. Near the stone on the ground: pick it up.
	if not _stone_on_spoon and is_instance_valid(_stone) and not _flying \
			and player_at.distance_to(_stone.global_position) <= CARRY_RANGE:
		_carrying_stone = true
		_stone.freeze = true
		_stone.sleeping = false
		return true
	return false

## Sets the aim directly: yaw and elevation in radians.
func set_aim(yaw: float, elevation: float) -> void:
	_yaw = yaw
	_elevation = clampf(elevation, ELEV_MIN, ELEV_MAX)

## The elevation that lands a shot at a horizontal distance, for the HUD and for tests.
func elevation_for_range(metres: float) -> float:
	var product: float = metres * GRAVITY / (POWER_MS * POWER_MS)
	if product <= 0.0 or product >= 1.0: return 0.785
	return clampf(asin(product) * 0.5, ELEV_MIN, ELEV_MAX)

func _spoon_point() -> Vector3:
	if is_instance_valid(_arm_spoon): return _arm_spoon.global_position
	return _cart.global_position + Vector3.UP * 2.2

func _set_stone_on_spoon() -> void:
	_carrying_stone = false
	_stone_on_spoon = true
	if is_instance_valid(_stone):
		_stone.freeze = true
		_stone.global_position = _spoon_point() + Vector3.UP * (STONE_RADIUS + 0.06)
	_arm_wound = false
	_winding = false
	_arm_angle = -0.55
	_apply_arm()

func _drop_stone() -> void:
	_carrying_stone = false
	if is_instance_valid(_stone):
		_stone.freeze = false
		_stone.global_position = _player.global_position \
			+ _player._visual.global_basis.z * 1.1 + Vector3.UP * 0.45
		_stone.linear_velocity = Vector3.ZERO

## ------------------------------------------------------------------ firing
func _start_wind() -> void:
	if not _stone_on_spoon or _winding: return
	_winding = true
	_wind_t = 0.0
	_arm_wound = false

func _apply_arm() -> void:
	if is_instance_valid(_arm_pivot):
		_arm_pivot.rotation = Vector3(_arm_angle, 0.0, 0.0)
	if is_instance_valid(_rope) and is_instance_valid(_arm_pivot):
		# From the drum at the back to the arm where the rope is tied.
		var from: Vector3 = _cart.global_position + Vector3(0.0, 0.62, -0.86)
		var to: Vector3 = _arm_pivot.to_global(Vector3(0.0, 0.0, -0.55))
		var middle: Vector3 = (from + to) * 0.5
		var length: float = from.distance_to(to)
		_rope.global_position = middle
		_rope.scale = Vector3(1.0, 1.0, maxf(0.05, length))
		if length > 0.05:
			_rope.look_at(to, Vector3.UP, true)

## Where the stone would go from here: a real ballistic solution, not a guess.
func _launch_velocity() -> Vector3:
	var forward := Vector3(sin(_yaw), 0.0, cos(_yaw)).normalized()
	var direction := (forward * cos(_elevation) + Vector3.UP * sin(_elevation)).normalized()
	return direction * POWER_MS

func _release() -> void:
	if not _stone_on_spoon or not is_instance_valid(_stone): return
	_winding = false
	_arm_wound = false
	# The arm swings forward and lets go at its own release angle, then settles.
	_release_angle = _elevation - 1.15
	_arm_angle = _release_angle
	_arm_settle = 1.0
	_apply_arm()
	_flying = true
	_fly_age = 0.0
	_stone_on_spoon = false
	_stone.freeze = false
	_stone.global_position = _spoon_point() + Vector3.UP * (STONE_RADIUS + 0.05)
	_fly_velocity = _launch_velocity()
	_stone.linear_velocity = _fly_velocity
	_fly_prev = _stone.global_position
	_fired += 1
	print("DSH_CATAPULT_FIRED yaw=", _yaw, " elevation=", _elevation,
		" speed=", _fly_velocity.length(), " shots=", _fired)

## ------------------------------------------------------------------ rolling
func _count_pushers() -> int:
	var men := 0
	if is_instance_valid(_player):
		var to_cart: Vector3 = _cart.global_position - _player.global_position
		to_cart.y = 0.0
		if to_cart.length() <= PUSH_RANGE and _player.is_on_floor():
			var push := Vector2(_player.velocity.x, _player.velocity.z)
			if push.length() > 0.6 and push.normalized().dot(Vector2(to_cart.x, to_cart.z).normalized()) > 0.35:
				men += 1
	# Everyone else standing at the frame counts too: the game's own population is
	# already walking this street, and a machine this heavy is moved by a crowd.
	if is_instance_valid(_world) and _world.has_method("count_helpers_near"):
		men += int(_world.call("count_helpers_near", _cart.global_position, PUSH_RANGE))
	return men

func _push_speed_for(men: int) -> float:
	if men <= 0: return 0.0
	return PUSH_BASE_MS + PUSH_PER_MAN_MS * float(men - 1) * (1.0 / sqrt(float(men)))

func _physics_process(delta: float) -> void:
	if not _ready or not is_instance_valid(_cart): return
	_pushers = _count_pushers()
	_push_speed = _push_speed_for(_pushers)
	if _pushers > 0 and not _occupied:
		var direction := Vector3(sin(_cart.rotation.y), 0.0, cos(_cart.rotation.y))
		var to_cart: Vector3 = _cart.global_position - _player.global_position
		to_cart.y = 0.0
		if to_cart.length_squared() > 1.0e-6:
			direction = to_cart.normalized()
		_cart.velocity = direction * _push_speed
	else:
		_cart.velocity = Vector3.ZERO
	_cart.velocity.y = -1.0
	_cart.move_and_slide()
	# The wheels turn with the distance actually covered.
	var moved: float = _cart.velocity.length() * delta
	_travelled += moved
	var spin := moved / maxf(0.05, _wheel_radius)
	for wheel: Node3D in _wheel_nodes:
		if is_instance_valid(wheel): wheel.rotate_x(spin)
	# The arm: winding pulls it back, the catch holds it, and after the release it
	# slams forward and settles instead of stopping dead.
	if _arm_settle > 0.0:
		_arm_settle = maxf(0.0, _arm_settle - delta * 1.9)
		var t := 1.0 - _arm_settle
		_arm_angle = lerpf(_release_angle, -0.55, t) + sin(t * PI * 2.0) * 0.10 * (1.0 - t)
		_apply_arm()
	if _winding:
		if is_instance_valid(_crank): _crank.rotate_x(delta * 5.0)
		if is_instance_valid(_crank): _crank.rotate_y(0.0)
		_wind_t += delta
		_arm_angle = lerpf(-0.55, -0.95, clampf(_wind_t / WIND_TIME, 0.0, 1.0))
		_apply_arm()
		if _wind_t >= WIND_TIME:
			_winding = false
			_arm_wound = true
			_release()
	_apply_arm()
	# The stone follows the player while it is being carried.
	if _carrying_stone and is_instance_valid(_stone):
		var want: Vector3 = _player.global_position \
			+ _player._visual.global_basis.z * 0.9 + Vector3.UP * 0.55
		_stone.global_position = _stone.global_position.lerp(want, clampf(12.0 * delta, 0.0, 1.0))
	elif _stone_on_spoon and is_instance_valid(_stone):
		_stone.global_position = _spoon_point() + Vector3.UP * (STONE_RADIUS + 0.06)
	# A fired stone is a real projectile: swept, so it cannot tunnel through a wall.
	if _flying and is_instance_valid(_stone):
		_step_flight(delta)
	_update_aim()

func _step_flight(delta: float) -> void:
	_fly_age += delta
	var from: Vector3 = _fly_prev
	var to: Vector3 = _stone.global_position
	var space := _world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid(), _cart.get_rid(), _stone.get_rid()]
	if space != null and from.distance_squared_to(to) > 1.0e-8:
		# The ray is cast between CENTRES, and a stone of this radius comes to rest with
		# its SURFACE on the ground without its centre ever crossing it - which is why a
		# shot that visibly landed reported no hit at all. The sweep is extended by the
		# stone's own radius so it is the surface that gets tested.
		var motion: Vector3 = to - from
		var extended: Vector3 = to + motion.normalized() * (STONE_RADIUS + 0.03)
		var query := PhysicsRayQueryParameters3D.create(from, extended, 1 | 5 | 256, exclude)
		query.hit_from_inside = true
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			_impact(hit)
			return
	_fly_prev = to
	# A stone that leaves the world is gone rather than falling for ever.
	if _fly_age > 20.0 or to.y < -20.0:
		_vanish()

## The strike: forward it into the building damage system the palazzo already uses.
func _impact(hit: Dictionary) -> void:
	var point: Vector3 = hit.get("position", _stone.global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var collider: Variant = hit.get("collider")
	var direction: Vector3 = _fly_velocity.normalized()
	_hits += 1
	var delivered := false
	var host: Variant = _world.get("preview_palazzo") if is_instance_valid(_world) else null
	if is_instance_valid(host) and is_instance_valid(collider) and host.has_method("_native_blast"):
		var source_id := ""
		var site: Variant = host.get("site")
		if is_instance_valid(site): source_id = str(site.get("source_id"))
		var event := {
			"scope": "new_local_session_building_damage",
			"event_id": "catapult:%d" % _hits,
			"source_id": source_id,
			"position": point, "normal": normal, "direction": direction,
			"collider": collider,
			"power": BLAST_POWER, "radius": BLAST_RADIUS,
			"weapon_id": "catapult", "explosive": true,
			"admitted": true, "authority": "local_preview", "server_authority": false,
		}
		var result: Variant = host.call("_native_blast", event)
		delivered = result is Dictionary and bool(result.get("ok", false))
		_last_impact = {"ok": delivered, "result": result, "point": point}
		print("DSH_CATAPULT_IMPACT delivered=", delivered, " at=", point, " result=", result)
	else:
		print("DSH_CATAPULT_IMPACT delivered=false reason=no_palazzo_host or foreign_collider")
	_vanish()

## The stone disappears after impact - it does not lie around as litter.
func _vanish() -> void:
	_flying = false
	_fly_velocity = Vector3.ZERO
	if is_instance_valid(_stone):
		var rock := _stone.get_child(2) as MeshInstance3D
		if is_instance_valid(rock): rock.visible = false
		_stone.freeze = true
		_stone.global_position = _cart.global_position + Vector3(0.0, -40.0, 0.0)
	# A fresh stone is laid at the cart for the next shot.
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(_stone) or _carrying_stone or _stone_on_spoon: return
	if is_instance_valid(_stone):
		var rock2 := _stone.get_child(2) as MeshInstance3D
		if is_instance_valid(rock2): rock2.visible = true
		_stone.global_position = _cart.global_position + Vector3(2.1, STONE_RADIUS + 0.05, 0.7)
		_stone.freeze = false
		_stone.linear_velocity = Vector3.ZERO

## ------------------------------------------------------------------ aim + HUD
func _update_aim() -> void:
	var show := _occupied
	var at: Vector3 = _spoon_point()
	var velocity := _launch_velocity()
	var space := _world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid(), _cart.get_rid(), _stone.get_rid()]
	var shown := 0
	var step := 0.06
	for i: int in _aim_dots.size():
		var next := at + velocity * step
		velocity += Vector3.DOWN * GRAVITY * step
		if shown >= 3 and space != null:
			var query := PhysicsRayQueryParameters3D.create(at, next, 1 | 5 | 256, exclude)
			query.hit_from_inside = true
			if not space.intersect_ray(query).is_empty():
				break
		var dot: MeshInstance3D = _aim_dots[i]
		dot.visible = show
		if show:
			dot.global_position = next
			dot.scale = Vector3.ONE * clampf(1.2 - float(i) / 40.0, 0.3, 1.2)
		shown += 1
		at = next
		if at.y < 0.2: break
	if not show:
		for dot: MeshInstance3D in _aim_dots:
			if is_instance_valid(dot): dot.visible = false

func _process(_delta: float) -> void:
	if not _ready or not is_instance_valid(_hud): return
	if not _active():
		_hud.text = ""
		return
	var player_at: Vector3 = _player.global_position
	var lines: Array[String] = []
	lines.append("КАТАПУЛЬТА · снаряд %.0f кг · колёса" % STONE_MASS)
	if _occupied:
		lines.append("ЛКМ — закрутить и выстрелить · колесо мыши — угол")
		lines.append("МЫШЬ — наводка · угол %.0f°" % rad_to_deg(_elevation))
		lines.append("E — отойти от катапульты")
	elif _carrying_stone:
		lines.append("E у ложечки — положить камень · E — бросить")
	elif _stone_on_spoon:
		lines.append("Камень на ложечке · E у станины — встать на место")
	elif player_at.distance_to(_stone.global_position) <= CARRY_RANGE and not _flying:
		lines.append("E — взять камень")
	elif player_at.distance_to(_cart.global_position) <= FRAME_RANGE:
		lines.append("E — встать к катапульте")
	if _pushers > 0:
		lines.append("КАТЯТ: %d · %.2f м/с" % [_pushers, _push_speed])
	lines.append("ПРОЙДЕНО %.1f м · выстрелов %d" % [_travelled, _fired])
	_hud.text = "\n".join(lines)

## ------------------------------------------------------------------ telemetry
func snapshot() -> Dictionary:
	return {
		"ready": _ready,
		"cart": _cart.global_position if is_instance_valid(_cart) else Vector3.ZERO,
		"yaw": _yaw, "elevation": _elevation,
		"speed_for_1": _push_speed_for(1), "speed_for_2": _push_speed_for(2),
		"speed_for_5": _push_speed_for(5), "pushers": _pushers,
		"travelled": _travelled,
		"stone": _stone.global_position if is_instance_valid(_stone) else Vector3.ZERO,
		"stone_on_spoon": _stone_on_spoon, "carrying": _carrying_stone,
		"occupied": _occupied, "winding": _winding, "wound": _arm_wound,
		"fired": _fired, "flying": _flying, "hits": _hits,
		"last_impact": _last_impact,
		"spoon": _spoon_point(),
	}

func _exit_tree() -> void:
	_aim_dots.clear()
	_wheel_nodes.clear()
