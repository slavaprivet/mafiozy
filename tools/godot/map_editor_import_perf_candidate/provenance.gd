extends RefCounted
const Trusted = preload("res://exact_equal.gd")
static func immutable(row: Dictionary,trusted: Dictionary,raw_source: Variant) -> bool:
	if row.size()!=trusted.size(): return false
	for key in trusted:
		if not row.has(key): return false
		if key=="transform": continue
		if key=="source":
			if not Trusted.equal(row[key],trusted[key]) and (raw_source==null or not Trusted.equal(row[key],raw_source)): return false
		elif not Trusted.equal(row[key],trusted[key]): return false
	return true
static func transform_extras(row: Dictionary,trusted: Dictionary) -> bool:
	if row.size()!=trusted.size(): return false
	for key in trusted:
		if not row.has(key): return false
		if key not in ["position","rotation","scale"] and not Trusted.equal(row[key],trusted[key]): return false
	return true
