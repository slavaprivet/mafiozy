extends Node
## Root-owned, single-source cold lease. Disabled unless a frozen binding is explicit.
const DamageBridge = preload("native_building_damage_bridge.gd")
const SOURCE_ID := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
const ASSET_ID := "old_town_narrow_townhouse_v1"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const BINDING_PATH := "res://data/modular30_binding.json"
var status := "disabled"
var report: Dictionary = {}
var _world: WeakRef
var _original: WeakRef
var _runtime: Node3D
var _prefab: Node3D
var _damage: RefCounted
var _mesh_rows: Array[Dictionary] = []
var _original_hulls: Array[StaticBody3D] = []
var _static_index := -1
var _committed := false
var _disposed := false
var _events: Array[Dictionary] = []

func _ready() -> void:
	set_physics_process(false)
	process_physics_priority = 100 # Rubble contact follows the native player tick.

func prepare(world: Node3D) -> Dictionary:
	if _disposed or _world != null or not is_instance_valid(world) or not world.is_inside_tree(): return {"ok":false,"reason":"world_lifetime"}
	_world = weakref(world)
	if not FileAccess.file_exists(BINDING_PATH): return _abort("binding_missing")
	var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
	if not binding is Dictionary: return _abort("binding_dictionary")
	if binding.get("enabled",false) != true:
		report={"ok":true,"enabled":false,"status":"disabled","source_id":SOURCE_ID}
		return report
	if world._static_batch_lease!=null: return _abort("cold_setup_before_static_batch_required")
	if not world.global_transform.is_equal_approx(Transform3D.IDENTITY): return _abort("world_identity_required")
	if binding.get("source_id")!=SOURCE_ID or binding.get("replacement_scope")!="root_reviewed_new_modular_exterior" or binding.get("active_external_owner_roots_reviewed")!=true: return _abort("explicit_root_replacement_scope_required")
	for pair: Array in [["owner_receipt_path","owner_receipt_sha256"],["companion_receipt_path","companion_receipt_sha256"],["prefab_path","prefab_sha256"]]:
		var path: String=str(binding.get(pair[0],"")); var digest: String=str(binding.get(pair[1],""))
		if not path.begins_with("res://") or digest.length()!=64 or not digest.is_valid_hex_number() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=digest: return _abort("frozen_pin:"+str(pair[0]))
	if FileAccess.get_sha256(world.block_data_path)!=BLOCK_SHA: return _abort("exact_current_block_required")
	var record: Dictionary = {}
	for candidate: Dictionary in world._block.buildings:
		if candidate.get("id")==SOURCE_ID:
			if not record.is_empty(): return _abort("duplicate_current_record")
			record=candidate.duplicate(true)
	if record.get("assetId")!=ASSET_ID or record.get("collisionBodiesM",[]).size()!=2: return _abort("exact_current_record_missing")
	if record.get("gameplayActive")!=false or record.get("sourceGameplayActive")!=false: return _abort("existing_townhouse_gameplay_owner_requires_binding")
	var inventory := _collect_originals(world,record)
	if not inventory.ok: return _abort(str(inventory.reason))
	# Validate source before loading or hiding any visual; no guessed companion frame.
	var loader: Script=load(str(binding.get("loader_path","")))
	var runtime_script: Script=load(str(binding.get("runtime_path","")))
	if loader==null or runtime_script==null: return _abort("runtime_or_loader_missing")
	var loaded: Dictionary=loader.instantiate_prefab(binding.prefab_path,binding.prefab_sha256)
	if not loaded.get("ok",false): return _abort("prefab:"+str(loaded))
	_prefab=loaded.instance
	if loaded.payload.get("source_id")!=SOURCE_ID or loaded.payload.get("asset_id")!=ASSET_ID: return _abort("companion_identity")
	# Authored glass/doors are not silently claimed as preserved. Active owned
	# scripts/bodies were rejected by inventory; helper nodes/IDs remain original.
	var obligations: Dictionary=loaded.payload.get("owner_obligations",{})
	if not obligations.get("protected_interiors",[]).is_empty(): return _abort("protected_interior_owner_binding_required")
	world.add_child(_prefab)
	_prefab.set_meta("source_id",SOURCE_ID)
	var bound: Dictionary=loader.bind_record(_prefab,record,true)
	if not bound.get("ok",false): return _abort("record_bind:"+str(bound))
	_runtime=runtime_script.new()
	_runtime.name="Modular30Runtime"
	add_child(_runtime)
	var configured: Dictionary=_runtime.configure(world)
	if not configured.get("ok",false): return _abort("runtime_configure:"+str(configured))
	var registered: Dictionary=_runtime.register_building(SOURCE_ID,_prefab,_original_hulls,bound.record)
	if not registered.get("ok",false): return _abort("runtime_register:"+str(registered))
	var original: Node3D=_original.get_ref()
	_static_index=world._static_render_roots.find(original)
	if _static_index>=0: world._static_render_roots.remove_at(_static_index)
	for row: Dictionary in _mesh_rows:
		var mesh: MeshInstance3D=row.node.get_ref()
		mesh.visible=false
	_committed=true
	status="geometry_ready_waiting_native_weapons"
	report={"ok":true,"enabled":true,"status":status,"source_id":SOURCE_ID,"registered":registered,"old_hulls":2,"old_meshes_reviewed":_mesh_rows.size(),"old_helpers_retained_in_original_tree":true,"authored_glass_preserved":false,"old_door_nodes_retained_hidden_due_to_aperture_mismatch":true,"operative_townhouse_doors":false,"owner_obligations":obligations.duplicate(true),"prefab_frame":str(_prefab.global_transform),"full_house_collapse":false}
	return report.duplicate(true)

