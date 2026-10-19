extends Node3D
## Vest worn over the clothes of the preview hero.
## Presentation only: armor points live in the backpack and are never written here.
## The vest is a box that follows the chest bone every frame: its size and offset are
## fractions of the actor's measured height, so it fits the real 1.9 m hero and any
## other humanoid rig without hand tuning. No BoneAttachment3D is used: its own
## transform must not be written when the skeleton owns the pose.
const BONE := "chest"
const HEIGHT_FRACTION := 0.23
const WIDTH_FRACTION := 0.24
const DEPTH_FRACTION := 0.16
const LIFT_FRACTION := 0.05
const FALLBACK_HEIGHT_M := 1.9
const DEFAULT_COLOR := "#46525c"
const BROKEN_DARKEN := 0.45
var ready_for_use := false
var error_text := ""
var _player: Node3D
var _rig: Skeleton3D
var _chest := -1
var _mesh: MeshInstance3D
var _box: BoxMesh
var _material: StandardMaterial3D
var _model_height := FALLBACK_HEIGHT_M
var _world_per_bone := 1.0
var _worn := ""
var _broken := false

func configure(player: Node3D, rig: Skeleton3D) -> Dictionary:
	if ready_for_use:
		return {"ok": false, "reason": "already_configured"}
	if not is_instance_valid(player) or not is_instance_valid(rig):
		return _fail("binding")
	var chest: int = rig.find_bone(BONE)
	if chest < 0:
		return _fail("chest_bone")
	_player = player
	_rig = rig
	_chest = chest
	_model_height = _measure_height(player)
	_mesh = MeshInstance3D.new()
	_mesh.name = "WornArmorMesh"
	_box = BoxMesh.new()
	_mesh.mesh = _box
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(DEFAULT_COLOR)
	_material.roughness = 0.62
	_material.metallic = 0.08
	_mesh.material_override = _material
	_mesh.visible = false
	add_child(_mesh)
	_follow_bone()
	ready_for_use = true
	return {
		"ok": true,
		"scope": "local_preview_armor_visual",
		"bone": BONE,
		"bone_index": chest,
		"model_height_m": _model_height,
		"world_per_bone": _world_per_bone,
		"size_m": [_box.size.x * _world_per_bone, _box.size.y * _world_per_bone, _box.size.z * _world_per_bone]
	}

## Shows the bought vest over the clothes. An empty id takes it off again.
func set_vest(id: String, color_hex: String = DEFAULT_COLOR, broken: bool = false) -> Dictionary:
	if not ready_for_use or not is_instance_valid(_mesh):
		return {"ok": false, "reason": "not_ready"}
	if id.is_empty():
		return clear_vest()
	_worn = id
	_broken = broken
	var tint := Color(color_hex if not color_hex.is_empty() else DEFAULT_COLOR)
	if broken:
		tint = tint.darkened(BROKEN_DARKEN)
	_material.albedo_color = tint
	_material.metallic = 0.03 if broken else 0.08
	_mesh.visible = true
	_follow_bone()
	return {"ok": true, "worn": _worn, "broken": _broken, "color": tint.to_html(false)}

func clear_vest() -> Dictionary:
	_worn = ""
	_broken = false
	if is_instance_valid(_mesh):
		_mesh.visible = false
	return {"ok": true, "worn": ""}

func worn() -> String:
	return _worn

func snapshot() -> Dictionary:
	return {
		"ready": ready_for_use,
		"error": error_text,
		"worn": _worn,
		"broken": _broken,
		"visible": _mesh.visible if is_instance_valid(_mesh) else false,
		"model_height_m": _model_height,
		"world_per_bone": _world_per_bone,
		"scope": "local_preview_armor_visual"
	}

func _process(_delta: float) -> void:
	_follow_bone()

## The chest bone of the real rig owns the pose; this node only reads it. Sizes are
## expressed in bone units, so the same numbers work for every model scale.
func _follow_bone() -> void:
	if not is_instance_valid(_mesh) or not is_instance_valid(_rig) or _chest < 0:
		return
	var frame: Transform3D = _rig.global_transform * _rig.get_bone_global_pose(_chest)
	if not frame.origin.is_finite():
		return
	var basis := frame.basis.orthonormalized()
	var scale_y := maxf(0.000001, frame.basis.get_scale().y)
	_world_per_bone = scale_y
	_box.size = Vector3(
		WIDTH_FRACTION * _model_height / scale_y,
		HEIGHT_FRACTION * _model_height / scale_y,
		DEPTH_FRACTION * _model_height / scale_y)
	_mesh.global_transform = Transform3D(basis, frame.origin) * Transform3D(Basis.IDENTITY, Vector3(0, LIFT_FRACTION * _model_height / scale_y, 0))

func _measure_height(actor: Node3D) -> float:
	var box := AABB()
	var first := true
	for child: Node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child
		if mesh_instance.mesh == null:
			continue
		var world: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		box = world if first else box.merge(world)
		first = false
	if not first and box.size.y > 0.1 and is_finite(box.size.y):
		return box.size.y
	return FALLBACK_HEIGHT_M

func dispose() -> void:
	ready_for_use = false
	_worn = ""
	if is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = null
	_box = null
	_material = null
	_rig = null
	_player = null

func _fail(reason: String) -> Dictionary:
	error_text = reason
	return {"ok": false, "reason": reason}
