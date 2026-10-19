extends Node3D
## DSH_TOWER: host for the siege ram tower.
##
## Owns one AnimatableBody3D machine, publishes the "E — ram" prompt to the same
## castle HUD plaque the ship and the barrels use, and forwards its own E press.
## Installation follows the other castle hosts: a dictionary-returning install()
## called a few physics frames after the castle map exists.

const BodyScript = preload("res://scripts/siege/siege_ram_tower_body.gd")

const SPAWN_LOCAL := Vector3(0.0, 0.0, 80.0)
const SPAWN_YAW := 0.0
const REACH := 3.2

var world: Node3D = null
var castle: Node3D = null
var player: CharacterBody3D = null
var body: AnimatableBody3D = null
var status := "disabled"
var _last_result: Dictionary = {}
var _visuals_optimized := false
var _far_idle := false

func _optimize_visuals(node: Node) -> void:
	# The tower is visible from the ship, so it must not be hidden.  Instead turn
	# off its shadow/GI cost on every mesh; the silhouette stays, rendering drops.
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			var gi := child as GeometryInstance3D
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_optimize_visuals(child)

func install(world_in: Node3D, castle_in: Node3D) -> Dictionary:
	world = world_in
	castle = castle_in
	if not is_instance_valid(world) or not is_instance_valid(castle):
		status = "missing_scene"
		return {"ok": false, "reason": status}
	player = world.get("_player") as CharacterBody3D
	if not is_instance_valid(player):
		status = "missing_player"
		return {"ok": false, "reason": status}
	body = BodyScript.new()
	body.name = "SiegeRamTower"
	add_child(body)
	var built: Dictionary = body.call("install", world, castle, player)
	if not built.get("ok", false):
		status = str(built.get("reason", "install_failed"))
		body.queue_free()
		body = null
		return {"ok": false, "reason": status}
	var spawn := _spawn_world()
	body.call("moor", spawn, SPAWN_YAW)
	process_physics_priority = 110
	status = "ready"
	if not _visuals_optimized:
		_visuals_optimized = true
		_optimize_visuals(body)
	# Optional inspection spawn: open the gate scene right at the push frame.
	if OS.get_cmdline_user_args().has("--player-at-tower=1"):
		player.global_position = body.to_global(Vector3(0.0, 0.15, 4.62))
		player.velocity = Vector3.ZERO
		player.set("_camera_yaw", 0.0)
		player.set("_heading", 0.0)
		var visual := player.get("_visual") as Node3D
		if is_instance_valid(visual):
			visual.rotation.y = deg_to_rad(float(player.get("visual_yaw_degrees")))
		if player.has_method("_update_camera_rotation"):
			player.call("_update_camera_rotation")
		print("DSH_PLAYER_AT_TOWER player=", player.global_position)
	print("DSH_TOWER_STATUS ", status, " spawn=", spawn, " parts=", built.get("parts", 0),
		" colliders=", built.get("colliders", 0))
	return {"ok": true, "spawn": spawn, "parts": built.get("parts", 0),
		"colliders": built.get("colliders", 0), "ram": built.get("ram", false)}

func _spawn_world() -> Vector3:
	var at := castle.to_global(SPAWN_LOCAL)
	at.y = _ground_height(SPAWN_LOCAL.x, SPAWN_LOCAL.z)
	return at

func _ground_height(local_x: float, local_z: float) -> float:
	var field: Variant = world.get("preview_battlefield") if is_instance_valid(world) else null
	if is_instance_valid(field) and (field as Node).has_method("terrain_height"):
		return float((field as Node).call("terrain_height", local_x, local_z))
	return castle.global_position.y

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body):
		return
	# Keep the tower visible from across the map; only stop simulating its
	# machinery when nobody can interact with it.
	body.visible = true
	if is_instance_valid(player) and player.global_position.distance_to(body.global_position) > 70.0:
		if not _far_idle:
			_far_idle = true
			body.process_mode = Node.PROCESS_MODE_DISABLED
			body.collision_layer = 0
			body.collision_mask = 0
		return
	if _far_idle:
		_far_idle = false
		body.process_mode = Node.PROCESS_MODE_INHERIT
		body.collision_layer = 1
		body.collision_mask = 1
	body.call("simulate_step", delta)
	if is_instance_valid(player):
		body.call("climb_assist", player, delta)

# ------------------------------------------------------------------ prompt / E
func action() -> Dictionary:
	if not is_instance_valid(body):
		return {}
	return body.call("prompt_action") as Dictionary

func interact(action_data: Variant = null) -> bool:
	if not is_instance_valid(body):
		return false
	if action_data is Dictionary and str((action_data as Dictionary).get("kind", "")) != "tower_ram":
		return false
	return bool(body.call("trigger_ram"))

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_E:
		return
	if not is_instance_valid(player) or not bool(player.get("_free_mouse_look")):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	var prompt := action()
	if prompt.is_empty():
		return
	if bool(body.call("trigger_ram")):
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ external damage
## Catapult stone / other siege impact.  Returns true when the machine was hit,
## so the caller can spend the projectile and raise its own dust.
func catapult_impact(world_point: Vector3, direction: Vector3 = Vector3.DOWN) -> bool:
	if not is_instance_valid(body):
		return false
	return bool(body.call("blast_at", world_point, 1.35, 420.0, "catapult"))

func powder_blast(world_point: Vector3) -> bool:
	if not is_instance_valid(body):
		return false
	return bool(body.call("blast_at", world_point, 5.2, 3200.0, "powder"))

func contains_point(world_point: Vector3, margin: float = 1.5) -> bool:
	if not is_instance_valid(body):
		return false
	var local: Vector3 = body.call("to_local", world_point)
	return absf(local.x) <= 3.6 + margin and local.z >= -8.6 - margin and local.z <= 5.4 + margin \
		and local.y >= -1.0 and local.y <= 13.6

# ------------------------------------------------------------------ QA
func snapshot() -> Dictionary:
	var out: Dictionary = {"status": status, "spawn": _spawn_world() if is_instance_valid(castle) else Vector3.ZERO}
	if is_instance_valid(body):
		out["body"] = body.call("snapshot")
	return out

func body_ref() -> Node:
	return body

func _exit_tree() -> void:
	status = "removed"
