extends SceneTree
const Inventory = preload("res://terrain_inventory.gd")
var failures: Array[String] = []
var checks := 0
var report := {}
func _initialize() -> void:
	run.call_deferred()
func require(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	if DisplayServer.get_name()!="headless": quit(2); return
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 240:
		await physics_frame
		if main.preview_ready: break
	require(main.preview_ready,"Actual original main ready")
	if not main.preview_ready: finish(); return
	var inventory := Inventory.new()
	var result: Dictionary = inventory.capture(main)
	require(result.ok,"Actual terrain capture: "+str(result.get("errors",result.get("report",{}).get("errors",[]))))
	if not result.ok: report=result.get("report",{}); finish(); return
	report = result.report
	checks += int(report.checks)
	require(not report.editor_adoption_ready and not report.navigation_accepted and not report.gpu,"Inventory cannot approve editing/navigation/GPU")
	require(report.source_water_cells==303 and report.water.cell_count==303,"Actual original water303 cells")
	var actual_instances := 0
	for group: Dictionary in report.groups:
		actual_instances += int(group.instance_count)
		if not group.actual_buffer_available:
			require(group.actual_buffer_sha=="UNAVAILABLE_DUMMY_RENDERER_NOT_PROOF","Unavailable native buffer explicitly not source evidence")
	require(actual_instances+report.water.cell_count==report.cells,"No missing/duplicate visual cell counts")
	require(report.uncertain_direct_bodies.is_empty(),"All direct native bodies classified without uncertainty")
	require(inventory.verify_snapshot(main,result.snapshot).ok,"Immediate readonly recapture exact node/resource identities")
	await physics_frame
	require(inventory.verify_snapshot(main,result.snapshot).ok,"Readonly after-yield exact original terrain/cache identities")
	# Negative fixtures alter only test-owned additions, never source nodes/resources.
	var body := StaticBody3D.new()
	body.name = "IsolatedUnmatchedBoxFixture"
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	body.add_child(collider)
	main.add_child(body)
	var negative: Dictionary = inventory.capture(main)
	require(not negative.ok and negative.report.uncertain_direct_bodies.size()==1,"New direct Box cannot silently become nonterrain")
	require(not inventory.verify_snapshot(main,result.snapshot).ok,"Snapshot rejects added direct body")
	main.remove_child(body)
	body.free()
	require(inventory.verify_snapshot(main,result.snapshot).ok,"Fixture removal leaves original identities unchanged")
	var wrong := StaticBody3D.new()
	wrong.name = "IsolatedMalformedBodyFixture"
	main.add_child(wrong)
	require(not inventory.capture(main).ok,"Malformed direct body cannot silently be ignored")
	main.remove_child(wrong)
	wrong.free()
	require(inventory.verify_snapshot(main,result.snapshot).ok,"Malformed fixture removal preserves source")
	var fake := StaticBody3D.new()
	fake.name = "IsolatedUntrustedConvexFixture"
	fake.set_meta("source_id",report.nonterrain_source_convex[0].source_id)
	fake.set_meta("source_index",report.nonterrain_source_convex[0].source_index)
	var fake_collider := CollisionShape3D.new()
	var fake_shape := ConvexPolygonShape3D.new()
	fake_shape.points = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK])
	fake_collider.shape = fake_shape
	fake.add_child(fake_collider)
	main.add_child(fake)
	require(not inventory.capture(main).ok,"Forged source metadata cannot classify unknown convex as nonterrain")
	main.remove_child(fake)
	fake.free()
	require(inventory.verify_snapshot(main,result.snapshot).ok,"Forged fixture removal preserves original resources")
	var other := Inventory.new()
	require(not other.verify_snapshot(main,result.snapshot).ok,"Snapshot issuer cannot be forged")
	var alternate_parent := Node3D.new()
	root.add_child(alternate_parent)
	main.reparent(alternate_parent)
	require(not inventory.verify_snapshot(main,result.snapshot).ok,"Isolated scene reparent invalidates original parent capsule")
	# Scene lifecycle negative: queue the isolated test scene only after all evidence.
	main.queue_free()
	require(not inventory.verify_snapshot(main,result.snapshot).ok,"Queued original scene lifetime rejected before deletion")
	# Reparent may invalidate gameplay-owner caches: no further gameplay ticks or
	# restoration promise. The inventory must not repair/resurrect those owners.
	main.free()
	alternate_parent.free()
	require(not inventory.verify_snapshot(null,result.snapshot).ok,"Destroyed scene snapshot rejected")
	finish()
func finish() -> void:
	var final := {"schema":"actual-terrain-native-inventory-test/v1","checks":checks,"failures":failures,"report":report,"gpu":false,"ready":false,"negative_fixtures":"Test-owned added malformed/unmatched bodies and isolated scene lifetime only"}
	var file := FileAccess.open("res://terrain_inventory_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(final,"\t",true,true))
	print(JSON.stringify({"checks":checks,"failures":failures,"groups":report.get("groups",[]).size(),"strips":report.get("strips",[]).size(),"water_cells":report.get("source_water_cells",0),"gpu":false,"ready":false}))
	quit(0 if failures.is_empty() else 1)
