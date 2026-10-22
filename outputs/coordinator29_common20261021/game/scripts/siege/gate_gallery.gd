extends Node3D
## Timber hoarding over the main gate: a working platform for the stone hatch and the
## oil cauldron. It replaces the old rope bridge that used to sit buried inside the
## merlons; the bridge had no collision and no access, while this deck is a place the
## player can actually stand on and fight from.
##
## The deck is static (it is the work surface, not a target), but every moving part of
## the two mechanisms lives in sibling nodes. Geometry is merged into a handful of
## vertex-coloured meshes: the deck costs two draw calls, the ironwork one, the stone
## spout one.

const Layout = preload("res://scripts/siege/gate_defense_layout.gd")
const Art = preload("res://scripts/siege/gate_defense_art.gd")

var _castle: Node3D
var _stats := {}


func install(castle: Node3D) -> Dictionary:
	_castle = castle
	name = "GateGallery"
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.93, 0.0, true)
	var iron: Material = castle.call("shared_material", "iron")
	var stone: Material = castle.call("shared_material", "stone")
	var cold: Material = castle.call("shared_material", "cold")

	var deck_parts: Array[Dictionary] = []
	var beam_parts: Array[Dictionary] = []
	var iron_parts: Array[Dictionary] = []
	var stone_parts: Array[Dictionary] = []

	_build_deck(deck_parts)
	_build_stairs(beam_parts)
	_build_frame(beam_parts, iron_parts)
	_build_parapets(beam_parts, iron_parts)
	_build_corbels(beam_parts, iron_parts)
	_build_spout(stone_parts)

	var deck := Art.box_batch(deck_parts, wood)
	deck.name = "GalleryDeck"
	add_child(deck)
	var beams := Art.box_batch(beam_parts, wood)
	beams.name = "GalleryFrame"
	add_child(beams)
	if not iron_parts.is_empty():
		var fittings := Art.box_batch(iron_parts, iron)
		fittings.name = "GalleryIronwork"
		add_child(fittings)
	var stonework := Art.box_batch(stone_parts, stone)
	stonework.name = "OilSpout"
	add_child(stonework)

	_build_collision()
	_build_labels(cold)
	_stats = {
		"deck_parts": deck_parts.size(),
		"beam_parts": beam_parts.size(),
		"iron_parts": iron_parts.size(),
		"stone_parts": stone_parts.size(),
		"floor_y": Layout.FLOOR_Y,
	}
	return {"ok": true, "stats": _stats}


func get_stats() -> Dictionary:
	return _stats.duplicate(true)


## ------------------------------------------------------------------ deck

func _build_deck(parts: Array[Dictionary]) -> void:
	var count := 20
	var width := (Layout.HALF_W * 2.0) / float(count)
	var hatch_min := Layout.HATCH_CENTRE.x - Layout.HATCH_HALF.x
	var hatch_max := Layout.HATCH_CENTRE.x + Layout.HATCH_HALF.x
	var hatch_z_min := Layout.HATCH_CENTRE.z - Layout.HATCH_HALF.y
	var hatch_z_max := Layout.HATCH_CENTRE.z + Layout.HATCH_HALF.y
	for i: int in count:
		var x: float = -Layout.HALF_W + (float(i) + 0.5) * width
		var tint := Color(0.40, 0.265, 0.150) if i % 3 != 1 else Color(0.355, 0.225, 0.125)
		tint = tint.lightened(0.012 * float(i % 4))
		var planks: Array[Vector2] = []
		if x + width * 0.5 <= hatch_min or x - width * 0.5 >= hatch_max:
			planks.append(Vector2(Layout.Z_IN, Layout.Z_OUT))
		else:
			planks.append(Vector2(Layout.Z_IN, hatch_z_min))
			planks.append(Vector2(hatch_z_max, Layout.Z_OUT))
		for segment: Vector2 in planks:
			var length: float = segment.y - segment.x
			if length <= 0.05:
				continue
			parts.append(Art.box(
				Vector3(x, Layout.FLOOR_Y - Layout.DECK * 0.5, (segment.x + segment.y) * 0.5),
				Vector3(width - 0.006, Layout.DECK, length - 0.004), tint))


## ------------------------------------------------------------------ access

