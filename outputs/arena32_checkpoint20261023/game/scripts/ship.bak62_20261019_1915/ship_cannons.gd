extends Node3D
## SHIP61 agent D — the four broadside cannons of the ship.
##
## Owns: mounting the four model guns, aiming (yaw ±32° from the broadside normal,
## pitch -8°..+30°), one-ball loading animation, recoil + muzzle flash + smoke,
## the 24-ball kinematic projectile pool and the impact bookkeeping (castle / water /
## ship / land).  The HUD lives in agent E's file; this node only reports `state()`.
##
## The cannon model is whatever `model.build()["cannons"]` returns (contract B):
##   {"index", "side", "node", "mount", "pivot", "barrel", "muzzle"}
## `mount` and `muzzle` are model-space Vector3 positions; `pivot` / `barrel` are the
## nodes the model itself built, so the aim offsets are applied RELATIVE to their rest
## basis and the visual gun can never drift away from the model.
##
## Extra API added for the integrator (beyond the contract):
##   bind_castle(castle)             — explicit castle, otherwise world.preview_castle
##   set_ball_stock(count) / ball_stock()
##   look_yaw(index) -> float        — player facing yaw that looks outward over the gun
##   debug_fire_at(point) -> Dictionary — QA: aim the best gun, load free, fire
##   set_aim_degrees(yaw, pitch) -> bool — absolute aim, clamped (QA / keyboard)
##
## No `class_name`: the project loads scripts through preload().

const CannonballScript = preload("res://scripts/ship/ship_cannonball.gd")

const BALL_SPEED := 62.0
const BALL_LIFE := 8.0
const POOL_SIZE := 24
const GRAVITY := 9.81

const YAW_LIMIT_DEG := 32.0
const PITCH_MIN_DEG := -8.0
const PITCH_MAX_DEG := 30.0
const YAW_LIMIT := YAW_LIMIT_DEG * PI / 180.0
const PITCH_MIN := PITCH_MIN_DEG * PI / 180.0
const PITCH_MAX := PITCH_MAX_DEG * PI / 180.0

const LOAD_TIME := 1.2
const RECOIL_DISTANCE := 0.35
const RECOIL_RETURN_SPEED := 1.6
const FLASH_TIME := 0.08

const AIM_DOTS := 26
const AIM_STEP := 0.06
const AIM_REFRESH := 0.05
const STATION_INSET := 1.2

var _installed := false
var _world: Node3D = null
var _boat: Node3D = null
var _model: Node3D = null
var _player: CharacterBody3D = null
var _basin: Node = null
var _castle: Node3D = null

var _guns: Array[Dictionary] = []
var _man_index := -1
var _last_man_index := -1
var _balls: Array = []
var _shots := 0
var _hits := 0
var _castle_hits := 0
var _water_hits := 0
var _ship_hits := 0
var _last_impact: Dictionary = {}
var _ball_stock := POOL_SIZE

var _effect_root: Node3D = null
var _ball_root: Node3D = null
var _aim_dots: Array[MeshInstance3D] = []
var _aim_tick := 0.0
var _puffs: Array[Dictionary] = []
var _mats: Dictionary = {}
var _puff_mesh: QuadMesh = null
var _own_rids: Array[RID] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


# ================================================================== install
func install(world: Node3D, boat: Node3D, model: Node3D, player: CharacterBody3D,
		basin: Node) -> Dictionary:
	if _installed:
		return {"ok": false, "reason": "already_installed", "cannons": _guns.size()}
	if not is_instance_valid(model):
		return {"ok": false, "reason": "no_model", "cannons": 0}
	if not model.has_method("build"):
		return {"ok": false, "reason": "model_without_build", "cannons": 0}
	var built: Variant = model.call("build")
	if not (built is Dictionary):
		return {"ok": false, "reason": "build_not_dictionary", "cannons": 0}
	var built_cannons: Variant = (built as Dictionary).get("cannons", [])
	if not (built_cannons is Array) or (built_cannons as Array).is_empty():
		return {"ok": false, "reason": "no_cannons_in_build", "cannons": 0}
	_world = world if is_instance_valid(world) else null
	_boat = boat if is_instance_valid(boat) else null
	_model = model
	_player = player if is_instance_valid(player) else null
	_basin = basin if is_instance_valid(basin) else null
	_build_roots()
	_build_materials()
	_build_pools()
	model.force_update_transform()
	var model_xform: Transform3D = model.global_transform
	var built_count := 0
	for raw: Variant in built_cannons:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var gun := _build_gun(entry, built_count, model_xform)
		if gun.is_empty():
			continue
		_guns.append(gun)
		built_count += 1
	if _guns.is_empty():
		return {"ok": false, "reason": "no_usable_cannons", "cannons": 0}
	_installed = true
	# The host may install the cannons before/after binding the castle; try the same
	# world lookup the rest of the preview uses and let the host override it later.
	if not is_instance_valid(_castle) and _world != null:
		var found_castle: Variant = _world.get("preview_castle")
		if found_castle is Node3D:
			_castle = found_castle
	_collect_boat_rids()
	var result := {
		"ok": true,
		"cannons": _guns.size(),
		"pool": _balls.size(),
		"castle": is_instance_valid(_castle),
		"boat": is_instance_valid(_boat),
		"basin": is_instance_valid(_basin),
		"player": is_instance_valid(_player),
		"speed": BALL_SPEED,
		"limits": {"yaw_deg": YAW_LIMIT_DEG, "pitch_min_deg": PITCH_MIN_DEG,
			"pitch_max_deg": PITCH_MAX_DEG},
	}
	return result


func bind_castle(castle: Node3D) -> void:
	_castle = castle if is_instance_valid(castle) else null


func bind_basin(basin: Node) -> void:
	_basin = basin if is_instance_valid(basin) else null


func set_ball_stock(count: int) -> void:
	_ball_stock = maxi(0, count)


func ball_stock() -> int:
	return _ball_stock


