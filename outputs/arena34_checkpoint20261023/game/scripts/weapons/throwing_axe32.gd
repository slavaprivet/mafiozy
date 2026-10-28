extends Node
const Model=preload("res://scripts/weapons/hatchet_model32.gd")
const Contact=preload("res://scripts/combat/arrow_contact31.gd")
const Armor=preload("res://scripts/combat/armor_damage31.gd")
const Wound=preload("res://scripts/combat/local_wound28.gd")
const Finish=preload("res://scripts/weapons/weapon_model_finish31.gd")
var host:Node
var pool:Array[Dictionary]=[]
var empty:Node3D
var contact=Contact.new()
var volume=preload("res://scripts/weapons/hatchet_volume32.gd").new()
var aiming:=false
var casting:=false
var cast_time:=0.0
var aim_age:=0.0
var launched:=0
var picked:=0
var last:Dictionary={}
var events:Array[Dictionary]=[]
var samples:=PackedVector3Array()
var _pose_frame:=-1
var world_shapes32:Array[Dictionary]=[]
func initialize(owner:Node)->void:
	host=owner
	# Dense authored boundary sampling: no whole-skin rebuild per sample.
	for i in 24:
		for z in [-.0015,.0015]:samples.append(Vector3(lerpf(.225,.455,float(i)/23.),.17,z))
	for i in 16:
		var t:=float(i)/15.
		for zsign in [-1.,1.]:
			samples.append(Vector3(lerpf(.285,.225,t),lerpf(.035,.17,t),lerpf(.019,.0015,t)*zsign))
			samples.append(Vector3(lerpf(.395,.455,t),lerpf(.035,.17,t),lerpf(.019,.0015,t)*zsign))
	for x in [-.14,.36]:
		for y in [-.022,.022]:
			for z in [-.022,.022]:samples.append(Vector3(x,y,z))
	var initial:Node3D=host._weapon_models.get("hatchet")
	if not is_instance_valid(initial):initial=Model.build(host,host._world)
	for index in 3:
		var model:Node3D=initial if index==0 else Model.build(host,host._world)
		model.set_meta("hatchet_serial32",index);model.visible=false
		pool.append({"node":model,"state":"reserve","velocity":Vector3.ZERO,"damage_done":false})
	empty=Node3D.new();empty.name="EmptyHatchetHand32";host._world.add_child(empty)
	host._weapon_models["hatchet"]=initial
	for child:Node in initial.find_children("*","MeshInstance3D",true,false):
		var mesh_node:=child as MeshInstance3D
		if mesh_node.mesh==null:continue
		var shape:=ConvexPolygonShape3D.new();shape.points=mesh_node.mesh.get_faces()
		world_shapes32.append({"shape":shape,"local":initial.global_transform.affine_inverse()*mesh_node.global_transform})
func count()->int:
	var n:=0
	for item in pool:
		if item.state in ["reserve","held"]:n+=1
	return n
func select()->Node3D:
	for item in pool:
		if item.state=="held":return item.node
	for item in pool:
		if item.state in ["reserve","held"]:
			item.state="held";return item.node
	return empty
func selected()->void:
	var model:=select();host._weapon_models["hatchet"]=model;host._sword=model
	host._sword_grounded=false;host._unarmed=model==empty;model.visible=model!=empty
	for item in pool:
		if item.state in ["held","reserve"]:
			item.node.visible=item.node==model
			item.state="held" if item.node==model else "reserve"
func cancel()->void:
	aiming=false;casting=false;aim_age=0.;host._aiming_throw=false
func input(event:InputEvent)->bool:
	if host==null or not host._ready or bool(host._world.get("preview_dead")):return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
		if host._player._free_mouse_look and pickup_near():return true
	if not host._player._free_mouse_look or host._weapon_id!="hatchet" or not host._selected or host._sword_grounded:return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if host._hand_lost31(&"right"):cancel();return true
		aiming=event.pressed and count()>0;aim_age=0.;host._aiming_throw=aiming;host._hold_right=false;host._held=false
		if not aiming:casting=false
		return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and aiming:
		if event.pressed and not casting and count()>0:casting=true;cast_time=0.
		host._hold_left=false;host._held=false
		return true
	return false
