extends "res://scripts/combat/spear_contact_resume29.gd"
## The pose is committed only after exact posed target surfaces are clear.
## Damage is a host callback; accepting damage or queuing a cut grants no passage.
const Profile=preload("res://scripts/combat/weapon_contact_profile29.gd")
const Segment=preload("res://scripts/combat/segment_triangle29.gd")
const BindBVH=preload("res://scripts/combat/contact_bvh31.gd")
const GAP := .003
const CELL := .05
var _samples:Array[Dictionary]=[]
var _static_points:=PackedVector3Array()
var _static_min:=PackedVector3Array()
var _static_max:=PackedVector3Array()
var _sample_identity:=0
var _triangles:Array[Dictionary]=[]
var _grid:Dictionary={}
var _pose_stamp:=0
var _contact_times:Dictionary={}
var _hold:Dictionary={}
var _last_good_player:=Vector3.ZERO
var _last_good_rig:=Transform3D.IDENTITY
var _last_good_transform:=Transform3D.IDENTITY
var _publish_safe:=true
var exact_checks:=0
var rejected_fallbacks:=0
var walk_blocks:=0
var _resolving_overlap:=false
var _target_bounds:=AABB()
var _safe_full_pose:Array[Transform3D]=[]
var _safe_rig_local:=Transform3D.IDENTITY
var holder_rollbacks:=0
var _geometry_frame:=-1
var geometry_builds:=0
var geometry_usec:=0
var max_solver_usec:=0
var _last_solver_begun:=0
var _dispatch_frames:Dictionary={}
var recovery_moves:=0
var _profile_bounds:=AABB()
var _query_bounds:=AABB()
var _safe_ancestors:Array[Dictionary]=[]
var _cached_poses:Array[Transform3D]=[]
var _structure_stamp:=0
var sweep_usec:=0
var static_usec:=0
var ik_usec:=0
var world_usec:=0
var _last_contact_was_safe:=false
var solver_calls:=0
var solver_usec:=0
var last_solver_usec:=0
var _triangle_seen:=PackedInt32Array()
var _segment_epoch:=0
var segment_calls:=0
var grid_visits:=0
var triangle_candidates:=0
var _candidate_obstruction:Dictionary={}
var _accepted_bore_frame:=Transform3D.IDENTITY
var _accepted_bore_id:=0
var early_safe_fallbacks:=0
var recovery_native_blocks:=0
var recovery_attempts:=0
var _world_obstruction:Dictionary={}
var _phase_running:=false
var _phase_prepared:=false
var prepare_usec:=0
var dynamic_egress:=0
var walk_calls:=0
var walk_usec:=0
var _phase_profiles:Dictionary={}
var _rigid_views:Array[Dictionary]=[]
var _posed_trees31:Dictionary={}
var rigid_triangles31:=0
var mixed_triangles31:=0
var bvh_builds31:=0
var bvh_build_usec31:=0
var skin_hits_usec31:=0
var _surface_sources31:Dictionary={}
var entry_collar_admissions31:=0

func _enabled(host:Node)->bool:
	return str(host.get("_weapon_id")) in ["sword","axe","mace","sledge","spear"] and not host.get("_sword_grounded") and not host.get("_unarmed") and host.get("_selected") and not host.get("_throwing") and not host.get("_spear_cast_pending31") and not bool(host.get("_world").get("preview_dead"))

func owns_body_contacts(host:Node)->bool:
	return _enabled(host)

func invalidate(reason:String="reset")->void:
	super.invalidate(reason)
	_hold.clear();_contact_times.clear();_dispatch_frames.clear();_samples.clear();_sample_identity=0;_pose_stamp=0;_geometry_frame=-1
	_accepted_bore_id=0
	_posed_trees31.clear()

func warm_contact31(host:Node)->Dictionary:
	if not is_instance_valid(host.get("_sword")) or not is_instance_valid(host.get("_npc_rig")):
		return {"ready":false,"reason":"weapon_or_actor_missing"}
	var begun:=Time.get_ticks_usec()
	_prepare(host)
	return {"ready":true,"usec":Time.get_ticks_usec()-begun,"rigid_triangles":rigid_triangles31,"mixed_triangles":mixed_triangles31,"shared":preload("res://scripts/combat/contact_topology_cache31.gd").report()}

func _prepare(host:Node,required:AABB=AABB())->void:
	var begun:=Time.get_ticks_usec()
	_prepare_impl(host,required)
	prepare_usec+=Time.get_ticks_usec()-begun

func _skin_nodes(host:Node)->Array:
	# Read live format metadata; surface_get_arrays downloads every vertex stream.
	# Traversal stays live so replaced meshes, reset and newly cut pieces are seen.
	var rig:Skeleton3D=host.get("_npc_rig")
	var result:Array=[]
	if not is_instance_valid(rig) or rig.get_parent()==null:return result
	for node:MeshInstance3D in rig.get_parent().find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ArrayMesh:continue
		for surface in node.mesh.get_surface_count():
			if (node.mesh.surface_get_format(surface)&Mesh.ARRAY_FORMAT_BONES)!=0 and node.mesh.surface_get_array_len(surface)>0:
				result.append(node);break
	return result

func _skin_batches(data:Dictionary,group:Dictionary,bind_count:int)->Dictionary:
	# Topology-owned cache contains only immutable bind-space indices/points.
	# Puncture replaces the topology object when mesh/skin/rig identity changes.
	if group.has("solid_batches29") and int(group.solid_batches29.bind_count)==bind_count:return group.solid_batches29
	var rigid:Dictionary={};var mixed:=PackedInt32Array()
	for vertex:int in group.vertices:
		var influence:=-1;var count:=0;var weight:=0.0
		for slot in 4:
			var k:=vertex*4+slot
			if k>=data.weights.size() or data.weights[k]<=0 or data.bones[k]<0 or data.bones[k]>=bind_count:continue
			count+=1;influence=data.bones[k];weight=data.weights[k]
		if count==1 and weight==1.0:
			if not rigid.has(influence):rigid[influence]={"bind":influence,"vertices":PackedInt32Array(),"points":PackedVector3Array()}
			rigid[influence].vertices.append(vertex);rigid[influence].points.append(data.points[vertex])
		else:mixed.append(vertex)
	var result:Dictionary={"bind_count":bind_count,"rigid":rigid.values(),"mixed":mixed}
	group.solid_batches29=result
	return result

func _bind_partition31(data:Dictionary,bind_count:int)->Dictionary:
	if data.has("solid_bind31") and int(data.solid_bind31.bind_count)==bind_count:return data.solid_bind31
	var begun:=Time.get_ticks_usec()
	var result:Dictionary=preload("res://scripts/combat/contact_build31.gd").partition(data,bind_count)
	bvh_builds31+=result.rigid.size()
	bvh_build_usec31+=Time.get_ticks_usec()-begun
	return result

