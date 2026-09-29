extends RefCounted
## Source presentation contact selection and triangle coordinates. No HP/hit authority.
## A durable anchor still needs the host's actual actor/mesh/resource lifetime binding.
## All ports are caller-owned synchronous local contracts; a success is geometry only.
const MAX_ACTORS := 512
const MAX_PARTS := 256
const MAX_VERTICES := 65536
const MAX_TRIANGLES := 131072
const ROW_WIDTH := 16
var _current: Callable
var _query: Callable
var _occlusion: Callable
var _ready := false
var _busy := false
var _interrupted := false
var _serial := 0

func configure(current: Callable, query_candidates: Callable, occlusion: Callable) -> bool:
	if _busy: _interrupted=true; return false
	if _ready or not Thread.is_main_thread(): return false
	if not current.is_valid() or not query_candidates.is_valid() or not occlusion.is_valid(): return false
	if current.get_argument_count()!=1 or query_candidates.get_argument_count()!=2 or occlusion.get_argument_count()!=1: return false
	_current=current;_query=query_candidates;_occlusion=occlusion;_ready=true
	return true

func dispose() -> void:
	_ready=false;_interrupted=true;_current=Callable();_query=Callable();_occlusion=Callable()

func _live() -> bool:
	return _ready and not _interrupted and _current.is_valid() and _query.is_valid() and _occlusion.is_valid()

static func _error(reason: String) -> Dictionary:return {"valid":false,"hit":false,"reason":reason}
static func _true(value: Variant) -> bool:return value is bool and value
static func _same_id(a: Variant,b: Variant) -> bool:return typeof(a)==typeof(b) and a==b
static func _number(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value))
static func _finite_vec(value: Variant) -> bool:return value is Vector3 and value.is_finite()

func _actor_current(actor: Dictionary) -> bool:
	if not _live(): return false
	var result: Variant=_current.call(actor)
	return _live() and _true(result)

func select(input: Dictionary, actors: Array) -> Dictionary:
	if not Thread.is_main_thread(): return _error("thread")
	if _busy: _interrupted=true; return _error("reentry")
	if not _ready: return _error("unbound")
	_busy=true;_interrupted=false;_serial+=1
	var result:=_select(input,actors)
	if not _live(): result=_error("owner_changed_or_reentry")
	_busy=false
	return result

func _attacks(input: Dictionary) -> Array[Dictionary]:
	var source: Variant=input.get("contacts")
	var rows: Array=[input] if source==null else source if source is Array else []
	var result: Array[Dictionary]=[]
	if rows.is_empty() or rows.size()>4: return result
	var type: String=str(input.get("attackType",""))
	var default_radius:=.14 if "kick" in type.to_lower() or "foot" in type.to_lower() else .10
	for index in rows.size():
		if not rows[index] is Dictionary: return []
		var row: Dictionary=rows[index]
		var from: Variant=row.get("previous");if from==null:from=row.get("from")
		var to: Variant=row.get("current");if to==null:to=row.get("to")
		var radius: Variant=row.get("radius");if radius==null:radius=input.get("radius");if radius==null:radius=default_radius
		if not _finite_vec(from) or not _finite_vec(to) or not _number(radius) or radius<=0 or radius>.5: return []
		result.append({"from":from,"to":to,"radius":float(radius),"sweep_index":index})
	return result

static func _near(center: Vector3, attack: Dictionary) -> bool:
	# Scalar double arithmetic preserves the source center-to-segment test.
	var a: Vector3=attack.from;var b: Vector3=attack.to
	var center_y:=float(center.y)+1.0
	var x:=float(b.x)-a.x;var y:=float(b.y)-a.y;var z:=float(b.z)-a.z
	var squared:=x*x+y*y+z*z;var t:=0.0
	if squared!=0:t=clampf(((float(center.x)-a.x)*x+(center_y-a.y)*y+(float(center.z)-a.z)*z)/squared,0,1)
	x=float(a.x)+x*t-center.x;y=float(a.y)+y*t-center_y;z=float(a.z)+z*t-center.z
	return x*x+y*y+z*z<=9.0

static func _radius_gate(a: Vector3,b: Vector3,c: Vector3,attack: Dictionary) -> bool:
	var from: Vector3=attack.from;var to: Vector3=attack.to;var r: float=attack.radius
	for axis in 3:
		if maxf(a[axis],maxf(b[axis],c[axis]))<minf(from[axis],to[axis])-r or minf(a[axis],minf(b[axis],c[axis]))>maxf(from[axis],to[axis])+r:return false
	return true

