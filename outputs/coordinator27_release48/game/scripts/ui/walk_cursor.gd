extends RefCounted
## Hardware cursors installed once; no per-frame drawing or retained GPU textures.
static func install() -> void:
	if DisplayServer.get_name() == "headless": return
	var arrow: Texture2D = load("res://assets/ui/cursor_arrow.svg")
	var hand: Texture2D = load("res://assets/ui/cursor_hand.svg")
	Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(5, 3))
	Input.set_custom_mouse_cursor(hand, Input.CURSOR_POINTING_HAND, Vector2(16, 3))

static func release() -> void:
	if DisplayServer.get_name() == "headless": return
	# Input owns cursor textures. Release them before RenderingServer shuts down.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