func _collect_originals(world: Node3D, record: Dictionary) -> Dictionary:
	var original: Node3D
	var indices: Dictionary={}
	for child: Node in world.get_children():
		if str(child.get_meta("source_id",""))!=SOURCE_ID: continue
		if child.has_meta("interior_kind"): return {"ok":false,"reason":"external_interior_owner"}
		if child is StaticBody3D:
			var index: Variant=child.get_meta("source_index",null)
			if not index is int and not index is float: return {"ok":false,"reason":"original_hull_index_type:"+str(index)}
			if index!=int(index) or int(index) not in [0,1] or indices.has(int(index)): return {"ok":false,"reason":"original_hull_index:"+str(index)}
			index=int(index)
			if child.get_script()!=null or child.get_child_count()!=1 or child.collision_layer!=1 or child.collision_mask!=1 or child.transform!=Transform3D.IDENTITY: return {"ok":false,"reason":"original_hull_authority_changed"}
			var shape_node: Node=child.get_child(0)
			if not shape_node is CollisionShape3D or shape_node.disabled or shape_node.transform!=Transform3D.IDENTITY or not shape_node.shape is ConvexPolygonShape3D: return {"ok":false,"reason":"original_hull_shape"}
			var expected:=PackedVector3Array()
			var row: Dictionary=record.collisionBodiesM[index]
			if int(row.sourceIndex)!=index: return {"ok":false,"reason":"record_hull_order"}
			for point: Array in row.polygonXZ:
				expected.append(Vector3(float(point[0]),float(row.minY),float(point[1])))
				expected.append(Vector3(float(point[0]),float(row.maxY),float(point[1])))
			if shape_node.shape.points!=expected: return {"ok":false,"reason":"original_hull_points_changed"}
			indices[index]=child
		elif child is Node3D and not child is CollisionObject3D:
			if original!=null: return {"ok":false,"reason":"multiple_source_visual_roots"}
			original=child
		else: return {"ok":false,"reason":"unbound_source_owner"}
	if original==null or indices.size()!=2: return {"ok":false,"reason":"exact_original_visual_and_two_hulls_required"}
	var transforms: Dictionary=record.transform
	var scale: Vector3=Vector3(float(transforms.horizontalScale[0]),1,float(transforms.horizontalScale[1]))*float(transforms.uniformScale)
	var expected_frame:=Transform3D(Basis.IDENTITY.scaled(scale),Vector3(float(record.positionLocalM[0]),float(record.positionLocalM[1]),float(record.positionLocalM[2])))
	if float(transforms.yawDegrees)!=0 or not original.transform.is_equal_approx(expected_frame): return {"ok":false,"reason":"original_townhouse_frame_changed"}
	var nodes: Array[Node]=[original]
	var visited:=0
	while not nodes.is_empty():
		var node: Node=nodes.pop_back(); visited+=1
		if visited>4096 or node.get_script()!=null or node is CollisionObject3D or node.has_meta("interior_kind") or node.has_meta("door_owner") or node.has_meta("gameplay_owner"): return {"ok":false,"reason":"active_owner_requires_separate_binding"}
		if node is MeshInstance3D: _mesh_rows.append({"node":weakref(node),"visible":node.visible,"name":str(node.name),"mesh":node.mesh})
		for child: Node in node.get_children(): nodes.append(child)
	if _mesh_rows.is_empty(): return {"ok":false,"reason":"original_meshes_missing"}
	_original=weakref(original)
	_original_hulls=[indices[0],indices[1]]
	return {"ok":true}

