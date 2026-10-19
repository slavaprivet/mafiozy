extends Control
## One shared screen-space nameplate. World visibility comes from the owner's
## bounded native ray; text stays crisp independently of the world's TAA.
const BACKGROUND = preload("res://scripts/npc_visual/resident_card_canvas29.gdshader")
const META := "npc_resident_card_canvas29"
var _label: WeakRef
var _title: Label
var _health: Label
var _background: ColorRect
var _last_claim := -100

static func for_scene(scene: Node) -> Control:
	var held: Variant = scene.get_meta(META) if scene.has_meta(META) else null
	if held is WeakRef and is_instance_valid(held.get_ref()): return held.get_ref()
	var layer := CanvasLayer.new(); layer.name = "ResidentFocusCanvas29"; layer.layer = 12
	scene.add_child(layer)
	var card: Control = load("res://scripts/npc_visual/npc_resident_card_canvas29.gd").new()
	layer.add_child(card); scene.set_meta(META, weakref(card))
	return card

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(224, 64)
	_background = ColorRect.new(); _background.size = size
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new(); material.shader = BACKGROUND
	_background.material = material; add_child(_background)
	_title = Label.new(); _title.position = Vector2(12, 4); _title.size = Vector2(200, 27)
	_title.text = "Житель"; _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_title)
	_health = Label.new(); _health.position = Vector2(12, 34); _health.size = Vector2(200, 24)
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _health.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health.add_theme_font_size_override("font_size", 15)
	_health.add_theme_color_override("font_color", Color("f3f8f5"))
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_health)
	visible = false

func claim(label: Label3D) -> void:
	_label = weakref(label); _last_claim = Engine.get_physics_frames()

func release(label: Label3D) -> void:
	if _label != null and _label.get_ref() == label: visible = false; _label = null

func _process(_delta: float) -> void:
	var label: Label3D = _label.get_ref() as Label3D if _label != null else null
	if not is_instance_valid(label) or not label.is_inside_tree() or not label.visible or Engine.get_physics_frames() - _last_claim > 2:
		visible = false; return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(label.global_position): visible = false; return
	var point: Vector2 = camera.unproject_position(label.global_position)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2(clampf(point.x - size.x * .5, 8, screen.x - size.x - 8), clampf(point.y - size.y * .5, 8, screen.y - size.y - 8))
	_title.add_theme_color_override("font_color", label.modulate)
	_health.text = str(label.get_meta("card29_health_text", ""))
	(_background.material as ShaderMaterial).set_shader_parameter("health", float(label.get_meta("card29_display_ratio", 1.0)))
	visible = true