func projectile_exclusions()->Array[RID]:
	var excluded:Array[RID]=[host._player.get_rid()]
	# Exact posed skin remains queried; only its enclosing locomotion shell is omitted.
	for body in [host._npc_body,host._npc_corpse31]:
		if is_instance_valid(body) and body is CollisionObject3D:excluded.append(body.get_rid())
	return excluded
func world_exclusions32()->Array[RID]:
	var excluded:=projectile_exclusions()
	contact._prepare(host)
	for ref:WeakRef in contact._proxies:
		var body:CollisionObject3D=ref.get_ref()
		if is_instance_valid(body):excluded.append(body.get_rid())
	var corpse:Node=host._npc_corpse31
	if is_instance_valid(corpse) and corpse.has_meta("ragdoll31"):
		for rid:RID in corpse.get_meta("ragdoll31").physical.body_rids():
			if not excluded.has(rid):excluded.append(rid)
	return excluded
func world_sweep32(before:Transform3D,motion:Vector3)->Dictionary:
	var space:PhysicsDirectSpaceState3D=host._world.get_world_3d().direct_space_state
	var excluded:=world_exclusions32()
	var best:Dictionary={};var fraction:=2.
	for row in world_shapes32:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=row.shape;query.transform=before*Transform3D(row.local)
		query.collision_mask=1;query.exclude=excluded;query.margin=.0002
		# Native casts ignore existing overlap; inspect the actual shape first.
		var info:Dictionary=space.get_rest_info(query)
		var f:=0.
		if info.is_empty():
			query.motion=motion
			var cast:PackedFloat32Array=space.cast_motion(query)
			if cast.size()<2 or cast[0]>=1.:continue
			f=cast[0]
			query.motion=Vector3.ZERO
			query.transform.origin+=motion*minf(1.,float(cast[1])+.0001)
			info=space.get_rest_info(query)
			if info.is_empty():
				# Keep the conservative native stop; never invent a contact normal.
				info={"point":query.transform.origin,"normal":Vector3.ZERO,"unresolved_rest32":true}
		if f<fraction:
			fraction=f
			best={"position":info.get("point",query.transform.origin),"normal":info.get("normal",Vector3.ZERO),"fraction32":f,"world_convex32":true,"unresolved_rest32":info.get("unresolved_rest32",false)}
	return best
func aim_direction()->Vector3:
	var camera:Camera3D=host._player.get_preview_camera()
	var forward:Vector3=-camera.global_basis.z.normalized()
	var from:Vector3=camera.global_position
	var space:PhysicsDirectSpaceState3D=host._world.get_world_3d().direct_space_state
	var excluded:Array[RID]=projectile_exclusions()
	var ray:Dictionary=contact.ray(host,space,from,from+forward*100.,1,excluded)
	var hit:Dictionary=ray.get("hit",{})
	var target:Vector3=hit.position if not hit.is_empty() else from+forward*35.
	var release:Vector3=host._sword.global_transform*Model.HEAD_EDGE
	var flight_time:=release.distance_to(target)/lerpf(16.,23.,clampf(aim_age/.8,0.,1.))
	return (target+Vector3.UP*4.9*flight_time*flight_time-release).normalized()
func pose(delta:float)->bool:
	if host._weapon_id!="hatchet" or not aiming or host._unarmed:return false
	if host._hand_lost31(&"right"):cancel();return true
	var frame:=Engine.get_process_frames()
	if frame!=_pose_frame:
		aim_age+=delta
		if casting:cast_time+=delta
		_pose_frame=frame
	var direction:=aim_direction()
	var right:=direction.cross(Vector3.UP).normalized()
	if right.length_squared()<.1:right=Vector3.RIGHT
	var up:=right.cross(direction).normalized()
	var t:=smoothstep(0.,.20,cast_time) if casting else 0.
	var shoulder:Vector3=host._player.global_position+Vector3.UP*1.35
	var grip:Vector3=shoulder+right*.23+up*lerpf(.28,-.05,t)+direction*lerpf(-.14,.42,t)
	var shaft:Vector3=(up-direction*.3*(1.-t)).normalized()
	var arm:Dictionary=host._arm_set(&"right")
	var rig:Skeleton3D=host._rig
	var local:Vector3=rig.global_transform.affine_inverse()*grip
	var local_axis:Vector3=(rig.global_basis.inverse()*shaft).normalized()
	host._pose_arm_ik(arm.clav,arm.upper,arm.fore,arm.hand,arm.rest_upper,arm.rest_fore,arm.rest_hand,arm.offset,local,local_axis,1.,true,arm.pole)
	rig.force_update_all_bone_transforms()
	var palm:Vector3=host._palm_position(&"right")
	var origin:Vector3=palm+shaft*host._grip_origin_offset()
	if not host._self_blade_clear_at51(shaft,origin):return true
	var edge:Vector3=(direction-shaft*direction.dot(shaft)).normalized()
	var proposed:=Transform3D(Basis(shaft,edge,shaft.cross(edge)).orthonormalized(),origin)
	var solid:RefCounted=host.get("_solid_weapon29")
	if solid!=null and (not solid._world_clear_pose(host,proposed) or not solid.query_static(host,proposed).is_empty()):return true
	host._dir=shaft;host._edge_direction=edge;host._sword_origin=origin
	host._sword.global_transform=Transform3D(Basis(shaft,edge,shaft.cross(edge)).orthonormalized(),origin)
	host._prev_points=PackedVector3Array()
	if casting and cast_time>=.20:launch(direction)
	return true
