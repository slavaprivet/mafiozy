extends RefCounted
## Accept only trusted source or its exact JSON transport representation.
## Never normalise caller data or use an epsilon for immutable authority fields.
static func equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not equal(a[index], b[index]): return false
		return true
	if a is int and b is int: return a == b
	if a is float and b is float: return float_bits(a) == float_bits(b)
	if a is int and b is float:
		return b < 9223372036854775808.0 and b >= -9223372036854775808.0 and int(b) == a and float_bits(float(a)) == float_bits(b)
	if a is float and b is int: return equal(b, a)
	return typeof(a) == typeof(b) and a == b

static func float_bits(value: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes

static func transport(trusted: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(trusted, "", true, true))

static func matches(trusted: Variant, supplied: Variant) -> bool:
	return equal(trusted, supplied) or equal(transport(trusted), supplied)
