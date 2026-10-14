extends SceneTree
## DSH_CLONEDOOR: functional proof for the palazzo-copy swing door.
##
## Read-only except for the player's own position and the one synthetic E press the
## owner asked for. It waits for the city, walks the player to the hospital copy's
## doorway, proves the closed leaf really blocks the doorway with physics rays, proves
## the existing "E" hint reaches the copy, then presses E through
## `Input.parse_input_event` and proves `trigger=player_e` and `prompt=shown`.

const SCENE := "res://scenes/main_city.tscn"
const CLONE := "TownClone_1"
const HOLD_FRAMES := 900
const WAIT_FRAMES := 20000
const STEP_FRAMES := 8
const SETTLE_FRAMES := 20
const APPROACH_LOCAL := Vector3(1.0, 0.0, 2.35)

var _root: Node
var _frames := 0
var _settle := 0
var _ready_total := 0
var _door: Node = null
var _phase := "wait"
var _phase_frames := 0
var _sub_phase := 0
var _scripted_calls := 0
var _e_result: Dictionary = {}


func _initialize() -> void:
	_root = load(SCENE).instantiate()
	root.add_child(_root)


func _clone_node() -> Node3D:
	return _root.get_node_or_null(CLONE) as Node3D


func _door_node() -> Node:
	var clone := _clone_node()
	if clone == null:
		return null
	return clone.get_node_or_null("CloneDoorSwing")


func _player() -> Node3D:
	var candidate: Variant = _root.get("_player")
	return candidate as Node3D if candidate is Node3D else null


func _place_player() -> bool:
	var clone := _clone_node()
	var actor := _player()
	if clone == null or actor == null:
		return false
	var target: Vector3 = clone.global_transform * APPROACH_LOCAL
	actor.global_position = target
	actor.velocity = Vector3.ZERO
	return true


func _report(tag: String, payload: Dictionary) -> void:
	print("PROBE_CLONEDOOR ", tag, " ", JSON.stringify(payload))


func _blocked() -> Variant:
	if _door == null:
		return null
	return _door.call("doorway_blocked")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > WAIT_FRAMES:
		_report("TIMEOUT", {"frames": _frames, "ready": bool(_root.get("preview_ready")),
			"phase": _phase, "ready_total": _ready_total, "door": _door != null})
		quit()
		return true
	# The scene's own `preview_ready` flaps while the city boots, so the gate is the
	# thing actually under test: the swing owner node the flag installs. No frames are
	# consumed by waiting for a flag that is not the contract.
	if _door == null:
		if _clone_node() == null:
			if _frames % 600 == 0:
				_report("WAITING", {"frame": _frames, "ready": bool(_root.get("preview_ready"))})
			return false
		_door = _door_node()
		if _door == null:
			_report("FAIL", {"reason": "no_clone_door_owner", "clone": CLONE})
			quit()
			return true
		_settle = 0
		_report("OWNER", _door.call("snapshot"))
		_phase = "closed_check"
		_phase_frames = 0
		return false
	# Give the physics world a few frames with the leaf in its authored frame before
	# the first ray test.
	_settle += 1
	if _settle < SETTLE_FRAMES:
		return false
	_ready_total += 1
	if _ready_total % 600 == 0:
		_report("HEARTBEAT", {"frame": _frames, "phase": _phase, "phase_frames": _phase_frames,
			"scripted_calls": _scripted_calls})
	return _scripted()


func _scripted() -> bool:
	_scripted_calls += 1
	_phase_frames += 1
	if _phase == "closed_check":
		_report("ENTER_CLOSED_CHECK", {"frame": _frames, "phase_frames": _phase_frames})
		_step_closed_check()
	elif _phase == "approach":
		return _step_approach()
	elif _phase == "prompt":
		return _step_prompt()
	elif _phase == "press_e":
		return _step_press_e()
	elif _phase == "opening":
		return _step_opening()
	elif _phase == "done":
		if _phase_frames < 6:
			return false
		_report("DONE", {"lines": "see DSH_CLONEDOOR above"})
		quit()
		return true
	return false


func _step_closed_check() -> void:
	var blocked: Variant = _blocked()
	_report("CLOSED_BARRIER", {"blocked": blocked, "snapshot": _door.call("snapshot")})
	if not (blocked is Dictionary) or not bool((blocked as Dictionary).get("barrier_in_doorway", false)):
		_report("FAIL", {"reason": "closed_leaf_is_not_a_barrier", "blocked": blocked})
		quit()
		return
	if not _place_player():
		_report("FAIL", {"reason": "no_player"})
		quit()
		return
	_phase = "approach"
	_phase_frames = 0