func launch(direction:Vector3)->void:
	if host._hand_lost31(&"right"):cancel();return
	var current:Dictionary={}
	for item in pool:
		if item.node==host._sword and item.state in ["held","reserve"]:current=item;break
	if current.is_empty():cancel();return
	current.state="flying";current.velocity=direction*lerpf(16.,23.,clampf(aim_age/.8,0.,1.));current.damage_done=false
	current.node.visible=true;current.start_position=current.node.global_position;current.age=0.
	launched+=1;casting=false;aiming=false;host._aiming_throw=false
	host._hold_left=false;host._held=false;host._omega=Vector3.ZERO;host._prev_points=PackedVector3Array()
	selected();host._update_hint();refresh_hud32()
	last={"event":"launch","serial":current.node.get_meta("hatchet_serial32"),"speed":Vector3(current.velocity).length(),"charges":count()};events.append(last)
func _physics_process(delta:float)->void:
	if not is_instance_valid(host) or not host._ready:return
	if aiming and (not host._active() or host._hand_lost31(&"right")):cancel()
	for item in pool:
		if not is_instance_valid(item.node):continue
		if item.state=="held" and host._weapon_id=="hatchet" and host._sword_grounded:item.state="ground"
		if item.state=="embedded":
			var ref:WeakRef=item.get("skin_rig31");var rig:Skeleton3D=ref.get_ref() if ref!=null else null
			if not is_instance_valid(rig) or int(item.get("generation",-1))!=host.lab_resets:
				land(item,Vector3.ZERO);continue
			contact.follow(item,item.node)
		elif item.state=="detached":
			item.detached_age=float(item.get("detached_age",0.))+delta
			if float(item.detached_age)>2.4:land(item,Vector3.ZERO)
		elif item.state=="flying":step_flight(item,delta)
func step_flight(item:Dictionary,delta:float)->void:
	var model:Node3D=item.node
	var before:Transform3D=model.global_transform
	item.velocity+=Vector3.DOWN*9.8*delta;item.age=float(item.age)+delta
	var after:=before;after.origin+=Vector3(item.velocity)*delta
	var space:PhysicsDirectSpaceState3D=host._world.get_world_3d().direct_space_state
	var excluded:Array[RID]=projectile_exclusions()
	var best:Dictionary=world_sweep32(before,after.origin-before.origin)
	var best_fraction:float=best.get("fraction32",2.);var sample_at:=Vector3.ZERO
	var solid:RefCounted=host.get("_solid_weapon29")
	var batch:Array=solid.begin_projectile_queries32() if solid!=null else []
	var begun:=Time.get_ticks_usec()
	# Authored cutting edge, socket and butt all sweep; a broad shaft contact
	# cannot score the edge's damage or tunnel behind a nearer wall.
	for local:Vector3 in samples:
		var a:=before*local;var b:=after*local
		var result:Dictionary=contact.ray(host,space,a,b,1,excluded)
		var hit:Dictionary=result.get("hit",{})
		if not bool(result.get("supported",false)):
			var query:=PhysicsRayQueryParameters3D.create(a,b,1,excluded);query.hit_from_inside=true;hit=space.intersect_ray(query)
		if not hit.is_empty():
			var f:float=a.distance_to(hit.position)/maxf(a.distance_to(b),.000001)
			if f<best_fraction:best=hit;best_fraction=f;sample_at=local
	if solid!=null:solid.end_projectile_queries32(batch)
	item.ray_usec=maxi(int(item.get("ray_usec",0)),Time.get_ticks_usec()-begun)
	if best.is_empty():
		model.global_transform=after
		if float(item.age)>12. or model.global_position.y< -10.:land(item,Vector3.ZERO)
		return
	model.global_transform=before.interpolate_with(after,clampf(best_fraction,0.,1.))
	impact(item,best,sample_at)
