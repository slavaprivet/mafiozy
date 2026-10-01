extends SceneTree
## SOURCE ONLY / ENGINE HOLD. Actual procedural Palazzo and physics queries.
## Damage uses the existing site.explode component API, not synthetic weapon
## receipts, collider edits, forced freezes or a second support simulator.
const Site = preload("res://scripts/destruction/palazzo/palazzo_structural_site.gd")
const SEAM := .05
const QUERY_CAP := 4096
const SHOTS := [
	{"tile":Vector2i(0,2),"role":"core","point":Vector3(.25025,-1.048,.17),"removed":[Vector2i(0,2),Vector2i(0,1),Vector2i(0,3),Vector2i(1,2)]},
	{"tile":Vector2i(0,0),"role":"sill","point":Vector3(-.61025,-.803,.43),"removed":[Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(2,0)]},
	{"tile":Vector2i(3,2),"role":"mullion","point":Vector3(.01125,.524,.2925),"removed":[Vector2i(3,2),Vector2i(3,1),Vector2i(2,2),Vector2i(4,2)]}
]
var site: Node3D
var world: Node3D
var panel: RigidBody3D
var target: RigidBody3D
var target_start := Vector3.ZERO
var output := "res://tests/frame_support44_result.json"
var expected := "observe"
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var finished := false
var maximum_support_releases := 0
var initial_shapes := 0
var initial_bodies := 0
var observed_target_ghost := false
var baseline_path := ""
var baseline_report: Dictionary = {}
var stable_keys: Dictionary = {}

func record_initial_inventory() -> void:
	var inventory: Array=[]
	for ref: WeakRef in site._owned_bodies.values():
		var body: RigidBody3D=ref.get_ref()
		var key: String="owned_%04d"%inventory.size()
		stable_keys[body.get_instance_id()]=key
		var shapes: Array=[]
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.shape==null: continue
			check(child.shape is BoxShape3D,"initial original owned geometry consists of actual boxes")
			shapes.append({"transform":child.transform,"size":child.shape.size if child.shape is BoxShape3D else null,"role":child.get_meta("finished_role","source_box")})
		inventory.append({"key":key,"body_pose":body.transform,"shapes":shapes})
	evidence.initial_owned_geometry=inventory
	if expected!="candidate": return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	if not check(parsed is Dictionary,"candidate requires a readable baseline native report"): return
	baseline_report=parsed
	if not check(baseline_report.get("status")=="REPRODUCED_GHOST_SUPPORT" and baseline_report.get("expected")=="baseline" and baseline_report.get("failures",["missing"]).is_empty(),"baseline must independently reproduce the authored ghost without failures"): return
	# JSON roundtrip removes Variant types equally in both runs. The sequential
	# owner keys are only compared after every original body/shape pose matches.
	var normalized_inventory: Variant=JSON.parse_string(JSON.stringify(inventory))
	check(normalized_inventory==baseline_report.get("evidence",{}).get("initial_owned_geometry",[]),"baseline/candidate original ownership order and every authored collision part are identical")

func compare_baseline_grounded() -> void:
	if expected!="candidate" or baseline_report.is_empty(): return
	for label: String in ["intact","shot1","shot2","shot3","stable_after_three","after_gravity_observation"]:
		var previous: Dictionary=baseline_report.get("evidence",{}).get("oracles",{}).get(label,{})
		var current: Dictionary=evidence.get("oracles",{}).get(label,{})
		if not check(previous.get("valid",false) and current.get("valid",false),label+": both native graphs exist for over-release comparison"): continue
		for key: String in previous.get("native_grounded_keys",[]):
			check(current.get("native_grounded_keys",[]).has(key),label+": candidate preserves genuinely ground-connected "+key)

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("FRAME44 FAIL ",label)
	return value

func step(count: int=1) -> void:
	for i in count:
		await physics_frame
		await process_frame

