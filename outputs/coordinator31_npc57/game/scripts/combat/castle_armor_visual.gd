extends Node3D
## Presentation-only modular castle armor. The combat owner decides absorption.
## The five slots can be mixed freely. Each piece follows the existing 28-bone rig.

const SLOTS := ["head", "torso", "hands", "legs", "feet"]
const TIERS := ["light", "medium", "heavy"]
const BONES := {
	"head": ["head"], "torso": ["chest"],
	"hands": ["forearm_l", "hand_l", "forearm_r", "hand_r"],
	"legs": ["thigh_l", "shin_l", "thigh_r", "shin_r"],
	"feet": ["foot_l", "foot_r"]
}
const PALETTE := {
	"light": {"main": Color(0.31, 0.26, 0.19), "edge": Color(0.63, 0.48, 0.28), "under": Color(0.18, 0.14, 0.11)},
	"medium": {"main": Color(0.34, 0.38, 0.42), "edge": Color(0.72, 0.65, 0.47), "under": Color(0.17, 0.20, 0.23)},
	"heavy": {"main": Color(0.36, 0.40, 0.45), "edge": Color(0.78, 0.73, 0.56), "under": Color(0.12, 0.14, 0.17)}
}

var _rig: Skeleton3D
var _actor: Node3D
var _unit := 1.0
var _roots: Dictionary = {}
var _equipped: Dictionary = {}
var _lost: Dictionary = {}
var _ready := false

func configure(rig: Skeleton3D, actor: Node3D) -> Dictionary:
	if _ready: return {"ok": false, "reason": "already_configured"}
	if not is_instance_valid(rig) or not is_instance_valid(actor): return {"ok": false, "reason": "binding"}
	if not actor.is_ancestor_of(rig): return {"ok": false, "reason": "rig_outside_actor"}
	for names: Array in BONES.values():
		for bone_name: String in names:
			if rig.find_bone(bone_name) < 0: return {"ok": false, "reason": "missing_bone", "bone": bone_name}
	_rig = rig
	_actor = actor
	var chest: Vector3 = rig.get_bone_global_pose(rig.find_bone("chest")).origin
	var pelvis: Vector3 = rig.get_bone_global_pose(rig.find_bone("pelvis")).origin
	_unit = clampf(chest.distance_to(pelvis), 0.35, 2.0)
	_ready = true
	return {"ok": true, "rig_bones": rig.get_bone_count(), "unit": _unit, "slots": SLOTS.duplicate()}

func set_armor(slot: String, item_id: String) -> Dictionary:
	if not _ready or not SLOTS.has(slot): return {"ok": false, "reason": "slot_or_binding"}
	if item_id.is_empty(): return clear_piece(slot)
	var tier := _tier_of(item_id)
	if tier.is_empty(): return {"ok": false, "reason": "item_id"}
	if _equipped.get(slot, "") == item_id: return {"ok": true, "slot": slot, "item_id": item_id, "unchanged": true}
	clear_piece(slot)
	_roots[slot] = []
	_equipped[slot] = item_id
	_build_slot(slot, tier)
	_apply_lost(slot)
	var meshes := 0
	for anchor: Node in _roots[slot]: meshes += anchor.get_child_count()
	return {"ok": true, "slot": slot, "item_id": item_id, "tier": tier, "meshes": meshes}

func set_piece(slot: String, tier: String) -> Dictionary:
	return set_armor(slot, tier + "_" + slot)

func clear_piece(slot: String) -> Dictionary:
	if not SLOTS.has(slot): return {"ok": false, "reason": "slot"}
	if _roots.has(slot):
		for old: Node in _roots[slot]:
			if is_instance_valid(old):
				_rig.remove_child(old)
				old.queue_free()
		_roots.erase(slot)
	_equipped.erase(slot)
	return {"ok": true, "slot": slot}

func on_severed(full_key: String) -> void:
	_lost[full_key] = true
	for slot: String in _roots.keys(): _apply_lost(slot)

func reset_severed() -> void:
	_lost.clear()
	for slot: String in _roots.keys(): _apply_lost(slot)

func snapshot() -> Dictionary:
	return {"ready": _ready, "equipped": _equipped.duplicate(), "lost": _lost.keys(), "unit": _unit}