func _build_roots() -> void:
	_effect_root = Node3D.new()
	_effect_root.name = "CannonEffects"
	add_child(_effect_root)
	_effect_root.top_level = true
	_effect_root.global_transform = Transform3D.IDENTITY
	_ball_root = _world if _world != null else _effect_root


func _build_gun(entry: Dictionary, ordinal: int, model_xform: Transform3D) -> Dictionary:
	var node := entry.get("node") as Node3D
	var pivot := entry.get("pivot") as Node3D
	var barrel := entry.get("barrel") as Node3D
	# build() may have just created these nodes on the same frame; make sure their
	# global transforms are resolved before the muzzle is sampled.
	for joint: Node3D in [node, pivot, barrel]:
		if is_instance_valid(joint):
			joint.force_update_transform()
	var side := str(entry.get("side", "port")).to_lower()
	if side != "port" and side != "starboard":
		side = "port" if ordinal % 2 == 0 else "starboard"
	var index_value: Variant = entry.get("index", ordinal)
	var index: int = int(index_value) if typeof(index_value) == TYPE_INT or typeof(index_value) == TYPE_FLOAT else ordinal
	var mount_value: Variant = entry.get("mount", Vector3.ZERO)
	var mount_local := Vector3.ZERO
	if mount_value is Node3D:
		mount_local = model_xform.affine_inverse() * (mount_value as Node3D).global_position
	elif typeof(mount_value) == TYPE_VECTOR3:
		mount_local = mount_value
	var mount_world: Vector3 = model_xform * mount_local
	if is_instance_valid(node):
		mount_world = node.global_position
	var muzzle_value: Variant = entry.get("muzzle", null)
	var muzzle_world := Vector3.ZERO
	var muzzle_known := false
	if muzzle_value is Node3D:
		muzzle_world = (muzzle_value as Node3D).global_position
		muzzle_known = true
	elif typeof(muzzle_value) == TYPE_VECTOR3:
		muzzle_world = model_xform * muzzle_value
		muzzle_known = true
	if not muzzle_known:
		var outward_fallback := Vector3.RIGHT if side == "starboard" else Vector3.LEFT
		muzzle_world = mount_world + (model_xform.basis * outward_fallback).normalized() * 1.35 \
			+ Vector3.UP * 0.55
	var outward_world: Vector3 = muzzle_world - mount_world
	outward_world.y = 0.0
	if outward_world.length_squared() < 1.0e-6:
		outward_world = model_xform.basis * (Vector3.RIGHT if side == "starboard" else Vector3.LEFT)
		outward_world.y = 0.0
	if outward_world.length_squared() < 1.0e-6:
		outward_world = Vector3.RIGHT
	outward_world = outward_world.normalized()
	# Inboard is the model-space direction from the gun towards the centreline:
	# +X for the port battery, -X for the starboard battery (contract B).
	var inward_local := Vector3.LEFT if side == "starboard" else Vector3.RIGHT
	if not is_instance_valid(_model):
		inward_local = model_xform.basis.inverse() * (-outward_world)
		inward_local.y = 0.0
		if inward_local.length_squared() > 1.0e-6:
			inward_local = inward_local.normalized()
		else:
			inward_local = Vector3.RIGHT
	# Rest basis of the two visual joints.  Aiming is applied on top of these, so the
	# model's own orientation (±90° pivot for the two sides) is preserved.
	var pivot_rest := Basis.IDENTITY
	var barrel_rest := Basis.IDENTITY
	var barrel_rest_position := Vector3.ZERO
	if is_instance_valid(pivot):
		pivot_rest = pivot.basis
	if is_instance_valid(barrel):
		barrel_rest = barrel.basis
		barrel_rest_position = barrel.position
	# Barrel-local forward: sampled from the model's own muzzle point, so it works for
	# a barrel built along -Z, +X or anything else the model agent chose.
	var local_forward := Vector3.FORWARD
	var pitch_axis := Vector3.RIGHT
	var muzzle_marker: Node3D = null
	var muzzle_len: float = maxf(0.4, mount_world.distance_to(muzzle_world))
	if is_instance_valid(barrel):
		var origin_world: Vector3 = barrel.global_position
		var forward_world: Vector3 = muzzle_world - origin_world
		if forward_world.length_squared() < 1.0e-6:
			forward_world = outward_world
		forward_world = forward_world.normalized()
		local_forward = (barrel.global_basis.inverse() * forward_world).normalized()
		if local_forward.length_squared() < 1.0e-6:
			local_forward = Vector3.FORWARD
		pitch_axis = local_forward.cross(Vector3.UP)
		if pitch_axis.length_squared() < 1.0e-4:
			pitch_axis = local_forward.cross(Vector3.RIGHT)
		if pitch_axis.length_squared() < 1.0e-6:
			pitch_axis = Vector3.RIGHT
		pitch_axis = pitch_axis.normalized()
		muzzle_marker = Node3D.new()
		muzzle_marker.name = "Muzzle"
		var local_muzzle: Vector3 = barrel.global_transform.affine_inverse() * muzzle_world
		barrel.add_child(muzzle_marker)
		muzzle_marker.position = local_muzzle
	var label := "Левый борт" if side == "port" else "Правый борт"
	# The model has one gun fore (z=-4.2) and one aft (z=+3.4) on each side.
	var number: int = 1 if mount_local.z < 0.0 else 2
	label = "%s %d" % [label, number]
	var gun := {
		"index": index,
		"ordinal": ordinal,
		"side": side,
		"label": label,
		"node": node,
		"pivot": pivot,
		"barrel": barrel,
		"mount_local": mount_local,
		"mount_world": mount_world,
		"inward_local": inward_local,
		"pivot_rest_basis": pivot_rest,
		"barrel_rest_basis": barrel_rest,
		"barrel_rest_position": barrel_rest_position,
		"local_forward": local_forward,
		"pitch_axis": pitch_axis,
		"muzzle_marker": muzzle_marker,
		"muzzle_len": muzzle_len,
		"outward_world": outward_world,
		"yaw": 0.0,
		"yaw_target": 0.0,
		"pitch": 0.0,
		"pitch_target": 0.0,
		"recoil": 0.0,
		"applied_yaw": 0.0,
		"applied_pitch": 0.0,
		"applied_recoil": 0.0,
		"loaded": false,
		"loading": false,
		"load_t": 0.0,
		"flash": null,
		"flash_t": 0.0,
		"load_ball_node": null,
		"rammer_node": null,
		"muzzle_local": Vector3.ZERO,
		"seat_local": Vector3.ZERO,
	}
	_create_gun_visuals(gun)
	return gun


