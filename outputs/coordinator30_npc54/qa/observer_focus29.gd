extends "observer_death28.gd"
var _focus_frames := 0
var _capturing := false

func _bind(scene: Node3D) -> bool:
	if not super._bind(scene): return false
	# Ordinary close view, without the inherited death fixture's sniper scope.
	_button(MOUSE_BUTTON_RIGHT, false)
	_weapons.equip("none")
	return true

func _physics_process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _phase == "bootstrap":
		if now - _start_ms > 90000: _finish("bootstrap_timeout"); return
		_bind(get_tree().current_scene as Node3D)
		return
	if _capturing: return
	if now > _deadline_ms: _finish("focus_timeout"); return
	_aim()
	var label: Label3D = _body.get_node_or_null("ResidentVisualMotion/DshResidentName") as Label3D
	if label != null and label.visible and label.get_node_or_null("ResidentHealth29") != null:
		_focus_frames += 1
	else: _focus_frames = 0
	if _focus_frames >= 15:
		_capturing = true
		_capture.call_deferred(label)

func _capture(label: Label3D) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("resident_card.png"))
	var row: Dictionary = _health.get("_row")
	var result := {"passed":label.visible and is_equal_approx(float(label.get_meta("hp")),float(row.hp)),
		"health_owner_hp":row.hp,"health_owner_max_hp":row.max_hp,"text":label.get_node("ResidentHealth29").text,
		"card_display_ratio":label.get_meta("card29_display_ratio"),"body_id":_body.get_instance_id(),
		"native_viewport_aim":true,"npc_relocated":false,"health_modified":false,"population":_active_ids()}
	var file := FileAccess.open(_out.path_join("FOCUS_GAME29.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("FOCUS_GAME29 ",JSON.stringify(result));get_tree().quit(0 if result.passed else 1)
