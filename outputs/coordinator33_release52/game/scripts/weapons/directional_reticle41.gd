extends Control
## Aim point stays fixed. The arrow shows the side FROM which the cut begins.
var combat: Node
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void:
	visible = is_instance_valid(combat) and combat._active() and combat._directional_enabled41() and not combat._unarmed and not combat._sword_grounded
	if visible: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(combat): return
	var attack = combat._directional41
	var direction: Vector2 = attack.chosen if attack.active() else attack.preview
	direction.y = -direction.y
	var colour := Color(0.94,0.94,0.90,0.94)
	if attack.phase == "windup": colour = Color(1.0,0.78,0.30)
	elif attack.phase == "release": colour = Color(1.0,0.35,0.20)
	elif attack.phase == "recover": colour = Color(0.60,0.64,0.68,0.7)
	var centre := size * 0.5
	draw_circle(centre,3.2,Color(0.0,0.0,0.0,0.75))
	draw_circle(centre,1.8,Color.WHITE)
	var tip := centre+direction*24.0
	var base := centre+direction*16.0
	var side := Vector2(-direction.y,direction.x)*4.0
	draw_line(centre+direction*11.0,tip,Color(0,0,0,0.8),4.0,true)
	draw_line(centre+direction*11.0,tip,colour,2.0,true)
	draw_colored_polygon(PackedVector2Array([tip,base+side,base-side]),colour)
