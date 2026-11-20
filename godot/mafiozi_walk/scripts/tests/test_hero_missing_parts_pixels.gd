extends SceneTree
## Render the actual HUD diagram and verify that missing anatomy leaves a gap.

const HudScript = preload("res://scripts/character/hero_vitals_hud.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(72, 104)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var diagram: Control = HudScript.BodyDiagram.new()
	viewport.add_child(diagram)
	var whole := {"head": {"health": 1.0, "severed": false},
		"hand_l": {"health": 1.0, "severed": false},
		"upperarm_r": {"health": 1.0, "severed": false},
		"forearm_r": {"health": 1.0, "severed": false},
		"hand_r": {"health": 1.0, "severed": false}}
	diagram.call("set_state", whole, false, {})
	await process_frame
	await process_frame
	var before := viewport.get_texture().get_image()
	var healthy := before.get_pixel(36, 17).a > 0.5 \
		and before.get_pixel(13, 63).a > 0.5 \
		and before.get_pixel(53, 38).a > 0.5
	var lost := whole.duplicate(true)
	lost.head.severed = true
	lost.hand_l.severed = true
	lost.hand_l.bleeding = true
	lost.upperarm_r.severed = true
	# The authority can report only the proximal cut; distal pieces still vanish.
	diagram.call("set_state", lost, false, {"hands": "heavy", "torso": "heavy"})
	await process_frame
	await process_frame
	var after := viewport.get_texture().get_image()
	var absent := after.get_pixel(36, 17).a < 0.05 \
		and after.get_pixel(13, 63).a < 0.05 \
		and after.get_pixel(53, 38).a < 0.05 \
		and after.get_pixel(59, 63).a < 0.05 \
		and after.get_pixel(8, 63).a < 0.05
	var stump := after.get_pixel(36, 26).a > 0.5
	print("HERO_MISSING_PARTS_PIXELS ", "PASS" if healthy and absent and stump else "FAIL",
		" healthy=", healthy, " absent=", absent, " stump=", stump)
	quit(0 if healthy and absent and stump else 1)
