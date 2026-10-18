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
	"light": {"main": Color(0.31, 0.19, 0.105), "edge": Color(0.59, 0.38, 0.19), "under": Color(0.13, 0.09, 0.065)},
	"medium": {"main": Color(0.39, 0.42, 0.45), "edge": Color(0.63, 0.60, 0.48), "under": Color(0.25, 0.28, 0.31)},
	"heavy": {"main": Color(0.055, 0.073, 0.085), "edge": Color(0.38, 0.34, 0.25), "under": Color(0.025, 0.028, 0.033)}
}
static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

var _rig: Skeleton3D
var _actor: Node3D
var _unit := 1.0
var _roots: Dictionary = {}
var _skinned: Dictionary = {}
var _equipped: Dictionary = {}
var _lost: Dictionary = {}
var _ready := false
var _hidden_headwear: Dictionary = {}
var _hidden_torso_trim: Dictionary = {}
var _hidden_fabric: Dictionary = {}

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
	# The canonical resident chest-to-pelvis span is about two bone units while
	# the visible torso radius is about one. Using the full span doubled every
	# plate in the scaled player rig and made the helmet wider than the head.
	_unit = clampf(chest.distance_to(pelvis) * .5, .5, 1.3)
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
	if slot == "head": _hide_headwear()
	if slot == "torso":
		_hide_torso_trim()
		_hide_torso_fabric()
	_apply_lost(slot)
	var meshes := 0
	for anchor: Node in _roots[slot]: meshes += anchor.get_child_count()
	if _skinned.has(slot): meshes += _skinned[slot].size()
	return {"ok": true, "slot": slot, "item_id": item_id, "tier": tier, "meshes": meshes}

func set_piece(slot: String, tier: String) -> Dictionary:
	return set_armor(slot, tier + "_" + slot)

func clear_piece(slot: String) -> Dictionary:
	if not SLOTS.has(slot): return {"ok": false, "reason": "slot"}
	if slot == "head": _restore_headwear()
	if slot == "torso":
		_restore_torso_trim()
		_restore_torso_fabric()
	if _roots.has(slot):
		for old: Node in _roots[slot]:
			if is_instance_valid(old):
				_rig.remove_child(old)
				old.queue_free()
		_roots.erase(slot)
	if _skinned.has(slot):
		for old: Node in _skinned[slot]:
			if is_instance_valid(old):
				old.get_parent().remove_child(old)
				old.queue_free()
		_skinned.erase(slot)
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

func _exit_tree() -> void:
	# Armor nodes live under the actor's rig, not under this controller. Release
	# them without changing a busy parent's child list during tree exit.
	_restore_headwear()
	_restore_torso_trim()
	_restore_torso_fabric()
	for anchors: Array in _roots.values():
		for old: Node in anchors:
			if is_instance_valid(old): old.queue_free()
	for overlays: Array in _skinned.values():
		for old: Node in overlays:
			if is_instance_valid(old): old.queue_free()
	_roots.clear()
	_skinned.clear()
	_equipped.clear()

func _hide_headwear() -> void:
	if not is_instance_valid(_actor): return
	for node: Node in _actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var name := String(mesh.name)
		if name in ["player_male_DEMO_hair_HAIR", "player_male_DEMO_headwear_HAIR", "player_male_DEMO_headwear_FABRIC", "player_female_DEMO_core_HAIR", "npc_hair_cap"] or name.begins_with("npc_wave"):
			if not _hidden_headwear.has(mesh): _hidden_headwear[mesh] = mesh.visible
			mesh.visible = false

func _restore_headwear() -> void:
	for mesh: MeshInstance3D in _hidden_headwear.keys():
		if is_instance_valid(mesh): mesh.visible = bool(_hidden_headwear[mesh])
	_hidden_headwear.clear()

func _hide_torso_trim() -> void:
	if not is_instance_valid(_actor): return
	for node: Node in _actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if String(mesh.name).ends_with("_core_TRIM") or (String(mesh.name) == "PeasantTornOvershirt" and mesh.get_meta("sword_peasant_cloth", false)):
			if not _hidden_torso_trim.has(mesh): _hidden_torso_trim[mesh] = mesh.visible
			mesh.visible = false

func _restore_torso_trim() -> void:
	for mesh: MeshInstance3D in _hidden_torso_trim.keys():
		if is_instance_valid(mesh): mesh.visible = bool(_hidden_torso_trim[mesh])
	_hidden_torso_trim.clear()

func _hide_torso_fabric() -> void:
	if not is_instance_valid(_actor): return
	for node: Node in _actor.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if not String(source.name).ends_with("_core_FABRIC") or source.mesh == null or source.skin == null or not source.mesh is ArrayMesh: continue
		if not _hidden_fabric.has(source):
			_hidden_fabric[source] = source.visible
			_fabric_lower_proxy(source)
		source.visible = false

func _restore_torso_fabric() -> void:
	for source: MeshInstance3D in _hidden_fabric.keys():
		if is_instance_valid(source): source.visible = bool(_hidden_fabric[source])
	_hidden_fabric.clear()

func _fabric_lower_proxy(source: MeshInstance3D) -> void:
	var key := "fabric_lower:" + str(source.mesh.get_instance_id())
	var lower: ArrayMesh = _mesh_cache.get(key) as ArrayMesh
	if lower == null:
		lower = ArrayMesh.new()
		for surface_index: int in source.mesh.get_surface_count():
			var arrays: Array = source.mesh.surface_get_arrays(surface_index)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var original_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var selected := PackedInt32Array()
			for triangle: int in int(original_indices.size() / 3):
				var start := triangle * 3
				var y := (positions[original_indices[start]].y + positions[original_indices[start + 1]].y + positions[original_indices[start + 2]].y) / 3.0
				if y >= 1.64: continue
				for corner: int in 3: selected.append(original_indices[start + corner])
			if selected.is_empty(): continue
			lower.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact_surface(arrays, selected, positions.size()))
			lower.surface_set_material(lower.get_surface_count() - 1, source.mesh.surface_get_material(surface_index))
		_mesh_cache[key] = lower
	if lower.get_surface_count() == 0: return
	var proxy := MeshInstance3D.new()
	proxy.name = "ArmorOriginalLowerGarment"
	proxy.mesh = lower
	proxy.skin = source.skin
	proxy.skeleton = source.skeleton
	proxy.transform = source.transform
	proxy.material_override = source.material_override
	source.get_parent().add_child(proxy)
	if not _skinned.has("torso"): _skinned["torso"] = []
	_skinned["torso"].append(proxy)

