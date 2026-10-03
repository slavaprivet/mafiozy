class_name PreviewBoundary
extends Node3D
## Temporary visible/physical guard for the cropped preview only.
## The caller supplies the admitted block.surface.boundsLocalM; this node does
## not create floors, water, source identities, or any per-frame work.

const WALL_HEIGHT_M := 2.5
const WALL_THICKNESS_M := 0.3
const EAST_LABEL_Z_M := -9.75
const LABEL_TEXT := "Граница тестового участка"
const GOLD := Color("d3a43c")
const SUBDUED_GOLD := Color("715923")

var configured := false
var bounds_local_m := AABB()

func configure(bounds_value: Variant, label_anchor_local_m: Variant = null) -> bool:
	if configured:
		return false
	var minimum := _v3(bounds_value.get("min") if bounds_value is Dictionary else null)
	var maximum := _v3(bounds_value.get("max") if bounds_value is Dictionary else null)
	if not minimum.is_finite() or not maximum.is_finite():
		return false
	var size := maximum - minimum
	if size.x <= WALL_THICKNESS_M * 2.0 or size.z <= WALL_THICKNESS_M * 2.0 or size.y < 0.0:
		return false
	bounds_local_m = AABB(minimum, size)
	var floor_y := maximum.y
	var center_y := floor_y + WALL_HEIGHT_M * 0.5
	var center_x := (minimum.x + maximum.x) * 0.5
	var center_z := (minimum.z + maximum.z) * 0.5
	_add_wall("West", Vector3(minimum.x + WALL_THICKNESS_M * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS_M, WALL_HEIGHT_M, size.z), GOLD)
	_add_wall("East", Vector3(maximum.x - WALL_THICKNESS_M * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS_M, WALL_HEIGHT_M, size.z), GOLD)
	_add_wall("North", Vector3(center_x, center_y, minimum.z + WALL_THICKNESS_M * 0.5),
		Vector3(size.x, WALL_HEIGHT_M, WALL_THICKNESS_M), SUBDUED_GOLD)
	_add_wall("South", Vector3(center_x, center_y, maximum.z - WALL_THICKNESS_M * 0.5),
		Vector3(size.x, WALL_HEIGHT_M, WALL_THICKNESS_M), SUBDUED_GOLD)
	_add_east_label(minimum, maximum, floor_y, label_anchor_local_m)
	configured = true
	return true

func _add_wall(side: String, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary" + side
	body.position = center
	body.set_meta("preview_boundary_side", side.to_lower())
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.15
	material.roughness = 0.72
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visible_wall := MeshInstance3D.new()
	visible_wall.name = "VisibleWall"
	visible_wall.mesh = mesh
	visible_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visible_wall)
	add_child(body)

func _add_east_label(minimum: Vector3, maximum: Vector3, floor_y: float,
		label_anchor_local_m: Variant) -> void:
	var label := Label3D.new()
	label.name = "BoundaryLabel"
	label.text = LABEL_TEXT
	var anchor := _v3(label_anchor_local_m)
	if not anchor.is_finite():
		anchor = Vector3(maximum.x - WALL_THICKNESS_M - 0.15, floor_y, EAST_LABEL_Z_M)
	label.position = Vector3(
		clampf(anchor.x, minimum.x + WALL_THICKNESS_M, maximum.x - WALL_THICKNESS_M),
		floor_y + WALL_HEIGHT_M * 0.70,
		clampf(anchor.z, minimum.z + 2.0, maximum.z - 2.0))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.no_depth_test = false
	label.modulate = Color("f0c760")
	label.outline_modulate = Color("3a2d12")
	label.font_size = 48
	label.outline_size = 8
	label.pixel_size = 0.008
	add_child(label)

static func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		return Vector3(float(value.x), float(value.y), float(value.z))
	return Vector3(NAN, NAN, NAN)
