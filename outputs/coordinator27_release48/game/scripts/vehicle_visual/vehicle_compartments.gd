extends RefCounted
## Presentation only; interaction and inventory authority remain with the host.
const DATA_PATH := "res://assets/vehicle_visual/compartments.json"
var _panels: Dictionary = {}
var _cargo: Dictionary = {}
var _visual = null
var _active := false

func configure(visual) -> Dictionary:
	if _visual != null:
		return {"ok": false, "error": "already_configured"}
	if visual == null or not is_instance_valid(visual.root):
		return {"ok": false, "error": "missing_visual"}
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null or file.get_length() > 524288:
		return {"ok": false, "error": "compartment_data"}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("schema") != "mafiozi.vehicle-compartments.v1":
		return {"ok": false, "error": "compartment_schema"}
	var record: Dictionary = data.get("profiles", {}).get(visual.profile_id, {})
	if record.is_empty() or record.get("visual_sha256") != visual.entry.get("sha256"):
		return {"ok": false, "error": "visual_source_mismatch"}
	var ready: Dictionary = {}
	for kind: String in ["hood", "trunk"]:
		var spec: Dictionary = record.get("panels", {}).get(kind, {})
		var hinge: Node3D = visual.nodes.get(spec.get("hinge"))
		var lid: Node3D = visual.nodes.get(spec.get("lid"))
		if hinge == null or lid == null or visual.entry.controls.get(kind) != spec.get("hinge"):
			return {"ok": false, "error": "panel_binding"}
		var supports: Array = []
		for s: Dictionary in spec.get("supports", []):
			var mesh: Node3D = visual.nodes.get(s.key)
			var parent: Node3D = visual.nodes.get(s.parent_key)
			if mesh == null or parent == null or mesh.get_parent() != parent:
				return {"ok": false, "error": "support_binding"}
			supports.append({"mesh": mesh, "parent": parent, "base": _point(s.base_parent), "tip": _point(s.tip_lid)})
		var engine: Array[Node3D] = []
		for key: String in spec.get("engine_nodes", []):
			var node: Node3D = visual.nodes.get(key)
			if node == null:
				return {"ok": false, "error": "engine_binding"}
			engine.append(node)
		ready[kind] = {"hinge": hinge, "lid": lid, "angle": float(spec.open_angle), "profile": spec.access_profile.duplicate(true), "supports": supports, "engine": engine, "amount": 0.0, "velocity": 0.0, "target": 0.0, "exposed": false}
	_visual = visual
	_panels = ready
	_cargo = record.get("cargo_bounds", {}).duplicate(true)
	return {"ok": true}

static func _point(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func set_open(kind: String, open: bool) -> bool:
	if _visual == null or not is_instance_valid(_visual.root) or not _panels.has(kind):
		return false
	_panels[kind].target = 1.0 if open else 0.0
	_active = _active or _panels[kind].amount != _panels[kind].target or _panels[kind].velocity != 0.0
	return true

func is_open(kind: String) -> bool:
	return _panels.has(kind) and _panels[kind].target == 1.0

func amount(kind: String) -> float:
	return float(_panels.get(kind, {}).get("amount", 0.0))

func is_animating() -> bool:
	return _active

func step(delta: float) -> void:
	if not _active or not is_finite(delta) or delta < 0.0:
		return
	if _visual == null or not is_instance_valid(_visual.root):
		dispose()
		return
	var h := minf(delta, 0.2)
	_active = false
	for kind: String in _panels:
		var p: Dictionary = _panels[kind]
		if p.amount == p.target and p.velocity == 0.0:
			continue
		var previous := float(p.amount)
		var offset := previous - float(p.target)
		var blend := (float(p.velocity) + 18.0 * offset) * h
		var decay := exp(-18.0 * h)
		p.amount = clampf(float(p.target) + (offset + blend) * decay, 0.0, 1.0)
		p.velocity = (float(p.velocity) - 18.0 * blend) * decay
		if absf(float(p.amount) - float(p.target)) < 0.0002 and absf(float(p.velocity)) < 0.004:
			p.amount = p.target
			p.velocity = 0.0
		_active = _active or p.amount != p.target or p.velocity != 0.0
		if previous == p.amount:
			continue
		var a := float(p.amount)
		p.hinge.rotation.x = a * a * (3.0 - 2.0 * a) * float(p.angle)
		if kind == "hood":
			var exposed := a > 0.01
			if exposed != p.exposed:
				for node: Node3D in p.engine:
					node.visible = exposed
				p.exposed = exposed
			if not exposed:
				continue
		for s: Dictionary in p.supports:
			var end: Vector3 = s.parent.global_transform.affine_inverse() * (p.lid.global_transform * s.tip)
			var direction: Vector3 = end - s.base
			var mesh: Node3D = s.mesh
			mesh.position = s.base + direction * 0.5
			mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
			mesh.scale = Vector3(1.0, direction.length(), 1.0)

func access_profile(kind: String) -> Dictionary:
	if not _panels.has(kind):
		return {}
	var p: Dictionary = _panels[kind].profile.duplicate(true)
	# Return native vehicle-local coordinates, outside the source-basis wrapper.
	p["position_local_m"] = Vector3(-float(p.get("accessSide", 0.0)), float(p.handleY), -float(p.get("accessZ", p.get("rearZ", 0.0))))
	p["range_m"] = 1.5 if kind == "hood" else 1.45
	p["outward_local"] = Vector3(0, 0, -1 if kind == "hood" and p.get("front", true) else 1)
	return p

func cargo_bounds() -> Dictionary:
	if _cargo.is_empty():
		return {}
	var lo := _point(_cargo.min)
	var hi := _point(_cargo.max)
	return {"min": Vector3(-hi.x, lo.y, -hi.z), "max": Vector3(-lo.x, hi.y, -lo.z)}

func contains_item(center: Vector3, half: Vector3) -> bool:
	if not center.is_finite() or not half.is_finite() or half.x < 0 or half.y < 0 or half.z < 0:
		return false
	var bounds := cargo_bounds()
	if bounds.is_empty():
		return false
	var lo: Vector3 = center - half
	var hi: Vector3 = center + half
	for axis in 3:
		if lo[axis] < bounds.min[axis] - 0.0000001 or hi[axis] > bounds.max[axis] + 0.0000001:
			return false
	return true

func dispose() -> void:
	_active = false
	_panels.clear()
	_cargo.clear()
	_visual = null
