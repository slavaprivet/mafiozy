extends RefCounted
## The life owner retains its task; attention only holds the current physical leg.
const Focus = preload("res://scripts/npc_visual/npc_resident_focus29.gd")
const TURN_SPEED := 6.0
var active := false
var _route: RefCounted
var _body: WeakRef

func clear(resume: bool = true) -> void:
	if active and resume and is_instance_valid(_route): _route.attention_resume29()
	var body: Node = _body.get_ref() if _body != null else null
	if is_instance_valid(body) and body.has_meta("npc_attention29"): body.remove_meta("npc_attention29")
	active = false; _route = null; _body = null

func _driver(life: RefCounted) -> RefCounted:
	if life._dsh_simple_goal_active(): return life._dsh_simple
	if life._economy28_active(): return life._economy28.get("_route")
	if life._restaurant28_active(): return life._restaurant28
	if life._roam51_active: return life._roam51
	return null

func step(life: RefCounted, delta: float, row: Dictionary) -> bool:
	var body: CharacterBody3D = life._token.get("body") as CharacterBody3D
	var allowed: bool = is_instance_valid(body) and body.is_inside_tree() and not life._disposed and not row.is_empty()
	allowed = allowed and not bool(row.get("dead", false)) and float(row.get("hp", 0)) > 0.0
	# Only the camera target can enter attention. An unfocused resident releases
	# existing attention immediately, without repeating unrelated admission checks.
	if not allowed or not Focus.focused(body): clear(); return false
	if allowed:
		allowed = life._host.target_current(life._token) and not life._health.should_pause_walk()
		# Damage clears attention synchronously, but gaze is evaluated again next frame.
		# Medical need (including retry cooldown) and the complete hospital visit own
		# movement until the resident has healed and physically left the building.
		allowed = allowed and not life._hospital51_below_threshold(row) and not life._needs_hospital(row) and str(life._goal.get("kind", "")) != "hospital"
		allowed = allowed and (life._threat30 == null or not life._threat30.active())
		allowed = allowed and life._phase != "INCIDENT_REACTING" and not life._incident_waiting_release and not life._interrupting
		var record: Dictionary = life._host.get("_records").get(str(life._token.source_id), {})
		var retaliation: RefCounted = record.get("melee_retaliation")
		if retaliation != null and retaliation.engaged(): allowed = false
	if not allowed: clear(); return false
	var route: RefCounted = _driver(life)
	if life._visit != null or (route == null and life._phase not in ["IDLE", "RESTING", "AMBIENT", "WAITING_FOR_RECOVERY"]):
		clear(); return false
	if active and route != _route: clear()
	if not active:
		if route != null and not route.attention_pause29(): return false
		life._ambient29_cancel("attention")
		active = true; _route = route; _body = weakref(body)
		# These are dwell clocks, never route destinations or saved purchase amounts.
		life._hospital_treat_started = -1.0; life._restaurant28_meal_started = -1.0
		life._hospital28_clear_treatment_pose()
		if life._economy28_active(): life._economy28.pause()
		life._next_decision = life._now
	if _route != null: _route.attention_hold29(delta)
	else:
		var before: Vector3 = body.global_position
		body.velocity.x = 0.0; body.velocity.z = 0.0
		body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 9.8 * delta
		body.move_and_slide()
		body.set_meta("npc_physical_drive51", {"frame":Engine.get_physics_frames(), "body_id":body.get_instance_id(), "from":before, "to":body.global_position, "delta":delta})
	var scene: Node = body.get_tree().current_scene
	var player: Node3D = scene.get("_player") as Node3D
	var facing: Vector3 = player.global_position - body.global_position
	if Vector2(facing.x, facing.z).length_squared() > .0001:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN_SPEED * delta))
	# The existing host performs the sole skeleton/visual-yaw write.
	body.set_meta("npc_attention29", {"frame":Engine.get_physics_frames(), "active":true})
	return true
