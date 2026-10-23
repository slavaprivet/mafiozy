extends SceneTree
## Actual imported hero writer/lifecycle proof; no target or damage authority.
const Player = preload("res://scripts/preview_player.gd")
var checks := 0
var failures: Array[String] = []
var player: CharacterBody3D
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func receipt() -> Dictionary: return player.get_meta(&"melee_skin_pose", {})
func capture() -> Array[Transform3D]:
	var frames: Array[Transform3D] = []
	for bone in player._pose_skeleton.get_bone_count(): frames.append(player._pose_skeleton.get_bone_global_pose(bone))
	return frames
func change_owner(_delta: float, selected: Dictionary) -> Dictionary:
	player.set_preview_pose_authority(&"vehicle")
	return selected
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	player = Player.new(); world.add_child(player); player.set_physics_process(false)
	var base := {"valid":true,"poses":player._locomotion._rest_poses.duplicate(),"visual_offset":Vector3.ZERO,"visual_rotation":Quaternion.IDENTITY}
	check(player._apply_selected_pose(base), "unregistered visual writer still works")
	check(receipt().is_empty(), "no invented identity")
	player.set_meta("actor_id", "player"); player.set_meta("life_generation", 1)
	check(player._apply_selected_pose(base), "registered writer works")
	var first := receipt()
	check(first.size()==5 and first.actor_id=="player" and first.life_generation==1 and first.pose_owner=="on_foot", "actual identity receipt")
	check(first.is_read_only() and first.pose_revision==player._pose_revision and first.pose_epoch==player._pose_epoch, "immutable completed revision")
	player._apply_selected_pose(base)
	check(receipt().pose_revision==first.pose_revision+1 and first.pose_revision!=receipt().pose_revision, "monotonic revision, retained receipt unchanged")
	var before := capture(); var revision: int = player._pose_revision
	for kind in ["missing", "count", "nan", "offset", "rotation", "invalid"]:
		var bad: Dictionary=base.duplicate(true)
		match kind:
			"missing": bad.erase("poses")
			"count": bad.poses.pop_back()
			"nan": bad.poses[12]=Transform3D(Basis.IDENTITY,Vector3(NAN,0,0))
			"offset": bad.visual_offset=Vector3(INF,0,0)
			"rotation": bad.visual_rotation=Quaternion(0,0,0,0)
			"invalid": bad.valid=false
		check(not player._apply_selected_pose(bad),kind+": rejected")
		check(capture()==before and player._pose_revision==revision,kind+": no partial bone write")
		check(receipt().is_empty(),kind+": no stale receipt")
	player._apply_selected_pose(base)
	var epoch: int=player._pose_epoch
	player.set_preview_pose_authority(&"vehicle")
	check(receipt().is_empty() and player._pose_epoch==epoch+1,"handoff invalidates before external writer")
	check(not player._apply_selected_pose(base,epoch),"old selected pose rejected after handoff")
	player._apply_selected_pose(base)
	check(receipt().is_empty(),"external writer not represented as on-foot receipt")
	player.set_preview_pose_authority(&"on_foot")
	player._apply_selected_pose(base)
	player.set_preview_pose_authority(&"on_foot",true)
	check(receipt().is_empty(),"same-owner new lifetime invalidates")
	player.set_meta("life_generation",2);player._apply_selected_pose(base)
	check(receipt().life_generation==2 and receipt().pose_revision>first.pose_revision,"new life copied from actual identity")
	check(player.set_hit_pose_decorator(change_owner),"ownership-changing decorator registered")
	before=capture();revision=player._pose_revision
	player._update_owned_pose(1.0/60.0)
	check(player._pose_authority==&"vehicle" and receipt().is_empty() and revision==player._pose_revision and capture()==before,"decorator handoff cannot be overwritten by stale selected pose")
	player.set_hit_pose_decorator(Callable())
	player.set_preview_pose_authority(&"on_foot")
	player._apply_selected_pose(base)
	world.remove_child(player)
	check(receipt().is_empty(),"exit invalidates receipt")
	world.add_child(player); player.set_physics_process(false)
	player._apply_selected_pose(base)
	world.queue_free()
	check(not player._apply_selected_pose(base) and receipt().is_empty(),"queued ancestor rejected")
	print("MELEE_POSE_RECEIPT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual hero writer, malformed pose atomicity and ownership/lifetime; headless, no gameplay hit claim"}))
	quit(0 if failures.is_empty() else 1)
