extends SceneTree
const Candidate = preload("./printshop_placement.gd")
class Owner extends Node3D:
	var held := false
	var permit_commit := true
	var permit_rollback := true
	var permit_resume := true
	var partial_prepare := false
	var permit_unreceipted_repair := false
	var unknown_prepare := false
	var reenter_rollback := false
	var extension: Node
	var staged := {}
	var receipt: RefCounted
	func is_held() -> bool:
		if reenter_rollback: extension.rollback_placement(RefCounted.new())
		return held
	func prepare(request: Dictionary) -> Dictionary:
		staged = request.duplicate(true)
		receipt = RefCounted.new()
		if unknown_prepare: return {}
		return {"ok": not partial_prepare, "receipt": receipt}
	func validate(value: RefCounted, request: Dictionary) -> Dictionary: return {"ok": value == receipt and request == staged and held}
	func commit(value: RefCounted, request: Dictionary) -> Dictionary: return {"ok": value == receipt and request == staged and held and permit_commit}
	func rollback(value: RefCounted, request: Dictionary) -> Dictionary:
		if (value != receipt and not (value == null and permit_unreceipted_repair)) or request != staged or not permit_rollback: return {"ok": false}
		staged.clear()
		return {"ok": true}
	func can_resume(_delta: Transform3D) -> Dictionary: return {"ok": held and permit_resume}
	func adopt(source_id: String, frozen: Dictionary) -> Dictionary: return {"ok": source_id == Candidate.SOURCE_ID and frozen.is_read_only()}
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func vector(row: Array) -> Vector3: return Vector3(row[0],row[1],row[2])
func run() -> void:
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var building := {}
	for row: Dictionary in block.buildings:
		if row.id == Candidate.SOURCE_ID: building = row
	check(not building.is_empty(), "actual source printshop record")
	var owner := Owner.new()
	root.add_child(owner)
	var placement := Node3D.new()
	placement.set_meta("source_id", Candidate.SOURCE_ID)
	var parameters: Dictionary = building.transform
	placement.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(parameters.yawDegrees)) * Basis.from_scale(Vector3(parameters.uniformScale*parameters.horizontalScale[0],parameters.uniformScale,parameters.uniformScale*parameters.horizontalScale[1])),vector(building.positionLocalM))
	owner.add_child(placement)
	var asset: PackedScene = load(building.path)
	var visual: Node3D = asset.instantiate()
	visual.position = vector(parameters.modelLocalOffsetM)
	placement.add_child(visual)
	var interior := Candidate.new()
	owner.extension = interior
	owner.add_child(interior)
	check(interior.attach_existing(visual,building,data), "actual original interior attaches: " + str(interior.errors))
	if not interior.ready_for_use: owner.free(); quit(1); return
	var original_data := JSON.stringify(data,"",true,true)
	var original_frame := placement.global_transform
	var original_anchor: Vector3 = interior.anchor("publicApproach")
	var mesh_ids := {}
	for key in interior._mesh_cache: mesh_ids[key] = interior._mesh_cache[key].get_instance_id()
	var shape_ids: Array[int] = []
	for node in interior.find_children("*","CollisionShape3D",true,false): shape_ids.append(node.shape.get_instance_id())
	var callbacks := {"held": owner.is_held, "prepare": owner.prepare, "validate": owner.validate, "commit": owner.commit, "rollback": owner.rollback, "can_resume": owner.can_resume}
	check(interior.configure_placement_owner(owner,placement,callbacks).ok, "explicit source owner bound")
	check(not interior.rollback_placement(RefCounted.new()).ok and not interior.placement_state().retained, "forged rollback cannot retain an idle source")
	check(interior._unsupported_multimesh and not interior._live() and not interior.begin_editor_placement().ok, "actual source MultiMesh has no native storage admission; default HOLD")
	# TEST-ONLY: exercise transaction/control branches after recording the actual
	# negative gate. This does NOT prove MultiMesh storage or admit this scene.
	interior._unsupported_multimesh = false
	var old_guard: Array[int] = []
	for i in 7:
		var started := Time.get_ticks_usec()
		check(interior._live(), "exact unfrozen source guard")
		old_guard.append(Time.get_ticks_usec()-started)
	check(interior.adopt_immutable_source_descriptor(owner.adopt).ok, "explicit source owner adopts exact immutable copy")
	check(interior._data.is_read_only() and interior._data.doors.public.is_read_only() and interior._data.meshes.is_read_only() and not data.is_read_only(), "recursive source freeze never mutates borrowed main data")
	var new_guard: Array[int] = []
	for i in 7:
		var started := Time.get_ticks_usec()
		check(interior._live(), "same exact source guard after readonly adoption")
		new_guard.append(Time.get_ticks_usec()-started)
	check(not interior.begin_editor_placement().ok, "no fabricated paused lease")
	owner.held = true
	check(interior.begin_editor_placement().ok, "fixture paused lease begins")
	check(not interior.request_door("public",true,interior.anchor("publicApproach"),[]).accepted, "door input held")
	var fraction: float = interior.door_fraction("public")
	interior.advance(0.1,[])
	check(interior.door_fraction("public") == fraction, "door animation held without reset")
	check(not interior.prepare_placement(Transform3D(Basis.from_scale(Vector3(2,1,1)),Vector3.ZERO)).ok, "capsule scale reinterpretation refused")
	check(not interior.prepare_placement(Transform3D(Basis(Vector3.RIGHT,0.3),Vector3.ZERO)).ok, "non-upright placement refused")
	var delta := Transform3D(Basis(Vector3.UP,0.7),Vector3(30,0,-15))
	var prepared: Dictionary = interior.prepare_placement(delta * original_frame)
	check(prepared.ok, "rigid transformed source placement prepared")
	if not prepared.ok:
		print(JSON.stringify({"earlyFailures": failures, "prepare": prepared, "unsupportedMultimesh": interior._unsupported_multimesh, "poisoned": interior._poisoned}))
		owner.free()
		quit(1)
		return
	check(not interior.apply_placement(RefCounted.new()).ok, "forged handle rejected")
	check(interior.apply_placement(prepared.handle).ok, "actual visual/interior placement committed")
	check(placement.global_transform.is_equal_approx(delta*original_frame) and interior.global_transform.is_equal_approx(delta), "sibling visual/interior move together")
	check(interior.anchor("publicApproach").is_equal_approx(delta*original_anchor), "current world source anchor projected")
	check(not interior.apply_placement(prepared.handle).ok, "handle cannot replay")
	check(JSON.stringify(data,"",true,true) == original_data, "immutable original placement/data/authority retained")
	for key in mesh_ids: check(interior._mesh_cache[key].get_instance_id() == mesh_ids[key], "same original mesh " + str(key))
	var after_shapes: Array[int] = []
	for node in interior.find_children("*","CollisionShape3D",true,false): after_shapes.append(node.shape.get_instance_id())
	check(after_shapes == shape_ids, "all exact native floor/wall/door shape identities retained")
	owner.permit_commit = false
	var rejected: Dictionary = interior.prepare_placement(original_frame)
	check(rejected.ok and not interior.apply_placement(rejected.handle).ok and not interior.placement_state().pending, "commit refusal rolls back both source frames")
	check(placement.global_transform.is_equal_approx(delta*original_frame) and interior.global_transform.is_equal_approx(delta), "refused placement leaves current source layout intact")
	owner.permit_commit = true
	owner.partial_prepare = true
	check(not interior.prepare_placement(original_frame).ok and not interior.placement_state().pending, "receipted partial prepare rolled back")
	owner.partial_prepare = false
	owner.permit_resume = false
	check(not interior.end_editor_placement().ok and interior.placement_state().editing, "missing real edited nav/support admission remains held")
	owner.permit_resume = true
	owner.reenter_rollback = true
	check(interior.end_editor_placement().ok, "fixture source owner alone admits resume")
	check(not interior.placement_state().retained, "held callback forged rollback has no transaction authority")
	owner.reenter_rollback = false
	var public_position: Vector3 = delta * vector(data.doors.public.anchor)
	check(not interior.nearest_action(public_position).is_empty(), "moved public door action found")
	check(not interior.request_door("public",true,public_position+Vector3(100,0,0),[]).accepted, "moved proximity preserved")
	var door: Dictionary = interior._doors.public
	var bounds: AABB = door.bounds[0]
	var blocked_position: Vector3 = delta * (door.base * Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))
	check(not interior.request_door("public",true,public_position,[{"position": blocked_position,"radius":0.3,"height":1.8}]).accepted, "moved native door sweep detects occupant")
	check(interior.request_door("public",true,public_position,[]).accepted, "moved public door opens without occupant")
	for i in 20: interior.advance(0.1,[])
	check(interior.door_fraction("public") > 0.99, "original door duration/easing survives placement")
	check(interior.begin_editor_placement().ok, "editing can capture already-open door phase")
	owner.unknown_prepare = true
	var unknown: Dictionary = interior.prepare_placement(original_frame)
	check(not unknown.ok and unknown.has("handle") and interior.placement_state().retained and not interior.end_editor_placement().ok, "unknown partial prepare is retained, never treated as unchanged")
	check(not interior.rollback_placement(unknown.handle).ok, "unreceipted external stage requires genuine owner repair")
	owner.permit_unreceipted_repair = true
	check(interior.rollback_placement(unknown.handle).ok, "explicit original owner repairs unreceipted stage")
	owner.permit_unreceipted_repair = false
	owner.unknown_prepare = false
	prepared = interior.prepare_placement(original_frame)
	check(prepared.ok and interior.apply_placement(prepared.handle).ok and interior.end_editor_placement().ok, "move open door back to source placement")
	check(interior.door_fraction("public") > 0.99 and interior.anchor("publicApproach").is_equal_approx(original_anchor), "phase retained through relocation, no replay/reset")
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(original_anchor+Vector3.UP,original_anchor-Vector3.UP*2,1)
	var hit: Dictionary = owner.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(), "actual source collision geometry survives relocation/rollback")
	check(interior.begin_editor_placement().ok, "negative rollback scenario paused")
	owner.permit_commit = false
	owner.permit_rollback = false
	prepared = interior.prepare_placement(delta*original_frame)
	check(prepared.ok and not interior.apply_placement(prepared.handle).ok and interior.placement_state().retained and not interior.end_editor_placement().ok, "failed external rollback retains source placement and held door phase")
	owner.permit_rollback = true
	check(interior.rollback_placement(prepared.handle).ok and interior.end_editor_placement().ok, "same owner can retry retained rollback")
	owner.permit_commit = true
	var before_descriptor: Dictionary = interior._data
	interior._data = before_descriptor.duplicate(true)
	check(not interior.begin_editor_placement().ok, "same-value writable descriptor replacement cannot reuse source admission")
	interior._data = before_descriptor
	check(interior._live(), "original readonly descriptor restored")
	placement.set_meta("source_id", "forged-building")
	check(not interior.begin_editor_placement().ok, "source identity metadata replacement refused")
	placement.set_meta("source_id", Candidate.SOURCE_ID)
	check(interior._live(), "exact original source identity restored")
	var source_mesh: MeshInstance3D = interior.find_children("*","MeshInstance3D",true,false)[0]
	var original_material: Material = source_mesh.get_surface_override_material(0)
	source_mesh.set_surface_override_material(0,StandardMaterial3D.new())
	check(not interior.begin_editor_placement().ok, "node per-surface material replacement refused")
	source_mesh.set_surface_override_material(0,original_material)
	check(interior._live(), "exact original node surface material restored")
	var extra_collision := CollisionShape3D.new()
	placement.add_child(extra_collision)
	check(not interior._live(), "new collision child cannot bypass original inventory")
	placement.remove_child(extra_collision)
	extra_collision.free()
	check(interior._live(), "exact original child inventory restored")
	for shader_row: Dictionary in interior._shader_parameters:
		for key in shader_row.parameters:
			var saved: Variant = shader_row.material.get_shader_parameter(key)
			if saved is float:
				shader_row.material.set_shader_parameter(key, saved + 0.25)
				check(not interior._live(), "silent shader uniform mutation refused: " + str(key))
				shader_row.material.set_shader_parameter(key, saved)
				check(interior._live(), "exact original shader uniform restored: " + str(key))
				break
	old_guard.sort()
	new_guard.sort()
	interior.restore_original()
	owner.free()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite":"source-printshop-placement", "checks":checks,"failures":failures,"gpu":false,"guard_before_p50_us":old_guard[3],"guard_after_p50_us":new_guard[3],"productionWired":false,"actualSourceAdmitted":false,"testOnlyMultimeshGateBypass":true,"ownerCallbacks":"explicit test fixture; real nav/water/HUD/authority and MultiMesh storage pending"}))
	quit(0 if failures.is_empty() else 1)
