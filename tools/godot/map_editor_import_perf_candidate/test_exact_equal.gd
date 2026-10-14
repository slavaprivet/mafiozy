extends SceneTree
const Candidate = preload("res://exact_equal.gd")
const Reference = preload("res://scripts/map_editor/trusted_json.gd")
var checks := 0
var failures := []
func check(a: Variant,b: Variant) -> void:
	checks += 1
	if Candidate.equal(a,b)!=Reference.equal(a,b): failures.append({"a":str(a),"b":str(b)})
func _initialize() -> void:
	var special_bits := [0, -9223372036854775808, 1, -9223372036854775807, 0x7ff0000000000000, -4503599627370496,0x7ff8000000000001,0x7ff8000000000002,0x7fffffffffffffff,0x3ff0000000000000,0x3ff0000000000001,0x43e0000000000000,0x4340000000000000]
	var floats := []
	var bytes := PackedByteArray()
	bytes.resize(8)
	for bits: int in special_bits:
		bytes.encode_u64(0,bits)
		floats.append(bytes.decode_double(0))
	for a in floats:
		for b in floats: check(a,b)
	for integer in [0,1,-1,9007199254740992,9007199254740993,-9223372036854775808,9223372036854775807]:
		for value in floats:
			check(integer,value)
			check(value,integer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 72658931
	for index in 10000:
		var bits: int = (int(rng.randi())<<32)|int(rng.randi())
		bytes.encode_u64(0,bits)
		var a := bytes.decode_double(0)
		bytes.encode_u64(0,bits+1)
		var b := bytes.decode_double(0)
		check(a,a)
		check(a,b)
		check({"source":[a,{"scale":a}],"opaque":false},{"source":[b,{"scale":b}],"opaque":false})
	print("EXACT_EQUAL_QA "+JSON.stringify({"checks":checks,"failures":failures,"seed":72658931,"reference":"original byte-exact trusted_json equal including NaN payload and signed zero"}))
	quit(0 if failures.is_empty() else 1)
