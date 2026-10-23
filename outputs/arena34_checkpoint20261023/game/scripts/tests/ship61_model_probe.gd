extends SceneTree
## SHIP61 model probe (headless).
##
## Builds the procedural ship model twice (idempotency), inspects every anchor,
## proves the cabin is hollow, that the walkable decks are represented in the
## collision boxes, and that damage calls are safe.  Prints SHIP61_MODEL_OK or
## SHIP61_MODEL_FAIL and quits with the matching code.

const ShipModel := preload("res://scripts/ship/ship_model.gd")

var _fails: Array[String] = []
var _checks := 0

func _initialize() -> void:
	_run()

func _fail(text: String) -> void:
	_fails.append(text)
	print("  FAIL ", text)

func _check(condition: bool, text: String) -> void:
	_checks += 1
	if not condition:
		_fail(text)

func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func _near_v(a: Vector3, b: Vector3, tol: float) -> bool:
	return a.distance_to(b) <= tol

func _inside(box: Dictionary, p: Vector3) -> bool:
	var size: Vector3 = box["size"]
	var pos: Vector3 = box["position"]
	var yaw: float = box.get("rotation_y", 0.0)
	var d := p - pos
	var c := cos(yaw)
	var s := sin(yaw)
	var local := Vector3(d.x * c - d.z * s, d.y, d.x * s + d.z * c)
	return absf(local.x) <= size.x * 0.5 + 0.001 \
		and absf(local.y) <= size.y * 0.5 + 0.001 \
		and absf(local.z) <= size.z * 0.5 + 0.001

func _blocked_by(boxes: Array, p: Vector3) -> bool:
	for box: Dictionary in boxes:
		if _inside(box, p):
			return true
	return false

func _count_tree(node: Node, type_name: String) -> int:
	var count := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_class(type_name):
			count += 1
		for c: Node in n.get_children():
			stack.append(c)
	return count