## A readable three-dimensional version of each item for a physical floor pickup.
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
			_preview(root_node, _hemisphere_mesh(), Vector3(0, .20, 0), Vector3(.38, .34, .36), p.main, tier)
			_preview_box(root_node, Vector3(0, .24, .35), Vector3(.73, .035, .05), p.edge, tier)
			for x: float in [-.34, .34]: _preview_box(root_node, Vector3(x, .12, .02), Vector3(.045, .25, .40), p.main, tier)
			if tier == "heavy": _preview_box(root_node, Vector3(0, .09, .36), Vector3(.43, .07, .07), p.edge, tier)
		"torso":
			_preview_ellipsoid(root_node, Vector3(0, .28, 0), Vector3(.40, .29, .24), p.main, tier)
			for x: float in [-.38, .38]:
				_preview_box(root_node, Vector3(x, .34, 0), Vector3(.09, .24, .39), p.edge, tier)
				if tier == "heavy": _preview_ellipsoid(root_node, Vector3(x, .47, 0), Vector3(.17, .09, .21), p.main, tier)
			if tier == "medium":
				for z: float in [-.23, .23]:
					for y: float in [.16, .25, .34, .43]: _preview_box(root_node, Vector3(0, y, z), Vector3(.62, .016, .018), p.edge, tier)
			if tier == "light":
				for x: float in [-.22, .22]: _preview_box(root_node, Vector3(x, .28, .25), Vector3(.035, .41, .03), p.edge, tier)
		"hands":
			for x: float in [-.22, .22]:
				_preview_ellipsoid(root_node, Vector3(x, .18, .04), Vector3(.18, .11, .24), p.main, tier)
				for finger: float in [-.10, -.03, .04, .11]: _preview_ellipsoid(root_node, Vector3(x + finger, .14, .28), Vector3(.025, .055, .12), p.edge, tier)
				_preview_box(root_node, Vector3(x, .24, -.13), Vector3(.29, .025, .08), p.edge, tier)
		"legs":
			for x: float in [-.21, .21]:
				_preview_ellipsoid(root_node, Vector3(x, .26, 0), Vector3(.19, .30, .18), p.main, tier)
				_preview_box(root_node, Vector3(x, .52, .08), Vector3(.32, .035, .14), p.edge, tier)
				if tier == "heavy": _preview_ellipsoid(root_node, Vector3(x, .09, .13), Vector3(.19, .10, .20), p.edge, tier)
		"feet":
			for x: float in [-.22, .22]:
				_preview_ellipsoid(root_node, Vector3(x, .14, .13), Vector3(.20, .13, .32), p.main, tier)
				_preview_box(root_node, Vector3(x, .09, .13), Vector3(.39, .045, .58), p.under, tier)
				_preview_box(root_node, Vector3(x, .26, -.07), Vector3(.34, .23, .18), p.main, tier)
				if tier != "light":
					for z: float in [.08, .22, .35]: _preview_box(root_node, Vector3(x, .27, z), Vector3(.33, .02, .03), p.edge, tier)
	return root_node

func _preview_ellipsoid(parent: Node3D, center: Vector3, radii: Vector3, color: Color, tier: String) -> void:
	_preview(parent, _sphere_mesh(), center, radii, color, tier)

func _hemisphere_mesh() -> SphereMesh:
	if _mesh_cache.has("hemisphere16x8"): return _mesh_cache["hemisphere16x8"]
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 8
	_mesh_cache["hemisphere16x8"] = dome
	return dome

