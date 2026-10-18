extends SceneTree
## Integrated assault-side ladders and live-merlon shields on one castle scene.
## Run in the graphical scheduler lane: headless MultiMesh transform readback is unavailable.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
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
	var defense: Node3D = castle.get_node_or_null("WallDefense24") as Node3D if castle != null else null
	if castle == null or field == null or wall == null or defense == null:
		print("BATTLEFIELD_COMBINED_FAIL missing_scene_parts")
		quit(1)
		return
	var wall_before: Dictionary = wall.call("get_stats")
	var defense_before: Dictionary = defense.call("get_stats")
	var anchors: Array = defense.get("_anchors")
	var anchor: Dictionary = anchors[0] if not anchors.is_empty() else {}
	var local_at: Vector3 = anchor.get("cell", {}).get("at", Vector3.ZERO)
	var blast: Dictionary = castle.call("apply_explosion", {"position": castle.to_global(local_at),
		"radius": 1.3, "power": 45.0, "direction": Vector3(0, 0, -1)})
	await create_timer(0.3).timeout
	var defense_after: Dictionary = defense.call("get_stats")
	var multi: MultiMesh = anchor.get("multi") as MultiMesh
	var hidden_transform: bool = multi != null and \
		absf(multi.get_instance_transform(int(anchor.get("slot", -1))).basis.determinant()) < 0.000001
	var broken_wall: int = int(wall.call("apply_damage",
		castle.global_position + Vector3(21, 10, 71), 2.5, 100.0))
	var shards: Array = wall.get("_shards")
	var wall_after: Dictionary = wall.call("get_stats")
	var passed: bool = int(wall_before.get("ladders", 0)) == 4 \
		and int(defense_before.get("shields", 0)) == 10 \
		and int(defense_before.get("batches", 0)) == 5 \
		and int(defense_before.get("physics_bodies", -1)) == 0 \
		and int(wall_before.get("colliders", -1)) == 0 \
		and bool(blast.get("ok", false)) \
		and not bool(anchor.get("cell", {}).get("alive", true)) \
		and int(defense_after.get("hidden", 0)) == 1 and hidden_transform \
		and broken_wall == 1 and int(wall_after.get("broken_groups", 0)) == 1 \
		and shards.size() == 4
	print("BATTLEFIELD_COMBINED ", JSON.stringify({"pass": passed,
		"wall_before": wall_before, "wall_after": wall_after,
		"defense_before": defense_before, "defense_after": defense_after,
		"blast_ok": blast.get("ok", false), "hidden_transform": hidden_transform,
		"broken_wall": broken_wall, "shards": shards.size()}))
	current_scene = null
	game.queue_free()
	packed = null
	for tick: int in 18:
		await process_frame
	quit(0 if passed else 1)
