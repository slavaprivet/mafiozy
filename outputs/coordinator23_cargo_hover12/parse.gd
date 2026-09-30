extends SceneTree
func _initialize():
	var a=load("res://scripts/weapons/weapon_pickup_visuals.gd")
	var b=load("res://scripts/weapons/cargo_aim_picker.gd")
	print("HOVER_PARSE ",a!=null and b!=null)
	quit()
