extends "res://paged_editor_controller.gd"
## The inherited setup creates and synchronously replaces a temporary base
## panel. Give that temporary panel no catalogue; fill the final panel once.
func setup(index: RefCounted, source: Dictionary, player_camera: Camera3D, begin_edit: Callable, end_edit: Callable, catalogue: Array = []) -> Dictionary:
	var result: Dictionary = super.setup(index, source, player_camera, begin_edit, end_edit, [])
	if result.get("ok", false):
		panel.set_catalog(catalogue)
	return result
