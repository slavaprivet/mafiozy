extends RefCounted
## Small, prebuilt visceral pieces, released only by a committed abdominal cut.
## Four world-only bodies at most per target; no soft-body solver or per-frame mesh rebuild.
var _generation := -1
var _released := false
var _pieces: Array[Dictionary] = []
var _gut: ArrayMesh
var _lobe: ArrayMesh
var _kidney: ArrayMesh
var _shapes:Array[ConvexPolygonShape3D]=[]
const Geometry31=preload("res://scripts/combat/organ_mesh31.gd")
var _gut_material: StandardMaterial3D
var _organ_material: StandardMaterial3D
var last: Dictionary = {}
const GLOBAL_BODY_LIMIT := 32
static var shared_bodies:Array[WeakRef]=[]

func warm_render(host:Node)->void:
	prepare()
	if DisplayServer.get_name()=="headless":return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(16,16);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,.3);camera.current=true;viewport.add_child(camera)
	for i in 3:
		var visual:=MeshInstance3D.new()
		visual.mesh=_gut if i==0 else (_lobe if i==1 else _kidney)
		visual.material_override=_gut_material if i==0 else _organ_material
		visual.position.x=-.04 if i==0 else .04
		viewport.add_child(visual)
		# Cook each shared hull inside the startup-only isolated physics world.
		# Their first combat assignment then reuses an already installed shape.
		var warm_body:=RigidBody3D.new();warm_body.freeze=true
		var warm_shape:=CollisionShape3D.new();warm_shape.shape=_shapes[i]
		warm_body.add_child(warm_shape);viewport.add_child(warm_body)
	for i in 3:
		await host.get_tree().physics_frame
		await host.get_tree().process_frame
		await RenderingServer.frame_post_draw
	viewport.queue_free()

