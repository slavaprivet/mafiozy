extends "res://transport_registry_perf.gd"
const Timing = preload("res://timing.gd")
func configure(factory: RefCounted, owner: Callable = Callable()) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.configure(factory,owner)
	Timing.record("transport.configure",Time.get_ticks_usec()-start)
	return result
func _check(id: String, record: Variant, trusted: Dictionary = {}) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super._check(id,record,trusted)
	Timing.record("transport._check",Time.get_ticks_usec()-start)
	return result
func _prepare(operation: String, id: String, record: Variant, dry_run: bool) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super._prepare(operation,id,record,dry_run)
	Timing.record("transport._prepare",Time.get_ticks_usec()-start)
	return result
func capture_install_checkpoint() -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.capture_install_checkpoint()
	Timing.record("transport.capture_install_checkpoint",Time.get_ticks_usec()-start)
	return result
func apply_document(document: Dictionary, dry_run: bool = false) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.apply_document(document,dry_run)
	Timing.record("transport.apply_document",Time.get_ticks_usec()-start)
	return result
func create_copy(template_id: String, id: String, frame: Transform3D) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = super.create_copy(template_id,id,frame)
	Timing.record("transport.create_copy",Time.get_ticks_usec()-start)
	return result