func _preview_box(parent: Node3D, center: Vector3, size: Vector3, color: Color, tier: String) -> void:
	_preview(parent, _box_mesh(size), center, Vector3.ONE, color, tier)

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
	if _roots.has(slot):
		for anchor: Node in _roots[slot]:
			var bone_name := String(anchor.get_meta("armor_bone", ""))
			var side := "_l" if bone_name.ends_with("_l") else ("_r" if bone_name.ends_with("_r") else "")
			var hidden := _lost.has("head") and slot == "head"
			if not side.is_empty():
				for part: String in ["upperarm", "forearm", "hand", "thigh", "shin", "foot"]:
					if _lost.has(part + side) and (bone_name == part + side or _is_descendant(bone_name, part + side)):
						hidden = true
			anchor.visible = not hidden
	if _skinned.has(slot):
		for overlay: Node in _skinned[slot]:
			var side := int(overlay.get_meta("armor_side", 0))
			var suffix := "_l" if side < 0 else ("_r" if side > 0 else "")
			var hidden := false
			if not suffix.is_empty():
				for part: String in ["upperarm", "forearm", "hand", "thigh", "shin", "foot"]:
					if _lost.has(part + suffix): hidden = true
			overlay.visible = not hidden

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
			_dome(head, Vector3(0, .54, -.04), Vector3(.56 if tier == "heavy" else .62, .68, .63 if tier == "heavy" else .66), p.main, tier, 4 if tier == "light" else 3)
			_shell(head, Vector3(0, .54, -.04), Vector3(.57 if tier == "heavy" else .63, .035, .64 if tier == "heavy" else .67), 65 if tier == "light" else -175, 295 if tier == "light" else 175, 0, p.edge, tier)
			if tier != "heavy":
				for side: float in [-1.0, 1.0]:
					var a := 57.0 if side > 0 else -123.0
					_shell(head, Vector3(0, .20, -.04), Vector3(.63, .34, .67), a, a + 65.0, -.16, p.main, tier)
					_rivet(head, Vector3(side * .58, .40, .12), p.edge, tier)
			if tier == "heavy":
				_face_helmet(head)
				_helmet_side_plates(head)
				for side: float in [-1.0, 1.0]:
					_ellipsoid(head, Vector3(side * .66, .40, .25), Vector3(.12, .22, .20), p.main, tier)
				_shell(head, Vector3(0, .38, -.04), Vector3(.55, .34, .60), 125, 235, -.26, p.main, tier)
				_crest(head, p.under, tier)
				_crest_ribs(head)
			if tier == "medium": _ellipsoid(head, Vector3(0, 1.17, -.02), Vector3(.09, .12, .43), p.edge, tier)
			if tier == "light": _shell(head, Vector3(0, -.04, -.04), Vector3(.48, .10, .43), 120, 240, 0, p.under, tier)
		"torso":
			var torso_color: Color = Color(.085, .105, .12) if tier == "heavy" else (p.under if tier == "medium" else p.main)
			var center_layer := _skinned_layer(slot, tier, 1.62, 3.45, .075, torso_color, "ArmorTailoredTorso", -.56, .56, "player_male_DEMO_core_FABRIC", false, "", "cuirass" if tier == "heavy" else "")
			var left_sleeve := _skinned_layer(slot, tier, 1.62, 3.45, .075, torso_color, "ArmorTailoredSleeveL", -1.48, -.56)
			var right_sleeve := _skinned_layer(slot, tier, 1.62, 3.45, .075, torso_color, "ArmorTailoredSleeveR", .56, 1.48)
			if center_layer and left_sleeve and right_sleeve:
				if tier == "heavy":
					for shoulder: String in ["upperarm_l", "upperarm_r"]:
						var pauldron := _anchor(slot, shoulder)
						_pauldron_lames(pauldron)
				else:
					var front := _anchor(slot, "chest")
					_shell(front, Vector3(0, -.55, 0), Vector3(.84, .07, .56), -178, 178, 0, p.edge if tier == "light" else p.main, tier)
					if tier == "medium":
						for y: float in [.33, .53, .73]: _shell(front, Vector3(0, y, 0), Vector3(.67, .018, .57), -70, 70, 0, p.main, tier)
					else:
						for y: float in [.29, .76]: _shell(front, Vector3(0, y, 0), Vector3(.61, .018, .54), -65, 65, 0, p.edge, tier)
				return
			var chest := _anchor(slot, "chest")
			var w := 1.75 if tier == "heavy" else (1.63 if tier == "medium" else 1.48)
			if tier == "light":
				_shell(chest, Vector3(0, .48, 0), Vector3(.77, .64, .53), -82, 82, -.16, p.main, tier)
				_shell(chest, Vector3(0, .48, 0), Vector3(.77, .64, .53), 100, 260, -.16, p.main, tier)
				for x: float in [-.54, .54]: _box(chest, Vector3(x, .48, .42), Vector3(.065, 1.05, .06), p.edge, tier)
			elif tier == "medium":
				_shell(chest, Vector3(0, .48, 0), Vector3(.84, .64, .56), -105, 105, -.10, p.under, tier)
				_shell(chest, Vector3(0, .48, 0), Vector3(.84, .64, .56), 105, 255, -.10, p.under, tier)
				for y: float in [.10, .27, .44, .61, .78]: _shell(chest, Vector3(0, y, 0), Vector3(.85, .022, .58), -72, 72, 0, p.edge, tier)
			else:
				_shell(chest, Vector3(0, .48, 0), Vector3(.89, .65, .61), -93, 93, -.23, p.main, tier)
				_shell(chest, Vector3(0, .48, 0), Vector3(.89, .65, .61), 100, 260, -.23, p.main, tier)
			for side: float in [-1.0, 1.0]:
				_shell(chest, Vector3(0, .48, 0), Vector3(w * .48, .48, .54), (76 if side > 0 else -104), (104 if side > 0 else -76), 0, p.under, tier)
				if tier == "heavy":
					_dome(chest, Vector3(side * .78, .86, 0), Vector3(.30, .17, .38), p.main, tier)
					for z: float in [-.26, .26]: _rivet(chest, Vector3(side * .85, .92, z), p.edge, tier)
				else: _box(chest, Vector3(side * .68, .90, 0), Vector3(.27, .07, .72), p.edge, tier)
			if tier != "light":
				for y: float in [.06, .24, .42]: _shell(chest, Vector3(0, y, 0), Vector3(w * .48, .015, .63), -80, 80, 0, p.edge, tier)
			if tier == "heavy":
				_shell(chest, Vector3(0, -.59, 0), Vector3(.78, .12, .52), -78, 78, .18, p.main, tier)
				_shell(chest, Vector3(0, -.59, 0), Vector3(.78, .12, .52), 102, 258, .18, p.main, tier)
				for x: float in [-.46, 0.0, .46]: _ellipsoid(chest, Vector3(x, -.77, .34), Vector3(.28, .26, .11), p.main, tier)
		"hands":
			if tier == "heavy":
				for side: float in [-1.0, 1.0]:
					var x_min := -1.70 if side < 0 else .63
					var x_max := -.63 if side < 0 else 1.70
					_skinned_layer(slot, tier, 1.45, 2.85, .095, p.under, "ArmorFittedGlove", x_min, x_max, "player_male_DEMO_core_SKIN", false, "hand_l" if side < 0 else "hand_r")
				for side: String in ["_l", "_r"]:
					var glove := _anchor(slot, "hand" + side)
					_gauntlet(glove)
				return
			var hand_layers := 0
			for side: float in [-1.0, 1.0]:
				var x_min := -1.6 if side < 0 else .72
				var x_max := -.72 if side < 0 else 1.6
				if _skinned_layer(slot, tier, 1.53, 2.72, .075, p.main, "ArmorTailoredGlove", x_min, x_max, "player_male_DEMO_core_SKIN"): hand_layers += 1
			if hand_layers == 2: return
			for side: String in ["_l", "_r"]:
				var fore := _anchor(slot, "forearm" + side)
				_shell(fore, Vector3(0, -.17, .04), Vector3(.21, .28, .19), -145, 145, .22, p.main, tier)
				_shell(fore, Vector3(0, -.18, .04), Vector3(.22, .025, .20), -145, 145, 0, p.edge, tier)
				for y: float in [-.34, -.13, .08]: _rivet(fore, Vector3(0, y, .24), p.edge, tier)
				var hand := _anchor(slot, "hand" + side)
				_shell(hand, Vector3(0, -.07, .04), Vector3(.20, .17, .19), -130, 130, .20, p.main, tier)
				for x: float in [-.13, -.045, .045, .13]:
					_ellipsoid(hand, Vector3(x, -.25, .15), Vector3(.037, .11, .06), p.main, tier)
					_rivet(hand, Vector3(x, -.15, .21), p.edge, tier)
				if tier == "heavy": _shell(hand, Vector3(0, -.10, .04), Vector3(.21, .04, .20), -130, 130, 0, p.edge, tier)
		"legs":
			var leg_layers := 0
			for side: float in [-1.0, 1.0]:
				var x_min := -.85 if side < 0 else .02
				var x_max := -.02 if side < 0 else .85
				if _skinned_layer(slot, tier, .48, 1.79, .075 if tier == "heavy" else .09, p.under if tier == "heavy" else p.main, "ArmorTailoredLeg", x_min, x_max): leg_layers += 1
			if leg_layers == 2:
				if tier == "heavy":
					for side: String in ["_l", "_r"]:
						var greave := _anchor(slot, "shin" + side)
						_jointed_greave(greave)
				return
			for side: String in ["_l", "_r"]:
				var thigh := _anchor(slot, "thigh" + side)
				_shell(thigh, Vector3(0, -.20, .07), Vector3(.29, .34, .26), -155, 155, .25, p.main, tier)
				_shell(thigh, Vector3(0, -.18, .07), Vector3(.30, .024, .27), -155, 155, 0, p.edge, tier)
				for y: float in [-.43, .02]: _rivet(thigh, Vector3(0, y, .34), p.edge, tier)
				var shin := _anchor(slot, "shin" + side)
				_shell(shin, Vector3(0, -.17, .08), Vector3(.23, .31, .21), -150, 150, -.13, p.main, tier)
				if tier == "heavy": _dome(shin, Vector3(0, .13, .08), Vector3(.26, .16, .26), p.edge, tier)
				elif tier == "medium": _shell(shin, Vector3(0, .11, .08), Vector3(.24, .05, .22), -130, 130, 0, p.edge, tier)
		"feet":
			var foot_layers := 0
			for side: float in [-1.0, 1.0]:
				var x_min := -.8 if side < 0 else .02
				var x_max := -.02 if side < 0 else .8
				if _skinned_layer(slot, tier, .12, .59, .075 if tier == "heavy" else .11, p.under if tier == "heavy" else p.main, "ArmorTailoredBoot", x_min, x_max): foot_layers += 1
			if foot_layers == 2:
				if tier == "heavy":
					for side: String in ["_l", "_r"]:
						var boot := _anchor(slot, "foot" + side)
						_boot_cap(boot)
				return
			for side: String in ["_l", "_r"]:
				var foot := _anchor(slot, "foot" + side)
				_ellipsoid(foot, Vector3(0, -.09, .18), Vector3(.25, .17, .44), p.main, tier)
				_ellipsoid(foot, Vector3(0, -.23, .18), Vector3(.26, .045, .46), p.under, tier)
				_shell(foot, Vector3(0, .04, -.12), Vector3(.25, .17, .20), -140, 140, -.10, p.main, tier)
				if tier != "light":
					for z: float in [.13, .31, .48]: _box(foot, Vector3(0, .065, z), Vector3(.35, .025, .035), p.edge, tier)