func impact(item:Dictionary,hit:Dictionary,sample:Vector3)->void:
	var model:Node3D=item.node
	var velocity:Vector3=item.velocity;var speed:=velocity.length();var direction:=velocity.normalized()
	var edge_hit:bool=sample.y>.16 and direction.dot(model.global_basis.y)>.50
	var tissue:bool=hit.get("actual_skin31",false)
	var protection:Dictionary={"region":"world","tier":"","damage":0.,"penetrates":false}
	if tissue and not item.damage_done:
		var part:String=str(hit.part31)
		var local:Vector3=host._armor_point31(host._npc_rig,part,hit.position,hit.get("collider"))
		var incoming:=.5*Model.MASS*speed*speed*.25
		var kind:="slice" if edge_hit else "blunt"
		protection=Armor.resolve(host._npc_armor_loadout31,part,kind,incoming,local,clampf(-direction.dot(hit.normal),0,1))
		var plate:bool=str(protection.region)=="plate"
		if plate:protection.damage=0.
		var penetrates:bool=not plate and edge_hit and Armor.tissue_penetrates(str(protection.region),kind,float(protection.damage))
		protection.penetrates=penetrates
		if not plate and not penetrates:host._npc_take_puncture_part31(part,hit.position,speed,direction,float(protection.damage),Model.MASS,false)
		item.damage_done=true
		if str(protection.region) in ["cloth","mail","plate"]:host.combat_audio_event30("armor_"+str(protection.tier),hit.position,clampf(incoming/100.,.1,1.),"hatchet:"+part)
		if penetrates:
			var depth:float=embed_depth32(hit,direction,clampf(float(protection.damage)*.0015,.008,Model.HEAD_DEPTH-.012))
			# Every extremum of the authored wooden shaft stays outside entry.
			var inward:Vector3=-Vector3(hit.normal).normalized()
			var axial:=direction.dot(inward)
			if axial>.0001:
				for x in [-.14,.36]:
					for y in [-.022,.022]:
						for z in [-.022,.022]:depth=minf(depth,(-.002-(model.global_basis*(Vector3(x,y,z)-sample)).dot(inward))/axial)
			depth=maxf(0.,depth)
			var insertion:=model.global_transform
			insertion.origin=Vector3(hit.position)-insertion.basis*sample
			var obstacle:=world_sweep32(insertion,direction*depth)
			if not obstacle.is_empty():
				depth=maxf(0.,depth*float(obstacle.fraction32)-.002)
				volume.last.world_convex_cap32=depth
			var tissue_reached:bool=not bool(volume.last.get("accessory_only32",false)) and depth>float(volume.last.get("body_entry_gap32",0.))+.001
			var wound_point:Vector3=volume.last.get("body_entry32",hit.position)
			if tissue_reached:
				host._npc_take_puncture_part31(part,wound_point,speed,direction,float(protection.damage),Model.MASS,true)
				Wound.apply(host,part,wound_point,velocity,model.global_basis.x,speed)
			else:
				protection.damage=0.;protection.penetrates=false
			if depth<=.001:
				last={"event":"bounce","speed":speed,"edge":edge_hit,"actual_skin":true,"protection":protection,"point":hit.position,"reason":"no_head_insertion_volume","serial":model.get_meta("hatchet_serial32")};events.append(last)
				model.global_position+=Vector3(hit.normal)*.003;land(item,velocity.bounce(hit.normal)*.28);return
			# The authored socket/handle stay outside the actual entry plane.
			model.global_position=Vector3(hit.position)+direction*depth-model.global_basis*sample
			var rig:Skeleton3D=hit.rig31.get_ref();var bone:int=int(volume.last.get("body_bone32",hit.bone31))
			var frame:Transform3D=rig.global_transform*rig.get_bone_global_pose(bone)
			item.skin_rig31=weakref(rig);item.skin_bone31=bone;item.skin_local31=frame.affine_inverse()*model.global_transform;item.skin_hit_local31=frame.affine_inverse()*(wound_point if tissue_reached else Vector3(hit.position));item.generation=host.lab_resets
			item.state="embedded";item.velocity=Vector3.ZERO;item.depth=depth
			var wood_min:=INF
			for x in [-.14,.36]:
				for y in [-.022,.022]:
					for z in [-.022,.022]:wood_min=minf(wood_min,(model.global_transform*Vector3(x,y,z)-Vector3(hit.position)).dot(Vector3(hit.normal)))
			last={"event":"embed","speed":speed,"part":part,"depth":depth,"volume":volume.last.duplicate(),"wood_exterior_m":wood_min,"entry":hit.position,"normal":hit.normal,"protection":protection,"serial":model.get_meta("hatchet_serial32")};events.append(last);return
	last={"event":"bounce","speed":speed,"edge":edge_hit,"actual_skin":tissue,"protection":protection,"point":hit.position,"serial":model.get_meta("hatchet_serial32")};events.append(last)
	# Preserve orientation at impact, then native rigid collision owns the fall.
	model.global_position+=Vector3(hit.normal)*.003
	land(item,velocity.bounce(hit.normal)*.28 if Vector3(hit.normal).length_squared()>.5 else Vector3.ZERO)
