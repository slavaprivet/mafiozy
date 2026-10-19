extends "res://tests/native_fixture.gd"

var edge_bounds: Dictionary = {}
var edge_calls := 0

func edge_diagnostics() -> Dictionary:
	edge_calls += 1
	return {"sourceBounds": edge_bounds}

func edge_number(value: Variant) -> Variant:
	if value is String and value == "NaN": return NAN
	if value is String and value == "Infinity": return INF
	return value

func _ready() -> void:
	var sampler = Sampler.new()
	var body := Node3D.new()
	add_child(body)
	var wrapper := RefCounted.new()
	var rows: Array = []
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://qa_cases.json"))
	for item: Dictionary in cases:
		if item.get("new_owner", false): wrapper = RefCounted.new()
		if item.get("new_node", false):
			body.free()
			body = Node3D.new()
			add_child(body)
		if item.get("reset", false): sampler.reset()
		if item.has("bounds"): edge_bounds = item.bounds
		if item.has("p"): body.position = Vector3(edge_number(item.p[0]), edge_number(item.p[1]), edge_number(item.p[2]))
		body.rotation.y = 0.7
		body.set_meta("massKg", item.get("meta_mass", 80))
		var options: Dictionary = item.duplicate()
		options.hero_owner = wrapper
		options.diagnostics = Callable(self, "edge_diagnostics")
		if options.has("vertical_velocity"): options.vertical_velocity = edge_number(options.vertical_velocity)
		var sample: Dictionary = sampler.sample(null if item.get("missing", false) else body, edge_number(item.get("dt", 0.1)), options)
		var normalized: Variant = null
		if not sample.is_empty():
			var v: Variant = sample.get("velocity", null)
			normalized = {"id":sample.id, "kind":sample.kind,"p":[sample.position.x,sample.position.y,sample.position.z],"yaw":sample.yaw,"contactOffsetY":sample.contactOffsetY,"enabled":sample.enabled,"teleport":sample.teleport,"v":[v.x,v.y,v.z] if v != null else null,"mass":sample.get("massKg",null),"footprint":sample.get("footprint",null)}
		rows.append({"name":item.name,"sample":normalized,"callbacks":edge_calls})
	print("INDEPENDENT_EDGE_TRACE=" + JSON.stringify(rows))
	body.free()
	await super._ready()
