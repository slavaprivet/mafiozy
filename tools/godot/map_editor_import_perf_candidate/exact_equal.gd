extends RefCounted
const Reference = preload("res://scripts/map_editor/trusted_json.gd")
## Exact float64 equality. Normal nonzero finite equal doubles have identical
## bits; signed zero and NaN payloads use the original byte comparison.
static func equal(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not equal(a[index],b[index]): return false
		return true
	if a is int and b is int: return a==b
	if a is float and b is float:
		if a==b and a!=0.0: return true
		if a==0.0 or b==0.0 or is_nan(a) or is_nan(b): return Reference.equal(a,b)
		return false
	if a is int and b is float:
		return b<9223372036854775808.0 and b>=-9223372036854775808.0 and int(b)==a and equal(float(a),b)
	if a is float and b is int: return equal(b,a)
	return typeof(a)==typeof(b) and a==b