func embed_depth32(hit:Dictionary,direction:Vector3,requested:float)->float:
	return volume.depth(host,hit,direction,requested,world_exclusions32())
func mark_ground32(model:Node3D)->void:
	cancel()
	for item in pool:
		if item.node==model:item.state="ground";refresh_hud32();return
func land(item:Dictionary,velocity:Vector3)->void:
	if item.node.get_parent()!=host._world:item.node.reparent(host._world,true)
	item.state="ground";item.velocity=Vector3.ZERO
	var body:RigidBody3D=Finish.make_ground_drop28(item.node,host._world,velocity.normalized() if velocity.length_squared()>.001 else Vector3.FORWARD,Model.MASS,0.)
	body.linear_velocity=velocity
	host._register_ground_sword(item.node);host._stamp_ground_weapon(item.node,"hatchet")
func pickup_near()->bool:
	var nearest:Dictionary={};var distance:=2.4
	for item in pool:
		if item.state!="ground" or not is_instance_valid(item.node):continue
		var d:float=host._player.global_position.distance_to(item.node.global_position)
		if d<distance:distance=d;nearest=item
	if nearest.is_empty():return false
	Finish.recover_ground_drop28(nearest.node,host._world)
	host._ground_swords.erase(nearest.node);nearest.state="reserve";nearest.node.visible=false;picked+=1
	if host._weapon_id=="hatchet":selected()
	refresh_hud32()
	last={"event":"pickup","serial":nearest.node.get_meta("hatchet_serial32"),"charges":count()};events.append(last);return true
func adopt_cut_piece32(actor:Node,body:RigidBody3D,cut:Dictionary)->void:
	if actor!=host:return
	for item in pool:
		if item.state!="embedded" or not is_instance_valid(item.node):continue
		var rig:Skeleton3D=item.skin_rig31.get_ref()
		if is_instance_valid(rig) and contact.detached_by_cut(item,rig,cut):
			item.node.reparent(body,true);item.state="detached";item.detached=weakref(body);item.detached_age=0.
func before_target_reset32()->void:
	for item in pool:
		if item.state in ["embedded","detached"] and is_instance_valid(item.node):land(item,Vector3.ZERO)
func refresh_hud32()->void:
	var arsenal:Node=host._world.get("preview_weapons")
	if is_instance_valid(arsenal):arsenal._refresh_ui()
func snapshot()->Dictionary:
	var states:Array=[]
	for item in pool:states.append({"id":item.node.get_instance_id() if is_instance_valid(item.node) else 0,"state":item.state,"ray_max_usec":item.get("ray_usec",0)})
	return {"charges":count(),"capacity":3,"aiming":aiming,"casting":casting,"launched":launched,"picked":picked,"last":last,"states":states,"events":events.duplicate(true)}
