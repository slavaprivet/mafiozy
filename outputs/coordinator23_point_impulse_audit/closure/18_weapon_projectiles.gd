extends RefCounted
const SHARED_RPG_FLIGHT := true
## Cosmetic source bullets/pellets, muzzle flash and spent casing pools.
## Caller owns accepted shots, exact mounted muzzle and collision admission.
## No HP/ammo/skin authority. Rockets/marks/blood/explosions are outside this port.
signal cosmetic_impact(receipt: Dictionary)
## Native terminal observations; never HP/ammo or an independent hit authority.
## Deferred until advance so accepted spawn batches stay callback-free.
signal projectile_resolved(receipt: Dictionary)
const RESOLUTION_LIMIT := 224
var _resolutions: Array[Dictionary] = []
var _resolution_epoch := 1
var _resolution_overflows := 0

func resolution_epoch() -> int:
	return _resolution_epoch

func _record_resolution(entry: Dictionary, status: String, hit: Dictionary = {}) -> void:
	if not entry.get("resolution_pending",false): return
	entry.resolution_pending=false
	if _resolutions.size() >= RESOLUTION_LIMIT:
		# Old incomplete aggregates must fail closed; consumers bind this epoch.
		_resolutions.clear(); _resolution_epoch+=1; _resolution_overflows+=1
	var receipt: Dictionary={"weaponId":entry.weapon_id,"shotId":entry.shot_id,
		"projectileIndex":entry.projectile_index,"projectileCount":entry.projectile_count,
		"producerEpoch":entry.producer_epoch,"status":status,"direction":entry.direction}
	if status=="hit":
		for key: String in ["point","normal","collider"]: receipt[key]=hit.get(key)
	_resolutions.append(receipt)

func _drain_resolutions() -> void:
	var completed: Array[Dictionary]=_resolutions
	_resolutions=[]
	for receipt: Dictionary in completed:
		if not _live(): return
		projectile_resolved.emit(receipt)

const SOURCE_SHA256 := "4dfa7adf47309b89dd1b87bb0776abd1b2385c15c24256b749b7c71dfa9ff7ec"
const DATA_PATH := "res://data/weapons/projectile_meshes.json"
const DATA_SHA256 := "84c1101d72a850f44149dc0be564d5d1972e9b58c60df162b53703590c52c714"
const CAPS := {"projectiles":112,"casings":48,"flashes":24,"pendingCasings":48}
const SCALE := 4.1
var _owner: WeakRef
var _ray: Callable
var _ground: Callable
var _root: Node3D
var _projectiles: Array[Dictionary]=[]
var _casings: Array[Dictionary]=[]
var _flashes: Array[Dictionary]=[]
var _pending: Array[Dictionary]=[]
var _limits: Dictionary={}
var _cursor := {"projectiles":0,"casings":0,"flashes":0}
var _counts := {"projectiles":0,"casings":0,"flashes":0}
var _active := 0
var _shots := 0
var _cases := 0
var _rounds := 0
var _configured := false
var _retired := false
var _updating := false
var _ground_y := .035
var _query_count := 0

static func _finite(value: Variant)->bool:
	return (value is float or value is int) and is_finite(value)
static func _v(value: Variant)->bool:
	return value is Vector3 and value.is_finite()
static func _vec(value: Array)->Vector3:return Vector3(value[0],value[1],value[2])
static func _positive(value: Variant,fallback: float,minimum: float)->float:
	return maxf(minimum,float(value) if _finite(value) and value!=0 else fallback)

