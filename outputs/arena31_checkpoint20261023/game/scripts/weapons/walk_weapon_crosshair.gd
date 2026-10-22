extends Control
## Source weapon_crosshair.mjs: physical accuracy cone -> bounded screen gap.
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
var gap := 3
var spread := 0.0
var arms := true
var redraws := 0
var _arm_style: StyleBoxFlat
var _dot_style: StyleBoxFlat
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
	_arm_style=StyleBoxFlat.new();_arm_style.bg_color=Color("f7f4e8");_arm_style.set_corner_radius_all(1)
	# CSS shadow0 0 2px 1px #111: bounded native soft shadow approximation.
	_arm_style.shadow_color=Color("111111");_arm_style.shadow_size=3
	_dot_style=StyleBoxFlat.new();_dot_style.bg_color=Color.WHITE;_dot_style.shadow_color=Color("111111");_dot_style.shadow_size=3
static func sample_gap(state: Dictionary,input: Dictionary,height: float,fov: float) -> Dictionary:
	var sample:Dictionary=Fire.sample_accuracy(state,input)
	var pixels:float=tan(float(sample.spread))*height/(2*tan(deg_to_rad(fov)*.5))
	sample["gap"]=clampf(3+pixels,3,64);sample["rounded_gap"]=int(floor(float(sample.gap)+.5))
	return sample
static func arm_rects(value: int) -> Array[Rect2]:
	return [Rect2(-value-6,-1,6,2),Rect2(value,-1,6,2),Rect2(-1,-value-6,2,6),Rect2(-1,value,2,6)]
func present(state: Dictionary,input: Dictionary,height: float,fov: float,show_arms: bool=true) -> void:
	var sample:Dictionary=sample_gap(state,input,height,fov)
	spread=float(sample.spread)
	var next:int=sample.rounded_gap
	if next==gap and arms==show_arms:return
	gap=next;arms=show_arms;redraws+=1;queue_redraw()
func _draw() -> void:
	draw_style_box(_dot_style,Rect2(-1,-1,2,2))
	if arms:
		for rect:Rect2 in arm_rects(gap):draw_style_box(_arm_style,rect)
func snapshot() -> Dictionary:
	return {"gap":gap,"spread":spread,"arms":arms,"redraws":redraws,"dot":Rect2(-1,-1,2,2),"rects":arm_rects(gap) if arms else []}