func _build_stairs(parts: Array[Dictionary]) -> void:
	var steps := 5
	var rise := (Layout.FLOOR_Y - 19.02) / float(steps)
	var run := (Layout.STAIR_Z1 - Layout.STAIR_Z0) / float(steps)
	for i: int in steps:
		var top: float = 19.02 + rise * float(i + 1)
		var z: float = Layout.STAIR_Z0 + run * (float(i) + 0.5)
		parts.append(Art.box(Vector3(0.0, top - 0.075, z),
			Vector3(Layout.STAIR_W, 0.15, run - 0.01),
			Color(0.36, 0.235, 0.135).lightened(0.018 * float(i))))
	# A pair of stringers under the treads, so the stair reads as carpentry.
	for side: float in [-1.0, 1.0]:
		parts.append(Art.beam(
			Vector3(side * (Layout.STAIR_W * 0.5 - 0.10), 19.06, Layout.STAIR_Z0 - 0.05),
			Vector3(side * (Layout.STAIR_W * 0.5 - 0.10), 19.94, Layout.STAIR_Z1 + 0.05),
			0.14, 0.18, Color(0.31, 0.20, 0.115)))


func _build_frame(parts: Array[Dictionary], iron: Array[Dictionary]) -> void:
	for x: float in [-2.92, -1.02, 1.02, 2.92]:
		parts.append(Art.box(Vector3(x, Layout.FLOOR_Y - 0.24, (Layout.Z_IN + Layout.Z_OUT) * 0.5),
			Vector3(0.24, 0.22, Layout.Z_OUT - Layout.Z_IN), Color(0.33, 0.215, 0.12)))
	for z: float in [Layout.Z_IN + 0.20, 70.55, Layout.Z_OUT - 0.20]:
		parts.append(Art.box(Vector3(0.0, Layout.FLOOR_Y - 0.25, z),
			Vector3(Layout.HALF_W * 2.0, 0.22, 0.24), Color(0.34, 0.22, 0.125)))
	# A deep fascia and visible knee braces close the dark gap under the deck, so the
	# hoarding reads as a built gallery rather than a table floating over the gate.
	parts.append(Art.box(Vector3(0.0, Layout.FLOOR_Y - 0.18, Layout.Z_OUT - 0.06),
		Vector3(Layout.HALF_W * 2.0 + 0.10, 0.34, 0.14), Color(0.37, 0.24, 0.14)))
	for side: float in [-1.0, 1.0]:
		parts.append(Art.box(Vector3(side * (Layout.HALF_W - 0.05), Layout.FLOOR_Y - 0.18,
			(Layout.Z_IN + Layout.Z_OUT) * 0.5), Vector3(0.14, 0.34,
			Layout.Z_OUT - Layout.Z_IN), Color(0.37, 0.24, 0.14)))
	for x: float in [-2.70, -0.90, 0.90, 2.70]:
		parts.append(Art.beam(Vector3(x, Layout.FLOOR_Y - 0.42, Layout.Z_OUT - 1.55),
			Vector3(x, Layout.FLOOR_Y - 0.08, Layout.Z_OUT - 0.05), 0.17, 0.19,
			Color(0.32, 0.205, 0.12)))
	# Iron straps where the hoarding meets the wall.
	for x: float in [-2.92, 2.92]:
		iron.append(Art.box(Vector3(x, Layout.FLOOR_Y - 0.36, Layout.Z_IN + 0.12),
			Vector3(0.34, 0.10, 0.44), Color(0.24, 0.255, 0.28)))
		for bolt: int in 2:
			iron.append(Art.box(Vector3(x, Layout.FLOOR_Y - 0.28, Layout.Z_IN + 0.05
				+ float(bolt) * 0.16), Vector3(0.08, 0.08, 0.08), Color(0.33, 0.34, 0.36)))


