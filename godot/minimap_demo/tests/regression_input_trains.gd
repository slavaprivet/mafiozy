extends SceneTree
## Native input/draw regression fixture; run directly with --script and --receipt=.
## This is a standalone minimap check, not current286 gameplay acceptance.

class Probe extends "res://addons/walk_minimap/minimap_control.gd":
	var observed_trains: Array[Dictionary] = []
	var observed_draw_frames: int = 0
	var train_draw_calls: int = 0

	func draw_map(canvas: Control) -> void:
		observed_trains.clear()
		train_draw_calls = 0
		observed_draw_frames += 1
		super.draw_map(canvas)

	func _draw_vehicle(canvas: Control, map_projection: RefCounted, value: Dictionary, train: bool) -> void:
		if train:
			train_draw_calls += 1
			var location: Variant = value.get("position", value)
			if MapProjection.valid_point(location):
				var at: Vector2 = map_projection.to_screen(MapProjection.point(location))
				if Rect2(Vector2.ZERO, canvas.size).grow(10).has_point(at):
					observed_trains.append({"id": str(value.get("id", "")), "x": float(location.x), "z": float(location.z)})
		super._draw_vehicle(canvas, map_projection, value, train)

var checks: int = 0
var failures: Array[String] = []
var check_results: Array[Dictionary] = []
var focus_trace: Array[Dictionary] = []
var external_presses: int = 0
var started_ms: int = 0
var finished: bool = false
var train_evidence: Dictionary = {}

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	create_timer(9.0).timeout.connect(_timeout)
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	check_results.append({"label": label, "passed": value})
	if not value:
		failures.append(label)
		printerr("INPUT/TRAIN CHECK FAILED: ", label)

func _timeout() -> void:
	if not finished:
		check(false, "fixture completed within nine-second deadline")
		finish()

func send_key(code: Key, pressed: bool, shifted: bool = false, unicode_value: int = 0) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shifted
	event.unicode = unicode_value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key, shifted: bool = false, unicode_value: int = 0) -> void:
	send_key(code, true, shifted, unicode_value)
	send_key(code, false, shifted, unicode_value)
	await process_frame

func owned_focus(map: Control) -> bool:
	var owner: Control = root.gui_get_focus_owner()
	return is_instance_valid(owner) and (owner == map or map.is_ancestor_of(owner)) and owner.is_visible_in_tree()

