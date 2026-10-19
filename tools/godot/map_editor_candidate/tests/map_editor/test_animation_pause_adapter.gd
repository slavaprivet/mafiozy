extends SceneTree
const Adapter = preload("res://scripts/map_editor/animation_pause_adapter.gd")
var failures: Array = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func fixture(world: Node3D, active: bool) -> Dictionary:
	var target := Node3D.new()
	target.name = "AnimatedTarget%d" % world.get_child_count()
	world.add_child(target)
	var player := AnimationPlayer.new()
	world.add_child(player)
	player.set_meta("source_id", target.name)
	player.set_meta("life_generation", 2)
	var animation := Animation.new()
	animation.length = 2
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(str(target.name) + ":position"))
	animation.track_insert_key(track, 0, Vector3.ZERO)
	animation.track_insert_key(track, 2, Vector3(4, 0, 0))
	var library := AnimationLibrary.new()
	library.add_animation("walk", animation)
	library.add_animation("queued", animation.duplicate())
	player.add_animation_library("source", library)
	player.speed_scale = 1.7
	player.play("source/walk", -1, 0.6)
	player.queue("source/queued")
	player.advance(0.31)
	player.active = active
	return {"player": player, "target": target, "animation": animation, "descriptor": {"mixer": player, "identity": {"source_id": target.name, "life_generation": 2}, "pose_targets": [{"node": target, "properties": ["transform"]}]}}
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var a := fixture(world, true)
	var b := fixture(world, false)
	var adapter := Adapter.new()
	check(adapter.configure(world, [a.descriptor, b.descriptor]).ok, "Explicit native AnimationPlayer/Mixer inventories admitted")
	var phase: float = a.player.current_animation_position
	var pose: Transform3D = a.target.transform
	var playing: bool = a.player.is_playing()
	var speed: float = a.player.get_playing_speed()
	var queue: Array = a.player.get_queue().duplicate()
	check(adapter.pause().ok and adapter.verify(), "Native active=false freezes playback without stop/play/seek")
	for i in 10: await process_frame
	check(a.player.current_animation_position == phase and a.target.transform == pose and a.player.is_playing() == playing, "Native playback phase and current pose do not drift across engine frames")
	check(a.player.get_playing_speed() == speed and a.player.get_queue() == queue and a.player.current_animation == "source/walk", "Speed/current animation/queue retained")
	check(adapter.restore().ok and a.player.active and not b.player.active, "Exact initially-active/inactive states restored")
	check(a.player.current_animation_position == phase and a.target.transform == pose, "Restore does not restart or seek current pose")
	for i in 3: await process_frame
	check(a.player.current_animation_position > phase, "Real native clock resumes at held phase")
	check(adapter.pause().ok, "Second native animation lease captured")
	a.player.set_meta("life_generation", 99)
	check(not adapter.verify() and not adapter.restore().ok and not a.player.active and not b.player.active, "Lifetime change retains paused animation and refuses success")
	a.player.set_meta("life_generation", 2)
	check(adapter.restore().ok, "Owner identity repair permits exact phase restore")
	check(adapter.pause().ok, "Explicit pose-owner parent checkpoint captured")
	var pose_parent: Node = a.target.get_parent()
	var other := Node3D.new()
	world.add_child(other)
	a.target.reparent(other)
	check(not adapter.verify() and not adapter.restore().ok and not a.player.active, "Reparented pose ownership cannot silently resume animation")
	a.target.reparent(pose_parent)
	check(adapter.restore().ok, "Actual pose target ownership repair restores exact native phase")
	check(not ClassDB.can_instantiate("AnimationMixer"), "Abstract AnimationMixer API proved through concrete native AnimationPlayer, not fake base instance")
	check(adapter.pause().ok, "Resource mutation guard lease captured")
	a.animation.track_set_key_value(0, 1, Vector3(9, 0, 0))
	check(not adapter.verify() and not adapter.restore().ok and adapter.state().resource_changed and not a.player.active, "Changing owned animation resource cannot be hidden as preserved visuals")
	var tree := AnimationTree.new()
	world.add_child(tree)
	check(not Adapter.new().configure(world, [{"mixer": tree}]).ok, "Unapproved AnimationTree state machine is not blindly frozen")
	world.free()
	print(JSON.stringify({"suite": "animation-pause-adapter", "checks": checks, "failures": failures, "gpu": false}))
	quit(0 if failures.is_empty() else 1)