func configure(scene: Node3D,ray_resolver: Callable,options: Dictionary={})->Dictionary:
	if _configured or _updating or _retired:return {"ok":false,"reason":"already_configured_or_retired"}
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not ray_resolver.is_valid():return {"ok":false,"reason":"live_scene_and_ray_required"}
	if FileAccess.get_sha256(DATA_PATH)!=DATA_SHA256:return {"ok":false,"reason":"mesh_hash"}
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary or data.get("source_sha256")!=SOURCE_SHA256:return {"ok":false,"reason":"source_mesh_data"}
	var requested: Variant=options.get("limits",{})
	if not requested is Dictionary:return {"ok":false,"reason":"limits"}
	for key:String in CAPS:
		var n:Variant=requested.get(key,CAPS[key])
		if not _finite(n) or n<1 or floor(n)!=n or n>CAPS[key]:return {"ok":false,"reason":"bounded_limits"}
		_limits[key]=int(n)
	if options.has("ground_height") and (not options.ground_height is Callable or not options.ground_height.is_valid()):return {"ok":false,"reason":"ground_provider"}
	if options.has("ground_y") and not _finite(options.ground_y):return {"ok":false,"reason":"ground_height"}
	_ground=options.get("ground_height",Callable());_ground_y=options.get("ground_y",.035)
	_owner=weakref(scene);_ray=ray_resolver;_root=Node3D.new();_root.name="SourceWeaponCosmetics";scene.add_child(_root)
	# The container uses world transforms: host hierarchy scale/rotation does not alter source metres.
	_root.top_level=true
	var meshes:Dictionary={}
	for key:String in data.meshes:meshes[key]=_mesh(data.meshes[key])
	for spec:Array in [["projectiles",data.projectile,_projectiles],["casings",data.casing,_casings],["flashes",data.flash,_flashes]]:
		for i in _limits[spec[0]]:
			var node:=_node(spec[1],meshes);_root.add_child(node)
			var parts:Dictionary={}
			for part:Node3D in node.get_children():parts[str(part.name)]=part
			spec[2].append({"root":node,"parts":parts,"active":false,"pool":spec[0]})
	scene.tree_exiting.connect(_owner_exit,CONNECT_ONE_SHOT)
	_configured=true
	return {"ok":true,"capacity":_limits.duplicate(),"source_sha256":SOURCE_SHA256}

func _mesh(data:Dictionary)->ArrayMesh:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	for i in range(0,data.vertices.size(),3):
		vertices.append(Vector3(data.vertices[i],data.vertices[i+1],data.vertices[i+2]))
		if not data.normals.is_empty(): normals.append(Vector3(data.normals[i],data.normals[i+1],data.normals[i+2]))
	for i in range(0,data.uv.size(),2):uv.append(Vector2(data.uv[i],data.uv[i+1]))
	var source:Array=data.indices
	if source.is_empty():for i in vertices.size():source.append(i)
	if data.get("lines",false): indices=PackedInt32Array(source)
	else:
		for i in range(0,source.size(),3):indices.append(source[i]);indices.append(source[i+2]);indices.append(source[i+1])
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
	if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL]=normals
	if not uv.is_empty():arrays[Mesh.ARRAY_TEX_UV]=uv
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_LINES if data.get("lines",false) else Mesh.PRIMITIVE_TRIANGLES,arrays);return result
func _node(data:Dictionary,meshes:Dictionary)->Node3D:
	var node:Node3D
	if data.mesh!=null:
		var instance:=MeshInstance3D.new();instance.mesh=meshes[data.mesh]
		var m:Dictionary=data.material;var material:=StandardMaterial3D.new()
		material.albedo_color=Color("#"+m.color);material.albedo_color.a=m.opacity;material.metallic=m.metalness;material.roughness=m.roughness
		if m.unlit:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		if m.transparent:material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		if not m.depthWrite:material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
		if m.additive:material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
		if m.get("doubleSided",false):material.cull_mode=BaseMaterial3D.CULL_DISABLED
		instance.material_override=material;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if str(data.name).begins_with("casing-") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node=instance
	else:node=Node3D.new()
	node.name=data.name if not str(data.name).is_empty() else "part";node.rotation_order=EULER_ORDER_XYZ
	node.position=_vec(data.position);node.quaternion=Quaternion(data.quaternion[0],data.quaternion[1],data.quaternion[2],data.quaternion[3]);node.scale=_vec(data.scale);node.visible=data.visible
	for child:Dictionary in data.children:node.add_child(_node(child,meshes))
	return node