func _run() -> void:
	print("SHIP61_MODEL_PROBE start")
	var model: Node3D = ShipModel.new()
	model.name = "ShipModel"
	root.add_child(model)
	var t0 := Time.get_ticks_msec()
	var built: Dictionary = model.build()
	var build_ms := Time.get_ticks_msec() - t0
	if built.is_empty() or built.get("ok") != true:
		_fail("build() did not return ok")
		_finish(model)
		return

	var stats: Dictionary = model.stats()
	print("SHIP61_MODEL_STATS meshes=", stats.get("meshes"), " triangles=", stats.get("triangles"),
		" surfaces=", stats.get("surfaces"), " materials=", stats.get("materials"),
		" holes=", stats.get("holes"), " collision=", stats.get("collision"),
		" build_ms=", build_ms)
	_check(int(stats.get("meshes", 0)) <= 150, "mesh instance budget > 150")
	_check(int(stats.get("triangles", 0)) <= 60000, "triangle budget > 60000")
	_check(int(stats.get("materials", 0)) <= 30, "material budget > 30")

	# Idempotency: a second build must not add a single node.
	var meshes_before := _count_tree(model, "MeshInstance3D")
	var children_before := model.get_child_count()
	var second: Dictionary = model.build()
	var meshes_after := _count_tree(model, "MeshInstance3D")
	_check(second == built, "second build() returned a different dictionary")
	_check(meshes_before == meshes_after, "second build() added meshes: %d -> %d" % [meshes_before, meshes_after])
	_check(children_before == model.get_child_count(), "second build() added child nodes")

	# Contract dimensions and anchors.
	_check(_near(float(built.get("length", 0.0)), 26.0, 0.01), "length is not 26")
	_check(_near(float(built.get("beam", 0.0)), 8.8, 0.01), "beam is not 8.8")
	_check(_near(float(built.get("deck_y", 0.0)), 1.75, 0.01), "deck_y is not 1.75")

	var helm: Dictionary = built.get("helm", {})
	_check(helm.has("node") and is_instance_valid(helm.get("node")), "helm node missing")
	_check(_near_v(helm.get("position", Vector3.ZERO), Vector3(0.0, 3.05, 10.4), 0.01), "helm position mismatch")

	var lever: Dictionary = built.get("sail_lever", {})
	_check(lever.has("node") and is_instance_valid(lever.get("node")), "sail_lever node missing")
	_check(_near_v(lever.get("position", Vector3.ZERO), Vector3(1.0, 2.2, 0.2), 0.01), "sail_lever position mismatch")

	var mast: Dictionary = built.get("mast", {})
	_check(_near_v(mast.get("base", Vector3.ZERO), Vector3(0.0, 1.75, -1.0), 0.01), "mast base mismatch")
	_check(_near_v(mast.get("top", Vector3.ZERO), Vector3(0.0, 17.7, -1.0), 0.01), "mast top mismatch")

	var sails: Dictionary = built.get("sails", {})
	_check(sails.has("node") and is_instance_valid(sails.get("node")), "sails node missing")

	var upper: Dictionary = built.get("upper_deck", {})
	_check(upper.has("node") and is_instance_valid(upper.get("node")), "upper_deck node missing")
	_check(_near_v(upper.get("position", Vector3.ZERO), Vector3(0.0, 5.2, -1.2), 0.01), "upper deck position mismatch")
	_check(_near_v(upper.get("ladder_base", Vector3.ZERO), Vector3(0.0, 1.75, 2.3), 0.01), "upper deck ladder_base mismatch")

	var bow: Dictionary = built.get("bow", {})
	_check(_near_v(bow.get("position", Vector3.ZERO), Vector3(0.0, 2.15, -13.0), 0.01), "bow position mismatch")

	var crates: Dictionary = built.get("crates", {})
	var ammo: Dictionary = crates.get("ammo", {})
	var boards: Dictionary = crates.get("boards", {})
	_check(ammo.has("node") and _near_v(ammo.get("position", Vector3.ZERO), Vector3(-2.0, 0.95, 10.2), 0.01), "ammo crate anchor")
	_check(boards.has("node") and _near_v(boards.get("position", Vector3.ZERO), Vector3(2.0, 0.95, 10.2), 0.01), "boards crate anchor")

	# Four cannons with usable pivots, barrels and muzzles.
	var cannons: Array = built.get("cannons", [])
	_check(cannons.size() == 4, "expected 4 cannons, got %d" % cannons.size())
	var barrel_meshes := 0
	for i: int in cannons.size():
		var c: Dictionary = cannons[i]
		_check(int(c.get("index", -1)) == i, "cannon %d index mismatch" % i)
		_check(is_instance_valid(c.get("node")), "cannon %d node invalid" % i)
		_check(is_instance_valid(c.get("pivot")), "cannon %d pivot invalid" % i)
		_check(is_instance_valid(c.get("barrel")), "cannon %d barrel invalid" % i)
		var side_sign := -1.0 if i < 2 else 1.0
		var z := -4.2 if i % 2 == 0 else 3.4
		_check(_near_v(c.get("mount", Vector3.ZERO), Vector3(side_sign * 3.55, 1.75, z), 0.01),
			"cannon %d mount mismatch" % i)
		_check(_near_v(c.get("muzzle", Vector3.ZERO), Vector3(side_sign * 4.9, 2.3, z), 0.01),
			"cannon %d muzzle mismatch" % i)
		var barrel: Node3D = c.get("barrel")
		if is_instance_valid(barrel) and _count_tree(barrel, "MeshInstance3D") > 0:
			barrel_meshes += 1
	_check(barrel_meshes == 4, "cannon barrels have no rotating meshes: %d/4" % barrel_meshes)

	# Parts and hit points.
	var parts: Array = model.parts()
	var part_ids := {}
	for p: Dictionary in parts:
		part_ids[str(p.get("id"))] = true
	var expected := {
		"mast": 220.0, "bowsprit": 70.0, "rails": 80.0, "transom": 120.0, "helm": 60.0,
		"crate_ammo": 25.0, "crate_boards": 25.0, "cannon_0": 60.0, "cannon_1": 60.0,
		"cannon_2": 60.0, "cannon_3": 60.0, "upper_rail": 60.0, "lanterns": 10.0,
	}
	for id: String in expected:
		_check(part_ids.has(id), "missing part %s" % id)
		_check(_near(model.part_health(id), expected[id], 0.01), "part %s hp mismatch (%.1f)" % [id, model.part_health(id)])
	_check(_near(model.part_health("nope"), 0.0, 0.001), "unknown part hp should be 0")

	# Collision: enough boxes, cabin free at (0,1.2,9), doorway open, deck solid.
	var boxes: Array = built.get("collision", [])
	print("SHIP61_MODEL_COLLISION boxes=", boxes.size())
	_check(boxes.size() >= 28, "too few collision boxes (%d)" % boxes.size())
	for box: Dictionary in boxes:
		if not (box.has("position") and box.has("size") and box.has("rotation_y")):
			_fail("collision box missing fields")
			break
	_check(not _blocked_by(boxes, Vector3(0.0, 1.2, 9.0)), "cabin interior is blocked at (0,1.2,9)")
	_check(not _blocked_by(boxes, Vector3(0.0, 1.5, 6.0)), "cabin doorway at z=6 is blocked")
	_check(_blocked_by(boxes, Vector3(2.6, 1.5, 6.0)), "cabin bulkhead beside the door is open")
	_check(_blocked_by(boxes, Vector3(0.0, 2.98, 9.0)), "no quarterdeck slab above the cabin")
	_check(_blocked_by(boxes, Vector3(0.0, 0.45, 9.0)), "cabin floor has no collision")
	_check(_blocked_by(boxes, Vector3(0.0, 1.70, -2.0)), "main deck has no collision")
	_check(_blocked_by(boxes, Vector3(0.0, 5.16, -1.2)), "upper deck has no collision")
	_check(_blocked_by(boxes, Vector3(0.0, 2.12, -12.7)), "bow platform has no collision")
	# Deck is not one solid slab over the cabin: the companionway is open from above.
	_check(not _blocked_by(boxes, Vector3(0.0, 1.60, 5.75)), "companionway is covered by a deck box")
	# Walk points are on their advertised decks.
	var walk: Dictionary = built.get("walk", {})
	for key: String in ["main", "quarter", "upper", "cabin"]:
		var points: Array = walk.get(key, [])
		_check(points.size() > 0, "walk.%s missing" % key)
	if walk.has("main"):
		var main_points: Array = walk["main"]
		if main_points.size() > 0:
			var main_point: Vector3 = main_points[0]
			_check(_near(main_point.y, 1.78, 0.05), "walk.main not on the main deck")
	if walk.has("cabin"):
		var cabin_points: Array = walk["cabin"]
		if cabin_points.size() > 0:
			var cabin_point: Vector3 = cabin_points[0]
			_check(_near(cabin_point.y, 0.52, 0.05), "walk.cabin not on the cabin floor")

	# Wheel, lever and sails move.
	model.set_wheel_angle(0.65)
	var wheel := model.get_node_or_null("Visual/Helm/Wheel")
	_check(wheel != null, "wheel node not found")
	if wheel != null:
		_check(absf((wheel as Node3D).rotation.z + 0.65) < 0.01, "wheel did not rotate")

	model.set_lever(true)
	await create_timer(0.9).timeout
	var lever_pivot := model.get_node_or_null("Visual/SailLever/LeverPivot")
	_check(lever_pivot != null, "lever pivot not found")
	if lever_pivot != null:
		_check((lever_pivot as Node3D).rotation.x > 0.5, "lever did not animate on")

	model.set_sail_amount(1.0)
	await create_timer(1.8).timeout
	var sail_node := _find_named(model, "Sail")
	var unfurled_ok := false
	if sail_node != null:
		unfurled_ok = (sail_node as Node3D).scale.y > 0.9
	_check(unfurled_ok, "set_sail_amount(1.0) did not unfurl the sail")
	model.set_sail_amount(0.0)
	await create_timer(1.8).timeout
	if sail_node != null:
		_check((sail_node as Node3D).scale.y < 0.1, "set_sail_amount(0.0) did not furl the sail")

	# Punch holes: safe, visible and capped at 24.
	model.punch_hole(Vector3(4.2, 1.0, -2.0), 0.55)
	model.punch_hole(Vector3(0.0, 1.9, -2.0), 0.4)
	model.punch_hole(Vector3(0.0, 1.2, 9.0), 0.3)
	for i: int in 30:
		model.punch_hole(Vector3(-4.1, 0.4 + float(i) * 0.05, -6.0 + float(i) * 0.3), 0.35)
	model.punch_hole(Vector3(NAN, 0.0, NAN), 0.5)
	model.punch_hole(Vector3(0.0, 1.0, 0.0), -2.0)
	var visible_holes := 0
	var holes: Array = model.get("_holes")
	for h: MeshInstance3D in holes:
		if h.visible:
			visible_holes += 1
	print("SHIP61_MODEL_HOLES visible=", visible_holes, " pool=", holes.size())
	_check(holes.size() == 24, "hole pool is not 24")
	_check(visible_holes > 0, "punch_hole did not reveal any hole")
	_check(visible_holes <= 24, "more than 24 holes visible")

	# Damage: mast state and part nodes.
	var mast_upper := model.get_node_or_null("Visual/Mast/MastUpper")
	var mast_stump := model.get_node_or_null("Visual/Mast/MastStump")
	_check(mast_upper != null and mast_upper.visible, "mast upper not visible before damage")
	_check(model.break_part("mast"), "break_part(mast) returned false")
	_check(_near(model.part_health("mast"), 0.0, 0.001), "mast hp did not reach 0")
	if mast_upper != null:
		_check(not (mast_upper as Node3D).visible, "mast upper still visible after break")
	if mast_stump != null:
		_check((mast_stump as Node3D).visible, "mast stump not shown after break")
	model.set_mast_broken(false)
	if mast_upper != null:
		_check((mast_upper as Node3D).visible, "mast upper did not restore")
	model.set_mast_broken(true)
	_check(model.break_part("bowsprit"), "break_part(bowsprit) returned false")
	var bowsprit := model.get_node_or_null("Visual/Bowsprit")
	if bowsprit != null:
		_check(not (bowsprit as Node3D).visible, "bowsprit still visible after break")
	for id: String in ["rails", "transom", "helm", "crate_ammo", "crate_boards", "cannon_0",
			"cannon_1", "cannon_2", "cannon_3", "upper_rail", "lanterns"]:
		_check(model.break_part(id), "break_part(%s) returned false" % id)
	_check(not model.break_part("not_a_part"), "break_part(unknown) should return false")
	model.shake(1.0)
	model.shake(NAN)
	# Sails and rigging vanish with the mast.
	var rig_upper := model.get_node_or_null("Visual/RiggingUpper")
	if rig_upper != null:
		_check(not (rig_upper as Node3D).visible, "upper rigging still visible after mast break")

	# Anchors getter must be the same data without rebuilding.
	var anchors: Dictionary = model.anchors()
	_check(anchors == built, "anchors() differs from build()")
	_check(_count_tree(model, "MeshInstance3D") == meshes_after, "anchors() rebuilt the model")

	_finish(model)

func _find_named(node: Node, wanted: String) -> Node:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == wanted:
			return n
		for c: Node in n.get_children():
			stack.append(c)
	return null

func _finish(model: Node) -> void:
	var stats: Dictionary = model.call("stats")
	print("SHIP61_MODEL_SUMMARY checks=", _checks, " fails=", _fails.size(),
		" meshes=", stats.get("meshes"), " tris=", stats.get("triangles"),
		" materials=", stats.get("materials"))
	if _fails.is_empty():
		print("SHIP61_MODEL_OK meshes=", stats.get("meshes"), " triangles=", stats.get("triangles"),
			" materials=", stats.get("materials"), " holepool=24 parts=", stats.get("parts"),
			" collision=", stats.get("collision"))
		quit(0)
	else:
		print("SHIP61_MODEL_FAIL ", "; ".join(_fails))
		quit(1)
