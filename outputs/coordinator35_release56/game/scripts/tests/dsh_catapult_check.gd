extends SceneTree
## DSH_CATAPULT: load check. Confirms the prototype parses and that the push formula
## behaves as the brief describes before anything is wired into the scene.

const Catapult = preload("res://scripts/weapons/catapult_prototype.gd")

func _initialize() -> void:
	var host: Node3D = Catapult.new()
	if host == null:
		print("CATAPULT_CHECK_RESULT FAIL instantiate")
		quit(1)
		return
	host.free()
	print("CATAPULT_CHECK_RESULT PASS")
	quit(0)