## A compact three-dimensional version of each item for a physical floor pickup.
## The pickup owner supplies collision and the E prompt; this is render only.
func make_ground_preview(item_id: String) -> Node3D:
	var tier := _tier_of(item_id)
	if tier.is_empty(): return null
	var slot := ""
	for key: String in SLOTS:
		if item_id.ends_with("_" + key): slot = key
	if slot.is_empty():
		if item_id.ends_with("_helmet"): slot = "head"
		elif item_id.ends_with("_chest") or item_id.ends_with("_chestplate"): slot = "torso"
		elif item_id.ends_with("_gloves") or item_id.ends_with("_gauntlets"): slot = "hands"
		elif item_id.ends_with("_pants") or item_id.ends_with("_greaves"): slot = "legs"
		elif item_id.ends_with("_boots"): slot = "feet"
	if slot.is_empty(): return null
	var root_node := Node3D.new()
	root_node.name = "ArmorPickupPreview_" + item_id
	var p: Dictionary = PALETTE[tier]
	match slot:
		"head":
			_preview(root_node, SphereMesh.new(), Vector3(0, .16, 0), Vector3(.25, .20, .22), p.main, tier)
			_preview_box(root_node, Vector3(0, .12, .21), Vector3(.48, .04, .07), p.edge, tier)
		"torso":
			_preview(root_node, SphereMesh.new(), Vector3(0, .10, 0), Vector3(.34, .13, .27), p.main, tier)
			for x: float in [-.30, .30]: _preview_box(root_node, Vector3(x, .15, 0), Vector3(.09, .10, .43), p.edge, tier)
		"hands":
			for x: float in [-.16, .16]:
				_preview_box(root_node, Vector3(x, .075, 0), Vector3(.24, .13, .34), p.main, tier)
				_preview_box(root_node, Vector3(x, .15, -.09), Vector3(.21, .025, .08), p.edge, tier)
		"legs":
			for x: float in [-.15, .15]: _preview_box(root_node, Vector3(x, .08, 0), Vector3(.23, .13, .48), p.main, tier)
		"feet":
			for x: float in [-.15, .15]:
				_preview_box(root_node, Vector3(x, .07, .02), Vector3(.25, .13, .38), p.main, tier)
				_preview_box(root_node, Vector3(x, .14, -.08), Vector3(.24, .025, .12), p.edge, tier)
	return root_node

func _preview_box(parent: Node3D, center: Vector3, size: Vector3, color: Color, tier: String) -> void:
	var box := BoxMesh.new()
	box.size = size
	_preview(parent, box, center, Vector3.ONE, color, tier)

func _preview(parent: Node3D, shape: Mesh, center: Vector3, scale3: Vector3, color: Color, tier: String) -> void:
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.position = center
	part.scale = scale3
	part.material_override = _material(color, tier)
	parent.add_child(part)

func _tier_of(item_id: String) -> String:
	for tier: String in TIERS:
		if item_id == tier or item_id.begins_with(tier + "_"): return tier
	return ""

func _apply_lost(slot: String) -> void:
	if not _roots.has(slot): return
	for anchor: Node in _roots[slot]:
		var bone_name := String(anchor.get_meta("armor_bone", ""))
		var side := "_l" if bone_name.ends_with("_l") else ("_r" if bone_name.ends_with("_r") else "")
		var hidden := _lost.has("head") and slot == "head"
		if not side.is_empty():
			for part: String in ["upperarm", "forearm", "hand", "thigh", "shin", "foot"]:
				if _lost.has(part + side) and (bone_name == part + side or _is_descendant(bone_name, part + side)):
					hidden = true
		anchor.visible = not hidden

func _is_descendant(bone_name: String, ancestor_name: String) -> bool:
	var index := _rig.find_bone(bone_name)
	var ancestor := _rig.find_bone(ancestor_name)
	while index >= 0:
		if index == ancestor: return true
		index = _rig.get_bone_parent(index)
	return false

