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
# Sample the accepted, displayed weapon after the parent's final contact solve.
var release_armed35:=false
var sample_valid35:=false
var previous_point35:=Vector3.ZERO
var previous_basis35:=Basis.IDENTITY
var release_velocity35:=Vector3.ZERO
var release_angular35:=Vector3.ZERO
var sample_msec35:=0
var sample_physics_frame35:=-1
var sampled_model35:Node3D
var edge_grip_model35:Node3D
const MASS_POINT35:=Vector3(.30,.08,0.)
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
	# A one-edged hatchet is taken with its cutting side facing forward.
	# Thereafter ordinary free-swing edge evolution and physical spin own it.
	if model!=empty and model!=edge_grip_model35:
		var direction:Vector3=host._dir.normalized()
		var forward:Vector3=-host._camera.global_basis.z
		var edge:Vector3=forward-direction*forward.dot(direction)
		if edge.length_squared()>.000001:host._edge_direction=edge.normalized()
		edge_grip_model35=model
	host._sword_grounded=false;host._unarmed=model==empty;model.visible=model!=empty
	for item in pool:
		if item.state in ["held","reserve"]:
			item.node.visible=item.node==model
			item.state="held" if item.node==model else "reserve"
func cancel()->void:
	aiming=false;casting=false;aim_age=0.;host._aiming_throw=false
	release_armed35=false;sample_valid35=false;release_velocity35=Vector3.ZERO;release_angular35=Vector3.ZERO;sample_physics_frame35=-1
func input(event:InputEvent)->bool:
	if host==null or not host._ready or bool(host._world.get("preview_dead")):return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
		if host._player._free_mouse_look and pickup_near():return true
	if not host._player._free_mouse_look or host._weapon_id!="hatchet" or not host._selected or host._sword_grounded:return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not release_armed35:
				release_armed35=count()>0 and not host._unarmed
				sample_valid35=false;release_velocity35=Vector3.ZERO;release_angular35=Vector3.ZERO;sample_physics_frame35=-1
			# Ordinary input and solver own the complete free hand swing.
			return false
		if release_armed35:
			var fresh:=sample_valid35 and Time.get_ticks_msec()-sample_msec35<=100
			launch(release_velocity35 if fresh else Vector3.ZERO,release_angular35 if fresh else Vector3.ZERO)
			return true
	return false
func _process(_delta:float)->void:
	if not release_armed35:return
	if not is_instance_valid(host) or not host._active() or host._weapon_id!="hatchet" or host._unarmed or host._sword_grounded or host._hand_lost31(host._carry_side):
		cancel();return
	var physics_frame:=Engine.get_physics_frames()
	# Rendering may repeat a single accepted physics pose at 120/144 FPS.
	# Retain its measured velocity; dividing by render delta gives 0/double speed.
	if physics_frame==sample_physics_frame35:return
	var delta:=float(physics_frame-sample_physics_frame35)*get_physics_process_delta_time()
	var model:Node3D=host._sword
	var point:Vector3=model.global_transform*MASS_POINT35
	if sample_valid35 and sampled_model35==model and delta>0.0001 and delta<=.1:
		var movement:=point-previous_point35
		# Equip, reset or teleport may replace the pose; they impart no momentum.
		release_velocity35=movement/delta if movement.length()<=.45 else Vector3.ZERO
		var turn:Quaternion=(model.global_basis.get_rotation_quaternion()*previous_basis35.get_rotation_quaternion().inverse()).normalized()
		if turn.w<0.:turn=-turn
		var angle:=turn.get_angle()
		# An instantaneous contact/equip flip is not accumulated angular energy.
		release_angular35=turn.get_axis()*angle/delta if angle>.00001 and angle<=.65 and movement.length()<=.45 else Vector3.ZERO
	else:release_velocity35=Vector3.ZERO;release_angular35=Vector3.ZERO
	previous_point35=point;previous_basis35=model.global_basis;sampled_model35=model;sample_valid35=true;sample_msec35=Time.get_ticks_msec();sample_physics_frame35=physics_frame
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
func world_rotational_sweep35(before:Transform3D,after:Transform3D)->Dictionary:
	# At <=.04 rad, the arc/chord deviation of this half-metre model is <.1mm.
	# A .2mm expanded hull of both poses contains the entire rotating volume.
	var bounds:=AABB();var first:=true
	for row in world_shapes32:
		for point:Vector3 in row.shape.points:
			var a:Vector3=before*Transform3D(row.local)*point
			var b:Vector3=after*Transform3D(row.local)*point
			if first:bounds=AABB(a,Vector3.ZERO);first=false
			bounds=bounds.expand(a).expand(b)
	if first:return {}
	var space:PhysicsDirectSpaceState3D=host._world.get_world_3d().direct_space_state
	var query:=PhysicsShapeQueryParameters3D.new()
	var broad:=BoxShape3D.new();broad.size=bounds.size+Vector3.ONE*.0004
	query.shape=broad;query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	query.collision_mask=1;query.exclude=world_exclusions32();query.margin=.0002
	if space.intersect_shape(query,1).is_empty():return {}
	for row in world_shapes32:
		var hull:=PackedVector3Array()
		for point:Vector3 in row.shape.points:
			hull.append(before*Transform3D(row.local)*point-bounds.get_center())
			hull.append(after*Transform3D(row.local)*point-bounds.get_center())
		var shape:=ConvexPolygonShape3D.new();shape.points=hull;query.shape=shape
		var hit:=space.get_rest_info(query)
		if not hit.is_empty():
			# Stay at the last clear pose; the bracket is at most one small substep.
			return {"position":hit.point,"normal":hit.normal,"fraction32":0.,"world_rotational35":true}
	return {}