func _build_parapets(parts: Array[Dictionary], iron: Array[Dictionary]) -> void:
	var top: float = Layout.FLOOR_Y + Layout.PARAPET_H
	# Outer edge, with a real gap for the oil spout. The gap is wider than the pot so
	# the cauldron can overhang it without touching the posts.
	for segment: Vector2 in [Vector2(-Layout.HALF_W, -2.85), Vector2(-0.85, Layout.HALF_W)]:
		var length: float = segment.y - segment.x
		if length <= 0.05:
			continue
		parts.append(Art.box(Vector3((segment.x + segment.y) * 0.5,
			Layout.FLOOR_Y + Layout.PARAPET_H * 0.5, Layout.Z_OUT),
			Vector3(length, Layout.PARAPET_H, 0.16), Color(0.34, 0.225, 0.13)))
		parts.append(Art.box(Vector3((segment.x + segment.y) * 0.5, top + 0.045,
			Layout.Z_OUT), Vector3(length, 0.09, 0.27), Color(0.39, 0.26, 0.155)))
	# Side rails and the courtyard-side return, leaving the stair mouth open.
	for side: float in [-1.0, 1.0]:
		parts.append(Art.box(Vector3(side * Layout.HALF_W,
			Layout.FLOOR_Y + Layout.PARAPET_H * 0.5, (Layout.Z_IN + Layout.Z_OUT) * 0.5),
			Vector3(0.15, Layout.PARAPET_H, Layout.Z_OUT - Layout.Z_IN),
			Color(0.335, 0.22, 0.128)))
		parts.append(Art.box(Vector3(side * Layout.HALF_W, top + 0.045,
			(Layout.Z_IN + Layout.Z_OUT) * 0.5), Vector3(0.26, 0.08, Layout.Z_OUT - Layout.Z_IN),
			Color(0.39, 0.26, 0.155)))
	# The courtyard-side return on the cauldron half is only a low curb: the pot is
	# pushed from there, and a waist-high rail would stand between the player and it.
	parts.append(Art.box(Vector3((-Layout.HALF_W - 1.30) * 0.5, Layout.FLOOR_Y + 0.09,
		Layout.Z_IN), Vector3(Layout.HALF_W - 1.30, 0.18, 0.13),
		Color(0.34, 0.225, 0.13)))
	parts.append(Art.box(Vector3((1.30 + Layout.HALF_W) * 0.5,
		Layout.FLOOR_Y + Layout.PARAPET_H * 0.5, Layout.Z_IN),
		Vector3(Layout.HALF_W - 1.30, Layout.PARAPET_H, 0.14),
		Color(0.335, 0.22, 0.128)))
	# Posts at the corners and at the oil gap, with iron caps.
	var posts: Array[Vector2] = [Vector2(-Layout.HALF_W, Layout.Z_IN),
		Vector2(Layout.HALF_W, Layout.Z_IN), Vector2(-Layout.HALF_W, Layout.Z_OUT),
		Vector2(Layout.HALF_W, Layout.Z_OUT), Vector2(-2.85, Layout.Z_OUT),
		Vector2(-0.85, Layout.Z_OUT)]
	for post: Vector2 in posts:
		parts.append(Art.box(Vector3(post.x, Layout.FLOOR_Y + 0.62, post.y),
			Vector3(0.18, 1.24, 0.18), Color(0.30, 0.19, 0.11)))
		iron.append(Art.box(Vector3(post.x, Layout.FLOOR_Y + 1.26, post.y),
			Vector3(0.24, 0.08, 0.24), Color(0.27, 0.285, 0.31)))


func _build_corbels(parts: Array[Dictionary], iron: Array[Dictionary]) -> void:
	# Long brackets from the gatehouse face carry the cantilevered front edge. They
	# pass through the old pediment, where they are hidden inside the masonry.
	for x: float in [-2.70, -0.90, 0.90, 2.70]:
		parts.append(Art.beam(Vector3(x, 18.55, 68.62), Vector3(x, 19.76, 71.55),
			0.26, 0.28, Color(0.30, 0.19, 0.11)))
		iron.append(Art.box(Vector3(x, 18.66, 68.72), Vector3(0.34, 0.12, 0.34),
			Color(0.26, 0.275, 0.30)))
	# Cross-bracing between the brackets, visible from below.
	for pair: int in 3:
		var z: float = 69.5 + float(pair) * 0.75
		var t: float = (z - 68.62) / (71.55 - 68.62)
		var y: float = lerpf(18.55, 19.76, t)
		parts.append(Art.box(Vector3(0.0, y - 0.05, z), Vector3(5.4, 0.12, 0.12),
			Color(0.31, 0.20, 0.115)))


func _build_spout(stone: Array[Dictionary]) -> void:
	var x: float = Layout.OIL_SPOUT.x
	var z: float = Layout.Z_OUT + 0.26
	stone.append(Art.box(Vector3(x, Layout.FLOOR_Y + 0.40, z),
		Vector3(0.78, 0.14, 0.62), Color(0.55, 0.53, 0.48), Vector3(0.16, 0.0, 0.0)))
	for side: float in [-1.0, 1.0]:
		stone.append(Art.box(Vector3(x + side * 0.34, Layout.FLOOR_Y + 0.54, z),
			Vector3(0.12, 0.22, 0.62), Color(0.60, 0.58, 0.52)))
	stone.append(Art.box(Vector3(x, Layout.FLOOR_Y + 0.64, Layout.Z_OUT + 0.02),
		Vector3(0.78, 0.14, 0.18), Color(0.57, 0.55, 0.50)))


