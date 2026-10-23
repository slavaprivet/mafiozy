extends SceneTree
## A real catapult impact must reach the wall dressing before the castle branch.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SIEGE_IMPACT_QA_FAIL scene")
		quit(1)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	var deadline: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and game.get("preview_ready") != true:
		await process_frame
	var castle: Node3D = game.get("preview_castle") as Node3D
	var field: Node3D = game.get("preview_battlefield") as Node3D
	var catapult: Node = game.get("preview_catapult") as Node
	var wall: Node3D = field.get_node_or_null("SiegeWallDressing") as Node3D if field != null else null
	if castle == null or field == null or wall == null or catapult == null:
		print("SIEGE_IMPACT_QA_FAIL missing_scene_parts")
		quit(1)
		return
	var before: Dictionary = wall.call("get_stats")
	var target: Vector3 = castle.global_position + Vector3(21.0, 10.0, 71.0)
	catapult.call("_impact", {"position": target, "normal": Vector3.FORWARD})
	for tick: int in 30:
		await physics_frame
	var after: Dictionary = wall.call("get_stats")
	var shards: Array = wall.get("_shards")
	var impact: Dictionary = catapult.get("_last_impact")
	var passed: bool = int(before.get("broken_groups", 0)) == 0 \
		and int(after.get("broken_groups", 0)) == 1 \
		and shards.size() == 4 and bool(impact.get("castle", false))
	print("SIEGE_IMPACT_QA ", JSON.stringify({"pass": passed,
		"before": before.get("broken_groups", -1),
		"after": after.get("broken_groups", -1),
		"shards": shards.size(), "catapult_castle": impact.get("castle", false),
		"catapult_ok": impact.get("ok", false)}))
	current_scene = null
	game.queue_free()
	packed = null
	for tick: int in 18:
		await process_frame
	quit(0 if passed else 1)