func bind_weapons() -> Dictionary:
	if _disposed or not _committed: return report.duplicate(true)
	var world: Variant=_world.get_ref()
	if not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(world.preview_weapons): return _abort("native_weapon_host_missing")
	_damage=DamageBridge.new()
	var result: Dictionary=_damage.configure(world.preview_weapons,Callable(self,"_native_blast"),Callable(),{"breach_radius_m":.8})
	if not result.get("ok",false): return _abort("native_damage_bridge:"+str(result))
	status="ready"
	report.status=status; report.damage_bridge=result
	set_physics_process(true)
	return report.duplicate(true)

func _native_blast(event: Dictionary) -> Dictionary:
	if _disposed or not _committed or status!="ready" or not is_instance_valid(_runtime) or not is_instance_valid(_prefab): return {"ok":false,"reason":"retired_lease"}
	if event.get("source_id")!=SOURCE_ID: return {"ok":false,"reason":"source_not_admitted"}
	var contact: Dictionary=_runtime.resolve_collision_contact(event.get("collider"),event.position,event.direction)
	if not contact.get("ok",false) or not is_instance_valid(contact.get("object")) or not _prefab.is_ancestor_of(contact.object) or not _runtime.owns_collision_mesh(event.collider,contact.object): return {"ok":false,"reason":"foreign_native_collision"}
	var result: Dictionary=_runtime.apply_explosion(event)
	_events.append({"event_id":event.event_id,"source_id":event.source_id,"position":event.position,"power":event.power,"radius":event.radius,"result":result.duplicate(true)})
	if _events.size()>16: _events.pop_front()
	return result

func _physics_process(delta: float) -> void:
	# Runtime advances its own jobs/rubble. This host never duplicates that tick.
	if _disposed or status!="ready" or _world==null or not is_instance_valid(_runtime): return
	var world: Variant=_world.get_ref()
	if not is_instance_valid(world) or not world.is_inside_tree() or world.preview_dead or world.preview_physics_fault: return
	var player: Variant=world._player; var capsule: Variant=world._player_capsule
	if not is_instance_valid(player) or not is_instance_valid(capsule) or not player.is_inside_tree(): return
	if player._pose_authority!=&"on_foot" or not player._jump.is_empty() or not player.is_on_floor() or not player._free_mouse_look: return
	if Vector2(player.velocity.x,player.velocity.z).length_squared()<.0001: return
	_runtime.push_from_actor(player,capsule,delta)