func _owner_exit()->void:dispose()
func _live()->bool:return _configured and _owner!=null and is_instance_valid(_owner.get_ref()) and is_instance_valid(_root)
func _take(pool:Array[Dictionary],key:String)->Dictionary:
	var entry:Dictionary=pool[_cursor[key]%pool.size()];_cursor[key]+=1
	if entry.active and key=="projectiles": _record_resolution(entry,"cancelled")
	# A shared slot may own source RPG flight. Evict its exact token without
	# external callbacks or an impact, before a new projectile occupies it.
	if entry.has("external_flight"):
		entry.external_flight.retire_token(entry.external_token)
		entry.erase("external_flight");entry.erase("external_token")
	if not entry.active:entry.active=true;_active+=1;_counts[key]+=1
	entry.root.visible=true;return entry
func _hide(entry:Dictionary)->void:
	if entry.active and entry.pool=="projectiles": _record_resolution(entry,"cancelled")
	if entry.active:entry.active=false;_active-=1;_counts[entry.pool]-=1
	if is_instance_valid(entry.root):entry.root.visible=false
func _color(part:MeshInstance3D,value:Variant,source_emission:bool=false)->void:
	var m:StandardMaterial3D=part.material_override
	var c:=Color(str(value)) if value is String else Color.hex(int(value)*256+255)
	c.a=m.albedo_color.a;m.albedo_color=c
	if source_emission:
		m.emission_enabled=true;m.emission=Color(c.r*.34,c.g*.34,c.b*.34)
func _opacity(part:MeshInstance3D,alpha:float)->void:
	var m:StandardMaterial3D=part.material_override;var c:=m.albedo_color;c.a=alpha;m.albedo_color=c

func can_shoot(shot:Dictionary,muzzle:Dictionary,target:Vector3)->bool:
	if not _live() or _updating:return false
	var projectiles:Variant=shot.get("projectiles")
	if not projectiles is Array or projectiles.is_empty() or projectiles.size()>7 or not _v(muzzle.get("origin")) or not target.is_finite():return false
	var origin:Vector3=muzzle.origin;var ejection:Variant=muzzle.get("ejection_origin",origin)
	if not _v(ejection):return false
	var direction:Vector3=target-origin
	if not is_finite(direction.length_squared()) or direction.length_squared()<1e-8:return false
	if not shot.get("weaponId") is String or shot.weaponId.is_empty():return false
	for p:Variant in projectiles:
		if not p is Dictionary or p.get("explosive",false) or not p.get("visual",{}) is Dictionary:return false
		for key:String in ["speed","range","yawOffset","pitchOffset"]:
			if p.has(key) and not _finite(p[key]):return false
		for key:String in ["caliber","length","trail"]:
			if p.get("visual",{}).has(key) and not _finite(p.visual[key]):return false
	var casing:Variant=shot.get("casing")
	if casing!=null and not casing is Dictionary:return false
	if casing!=null:
		for key:String in ["delay","scale"]:
			if casing.has(key) and not _finite(casing[key]):return false
		if not casing.get("velocity",{}) is Dictionary:return false
		for key:String in ["right","up","forward"]:
			if casing.get("velocity",{}).has(key) and not _finite(casing.velocity[key]):return false
	return true

func shoot(shot:Dictionary,muzzle:Dictionary,target:Vector3,obstacle_port:Callable=Callable())->bool:
	if not can_shoot(shot,muzzle,target):return false
	var projectiles:Array=shot.projectiles
	var origin:Vector3=muzzle.origin
	var ejection:Vector3=muzzle.get("ejection_origin",origin)
	var casing:Variant=shot.get("casing")
	var direction:Vector3=(target-origin).normalized();_shots+=1
	_flash(origin,direction,str(projectiles[0].get("visual",{}).get("kind","round")))
	if casing!=null:
		_pending.append({"delay":maxf(0,casing.get("delay",0)),"origin":ejection,"direction":direction,"casing":casing.duplicate(true),"weaponId":shot.get("weaponId","")})
		if _pending.size()>_limits.pendingCasings:_pending.pop_front()
	for projectile_index in projectiles.size():
		var projectile: Dictionary=projectiles[projectile_index]
		var dir:=direction.rotated(Vector3.UP,projectile.get("yawOffset",0));var right:=dir.cross(Vector3.UP)
		if right.length_squared()>1e-8:dir=dir.rotated(right.normalized(),projectile.get("pitchOffset",0))
		_spawn(projectile,shot,origin,dir.normalized(),obstacle_port if obstacle_port.is_valid() else _ray,projectile_index,projectiles.size())
	return true
