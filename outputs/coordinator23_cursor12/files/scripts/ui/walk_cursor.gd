extends RefCounted
## Small hardware cursors: one installation, no per-frame UI drawing or input interception.
const Arrow: Texture2D = preload("res://assets/ui/cursor_arrow.svg")
const Hand: Texture2D = preload("res://assets/ui/cursor_hand.svg")

static func install() -> void:
	if DisplayServer.get_name() == "headless": return
	Input.set_custom_mouse_cursor(Arrow, Input.CURSOR_ARROW, Vector2(5, 3))
	Input.set_custom_mouse_cursor(Hand, Input.CURSOR_POINTING_HAND, Vector2(16, 3))