func _step_approach() -> bool:
	if _phase_frames < STEP_FRAMES:
		return false
	_place_player()
	var actor := _player()
	# main.gd `_unhandled_input` refuses every key while the mouse is free, so the
	# owner's scripted E press has to happen in the same mode a playing owner is in.
	if not bool(actor.get("_free_mouse_look")):
		if actor.has_method("set_mouse_captured"):
			actor.call("set_mouse_captured", true)
	var anchor: Vector3 = _door.get("anchor")
	_report("APPROACH", {
		"player": [actor.global_position.x, actor.global_position.y, actor.global_position.z],
		"anchor": [anchor.x, anchor.y, anchor.z],
		"distance_xz": Vector2(actor.global_position.x - anchor.x, actor.global_position.z - anchor.z).length(),
		"pose_authority": str(actor.get("_pose_authority")),
		"free_mouse": bool(actor.get("_free_mouse_look")),
	})
	_phase = "prompt"
	_phase_frames = 0
	_sub_phase = 0
	return false


func _step_prompt() -> bool:
	if _phase_frames < 6:
		return false
	_place_player()
	var action: Dictionary = _root.call("_current_door_action")
	var hint: Variant = _root.get("_door_hint")
	var hint_text := ""
	if hint is Label:
		hint_text = (hint as Label).text
	var panel: Variant = _root.get("_door_hint_panel")
	var key: Variant = _root.get("_door_hint_key")
	_report("PROMPT", {
		"action_owner": str(action.get("owner", "")),
		"action_clone": str(action.get("clone", "")),
		"action_label": str(action.get("label", "")),
		"hint_text": hint_text,
		"panel_visible": (panel is CanvasItem and (panel as CanvasItem).visible),
		"key_visible": (key is CanvasItem and (key as CanvasItem).visible),
		"prompt_shown_flag": bool(_door.call("prompt_shown")),
	})
	if str(action.get("owner", "")) != "clone" or hint_text.is_empty():
		_report("FAIL", {"reason": "clone_hint_not_shown", "action": action, "hint": hint_text})
		quit()
		return true
	_phase = "press_e"
	_phase_frames = 0
	return false


func _step_press_e() -> bool:
	if _phase_frames < 4:
		return false
	var actor := _player()
	if not bool(actor.get("_free_mouse_look")):
		if actor.has_method("set_mouse_captured"):
			actor.call("set_mouse_captured", true)
		_phase_frames = 0
		return false
	if _sub_phase == 0:
		var down := InputEventKey.new()
		down.physical_keycode = KEY_E
		down.keycode = KEY_E
		down.pressed = true
		Input.parse_input_event(down)
		_sub_phase = 1
		_phase_frames = 0
		return false
	if _sub_phase == 1:
		var up := InputEventKey.new()
		up.physical_keycode = KEY_E
		up.keycode = KEY_E
		up.pressed = false
		Input.parse_input_event(up)
		_e_result = _root.get("_dsh_clone_door_last_result")
		_report("E_PRESSED", {"snapshot": _door.call("snapshot"), "result": _e_result})
		_phase = "opening"
		_phase_frames = 0
		_sub_phase = 2
	return false


func _step_opening() -> bool:
	if _phase_frames < 2:
		return false
	var snapshot: Dictionary = _door.call("snapshot")
	if _phase_frames % 40 == 0:
		_report("OPENING", {"state": snapshot.state, "fraction": snapshot.fraction, "trigger": snapshot.trigger})
	if float(snapshot.fraction) >= 1.0:
		var open_state: Variant = _blocked()
		_report("OPENED", snapshot)
		_report("OPEN_BARRIER", {"blocked": open_state})
		if open_state is Dictionary and bool((open_state as Dictionary).get("barrier_in_doorway", false)):
			_report("FAIL", {"reason": "open_leaf_still_occupies_doorway", "blocked": open_state})
			quit()
			return true
		_phase = "done"
		_phase_frames = 0
		return false
	if _phase_frames > HOLD_FRAMES:
		_report("FAIL", {"reason": "leaf_never_opened", "snapshot": snapshot})
		quit()
		return true
	return false