func pose(_delta:float)->bool:
	# The normal weapon solver supplies both the visible hand and release pose.
	return false
func launch(velocity:Vector3,angular_velocity:Vector3=Vector3.ZERO)->void:
	if host._hand_lost31(host._carry_side):cancel();return
	var current:Dictionary={}
	for item in pool:
		if item.node==host._sword and item.state in ["held","reserve"]:current=item;break
	if current.is_empty():cancel();return
	current.state="flying";current.velocity=velocity;current.damage_done=false
	current.angular_velocity35=angular_velocity
	current.node.visible=true;current.start_position=current.node.global_position;current.age=0.
	launched+=1;cancel()
	host._hold_left=false;host._held_event=false;host._held=false;host._omega=Vector3.ZERO;host._prev_points=PackedVector3Array()
	host._sword_coast_until_ms31=0
	selected();host._update_hint();refresh_hud32()
	last={"event":"launch","serial":current.node.get_meta("hatchet_serial32"),"speed":velocity.length(),"velocity35":velocity,"angular_velocity35":angular_velocity,"release_transform35":current.node.global_transform,"charges":count()};events.append(last)
func _physics_process(delta:float)->void:
	if not is_instance_valid(host) or not host._ready:return
	if release_armed35 and (not host._active() or host._hand_lost31(host._carry_side)):cancel()
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
	var started:=Time.get_ticks_usec()
	var angular:Vector3=item.get("angular_velocity35",Vector3.ZERO)
	var steps:=maxi(1,ceili(angular.length()*delta/.04))
	var solid:RefCounted=host.get("_solid_weapon29")
	var batch:Array=solid.begin_projectile_queries32() if solid!=null else []
	var collision:Dictionary={}
	for substep in steps:
		if item.state!="flying":break
		collision=_step_flight35(item,delta/float(steps))
		if not collision.is_empty():break
	# All substeps see the same current actor pose. End the read batch before
	# impact can change wounds, damage or ownership of any target geometry.
	if solid!=null:solid.end_projectile_queries32(batch)
	if collision.has("hit"):impact(item,collision.hit,collision.sample)
	elif collision.get("expired",false):land(item,Vector3.ZERO)
	item.flight_last_usec35=Time.get_ticks_usec()-started
	item.flight_peak_usec35=maxi(int(item.get("flight_peak_usec35",0)),int(item.flight_last_usec35))
func _step_flight35(item:Dictionary,delta:float)->Dictionary:
	var model:Node3D=item.node
	var before:Transform3D=model.global_transform
	item.velocity+=Vector3.DOWN*9.8*delta;item.age=float(item.age)+delta
	var after:=before
	var angular:Vector3=item.get("angular_velocity35",Vector3.ZERO)
	if angular.length_squared()>.000001:
		after.basis=(Basis(Quaternion(angular.normalized(),angular.length()*delta))*before.basis).orthonormalized()
	# Linear momentum belongs to the centre of mass; rotation must not push it.
	after.origin=before*MASS_POINT35+Vector3(item.velocity)*delta-after.basis*MASS_POINT35
	var space:PhysicsDirectSpaceState3D=host._world.get_world_3d().direct_space_state
	var excluded:Array[RID]=projectile_exclusions()
	var best:Dictionary=world_sweep32(before,after.origin-before.origin)
	var best_fraction:float=best.get("fraction32",2.);var sample_at:=Vector3.ZERO
	if angular.length_squared()>.000001:
		var rotated_hit:=world_rotational_sweep35(before,after)
		if not rotated_hit.is_empty():best=rotated_hit;best_fraction=0.
	var solid:RefCounted=host.get("_solid_weapon29")
	var swept_bounds:=AABB(before*samples[0],Vector3.ZERO)
	for point:Vector3 in samples:swept_bounds=swept_bounds.expand(before*point).expand(after*point)
	swept_bounds=swept_bounds.grow(.0002)
	if solid!=null:solid._prepare(host,swept_bounds)
	var query_skin:bool=solid==null or not solid._target_bounds_safe31 or solid._target_bounds.intersects(swept_bounds)
	var begun:=Time.get_ticks_usec()
	# Authored cutting edge, socket and butt all sweep; a broad shaft contact
	# cannot score the edge's damage or tunnel behind a nearer wall.
	for local:Vector3 in (samples if query_skin else PackedVector3Array()):
		var a:=before*local;var b:=after*local
		var result:Dictionary=contact.ray(host,space,a,b,1,excluded)
		var hit:Dictionary=result.get("hit",{})
		if not bool(result.get("supported",false)):
			var query:=PhysicsRayQueryParameters3D.create(a,b,1,excluded);query.hit_from_inside=true;hit=space.intersect_ray(query)
		if not hit.is_empty():
			var f:float=a.distance_to(hit.position)/maxf(a.distance_to(b),.000001)
			if f<best_fraction:best=hit;best_fraction=f;sample_at=local
	item.ray_usec=maxi(int(item.get("ray_usec",0)),Time.get_ticks_usec()-begun)
	if best.is_empty():
		model.global_transform=after
		return {"expired":true} if float(item.age)>12. or model.global_position.y< -10. else {}
	model.global_transform=before.interpolate_with(after,clampf(best_fraction,0.,1.))
	return {"hit":best,"sample":sample_at}
func impact(item:Dictionary,hit:Dictionary,sample:Vector3)->void:
	var model:Node3D=item.node
	var angular:Vector3=item.get("angular_velocity35",Vector3.ZERO)
	var velocity:Vector3=Vector3(item.velocity)+angular.cross(Vector3(hit.position)-model.global_transform*MASS_POINT35)
	var speed:=velocity.length();var direction:=velocity.normalized()
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