func _build_slot(slot: String, tier: String) -> void:
	var p: Dictionary = PALETTE[tier]
	match slot:
		"head":
			var head := _anchor(slot, "head")
			# Open lower face and neck. Heavy gets a segmented brow and cheek guards.
			_ellipsoid(head, Vector3(0, .30, -.04), Vector3(.47, .27, .42), p.main, tier)
			_box(head, Vector3(0, .20, .39), Vector3(.90, .065, .06), p.edge, tier)
			for side: float in [-1.0, 1.0]:
				_box(head, Vector3(side * .41, .02, .03), Vector3(.08, .32, .59), p.main, tier)
				if tier == "heavy": _box(head, Vector3(side * .39, -.19, .22), Vector3(.11, .30, .34), p.main, tier)
			if tier == "heavy": _box(head, Vector3(0, -.31, .37), Vector3(.53, .07, .08), p.edge, tier)
			if tier == "medium": _ellipsoid(head, Vector3(0, .56, -.02), Vector3(.13, .12, .37), p.edge, tier)
			if tier == "light": _box(head, Vector3(0, .02, -.35), Vector3(.64, .18, .08), p.under, tier)
		"torso":
			var chest := _anchor(slot, "chest")
			var w := 1.75 if tier == "heavy" else (1.63 if tier == "medium" else 1.48)
			if tier == "light":
				_ellipsoid(chest, Vector3(0, -.08, .34), Vector3(.77, .54, .22), p.main, tier)
				_ellipsoid(chest, Vector3(0, -.08, -.34), Vector3(.77, .54, .20), p.main, tier)
				for x: float in [-.47, .47]: _box(chest, Vector3(x, -.08, .55), Vector3(.065, .88, .045), p.edge, tier)
			elif tier == "medium":
				_ellipsoid(chest, Vector3(0, -.08, 0), Vector3(.85, .55, .55), p.under, tier)
				for y: float in [-.38, -.23, -.08, .07, .22]:
					_box(chest, Vector3(0, y, .51), Vector3(1.39, .055, .055), p.edge, tier)
					_box(chest, Vector3(0, y, -.50), Vector3(1.39, .055, .055), p.edge, tier)
			else:
				_ellipsoid(chest, Vector3(0, -.02, .29), Vector3(.89, .52, .31), p.main, tier)
				_ellipsoid(chest, Vector3(0, -.02, -.29), Vector3(.89, .52, .29), p.main, tier)
			for side: float in [-1.0, 1.0]:
				_box(chest, Vector3(side * (w * .48), -.08, 0), Vector3(.10, .72, .70), p.under, tier)
				if tier == "heavy":
					_ellipsoid(chest, Vector3(side * .77, .42, 0), Vector3(.39, .20, .51), p.main, tier)
					_box(chest, Vector3(side * .78, .54, 0), Vector3(.43, .035, .70), p.edge, tier)
				else: _box(chest, Vector3(side * .68, .31, 0), Vector3(.27, .09, .80), p.edge, tier)
			if tier != "light":
				for y: float in [-.34, -.19, -.04]: _box(chest, Vector3(0, y, .56), Vector3(w * .86, .025, .035), p.edge, tier)
			if tier == "heavy":
				_box(chest, Vector3(0, -.57, .40), Vector3(1.48, .18, .16), p.main, tier)
				_box(chest, Vector3(0, -.57, -.39), Vector3(1.48, .18, .15), p.main, tier)
				for x: float in [-.46, 0.0, .46]: _ellipsoid(chest, Vector3(x, -.77, .34), Vector3(.28, .26, .11), p.main, tier)
		"hands":
			for side: String in ["_l", "_r"]:
				var fore := _anchor(slot, "forearm" + side)
				_box(fore, Vector3(0, -.18, .06), Vector3(.36, .48, .33), p.main, tier)
				_box(fore, Vector3(0, -.13, .25), Vector3(.31, .035, .05), p.edge, tier)
				var hand := _anchor(slot, "hand" + side)
				_box(hand, Vector3(0, -.08, .09), Vector3(.34, .27, .32), p.main, tier)
				for x: float in [-.12, -.04, .04, .12]: _box(hand, Vector3(x, -.25, .17), Vector3(.055, .17, .08), p.edge, tier)
		"legs":
			for side: String in ["_l", "_r"]:
				var thigh := _anchor(slot, "thigh" + side)
				_box(thigh, Vector3(0, -.21, .12), Vector3(.53, .56, .43), p.main, tier)
				_box(thigh, Vector3(0, -.19, .35), Vector3(.39, .035, .04), p.edge, tier)
				var shin := _anchor(slot, "shin" + side)
				_box(shin, Vector3(0, -.17, .14), Vector3(.42, .48, .32), p.main, tier)
				if tier == "heavy": _ellipsoid(shin, Vector3(0, .14, .19), Vector3(.27, .13, .25), p.edge, tier)
		"feet":
			for side: String in ["_l", "_r"]:
				var foot := _anchor(slot, "foot" + side)
				_box(foot, Vector3(0, -.10, .19), Vector3(.46, .25, .78), p.main, tier)
				_box(foot, Vector3(0, -.18, .23), Vector3(.48, .06, .81), p.under, tier)
				if tier != "light": _box(foot, Vector3(0, -.01, .44), Vector3(.45, .04, .30), p.edge, tier)

func _anchor(slot: String, bone_name: String) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = "ArmorBone_" + bone_name
	attachment.bone_name = bone_name
	attachment.set_meta("armor_bone", bone_name)
	_rig.add_child(attachment)
	_roots[slot].append(attachment)
	return attachment

func _box(anchor: Node3D, local_center: Vector3, local_size: Vector3, color: Color, tier: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "ArmorPlate"
	var box := BoxMesh.new()
	box.size = local_size * _unit
	mesh.mesh = box
	mesh.material_override = _material(color, tier)
	mesh.position = local_center * _unit
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anchor.add_child(mesh)

func _ellipsoid(anchor: Node3D, local_center: Vector3, radii: Vector3, color: Color, tier: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "ArmorCurvedPlate"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = _material(color, tier)
	mesh.position = local_center * _unit
	mesh.scale = radii * _unit
	anchor.add_child(mesh)

func _material(color: Color, tier: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = .08 if tier == "light" else (.52 if tier == "medium" else .76)
	material.roughness = .76 if tier == "light" else (.45 if tier == "medium" else .35)
	return material