func _prepare_impl(host:Node,required:AABB=AABB())->void:
	var weapon:Node3D=host.get("_sword")
	if _sample_identity!=weapon.get_instance_id():
		_samples=Profile.build(host);_sample_identity=weapon.get_instance_id()
		_static_points.clear();_static_min.clear();_static_max.clear();_phase_prepared=false
		var edges:=Profile.build_edges(host)
		edges.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return minf(a.edge_from.x,a.edge_to.x)<minf(b.edge_from.x,b.edge_to.x))
		for edge:Dictionary in edges:
			_static_points.append(edge.edge_from);_static_points.append(edge.edge_to)
			_static_min.append(Vector3(edge.edge_from).min(edge.edge_to));_static_max.append(Vector3(edge.edge_from).max(edge.edge_to))
		if not _samples.is_empty():
			_profile_bounds=AABB(_samples[0].local,Vector3.ZERO)
			for row:Dictionary in _samples:_profile_bounds=_profile_bounds.expand(row.local)
			for point:Vector3 in _static_points:_profile_bounds=_profile_bounds.expand(point)
	var frame:=Engine.get_process_frames()
	var requested_bounds:AABB=weapon.global_transform*_profile_bounds
	if _ready:requested_bounds=requested_bounds.merge(_last_good_transform*_profile_bounds)
	if required.size.length_squared()>0:requested_bounds=requested_bounds.merge(required)
	if _phase_running and _phase_prepared and _query_bounds.encloses(requested_bounds):return
	_geometry_frame=frame
	var rig:Skeleton3D=host.get("_npc_rig")
	if not is_instance_valid(rig):return
	var nodes:Array=_skin_nodes(host)
	var structure:Array=[host.get("lab_resets"),rig.get_instance_id()]
	var poses:Array[Transform3D]=[rig.global_transform]
	for bone in rig.get_bone_count():poses.append(rig.global_transform*rig.get_bone_global_pose(bone))
	for node:MeshInstance3D in nodes:
		poses.append(node.global_transform);structure.append(node.get_instance_id());structure.append(node.mesh.get_instance_id() if node.mesh!=null else 0);structure.append(node.skin.get_instance_id() if node.skin!=null else 0);structure.append(node.is_visible_in_tree())
	var stamp:=hash(structure)
	if stamp==_structure_stamp and _near_pose(poses,_cached_poses) and _query_bounds.encloses(requested_bounds):_phase_prepared=true;return
	requested_bounds=requested_bounds.grow(.055)
	var begun:=Time.get_ticks_usec();geometry_builds+=1
	_structure_stamp=stamp;_cached_poses=poses
	_pose_stamp=stamp;_triangles.clear();_grid.clear();_rigid_views.clear();_surface_sources31.clear();_target_bounds=AABB();_query_bounds=requested_bounds
	var first_target:=true;var order_offset:=0;var live_trees:Dictionary={}
	rigid_triangles31=0;mixed_triangles31=0
	for node:MeshInstance3D in nodes:
		if node.mesh==null or not node.is_visible_in_tree():continue
		var binds:Array[Transform3D]=host.call("_cut_skin_transforms39",node)
		var surface_index:=0
		for data:Dictionary in Puncture._topology(host,node):
			var source_key:="%s:%s:%s"%[node.get_instance_id(),node.mesh.get_instance_id(),surface_index]
			surface_index+=1
			_surface_sources31[source_key]={"node":weakref(node),"mesh_id":node.mesh.get_instance_id(),"skin_id":node.skin.get_instance_id() if node.skin!=null else 0,"data":data,"binds":binds,"transform":node.global_transform}
			var partition:=_bind_partition31(data,binds.size())
			for view:Dictionary in partition.rigid:
				var tree_key:="%s:%s"%[node.get_instance_id(),view.tree.get_instance_id()]
				live_trees[tree_key]=true
				if not _posed_trees31.has(tree_key):_posed_trees31[tree_key]=view.tree.instantiate_pose31()
				var tree:RefCounted=_posed_trees31[tree_key]
				tree.set_transform(node.global_transform*(binds[view.bind] if view.bind>=0 else Transform3D.IDENTITY))
				var part:String=str(rig.get_bone_name(view.bone)) if view.bone>=0 else "chest"
				_rigid_views.append({"tree":tree,"bone":view.bone,"part":part,"family":Puncture._family(part),"order":order_offset,"source_key":source_key})
				rigid_triangles31+=tree.orders.size()
				_target_bounds=tree.world_bounds if first_target else _target_bounds.merge(tree.world_bounds);first_target=false
			if partition.mixed.is_empty():
				order_offset+=int(partition.triangles)
				continue
			var posed:=PackedVector3Array();posed.resize(data.points.size())
			var posed_flags:=PackedByteArray();posed_flags.resize(data.points.size())
			for group:Dictionary in partition.mixed:
				var group_bounds:=AABB();var first_bound:=true
				for influence:int in group.bounds:
					var transform:Transform3D=node.global_transform*(binds[influence] if influence>=0 else Transform3D.IDENTITY)
					var box:AABB=transform*group.bounds[influence]
					group_bounds=box if first_bound else group_bounds.merge(box);first_bound=false
				if group.safe_bounds and not group_bounds.intersects(_query_bounds):continue
				var batches:=_skin_batches(data,group,binds.size())
				for batch:Dictionary in batches.rigid:
					var transformed:PackedVector3Array=(node.global_transform*binds[batch.bind])*PackedVector3Array(batch.points)
					for index in batch.vertices.size():
						var vertex:int=batch.vertices[index]
						posed[vertex]=transformed[index];posed_flags[vertex]=1
				for vertex:int in batches.mixed:
					if posed_flags[vertex]!=0:continue
					var position:=Vector3.ZERO;var total:=0.0
					for slot in 4:
						var k:=vertex*4+slot
						if k>=data.weights.size() or data.weights[k]<=0 or data.bones[k]<0 or data.bones[k]>=binds.size():continue
						position+=(binds[data.bones[k]]*data.points[vertex])*data.weights[k];total+=data.weights[k]
					posed[vertex]=node.to_global(position if total>0 else data.points[vertex]);posed_flags[vertex]=1
				var part:String=str(rig.get_bone_name(group.bone)) if group.bone>=0 else "chest"
				for i in range(0,group.indices.size(),3):
					var a:Vector3=posed[group.indices[i]];var b:Vector3=posed[group.indices[i+1]];var c:Vector3=posed[group.indices[i+2]]
					var normal:Vector3=(b-a).cross(c-a).normalized()
					if normal.length_squared()<.5:continue
					var bounds:=AABB(a,Vector3.ZERO).expand(b).expand(c).grow(.0001)
					if not bounds.intersects(_query_bounds):continue
					var index:=_triangles.size()
					_target_bounds=bounds if first_target else _target_bounds.merge(bounds);first_target=false
					_triangles.append({"a":a,"b":b,"c":c,"normal":normal,"bounds":bounds,"bone":group.bone,"part":part,"family":Puncture._family(part),"order":order_offset+group.orders[i/3],"face":group.orders[i/3],"source_key":source_key})
					mixed_triangles31+=1
					for key:Vector3i in _cells(bounds):
						if not _grid.has(key):_grid[key]=[]
						_grid[key].append(index)
			order_offset+=int(partition.triangles)
	for tree_key:String in _posed_trees31.keys():
		if not live_trees.has(tree_key):_posed_trees31.erase(tree_key)
	geometry_usec+=Time.get_ticks_usec()-begun
	_triangle_seen.resize(_triangles.size());_triangle_seen.fill(0);_segment_epoch=0
	_phase_prepared=true

func _near_pose(a:Array[Transform3D],b:Array[Transform3D])->bool:
	# Exact poses: a small stale offset can still change a near-skin empty query.
	return a==b

func _axial_tip(host:Node,step:Vector3,axis:Vector3)->bool:
	return not bool(host.get("_weapon_crush")) and str(host.get("_weapon_id")) in ["sword","spear"] and step.length_squared()>1e-12 and step.normalized().dot(axis.normalized())>.80

func _contact_gap(host:Node,contact:Dictionary,transform:Transform3D)->float:
	# The actual foremost point may approach the skin continuously at any speed.
	# Side/shaft samples retain the normal clearance and never inherit this margin.
	if str(host.get("_weapon_id")) in ["sword","spear"] and Vector3(contact.sample_local).distance_squared_to(Puncture.tip_local(host))<.002*.002 and transform.basis.x.normalized().dot(-Vector3(contact.normal))>.80:
		return 0.0
	return GAP

func _cells(bounds:AABB)->Array[Vector3i]:
	var cells:Array[Vector3i]=[]
	var low:=Vector3i(floori(bounds.position.x/CELL),floori(bounds.position.y/CELL),floori(bounds.position.z/CELL))
	var high:=Vector3i(floori(bounds.end.x/CELL),floori(bounds.end.y/CELL),floori(bounds.end.z/CELL))
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for z in range(low.z,high.z+1):cells.append(Vector3i(x,y,z))
	return cells