func settle(label: String) -> bool:
	var total_advance_usec:=0
	var advance_samples: Array[int]=[]
	for i in 720:
		await step()
		var diagnostic: Dictionary=site._structure.diagnostics()
		maximum_support_releases=maxi(maximum_support_releases,int(diagnostic.get("last_released",0)))
		var spent: int=int(diagnostic.get("last_advance_usec",0))
		total_advance_usec+=spent; advance_samples.append(spent)
		if not diagnostic.get("busy",true):
			advance_samples.sort()
			evidence.get_or_add("settles",{})[label]={"frames":i+1,"support":diagnostic,"observed_advance_usec_sum":total_advance_usec,"observed_advance_usec_p50":advance_samples[floori((advance_samples.size()-1)*.50)],"observed_advance_usec_p95":advance_samples[floori((advance_samples.size()-1)*.95)],"component_samples_only":true}
			return check(diagnostic.get("ok",false),label+": actual bounded support job completes")
	return check(false,label+": support does not stabilize within component bound")

func grid(body: RigidBody3D) -> Vector2i:
	var center: Vector3=body.get_meta("panel_center")
	var size: Vector3=panel.get_meta("section_size")
	return Vector2i(roundi((center.y+size.y*.5)/(size.y/5.0)-.5),roundi((center.x+size.x*.5)/(size.x/4.0)-.5))

func tile(at: Vector2i) -> RigidBody3D:
	for body: RigidBody3D in panel.get_meta("pooled_fragments"):
		if grid(body)==at: return body
	return null

func identify(body: CollisionObject3D) -> Dictionary:
	var result: Dictionary={"id":body.get_instance_id(),"name":str(body.name)}
	if stable_keys.has(body.get_instance_id()): result.key=stable_keys[body.get_instance_id()]
	if body is RigidBody3D and body.has_meta("wall_panel"):
		var parent: RigidBody3D=body.get_meta("wall_panel")
		result.wall=str(parent.name)
		if parent==panel: result.grid=str(grid(body))
	return result

func enabled_boxes(body: CollisionObject3D) -> Array[Dictionary]:
	var boxes: Array[Dictionary]=[]
	for child: Node in body.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape==null: continue
		if not check(child.shape is BoxShape3D,"oracle uses each actual BoxShape3D, never an invented slab"): return []
		var shape: BoxShape3D=child.shape
		var transform: Transform3D=site.global_transform.affine_inverse()*child.global_transform
		var bounds: AABB=transform*AABB(-shape.size*.5,shape.size)
		boxes.append({"shape":shape,"world":child.global_transform,"bounds":bounds,"role":str(child.get_meta("finished_role","source_box"))})
	return boxes

func merged(boxes: Array[Dictionary]) -> AABB:
	var result: AABB=boxes[0].bounds
	for i in range(1,boxes.size()): result=result.merge(boxes[i].bounds)
	return result

func touch(a: AABB,b: AABB) -> bool:
	return a.position.x<=b.end.x+SEAM and a.end.x+SEAM>=b.position.x and a.position.y<=b.end.y+SEAM and a.end.y+SEAM>=b.position.y and a.position.z<=b.end.z+SEAM and a.end.z+SEAM>=b.position.z

func eligible(body: Variant) -> bool:
	return body is RigidBody3D and is_instance_valid(body) and site.owns_collider(body) and body.freeze and (body.collision_layer&1)!=0 and not body.get_meta("detached",false) and not body.get_meta("parked",false)

func rooted(edges: Dictionary,anchors: Dictionary) -> Dictionary:
	var reached: Dictionary=anchors.duplicate()
	var parent: Dictionary={}
	var queue: Array=anchors.keys()
	var cursor:=0
	while cursor<queue.size():
		var id: int=queue[cursor]; cursor+=1
		for other: int in edges[id]:
			if reached.has(other): continue
			reached[other]=true; parent[other]=id; queue.append(other)
	return {"reached":reached,"parent":parent}

func path_to_ground(id: int,walk: Dictionary,rows: Dictionary) -> Array:
	var path: Array=[]
	if not walk.reached.has(id): return path
	while true:
		path.append(rows[id].identity)
		if not walk.parent.has(id): break
		id=walk.parent[id]
	return path

