extends SceneTree
const Snapshot=preload("res://scripts/transport/candidates/transport_vehicle_debris_material_snapshot_cached.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	check(Snapshot.SOURCE_EXPLOSION_ORDER==["char_source_materials","on_explosion_callback","hide_glass","stage_and_commit_private_materials","launch_and_hide_sources"],"exact source explosion order exposed")
	var setup:=_setup(world,"primary")
	check(setup.ok,"two-surface shared-material debris configured")
	if not setup.ok: finish({}); return
	var helper=setup.helper; var source: MeshInstance3D=setup.source; var shared: StandardMaterial3D=setup.shared
	while not helper.stats().ready:
		check(helper.prewarm_step(1).ok,"prepared body prewarmed")
		await physics_frame
	var private:=_private_mesh(helper)
	check(private!=null and private.mesh.get_surface_count()==2,"private two-surface binding exists")
	var initial_receipt: Dictionary=helper.material_snapshot_receipt()
	check(helper.launch([{"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO}]).error=="visual_revision_required","raw launch cannot bypass material receipt")
	# Source exact ordering boundary: burn shared material, finish callback which
	# replaces surface 1, hide external glass, then stage+commit.
	shared.albedo_color=Color("100f0e"); shared.roughness=.99
	var callback_material:=StandardMaterial3D.new(); callback_material.albedo_color=Color(.21,.13,.08,1); callback_material.roughness=.83
	source.mesh.surface_set_material(1,callback_material)
	var glass:=Node3D.new(); glass.name="External_glass"; world.add_child(glass); glass.visible=false
	var stage_begin:=Time.get_ticks_usec(); var staged: Dictionary=helper.stage_material_snapshot(0,1); var stage_us:=Time.get_ticks_usec()-stage_begin
	check(staged.ok and staged.meshes==1 and staged.surfaces==2,"post-callback materials staged")
	check(helper.material_snapshot_receipt().material_ids==initial_receipt.material_ids,"stage does not mutate private materials")
	check(helper.stage_material_snapshot(0,1).error=="pending","one pending transaction enforced")
	check(helper.commit_material_snapshot(RefCounted.new()).error=="stage_token","foreign token rejected")
	var commit_begin:=Time.get_ticks_usec(); var committed: Dictionary=helper.commit_material_snapshot(staged.stage_token); var commit_us:=Time.get_ticks_usec()-commit_begin
	check(committed.ok and committed.revision==1,"snapshot committed atomically")
	var private0:=private.get_active_material(0) as StandardMaterial3D; var private1:=private.get_active_material(1) as StandardMaterial3D
	check(private0!=shared and private1!=callback_material and private0!=private1,"every private surface owns an independent material")
	check(private0.albedo_color.is_equal_approx(shared.albedo_color) and is_equal_approx(private0.roughness,.99),"burn material captured after char")
	check(private1.albedo_color.is_equal_approx(callback_material.albedo_color) and is_equal_approx(private1.roughness,.83),"callback replacement captured at boundary")
	check(not private.is_ancestor_of(glass) and glass.get_parent()==world,"external damage effects are not cloned")
	shared.albedo_color=Color.WHITE; shared.roughness=.2; callback_material.albedo_color=Color.BLUE
	check(private0.albedo_color.is_equal_approx(Color("100f0e")) and is_equal_approx(private0.roughness,.99) and private1.albedo_color.is_equal_approx(Color(.21,.13,.08,1)),"source reset cannot recolour committed debris")
	check(helper.refresh_geometry(source,[source],0,1).error=="material_snapshot_started","geometry refresh is sealed before visual snapshot")
	check(helper.launch_with_visual_revision([{"linear_velocity":Vector3(0,1,0),"angular_velocity":Vector3.ZERO}],0).error=="visual_revision","launch rejects stale visual revision")
	check(helper.launch_with_visual_revision([{"linear_velocity":Vector3(0,1,0),"angular_velocity":Vector3.ZERO}],1).ok,"launch accepts committed visual revision")
	helper.reset()
	check(private0.albedo_color.is_equal_approx(Color("100f0e")) and not helper.material_snapshot_receipt().committed,"reset preserves resource but invalidates its receipt")
	check(helper.launch_with_visual_revision([{"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO}],1).error=="visual_revision","reset requires a fresh material snapshot")
	check(helper.refresh_geometry(source,[source],0,1).error=="after_launch","launched-reset geometry requires dispose and reconfigure")
	var reset_stage: Dictionary=helper.stage_material_snapshot(1,2); check(reset_stage.ok and helper.commit_material_snapshot(reset_stage.stage_token).ok,"reset advances fresh visual revision")
	check(helper.launch_with_visual_revision([{"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO}],2).ok,"fresh reset snapshot relaunches")
	helper.dispose(); setup.root.free(); glass.free()

	await _rollback_cases(world)
	var actual: Dictionary=await _actual_compact_cost(world)
	finish({"two_surface_stage_us":stage_us,"two_surface_commit_us":commit_us,"actual_compact":actual})

func _rollback_cases(world: Node3D) -> void:
	var replacement:=_setup(world,"replacement"); var helper=replacement.helper; var source: MeshInstance3D=replacement.source
	var before: Dictionary=helper.material_snapshot_receipt(); var staged: Dictionary=helper.stage_material_snapshot(0,1)
	var changed:=StandardMaterial3D.new(); changed.albedo_color=Color.RED; source.mesh.surface_set_material(1,changed)
	check(staged.ok and helper.commit_material_snapshot(staged.stage_token).error=="source_material_changed","source material replacement between stage and commit rejected")
	var after_failure: Dictionary=helper.material_snapshot_receipt()
	check(after_failure.material_ids==before.material_ids and after_failure.revision==before.revision and not after_failure.committed,"source replacement failure is atomic")
	check(helper.abort_material_snapshot(staged.stage_token).ok,"failed pending transaction can abort")
	check(helper.commit_material_snapshot(staged.stage_token).error=="no_pending","aborted token is stale")
	helper.dispose(); replacement.root.free()

	var prepared:=_setup(world,"prepared"); helper=prepared.helper; staged=helper.stage_material_snapshot(0,1); var private:=_private_mesh(helper)
	var prepared_other:=private.get_active_material(1); var intrusive:=StandardMaterial3D.new(); private.mesh.surface_set_material(0,intrusive)
	check(helper.commit_material_snapshot(staged.stage_token).error=="private_material_changed","prepared material replacement between stage and commit rejected")
	check(private.get_active_material(0)==intrusive and private.get_active_material(1)==prepared_other,"prepared replacement failure performs no partial write")
	helper.abort_material_snapshot(staged.stage_token); helper.dispose(); prepared.root.free()

	var content:=_setup(world,"content"); helper=content.helper; staged=helper.stage_material_snapshot(0,1); var content_shared: StandardMaterial3D=content.shared
	content_shared.roughness=.91
	check(helper.commit_material_snapshot(staged.stage_token).error=="material_content_changed","same-resource content mutation after stage rejected")
	check(helper.material_snapshot_receipt().revision==0,"content mutation keeps revision and private resources")
	helper.abort_material_snapshot(staged.stage_token); helper.dispose(); content.root.free()

	var committed_change:=_setup(world,"committed_change"); helper=committed_change.helper; staged=helper.stage_material_snapshot(0,1); check(helper.commit_material_snapshot(staged.stage_token).ok,"committed-change fixture committed")
	private=_private_mesh(helper); (private.get_active_material(0) as StandardMaterial3D).roughness=.17
	check(helper.launch_with_visual_revision([{"linear_velocity":Vector3.ZERO,"angular_velocity":Vector3.ZERO}],1).error=="private_material_changed","in-place private mutation invalidates launch receipt")
	helper.dispose(); committed_change.root.free()

	var layout:=_setup(world,"layout"); helper=layout.helper; source=layout.source; staged=helper.stage_material_snapshot(0,1)
	var mesh:=source.mesh as ArrayMesh; var arrays:=mesh.surface_get_arrays(0); var material:=mesh.surface_get_material(0); mesh.clear_surfaces(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,material)
	check(helper.commit_material_snapshot(staged.stage_token).error=="surface_layout","in-place surface layout replacement rejected")
	check(helper.material_snapshot_receipt().revision==0,"surface layout failure keeps revision")
	helper.abort_material_snapshot(staged.stage_token); helper.dispose(); layout.root.free()

	var stale:=_setup(world,"stale"); helper=stale.helper; staged=helper.stage_material_snapshot(0,1); (stale.source as MeshInstance3D).free()
	check(helper.commit_material_snapshot(staged.stage_token).error=="stale_node","freed source binding rejected")
	helper.dispose(); stale.root.free()

	var revisions:=_setup(world,"revision"); helper=revisions.helper
	check(helper.stage_material_snapshot(1,2).error=="stale_revision","stale expected revision rejected")
	staged=helper.stage_material_snapshot(0,1); check(staged.ok,"valid revision stages")
	check(not helper.configure(revisions.root,world,[],null,0,0).ok,"failed reconfigure rejected without touching pending state")
	check(helper.abort_material_snapshot(staged.stage_token).ok,"valid staged revision aborts")
	check(helper.material_snapshot_receipt().revision==0,"abort leaves revision unchanged")
	helper.dispose(); revisions.root.free()

	var moved:=_setup(world,"moved"); helper=moved.helper; source=moved.source; staged=helper.stage_material_snapshot(0,1); var original_parent:=source.get_parent(); source.reparent(world,true)
	var moved_error: String=helper.commit_material_snapshot(staged.stage_token).get("error","")
	check(moved_error in ["source_changed","hierarchy_changed"],"source reparent between stage and commit rejected")
	source.reparent(original_parent,true); helper.abort_material_snapshot(staged.stage_token); helper.dispose(); moved.root.free()

	var private_moved:=_setup(world,"private_moved"); helper=private_moved.helper; staged=helper.stage_material_snapshot(0,1); private=_private_mesh(helper); var private_parent:=private.get_parent(); private.reparent(world,false)
	check(helper.commit_material_snapshot(staged.stage_token).error=="prepared_body_changed","private reparent between stage and commit rejected")
	private.reparent(private_parent,false); helper.abort_material_snapshot(staged.stage_token); helper.dispose(); private_moved.root.free()

	var queued:=_setup(world,"queued"); helper=queued.helper; source=queued.source; staged=helper.stage_material_snapshot(0,1); source.queue_free()
	check(helper.commit_material_snapshot(staged.stage_token).error=="stale_node","queued-free source rejected in same frame")
	check(not helper.material_snapshot_receipt().valid and helper.material_snapshot_receipt().error=="stale_node","queued-free receipt fails closed")
	helper.dispose(); queued.root.free()

	var reset_pending:=_setup(world,"reset_pending"); helper=reset_pending.helper; staged=helper.stage_material_snapshot(0,1); helper.reset()
	check(helper.commit_material_snapshot(staged.stage_token).error=="no_pending","reset invalidates old pending token")
	check(helper.material_snapshot_receipt().revision==0 and not helper.material_snapshot_receipt().committed,"reset leaves monotonic revision uncommitted")
	helper.dispose(); reset_pending.root.free()

	var body_moved:=_setup(world,"body_moved"); helper=body_moved.helper
	while not helper.stats().ready:
		check(helper.prewarm_step(1).ok,"body-move fixture prewarms")
		await physics_frame
	staged=helper.stage_material_snapshot(0,1); var body:=helper._entries[0].body as RigidBody3D; var alternate:=Node3D.new(); world.add_child(alternate); body.reparent(alternate,true)
	check(helper.commit_material_snapshot(staged.stage_token).error=="prepared_body_changed","prepared body reparent between stage and commit rejected")
	body.reparent(world,true); helper.abort_material_snapshot(staged.stage_token); helper.dispose(); body_moved.root.free(); alternate.free()

	var unsupported:=_setup(world,"unsupported"); helper=unsupported.helper; source=unsupported.source; var shader:=ShaderMaterial.new(); shader.shader=Shader.new(); shader.shader.code="shader_type spatial;"
	source.material_override=shader
	check(helper.stage_material_snapshot(0,1).error=="unsupported_material","unsupported ShaderMaterial fails closed")
	helper.dispose(); unsupported.root.free()

func _setup(world: Node3D,label: String) -> Dictionary:
	var vehicle:=Node3D.new(); vehicle.name="Vehicle_"+label; world.add_child(vehicle)
	var assembly:=MeshInstance3D.new(); assembly.name="Door_"+label; vehicle.add_child(assembly)
	var shared:=StandardMaterial3D.new(); shared.albedo_color=Color(.6,.2,.1,1); shared.roughness=.45
	var mesh:=ArrayMesh.new()
	var a:=[]; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,1,0)])
	var b:=[]; b.resize(Mesh.ARRAY_MAX); b[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,0,1)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a); mesh.surface_set_material(0,shared)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b); mesh.surface_set_material(1,shared)
	assembly.mesh=mesh
	var helper:=Snapshot.new(); var configured:=helper.configure(vehicle,world,[{"source":assembly,"mass_kg":12.0,"collision_layer":8,"collision_mask":1,"linear_damp":.2,"angular_damp":1.0,"friction":.7,"bounce":.05}],null,0,0)
	return {"ok":configured.get("ok",false),"error":configured.get("error",""),"helper":helper,"root":vehicle,"source":assembly,"shared":shared}

func _actual_compact_cost(world: Node3D) -> Dictionary:
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	var profile: Dictionary={}
	for row: Dictionary in Bindings.load_oracle().get("rows",[]):
		if row.profile_id=="compact_sedan": profile=row; break
	check(loaded.ok and not profile.is_empty(),"actual compact visual and source profile load")
	if not loaded.ok or profile.is_empty(): return {"ok":false,"error":"load"}
	var visual=loaded.visual; world.add_child(visual.root)
	var bound:=Bindings.bind(visual,profile)
	check(bound.ok,"actual compact explosion order binds exact source descriptors")
	if not bound.ok: visual.dispose(); return {"ok":false,"error":bound.get("error","")}
	var rows: Array=[]; var source_indices: Array=[]
	for descriptor: Dictionary in bound.explosion:
		if not descriptor.copy_eligible_at_export: continue
		source_indices.append(descriptor.source_index)
		rows.append({"source":descriptor.source,"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05})
	var helper:=Snapshot.new(); var load_begin:=Time.get_ticks_usec(); var configured: Dictionary=helper.configure(visual.root,world,rows,null,0,0); var load_us:=Time.get_ticks_usec()-load_begin
	check(configured.ok,"actual compact prepared debris configured in source order")
	if not configured.ok: helper.dispose(); visual.dispose(); return {"ok":false,"error":configured.get("error",""),"load_us":load_us}
	var warm: Dictionary={}
	while not helper.stats().ready:
		warm=helper.prewarm_step(rows.size())
		if not warm.ok: break
		await physics_frame
	check(warm.get("ok",false) and helper.stats().ready,"actual compact debris bodies prepared before snapshot")
	var stage_begin:=Time.get_ticks_usec(); var staged: Dictionary=helper.stage_material_snapshot(0,1); var stage_us:=Time.get_ticks_usec()-stage_begin
	check(staged.ok,"actual compact effective materials staged")
	var commit_us:=0; var committed: Dictionary={}
	if staged.ok:
		var commit_begin:=Time.get_ticks_usec(); committed=helper.commit_material_snapshot(staged.stage_token); commit_us=Time.get_ticks_usec()-commit_begin
	check(committed.get("ok",false),"actual compact private materials committed")
	var result={"ok":configured.ok and staged.ok and committed.get("ok",false),"source_indices":source_indices,"assemblies":rows.size(),"meshes":staged.get("meshes",0),"surfaces":staged.get("surfaces",0),"load_us":load_us,"stage_us":stage_us,"commit_us":commit_us}
	helper.dispose(); visual.dispose(); return result

func _private_mesh(helper) -> MeshInstance3D:
	var bodies: Array=helper.bodies()
	if bodies.is_empty():
		# Prepared bodies are not externally listed until prewarm. Tests that only
		# stage use the inherited candidate's configured entry.
		if helper._entries.is_empty(): return null
		return helper._entries[0].template as MeshInstance3D
	var body:=bodies[0] as RigidBody3D
	return body.get_child(0) as MeshInstance3D

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_MATERIAL_SNAPSHOT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"candidate post-callback material transaction; no HP/authority/main/GPU"}))
	quit(0 if failures.is_empty() else 1)