## Copies only the selected triangles from the hero's own skinned clothing.
## Bones, weights, UVs and Skin are retained byte-for-byte; only bind-space
## positions move outward by a small normal offset (about 4 cm at hero scale).
func _skinned_layer(slot: String, tier: String, y_min: float, y_max: float, inflation: float, color: Color, label: String, x_min: float = -99.0, x_max: float = 99.0, source_name: String = "player_male_DEMO_core_FABRIC", front_only: bool = false, bone_filter: String = "", style: String = "") -> bool:
	var source: MeshInstance3D = null
	for node: Node in _actor.find_children("*", "MeshInstance3D", true, false):
		if String(node.name) == source_name: source = node as MeshInstance3D; break
	if source == null:
		var wanted_suffix := "_core_SKIN" if source_name.ends_with("_core_SKIN") else "_core_FABRIC"
		for node: Node in _actor.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).ends_with(wanted_suffix):
				source = node as MeshInstance3D
				break
	if source == null or source.mesh == null or source.skin == null or not source.mesh is ArrayMesh: return false
	var key := "skinned:" + str(source.mesh.get_instance_id()) + ":" + str(y_min) + ":" + str(y_max) + ":" + str(x_min) + ":" + str(x_max) + ":" + str(inflation) + ":" + str(front_only) + ":" + bone_filter + ":" + style
	var generated: ArrayMesh = _mesh_cache.get(key) as ArrayMesh
	if generated == null:
		generated = ArrayMesh.new()
		for surface_index: int in source.mesh.get_surface_count():
			var arrays: Array = source.mesh.surface_get_arrays(surface_index)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var original_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var selected_binds := {}
			if not bone_filter.is_empty():
				var target_bone := _rig.find_bone(bone_filter)
				for bind: int in source.skin.get_bind_count():
					var bone := source.skin.get_bind_bone(bind)
					if bone < 0: bone = _rig.find_bone(source.skin.get_bind_name(bind))
					while bone >= 0:
						if bone == target_bone:
							selected_binds[bind] = true
							break
						bone = _rig.get_bone_parent(bone)
			if positions.is_empty() or normals.size() != positions.size() or original_indices.size() % 3 != 0: return false
			var inflated := _welded_inflated_positions(positions, normals, inflation)
			var indices := PackedInt32Array()
			for triangle: int in original_indices.size() / 3:
				var start := triangle * 3
				if not bone_filter.is_empty():
					if _triangle_bone_weight(original_indices, start, bones, weights, positions.size(), selected_binds) < .18: continue
				else:
					var center_y := (positions[original_indices[start]].y + positions[original_indices[start + 1]].y + positions[original_indices[start + 2]].y) / 3.0
					if center_y < y_min or center_y > y_max: continue
					var center_x := (positions[original_indices[start]].x + positions[original_indices[start + 1]].x + positions[original_indices[start + 2]].x) / 3.0
					if center_x < x_min or center_x > x_max: continue
					if front_only:
						var normal_z := (normals[original_indices[start]].z + normals[original_indices[start + 1]].z + normals[original_indices[start + 2]].z) / 3.0
						if normal_z < .28: continue
				indices.append(original_indices[start])
				indices.append(original_indices[start + 1])
				indices.append(original_indices[start + 2])
			if indices.is_empty(): continue
			if label in ["ArmorTailoredTorso", "ArmorFittedBreastplate", "ArmorFittedFauld"]:
				indices = _largest_welded_component(positions, indices)
			arrays[Mesh.ARRAY_VERTEX] = inflated
			var compact := _compact_surface(arrays, indices, positions.size())
			if style == "cuirass": _color_cuirass_surface(compact)
			generated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, compact)
		if generated.get_surface_count() == 0: return false
		_mesh_cache[key] = generated
	var overlay := MeshInstance3D.new()
	overlay.name = label + ("L" if x_max < 0 else ("R" if x_min > 0 else ""))
	overlay.mesh = generated
	overlay.skin = source.skin
	overlay.skeleton = source.skeleton
	overlay.transform = source.transform
	overlay.material_override = _cuirass_material() if style == "cuirass" else _material(color, tier)
	overlay.set_meta("armor_side", -1 if x_max < 0 else (1 if x_min > 0 else 0))
	source.get_parent().add_child(overlay)
	if not _skinned.has(slot): _skinned[slot] = []
	_skinned[slot].append(overlay)
	return true

func _triangle_bone_weight(indices: PackedInt32Array, start: int, bones: PackedInt32Array, weights: PackedFloat32Array, vertex_count: int, selected_binds: Dictionary) -> float:
	if bones.is_empty() or weights.is_empty() or vertex_count < 1: return 0.0
	var stride := int(bones.size() / vertex_count)
	if stride < 4 or weights.size() != bones.size(): return 0.0
	var total := 0.0
	for corner: int in 3:
		var vertex := indices[start + corner]
		for influence: int in stride:
			var offset := vertex * stride + influence
			if selected_binds.has(bones[offset]): total += weights[offset]
	return total / 3.0

func _welded_inflated_positions(positions: PackedVector3Array, normals: PackedVector3Array, inflation: float) -> PackedVector3Array:
	# UV seams duplicate vertices and may split their shading normals. Give each
	# duplicate bind position the same outward offset so armor has no cracks.
	var sums := {}
	var keys: Array[String] = []
	keys.resize(positions.size())
	for vertex: int in positions.size():
		var key := str(positions[vertex].snapped(Vector3.ONE * .0001))
		keys[vertex] = key
		var sum: Vector3 = sums.get(key, Vector3.ZERO)
		sums[key] = sum + normals[vertex]
	var inflated := positions.duplicate()
	for vertex: int in inflated.size():
		var averaged: Vector3 = sums[keys[vertex]]
		var direction := averaged.normalized() if averaged.length_squared() > .04 else normals[vertex]
		inflated[vertex] += direction * inflation
	return inflated