func _create_gun_visuals(gun: Dictionary) -> void:
	var barrel := gun.get("barrel") as Node3D
	# One muzzle flash sphere per gun, parented to the world-aligned effect root.
	var flash := MeshInstance3D.new()
	flash.name = "Flash%d" % int(gun.get("ordinal", 0))
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	sphere.radial_segments = 8
	sphere.rings = 4
	flash.mesh = sphere
	flash.material_override = _mats.get("flash")
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effect_root.add_child(flash)
	gun["flash"] = flash
	if not is_instance_valid(barrel):
		return
	var marker := gun.get("muzzle_marker") as Node3D
	var muzzle_local := Vector3.ZERO
	if is_instance_valid(marker):
		muzzle_local = marker.position
	var seat_local := Vector3(muzzle_local.x, muzzle_local.y, muzzle_local.z * 0.34)
	gun["muzzle_local"] = muzzle_local
	gun["seat_local"] = seat_local
	var ball_node := MeshInstance3D.new()
	ball_node.name = "LoadedBall"
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.12
	ball_mesh.height = 0.24
	ball_mesh.radial_segments = 8
	ball_mesh.rings = 4
	ball_node.mesh = ball_mesh
	ball_node.material_override = _mats.get("iron")
	ball_node.visible = false
	barrel.add_child(ball_node)
	gun["load_ball_node"] = ball_node
	var rammer := MeshInstance3D.new()
	rammer.name = "Rammer"
	var rod := CylinderMesh.new()
	rod.top_radius = 0.035
	rod.bottom_radius = 0.035
	rod.height = 1.5
	rammer.mesh = rod
	rammer.material_override = _mats.get("rammer")
	rammer.rotation.x = PI * 0.5
	rammer.visible = false
	barrel.add_child(rammer)
	gun["rammer_node"] = rammer


func _build_materials() -> void:
	var iron := _make_material(Color(0.15, 0.16, 0.18), 0, false, false, false)
	iron.metallic = 0.9
	iron.roughness = 0.25
	_mats["iron"] = iron
	var rammer := _make_material(Color(0.42, 0.28, 0.16), 0, false, false, false)
	rammer.roughness = 0.8
	_mats["rammer"] = rammer
	_mats["flash"] = _make_material(Color(1.0, 0.75, 0.32),
		Color(1.0, 0.55, 0.12), true, false, false)
	var smoke := _make_material(Color(0.58, 0.58, 0.60, 0.55), 0, true, true, true)
	smoke.roughness = 1.0
	_mats["smoke"] = smoke
	var splash := _make_material(Color(0.82, 0.92, 1.0, 0.72), 0, true, true, true)
	_mats["water"] = splash
	var dust := _make_material(Color(0.62, 0.53, 0.40, 0.72), 0, true, true, true)
	_mats["land"] = dust
	var wood := _make_material(Color(0.38, 0.27, 0.17, 0.80), 0, true, true, true)
	_mats["ship"] = wood
	var aim := _make_material(Color(0.30, 0.85, 0.45), Color(1.0, 0.75, 0.22), true, false, false)
	_mats["aim"] = aim
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2(1.0, 1.0)