func prepare() -> void:
	if _gut != null: return
	_gut_material = StandardMaterial3D.new()
	_gut_material.albedo_color = Color(.40,.13,.145)
	_gut_material.roughness = .37
	_gut_material.metallic_specular = .30
	_gut_material.vertex_color_use_as_albedo=true
	_organ_material = StandardMaterial3D.new()
	_organ_material.albedo_color = Color(.14,.018,.028)
	_organ_material.roughness = .25
	_organ_material.metallic_specular = .44
	_organ_material.vertex_color_use_as_albedo=true
	_gut=Geometry31.bowel()
	_lobe=Geometry31.organ(0)
	_kidney=Geometry31.organ(1)
	# Collision must support the actual folded geometry, not a tiny sphere
	# that leaves its ends floating. Hull construction is startup-only.
	for mesh:ArrayMesh in [_gut,_lobe,_kidney]:
		var hull:=ConvexPolygonShape3D.new()
		hull.points=_support_points31(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		hull.margin=.001
		_shapes.append(hull)

static func _support_points31(points:PackedVector3Array)->PackedVector3Array:
	# A small convex debris proxy, fitted to actual extremal authored points.
	# Keep hull/CCD cost bounded; all 26 axis/diagonal supports are startup-only.
	var result:=PackedVector3Array()
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				var direction:=Vector3(x,y,z)
				if direction.is_zero_approx():continue
				var best:=0;var distance:=-INF
				for i in points.size():
					var d:float=points[i].dot(direction)
					if d>distance:distance=d;best=i
				# Jolt's ordinary contact tolerance is 10mm, comparable to
				# a bowel radius. A 16mm contact skin keeps the visible tube
				# above the floor rather than half buried. Only 26 hull points.
				result.append(points[best]+direction.normalized()*.016)
	return result

func tick(host: Node) -> void:
	var generation := int(host.get("lab_resets"))
	if _generation != generation:
		clear();_generation=generation
	var now := Time.get_ticks_msec()
	for i in range(_pieces.size()-1,-1,-1):
		var body: RigidBody3D = _pieces[i].body.get_ref()
		if not is_instance_valid(body): _pieces.remove_at(i)
		elif now>=int(_pieces[i].expires):
			body.queue_free();_pieces.remove_at(i)

func clear() -> void:
	for row: Dictionary in _pieces:
		var body: Node = row.body.get_ref()
		if is_instance_valid(body): body.queue_free()
	_pieces.clear();_released=false

func release(host: Node, context: Dictionary, before: int) -> void:
	var begun := Time.get_ticks_usec()
	tick(host)
	if _released or str(context.get("base","")) not in ["chest","pelvis"]: return
	var debris: Array = host.get("_npc_debris")
	if before>=debris.size() or not is_instance_valid(debris[before].node): return
	var rig: Skeleton3D = host.get("_npc_rig")
	if not is_instance_valid(rig): return
	var chest := rig.find_bone("chest")
	var left := rig.find_bone("thigh_l")
	var right := rig.find_bone("thigh_r")
	if chest<0 or left<0 or right<0: return
	var upper: Vector3 = rig.global_transform*rig.get_bone_global_pose(chest).origin
	var hips: Vector3 = rig.global_transform*((rig.get_bone_global_pose(left).origin+rig.get_bone_global_pose(right).origin)*.5)
	var abdomen := hips.lerp(upper,.55)
	var height := clampf(upper.distance_to(hips),.12,.5)
	var plane: Plane = context.plane
	# A chest/neck cut above the abdominal volume does not create intestines.
	if absf(plane.distance_to(abdomen))>maxf(.055,height*.48):
		last={"released":false,"reason":"outside_abdomen"};return
	var opening := plane.project(abdomen)
	var keep_front := plane.distance_to(Vector3(context.keep))>=0.0
	var outward := plane.normal*(-1.0 if keep_front else 1.0)
	var side := outward.cross(Vector3.UP).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	prepare()
	var size := clampf(height/.30,.65,1.3)
	var world: Node = host.get_tree().current_scene
	var expires := Time.get_ticks_msec()+3000
	for i in range(shared_bodies.size()-1,-1,-1):
		if not is_instance_valid(shared_bodies[i].get_ref()) or shared_bodies[i].get_ref().is_queued_for_deletion():shared_bodies.remove_at(i)
	var count:=mini(4,GLOBAL_BODY_LIMIT-shared_bodies.size())
	for i in count:
		var body := RigidBody3D.new()
		body.name="LooseIntestine31" if i<2 else "LooseOrgan31"
		body.mass=.10 if i<2 else .16
		body.collision_layer=1
		body.collision_mask=1
		body.continuous_cd=true
		body.linear_damp=.9
		body.angular_damp=1.4
		var physics := PhysicsMaterial.new()
		physics.friction=.72;physics.bounce=.04
		body.physics_material_override=physics
		var visual := MeshInstance3D.new()
		visual.mesh=_gut if i<2 else (_lobe if i==2 else _kidney)
		visual.material_override=_gut_material if i<2 else _organ_material
		visual.scale=Vector3.ONE*size
		visual.rotation=Vector3(.25*float(i),.7*float(i),.35*float(i))
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		collision.shape=_shapes[0 if i<2 else i-1]
		collision.scale=Vector3.ONE*size
		collision.rotation=visual.rotation
		body.add_child(collision)
		world.add_child(body)
		# These soft pieces share one opening. Internal convex hull overlap must
		# not create an expensive rigid explosion; the world still stops each.
		for previous:Dictionary in _pieces:
			var other:RigidBody3D=previous.body.get_ref()
			if is_instance_valid(other):
				body.add_collision_exception_with(other);other.add_collision_exception_with(body)
		body.global_position=opening+outward*(.018+.009*float(i))+side*((float(i)-1.5)*.025*size)
		body.linear_velocity=outward*(.18+.035*float(i))+side*((float(i)-1.5)*.05)+Vector3.DOWN*.1
		body.angular_velocity=Vector3(.7,float(i)*.35,.4)
		host._lab_debris_ignore_owner28(body)
		_pieces.append({"body":weakref(body),"expires":expires})
		shared_bodies.append(weakref(body))
	_released=true
	last={"released":true,"count":count,"position":opening,"frame":Engine.get_process_frames(),"spawn_usec":Time.get_ticks_usec()-begun}

func status() -> Dictionary:
	return {"live":_pieces.size(),"released":_released,"last":last,"prewarmed":_gut!=null}