func _flash(origin:Vector3,direction:Vector3,kind:String)->void:
	var e:=_take(_flashes,"flashes");e.life=.07 if kind=="pellet" else .052;e.max_life=e.life;e.strength=1.25 if kind=="pellet" else (.9 if kind=="rifle" else .65)
	e.root.position=origin;e.root.quaternion=Quaternion(Vector3.BACK,direction);e.root.scale=Vector3.ONE*e.strength
	_color(e.parts["muzzle-hot-core"],0xfff4cf);_color(e.parts["muzzle-forward-flame"],0xffa241);_opacity(e.parts["muzzle-hot-core"],1);_opacity(e.parts["muzzle-forward-flame"],.8)
	var children:Array=e.root.get_children()
	for n in 3:
		var petal:Node3D=children[n+2];var angle:float=_shots*2.399963+n*TAU/3
		petal.position=Vector3(cos(angle)*.065,sin(angle)*.065,.095);petal.quaternion=Quaternion(Vector3.UP,Vector3(cos(angle)*.55,sin(angle)*.55,1).normalized());petal.scale=Vector3(1,.78+(n%2)*.3,.45)
		_color(petal,0xffa241);_opacity(petal,.8)
func _spawn(p:Dictionary,shot:Dictionary,origin:Vector3,direction:Vector3,ray:Callable,projectile_index:int,projectile_count:int)->void:
	var e:=_take(_projectiles,"projectiles");var visual:Dictionary=p.get("visual",{});var kind:String=visual.get("kind","round")
	var caliber:=_positive(visual.get("caliber"),.007,.004);var length:=_positive(visual.get("length"),.065,.03);var trail:=_positive(visual.get("trail"),.08,.03)
	e.root.position=origin+direction*.045;e.root.quaternion=Quaternion(Vector3.BACK,direction);e.direction=direction;e.speed=_positive(p.get("speed"),20,.1)*SCALE;e.remaining=_positive(p.get("range"),8,.2)*SCALE
	e.ray=ray;e.sweep_origin=origin;e.first=true;e.visual_id=str(p.get("visualId",kind));e.weapon_id=str(shot.get("weaponId",e.visual_id));e.shot_id=str(shot.get("shotId",e.weapon_id+":"+str(shot.get("sequence",""))))
	var parts:Dictionary=e.parts;var core:MeshInstance3D=parts["projectile-core"];var nose:MeshInstance3D=parts["projectile-nose"];var streak:MeshInstance3D=parts["projectile-motion-streak"];var jacket:MeshInstance3D=parts["projectile-jacket-band"]
	core.scale=Vector3(caliber*2,length,caliber*2);nose.visible=kind!="pellet";nose.scale=Vector3(caliber*1.35,length*.22,caliber*1.35);nose.position.z=length*.58
	streak.scale=Vector3(maxf(.003,caliber*.24),trail,maxf(.003,caliber*.24));streak.position.z=-trail*.52-length*.42;_opacity(streak,.28 if kind=="pellet" else .52)
	var color:Variant=visual.get("color",p.get("color","#caa36a"));_color(core,color,true);_color(nose,color,true);_color(streak,0xe8cc91)
	jacket.visible=kind!="pellet";jacket.scale=Vector3(caliber*2.07,length*.08,caliber*2.07);jacket.position.z=-length*.33
	e.projectile_kind=kind
	e.projectile_index=projectile_index;e.projectile_count=projectile_count;e.producer_epoch=_resolution_epoch;e.resolution_pending=true
	_rounds+=1
