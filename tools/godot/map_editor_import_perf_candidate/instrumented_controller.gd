extends "res://scripts/map_editor/editor_controller.gd"
const Timing = preload("res://timing.gd")
func prepare_install_document(source: Dictionary) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.prepare_install_document(source)
	Timing.record("controller.prepare_install_document",Time.get_ticks_usec()-start)
	return result
func install_document(source: Dictionary) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.install_document(source)
	Timing.record("controller.install_document",Time.get_ticks_usec()-start)
	return result
