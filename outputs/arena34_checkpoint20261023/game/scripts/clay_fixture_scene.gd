extends "res://scripts/arena27.gd"
func _start_lab() -> void:
	await get_tree().physics_frame
	preview_weapons=load("res://scripts/weapons/preview_weapons.gd").new();add_child(preview_weapons)
	preview_weapons.configure(self,_player)
	_player._weapon_host=preview_weapons
	lab=load("res://scripts/clay_target.gd").new();add_child(lab)
	preview_sword_prototype=lab
	lab.install(self,_player)
	lab.lab_spawn()
	preview_ready=true;lab_ready=true
	_lab_equip(0)
	_player.set_mouse_captured(false)
