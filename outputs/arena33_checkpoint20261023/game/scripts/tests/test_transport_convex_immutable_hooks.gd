extends SceneTree

class SealedConvex:
	extends ConvexPolygonShape3D
	var sealed := false
	var intercepted: Array[String] = []
	func _set(property: StringName, _value: Variant) -> bool:
		intercepted.append(String(property))
		return sealed and String(property) in ["points","margin","custom_solver_bias"]
	func _validate_property(property: Dictionary) -> void:
		if sealed and String(property.get("name","")) in ["points","margin","custom_solver_bias"]:
			property.usage = int(property.usage) | PROPERTY_USAGE_READ_ONLY

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func _points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(0,1,-1),Vector3(0,0,1)])

func _new_sealed() -> SealedConvex:
	var shape := SealedConvex.new()
	shape.points=_points()
	shape.margin=.04
	shape.custom_solver_bias=0.0
	shape.sealed=true
	shape.notify_property_list_changed()
	return shape

func run() -> void:
	var scene := Node3D.new(); root.add_child(scene)
	var body := StaticBody3D.new(); scene.add_child(body)
	var collider := CollisionShape3D.new(); body.add_child(collider)
	var shape := _new_sealed(); collider.shape=shape
	var through: Shape3D = collider.shape
	var original_points := shape.points.to_byte_array()
	var altered := shape.points; altered[0].x -= 2.0
	through.points=altered
	var assignment_points_changed := shape.points.to_byte_array()!=original_points
	var assignment_intercepted := shape.intercepted.has("points")
	shape=_new_sealed(); collider.shape=shape
	through=collider.shape
	var margin_before := shape.margin
	through.margin=margin_before+.2
	var assignment_margin_changed := shape.margin!=margin_before
	var assignment_margin_intercepted := shape.intercepted.has("margin")
	shape=_new_sealed(); collider.shape=shape
	through=collider.shape
	var bias_before := shape.custom_solver_bias
	through.custom_solver_bias=.3
	var assignment_bias_changed := shape.custom_solver_bias!=bias_before
	var assignment_bias_intercepted := shape.intercepted.has("custom_solver_bias")
	shape=_new_sealed(); collider.shape=shape
	through=collider.shape
	var set_points := shape.points; set_points[0].y -= 2.0
	through.set("points",set_points)
	var set_points_changed := shape.points.to_byte_array()!=original_points
	var set_points_intercepted := shape.intercepted.has("points")
	shape=_new_sealed(); collider.shape=shape
	through=collider.shape
	through.set("margin",.37)
	var set_margin_changed := shape.margin!=.04
	var set_margin_intercepted := shape.intercepted.has("margin")
	shape=_new_sealed(); collider.shape=shape
	through=collider.shape
	through.set("custom_solver_bias",.4)
	var set_bias_changed := shape.custom_solver_bias!=0.0
	var set_bias_intercepted := shape.intercepted.has("custom_solver_bias")
	shape=_new_sealed(); collider.shape=shape
	var duplicate := shape.duplicate(true)
	var duplicate_script: bool = duplicate.get_script()==shape.get_script()
	var duplicate_sealed: bool = duplicate.get("sealed") == true
	var duplicate_before := (duplicate as ConvexPolygonShape3D).points.to_byte_array()
	var duplicate_points := (duplicate as ConvexPolygonShape3D).points
	duplicate_points[0].z -= 2.0
	duplicate.set("points",duplicate_points)
	var duplicate_changed := (duplicate as ConvexPolygonShape3D).points.to_byte_array()!=duplicate_before
	var rid_before: Variant = PhysicsServer3D.shape_get_data(shape.get_rid())
	var rid_data := rid_before as PackedVector3Array
	var rid_call_ok := false
	if rid_data.size()>0:
		rid_data[0].x-=2.0
		PhysicsServer3D.shape_set_data(shape.get_rid(),rid_data)
		rid_call_ok=true
	var rid_after: Variant = PhysicsServer3D.shape_get_data(shape.get_rid())
	var rid_changed: bool = rid_call_ok and rid_after!=rid_before
	var resource_points_after_rid := shape.points.to_byte_array()!=original_points
	# This test is diagnostic: report whether mutation was denied, do not assume it.
	var results := {"assignment":{"points_changed":assignment_points_changed,"points_intercepted":assignment_intercepted,"margin_changed":assignment_margin_changed,"margin_intercepted":assignment_margin_intercepted,"bias_changed":assignment_bias_changed,"bias_intercepted":assignment_bias_intercepted},"set":{"points_changed":set_points_changed,"points_intercepted":set_points_intercepted,"margin_changed":set_margin_changed,"margin_intercepted":set_margin_intercepted,"bias_changed":set_bias_changed,"bias_intercepted":set_bias_intercepted},"duplicate":{"script_preserved":duplicate_script,"sealed_preserved":duplicate_sealed,"points_changed":duplicate_changed},"rid":{"data_type":type_string(typeof(rid_before)),"call_ok":rid_call_ok,"physics_data_changed":rid_changed,"resource_points_changed":resource_points_after_rid}}
	check(collider.shape==shape,"collision node exposes same subclass resource")
	check(rid_call_ok,"physics RID data accessible")
	print("TRANSPORT_CONVEX_IMMUTABILITY ",JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	quit(0 if failures.is_empty() else 1)
