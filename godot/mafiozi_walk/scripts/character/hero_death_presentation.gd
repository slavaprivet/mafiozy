extends Node
## One-shot death view. The existing articulated physics owner moves the body;
## this node only follows it with a separate camera and presents the cause.

var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var title: Label
var cause := "combat"
var _relative_offset := Vector3(3.5, 3.7, 6.0)

func begin(scene: Node3D, actor: CharacterBody3D, death_cause: String) -> bool:
	if is_instance_valid(camera) or not is_instance_valid(scene) or not is_instance_valid(actor):
		return false
	world = scene
	player = actor
	cause = "fall" if death_cause == "fall" else "combat"
	var original := scene.get_viewport().get_camera_3d()
	var yaw := float(actor.get("_camera_yaw"))
	_relative_offset = Basis(Vector3.UP, yaw) * _relative_offset
	camera = Camera3D.new()
	camera.name = "HeroDeathCamera"
	camera.fov = 55.0
	camera.near = 0.08
	camera.far = 1600.0
	scene.add_child(camera)
	if is_instance_valid(original):
		camera.global_transform = original.global_transform
	else:
		camera.global_position = actor.global_position + _relative_offset
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.name = "HeroDeathMessage"
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "DeathMessagePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.72
	panel.anchor_bottom = 0.72
	panel.offset_left = -190.0
	panel.offset_right = 190.0
	panel.offset_top = -45.0
	panel.offset_bottom = 45.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.065, 0.82)
	style.border_color = Color(0.59, 0.42, 0.25, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	title = Label.new()
	title.name = "DeathCause"
	title.text = "Разбился" if cause == "fall" else "Пал в бою"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.94, 0.78, 0.61))
	column.add_child(title)
	var hint := Label.new()
	hint.text = "R — начать заново"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.82, 0.81, 0.77))
	column.add_child(hint)
	set_process(true)
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		set_process(false)
		return
	var focus := player.global_position + Vector3.UP * 0.75
	var desired := Transform3D(Basis.IDENTITY, focus + _relative_offset).looking_at(focus, Vector3.UP)
	camera.global_transform = camera.global_transform.interpolate_with(desired,
		clampf(delta * 3.8, 0.0, 1.0))