func _ray_cells(from:Vector3,to:Vector3)->Array[Vector3i]:
	# Amanatides-Woo traversal visits the ray, rather than the volume of its AABB.
	# Triangle cell bounds are expanded by 0.1mm, so exact corner/edge touches
	# are also present in the cells on either side of a simultaneous boundary.
	var cell:=Vector3i(floori(from.x/CELL),floori(from.y/CELL),floori(from.z/CELL))
	var end:=Vector3i(floori(to.x/CELL),floori(to.y/CELL),floori(to.z/CELL))
	var direction:=to-from
	var step:=Vector3i(signi(int(signf(direction.x))),signi(int(signf(direction.y))),signi(int(signf(direction.z))))
	var next:=Vector3(INF,INF,INF);var increment:=Vector3(INF,INF,INF)
	for axis in 3:
		if step[axis]!=0:
			next[axis]=((cell[axis]+(1 if step[axis]>0 else 0))*CELL-from[axis])/direction[axis]
			increment[axis]=CELL/absf(direction[axis])
	var result:Array[Vector3i]=[]
	var distance:=end-cell
	for iteration in absi(distance.x)+absi(distance.y)+absi(distance.z)+4:
		result.append(cell)
		if cell==end:break
		var crossing:=minf(next.x,minf(next.y,next.z))
		if crossing>1.000001:break
		for axis in 3:
			if next[axis]<=crossing+0.00000001:
				cell[axis]+=step[axis];next[axis]+=increment[axis]
	return result

func _segment(from:Vector3,to:Vector3)->Dictionary:
	segment_calls+=1
	if from.distance_squared_to(to)<.0000000001:return {}
	if not _target_bounds.intersects_segment(from,to):return {}
	_segment_epoch+=1
	if _segment_epoch>=2147483647:_triangle_seen.fill(0);_segment_epoch=1
	var best:Dictionary={}
	for key:Vector3i in _ray_cells(from,to):
		grid_visits+=1
		for index:int in _grid.get(key,[]):
			if _triangle_seen[index]==_segment_epoch:continue
			_triangle_seen[index]=_segment_epoch;triangle_candidates+=1
			var triangle:Dictionary=_triangles[index]
			if not triangle.bounds.intersects_segment(from,to):continue
			exact_checks+=1
			var point:Variant=Segment.intersect(from,to,triangle.a,triangle.b,triangle.c)
			if point==null:continue
			var fraction:=from.distance_to(point)/from.distance_to(to)
			if not best.is_empty() and fraction>=float(best.fraction):continue
			var normal:Vector3=triangle.normal
			if normal.dot(to-from)>0:normal=-normal
			best={"position":point,"normal":normal,"fraction":fraction,"part":triangle.part,"bone":triangle.bone,"source_key":triangle.source_key,"face":triangle.face}
	for view:Dictionary in _rigid_views:
		var tree:RefCounted=view.tree
		var old_candidates:int=tree.candidates;var old_exact:int=tree.exact;var old_visits:int=tree.visits
		var hits:Array=tree.intersections(from,to)
		triangle_candidates+=tree.candidates-old_candidates;exact_checks+=tree.exact-old_exact;grid_visits+=tree.visits-old_visits
		if hits.is_empty():continue
		var hit:Dictionary=hits[0]
		if not best.is_empty() and float(hit.fraction)>=float(best.fraction):continue
		hit.part=view.part;hit.bone=view.bone;hit.source_key=view.source_key;hit.face=hit.order
		best=hit
	return best

func skin_hits(host:Node,from:Vector3,to:Vector3,part:String="")->Array[Dictionary]:
	var begun:=Time.get_ticks_usec()
	var hits:Array[Dictionary]=[]
	if from.distance_squared_to(to)<=1e-20:return hits
	_prepare(host,AABB(from,Vector3.ZERO).expand(to).grow(.0001))
	var family:=Puncture._family(part)
	var raw:Array[Dictionary]=[]
	for view:Dictionary in _rigid_views:
		if not part.is_empty() and str(view.family)!=family:continue
		for hit:Dictionary in view.tree.intersections(from,to,true):
			raw.append({"point":hit.position,"bone":view.bone,"normal":hit.normal,"order":int(view.order)+int(hit.order)})
	_segment_epoch+=1
	if _segment_epoch>=2147483647:_triangle_seen.fill(0);_segment_epoch=1
	for cell:Vector3i in _ray_cells(from,to):
		for index:int in _grid.get(cell,[]):
			if _triangle_seen[index]==_segment_epoch:continue
			_triangle_seen[index]=_segment_epoch
			var triangle:Dictionary=_triangles[index]
			if not part.is_empty() and str(triangle.family)!=family:continue
			if not triangle.bounds.intersects_segment(from,to):continue
			var point:Variant=Segment.intersect(from,to,triangle.a,triangle.b,triangle.c)
			if point==null:continue
			var normal:Vector3=triangle.normal
			if normal.dot(to-from)>0:normal=-normal
			raw.append({"point":point,"bone":triangle.bone,"normal":normal,"order":triangle.order})
	# Preserve authored traversal order for the same 1mm duplicate rule used by
	# Puncture._hits, including shared seams between two body-part surfaces.
	raw.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.order)<int(b.order))
	for hit:Dictionary in raw:
		var duplicate:=false
		for old:Dictionary in hits:
			if Vector3(old.point).distance_to(hit.point)<.001:duplicate=true;break
		if not duplicate:hits.append({"point":hit.point,"bone":hit.bone,"normal":hit.normal})
	hits.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return from.distance_squared_to(a.point)<from.distance_squared_to(b.point))
	skin_hits_usec31+=Time.get_ticks_usec()-begun
	return hits

func _bore_frame(host:Node,node:Node3D)->Transform3D:
	var controller:Node=host.get_meta("local_wound28_controller",null)
	if is_instance_valid(controller):
		for wound:Dictionary in controller.wounds:
			if wound.node==node:
				var rig:Skeleton3D=host.get("_npc_rig")
				return rig.global_transform*rig.get_bone_global_pose(int(wound.bone))*Transform3D(wound.local)
	return node.global_transform

func _tip_profile(host:Node,depth:float)->Vector2:
	if not _phase_running:return Puncture.tip_profile(host,depth)
	var key:Array=[host.get("_sword").get_instance_id(),depth]
	if not _phase_profiles.has(key):_phase_profiles[key]=Puncture.tip_profile(host,depth)
	return _phase_profiles[key]

var bore_reject31:Array=[]
var _bore_reject_frame31:=-1
func _bore_rejected31(host:Node,reason:String,data:Dictionary)->bool:
	if not bool(host.get_meta("debug_bore31",false)):return false
	var frame:=Engine.get_physics_frames()
	if frame!=_bore_reject_frame31:bore_reject31.clear();_bore_reject_frame31=frame
	if bore_reject31.size()<8:
		data["reason"]=reason;data["frame"]=frame;bore_reject31.append(data)
	return false

func _collar_triangle31(source:Dictionary,face:int)->PackedVector3Array:
	var data:Dictionary=source.data
	if face<0 or face>=data.entry_faces31.size():return PackedVector3Array()
	var result:=PackedVector3Array();var indices:Vector3i=data.entry_faces31[face]
	for vertex:int in [indices.x,indices.y,indices.z]:
		var point:=Vector3.ZERO;var total:=0.0
		for slot in 4:
			var k:=vertex*4+slot
			if k>=data.weights.size() or data.weights[k]<=0 or data.bones[k]<0 or data.bones[k]>=source.binds.size():continue
			point+=(Transform3D(source.binds[data.bones[k]])*Vector3(data.points[vertex]))*float(data.weights[k]);total+=float(data.weights[k])
		result.append(Transform3D(source.transform)*(point if total>0 else Vector3(data.points[vertex])))
	return result

