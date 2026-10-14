extends "res://scripts/procedural_registry.gd"
const Provenance = preload("res://provenance.gd")
func _check(id: String, record: Variant, trusted: Dictionary = {}) -> Dictionary:
	if trusted.is_empty():
		if not has_object(id): return _fail("Unknown procedural identity")
		trusted = _records[id]
	if record==null: return {"ok":true,"record":null,"frame":null}
	var checked := Document.validate_record(record)
	if not checked.ok: return checked
	if checked.record.id!=id: return _fail("Identity mismatch")
	var template: String = trusted.get("template_id",id)
	if not Provenance.immutable(checked.record,trusted,_raw_sources.get(template)):
		return _fail("Trusted source/model/template cannot change: "+id)
	checked.record.source = trusted.source.duplicate(true)
	if not Provenance.transform_extras(checked.record.transform,trusted.transform): return _fail("Unknown transform metadata cannot change")
	var frame: Variant = _decode(checked.record.transform)
	if frame==null or not frame.is_finite() or frame.basis.determinant()<=0.000001: return _fail("Invalid frame")
	if _factory._paint_ids.has(id) or _factory._paint_ids.has(trusted.get("template_id","")):
		if not frame.basis.y.normalized().is_equal_approx(Vector3.UP): return _fail("Road paint must stay upright")
	return {"ok":true,"record":checked.record,"frame":frame}
