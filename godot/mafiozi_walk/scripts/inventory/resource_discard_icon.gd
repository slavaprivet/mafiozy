extends Control
## Small, resolution-independent discard symbol used by the resource context menu.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(20, 20)

func _draw() -> void:
	var ink := Color("d7c18a")
	draw_line(Vector2(5, 6), Vector2(15, 6), ink, 1.6, true)
	draw_line(Vector2(7, 4), Vector2(13, 4), ink, 1.6, true)
	draw_rect(Rect2(6, 7, 8, 9), ink, false, 1.6, true)
	draw_line(Vector2(9, 9), Vector2(9, 14), ink, 1.2, true)
	draw_line(Vector2(12, 9), Vector2(12, 14), ink, 1.2, true)