func oracle(label: String) -> Dictionary:
	# Independent narrow oracle: Godot's actual per-shape collision queries.
	# It does not call candidate SAT, _body_bounds, _touch or _eligible helpers.
	var rows: Dictionary={}; var grounds: Dictionary={}
	for name: String in ["OriginalFoundation","OriginalPlaza"]:
		var body: StaticBody3D=site.get_node(name)
		var boxes: Array[Dictionary]=enabled_boxes(body)
		if not check(not boxes.is_empty(),label+": real ground has enabled box geometry"): return {"valid":false}
		grounds[body.get_instance_id()]={"body":body,"boxes":boxes,"bounds":merged(boxes)}
	for body: RigidBody3D in site.pieces:
		if not eligible(body): continue
		var boxes: Array[Dictionary]=enabled_boxes(body)
		if not check(not boxes.is_empty(),label+": each eligible structural body has enabled box geometry"): return {"valid":false}
		rows[body.get_instance_id()]={"body":body,"boxes":boxes,"bounds":merged(boxes),"identity":identify(body)}
	var broad: Dictionary={}; var narrow: Dictionary={}; var broad_anchors: Dictionary={}; var narrow_anchors: Dictionary={}
	for id: int in rows: broad[id]=[]; narrow[id]=[]
	for id: int in rows:
		var row: Dictionary=rows[id]
		for ground: Dictionary in grounds.values():
			if touch(row.bounds,ground.bounds) and ground.bounds.end.y>=row.bounds.position.y-SEAM and ground.bounds.end.y<=row.bounds.end.y+SEAM: broad_anchors[id]=true
		for other: int in rows:
			if other>id and touch(row.bounds,rows[other].bounds): broad[id].append(other); broad[other].append(id)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.collision_mask=1; query.exclude=[row.body.get_rid()]; query.margin=SEAM
		for box: Dictionary in row.boxes:
			query.shape=box.shape; query.transform=box.world
			var hits: Array[Dictionary]=site.get_world_3d().direct_space_state.intersect_shape(query,QUERY_CAP)
			if not check(hits.size()<QUERY_CAP,label+": native contact query does not saturate"): return {"valid":false}
			for hit: Dictionary in hits:
				var body: Variant=hit.get("collider")
				if not is_instance_valid(body): continue
				var other: int=body.get_instance_id()
				if rows.has(other) and other!=id:
					if not narrow[id].has(other): narrow[id].append(other)
					if not narrow[other].has(id): narrow[other].append(id)
				elif grounds.has(other):
					var ground: Dictionary=grounds[other]
					if ground.bounds.end.y>=box.bounds.position.y-SEAM and ground.bounds.end.y<=box.bounds.end.y+SEAM: narrow_anchors[id]=true
	var broad_walk: Dictionary=rooted(broad,broad_anchors)
	var narrow_walk: Dictionary=rooted(narrow,narrow_anchors)
	var ghosts: Array=[]; var false_edges: Array=[]
	for id: int in rows:
		if broad_walk.reached.has(id) and not narrow_walk.reached.has(id):
			ghosts.append({"body":rows[id].identity,"merged_ground_path":path_to_ground(id,broad_walk,rows),"native_shape_neighbors":narrow[id],"frozen":rows[id].body.freeze,"collision_layer":rows[id].body.collision_layer})
		for other: int in broad[id]:
			if other>id and not narrow[id].has(other): false_edges.append({"a":rows[id].identity,"b":rows[other].identity})
	var target_id: int=target.get_instance_id()
	var native_grounded_keys: Array[String]=[]
	for id: int in narrow_walk.reached: native_grounded_keys.append(stable_keys[id])
	native_grounded_keys.sort()
	var report: Dictionary={"valid":true,"active_static_bodies":rows.size(),"broad_grounded":broad_walk.reached.size(),"native_shape_grounded":narrow_walk.reached.size(),"ghosts":ghosts,"false_edges":false_edges,"target":{"identity":identify(target),"eligible":rows.has(target_id),"broad_grounded":broad_walk.reached.has(target_id),"native_grounded":narrow_walk.reached.has(target_id),"native_neighbors":narrow.get(target_id,[]),"broad_ground_path":path_to_ground(target_id,broad_walk,rows),"detached":target.get_meta("detached",false),"support_released":target.get_meta("support_released",false),"local_position":site.to_local(target.global_position)},"margin_m":SEAM,"native_query":"intersect_shape for every enabled original BoxShape3D; exact original transforms; mask1; exclude only queried body","not_a_dynamic_stress_solver":true}
	report.native_grounded_keys=native_grounded_keys
	evidence.get_or_add("oracles",{})[label]=report
	return report