func snapshot() -> Dictionary:
	return {"status":status,"report":report.duplicate(true),"events":_events.duplicate(true),"runtime":_runtime.stats() if is_instance_valid(_runtime) and not _disposed else {},"damage":_damage.snapshot() if _damage!=null and not _disposed else {}}

func navigation_retirement_receipt() -> Dictionary:
	# Conservative NAV-ONLY no-entry envelope. Exact original objects remain;
	# gameplay physics uses the registered modular triangle body. No NPC breach claim.
	if status in ["disabled","fallback"]: return {"ok":true,"enabled":false}
	if _disposed or not _committed or status not in ["geometry_ready_waiting_native_weapons","ready"] or _world==null or not is_instance_valid(_runtime): return {"ok":false}
	var world: Variant=_world.get_ref()
	if not is_instance_valid(world) or not world.is_inside_tree() or not _runtime.is_inside_tree() or not is_instance_valid(_prefab): return {"ok":false}
	if _original_hulls.size()!=2 or not _runtime.buildings.has(SOURCE_ID): return {"ok":false}
	var building: Dictionary=_runtime.buildings[SOURCE_ID]
	if building.root!=_prefab or building.groups.size()!=1: return {"ok":false}
	for body: StaticBody3D in _original_hulls:
		if not is_instance_valid(body) or body.get_parent()!=world or body.collision_layer!=0 or body.collision_mask!=0: return {"ok":false}
	var group: Dictionary=building.groups[0]
	if not is_instance_valid(group.body) or not is_instance_valid(group.collision) or group.body.get_parent()!=_runtime or group.body.collision_layer!=1 or group.body.collision_mask!=1 or group.collision.shape==null or group.collision.shape!=group.shape: return {"ok":false}
	return {"ok":true,"enabled":true,"schema":"modular30_nav_no_entry/v1","source_id":SOURCE_ID,"world_instance_id":world.get_instance_id(),"world_rid":world.get_world_3d().space,"host_instance_id":get_instance_id(),"retired":_original_hulls.duplicate(),"runtime_instance_id":_runtime.get_instance_id(),"replacement_body":group.body,"replacement_shape_id":group.collision.shape.get_instance_id(),"generation":group.generation,"policy":"conservative_original_hulls_no_entry","gameplayActive":false,"sourceGameplayActive":false}

func _abort(reason: String) -> Dictionary:
	dispose()
	status="fallback"
	report={"ok":false,"status":status,"reason":reason,"rolled_back":true,"source_id":SOURCE_ID}
	return report.duplicate(true)

func dispose(restore_render_lease: bool = true) -> void:
	if _disposed: return
	_disposed=true
	set_physics_process(false)
	if _damage!=null: _damage.dispose(); _damage=null
	var world: Variant=_world.get_ref() if _world!=null else null
	var live_world: bool=is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion()
	var rebatch: bool=_committed and live_world and restore_render_lease and world._static_batch_lease!=null
	if rebatch: world.restore_preview_static_batches("modular30_restore_original")
	if is_instance_valid(_runtime): _runtime.dispose(); _runtime.queue_free()
	_runtime=null
	if is_instance_valid(_prefab):
		_prefab.visible=false
		# On world teardown a sibling may already have left the tree while its
		# parent is still removing children. Only an unparented failed load is freeable.
		if _prefab.get_parent()!=null: _prefab.queue_free()
		else: _prefab.free()
	_prefab=null
	for row: Dictionary in _mesh_rows:
		var node: Variant=row.node.get_ref()
		if is_instance_valid(node): node.visible=row.visible
	if _committed and is_instance_valid(world) and _original!=null:
		var original: Variant=_original.get_ref()
		if is_instance_valid(original) and _static_index>=0 and not world._static_render_roots.has(original): world._static_render_roots.insert(mini(_static_index,world._static_render_roots.size()),original)
	if rebatch: world.apply_preview_static_batches()
	_mesh_rows.clear(); _original_hulls.clear(); _committed=false
	status="disposed"

func _exit_tree() -> void:
	dispose(false)