func _eject(pending:Dictionary)->void:
	var e:=_take(_casings,"casings");var casing:Dictionary=pending.casing;var shell:bool=pending.weaponId in ["shotgun","sawn_off"];var rifle:bool=pending.weaponId in ["ak74","m16","sniper"]
	e.life=4.2;e.kind="shotgun-shell" if shell else ("rifle-brass" if rifle else "pistol-brass");e.settled=false;e.bounces=0;e.root.position=pending.origin;e.rotation=Vector3(.4,_cases*1.7,.2);e.root.rotation=e.rotation
	var right:=Vector3.UP.cross(pending.direction);right=Vector3.RIGHT if right.length_squared()<1e-8 else right.normalized();var velocity:Dictionary=casing.get("velocity",{})
	e.velocity=right*velocity.get("right",1.65+(_cases%3)*.15)+Vector3.UP*velocity.get("up",2.2)+pending.direction*velocity.get("forward",-.4);e.spin=Vector3(13+(_cases%4)*1.2,5+(_cases%3)*2.1,9+(_cases%5))
	e.root.scale=Vector3(1.2 if shell else 1,1.35 if rifle else 1,1.2 if shell else 1)*casing.get("scale",1)
	var body:MeshInstance3D=e.parts["casing-hollow-body"];_color(body,0x9e2c21 if shell else 0xc89b48);body.material_override.metallic=.12 if shell else .82;body.material_override.roughness=.58 if shell else .25
	e.parts["casing-rifle-shoulder"].visible=rifle;e.parts["casing-open-mouth"].position.y=.049 if rifle else .037;e.parts["casing-open-mouth"].scale=Vector3.ONE*(.65 if rifle else 1);_cases+=1

func advance(delta:float)->void:
	if not _live() or _updating or not is_finite(delta) or delta<0:return
	if _active==0 and _pending.is_empty() and _resolutions.is_empty():return
	_updating=true;var dt:=minf(.1,delta)
	for i in range(_pending.size()-1,-1,-1):
		_pending[i].delay-=dt
		if _pending[i].delay<=0:_eject(_pending[i]);_pending.remove_at(i)
	if _counts.projectiles>0:
		for e:Dictionary in _projectiles:
			if not e.active or e.has("external_flight"):continue
			var distance:float=minf(e.remaining,e.speed*dt)
			if distance<=0:continue
			var origin:Vector3=e.sweep_origin if e.first else e.root.position
			var sweep_range:float=distance+(.045 if e.first else 0)
			_query_count+=1
			var hit:Variant=e.ray.call({"origin":origin,"direction":e.direction,"range":sweep_range,"weaponId":e.weapon_id,"shotId":e.shot_id}) if e.ray.is_valid() else null
			if not _live():_updating=false;return
			if not hit is Dictionary:_hide(e);continue # Invalid or retired provider fails closed.
			e.first=false
			if not hit.is_empty():
				if not _v(hit.get("point")) or not _v(hit.get("normal")) or not _finite(hit.get("distance")) or hit.distance<0 or hit.distance>sweep_range+.00001 or hit.normal.length_squared()<1e-12:_hide(e);continue
				if (hit.point-(origin+e.direction*hit.distance)).length()>.0001:_hide(e);continue
				e.root.position=hit.point
				var receipt:Dictionary={"weaponId":e.weapon_id,"shotId":e.shot_id,"point":hit.point,"normal":hit.normal.normalized(),"direction":e.direction,"collider":hit.get("collider"),"projectile_kind":e.projectile_kind,"cosmetic_only":true}
				_record_resolution(e,"hit",receipt)
				_hide(e);cosmetic_impact.emit(receipt)
				if not _live():_updating=false;return
			else:
				e.root.position+=e.direction*distance;e.remaining-=distance
				if e.remaining<=1e-5:
					_record_resolution(e,"miss");_hide(e)
	if _counts.casings>0:
		for e:Dictionary in _casings:
			if not e.active:continue
			e.life-=delta
			if e.life<=0:_hide(e);continue
			if e.settled:continue
			e.velocity.y-=9.8*dt;e.root.position+=e.velocity*dt;e.rotation+=e.spin*dt;e.root.rotation=e.rotation
			var sampled:Variant=_ground.call(e.root.position.x,e.root.position.z,e.root.position.y) if _ground.is_valid() else null
			if not _live():_updating=false;return
			var floor_y:float=sampled+.028*maxf(e.root.scale.x,e.root.scale.z) if _finite(sampled) else _ground_y
			if e.root.position.y<floor_y:
				e.root.position.y=floor_y;e.bounces+=1;e.velocity.y=absf(e.velocity.y)*(.32 if e.bounces==1 else .18);e.velocity.x*=.55;e.velocity.z*=.55;e.spin*=.43
				if e.velocity.y<.22 or e.bounces>=3:e.settled=true;e.velocity=Vector3.ZERO;e.spin=Vector3.ZERO;e.rotation.x=PI/2;e.rotation.z=0;e.root.rotation=e.rotation
	if _counts.flashes>0:
		for e:Dictionary in _flashes:
			if not e.active:continue
			e.life-=delta
			if e.life<=0:_hide(e);continue
			var p:float=e.life/e.max_life;e.root.scale=Vector3.ONE*e.strength*(.6+p*.5);_opacity(e.parts["muzzle-hot-core"],p)
			for part:Node3D in e.root.get_children():
				if part.name!="muzzle-hot-core":_opacity(part,p*p*.8)
	_drain_resolutions()
	_updating=false

