extends Node3D
## DSH_CLONEDOOR: prostaя otkryvaemaya dver' dlya kopij palacco.
## Veshaetsya na uzel polotna (kopiya SourceDoor_public) vnutri kopii.
## Rabotaet BEZ kontraktov i integracij: sama nahodit igroka i zhitelej po gruppe,
## povorachivaet polotno, pokazyvaet podskazku "E - otkryt'" i pechataet DSH_CLONEDOOR.
##
## Flag: --city-clone-door-swing=1 (default 0 = povedenie ne menyaetsya).

const NEAR_M := 2.5
const PROMPT_M := 3.2
const SWING_DEG := 100.0
const SPEED_DEG_PER_S := 220.0

var clone_name := "clone"
var _closed_y := 0.0
var _angle := 0.0
var _open := false
var _prompt: Label3D
var _prompt_shown := false
var _state := "closed"
var _player: Node3D


static func enabled() -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--city-clone-door-swing="):
			return int(a.trim_prefix("--city-clone-door-swing=")) != 0
	return false


func setup(name_of_clone: String, closed_rotation_y: float) -> void:
	clone_name = name_of_clone
	_closed_y = closed_rotation_y
	rotation.y = _closed_y
	_prompt = Label3D.new()
	_prompt.name = "CloneDoorPrompt"
	_prompt.text = "Е — открыть"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.double_sided = true
	_prompt.pixel_size = .006
	_prompt.font_size = 64
	_prompt.modulate = Color(1, .95, .75, 1)
	_prompt.outline_modulate = Color(0, 0, 0, 1)
	_prompt.outline_size = 16
	_prompt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prompt.visible = false
	add_child(_prompt)
	_prompt.position = Vector3(0, 2.2, 0)


func _player_node() -> Node3D:
	if is_instance_valid(_player): return _player
	for n: Node in get_tree().get_nodes_in_group("player"):
		if n is Node3D: _player = n as Node3D; return _player
	# fallback: uzly s "player"/"hero" v imeni
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var n2: Node = stack.pop_back()
		if n2 == null: continue
		if n2 is Node3D and str(n2.name).to_lower().contains("player"):
			_player = n2 as Node3D; return _player
		for c: Node in n2.get_children(): stack.append(c)
	return null


func _alive_body(skip: Node3D) -> bool:
	# Zhitel' - lyuboj CharacterBody3D, krome igroka, v radiuse NEAR_M.
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null: continue
		if n is CharacterBody3D and n != skip:
			if (n as Node3D).global_position.distance_to(global_position) <= NEAR_M: return true
		for c: Node in n.get_children(): stack.append(c)
	return false


func _process(delta: float) -> void:
	var player := _player_node()
	var player_near := player != null and player.global_position.distance_to(global_position) <= NEAR_M
	var player_prompt := player != null and player.global_position.distance_to(global_position) <= PROMPT_M
	var resident_near := _alive_body(player)

	# Podskazka: pokazyvaem tol'ko igroku i tol'ko kogda dver' zakryta.
	var want_prompt := player_prompt and not _open
	if _prompt != null and want_prompt != _prompt_shown:
		_prompt_shown = want_prompt
		_prompt.visible = want_prompt
		_report("prompt=" + ("shown" if want_prompt else "hidden"), "idle")

	# E - pereklyuchaet dlya igroka.
	if player_near and Input.is_action_just_pressed("ui_accept"):
		_open = not _open
		_report("trigger=player_e", "opening" if _open else "closing")

	# Zhitel' otkryvaet sam.
	if not _open and resident_near:
		_open = true
		_report("trigger=resident", "opening")
	elif _open and not resident_near and not player_near and _angle >= SWING_DEG - .5:
		_open = false
		_report("trigger=idle", "closing")

	var target: float = SWING_DEG if _open else 0.0
	if absf(_angle - target) > .01:
		var step: float = SPEED_DEG_PER_S * delta
		_angle = move_toward(_angle, target, step)
		rotation.y = _closed_y - deg_to_rad(_angle)
		var st := "opening" if _open else "closing"
		if _state != st:
			_state = st
			_report("", st)
	elif _angle == target and _state != ("open" if _open else "closed"):
		_state = "open" if _open else "closed"
		_report("", _state)


func _report(extra: String, state: String) -> void:
	if not enabled(): return
	print("DSH_CLONEDOOR clone=", clone_name, " state=", state,
		" fraction=", "%.2f" % (_angle / SWING_DEG),
		" ", extra, " frame=", Engine.get_physics_frames())