func _make_material(albedo: Color, emission: Color, unshaded: bool,
		transparent: bool, billboard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.65
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if emission != Color(0, 0, 0):
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 4.0
	return material


func _build_pools() -> void:
	for i: int in POOL_SIZE:
		var ball = CannonballScript.new()
		ball.name = "Cannonball%d" % i
		_ball_root.add_child(ball)
		if ball.has_method("deactivate"):
			ball.call("deactivate")
		_balls.append(ball)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.075
	dot_mesh.height = 0.15
	dot_mesh.radial_segments = 6
	dot_mesh.rings = 3
	for i: int in AIM_DOTS:
		var dot := MeshInstance3D.new()
		dot.name = "AimDot%d" % i
		dot.mesh = dot_mesh
		dot.material_override = _mats.get("aim")
		dot.visible = false
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_effect_root.add_child(dot)
		_aim_dots.append(dot)
	for i: int in 56:
		var puff := MeshInstance3D.new()
		puff.name = "Puff%d" % i
		puff.mesh = _puff_mesh
		puff.material_override = _mats.get("smoke")
		puff.visible = false
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_effect_root.add_child(puff)
		_puffs.append({
			"node": puff, "life": 0.0, "max_life": 1.0, "velocity": Vector3.ZERO,
			"start": 1.0, "end": 2.0, "gravity": 0.0,
		})


func _collect_boat_rids() -> void:
	_own_rids.clear()
	if not is_instance_valid(_boat):
		return
	var body := _boat as CollisionObject3D
	if body != null:
		_own_rids.append(body.get_rid())
	for found: Node in _boat.find_children("*", "CollisionObject3D", true, false):
		var collision_object := found as CollisionObject3D
		if collision_object == null:
			continue
		var rid: RID = collision_object.get_rid()
		if not _own_rids.has(rid):
			_own_rids.append(rid)


# ================================================================== manning
func man(index: int) -> bool:
	if not _installed:
		return false
	if index < 0 or index >= _guns.size():
		return false
	if _man_index == index:
		return true
	if _man_index >= 0:
		_cancel_loading(_man_index)
	_man_index = index
	_last_man_index = index
	return true


func leave() -> void:
	if _man_index >= 0:
		_cancel_loading(_man_index)
	_man_index = -1
	_hide_aim_dots()


func manning() -> bool:
	return _installed and _man_index >= 0


func manning_index() -> int:
	return _man_index


# ================================================================== aiming
func aim(delta_yaw: float, delta_pitch: float) -> void:
	if not _installed or _man_index < 0:
		return
	var gun: Dictionary = _guns[_man_index]
	gun["yaw_target"] = clampf(float(gun.get("yaw_target", 0.0)) + delta_yaw,
		-YAW_LIMIT, YAW_LIMIT)
	gun["pitch_target"] = clampf(float(gun.get("pitch_target", 0.0)) + delta_pitch,
		PITCH_MIN, PITCH_MAX)


## Absolute aim in degrees, clamped.  Returns false when nobody is at a gun.
func set_aim_degrees(yaw_degrees: float, pitch_degrees: float) -> bool:
	if not _installed or _man_index < 0:
		return false
	var gun: Dictionary = _guns[_man_index]
	gun["yaw_target"] = clampf(deg_to_rad(yaw_degrees), -YAW_LIMIT, YAW_LIMIT)
	gun["pitch_target"] = clampf(deg_to_rad(pitch_degrees), PITCH_MIN, PITCH_MAX)
	return true


func _snap_aim(gun: Dictionary) -> void:
	gun["yaw"] = float(gun.get("yaw_target", 0.0))
	gun["pitch"] = float(gun.get("pitch_target", 0.0))
	_apply_gun_pose(gun, true)


# ================================================================== loading
func load_ball() -> bool:
	if not _installed or _man_index < 0:
		return false
	var gun: Dictionary = _guns[_man_index]
	if bool(gun.get("loaded", false)) or bool(gun.get("loading", false)):
		return false
	gun["loading"] = true
	gun["load_t"] = 0.0
	gun["loaded"] = false
	_set_load_visuals(gun, 0.0, true)
	return true


func loaded() -> bool:
	if not _installed or _man_index < 0:
		return false
	return bool(_guns[_man_index].get("loaded", false))


func _cancel_loading(index: int) -> void:
	if index < 0 or index >= _guns.size():
		return
	var gun: Dictionary = _guns[index]
	gun["loading"] = false
	gun["load_t"] = 0.0
	_set_load_visuals(gun, 0.0, false)


func _set_load_visuals(gun: Dictionary, t: float, visible: bool) -> void:
	var ball_node := gun.get("load_ball_node") as MeshInstance3D
	var rammer := gun.get("rammer_node") as MeshInstance3D
	if not visible:
		if is_instance_valid(ball_node):
			ball_node.visible = false
		if is_instance_valid(rammer):
			rammer.visible = false
		return
	var muzzle_local: Vector3 = gun.get("muzzle_local", Vector3.ZERO)
	var seat_local: Vector3 = gun.get("seat_local", Vector3.ZERO)
	var eased: float = smoothstep(0.0, 1.0, t)
	if is_instance_valid(ball_node):
		ball_node.visible = true
		ball_node.position = muzzle_local.lerp(seat_local, eased)
	if is_instance_valid(rammer):
		rammer.visible = t < 0.92
		var z: float = seat_local.z + 0.9 - 0.9 * eased
		rammer.position = Vector3(seat_local.x, seat_local.y, z)


# ================================================================== firing
func fire() -> Dictionary:
	var failed := {"ok": false, "reason": "not_installed", "from": Vector3.ZERO,
		"direction": Vector3.ZERO}
	if not _installed:
		return failed
	if _man_index < 0:
		return {"ok": false, "reason": "not_manning", "from": Vector3.ZERO,
			"direction": Vector3.ZERO}
	var gun: Dictionary = _guns[_man_index]
	if bool(gun.get("loading", false)):
		return {"ok": false, "reason": "loading", "from": Vector3.ZERO,
			"direction": Vector3.ZERO}
	if not bool(gun.get("loaded", false)):
		return {"ok": false, "reason": "not_loaded", "from": Vector3.ZERO,
			"direction": Vector3.ZERO}
	var ball: Variant = _take_ball()
	if ball == null:
		return {"ok": false, "reason": "pool_empty", "from": Vector3.ZERO,
			"direction": Vector3.ZERO}
	var from: Vector3 = _muzzle_world(_man_index)
	var direction: Vector3 = _gun_direction(_man_index)
	if direction.length_squared() < 1.0e-6:
		return {"ok": false, "reason": "no_direction", "from": from,
			"direction": Vector3.ZERO}
	direction = direction.normalized()
	_shots += 1
	gun["loaded"] = false
	gun["loading"] = false
	gun["load_t"] = 0.0
	gun["recoil"] = RECOIL_DISTANCE
	_set_load_visuals(gun, 0.0, false)
	ball.call("launch", from, direction, BALL_SPEED, _boat, _castle, _basin, _shots)
	_flash_gun(gun, from, direction)
	return {"ok": true, "from": from, "direction": direction, "speed": BALL_SPEED,
		"index": _man_index, "side": str(gun.get("side", "port")), "shot": _shots}


func _take_ball() -> Variant:
	for ball: Variant in _balls:
		if ball == null:
			continue
		if not bool(ball.get("active")):
			return ball
	return null


func _flash_gun(gun: Dictionary, from: Vector3, direction: Vector3) -> void:
	var flash := gun.get("flash") as MeshInstance3D
	if is_instance_valid(flash):
		flash.global_position = from + direction * 0.25
		flash.visible = true
		flash.scale = Vector3.ONE * _rng.randf_range(0.9, 1.35)
	gun["flash_t"] = FLASH_TIME
	_spawn_puffs("smoke", from + direction * 0.45, direction, 8, 3.2, 0.7, 1.25, -0.35)


# ================================================================== debug / QA
## Pick the gun that can point at `world_point` best, snap it there, load it for free
## and fire immediately.  Used by QA screenshots and volley tests; does not touch the
## host's ammunition stock.
func debug_fire_at(world_point: Vector3) -> Dictionary:
	if not _installed:
		return {"ok": false, "reason": "not_installed"}
	if _guns.is_empty():
		return {"ok": false, "reason": "no_usable_cannons"}
	var best := -1
	var best_score := 1.0e9
	var best_yaw := 0.0
	var best_pitch := 0.0
	for i: int in _guns.size():
		var gun: Dictionary = _guns[i]
		var from: Vector3 = _muzzle_world(i)
		var to_target: Vector3 = world_point - from
		var horizontal := Vector3(to_target.x, 0.0, to_target.z)
		var distance: float = horizontal.length()
		if distance < 0.2:
			continue
		var outward: Vector3 = _gun_rest_outward_world(i)
		var desired: Vector3 = horizontal / distance
		var yaw_error: float = outward.signed_angle_to(desired, Vector3.UP)
		var yaw_limited: float = clampf(yaw_error, -YAW_LIMIT, YAW_LIMIT)
		var pitch: float = _ballistic_pitch(distance, to_target.y, BALL_SPEED)
		var pitch_limited: float = clampf(pitch, PITCH_MIN, PITCH_MAX)
		var score: float = absf(yaw_limited) + absf(pitch - pitch_limited) * 1.2
		if absf(yaw_error) > YAW_LIMIT:
			score += 2.5
		if outward.dot(desired) < 0.0:
			score += 4.0
		if score < best_score:
			best_score = score
			best = i
			best_yaw = yaw_limited
			best_pitch = pitch_limited
	if best < 0:
		return {"ok": false, "reason": "no_solution"}
	man(best)
	var gun: Dictionary = _guns[best]
	gun["yaw_target"] = best_yaw
	gun["pitch_target"] = best_pitch
	_snap_aim(gun)
	gun["loaded"] = true
	gun["loading"] = false
	gun["load_t"] = 0.0
	_set_load_visuals(gun, 0.0, false)
	var result: Dictionary = fire()
	result["debug"] = true
	result["index"] = best
	result["yaw_deg"] = rad_to_deg(best_yaw)
	result["pitch_deg"] = rad_to_deg(best_pitch)
	result["yaw_error_deg"] = rad_to_deg(absf(best_yaw))
	result["pitch_deg_solved"] = rad_to_deg(best_pitch)
	result["aim_score"] = best_score
	return result


func _ballistic_pitch(horizontal: float, height: float, speed: float) -> float:
	if horizontal < 0.05:
		return PITCH_MAX if height > 0.0 else PITCH_MIN
	var v2: float = speed * speed
	var discriminant: float = v2 * v2 - GRAVITY * (GRAVITY * horizontal * horizontal + 2.0 * height * v2)
	if discriminant < 0.0:
		return atan2(height, horizontal)
	var root: float = sqrt(discriminant)
	return atan2(v2 - root, GRAVITY * horizontal)


func look_yaw(index: int) -> float:
	if not _installed or index < 0 or index >= _guns.size():
		return 0.0
	var gun: Dictionary = _guns[index]
	var outward: Vector3 = _gun_rest_outward_world(index)
	if outward.length_squared() < 1.0e-6:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	# Godot's player faces -Z, so the heading that looks along a direction d is
	# atan2(-d.x, -d.z) (same convention as main.gd's spawn facing).
	return atan2(-outward.x, -outward.z)


# ================================================================== world points
func mount_world(index: int) -> Vector3:
	if not _installed or index < 0 or index >= _guns.size():
		return Vector3.ZERO
	var gun: Dictionary = _guns[index]
	var node := gun.get("node") as Node3D
	if is_instance_valid(node):
		return node.global_position
	if is_instance_valid(_model):
		return _model.global_transform * (gun.get("mount_local", Vector3.ZERO) as Vector3)
	return gun.get("mount_world", Vector3.ZERO)


func station_world(index: int) -> Vector3:
	if not _installed or index < 0 or index >= _guns.size():
		return Vector3.ZERO
	var gun: Dictionary = _guns[index]
	var mount: Vector3 = mount_world(index)
	var inward: Vector3 = gun.get("inward_local", Vector3.RIGHT)
	if is_instance_valid(_model):
		var direction: Vector3 = _model.global_basis * inward
		direction.y = 0.0
		if direction.length_squared() > 1.0e-6:
			direction = direction.normalized()
			var up: Vector3 = _model.global_basis * Vector3.UP
			up = up.normalized() if up.length_squared() > 1.0e-6 else Vector3.UP
			return mount + direction * STATION_INSET + up * 0.02
	return mount + Vector3(0.0, 0.02, 0.0)


func _gun_rest_outward_world(index: int) -> Vector3:
	if not _installed or index < 0 or index >= _guns.size():
		return Vector3.ZERO
	var gun: Dictionary = _guns[index]
	var outward: Vector3 = gun.get("outward_world", Vector3.RIGHT)
	if is_instance_valid(_model):
		var inbound_local: Vector3 = gun.get("inward_local", Vector3.RIGHT)
		outward = (_model.global_basis * (-inbound_local))
		outward.y = 0.0
		if outward.length_squared() > 1.0e-6:
			return outward.normalized()
	return outward


func _gun_direction(index: int) -> Vector3:
	if not _installed or index < 0 or index >= _guns.size():
		return Vector3.ZERO
	var gun: Dictionary = _guns[index]
	var barrel := gun.get("barrel") as Node3D
	if is_instance_valid(barrel):
		var direction: Vector3 = barrel.global_basis * (gun.get("local_forward", Vector3.FORWARD) as Vector3)
		if direction.length_squared() > 1.0e-8:
			return direction.normalized()
	var pivot := gun.get("pivot") as Node3D
	if is_instance_valid(pivot):
		var direction: Vector3 = pivot.global_basis * (gun.get("local_forward", Vector3.FORWARD) as Vector3)
		if direction.length_squared() > 1.0e-8:
			return direction.normalized()
	return _fallback_direction(gun)


func _fallback_direction(gun: Dictionary) -> Vector3:
	var forward: Vector3 = _gun_rest_outward_world(int(gun.get("ordinal", 0)))
	if forward.length_squared() < 1.0e-6:
		forward = Vector3.RIGHT
	forward = forward.normalized()
	forward = forward.rotated(Vector3.UP, float(gun.get("yaw", 0.0)))
	var right: Vector3 = forward.cross(Vector3.UP)
	if right.length_squared() < 1.0e-6:
		right = forward.cross(Vector3.RIGHT)
	if right.length_squared() > 1.0e-6:
		forward = forward.rotated(right.normalized(), float(gun.get("pitch", 0.0)))
	return forward.normalized()


func _muzzle_world(index: int) -> Vector3:
	if not _installed or index < 0 or index >= _guns.size():
		return Vector3.ZERO
	var gun: Dictionary = _guns[index]
	var marker := gun.get("muzzle_marker") as Node3D
	if is_instance_valid(marker):
		return marker.global_position
	var from: Vector3 = mount_world(index)
	var direction: Vector3 = _gun_direction(index)
	if direction.length_squared() < 1.0e-6:
		direction = _fallback_direction(gun)
	return from + direction * float(gun.get("muzzle_len", 1.35))


func _space_state() -> PhysicsDirectSpaceState3D:
	if not is_inside_tree():
		return null
	return get_world_3d().direct_space_state


# ================================================================== per-frame
func _process(delta: float) -> void:
	if not _installed:
		return
	var clamped_delta: float = minf(maxf(delta, 0.0), 0.1)
	for i: int in _guns.size():
		_advance_gun(_guns[i], clamped_delta)
	_aim_tick -= clamped_delta
	if _man_index >= 0:
		if _aim_tick <= 0.0:
			_aim_tick = AIM_REFRESH
			_update_aim_dots()
	else:
		_hide_aim_dots()
	_update_flashes(clamped_delta)
	_update_puffs(clamped_delta)


func _advance_gun(gun: Dictionary, delta: float) -> void:
	var changed := false
	var yaw: float = float(gun.get("yaw", 0.0))
	var yaw_target: float = float(gun.get("yaw_target", 0.0))
	if absf(yaw - yaw_target) > 1.0e-5:
		yaw += (yaw_target - yaw) * (1.0 - exp(-9.0 * delta))
		if absf(yaw - yaw_target) < 5.0e-4:
			yaw = yaw_target
		gun["yaw"] = yaw
		changed = true
	var pitch: float = float(gun.get("pitch", 0.0))
	var pitch_target: float = float(gun.get("pitch_target", 0.0))
	if absf(pitch - pitch_target) > 1.0e-5:
		pitch += (pitch_target - pitch) * (1.0 - exp(-9.0 * delta))
		if absf(pitch - pitch_target) < 5.0e-4:
			pitch = pitch_target
		gun["pitch"] = pitch
		changed = true
	var recoil: float = float(gun.get("recoil", 0.0))
	if recoil > 0.0:
		recoil = maxf(0.0, recoil - RECOIL_RETURN_SPEED * delta)
		gun["recoil"] = recoil
		changed = true
	if changed:
		_apply_gun_pose(gun, false)
	if bool(gun.get("loading", false)):
		var load_t: float = float(gun.get("load_t", 0.0)) + delta
		gun["load_t"] = load_t
		var t: float = clampf(load_t / LOAD_TIME, 0.0, 1.0)
		_set_load_visuals(gun, t, true)
		if t >= 1.0:
			gun["loading"] = false
			gun["loaded"] = true
			_set_load_visuals(gun, 1.0, false)


func _apply_gun_pose(gun: Dictionary, force: bool) -> void:
	var yaw: float = float(gun.get("yaw", 0.0))
	var pitch: float = float(gun.get("pitch", 0.0))
	var recoil: float = float(gun.get("recoil", 0.0))
	if not force:
		if absf(yaw - float(gun.get("applied_yaw", 0.0))) < 1.0e-6 \
				and absf(pitch - float(gun.get("applied_pitch", 0.0))) < 1.0e-6 \
				and absf(recoil - float(gun.get("applied_recoil", 0.0))) < 1.0e-6:
			return
	gun["applied_yaw"] = yaw
	gun["applied_pitch"] = pitch
	gun["applied_recoil"] = recoil
	var pivot := gun.get("pivot") as Node3D
	if is_instance_valid(pivot):
		pivot.basis = (gun.get("pivot_rest_basis", Basis.IDENTITY) as Basis) * Basis(Vector3.UP, yaw)
		pivot.force_update_transform()
	var barrel := gun.get("barrel") as Node3D
	if is_instance_valid(barrel):
		var axis: Vector3 = gun.get("pitch_axis", Vector3.RIGHT)
		barrel.basis = (gun.get("barrel_rest_basis", Basis.IDENTITY) as Basis) * Basis(axis, pitch)
		var rest_position: Vector3 = gun.get("barrel_rest_position", Vector3.ZERO)
		if recoil > 1.0e-5:
			var forward_parent: Vector3 = barrel.basis * (gun.get("local_forward", Vector3.FORWARD) as Vector3)
			barrel.position = rest_position - forward_parent.normalized() * recoil
		else:
			barrel.position = rest_position
		barrel.force_update_transform()


func _update_flashes(delta: float) -> void:
	for gun: Dictionary in _guns:
		var flash := gun.get("flash") as MeshInstance3D
		if not is_instance_valid(flash):
			continue
		var left: float = float(gun.get("flash_t", 0.0))
		if left <= 0.0:
			continue
		left = maxf(0.0, left - delta)
		gun["flash_t"] = left
		flash.visible = left > 0.0
		if left > 0.0:
			flash.scale = flash.scale * (1.0 + 6.0 * delta)


func _update_aim_dots() -> void:
	if _man_index < 0 or _man_index >= _guns.size():
		_hide_aim_dots()
		return
	var from: Vector3 = _muzzle_world(_man_index)
	var direction: Vector3 = _gun_direction(_man_index)
	if direction.length_squared() < 1.0e-6:
		_hide_aim_dots()
		return
	var velocity: Vector3 = direction * BALL_SPEED
	var at: Vector3 = from
	var space := _space_state()
	var shown := 0
	var stop := false
	for i: int in _aim_dots.size():
		if stop:
			break
		var next: Vector3 = at + velocity * AIM_STEP
		velocity += Vector3.DOWN * GRAVITY * AIM_STEP
		if i >= 4 and space != null:
			var query := PhysicsRayQueryParameters3D.create(at, next, 1, _own_rids)
			query.hit_from_inside = true
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var dot: MeshInstance3D = _aim_dots[shown]
				dot.visible = true
				dot.global_position = hit.get("position", next)
				dot.scale = Vector3.ONE
				shown += 1
				stop = true
				break
		if _is_water_point(next):
			var water_dot: MeshInstance3D = _aim_dots[shown]
			water_dot.visible = true
			water_dot.global_position = next
			water_dot.scale = Vector3.ONE * 1.15
			shown += 1
			stop = true
			break
		var marker: MeshInstance3D = _aim_dots[shown]
		marker.visible = true
		marker.global_position = next
		marker.scale = Vector3.ONE * clampf(1.1 - float(i) / float(_aim_dots.size()), 0.35, 1.1)
		shown += 1
		at = next
		if at.y < -0.6:
			break
	for i: int in range(shown, _aim_dots.size()):
		_aim_dots[i].visible = false


func _hide_aim_dots() -> void:
	for dot: MeshInstance3D in _aim_dots:
		if is_instance_valid(dot):
			dot.visible = false


func _is_water_point(point: Vector3) -> bool:
	if not is_instance_valid(_basin) or not _basin.has_method("depth_at"):
		return false
	var depth: float = float(_basin.call("depth_at", point.x, point.z))
	var level := -0.55
	if _basin.has_method("water_level"):
		level = float(_basin.call("water_level"))
	return depth > 0.05 and point.y <= level


# ================================================================== effects
func _spawn_puffs(kind: String, origin: Vector3, direction: Vector3, count: int,
		speed: float, start_scale: float, end_scale: float, rise: float) -> void:
	var material: Material = _mats.get(kind, _mats.get("smoke"))
	var dir: Vector3 = direction
	if dir.length_squared() < 1.0e-6:
		dir = Vector3.UP
	dir = dir.normalized()
	for i: int in count:
		var entry := _take_puff()
		if entry.is_empty():
			return
		var node := entry.get("node") as MeshInstance3D
		if not is_instance_valid(node):
			continue
		node.material_override = material
		var sideways := dir.cross(Vector3.UP)
		if sideways.length_squared() < 1.0e-6:
			sideways = dir.cross(Vector3.RIGHT)
		sideways = sideways.normalized() if sideways.length_squared() > 1.0e-6 else Vector3.RIGHT
		var upward: Vector3 = sideways.cross(dir).normalized()
		var spread: Vector3 = sideways * _rng.randf_range(-1.0, 1.0) \
			+ upward * _rng.randf_range(-0.6, 1.0) + dir * _rng.randf_range(0.1, 0.8)
		entry["velocity"] = spread.normalized() * speed * _rng.randf_range(0.45, 1.0) \
			+ Vector3.UP * rise
		entry["life"] = 0.0
		entry["max_life"] = (1.25 if kind == "smoke" else 0.75) * _rng.randf_range(0.7, 1.2)
		entry["start"] = start_scale * _rng.randf_range(0.7, 1.2)
		entry["end"] = end_scale * _rng.randf_range(0.8, 1.4)
		entry["gravity"] = (-1.2 if kind == "smoke" else -7.0)
		node.material_override = material
		node.global_position = origin + spread.normalized() * _rng.randf_range(0.0, 0.5)
		node.scale = Vector3.ONE * float(entry["start"])
		node.transparency = 0.0
		node.visible = true


func _take_puff() -> Dictionary:
	for entry: Dictionary in _puffs:
		var node := entry.get("node") as MeshInstance3D
		if is_instance_valid(node) and not node.visible:
			return entry
	return {}


func _update_puffs(delta: float) -> void:
	for entry: Dictionary in _puffs:
		var node := entry.get("node") as MeshInstance3D
		if not is_instance_valid(node) or not node.visible:
			continue
		var life: float = float(entry.get("life", 0.0)) + delta
		var maximum: float = maxf(0.05, float(entry.get("max_life", 1.0)))
		if life >= maximum:
			node.visible = false
			continue
		entry["life"] = life
		var t: float = life / maximum
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		velocity.y += float(entry.get("gravity", 0.0)) * delta
		velocity *= (1.0 - 1.4 * delta)
		entry["velocity"] = velocity
		node.global_position += velocity * delta
		var start: float = float(entry.get("start", 1.0))
		var end: float = float(entry.get("end", 2.0))
		node.scale = Vector3.ONE * lerpf(start, end, sqrt(t))
		node.transparency = clampf(t * 1.1, 0.0, 1.0)


func _spawn_impact_effects(result: Dictionary) -> void:
	var kind: String = str(result.get("type", ""))
	var point: Vector3 = result.get("position", Vector3.ZERO)
	var direction: Vector3 = result.get("direction", Vector3.UP)
	if direction.length_squared() < 1.0e-6:
		direction = Vector3.UP
	direction = direction.normalized()
	match kind:
		"water":
			_spawn_puffs("water", point, Vector3.UP, 12, 4.5, 0.55, 1.8, 2.2)
		"castle":
			_spawn_puffs("land", point, direction, 9, 3.6, 0.5, 1.7, 1.2)
			_spawn_puffs("smoke", point, direction, 3, 2.0, 0.8, 2.2, 0.8)
		"ship":
			_spawn_puffs("ship", point, direction, 7, 3.0, 0.45, 1.4, 1.0)
		"land", "expire":
			_spawn_puffs("land", point, Vector3.UP, 6, 2.4, 0.45, 1.4, 1.0)


# ================================================================== projectiles
func _physics_process(delta: float) -> void:
	if not _installed:
		return
	for ball: Variant in _balls:
		if ball == null:
			continue
		if not bool(ball.get("active")):
			continue
		var result: Variant = ball.call("advance", delta)
		if not (result is Dictionary):
			continue
		var impact: Dictionary = result
		if impact.is_empty() or bool(impact.get("ignored", false)):
			continue
		var kind: String = str(impact.get("type", "land"))
		if kind == "expire":
			# A ball that simply ran out of its 8 s life is not a hit.
			_last_impact = impact.duplicate(true)
			continue
		_hits += 1
		match kind:
			"castle":
				_castle_hits += 1
			"water":
				_water_hits += 1
			"ship":
				_ship_hits += 1
		_last_impact = impact.duplicate(true)
		_spawn_impact_effects(impact)


# ================================================================== state
func state() -> Dictionary:
	var manning_now: bool = _installed and _man_index >= 0
	var gun: Dictionary = {}
	if manning_now:
		gun = _guns[_man_index]
	var from := Vector3.ZERO
	var direction := Vector3.ZERO
	if manning_now:
		from = _muzzle_world(_man_index)
		direction = _gun_direction(_man_index)
	var active_balls := 0
	for ball: Variant in _balls:
		if ball != null and bool(ball.get("active")):
			active_balls += 1
	return {
		"ok": _installed,
		"installed": _installed,
		"manning": manning_now,
		"index": _man_index if manning_now else -1,
		"loaded": bool(gun.get("loaded", false)) if manning_now else false,
		"loading": bool(gun.get("loading", false)) if manning_now else false,
		"load_progress": clampf(float(gun.get("load_t", 0.0)) / LOAD_TIME, 0.0, 1.0) if manning_now else 0.0,
		"yaw_deg": rad_to_deg(float(gun.get("yaw", 0.0))) if manning_now else 0.0,
		"pitch_deg": rad_to_deg(float(gun.get("pitch", 0.0))) if manning_now else 0.0,
		"yaw_target_deg": rad_to_deg(float(gun.get("yaw_target", 0.0))) if manning_now else 0.0,
		"pitch_target_deg": rad_to_deg(float(gun.get("pitch_target", 0.0))) if manning_now else 0.0,
		"yaw_limit_deg": YAW_LIMIT_DEG,
		"pitch_min_deg": PITCH_MIN_DEG,
		"pitch_max_deg": PITCH_MAX_DEG,
		"side": str(gun.get("side", "")) if manning_now else "",
		"label": str(gun.get("label", "")) if manning_now else "",
		"balls_in_stock": _ball_stock,
		# Aliases read by agent E's HUD ("ЯДРА N" in the cannon hint).
		"balls": _ball_stock,
		"ammo": _ball_stock,
		"pool": _balls.size(),
		"balls_active": active_balls,
		"shots": _shots,
		"hits": _hits,
		"castle_hits": _castle_hits,
		"water_hits": _water_hits,
		"ship_hits": _ship_hits,
		"from": from,
		"direction": direction,
		"speed": BALL_SPEED,
		"last_impact": _last_impact.duplicate(true),
		"castle": is_instance_valid(_castle),
		"boat": is_instance_valid(_boat),
		"basin": is_instance_valid(_basin),
		"player": is_instance_valid(_player),
	}


func snapshot() -> Dictionary:
	var out: Dictionary = state()
	var mounts: Array[Vector3] = []
	var stations: Array[Vector3] = []
	var looks: Array[float] = []
	var sides: Array[String] = []
	var loaded_flags: Array[bool] = []
	var yaws: Array[float] = []
	var pitches: Array[float] = []
	for i: int in _guns.size():
		mounts.append(mount_world(i))
		stations.append(station_world(i))
		looks.append(look_yaw(i))
		sides.append(str(_guns[i].get("side", "")))
		loaded_flags.append(bool(_guns[i].get("loaded", false)))
		yaws.append(rad_to_deg(float(_guns[i].get("yaw", 0.0))))
		pitches.append(rad_to_deg(float(_guns[i].get("pitch", 0.0))))
	out["cannon_count"] = _guns.size()
	out["cannon_states"] = []
	for i: int in _guns.size():
		(out["cannon_states"] as Array).append({
			"index": int(_guns[i].get("index", i)),
			"side": str(_guns[i].get("side", "")),
			"label": str(_guns[i].get("label", "")),
			"loaded": bool(_guns[i].get("loaded", false)),
			"yaw_deg": rad_to_deg(float(_guns[i].get("yaw", 0.0))),
			"pitch_deg": rad_to_deg(float(_guns[i].get("pitch", 0.0))),
		})
	out["mounts"] = mounts
	out["stations"] = stations
	out["look_yaw"] = looks
	out["sides"] = sides
	out["loaded_flags"] = loaded_flags
	out["yaws_deg"] = yaws
	out["pitches_deg"] = pitches
	out["last_man_index"] = _last_man_index
	out["ball_speed"] = BALL_SPEED
	out["ball_life"] = BALL_LIFE
	out["recoil_distance"] = RECOIL_DISTANCE
	return out


func _exit_tree() -> void:
	# Balls live under the world, not under this node, so they are freed explicitly.
	for ball: Variant in _balls:
		if ball != null and is_instance_valid(ball):
			ball.queue_free()
	_guns.clear()
	_balls.clear()
	_aim_dots.clear()
	_puffs.clear()
	_installed = false