func stats()->Dictionary:
	return {"totalShots":_shots,"totalCases":_cases,"totalProjectiles":_rounds,"active":_active,"activeProjectiles":_counts.projectiles,"activeCasings":_counts.casings,"activeFlashes":_counts.flashes,"pendingCasings":_pending.size(),"rayQueries":_query_count,"configured":_configured}
func debug_snapshot()->Dictionary:
	var result:Dictionary={"projectiles":[],"casings":[],"flashes":[],"pending":_pending.size(),"totalShots":_shots,"totalCases":_cases,"totalProjectiles":_rounds}
	for e:Dictionary in _projectiles:
		if e.active:result.projectiles.append({"position":e.root.position,"direction":e.direction,"remaining":e.remaining,"core_size":e.parts["projectile-core"].scale,"nose_size":e.parts["projectile-nose"].scale,"trail_size":e.parts["projectile-motion-streak"].scale,"jacket_size":e.parts["projectile-jacket-band"].scale,"visual_id":e.visual_id})
	for e:Dictionary in _casings:
		if e.active:result.casings.append({"position":e.root.position,"velocity":e.velocity,"spin":e.spin,"life":e.life,"kind":e.kind,"settled":e.settled,"bounces":e.bounces,"scale":e.root.scale,"rotation":e.rotation})
	for e:Dictionary in _flashes:
		if e.active:result.flashes.append({"position":e.root.position,"life":e.life,"scale":e.root.scale,"core_opacity":e.parts["muzzle-hot-core"].material_override.albedo_color.a,"cone_opacity":e.parts["muzzle-forward-flame"].material_override.albedo_color.a})
	return result
func dispose()->void:
	for entry:Dictionary in _projectiles:
		if entry.has("external_flight"):
			entry.external_flight.retire_token(entry.external_token)
			entry.erase("external_flight");entry.erase("external_token")
	_configured=false;_retired=true;_pending.clear()
	_resolutions.clear();_resolution_epoch+=1
	if _owner!=null:
		var scene:Variant=_owner.get_ref()
		if is_instance_valid(scene) and scene.tree_exiting.is_connected(_owner_exit):scene.tree_exiting.disconnect(_owner_exit)
	_owner=null;_ray=Callable();_ground=Callable()
	if is_instance_valid(_root):
		_root.hide();_root.queue_free()
	_root=null;_projectiles.clear();_casings.clear();_flashes.clear();_active=0;_counts={"projectiles":0,"casings":0,"flashes":0}