func real_blast(index: int) -> bool:
	var shot: Dictionary=SHOTS[index]
	var hit_body: RigidBody3D=panel if index==0 else tile(shot.tile)
	if not check(eligible(hit_body),"shot%d actual target is still an owned static collider"%(index+1)): return false
	var at: Vector3=panel.to_global(shot.point)
	var normal: Vector3=panel.global_basis.z
	var ray:=PhysicsRayQueryParameters3D.create(at+normal*.025,at-normal*.025,1)
	var hit: Dictionary=site.get_world_3d().direct_space_state.intersect_ray(ray)
	if not check(hit.get("collider")==hit_body,"shot%d short native ray hits the planned actual %s surface"%[index+1,shot.role]): return false
	var before: Dictionary={}
	for body: RigidBody3D in panel.get_meta("pooled_fragments"):
		before[body.get_instance_id()]=bool(body.get_meta("detached",false))
	var serial: int=site.blast_serial
	site.explode(hit.position,.8,hit_body,false)
	var newly: Array[String]=[]
	for body: RigidBody3D in panel.get_meta("pooled_fragments"):
		if body.get_meta("detached",false) and not before[body.get_instance_id()]: newly.append(str(grid(body)))
	var planned: Array[String]=[]
	for point: Vector2i in shot.removed: planned.append(str(point))
	newly.sort(); planned.sort()
	check(site.blast_serial==serial+1 and site.last_explosion.get("committed",false) and site.last_explosion.get("detached")==4,"shot%d commits the ordinary four-fragment owner route"%(index+1))
	check(newly==planned,"shot%d actual detached grid identities match the reviewed selector witness"%(index+1))
	check(not target.get_meta("detached",false),"shot%d does not directly release the target mullion tile"%(index+1))
	var stats: Dictionary=site.get_stats()
	check(stats.native_shape_count==initial_shapes and stats.native_body_count==initial_bodies,"shot%d keeps every authored collision part and prewarmed native body"%(index+1))
	evidence.get_or_add("shots",[]).append({"shot":index+1,"component_API":"site.explode","native_projectile":false,"hit_collider":identify(hit_body),"native_hit":hit.position,"point_in_panel":panel.to_local(hit.position),"newly_detached":newly,"expected":planned,"result":site.last_explosion.duplicate(),"pool":stats.pool,"native_shapes":stats.native_shape_count})
	return failures.is_empty()

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		if arg.begins_with("--expect="): expected=arg.trim_prefix("--expect=")
		if arg.begins_with("--baseline-report="): baseline_path=arg.trim_prefix("--baseline-report=")
	if not check(expected in ["observe","baseline","candidate"],"recognized expected outcome"): finish(); return
	if expected=="candidate" and not check(not baseline_path.is_empty(),"candidate comparison requires the actual prior baseline report path"): finish(); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	create_timer(60).timeout.connect(func():
		if not finished: check(false,"bounded sixty-second component watchdog"); finish())
	world=Node3D.new(); root.add_child(world)
	site=Site.new(); site.source_id="frame-support44-native-component"
	site.transform=Transform3D(Basis(Vector3.UP,.41),Vector3(30,2,-20))
	world.add_child(site); await step(4)
	if not check(site.site_ready and site.support_setup.get("ok",false),"original finished Palazzo/support initializes under translated yaw"): finish(); return
	for wall: RigidBody3D in site.wall_panels:
		if str(wall.name).begins_with("Facade") and wall.position.is_equal_approx(Vector3(-3,1.57,3)): panel=wall
	if not check(is_instance_valid(panel) and panel.get_meta("pooled_fragments").size()==20,"reviewed front-left panel has its exact twenty compound tiles"): finish(); return
	target=tile(Vector2i(2,1)); target_start=target.global_position
	var stats: Dictionary=site.get_stats(); initial_shapes=stats.native_shape_count; initial_bodies=stats.native_body_count
	check(stats.pieces==97 and stats.pool==560,"original source inventory, no replacement geometry")
	record_initial_inventory()
	if not failures.is_empty(): finish(); return
	var roles: Dictionary={}
	for box: Dictionary in enabled_boxes(target): roles[box.role]=true
	check(roles.size()==1 and roles.has("mullion"),"selected survivor is actual thin mullion geometry, not a cyan glass rim")
	if not await settle("intact"): finish(); return
	oracle("intact")
	for index in SHOTS.size():
		if not real_blast(index): finish(); return
		if not await settle("shot%d"%(index+1)): finish(); return
		await step(2) # Physics server has applied the actual retired body layers.
		oracle("shot%d"%(index+1))
	var final: Dictionary=oracle("stable_after_three")
	if not final.get("valid",false): finish(); return
	observed_target_ghost=final.target.eligible and final.target.broad_grounded and not final.target.native_grounded
	await step(90)
	var later: Dictionary=oracle("after_gravity_observation")
	if not later.get("valid",false): finish(); return
	evidence.gravity={"before":target_start,"after":target.global_position,"drop_m":target_start.y-target.global_position.y,"frozen":target.freeze,"detached":target.get_meta("detached",false),"support_released":target.get_meta("support_released",false),"manual_target_release":false}
	if expected=="baseline":
		# An honest NOT_REPRODUCED is informative; missing physical reproduction
		# must never become a fabricated PASS based on the eight potential edges.
		if observed_target_ghost: check(later.target.eligible and later.target.broad_grounded and not later.target.native_grounded and absf(target.global_position.y-target_start.y)<.002,"baseline ghost remains physically fixed across ninety native physics ticks")
	elif expected=="candidate":
		check(final.ghosts.is_empty() and later.ghosts.is_empty(),"candidate leaves no active body with only a broad ground path")
		check(target.get_meta("support_released",false) and target.get_meta("detached",false),"actual support owner, not fixture, releases the unsupported mullion")
		check(target_start.y-target.global_position.y>.08,"released mullion actually descends under native gravity")
	check(maximum_support_releases<=8,"existing support release budget remains at most eight per physics frame")
	compare_baseline_grounded()
	finish()

func finish() -> void:
	if finished: return
	finished=true
	var status: String="FAIL" if not failures.is_empty() else ("CANDIDATE_COMPONENT_PASS" if expected=="candidate" else ("REPRODUCED_GHOST_SUPPORT" if observed_target_ghost else "NOT_REPRODUCED"))
	var report: Dictionary={"status":status,"checks":checks,"failures":failures,"expected":expected,"evidence":evidence,"maximum_support_releases":maximum_support_releases,"native_collision_oracle":true,"native_weapon_input":false,"component_explosion_API":true,"fixture_collision_edits":false,"fixture_target_freeze_or_release":false,"loaded_player_passage_accepted":false,"loaded_performance_accepted":false,"limits":["Native contact topology at a documented .05m seam is a component oracle, not real structural stress simulation.","Native actual projectile/character movement and full-scene performance remain required.","The ray/selector/geometry gates must hold; otherwise this scenario is invalid, not proof of ghost support."]}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: push_error("Unable to write frame44 report")
	print("FRAME44 ",status," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 2)