func _seed_entry_collar31(host:Node,channel:Dictionary,frame:Transform3D)->void:
	# Establish identity only at original shallow entry. Never adopt a later hit,
	# another folded layer, or a deep channel after mesh replacement as its mouth.
	if channel.has("entry_collar31") or float(channel.get("cut_depth",0))>.015:return
	var tick:=Engine.get_physics_frames()
	if int(channel.get("entry_collar_seed_tick31",-1))==tick:return
	channel.entry_collar_seed_tick31=tick
	var hit:=_segment(frame*Vector3(0,0,.006),frame*Vector3(0,0,-.006))
	if hit.is_empty() or not _surface_sources31.has(hit.get("source_key","")):return
	var rig:Skeleton3D=host.get("_npc_rig")
	var bone:=int(channel.get("bone",-1))
	if bone<0 or Puncture._family(str(hit.part).replace("spine_01","spine"))!=Puncture._family(str(rig.get_bone_name(bone)).replace("spine_01","spine")):return
	var source:Dictionary=_surface_sources31[hit.source_key]
	var tri:=_collar_triangle31(source,int(hit.face))
	if tri.size()!=3:return
	var normal:Vector3=(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
	var sign_normal:=1.0 if normal.dot(frame.basis.z)>0 else -1.0
	var patch:Dictionary={int(hit.face):true};var frontier:Array=[int(hit.face)]
	for hop in 2:
		var next:Array=[]
		for face:int in frontier:
			for adjacent:int in source.data.entry_neighbors31[face]:
				if patch.has(adjacent) or patch.size()>=32:continue
				patch[adjacent]=true;next.append(adjacent)
		frontier=next
	channel.entry_collar31={"source_key":hit.source_key,"mesh_id":source.mesh_id,"skin_id":source.skin_id,"patch":patch,"normal_sign":sign_normal,"generation":channel.generation,"weapon_instance_id":channel.weapon_instance_id}

func _entry_surface_collar31(channel:Dictionary,frame:Transform3D,point:Vector3,world_hit:Vector3,known_hit:Dictionary={})->bool:
	if float(channel.get("cut_depth",0))<=.0001 or point.z<=.006 or point.z>.012:return false
	var collar:Dictionary=channel.get("entry_collar31",{})
	if collar.is_empty() or collar.generation!=channel.generation or collar.weapon_instance_id!=channel.weapon_instance_id:return false
	var key:String=collar.source_key
	if not _surface_sources31.has(key):return false
	var source:Dictionary=_surface_sources31[key]
	var node:MeshInstance3D=source.node.get_ref()
	if not is_instance_valid(node) or node.mesh==null or node.mesh.get_instance_id()!=int(collar.mesh_id) or (node.skin.get_instance_id() if node.skin!=null else 0)!=int(collar.skin_id):return false
	var normal:=frame.basis.z.normalized()
	var hit:=known_hit
	if hit.is_empty():hit=_segment(world_hit+normal*.00025,world_hit-normal*.00025)
	if hit.is_empty() or str(hit.get("source_key",""))!=key or not collar.patch.has(int(hit.get("face",-1))):return false
	var tri:=_collar_triangle31(source,int(hit.face))
	if tri.size()!=3:return false
	var surface_normal:Vector3=(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()*float(collar.normal_sign)
	if surface_normal.dot(normal)<.5:return false
	var actual:Variant=Segment.intersect(world_hit+normal*.00025,world_hit-normal*.00025,tri[0],tri[1],tri[2])
	if actual==null:return false
	var local:Vector3=frame.affine_inverse()*Vector3(actual)
	# Only the current entry surface grants this exterior collar. An endpoint
	# farther outside it still collides; no lateral/deep lane or damage grows.
	if local.z<.006 or local.z>.012 or point.z>local.z+.00025:return false
	entry_collar_admissions31+=1
	return true

func _channel_allows(host:Node,from:Vector3,to:Vector3,transform:Transform3D,moving:bool=false,actual_to:Vector3=Vector3.INF,hit_part:String="",surface_hit:Dictionary={})->bool:
	var channel:Dictionary=host.get_meta("puncture29_channel",{})
	if not channel.get("valid",false) or not channel.get("active",false) or not channel.get("actual_hit",false):return false
	if int(channel.get("generation",-1))!=int(host.get("lab_resets")) or int(channel.get("weapon_instance_id",-1))!=host.get("_sword").get_instance_id():return false
	if str(channel.get("weapon",""))!=str(host.get("_weapon_id")):return false
	var reference:WeakRef=channel.get("node_ref")
	var node:Node3D=reference.get_ref() if reference!=null else null
	if not is_instance_valid(node):return false
	# The slit admits actual blade steel, never a sword guard or grip following it.
	if str(host.get("_weapon_id"))=="sword":
		var steel_point:=transform.affine_inverse()*(actual_to if actual_to.is_finite() else to)
		if steel_point.x<.155:return false
	var frame:=_bore_frame(host,node)
	var width:=float(channel.get("radius",.004));var height:=width
	var controller:Node=host.get_meta("local_wound28_controller",null)
	if is_instance_valid(controller):
		for wound:Dictionary in controller.wounds:
			if wound.node==node:
				if not hit_part.is_empty() and Puncture._family(hit_part.replace("spine_01","spine"))!=Puncture._family(str(wound.part).replace("spine_01","spine")):return _bore_rejected31(host,"part",{"hit":hit_part,"wound":wound.part})
				width=wound.length;height=wound.width
				break
	_seed_entry_collar31(host,channel,frame)
	var axis:Vector3=-frame.basis.z.normalized()
	if transform.basis.x.normalized().dot(axis)<.985:return _bore_rejected31(host,"axis",{"dot":transform.basis.x.normalized().dot(axis)})
	var previous_frame:=_accepted_bore_frame if moving and float(channel.get("cut_depth",0))>.0001 and _accepted_bore_id==node.get_instance_id() else frame
	var relative_from:=previous_frame.affine_inverse()*from
	var relative_to:=frame.affine_inverse()*(actual_to if actual_to.is_finite() else to)
	# Prospective steel may open this already verified axial path, but injury
	# depth is committed only after the complete final pose is accepted.
	var local_tip:=frame.affine_inverse()*(transform*Puncture.tip_local(host))
	if Vector2(local_tip.x,local_tip.y).length()>maxf(width,.004)+.012:return _bore_rejected31(host,"tip_radial",{"tip":local_tip,"width":width})
	# Current posed steel defines prospective axial depth; initial rest-skin
	# thickness cannot block the exit of a deforming, already verified bore.
	var depth:=maxf(0.0,-local_tip.z)
	var profile:=_tip_profile(host,depth)
	width=maxf(width,profile.x);height=maxf(height,profile.y)
	# The airborne approach can be oblique. Only the trajectory behind the entry
	# plane must stay within the finite, verified aperture; target co-motion is
	# measured in its previous/current bone frame, never applied to the weapon.
	if moving:
		if relative_from.z>0 and relative_to.z<relative_from.z:
			relative_from=relative_from.lerp(relative_to,clampf(relative_from.z/(relative_from.z-relative_to.z),0,1))
		if relative_to.z>0 and relative_from.z<relative_to.z:
			relative_to=relative_from.lerp(relative_to,clampf(-relative_from.z/(relative_to.z-relative_from.z),0,1))
		for endpoint:Vector3 in [relative_from,relative_to]:
			if pow(endpoint.x/maxf(width+.002,.004),2)+pow(endpoint.y/maxf(height+.002,.004),2)>1.0:return _bore_rejected31(host,"swept_ellipse",{"endpoint":endpoint,"width":width,"height":height,"tip":local_tip})
	# A world-space sweep against the current skin includes target translation.
	# The full relative segment was checked above in both bore frames.
	var point:=relative_to if moving else frame.affine_inverse()*to
	var front_clear:=point.z<=.006
	if not front_clear and point.z<=.012:
		front_clear=_entry_surface_collar31(channel,frame,point,to,surface_hit)
	var permitted:=pow(point.x/maxf(width+.002,.004),2)+pow(point.y/maxf(height+.002,.004),2)<=1.0 and front_clear and -point.z<=maxf(depth,float(channel.get("cut_depth",0)))+.006
	if not permitted:return _bore_rejected31(host,"point",{"point":point,"width":width,"height":height,"tip":local_tip,"depth":depth,"cut_depth":channel.get("cut_depth",0),"moving":moving})
	return true

func query_sweep(host:Node,before:Transform3D,current:Transform3D)->Dictionary:
	var begun:=Time.get_ticks_usec()
	if _samples.is_empty():_prepare(host)
	_prepare(host,(before*_profile_bounds).merge(current*_profile_bounds))
	var best:Dictionary={}
	for row:Dictionary in _samples:
		var from:Vector3=before*Vector3(row.local);var to:Vector3=current*Vector3(row.local)
		var hit:=_segment(from,to)
		if not hit.is_empty() and _channel_allows(host,from,hit.position,current,true,to,str(hit.part),hit):continue
		if hit.is_empty() or (not best.is_empty() and float(hit.fraction)>=float(best.fraction)):continue
		hit.sample_local=row.local;hit.sample_x=Vector3(row.local).x
		hit.previous_sample=from;hit.current_sample=to;hit.motion=(to-from)/_delta;hit.travel=from.distance_to(to)
		hit.kind=Profile.kind(str(host.get("_weapon_id")),row,to-from,current.basis)
		best=hit
	sweep_usec+=Time.get_ticks_usec()-begun
	return best

func query_static(host:Node,current:Transform3D)->Dictionary:
	var begun:=Time.get_ticks_usec()
	if _samples.is_empty():_prepare(host)
	_prepare(host,current*_profile_bounds)
	var local_bounds:AABB=current.affine_inverse()*_target_bounds
	var low:=local_bounds.position;var high:=local_bounds.end
	for edge in _static_min.size():
		var edge_min:=_static_min[edge];var edge_max:=_static_max[edge]
		if edge_min.x>high.x:break
		if edge_max.x<low.x or edge_min.y>high.y or edge_max.y<low.y or edge_min.z>high.z or edge_max.z<low.z:continue
		var from:Vector3=current*_static_points[edge*2];var to:Vector3=current*_static_points[edge*2+1]
		var hit:=_segment(from,to)
		if hit.is_empty():continue
		# A static edge through a real existing axial bore is legitimate steel.
		if _channel_allows(host,hit.position,hit.position,current,false,Vector3.INF,str(hit.part),hit):continue
		hit.sample_local=current.affine_inverse()*Vector3(hit.position);hit.sample_x=Vector3(hit.sample_local).x
		if Vector3(hit.normal).dot(host.get("_player").global_position-Vector3(hit.position))<0:hit.normal=-Vector3(hit.normal)
		hit.previous_sample=hit.position;hit.current_sample=hit.position;hit.motion=Vector3.ZERO;hit.travel=0.0
		hit.kind="blunt";hit.fraction=0.0;hit.overlap=true
		static_usec+=Time.get_ticks_usec()-begun
		return hit
	static_usec+=Time.get_ticks_usec()-begun
	return {}

func _dispatch(host:Node,hit:Dictionary,before:Transform3D,current:Transform3D)->Dictionary:
	hit.exact_skin=true;hit.previous_transform=before;hit.current_transform=current
	hit.delta=_delta
	hit.weapon=str(host.get("_weapon_id"));hit.weapon_instance_id=host.get("_sword").get_instance_id();hit.generation=host.get("lab_resets")
	hit.collider=_part_collider(host,hit.part)
	var holder:CharacterBody3D=host.get("_player")
	var target:CharacterBody3D=host.get("_npc_body")
	var target_velocity:Vector3=target.velocity if is_instance_valid(target) else Vector3.ZERO
	var physical_velocity:Vector3=Vector3(host.get("_omega")).cross(current.basis*Vector3(hit.sample_local))+holder.velocity-target_velocity
	var raw:Vector3=hit.motion
	if raw.length_squared()<.0000001 and target_velocity.length_squared()>.000001:raw=-target_velocity
	hit.raw_motion=raw
	hit.physical_speed=physical_velocity.length()
	hit.motion=raw.limit_length(physical_velocity.length())
	var approach:Vector3=(Vector3(hit.current_sample)-Vector3(hit.previous_sample))*clampf(float(hit.fraction),0.0,1.0)
	var axis:=current.basis.x.normalized()
	hit.accepted_travel=(approach-axis*approach.dot(axis)).length()
	hit.approach_to=Vector3(hit.previous_sample)+approach
	var key:="%s:%s"%[hit.part,hit.kind]
	var frame:=Engine.get_physics_frames()
	if int(_dispatch_frames.get(key,-1))==frame:hit.fresh=false;return {"duplicate_frame":true}
	_dispatch_frames[key]=frame
	hit.fresh=not _contact_times.has(key)
	if hit.fresh:_contact_times[key]=true
	hit.from=hit.previous_sample;hit.to=hit.current_sample
	if hit.kind=="tip":
		hit.tip_from=hit.previous_sample;hit.proposed_tip_to=hit.current_sample
		hit.tip_to=Vector3(hit.position)+current.basis.x.normalized()*.0012
		_publish_safe=false
	var result:Dictionary=host.call("_solid_contact29",hit) if host.has_method("_solid_contact29") else {}
	_phase_prepared=false # Damage/death may change the target pose or topology.
	return result

func _part_collider(host:Node,part:String)->Node3D:
	if host.has_method("_solid_collider29"):return host.call("_solid_collider29",part)
	var rig:Skeleton3D=host.get("_npc_rig")
	for child:Node in rig.find_children("*","CollisionObject3D",true,false):
		if str(child.get_meta("sword_npc_part",""))==part:return child
	return null

func constrain_pose(host:Node,delta:float=-1.0)->Dictionary:
	var begun:=Time.get_ticks_usec()
	_phase_running=true;_phase_prepared=false;_phase_profiles.clear()
	var result:=_constrain_pose(host,delta)
	_phase_running=false
	last_solver_usec=Time.get_ticks_usec()-begun
	solver_calls+=1;solver_usec+=last_solver_usec;max_solver_usec=maxi(max_solver_usec,last_solver_usec)
	return result

func _constrain_pose(host:Node,delta:float=-1.0)->Dictionary:
	_last_solver_begun=Time.get_ticks_usec()
	_publish_safe=false
	if delta>0:set_delta(delta)
	if not _enabled(host):invalidate("inactive");return {}
	var weapon:Node3D=host.get("_sword")
	var player:CharacterBody3D=host.get("_player")
	if not is_instance_valid(weapon):return {}
	var identity:="%s:%s"%[weapon.get_instance_id(),host.get("lab_resets")]
	if identity!=_identity:invalidate("equipment");_identity=identity
	var current:=weapon.global_transform
	if not _ready or player.global_position.distance_to(_previous_player)>.4:
		_prepare(host)
		var initial_overlap:=query_static(host,current)
		if initial_overlap.is_empty():_remember(host,weapon);return {}
		# Equipment/teleport cannot mint a safe pose through intact triangles.
		# Resolve outward with attached hands before recording the first safe pose.
		_last_good_transform=current;_resolving_overlap=true
		_apply_pose(host,current,initial_overlap)
		_resolving_overlap=false
		last_contact=initial_overlap;last_contact.pose_safe=_publish_safe
		if _publish_safe:_remember(host,weapon)
		return last_contact
	_prepare(host)
	var tip:=Puncture.tip_local(host);var tip_before:=_previous*tip;var tip_now:=current*tip
	if _axial_tip(host,tip_now-tip_before,current.basis.x):
		var tip_hit:=_segment(tip_before,tip_now)
		if not tip_hit.is_empty():
			tip_hit.kind="tip";tip_hit.sample_local=tip;tip_hit.sample_x=tip.x
			tip_hit.previous_sample=tip_before;tip_hit.current_sample=tip_now;tip_hit.motion=(tip_now-tip_before)/_delta;tip_hit.travel=tip_before.distance_to(tip_now)
			var first:=query_sweep(host,_previous,current)
			if (first.is_empty() or float(tip_hit.fraction)<=float(first.fraction)+.015) and _world_clear_pose(host,current) and bool(host.call("_self_blade_clear_at51",current.basis.x,current.origin)):
				_dispatch(host,tip_hit,_previous,current)
	var collision:=query_sweep(host,_previous,current)
	if collision.is_empty():
		var overlap:=query_static(host,current)
		if not overlap.is_empty():collision=overlap
	if collision.is_empty():
		# Keep a contact plane only while the actual mesh still occupies it.
		if not _hold.is_empty():
			var p:Vector3=current*Vector3(_hold.sample_local);var n:Vector3=_hold.normal
			var plane_hit:=_segment(Vector3(_hold.position)+n*.012,Vector3(_hold.position)-n*.012)
			var gap:=n.dot(p-Vector3(_hold.position))
			var near:=not plane_hit.is_empty() and gap<.025 and (p-Vector3(_hold.position)-n*gap).length()<.06
			if near and not _channel_allows(host,_previous*Vector3(_hold.sample_local),p,current,true,p,str(_hold.part)):
				if gap<_contact_gap(host,_hold,current):
					collision=_hold.duplicate();collision.fraction=0.0;collision.previous_sample=_previous*Vector3(_hold.sample_local);collision.current_sample=p;collision.motion=(p-collision.previous_sample)/_delta;collision.travel=Vector3(collision.motion).length()*_delta
			else:_hold.clear()
	if collision.is_empty():
		if _hold.is_empty():_contact_times.clear()
		_publish_safe=true
		_commit_depth(host)
		_remember(host,weapon);return {}
	var result:=_dispatch(host,collision,_previous,current)
	var normal:Vector3=collision.normal
	var fraction:=maxf(0.0,float(collision.fraction)-GAP/maxf(float(collision.travel),.000001))
	var accepted:=_previous.interpolate_with(current,fraction)
	_hold=collision.duplicate()
	var omega:Vector3=host.get("_omega");var gradient:=accepted.basis.x.cross(normal)
	var incoming:=omega.dot(gradient)
	if incoming<0 and gradient.length_squared()>.000001:
		omega-=gradient*(incoming/gradient.length_squared())
		# Rebound once at fresh impact, not every held frame.
		if collision.get("fresh",false):omega+=gradient.normalized()*minf(.30,-incoming*.06)
	host.set("_omega",omega)
	_apply_pose(host,accepted,collision)
	contacts+=1
	last_contact=collision.duplicate();last_contact.response=result;last_contact.pose_safe=_publish_safe
	last_contact.accepted_gap=normal.dot(weapon.global_transform*Vector3(collision.sample_local)-Vector3(collision.position))
	host.set("_prev_points",PackedVector3Array())
	if _publish_safe:
		_commit_depth(host)
		_remember(host,weapon)
	max_solver_usec=maxi(max_solver_usec,Time.get_ticks_usec()-_last_solver_begun)
	return last_contact

func _commit_depth(host:Node)->void:
	var channel:Dictionary=host.get_meta("puncture29_channel",{})
	if channel.get("valid",false) and channel.get("active",false):Wound.advance_active29(host,Puncture.tip_world(host))

func _remember(host:Node,weapon:Node3D)->void:
	_publish_safe=true
	super._remember(host,weapon)
	_last_good_player=host.get("_player").global_position
	_last_good_rig=host.get("_rig").global_transform
	_last_good_transform=weapon.global_transform
	var channel:Dictionary=host.get_meta("puncture29_channel",{})
	var reference:WeakRef=channel.get("node_ref")
	var node:Node3D=reference.get_ref() if reference!=null else null
	_accepted_bore_id=0
	if channel.get("valid",false) and channel.get("active",false) and is_instance_valid(node):
		_accepted_bore_id=node.get_instance_id();_accepted_bore_frame=_bore_frame(host,node)
	var rig:Skeleton3D=host.get("_rig")
	_safe_rig_local=rig.transform;_safe_full_pose.clear()
	for bone in rig.get_bone_count():_safe_full_pose.append(rig.get_bone_pose(bone))
	_safe_ancestors.clear()
	var player:Node=host.get("_player")
	var ancestor:Node=rig.get_parent()
	if player.is_ancestor_of(rig):
		while ancestor!=player:
			if ancestor is Node3D:_safe_ancestors.append({"node":weakref(ancestor),"transform":ancestor.transform})
			ancestor=ancestor.get_parent()

func _candidate_clear(host:Node,transform:Transform3D,contact:Dictionary)->bool:
	# The cached tangent plane guides projection, but is not a solid halfspace:
	# a valid pose around a curved limb can lie behind that historical plane.
	_candidate_obstruction=query_static(host,transform)
	if not _candidate_obstruction.is_empty():return false
	if not _resolving_overlap:
		_candidate_obstruction=query_sweep(host,_last_good_transform,transform)
		if not _candidate_obstruction.is_empty():return false
	if not bool(host.call("_self_blade_clear_at51",transform.basis.x,transform.origin)):return false
	if not _world_clear_pose(host,transform):return false
	return true

func _apply_pose(host:Node,accepted:Transform3D,contact:Dictionary)->void:
	var begun:=Time.get_ticks_usec()
	var rig:Skeleton3D=host.get("_rig")
	var active:StringName=host.call("_active_side")
	var primary:StringName=&"right" if active==&"both" else active
	var arm:Dictionary=host.call("_arm_set",primary)
	var axis:=accepted.basis.x.normalized();var origin:=accepted.origin
	var normal:Vector3=contact.normal;var actual_grip:=Vector3.ZERO;var local_axis:=Vector3.ZERO
	var verified_transform:=accepted
	var recovery_trace:Array=[]
	_publish_safe=false
	if _ready and not _resolving_overlap and float(contact.get("fraction",1.0))<.05 and host.get("_player").global_position.distance_squared_to(_last_good_player)<.000001 and _safe_full_pose.size()==rig.get_bone_count():
		var trial_rig:=rig.transform;var trial_pose:Array[Transform3D]=[];var trial_ancestors:Array[Dictionary]=[]
		for bone in rig.get_bone_count():trial_pose.append(rig.get_bone_pose(bone));rig.set_bone_pose(bone,_safe_full_pose[bone])
		for record:Dictionary in _safe_ancestors:
			var ancestor:Node3D=record.node.get_ref()
			if is_instance_valid(ancestor):trial_ancestors.append({"node":ancestor,"transform":ancestor.transform});ancestor.transform=record.transform
		rig.transform=_safe_rig_local;rig.force_update_all_bone_transforms()
		var prior_axis:=_last_good_transform.basis.x.normalized();var prior_grip:Vector3=host.call("_palm_position",primary)
		var prior_transform:=Transform3D(_last_good_transform.basis,prior_grip+prior_axis*float(host.call("_grip_origin_offset")))
		if _candidate_clear(host,prior_transform,contact):
			_publish_safe=true;verified_transform=prior_transform;axis=prior_axis;origin=prior_transform.origin;actual_grip=prior_grip;early_safe_fallbacks+=1
		else:
			rig.transform=trial_rig
			for record:Dictionary in trial_ancestors:record.node.transform=record.transform
			for bone in trial_pose.size():rig.set_bone_pose(bone,trial_pose[bone])
			rig.force_update_all_bone_transforms()
	if not _publish_safe and _ready and not _resolving_overlap and float(contact.get("fraction",1.0))<.05 and not _safe_bones.is_empty():
		var trial_bones:Dictionary={}
		for bone:int in _safe_bones:trial_bones[bone]=rig.get_bone_pose(bone);rig.set_bone_pose(bone,_safe_bones[bone])
		rig.force_update_all_bone_transforms()
		var prior_axis:=_last_good_transform.basis.x.normalized()
		var prior_grip:Vector3=host.call("_palm_position",primary)
		var prior_transform:=Transform3D(_last_good_transform.basis,prior_grip+prior_axis*float(host.call("_grip_origin_offset")))
		if _candidate_clear(host,prior_transform,contact):
			_publish_safe=true;verified_transform=prior_transform;axis=prior_axis;origin=prior_transform.origin;actual_grip=prior_grip;early_safe_fallbacks+=1
		else:
			for bone:int in trial_bones:rig.set_bone_pose(bone,trial_bones[bone])
			rig.force_update_all_bone_transforms()
	for attempt in (0 if _publish_safe else (28 if _resolving_overlap else 5)):
		var local_grip:Vector3=rig.global_transform.affine_inverse()*(origin-axis*float(host.call("_grip_origin_offset")))
		local_axis=(rig.global_basis.inverse()*axis).normalized()
		host.call("_pose_arm_ik",arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,local_grip,local_axis,1.0,true,arm.pole)
		rig.force_update_all_bone_transforms()
		actual_grip=host.call("_palm_position",primary);origin=actual_grip+axis*float(host.call("_grip_origin_offset"))
		var edge:Vector3=host.call("_edge_axis",axis)
		var transform:=Transform3D(Basis(axis,edge,axis.cross(edge).normalized()),origin)
		if _candidate_clear(host,transform,contact):_publish_safe=true;verified_transform=transform;break
		var obstruction:Dictionary=_candidate_obstruction if not _candidate_obstruction.is_empty() else contact
		var correction_normal:Vector3=obstruction.normal
		var clearance:=correction_normal.dot(transform*Vector3(obstruction.sample_local)-Vector3(obstruction.position))
		origin+=correction_normal*maxf(.015 if _resolving_overlap else .004,GAP-clearance)
		if attempt>3:axis=(axis+correction_normal*.025).normalized()
	if not _publish_safe:
		for bone:int in _safe_bones:rig.set_bone_pose(bone,_safe_bones[bone])
		rig.force_update_all_bone_transforms()
		axis=_last_good_transform.basis.x.normalized();actual_grip=host.call("_palm_position",primary)
		origin=actual_grip+axis*float(host.call("_grip_origin_offset"))
		var edge:Vector3=_last_good_transform.basis.y
		verified_transform=Transform3D(_last_good_transform.basis,origin)
		_publish_safe=_candidate_clear(host,verified_transform,contact)
		safe_fallbacks+=1
		if not _publish_safe and _safe_full_pose.size()==rig.get_bone_count():
			# Reject the holder step which made the last accepted attached pose
			# unreachable. Restore body and arms together, never leave floating steel.
			var player:CharacterBody3D=host.get("_player")
			var rollback:=_last_good_player-player.global_position
			if rollback.length()<=.4 and (rollback.length_squared()<.000001 or not player.test_move(player.global_transform,rollback)):
				player.global_position=_last_good_player;rig.transform=_safe_rig_local
				for record:Dictionary in _safe_ancestors:
					var node:Node3D=record.node.get_ref()
					if is_instance_valid(node):node.transform=record.transform
				for bone in _safe_full_pose.size():rig.set_bone_pose(bone,_safe_full_pose[bone])
				rig.force_update_all_bone_transforms()
				actual_grip=host.call("_palm_position",primary);axis=_last_good_transform.basis.x.normalized()
				origin=actual_grip+axis*float(host.call("_grip_origin_offset"))
				verified_transform=Transform3D(_last_good_transform.basis,origin)
				_publish_safe=_candidate_clear(host,verified_transform,contact)
				if _publish_safe:
					holder_rollbacks+=1
					if player.velocity.dot(normal)<0:player.velocity-=normal*player.velocity.dot(normal)
		if not _publish_safe:
			var player:CharacterBody3D=host.get("_player")
			var start:=player.global_transform
			# A moving body can occupy yesterday's valid pose. Resolve the holder
			# outward through native movement clearance, then validate attached steel.
			var away:Vector3=player.global_position-host.get("_npc_body").global_position
			away.y=0;away=away.normalized()
			# A side/back surface can overlap yesterday's pose. Retreating only
			# toward the holder may cross the entire head instead of leaving its
			# nearest surface. Test both normal orientations; static normals are
			# oriented for contact response and need not be outward mesh normals.
			var lateral:=Vector3(normal.x,0,normal.z).normalized()
			var directions:Array[Vector3]=[]
			if lateral.length_squared()>.5:
				directions.append(lateral);directions.append(-lateral)
				# A curved rear-face graze can require a tangent escape. Both signs
				# remain bounded native holder moves with full final validation.
				directions.append(lateral.cross(Vector3.UP));directions.append(Vector3.UP.cross(lateral))
			directions.append(away)
			var world_hit:Dictionary=_world_obstruction.get("hit",{})
			var blocker:Node3D=world_hit.get("collider")
			if is_instance_valid(blocker) and blocker is RigidBody3D and Vector3(world_hit.get("normal",Vector3.UP)).length_squared()<.00000001:
				# A detached piece can settle beside the holder, where retreat from
				# the original NPC is not an escape direction. Every alternative
				# still needs native holder clearance and the full weapon validation.
				var piece_away:Vector3=origin-blocker.global_position;piece_away.y=0
				if piece_away.length_squared()>.000001:directions.append(piece_away.normalized())
				directions.append(away.cross(Vector3.UP));directions.append(Vector3.UP.cross(away))

			# If a falling target makes the retained bore unreachable, try its
			# exact axial exit first. Searching every lateral direction cannot
			# resolve the same narrow slit and used dozens of redundant IK checks.
			var channel:Dictionary=host.get_meta("puncture29_channel",{})
			var reference:WeakRef=channel.get("node_ref")
			var wound:Node3D=reference.get_ref() if reference!=null else null
			if bool(host.get("_npc_dead")) and channel.get("active",false) and is_instance_valid(wound):
				var bore:=_bore_frame(host,wound)
				var bore_axis:Vector3=-bore.basis.z.normalized()
				var withdrawal:=-Vector3(bore_axis.x,0,bore_axis.z).normalized()
				var remaining:=maxf(0.0,(_last_good_transform*Puncture.tip_local(host)-bore.origin).dot(bore_axis))
				var axial_step:=withdrawal*(remaining+.012)/maxf(.1,-withdrawal.dot(bore_axis))
				if axial_step.length()<=.4 and not player.test_move(start,axial_step):
					player.global_position=start.origin+axial_step
					rig.force_update_all_bone_transforms();actual_grip=host.call("_palm_position",primary)
					origin=actual_grip+axis*float(host.call("_grip_origin_offset"))
					verified_transform=Transform3D(_last_good_transform.basis,origin)
					var was_resolving:=_resolving_overlap;_resolving_overlap=true
					_publish_safe=_candidate_clear(host,verified_transform,contact)
					_resolving_overlap=was_resolving
					if _publish_safe:recovery_moves+=1
					else:player.global_transform=start
			for distance:float in ([] if _publish_safe else [.015,.03,.06,.10,.16,.24,.32]):
				for direction:Vector3 in directions:
					recovery_attempts+=1
					var step:=direction*distance
					if player.test_move(start,step):recovery_native_blocks+=1;continue
					player.global_position=start.origin+step
					rig.force_update_all_bone_transforms();actual_grip=host.call("_palm_position",primary)
					origin=actual_grip+axis*float(host.call("_grip_origin_offset"))
					verified_transform=Transform3D(_last_good_transform.basis,origin)
					var was_resolving:=_resolving_overlap;_resolving_overlap=true
					_publish_safe=_candidate_clear(host,verified_transform,contact)
					if bool(host.get("_lab_trace_enabled28")):recovery_trace.append({"step":step,"player":player.global_position,"rig":rig.global_position,"grip":actual_grip,"origin":origin,"accepted":_publish_safe,"static_obstruction":_candidate_obstruction.duplicate(),"self_clear":host.call("_self_blade_clear_at51",axis,origin),"world_obstruction":_world_obstruction.duplicate(),"skip_incoming_target_sweep":_resolving_overlap})
					_resolving_overlap=was_resolving
					if _publish_safe:recovery_moves+=1;break
				if _publish_safe:break
			if not _publish_safe:
				player.global_transform=start;rig.force_update_all_bone_transforms()
				actual_grip=host.call("_palm_position",primary)
				origin=actual_grip+axis*float(host.call("_grip_origin_offset"))
				verified_transform=Transform3D(_last_good_transform.basis,origin)
		if not _publish_safe:
			rejected_fallbacks+=1;unresolved+=1
			last_unresolved={"contact":contact.duplicate(),"gap":normal.dot(verified_transform*Vector3(contact.sample_local)-Vector3(contact.position)),"static":query_static(host,verified_transform),"sweep":query_sweep(host,_last_good_transform,verified_transform),"player":host.get("_player").global_position,"last_good_player":_last_good_player,"rig_under_player":host.get("_player").is_ancestor_of(rig),"self_clear":host.call("_self_blade_clear_at51",axis,origin),"world_clear":_world_clear_pose(host,verified_transform),"world_obstruction":_world_obstruction.duplicate(),"recovery_attempts":recovery_attempts,"recovery_native_blocks":recovery_native_blocks,"recovery_trace":recovery_trace}
	if active==&"both":
		local_axis=(rig.global_basis.inverse()*axis).normalized()
		var support:Vector3=rig.global_transform.affine_inverse()*actual_grip-local_axis*float(host.get("_two_hand_offset_rig"))
		host.call("_pose_support",&"left",support);rig.force_update_all_bone_transforms()
		max_support_error=maxf(max_support_error,Vector3(host.call("_palm_position",&"left")).distance_to(rig.global_transform*support))
	host.set("_dir",axis);host.set("_sword_origin",origin);host.call("_place_sword",origin,axis)
	host.get("_sword").global_transform=verified_transform
	max_grip_error=maxf(max_grip_error,(origin-axis*float(host.call("_grip_origin_offset"))).distance_to(host.call("_palm_position",primary)))
	ik_usec+=Time.get_ticks_usec()-begun

func _world_clear(host:Node,axis:Vector3,origin:Vector3)->bool:
	var edge:Vector3=host.call("_edge_axis",axis)
	var candidate:=Transform3D(Basis(axis,edge,axis.cross(edge).normalized()),origin)
	return _world_clear_pose(host,candidate)

func _world_clear_pose(host:Node,candidate:Transform3D)->bool:
	var begun:=Time.get_ticks_usec()
	_world_obstruction.clear()
	var player:CharacterBody3D=host.get("_player")
	var exclude:Array[RID]=[player.get_rid()]
	var target:CollisionObject3D=host.get("_npc_body")
	if is_instance_valid(target):exclude.append(target.get_rid())
	var rig:Node=host.get("_npc_rig")
	for node:Node in rig.find_children("*","CollisionObject3D",true,false):exclude.append(node.get_rid())
	var corpse:CollisionObject3D=host.get("_npc_corpse31")
	if is_instance_valid(corpse):
		exclude.append(corpse.get_rid())
		var ragdoll:Node=corpse.get_meta("ragdoll31") if corpse.has_meta("ragdoll31") else null
		if is_instance_valid(ragdoll):
			var physical:RefCounted=ragdoll.get("physical")
			if is_instance_valid(physical) and physical.has_method("body_rids"):
				for owned_rid:RID in physical.call("body_rids"):
					if not exclude.has(owned_rid):exclude.append(owned_rid)
	var space:=player.get_world_3d().direct_space_state
	for row:Dictionary in _samples:
		var from:Vector3=_last_good_transform*Vector3(row.local);var to:Vector3=candidate*Vector3(row.local)
		if from.distance_squared_to(to)<.000001:continue
		if not _world_ray_clear(space,from,to,exclude):world_usec+=Time.get_ticks_usec()-begun;return false
	world_usec+=Time.get_ticks_usec()-begun
	return true

func _world_ray_clear(space:PhysicsDirectSpaceState3D,from:Vector3,to:Vector3,excluded:Array[RID])->bool:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1,excluded);query.hit_from_inside=true
	for attempt in 4:
		var hit:=space.intersect_ray(query)
		if hit.is_empty():return true
		_world_obstruction={"hit":hit,"from":from,"to":to}
		# A falling severed rigid body can engulf previously valid held steel.
		# Only departure from that initial overlap is legal; incoming hits, static
		# walls, or an endpoint still inside the body remain solid.
		if not hit.collider is RigidBody3D or Vector3(hit.normal).length_squared()>.00000001:return false
		var sphere:=SphereShape3D.new();sphere.radius=.0005
		var endpoint:=PhysicsShapeQueryParameters3D.new();endpoint.shape=sphere;endpoint.transform=Transform3D(Basis.IDENTITY,to);endpoint.collision_mask=1;endpoint.exclude=excluded
		for overlap:Dictionary in space.intersect_shape(endpoint,64):
			if overlap.rid==hit.rid:return false
		var more:Array[RID]=query.exclude.duplicate();more.append(hit.rid);query.exclude=more;dynamic_egress+=1
	return false

func constrain_walk_velocity(host:Node,value:Vector3,delta:float)->Vector3:
	var begun:=Time.get_ticks_usec();var outer_phase:=_phase_running
	_phase_running=true;_phase_prepared=false;_phase_profiles.clear()
	var result:=_constrain_walk_velocity(host,value,delta)
	_phase_running=outer_phase;_phase_prepared=false
	walk_calls+=1;walk_usec+=Time.get_ticks_usec()-begun
	return result

func _constrain_walk_velocity(host:Node,value:Vector3,delta:float)->Vector3:
	if not _enabled(host) or not _ready or value.length_squared()<.000001:return value
	set_delta(delta)
	var weapon:Node3D=host.get("_sword")
	var candidate:=weapon.global_transform;candidate.origin+=value*delta
	var tip:=Puncture.tip_local(host)
	var tip_from:=weapon.global_transform*tip;var tip_to:=candidate*tip
	_prepare(host,(weapon.global_transform*_profile_bounds).merge(candidate*_profile_bounds))
	if _axial_tip(host,tip_to-tip_from,candidate.basis.x):
		var tip_hit:=_segment(tip_from,tip_to)
		if not tip_hit.is_empty():
			var first:=query_sweep(host,weapon.global_transform,candidate)
			if (first.is_empty() or float(tip_hit.fraction)<=float(first.fraction)+.015) and _world_clear_pose(host,candidate):
				tip_hit.kind="tip";tip_hit.sample_local=tip;tip_hit.sample_x=tip.x
				tip_hit.previous_sample=tip_from;tip_hit.current_sample=tip_to;tip_hit.motion=value;tip_hit.travel=tip_from.distance_to(tip_to)
				_dispatch(host,tip_hit,weapon.global_transform,candidate)
	var collision:=query_sweep(host,weapon.global_transform,candidate)
	if collision.is_empty():return value
	var normal:Vector3=collision.normal
	if value.dot(normal)>=0:return value
	walk_blocks+=1
	# Allow the portion up to exact skin; the pose callback owns the impact.
	return value*maxf(0.0,float(collision.fraction)-_contact_gap(host,collision,candidate)/maxf(value.length()*delta,.000001))

func status()->Dictionary:
	var result:=super.status()
	result.profile_samples=_samples.size();result.exact_checks=exact_checks;result.rejected_fallbacks=rejected_fallbacks;result.walk_blocks=walk_blocks
	result.static_edges=_static_points.size()/2
	result.holder_rollbacks=holder_rollbacks
	result.geometry_builds=geometry_builds;result.geometry_usec=geometry_usec;result.max_solver_usec=max_solver_usec
	result.recovery_moves=recovery_moves
	result.sweep_usec=sweep_usec;result.static_usec=static_usec;result.ik_usec=ik_usec;result.world_usec=world_usec
	result.solver_calls=solver_calls;result.solver_usec=solver_usec;result.last_solver_usec=last_solver_usec
	result.segment_calls=segment_calls;result.grid_visits=grid_visits;result.triangle_candidates=triangle_candidates
	result.early_safe_fallbacks=early_safe_fallbacks;result.recovery_attempts=recovery_attempts;result.recovery_native_blocks=recovery_native_blocks
	result.prepare_usec=prepare_usec;result.dynamic_egress=dynamic_egress
	result.walk_calls=walk_calls;result.walk_usec=walk_usec
	result.pose_safe=_publish_safe;result.last_contact=last_contact
	result.rigid_triangles31=rigid_triangles31;result.mixed_triangles31=mixed_triangles31
	result.bvh_builds31=bvh_builds31;result.bvh_build_usec31=bvh_build_usec31;result.skin_hits_usec31=skin_hits_usec31
	return result
