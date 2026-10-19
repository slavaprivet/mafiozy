extends "res://scripts/map_editor/composite_registry.gd"
const Timing = preload("res://timing.gd")
func configure(children: Array, map_id: String, metadata: Dictionary = {}) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.configure(children,map_id,metadata)
	Timing.record("composite.configure",Time.get_ticks_usec()-start)
	return result
func _partition(document: Dictionary) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super._partition(document)
	Timing.record("composite._partition",Time.get_ticks_usec()-start)
	return result
func _capture() -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super._capture()
	Timing.record("composite._capture",Time.get_ticks_usec()-start)
	return result
func apply_document(document: Dictionary, dry_run: bool = false) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.apply_document(document,dry_run)
	Timing.record("composite.apply_document",Time.get_ticks_usec()-start)
	return result
