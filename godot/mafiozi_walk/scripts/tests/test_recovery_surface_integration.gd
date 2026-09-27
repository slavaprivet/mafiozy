extends SceneTree
const Player = preload("res://scripts/preview_player.gd")
const Driver = preload("res://scripts/character_physics/character_physics_driver.gd")
var checks := 0
var failures: Array[String] = []
var floor_height := 0.0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func floor_y(_x: float, _z: float) -> float: return floor_height
func make_box(parent: Node3D, size: Vector3, transform: Transform3D) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = size
	node.shape = shape; node.transform = transform; parent.add_child(node)
	return node
func run() -> void:
	var fixtures: Array = FileAccess.open("res://scripts/tests/fixtures/recovery_surface_bounds.bin", FileAccess.READ).get_var()
	var world := Node3D.new(); root.add_child(world)
	var player := Player.new(); root.add_child(player); player.set_physics_process(false)
	var driver := Driver.new(); check(driver.configure(player, world).get("ok", false), "actual driver configured")
	var car := StaticBody3D.new(); root.add_child(car)
	var car_shape := make_box(car, Vector3.ONE, Transform3D.IDENTITY)
	var floor_body := StaticBody3D.new(); root.add_child(floor_body)
	make_box(floor_body, Vector3(200,.2,200), Transform3D(Basis.IDENTITY,Vector3(0,-.1,0)))
	var refined_count := 0
	var costs: Array[int] = []
	for index in fixtures.size():
		var fixture: Dictionary = fixtures[index]
		floor_height = fixture.support_y
		player._pose_motion.get_parent().global_transform = fixture.world
		car_shape.transform = fixture.box_transform; car_shape.shape.size = fixture.box_size
		driver._getup_to = Vector3(0, floor_height+.003, 0)
		driver._accepted_recovery_pose = fixture.previous
		# Produce the real prepared cache through its public sampler, at an
		# infinitesimal continuation of the captured proposed pose.
		var next: Dictionary = driver._pose.standing_blend(fixture.proposed,.000001,floor_y,fixture.proposed.authority_epoch)
		check(next.get("valid", false), "real next cache "+str(index))
		var previous_skin: Dictionary = driver._clearance.snapshot(fixture.previous,fixture.world,false)
		var next_skin: Dictionary = driver._clearance.snapshot(next,fixture.world)
		var sweep: Dictionary = driver._clearance.between(previous_skin,next_skin)
		await physics_frame; await physics_frame
		check(driver._verified_box_shapes(car).size()==1, "actual server/node shape identity "+str(index))
		var before: Array[RID] = driver._recovery_query.exclude.duplicate()
		var broad: bool = driver._recovery_path_clear(sweep)
		var started := Time.get_ticks_usec()
		var refined: bool = driver._refined_recovery_path_clear(sweep,next)
		costs.append(Time.get_ticks_usec()-started)
		if -float(fixture.continuous_plane_upper_bound) > .001:
			check(broad or refined, "separated complete world path "+str(index))
		else:
			check(not broad and not refined, "sub-millimetre clearance retains margin "+str(index))
		check(driver._recovery_query.exclude==before, "exclusions restored "+str(index))
		if not broad and refined: refined_count += 1
		if index != 1: continue
		# A second real shape on the same body occupies the skin. Proving the
		# original car box is free must not remove this compound obstruction.
		var wall := make_box(car,Vector3(.4,2,.4),Transform3D(Basis.IDENTITY,next_skin.bounds.get_center()))
		await physics_frame; await physics_frame
		check(driver._verified_box_shapes(car).size()==2, "compound has two server shapes")
		check(not driver._refined_recovery_path_clear(sweep,next), "compound obstacle retained")
		check(driver._recovery_query.exclude==before, "compound rejection restores exclusions")
		wall.free()
		var unknown := StaticBody3D.new(); root.add_child(unknown)
		var sphere := CollisionShape3D.new(); sphere.shape=SphereShape3D.new(); sphere.shape.radius=.4
		unknown.add_child(sphere); sphere.global_position=next_skin.bounds.get_center()
		await physics_frame; await physics_frame
		check(driver._verified_box_shapes(unknown).is_empty(), "unknown shape cannot receive box proof")
		check(not driver._refined_recovery_path_clear(sweep,next), "unknown obstacle remains in world guard")
		check(driver._recovery_query.exclude==before, "unknown rejection restores exclusions")
		unknown.free()
		await physics_frame; await physics_frame
	check(refined_count>0,"at least one original false obstruction removed")
	costs.sort()
	print("RECOVERY_SURFACE_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures,"refined_cases":refined_count,"cpu_us":costs,"scope":"Actual player/native server/world guard and captured poses; no GPU/FPS claim"}))
	driver.dispose(); car.free(); floor_body.free(); player.free(); world.free()
	quit(0 if failures.is_empty() else 1)
