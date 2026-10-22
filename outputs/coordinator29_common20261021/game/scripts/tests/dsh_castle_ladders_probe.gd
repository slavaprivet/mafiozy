extends SceneTree
## Wall-ladder probe: the four assault ladders must be climbable with W/S, must feed
## the existing crawl pose, and must lose individual pieces when a siege projectile
## lands on them.

var _game: Node
var _castle: Node3D
var _player: CharacterBody3D
var _dressing: Node3D
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(name: String, value: bool, detail: Variant = "") -> void:
	if not value:
		_failures.append(name + " " + str(detail))
	print("LADDER_CHECK ", name, " ", value, " ", detail)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and _game.get("preview_ready") != true:
		await process_frame
	_castle = _game.get("preview_castle") as Node3D
	_player = _game.get("_player") as CharacterBody3D
	# The castle's spawn guard owns the player for its first frames; the probe moves
	# him to the ladder before that lease ends.
	_game.set("_castle_spawn_frames", 0)
	# The ship installs after the castle and puts the player on its deck once. Wait for
	# that startup lease to end before taking the body to the wall.
	for i: int in 240:
		await physics_frame
	var field: Node3D = _game.get("preview_battlefield") as Node3D
	_dressing = field.get_node_or_null("SiegeWallDressing") as Node3D if field != null else null
	_check("dressing", _dressing != null)
	if _dressing == null:
		_report()
		return
	var stats: Dictionary = _dressing.call("get_stats")
	_check("four_ladders", int(stats.get("ladders", 0)) == 4, stats)
	# Foot of the west ladder.
	var foot := _dressing.to_global(Vector3(-38.0, 0.25, 74.15))
	_player.global_position = foot
	_player.velocity = Vector3.ZERO
	_dressing.call("debug_climb_axis", 1.0)
	_player.set_physics_process(false)
	for i: int in 760:
		_dressing.call("climb_assist", _player, 1.0 / 60.0)
	_dressing.call("debug_climb_axis", 0.0)
	_dressing.call("climb_assist", _player, 1.0 / 60.0)
	_player.set_physics_process(true)
	var top_position := _player.global_position
	_check("climb_reached_top", top_position.y > 18.8, top_position)
	_check("climb_step_onto_wall", absf(_dressing.to_local(top_position).z - 68.80) < 0.6,
		_dressing.to_local(top_position))
	var lift: Dictionary = _dressing.call("ladder_status")
	_check("climb_released_at_top", not bool(lift.get("climbing", true)), lift)
	# Descend from the wall head.
	_player.global_position = _dressing.to_global(Vector3(-38.0, 19.02, 68.80))
	_dressing.call("debug_climb_axis", -1.0)
	_player.set_physics_process(false)
	for i: int in 760:
		_dressing.call("climb_assist", _player, 1.0 / 60.0)
	_dressing.call("debug_climb_axis", 0.0)
	_dressing.call("climb_assist", _player, 1.0 / 60.0)
	_player.set_physics_process(true)
	var bottom_position := _player.global_position
	_check("climb_descended", bottom_position.y < 0.4, bottom_position)
	_check("climb_released_at_bottom", bottom_position.z > 73.5, bottom_position)
	# A siege hit takes rungs locally, not the whole ladder at once.
	var hit_at := _dressing.to_global(Vector3(-38.0, 10.5, 71.6))
	var first: int = int(_dressing.call("apply_damage", hit_at, 2.6, 85.0, 62.0))
	var status_after_first: Dictionary = _dressing.call("ladder_status")
	var rows: Dictionary = status_after_first.get("rows", {})
	var row: Dictionary = rows.get("ladder_-38", {})
	_check("first_hit_damages_ladder", first == 1, status_after_first)
	_check("first_hit_breaks_parts", int(row.get("alive", 99)) < int(row.get("parts", 0)),
		status_after_first)
	_check("damaged_ladder_not_climbable",
		not bool(_dressing.call("ladder_climbable", "ladder_-38")), status_after_first)
	var alive_after_first := int(row.get("alive", 0))
	var second: int = int(_dressing.call("apply_damage",
		_dressing.to_global(Vector3(-38.0, 13.5, 70.2)), 2.6, 85.0, 62.0))
	var rows_second: Dictionary = (_dressing.call("ladder_status") as Dictionary).get("rows", {})
	var row_second: Dictionary = rows_second.get("ladder_-38", {})
	_check("second_hit_breaks_more_parts", int(row_second.get("alive", 99)) < alive_after_first,
		row_second)
	_check("second_hit_not_new_group", second == 0, second)
	var shards: int = int(_dressing.get("_shards").size()) if _dressing.get("_shards") != null else 0
	_check("shards_spawned", shards > 0, shards)
	_report()


func _report() -> void:
	print("CASTLE_LADDERS ", JSON.stringify({"pass": _failures.is_empty(),
		"failures": _failures,
		"status": _dressing.call("ladder_status") if _dressing != null else {}}))
	quit(0 if _failures.is_empty() else 1)