func _ray_clear(actor: Dictionary, token: Variant, from: Vector3, point: Vector3, kind: String) -> Dictionary:
	var dx:=float(point.x)-from.x;var dy:=float(point.y)-from.y;var dz:=float(point.z)-from.z
	var distance:=sqrt(dx*dx+dy*dy+dz*dz)
	if distance<=1e-8:return {"valid":true,"clear":true}
	if not _actor_current(actor):return _error("stale_actor")
	var response: Variant=_occlusion.call({"phase":"ray","token":token,"from":from,"to":point,"kind":kind,"actor_id":actor.actor_id})
	if not _live() or not _actor_current(actor):return _error("stale_actor")
	if not response is Dictionary or not _true(response.get("valid")) or not response.has("distance"):return _error("occlusion_unavailable")
	var wall: Variant=response.distance
	if wall!=null and (not _number(wall) or float(wall)<0 or float(wall)>distance+1e-5):return _error("occlusion_distance")
	return {"valid":true,"clear":wall==null or float(wall)>=distance-1e-5}

func _select(input: Dictionary, actors: Array) -> Dictionary:
	if input.get("active") is bool and input.active==false:return {"valid":true,"hit":false}
	if actors.size()>MAX_ACTORS:return _error("actor_limit")
	if input.has("attackType") and not (input.attackType is String or input.attackType is StringName):return _error("attack_type")
	var attacks:=_attacks(input)
	if attacks.is_empty():return _error("attack_input")
	if not _live():return _error("ports")
	var scene: Variant=_occlusion.call({"phase":"begin"})
	if not _live() or not scene is Dictionary or not _true(scene.get("valid")) or not scene.get("blocker_count") is int or scene.blocker_count<0 or not scene.has("token") or scene.token==null:return _error("occlusion_snapshot")
	var best: Dictionary={};var best_score:=INF;var best_actor: Dictionary={}
	var origin: Variant=input.get("origin")
	for actor_value: Variant in actors:
		if not actor_value is Dictionary:return _error("actor_schema")
		var actor: Dictionary=actor_value
		if not actor.has("actor_id") or not (actor.actor_id is String or actor.actor_id is int) or not _finite_vec(actor.get("root_position")) or not actor.get("visible") is bool or not actor.get("receipt") is Dictionary or actor.receipt.is_empty():return _error("actor_schema")
		if not _actor_current(actor):return _error("stale_actor")
		if (input.has("excludeId") and _same_id(actor.actor_id,input.excludeId)) or not actor.visible:continue
		var near: Array[Dictionary]=[];var center: Vector3=actor.root_position
		for attack: Dictionary in attacks:
			if _near(center,attack):near.append(attack)
		if near.is_empty():continue
		var parts: Variant=actor.get("parts")
		if not parts is Array or parts.size()>MAX_PARTS:return _error("parts")
		var faces:=0;var vertices:=0;var any_visible:=false;var last_mesh_order:=-1
		for index in parts.size():
			var part: Variant=parts[index]
			if not part is Dictionary or not part.get("mesh_id") is String or not part.get("mesh_order") is int or part.mesh_order<=last_mesh_order or not part.get("visible") is bool or not part.get("world_vertices") is PackedVector3Array or not part.get("indices") is PackedInt32Array or not part.get("head_slot_weights") is PackedFloat32Array:return _error("part_schema")
			last_mesh_order=part.mesh_order
			if part.get("triangle_first")!=faces or part.get("vertex_first")!=vertices or part.indices.size()%3!=0 or part.head_slot_weights.size()!=part.world_vertices.size()*4:return _error("part_topology")
			faces+=part.indices.size()/3;vertices+=part.world_vertices.size();any_visible=any_visible or part.visible
		if faces>MAX_TRIANGLES or vertices>MAX_VERTICES:return _error("topology_limit")
		if not any_visible or faces==0:continue
		var request:={"key":str(get_instance_id())+":"+str(_serial),"receipt":actor.receipt.duplicate(true),"contacts":near.duplicate(true)}
		var queried: Variant=_query.call(actor,request)
		if not _live() or not _actor_current(actor):return _error("stale_actor")
		if not queried is Dictionary or not _true(queried.get("valid")) or not _true(queried.get("complete")) or queried.get("key")!=request.key or queried.get("receipt")!=request.receipt or not queried.get("rows") is PackedFloat64Array:return _error("query_incomplete_or_mismatched")
		var rows: PackedFloat64Array=queried.rows
		if rows.size()%ROW_WIDTH!=0 or rows.size()/ROW_WIDTH>faces*near.size():return _error("query_shape")
		for value: float in rows:
			if not is_finite(value):return _error("query_nonfinite")
		var order: Array[int]=[]
		for row in rows.size()/ROW_WIDTH:
			var at: int=row*ROW_WIDTH
			if rows[at]!=floor(rows[at]) or rows[at]<0 or rows[at]>=faces or rows[at+1]!=floor(rows[at+1]) or rows[at+1]<0 or rows[at+1]>=near.size() or rows[at+14]<0 or rows[at+15]<0:return _error("query_index_or_score")
			order.append(at)
		order.sort_custom(func(a:int,b:int)->bool:return rows[a]<rows[b] if rows[a]!=rows[b] else rows[a+1]<rows[b+1])
		var part_index:=0;var previous_triangle:=-1;var previous_sweep:=-1
		for at: int in order:
			var face:=int(rows[at]);var limb:=int(rows[at+1])
			if face==previous_triangle and limb==previous_sweep:return _error("duplicate_candidate")
			previous_triangle=face;previous_sweep=limb
			while part_index<parts.size() and face>=int(parts[part_index].triangle_first)+parts[part_index].indices.size()/3:part_index+=1
			if part_index>=parts.size():return _error("face_mapping")
			var part: Dictionary=parts[part_index]
			if not part.visible:continue
			var local_face: int=face-int(part.triangle_first);var indices: PackedInt32Array=part.indices
			var ia:=indices[local_face*3];var ib:=indices[local_face*3+1];var ic:=indices[local_face*3+2]
			var points: PackedVector3Array=part.world_vertices
			if mini(ia,mini(ib,ic))<0 or maxi(ia,maxi(ib,ic))>=points.size() or not points[ia].is_finite() or not points[ib].is_finite() or not points[ic].is_finite():return _error("triangle_vertices")
			var attack: Dictionary=near[limb]
			if not _radius_gate(points[ia],points[ib],points[ic],attack) or rows[at+15]>attack.radius*attack.radius+1e-10 or rows[at+14]>=best_score:continue
			var point:=Vector3(rows[at+2],rows[at+3],rows[at+4])
			var clear:=_ray_clear(actor,scene.token,attack.from,point,"limb")
			if not clear.valid:return clear
			if not clear.clear:continue
			if _finite_vec(origin) and scene.blocker_count>0:
				clear=_ray_clear(actor,scene.token,origin,point,"origin")
				if not clear.valid:return clear
				if not clear.clear:continue
			var nx:=rows[at+8];var ny:=rows[at+9];var nz:=rows[at+10]
			var dx:=rows[at+5]-rows[at+2];var dy:=rows[at+6]-rows[at+3];var dz:=rows[at+7]-rows[at+4]
			var flip:=nx*dx+ny*dy+nz*dz<0
			if dx*dx+dy*dy+dz*dz<=1e-12:
				var from: Vector3=attack.from;var to: Vector3=attack.to
				flip=nx*(float(to.x)-from.x)+ny*(float(to.y)-from.y)+nz*(float(to.z)-from.z)>0
			var head:=0.0;var weights: PackedFloat32Array=part.head_slot_weights;var face_ids: Array[int]=[ia,ib,ic]
			for corner in 3:
				for slot in 4:
					var weight:=float(weights[face_ids[corner]*4+slot])
					if not is_finite(weight) or weight<0 or weight>1:return _error("head_weights")
					head+=weight*rows[at+11+corner]
			best_score=rows[at+14]
			best={"actor_id":actor.actor_id,"mesh_id":part.mesh_id,"face_index":local_face,"indices":PackedInt32Array(face_ids),"point":point,"normal":Vector3(nx,ny,nz)*(-1 if flip else 1),"zone":"head" if head>=.5 else "body","distance":sqrt(best_score),"attack_type":str(input.get("attackType","punch")) if not str(input.get("attackType","")).is_empty() else "punch","sweep_index":attack.sweep_index,"receipt":actor.receipt.duplicate(true)}
			# Preserve the exact barycentric output for the original face order.
			# Do not normalize weights or manufacture browser UUIDs for native meshes.
			best.weights=PackedFloat64Array([rows[at+11],rows[at+12],rows[at+13]])
			best.normal_side=-1 if (points[ib]-points[ia]).cross(points[ic]-points[ia]).dot(best.normal)<0 else 1
			best_actor=actor
		if not _actor_current(actor):return _error("stale_actor")
	# A later actor's synchronous query/occlusion callback can retire the earlier
	# winner. Its validation inside that earlier iteration is no longer sufficient.
	if not best.is_empty() and not _actor_current(best_actor):return _error("stale_winner")
	return {"valid":true,"hit":not best.is_empty(),"contact":best} if not best.is_empty() else {"valid":true,"hit":false}
