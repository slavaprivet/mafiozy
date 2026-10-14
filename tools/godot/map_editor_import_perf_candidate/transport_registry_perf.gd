extends "res://transport_registry.gd"
const Provenance = preload("res://provenance.gd")
func _check(id: String,record: Variant,trusted: Dictionary = {}) -> Dictionary:
	if trusted.is_empty():
		if not has_object(id): return _fail("Unknown source ID")
		trusted = _records[id]
	if record==null: return {"ok":true,"record":null}
	var validation := Document.validate_record(record)
	if not validation.ok: return validation
	if validation.record.id!=id: return _fail("Identity mismatch")
	if not Provenance.immutable(validation.record,trusted,_raw.get(trusted.get("template_id",id))): return _fail("Trusted template descriptor changed")
	var frame: Variant = Frames.decode_transform(validation.record.transform)
	if frame==null or not frame.is_finite() or frame.basis.determinant()<=0.000001: return _fail("Invalid transform")
	if not Provenance.transform_extras(validation.record.transform,trusted.transform): return _fail("Transform metadata changed")
	validation.record.source = trusted.source.duplicate(true)
	return {"ok":true,"record":validation.record,"frame":frame}
