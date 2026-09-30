extends RefCounted
## Cosmetic port of hero_artist14_surface.mjs + wound_bleeding.mjs.
## Fixed 112 particles and four bone anchors per actual actor; no HP writes.
## User-requested readability profile: 1.65x particle radius, opacity .95.
## Source counts 20/32, trajectories, lifetimes, wounds, idle optimization intact.
const CAPACITY := 112
var mesh: MultiMeshInstance3D
var _rig: Skeleton3D
var _body: Node3D
var _unit := 1.0
var _height := 1.8
var _cursor := 0
var _life := PackedFloat64Array()
var _pos := PackedVector3Array()
var _velocity := PackedVector3Array()
var _buffer := PackedFloat32Array()
var _wounds: Array[Dictionary] = []
var _children: Array[PackedInt32Array] = []
var _bone_world: Array[Transform3D] = []
var _last_time := -1.0
var _next_emission := 0.0
var _last_root := Vector3.ZERO
var emitted := 0
var active := 0
var _has_particles := false

func configure(parent: Node3D, body: Node3D, rig: Skeleton3D, unit: float, height: float) -> bool:
	if mesh!=null or not is_instance_valid(parent) or not is_instance_valid(body) or not is_instance_valid(rig) or not is_finite(unit) or unit<=0 or not is_finite(height) or height<=0: return false
	_body=body; _rig=rig; _unit=unit; _height=height; _last_root=body.global_position
	_life.resize(CAPACITY); _pos.resize(CAPACITY); _velocity.resize(CAPACITY)
	_buffer.resize(CAPACITY*12)
	_children.resize(rig.get_bone_count()); _bone_world.resize(rig.get_bone_count())
	for i in rig.get_bone_count():
		var parent_index:=rig.get_bone_parent(i)
		if parent_index>=0: _children[parent_index].append(i)
	var sphere:=SphereMesh.new()
	sphere.radius=.028*unit*1.65; sphere.height=.056*unit*1.65; sphere.radial_segments=6; sphere.rings=3
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("8c1524"); material.albedo_color.a=.95
	material.roughness=.55; material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material=material
	var instances:=MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D; instances.mesh=sphere; instances.instance_count=CAPACITY; instances.visible_instance_count=0
	mesh=MultiMeshInstance3D.new(); mesh.name="NpcBloodSourceParticles"
	mesh.multimesh=instances; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh); mesh.top_level=true; mesh.global_transform=Transform3D.IDENTITY
	return true

func _emit(point: Vector3, count: int, normal: Vector3, drip: bool=false) -> void:
	_has_particles=true
	for i in count:
		var slot:=_cursor%CAPACITY
		_cursor+=1
		var angle:=float(_cursor)*2.399963
		_life[slot]=.7 if drip else .35+float(i%5)*.07
		_pos[slot]=point
		_velocity[slot]=Vector3(sin(angle)*(.08 if drip else 1.5),-.12 if drip else 1.1+float(i%4)*.4,cos(angle)*(.06 if drip else 1.3))*_unit
		if normal.length_squared()>0: _velocity[slot]+=normal.normalized()*.6*_unit
		emitted+=1

func accept(point: Vector3, normal: Vector3, now: float, heavy: bool=false) -> void:
	if mesh==null or not point.is_finite() or not normal.is_finite() or not is_finite(now): return
	_emit(point,32 if heavy else 20,normal)
	# Source fallback: closest real bone or direct child-bone segment.
	# Triangle skin binding is unavailable in this native hit contract.
	var nearest:=-1
	var best:=INF
	for i in _rig.get_bone_count():
		_bone_world[i]=_rig.global_transform*_rig.get_bone_global_pose(i)
	for i in _rig.get_bone_count():
		var a: Vector3=_bone_world[i].origin
		var distance:=point.distance_squared_to(a)
		for j in _children[i]:
			var b: Vector3=_bone_world[j].origin
			var ab:=b-a
			var t:=clampf((point-a).dot(ab)/maxf(1e-12,ab.length_squared()),0,1)
			distance=minf(distance,point.distance_squared_to(a+ab*t))
		if distance<best: best=distance; nearest=i
	if nearest<0 or best>pow(1.2*_unit,2): return
	var transform: Transform3D=_bone_world[nearest]
	_wounds.append({"bone":nearest,"local":transform.affine_inverse()*point,"expires":now+(12 if heavy else 8),"next":now+.18,"interval":.32 if heavy else .45})
	if _wounds.size()>4: _wounds.pop_front()

func update(delta: float, now: float, ground: float) -> void:
	if mesh==null or not is_instance_valid(_body) or not is_instance_valid(_rig): return
	if not is_finite(delta) or not is_finite(now) or not is_finite(ground): clear(); return
	if _last_time>=0 and now<_last_time: clear()
	_last_time=now
	var teleported:=_last_root.distance_to(_body.global_position)>maxf(1.0,_height*4)
	_last_root=_body.global_position
	if teleported: _life.fill(0); _has_particles=false
	for i in range(_wounds.size()-1,-1,-1):
		if now>=float(_wounds[i].expires): _wounds.remove_at(i)
	if not _body.is_visible_in_tree() or teleported:
		_next_emission=now+.1
		for wound in _wounds: wound.next=now+float(wound.interval)
	elif now>=_next_emission:
		var due: Dictionary={}
		for wound in _wounds:
			if float(wound.next)<=now and (due.is_empty() or float(wound.next)<float(due.next)): due=wound
		if not due.is_empty():
			var point: Vector3=(_rig.global_transform*_rig.get_bone_global_pose(int(due.bone)))*due.local
			due.next=now+float(due.interval); _next_emission=now+.1
			if point.is_finite(): _emit(point,1,Vector3.ZERO,true)
	# Preserve clock/root/wound expiration and due-drop work above. A burst
	# marks pending particles immediately, even without a valid wound anchor.
	if not _has_particles:
		if active!=0:
			active=0; mesh.multimesh.visible_instance_count=0
		return
	var dt:=clampf(delta,0,.25)
	active=0
	for i in CAPACITY:
		if _life[i]<=0: continue
		_life[i]-=dt
		if _life[i]<=0: continue
		_velocity[i].y-=9.8*_unit*dt
		_pos[i]+=_velocity[i]*dt
		if _pos[i].y<ground: _life[i]=0; continue
		var scale:=Vector3(.7,1.5,.7)*minf(1,_life[i]*8)
		# One bounded native upload, no individual per-instance server calls.
		var at:=active*12
		_buffer[at]=scale.x; _buffer[at+3]=_pos[i].x
		_buffer[at+5]=scale.y; _buffer[at+7]=_pos[i].y
		_buffer[at+10]=scale.z; _buffer[at+11]=_pos[i].z
		active+=1
	_has_particles=active>0
	if _has_particles: mesh.multimesh.buffer=_buffer
	mesh.multimesh.visible_instance_count=active

func clear() -> void:
	_life.fill(0); _wounds.clear(); active=0; _next_emission=0; _has_particles=false
	if is_instance_valid(mesh): mesh.multimesh.visible_instance_count=0

func dispose() -> void:
	clear()
	if is_instance_valid(mesh): mesh.free()
	mesh=null; _body=null; _rig=null