func _largest_welded_component(positions: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	# The imported FABRIC mesh contains disconnected lapels, tie and buttons.
	# Weld by bind-position for connectivity because GLB often duplicates vertices
	# at UV seams. Retain the body's largest component in each tailored region.
	var triangle_count := int(indices.size() / 3)
	if triangle_count < 2: return indices
	var vertex_keys: Array = []
	vertex_keys.resize(positions.size())
	var key_to_triangles := {}
	for triangle: int in triangle_count:
		for corner: int in 3:
			var vertex := indices[triangle * 3 + corner]
			var key: String = str(positions[vertex].snapped(Vector3.ONE * .006))
			vertex_keys[vertex] = key
			if not key_to_triangles.has(key): key_to_triangles[key] = []
			key_to_triangles[key].append(triangle)
	var visited := PackedByteArray()
	visited.resize(triangle_count)
	var best := PackedInt32Array()
	for first: int in triangle_count:
		if visited[first] != 0: continue
		var queue := [first]
		visited[first] = 1
		var component := PackedInt32Array()
		var cursor := 0
		while cursor < queue.size():
			var triangle: int = queue[cursor]
			cursor += 1
			component.append(triangle)
			for corner: int in 3:
				var key: String = vertex_keys[indices[triangle * 3 + corner]]
				for neighbor: int in key_to_triangles[key]:
					if visited[neighbor] == 0:
						visited[neighbor] = 1
						queue.append(neighbor)
		if component.size() > best.size(): best = component
	var retained := PackedInt32Array()
	for triangle: int in best:
		for corner: int in 3: retained.append(indices[triangle * 3 + corner])
	return retained

func _compact_surface(source_arrays: Array, selected_indices: PackedInt32Array, source_vertex_count: int) -> Array:
	# Every surviving triangle gets a dense index. Repack all populated vertex
	# channels with their original per-vertex stride, including 4/8 bone weights.
	var remap := {}
	var vertices := PackedInt32Array()
	var indices := PackedInt32Array()
	for original: int in selected_indices:
		if not remap.has(original):
			remap[original] = vertices.size()
			vertices.append(original)
		indices.append(int(remap[original]))
	var compact := source_arrays.duplicate(true)
	for channel: int in Mesh.ARRAY_MAX:
		if channel == Mesh.ARRAY_INDEX: continue
		var input: Variant = source_arrays[channel]
		if input == null or input.size() == 0: continue
		if source_vertex_count < 1 or input.size() % source_vertex_count != 0:
			var uncompressed := source_arrays.duplicate(true)
			uncompressed[Mesh.ARRAY_INDEX] = selected_indices
			return uncompressed
		var stride := int(input.size() / source_vertex_count)
		var output: Variant = input.duplicate()
		output.resize(0)
		for original: int in vertices:
			for component: int in stride:
				output.append(input[original * stride + component])
		compact[channel] = output
	compact[Mesh.ARRAY_INDEX] = indices
	return compact

func _color_cuirass_surface(arrays: Array) -> void:
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for point: Vector3 in positions:
		var front := smoothstep(.03, .40, point.z)
		var waist := smoothstep(1.78, 2.18, point.y)
		var upper := smoothstep(2.33, 2.80, point.y)
		var plate := Color(.105, .13, .15).lerp(Color(.17, .20, .22), upper * .45)
		plate *= lerpf(.70, 1.0, waist)
		var seam := absf(point.y - 2.30) < .055 or absf(point.y - 2.75) < .045
		if seam: plate *= .58
		var edge := smoothstep(.38, .62, absf(point.x))
		plate *= lerpf(1.0, .65, edge)
		colors.append(Color(.025, .031, .038).lerp(plate, front))
	arrays[Mesh.ARRAY_COLOR] = colors

func _cuirass_material() -> StandardMaterial3D:
	if _material_cache.has("fitted_cuirass_material_v22"): return _material_cache["fitted_cuirass_material_v22"]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = .70
	material.roughness = .47
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache["fitted_cuirass_material_v22"] = material
	return material

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
	mesh.mesh = _box_mesh(local_size)
	mesh.material_override = _material(color, tier)
	mesh.position = local_center * _unit
	mesh.scale = Vector3.ONE * _unit
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anchor.add_child(mesh)

func _ellipsoid(anchor: Node3D, local_center: Vector3, radii: Vector3, color: Color, tier: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "ArmorCurvedPlate"
	mesh.mesh = _sphere_mesh()
	mesh.material_override = _material(color, tier)
	mesh.position = local_center * _unit
	mesh.scale = radii * _unit
	anchor.add_child(mesh)

func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "box:" + str(size)
	if _mesh_cache.has(key): return _mesh_cache[key]
	var box := BoxMesh.new()
	box.size = size
	_mesh_cache[key] = box
	return box

func _sphere_mesh() -> SphereMesh:
	if _mesh_cache.has("sphere16x8"): return _mesh_cache["sphere16x8"]
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_mesh_cache["sphere16x8"] = sphere
	return sphere

## A curved open sheet, rather than a solid primitive. Angular gaps become real
## openings at the armpit, face, and back. The mesh has no collision authority.
func _shell(anchor: Node3D, center: Vector3, radii: Vector3, start_deg: float, end_deg: float, taper: float, color: Color, tier: String) -> void:
	var key := "shell:" + str(center) + ":" + str(radii) + ":" + str(start_deg) + ":" + str(end_deg) + ":" + str(taper)
	if _mesh_cache.has(key):
		var cached := MeshInstance3D.new()
		cached.name = "ArmorCurvedShell"
		cached.mesh = _mesh_cache[key]
		cached.scale = Vector3.ONE * _unit
		cached.material_override = _material(color, tier)
		anchor.add_child(cached)
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 18
	var rows := 6
	for row: int in rows:
		var v0 := float(row) / float(rows)
		var v1 := float(row + 1) / float(rows)
		for column: int in columns:
			var u0 := float(column) / float(columns)
			var u1 := float(column + 1) / float(columns)
			var a := _shell_point(center, radii, start_deg, end_deg, taper, u0, v0)
			var b := _shell_point(center, radii, start_deg, end_deg, taper, u1, v0)
			var c := _shell_point(center, radii, start_deg, end_deg, taper, u0, v1)
			var d := _shell_point(center, radii, start_deg, end_deg, taper, u1, v1)
			for point: Vector3 in [a, c, b, b, c, d]: surface.add_vertex(point)
	surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.name = "ArmorCurvedShell"
	shell.mesh = surface.commit()
	_mesh_cache[key] = shell.mesh
	shell.scale = Vector3.ONE * _unit
	shell.material_override = _material(color, tier)
	anchor.add_child(shell)

func _shell_point(center: Vector3, radii: Vector3, start_deg: float, end_deg: float, taper: float, u: float, v: float) -> Vector3:
	var angle := deg_to_rad(lerpf(start_deg, end_deg, u))
	var width := 1.0 + taper * (v - .5)
	return center + Vector3(sin(angle) * radii.x * width, (v - .5) * radii.y * 2.0, cos(angle) * radii.z * width)

func _vertex_steel() -> StandardMaterial3D:
	if _material_cache.has("vertex_steel"): return _material_cache["vertex_steel"]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = .54
	material.roughness = .59
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache["vertex_steel"] = material
	return material

func _cuirass(anchor: Node3D) -> void:
	var plate := MeshInstance3D.new()
	plate.name = "ArmorAnatomicCuirass"
	if not _mesh_cache.has("anatomic_cuirass_v1"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := [
			{"levels": [-.34, -.22, -.07, .12, .36], "base": Color(.10, .13, .15)},
			{"levels": [.42, .55, .72, .89, 1.02], "base": Color(.20, .23, .25)}
		]
		for segment: Dictionary in segments:
			var levels: Array = segment.levels
			for row: int in levels.size() - 1:
				for column: int in 20:
					var u0 := -1.0 + float(column) * .10
					var u1 := u0 + .10
					var y0: float = levels[row]
					var y1: float = levels[row + 1]
					var a := _cuirass_point(u0, y0)
					var b := _cuirass_point(u1, y0)
					var c := _cuirass_point(u0, y1)
					var d := _cuirass_point(u1, y1)
					var edge := .75 if absf((u0 + u1) * .5) > .84 else 1.0
					var band := 1.16 if row == 0 or row == levels.size() - 2 else 1.0
					var color: Color = segment.base * edge * band
					for point: Vector3 in [a, b, c, b, d, c]:
						surface.set_color(color)
						surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["anatomic_cuirass_v1"] = surface.commit()
	plate.mesh = _mesh_cache["anatomic_cuirass_v1"]
	plate.scale = Vector3.ONE * _unit
	plate.material_override = _vertex_steel()
	anchor.add_child(plate)

func _cuirass_point(u: float, y: float) -> Vector3:
	var width := (.59 + .075 * smoothstep(.08, .84, y)) * (1.0 - .08 * smoothstep(.84, 1.04, y))
	var curve := sqrt(maxf(.05, 1.0 - pow(u * .73, 2.0)))
	var chest := .08 * exp(-pow(y - .78, 2.0) / .14) * (1.0 - pow(u, 2.0))
	return Vector3(u * width, y, .07 + .65 * curve + chest)

func _pauldron_lames(anchor: Node3D) -> void:
	var plate := MeshInstance3D.new()
	plate.name = "ArmorJointedPauldron"
	if not _mesh_cache.has("pauldron_lames_v1"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for band: int in 3:
			var top := .28 - float(band) * .15
			var bottom := top - .11
			var radius := .43 - float(band) * .022
			var color := Color(.23, .26, .28) if band == 0 else (Color(.17, .20, .22) if band == 1 else Color(.12, .15, .17))
			for column: int in 16:
				var a0 := deg_to_rad(-135.0 + float(column) * 16.875)
				var a1 := deg_to_rad(-135.0 + float(column + 1) * 16.875)
				var p0 := Vector3(sin(a0) * radius, bottom, cos(a0) * radius + .13)
				var p1 := Vector3(sin(a1) * radius, bottom, cos(a1) * radius + .13)
				var p2 := Vector3(sin(a0) * (radius - .018), top, cos(a0) * (radius - .018) + .13)
				var p3 := Vector3(sin(a1) * (radius - .018), top, cos(a1) * (radius - .018) + .13)
				for point: Vector3 in [p0, p2, p1, p1, p2, p3]:
					surface.set_color(color)
					surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["pauldron_lames_v1"] = surface.commit()
	plate.mesh = _mesh_cache["pauldron_lames_v1"]
	plate.scale = Vector3.ONE * _unit
	plate.material_override = _vertex_steel()
	_align_authored_to_rig(plate, String(anchor.get_meta("armor_bone", "")))
	anchor.add_child(plate)

func _gauntlet(anchor: Node3D) -> void:
	var glove := MeshInstance3D.new()
	glove.name = "ArmorArticulatedGauntlet"
	if not _mesh_cache.has("gauntlet_v1"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y_levels := [.18, .07, -.08, -.20, -.34]
		var radii := [.17, .21, .22, .18, .10]
		for row: int in y_levels.size() - 1:
			var color := Color(.23, .26, .28) if row == 0 else (Color(.13, .16, .18) if row == 2 else Color(.18, .21, .23))
			for column: int in 12:
				var a0 := TAU * float(column) / 12.0
				var a1 := TAU * float(column + 1) / 12.0
				var p0 := Vector3(cos(a0) * radii[row], y_levels[row], sin(a0) * radii[row] * .82 + .055)
				var p1 := Vector3(cos(a1) * radii[row], y_levels[row], sin(a1) * radii[row] * .82 + .055)
				var p2 := Vector3(cos(a0) * radii[row + 1], y_levels[row + 1], sin(a0) * radii[row + 1] * .82 + .07)
				var p3 := Vector3(cos(a1) * radii[row + 1], y_levels[row + 1], sin(a1) * radii[row + 1] * .82 + .07)
				for point: Vector3 in [p0, p1, p2, p1, p3, p2]:
					surface.set_color(color)
					surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["gauntlet_v1"] = surface.commit()
	glove.mesh = _mesh_cache["gauntlet_v1"]
	glove.scale = Vector3.ONE * _unit
	glove.material_override = _vertex_steel()
	_align_authored_to_rig(glove, String(anchor.get_meta("armor_bone", "")))
	anchor.add_child(glove)

func _jointed_greave(anchor: Node3D) -> void:
	var greave := MeshInstance3D.new()
	greave.name = "ArmorJointedGreave"
	if not _mesh_cache.has("jointed_greave_v1"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		# The knee cup follows the shin bone; gaps between bands leave knee flex visible.
		var bands := [
			{"top": .23, "bottom": .08, "radius": .285, "color": Color(.23, .26, .28)},
			{"top": .045, "bottom": -.20, "radius": .245, "color": Color(.16, .19, .21)},
			{"top": -.23, "bottom": -.48, "radius": .215, "color": Color(.12, .15, .17)}
		]
		for band: Dictionary in bands:
			for column: int in 16:
				var a0 := deg_to_rad(-125.0 + float(column) * 15.625)
				var a1 := deg_to_rad(-125.0 + float(column + 1) * 15.625)
				var top: float = band.top
				var bottom: float = band.bottom
				var radius: float = band.radius
				var p0 := Vector3(sin(a0) * radius, bottom, cos(a0) * radius + .075)
				var p1 := Vector3(sin(a1) * radius, bottom, cos(a1) * radius + .075)
				var p2 := Vector3(sin(a0) * (radius + .015), top, cos(a0) * (radius + .015) + .075)
				var p3 := Vector3(sin(a1) * (radius + .015), top, cos(a1) * (radius + .015) + .075)
				for point: Vector3 in [p0, p2, p1, p1, p2, p3]:
					surface.set_color(band.color)
					surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["jointed_greave_v1"] = surface.commit()
	greave.mesh = _mesh_cache["jointed_greave_v1"]
	greave.scale = Vector3.ONE * _unit
	greave.material_override = _vertex_steel()
	_align_authored_to_rig(greave, String(anchor.get_meta("armor_bone", "")))
	anchor.add_child(greave)

func _boot_cap(anchor: Node3D) -> void:
	var cap := MeshInstance3D.new()
	cap.name = "ArmorArticulatedBootCap"
	if not _mesh_cache.has("articulated_boot_cap_v1"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var stations := [-.20, -.04, .13, .30, .47, .58]
		for row: int in stations.size() - 1:
			var z0: float = stations[row]
			var z1: float = stations[row + 1]
			var r0 := .175 + .075 * sin(float(row) / 5.0 * PI)
			var r1 := .175 + .075 * sin(float(row + 1) / 5.0 * PI)
			var color := Color(.16, .19, .21) if row % 2 == 0 else Color(.23, .26, .28)
			for column: int in 8:
				var a0 := PI * float(column) / 8.0
				var a1 := PI * float(column + 1) / 8.0
				var p0 := Vector3(cos(a0) * r0, -.045 + sin(a0) * .15, z0)
				var p1 := Vector3(cos(a1) * r0, -.045 + sin(a1) * .15, z0)
				var p2 := Vector3(cos(a0) * r1, -.045 + sin(a0) * .15, z1)
				var p3 := Vector3(cos(a1) * r1, -.045 + sin(a1) * .15, z1)
				for point: Vector3 in [p0, p2, p1, p1, p2, p3]:
					surface.set_color(color)
					surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["articulated_boot_cap_v1"] = surface.commit()
	cap.mesh = _mesh_cache["articulated_boot_cap_v1"]
	cap.scale = Vector3.ONE * _unit
	cap.material_override = _vertex_steel()
	_align_authored_to_rig(cap, String(anchor.get_meta("armor_bone", "")))
	anchor.add_child(cap)

func _align_authored_to_rig(mesh: MeshInstance3D, bone_name: String) -> void:
	var index := _rig.find_bone(bone_name)
	if index < 0: return
	# Drafted plate coordinates use the rig's bind-world up and front. Convert
	# them into this bone's local bind frame; the bone then carries the plate.
	mesh.quaternion = _rig.get_bone_global_rest(index).basis.inverse().get_rotation_quaternion()

func _face_helmet(anchor: Node3D) -> void:
	var face := MeshInstance3D.new()
	face.name = "ArmorForgedFaceWithEyeSlits"
	if not _mesh_cache.has("forged_face_v26"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var levels: Array[float] = [-.13, .02, .16, .31, .52, .69, .79, .87, .95]
		for row: int in levels.size() - 1:
			for column: int in 24:
				var x0 := -.60 + float(column) * .05
				var x1 := x0 + .05
				var center_x := (x0 + x1) * .5
				# Two genuine openings, bounded by a central nose bridge and cheek plates.
				if row == 5 and absf(center_x) > .17 and absf(center_x) < .39: continue
				if row <= 1: continue
				# Cheek plates taper to the jaw; the central nose bridge stays narrow.
				if row <= 3:
					var side_min: float = [.28, .26, .23, .20][row]
					var side_max: float = [.42, .47, .52, .58][row]
					if absf(center_x) > side_max: continue
					if absf(center_x) < side_min and (row <= 1 or absf(center_x) > .10): continue
				var a := _face_point(x0, levels[row])
				var b := _face_point(x1, levels[row])
				var c := _face_point(x0, levels[row + 1])
				var d := _face_point(x1, levels[row + 1])
				for point: Vector3 in [a, b, c, b, d, c]: surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["forged_face_v26"] = surface.commit()
	face.mesh = _mesh_cache["forged_face_v26"]
	face.scale = Vector3.ONE * _unit
	face.material_override = _material(Color(.075, .095, .108), "heavy")
	anchor.add_child(face)
	_forged_brows(anchor)
	var seams := MeshInstance3D.new()
	seams.name = "ArmorForgedCheekSeams"
	if not _mesh_cache.has("forged_cheek_seams_v1"):
		var seam_surface := SurfaceTool.new()
		seam_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1.0, 1.0]:
			for step: int in 8:
				var y0 := -.08 + float(step) * .065
				var y1 := y0 + .065
				var x0 := side * lerpf(.33, .17, smoothstep(-.08, .44, y0))
				var x1 := side * lerpf(.33, .17, smoothstep(-.08, .44, y1))
				var a := _face_point(x0 - .009, y0) + Vector3(0, 0, .013)
				var b := _face_point(x0 + .009, y0) + Vector3(0, 0, .013)
				var c := _face_point(x1 - .009, y1) + Vector3(0, 0, .013)
				var d := _face_point(x1 + .009, y1) + Vector3(0, 0, .013)
				for point: Vector3 in [a, b, c, b, d, c]: seam_surface.add_vertex(point)
		seam_surface.generate_normals()
		_mesh_cache["forged_cheek_seams_v1"] = seam_surface.commit()
	seams.mesh = _mesh_cache["forged_cheek_seams_v1"]
	seams.scale = Vector3.ONE * _unit
	seams.material_override = _material(Color(.045, .06, .07), "heavy")
	anchor.add_child(seams)

func _forged_brows(anchor: Node3D) -> void:
	var brows := MeshInstance3D.new()
	brows.name = "ArmorAngledBrowRidges"
	if not _mesh_cache.has("angled_brows_v22"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1.0, 1.0]:
			for column: int in 8:
				var u0 := float(column) / 8.0
				var u1 := float(column + 1) / 8.0
				var x0 := side * lerpf(.15, .45, u0)
				var x1 := side * lerpf(.15, .45, u1)
				var y0 := .84 - .075 * u0
				var y1 := .84 - .075 * u1
				var a := _face_point(x0, y0 - .026) + Vector3(0, 0, .03)
				var b := _face_point(x1, y1 - .026) + Vector3(0, 0, .03)
				var c := _face_point(x0, y0 + .026) + Vector3(0, 0, .03)
				var d := _face_point(x1, y1 + .026) + Vector3(0, 0, .03)
				for point: Vector3 in [a, b, c, b, d, c]: surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["angled_brows_v22"] = surface.commit()
	brows.mesh = _mesh_cache["angled_brows_v22"]
	brows.scale = Vector3.ONE * _unit
	brows.material_override = _material(Color(.17, .20, .22), "heavy")
	anchor.add_child(brows)

func _face_point(x: float, y: float) -> Vector3:
	var shaped_x := x * lerpf(.67, .93, smoothstep(-.13, .95, y))
	var arc := sqrt(maxf(.02, 1.0 - pow(shaped_x / .76, 2.0)))
	var nose := .13 * exp(-pow(shaped_x / .11, 2.0)) * smoothstep(.0, .4, y)
	var cheek := .085 * exp(-pow((absf(shaped_x) - .31) / .11, 2.0)) * (1.0 - smoothstep(.45, .85, y))
	return Vector3(shaped_x, y, -.04 + .73 * arc + nose + cheek)

func _helmet_side_plates(anchor: Node3D) -> void:
	var plates := MeshInstance3D.new()
	plates.name = "ArmorJoinedTempleEarAndJawPlates"
	if not _mesh_cache.has("joined_temples_v22l"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1.0, 1.0]:
			for row: int in 8:
				for column: int in 9:
					var u0 := float(column) / 9.0
					var u1 := float(column + 1) / 9.0
					var v0 := float(row) / 8.0
					var v1 := float(row + 1) / 8.0
					var a := _helmet_side_point(side, u0, v0)
					var b := _helmet_side_point(side, u1, v0)
					var c := _helmet_side_point(side, u0, v1)
					var d := _helmet_side_point(side, u1, v1)
					for point: Vector3 in [a, b, c, b, d, c]: surface.add_vertex(point)
		surface.generate_normals()
		_mesh_cache["joined_temples_v22l"] = surface.commit()
	plates.mesh = _mesh_cache["joined_temples_v22l"]
	plates.scale = Vector3.ONE * _unit
	plates.material_override = _material(Color(.088, .11, .125), "heavy")
	anchor.add_child(plates)

func _helmet_side_point(side: float, around: float, height: float) -> Vector3:
	# The front edge is welded visually to the cheek; the broad middle covers
	# the ear, and its lower rim climbs diagonally toward the occiput.
	var lower_y := .12 + .22 * pow(around, 3.0)
	var y := lerpf(lower_y, .98, height)
	var front := _face_point(side * lerpf(.50, .56, height), y)
	var angle := lerpf(deg_to_rad(32.0), deg_to_rad(157.0), around)
	var taper := lerpf(.82, 1.0, smoothstep(0.0, .42, height))
	var ear_cover := .18 * exp(-pow((y - .48) / .27, 2.0))
	var ear_flank := exp(-pow((around - .35) / .22, 2.0)) * exp(-pow((y - .42) / .24, 2.0))
	var rounded := Vector3(side * (sin(angle) * (.56 + ear_cover) * taper + .17 * ear_flank), y, -.01 + cos(angle) * .64 * taper + .18 * ear_flank)
	return front.lerp(rounded, smoothstep(.0, .22, around))

func _dome(anchor: Node3D, center: Vector3, radii: Vector3, color: Color, tier: String, front_cut_rows: int = 0) -> void:
	var key := "dome:" + str(center) + ":" + str(radii) + ":" + str(front_cut_rows)
	if _mesh_cache.has(key):
		var cached := MeshInstance3D.new()
		cached.name = "ArmorHollowHelmet"
		cached.mesh = _mesh_cache[key]
		cached.scale = Vector3.ONE * _unit
		cached.material_override = _material(color, tier)
		anchor.add_child(cached)
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in 8:
		var p0 := float(row) / 8.0 * PI * .5
		var p1 := float(row + 1) / 8.0 * PI * .5
		for column: int in 24:
			var t0 := float(column) / 24.0 * TAU
			var t1 := float(column + 1) / 24.0 * TAU
			var middle_angle := (t0 + t1) * .5
			if front_cut_rows > 0 and row >= 8 - front_cut_rows and (middle_angle < deg_to_rad(70.0) or middle_angle > TAU - deg_to_rad(70.0)): continue
			var a := center + Vector3(sin(t0) * sin(p0) * radii.x, cos(p0) * radii.y, cos(t0) * sin(p0) * radii.z)
			var b := center + Vector3(sin(t1) * sin(p0) * radii.x, cos(p0) * radii.y, cos(t1) * sin(p0) * radii.z)
			var c := center + Vector3(sin(t0) * sin(p1) * radii.x, cos(p1) * radii.y, cos(t0) * sin(p1) * radii.z)
			var d := center + Vector3(sin(t1) * sin(p1) * radii.x, cos(p1) * radii.y, cos(t1) * sin(p1) * radii.z)
			for point: Vector3 in [a, c, b, b, c, d]: surface.add_vertex(point)
	surface.generate_normals()
	var helmet := MeshInstance3D.new()
	helmet.name = "ArmorHollowHelmet"
	helmet.mesh = surface.commit()
	_mesh_cache[key] = helmet.mesh
	helmet.scale = Vector3.ONE * _unit
	helmet.material_override = _material(color, tier)
	anchor.add_child(helmet)

func _rivet(anchor: Node3D, at: Vector3, color: Color, tier: String) -> void:
	_ellipsoid(anchor, at, Vector3(.025, .025, .025), color, tier)

func _crest(anchor: Node3D, color: Color, tier: String) -> void:
	if _mesh_cache.has("dark_fan_crest_v22"):
		var cached := MeshInstance3D.new()
		cached.name = "ArmorDarkFanCrest"
		cached.mesh = _mesh_cache["dark_fan_crest_v22"]
		cached.scale = Vector3.ONE * _unit
		cached.material_override = _material(color, tier)
		anchor.add_child(cached)
		return
	# A rounded tapered plume, all strands in one bounded mesh.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in 18:
		var x0 := -.39 + float(segment) * .0433333
		var x1 := x0 + .0433333
		var h0 := 1.31 + .43 * sqrt(maxf(0.0, 1.0 - pow(x0 / .42, 2.0)))
		var h1 := 1.31 + .43 * sqrt(maxf(0.0, 1.0 - pow(x1 / .42, 2.0)))
		for z: float in [-.052, .052]:
			var a := Vector3(x0 * .65, 1.09, z)
			var b := Vector3(x1 * .65, 1.09, z)
			var c := Vector3(x0, h0, z - .035)
			var d := Vector3(x1, h1, z - .035)
			for point: Vector3 in [a, c, b, b, c, d]: surface.add_vertex(point)
	surface.generate_normals()
	var plume := MeshInstance3D.new()
	plume.name = "ArmorDarkFanCrest"
	plume.mesh = surface.commit()
	_mesh_cache["dark_fan_crest_v22"] = plume.mesh
	plume.scale = Vector3.ONE * _unit
	plume.material_override = _material(color, tier)
	anchor.add_child(plume)

func _crest_ribs(anchor: Node3D) -> void:
	var ribs := MeshInstance3D.new()
	ribs.name = "ArmorFanCrestRibs"
	if _mesh_cache.has("fan_crest_ribs_v22"):
		ribs.mesh = _mesh_cache["fan_crest_ribs_v22"]
	else:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strand: int in 17:
			var x := -.36 + float(strand) * .045
			var tip := 1.31 + .43 * sqrt(maxf(0.0, 1.0 - pow(x / .42, 2.0)))
			var base := x * .65
			var points := [Vector3(base - .008, 1.10, .056), Vector3(base + .008, 1.10, .056), Vector3(x + .006, tip - .025, .025), Vector3(x - .006, tip - .025, .025)]
			for index: int in [0, 1, 3, 1, 2, 3]: surface.add_vertex(points[index])
		surface.generate_normals()
		ribs.mesh = surface.commit()
		_mesh_cache["fan_crest_ribs_v22"] = ribs.mesh
	ribs.scale = Vector3.ONE * _unit
	ribs.material_override = _material(Color(.20, .22, .24), "medium")
	anchor.add_child(ribs)

func _material(color: Color, tier: String) -> StandardMaterial3D:
	var key := tier + ":" + color.to_html(true)
	if _material_cache.has(key): return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if tier == "heavy":
		var is_padding := color == PALETTE["heavy"]["under"]
		material.metallic = .10 if is_padding else .58
		material.roughness = .88 if is_padding else .59
	elif tier == "medium":
		material.metallic = .42
		material.roughness = .62
	else:
		material.metallic = .06
		material.roughness = .83
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = material
	return material