## ------------------------------------------------------------------ collision

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GalleryCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var top: float = Layout.FLOOR_Y - Layout.DECK * 0.5
	var hatch_min := Layout.HATCH_CENTRE.x - Layout.HATCH_HALF.x
	var hatch_max := Layout.HATCH_CENTRE.x + Layout.HATCH_HALF.x
	var hatch_z_min := Layout.HATCH_CENTRE.z - Layout.HATCH_HALF.y
	var hatch_z_max := Layout.HATCH_CENTRE.z + Layout.HATCH_HALF.y
	# Four floor slabs around the hatch opening: the hole must be walkable-through
	# when the flaps are open, and the rest of the deck must not.
	_add_box_shape(body, Vector3((-Layout.HALF_W + hatch_min) * 0.5, top,
		(Layout.Z_IN + Layout.Z_OUT) * 0.5),
		Vector3(hatch_min + Layout.HALF_W, Layout.DECK, Layout.Z_OUT - Layout.Z_IN))
	_add_box_shape(body, Vector3((hatch_max + Layout.HALF_W) * 0.5, top,
		(Layout.Z_IN + Layout.Z_OUT) * 0.5),
		Vector3(Layout.HALF_W - hatch_max, Layout.DECK, Layout.Z_OUT - Layout.Z_IN))
	_add_box_shape(body, Vector3(Layout.HATCH_CENTRE.x, top,
		(Layout.Z_IN + hatch_z_min) * 0.5),
		Vector3(hatch_max - hatch_min, Layout.DECK, hatch_z_min - Layout.Z_IN))
	_add_box_shape(body, Vector3(Layout.HATCH_CENTRE.x, top,
		(hatch_z_max + Layout.Z_OUT) * 0.5),
		Vector3(hatch_max - hatch_min, Layout.DECK, Layout.Z_OUT - hatch_z_max))
	# Stair ramp: a smooth collider under visual treads, the same trick the castle
	# stairs use. A box rotated about X is a ramp a character cannot catch a toe on.
	var ramp := StaticBody3D.new()
	ramp.name = "GalleryStairRamp"
	ramp.collision_layer = 1
	ramp.collision_mask = 1
	add_child(ramp)
	var run := Layout.STAIR_Z1 - Layout.STAIR_Z0
	var rise := Layout.FLOOR_Y - 19.02
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(Layout.STAIR_W, 0.10, sqrt(run * run + rise * rise))
	ramp_shape.shape = ramp_box
	ramp_shape.position = Vector3(0.0, (19.02 + Layout.FLOOR_Y) * 0.5 - 0.05,
		(Layout.STAIR_Z0 + Layout.STAIR_Z1) * 0.5)
	ramp_shape.rotation.x = -atan2(rise, run)
	ramp.add_child(ramp_shape)
	# Parapets and side rails are solid, so the player cannot walk off the hoarding.
	for segment: Vector2 in [Vector2(-Layout.HALF_W, -2.85), Vector2(-0.85, Layout.HALF_W)]:
		var length: float = segment.y - segment.x
		_add_box_shape(body, Vector3((segment.x + segment.y) * 0.5,
			Layout.FLOOR_Y + Layout.PARAPET_H * 0.5, Layout.Z_OUT),
			Vector3(length, Layout.PARAPET_H, 0.18))
	for side: float in [-1.0, 1.0]:
		_add_box_shape(body, Vector3(side * Layout.HALF_W,
			Layout.FLOOR_Y + Layout.PARAPET_H * 0.5, (Layout.Z_IN + Layout.Z_OUT) * 0.5),
			Vector3(0.17, Layout.PARAPET_H, Layout.Z_OUT - Layout.Z_IN))
	_add_box_shape(body, Vector3((-Layout.HALF_W - 1.30) * 0.5, Layout.FLOOR_Y + 0.09,
		Layout.Z_IN), Vector3(Layout.HALF_W - 1.30, 0.18, 0.15))
	_add_box_shape(body, Vector3((1.30 + Layout.HALF_W) * 0.5,
		Layout.FLOOR_Y + Layout.PARAPET_H * 0.5, Layout.Z_IN),
		Vector3(Layout.HALF_W - 1.30, Layout.PARAPET_H, 0.16))


func _add_box_shape(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


## ------------------------------------------------------------------ signs

func _build_labels(_cold: Material) -> void:
	_label("МАСЛО", Vector3(-Layout.HALF_W + 0.13, Layout.FLOOR_Y + 0.62, 70.40),
		Color(0.90, 0.72, 0.40), 54, PI * 0.5)
	_label("КАМНИ", Vector3(Layout.HALF_W - 0.13, Layout.FLOOR_Y + 0.62, 70.40),
		Color(0.82, 0.78, 0.66), 54, -PI * 0.5)


func _label(text: String, at: Vector3, color: Color, size: int = 54,
		yaw: float = PI) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0030
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.10, 0.075, 0.045, 0.95)
	label.double_sided = true
	label.no_depth_test = false
	label.position = at
	label.rotation.y = yaw
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
