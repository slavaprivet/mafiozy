extends RefCounted
## One camera ray per physics frame, shared by every resident. Current health is
## supplied by its existing owner; this presentation never changes simulation.
const CARD_SHADER = preload("res://scripts/npc_visual/resident_card29.gdshader")
const RANGE_M := 5.0
static var _frame := -1
static var _scene_id := 0
static var _hit: WeakRef
static var _player_position := Vector3.INF
static var _queries := 0
static var _shader: Shader = CARD_SHADER

static func focused(body: Node3D) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree(): return false
	var scene: Node = body.get_tree().current_scene
	if scene == null: return false
	var frame: int = Engine.get_physics_frames()
	if frame != _frame or scene.get_instance_id() != _scene_id:
		_frame = frame; _scene_id = scene.get_instance_id(); _hit = null
		_player_position = Vector3.INF
		var player: Node3D = scene.get("_player") as Node3D
		var camera: Camera3D = body.get_viewport().get_camera_3d()
		if not is_instance_valid(player) or not is_instance_valid(camera): return false
		_player_position = player.global_position
		var viewport: Viewport = body.get_viewport()
		var screen: Vector2 = viewport.get_visible_rect().size * .5 if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else viewport.get_mouse_position()
		var origin: Vector3 = camera.project_ray_origin(screen)
		# Third-person camera can be behind the player. The player-distance gate
		# below is separate from camera ray length.
		var length: float = camera.global_position.distance_to(_player_position) + RANGE_M + 2.0
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * length)
		if player is CollisionObject3D: ray.exclude = [(player as CollisionObject3D).get_rid()]
		ray.collide_with_areas = false
		var result: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
		_queries += 1
		if result.get("collider") is Node: _hit = weakref(result.collider)
	if not _player_position.is_finite() or body.global_position.distance_squared_to(_player_position) > RANGE_M * RANGE_M: return false
	var collider: Node = _hit.get_ref() as Node if _hit != null else null
	return is_instance_valid(collider) and (collider == body or body.is_ancestor_of(collider))

static func prepare(label: Label3D) -> void:
	if label.get_node_or_null("ResidentIdentityCard29") != null: return
	var old: Node = label.get_node_or_null("ResidentIdentityCard28")
	if old != null:
		if old is Node3D: old.visible = false
		old.queue_free()
	label.font_size = 42
	label.pixel_size = .0034
	label.outline_size = 5
	label.render_priority = 2
	label.offset = Vector2(0, 24)
	var card := MeshInstance3D.new()
	card.name = "ResidentIdentityCard29"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.76, .49)
	card.mesh = quad
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.render_priority = 0
	card.material_override = material
	label.add_child(card)
	var hp := Label3D.new()
	hp.name = "ResidentHealth29"
	hp.font_size = 28; hp.pixel_size = label.pixel_size
	hp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp.no_depth_test = true; hp.double_sided = true
	hp.outline_size = 4; hp.outline_modulate = Color("08121a")
	hp.modulate = Color("f3f8f5"); hp.render_priority = 2
	hp.offset = Vector2(0, -29)
	hp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.add_child(hp)

static func paint(label: Label3D, hp: float, maximum: float, known: bool, ratio: float) -> void:
	prepare(label)
	var health_label: Label3D = label.get_node("ResidentHealth29")
	var text: String = "Здоровье  %d / %d" % [ceili(hp), ceili(maximum)] if known else "Здоровье  —"
	if health_label.text != text: health_label.text = text
	var now: int = Time.get_ticks_msec()
	var previous: float = float(label.get_meta("card29_display_ratio", ratio))
	var seconds: float = clampf(float(now - int(label.get_meta("card29_paint_ms", now))) / 1000.0, 0.0, .1)
	var shown: float = lerpf(previous, ratio, 1.0 - exp(-seconds * 14.0))
	if absf(shown - ratio) < .001: shown = ratio
	var card: MeshInstance3D = label.get_node("ResidentIdentityCard29")
	(card.material_override as ShaderMaterial).set_shader_parameter("health", shown)
	label.set_meta("card29_display_ratio", shown)
	label.set_meta("card29_paint_ms", now)
	label.set_meta("npc_vitals29_style", "walk_two_lines_soft_health_fill")

static func update_visibility(body: Node3D, label: Label3D, row: Dictionary) -> void:
	label.visible = not bool(row.get("dead", false)) and focused(body)
	label.set_meta("focus29_range_m", RANGE_M)
	label.set_meta("focus29_ray_queries", _queries)

static func diagnostics() -> Dictionary:
	return {"ray_queries": _queries, "frame": _frame, "range_m": RANGE_M}
