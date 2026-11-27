extends Control
## Lightweight code-drawn inventory art. New resource kinds can reuse this control
## without adding texture memory or import-time files.

var icon_kind := "wood"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_kind(value: String) -> void:
	icon_kind = value
	queue_redraw()

func _draw() -> void:
	if icon_kind == "wood":
		_draw_wood()
		return
	var center := size * 0.5
	draw_circle(center, minf(size.x,size.y)*0.25,Color("77817e"))
	draw_string(ThemeDB.fallback_font,center-Vector2(5,-5),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)

func _draw_wood() -> void:
	var scale := minf(size.x/128.0,size.y/96.0)
	var origin := Vector2((size.x-128.0*scale)*0.5,(size.y-96.0*scale)*0.5)
	for entry: Array in [[Vector2(22,53),-0.20,Color("754526")],
			[Vector2(48,31),0.13,Color("996036")],[Vector2(57,61),-0.05,Color("87502c")]]:
		_draw_log(origin+(entry[0] as Vector2)*scale,float(entry[1]),entry[2] as Color,scale)

func _draw_log(at: Vector2,angle: float,bark: Color,scale: float) -> void:
	var length := 64.0*scale
	var radius := 13.0*scale
	var axis := Vector2(cos(angle),sin(angle))
	var side := Vector2(-axis.y,axis.x)
	var start := at
	var finish := at+axis*length
	var polygon := PackedVector2Array([start-side*radius,start+side*radius,
		finish+side*radius,finish-side*radius])
	draw_colored_polygon(polygon,bark)
	draw_line(start-side*radius*0.72,finish-side*radius*0.72,bark.lightened(0.18),2.0*scale,true)
	draw_line(start+side*radius*0.35,finish+side*radius*0.35,bark.darkened(0.20),2.0*scale,true)
	draw_circle(finish,radius,Color("c58a51"))
	draw_circle(finish,radius*0.72,Color("ddb173"))
	draw_arc(finish,radius*0.43,0.0,TAU,18,Color("9c6339"),1.4*scale,true)
	draw_circle(finish,radius*0.10,Color("82502e"))
