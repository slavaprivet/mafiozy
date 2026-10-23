extends SceneTree
## Independent native acceptance of the optional outer-wall siege dressing.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SIEGE_WALL_QA_FAIL scene")
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
	var wall: Node3D = field.get_node_or_null("SiegeWallDressing") as Node3D if field != null else null
	if castle == null or field == null or wall == null:
		print("SIEGE_WALL_QA_FAIL missing_scene_parts")
		quit(1)
		return
	var before: Dictionary = wall.call("get_stats")
	var meshes: int = 0
	var permanent_colliders: int = 0
	for node: Node in wall.find_children("*", "", true, false):
		if node is MultiMeshInstance3D:
			meshes += 1
		if node is CollisionObject3D:
			permanent_colliders += 1
	var groups: Dictionary = wall.get("_groups")
	var ladder: Dictionary = groups.get("ladder_21", {})
	var center: Vector3 = castle.global_position + Vector3(21.0, 10.0, 71.0)
	var broken_first: int = int(wall.call("apply_damage", center, 2.5, 100.0))
	var broken_second: int = int(wall.call("apply_damage", center, 2.5, 100.0))
	var shards: Array = wall.get("_shards")
	var shard_count: int = shards.size()
	var shard_start: Vector3 = (shards[0] as Node3D).global_position if shard_count > 0 else Vector3.ZERO
	for tick: int in 30:
		await physics_frame
	var shard_motion: float = (shards[0] as Node3D).global_position.distance_to(shard_start) if shard_count > 0 else 0.0
	var after: Dictionary = wall.call("get_stats")
	var passed: bool = int(before.get("ladders", 0)) == 4 \
		and int(before.get("arrows", 0)) == 66 and int(before.get("spears", 0)) == 4 \
		and int(before.get("broken_shields", 0)) == 6 \
		and int(before.get("impact_scars", 0)) == 6 \
		and int(before.get("batches", 0)) == 3 and meshes == 3 \
		and permanent_colliders == 0 and not ladder.is_empty() \
		and broken_first == 1 and broken_second == 0 \
		and int(after.get("broken_groups", 0)) == 1 \
		and shard_count == 4 and shard_motion > 0.05
	print("SIEGE_WALL_QA ", JSON.stringify({"pass": passed,
		"before": before, "after": after, "meshes": meshes,
		"permanent_colliders": permanent_colliders,
		"broken_first": broken_first, "broken_second": broken_second,
		"shard_count": shard_count, "shard_motion": shard_motion,
		"ladder_21_parts": (ladder.get("indices", []) as Array).size()}))
	current_scene = null
	game.queue_free()
	packed = null
	for tick: int in 18:
		await process_frame
	quit(0 if passed else 1)