func collect_buttons(node: Node, result: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled and child.focus_mode != Control.FOCUS_NONE:
			result.append(child)
		collect_buttons(child, result)

func inspect_focus(map: Probe, direction: String, edge: String, step: int) -> void:
	var owner: Control = root.gui_get_focus_owner()
	var path: String = str(owner.get_path()) if is_instance_valid(owner) else "<none>"
	focus_trace.append({"direction": direction, "edge": edge, "step": step, "owner": path})
	check(map.expanded and owned_focus(map), "%s %s %d retains visible map focus" % [direction, edge, step])
	check(not is_instance_valid(owner) or not map._filter_options.is_ancestor_of(owner), "%s %s %d excludes hidden filter controls" % [direction, edge, step])

func run() -> void:
	# Match the native fixtures' startup delay before registering direct root children.
	await create_timer(2.0).timeout
	root.size = Vector2i(1000, 760)
	var map: Probe = Probe.new()
	map.name = "MinimapUnderTest"
	root.add_child(map)
	var external_button: Button = Button.new()
	external_button.name = "ExternalButton"
	external_button.text = "Outside map"
	external_button.position = Vector2(2, 2)
	external_button.size = Vector2(130, 32)
	external_button.pressed.connect(func() -> void: external_presses += 1)
	root.add_child(external_button)
	var editor: LineEdit = LineEdit.new()
	editor.name = "ExternalLineEdit"
	editor.position = Vector2(140, 2)
	editor.size = Vector2(160, 32)
	root.add_child(editor)
	check(map.set_world({"bounds": {"minX": -100.0, "maxX": 100.0, "minZ": -100.0, "maxZ": 100.0}, "objects": [{"id": "station", "kind": "station", "name": "Station", "x": 0.0, "z": 0.0}]}), "fixture world accepted")
	await process_frame
	check(map.get_parent() == root and external_button.get_parent() == root and editor.get_parent() == root, "map and external focus controls registered as direct siblings")
	external_button.grab_focus()
	await tap(KEY_M)
	check(map.expanded and owned_focus(map), "real M opens and focuses expanded map")
	check(not map._filter_options.is_visible_in_tree(), "filter controls initially hidden")
	var expected: Array[Control] = [map._surface]
	collect_buttons(map, expected)
	check(expected.size() >= 7, "focus fixture includes toolbar and sidebar buttons")
	for shifted: bool in [false, true]:
		map._surface.grab_focus()
		var visited: Array[Control] = [map._surface]
		var direction: String = "ShiftTab" if shifted else "Tab"
		for step: int in range(expected.size() * 2 + 2):
			send_key(KEY_TAB, true, shifted)
			inspect_focus(map, direction, "press", step)
			var owner: Control = root.gui_get_focus_owner()
			if is_instance_valid(owner) and not visited.has(owner):
				visited.append(owner)
			send_key(KEY_TAB, false, shifted)
			inspect_focus(map, direction, "release", step)
			await process_frame
			inspect_focus(map, direction, "frame", step)
		for control: Control in expected:
			check(visited.has(control), "%s visits visible control %s" % [direction, control.get_path()])
	check(external_presses == 0, "Tab traversal does not activate external button")
	# Simulate a host retaining external focus: expanded keyboard handling must still
	# swallow activation keys, even if focus was assigned outside keyboard traversal.
	for code: Key in [KEY_ENTER, KEY_SPACE]:
		external_button.grab_focus()
		await tap(code)
		check(external_presses == 0, "expanded map blocks external activation key %d" % code)
	map._surface.grab_focus()
	await tap(KEY_ESCAPE)
	check(not map.expanded, "real Esc closes expanded map")
	check(root.gui_get_focus_owner() == external_button, "close restores previous external focus")
	await tap(KEY_M)
	check(map.expanded, "real M reopens map")
	await tap(KEY_M)
	check(not map.expanded, "real M closes map")
	editor.grab_focus()
	editor.clear()
	await tap(KEY_M, false, 109)
	check(not map.expanded and root.gui_get_focus_owner() == editor, "closed typing guard preserves LineEdit focus and map state")
	check(editor.text == "m", "closed typing guard delivers M text to LineEdit")
	external_button.grab_focus()
	await tap(KEY_M)
	check(map.expanded and owned_focus(map), "map reopened for native train draw")
	var previous_frames: int = map.observed_draw_frames
	map.update_state({"trains": [{"id": "T", "position": {"x": NAN, "z": 20.0}}], "actors": [{"id": "T", "kind": "train", "x": 10.0, "z": 20.0}]})
	map._request_draw(true)
	# Observe the production draw callback, never invoke it outside native _draw.
	for frame: int in range(8):
		await process_frame
		if map.observed_draw_frames > previous_frames:
			break
	check(map.observed_draw_frames > previous_frames, "native draw ran after mixed train snapshot")
	train_evidence = {"draw_frames_before": previous_frames, "draw_frames_after": map.observed_draw_frames, "draw_calls_in_last_frame": map.train_draw_calls, "markers_in_last_frame": map.observed_trains.duplicate(true)}
	check(map.train_draw_calls == 1, "mixed train sources invoke train drawing exactly once per frame")
	check(map.observed_trains.size() == 1, "invalid first train does not suppress valid same-ID actor")
	if map.observed_trains.size() == 1:
		var marker: Dictionary = map.observed_trains[0]
		check(marker.id == "T" and marker.x == 10.0 and marker.z == 20.0, "native marker uses valid T position x10 z20")
	map.queue_free()
	external_button.queue_free()
	editor.queue_free()
	await process_frame
	finish()

func finish() -> void:
	if finished:
		return
	finished = true
	var result: Dictionary = {"schema": "mafiozi.minimap.input_trains/v1", "checks": checks, "check_results": check_results, "failures": failures, "passed": failures.is_empty(), "elapsed_ms": Time.get_ticks_msec() - started_ms, "input_method": "Input.parse_input_event", "focus_trace": focus_trace, "external_button_presses": external_presses, "train_draw": train_evidence, "full_city_performance": "NOT_RUN"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="):
			var path: String = arg.trim_prefix("--receipt=")
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				failures.append("Cannot write receipt: " + path)
				result.passed = false
				printerr(failures.back())
			else:
				file.store_string(JSON.stringify(result, "\t"))
				file.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
