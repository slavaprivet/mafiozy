extends RefCounted
## Opt-in LOCAL entry proxy. Host.step is the only caller allowed to move.
## Pinned source polygons retain the .738m square; actual native shapes remain.
const Sweep = preload("npc_contact_sweep.gd")
const ACCEPTED := {
	"REBUILD-VISUAL-hospital-001":"38fd812d2619fe9ba705ff042bfdcb9b6488747902daba3be94f7b1d744983c1",
	"REBUILD-bank:small":"f391543571b8eafef6aef2feccd14ce3e28dd00a5c46d4ed93b66c8ee7d520ba"}
const HALF := .738
const OFFSETS := [Vector2.ZERO,Vector2(-HALF,-HALF),Vector2(-HALF,HALF),Vector2(HALF,-HALF),Vector2(HALF,HALF)]
const LOCAL_ID_BASE := 2000000000
static var _next_id := LOCAL_ID_BASE
var host: RefCounted
var base_nav: RefCounted
var policy: RefCounted
var token: Dictionary = {}
var body: CharacterBody3D
var scene: Node3D
var interior: Node3D
var _activity: WeakRef
var _data: Dictionary = {}
var _phase := "UNBOUND"
var _disposed := false
var _busy := false
var _active := -1
var _requests: Dictionary = {}
var _version := -1
var _origin := Vector3.ZERO
var _handoff := Vector3.ZERO
var _pins: Array = []
var _resources: Array[Resource] = []
var _parents: Array[Node] = []
var _entry_rids: Array[RID] = []
var _visual: WeakRef
var _visual_frame := Transform3D.IDENTITY
var _doors: Dictionary = {}
var _invalid := false
var _solids: Array = []
var _floors: Dictionary = {}
var _floor_cells: Dictionary = {}
var _sweep := Sweep.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _capsule := PhysicsShapeQueryParameters3D.new()
var _square := PhysicsShapeQueryParameters3D.new()
var diagnostics := {"steps":0,"travel_m":0.0,"step_us_total":0,"step_us_max":0,"floor_queries":0,"source_sweeps":0,"reason":"","current_us_peaks":[]}

static func _v(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
# DSH_DAILYPIN: configure() re-proves the same pinned route bytes on every hospital/bank
# start. With --city-daily-pin-cache=1 one accepted packet per source_id is proven once and
# reused; every source shape, polygon and the .738 m square stay untouched. 0 (default)
# re-proves every start, exactly as today.
static var _dsh_pin_flag := -1  # DSH_DAILYPIN
static var _dsh_pin_data: Dictionary = {}  # DSH_DAILYPIN
static var _dsh_pin_site := ""  # DSH_DAILYPIN

static func _dsh_pin_on() -> bool:  # DSH_DAILYPIN
	if _dsh_pin_flag < 0:
		_dsh_pin_flag = 1  # DSH_ACCEPTED: the pinned session constants are proven once by default; --city-daily-pin-cache=0 restores the per-start re-proof
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-pin-cache="):
				_dsh_pin_flag = 1 if int(argument.trim_prefix("--city-daily-pin-cache=")) != 0 else 0
	return _dsh_pin_flag == 1

static func _dsh_pinned_data(route_bytes: PackedByteArray, id: String) -> Variant:  # DSH_DAILYPIN
	if _dsh_pin_on() and _dsh_pin_site==id and not _dsh_pin_data.is_empty(): return _dsh_pin_data
	if _hash(route_bytes)!=ACCEPTED[id]: return null
	var data: Variant=JSON.parse_string(route_bytes.get_string_from_utf8())
	if not data is Dictionary: return null
	if _dsh_pin_on(): _dsh_pin_data=data; _dsh_pin_site=id
	return data

# DSH_VISITCACHE: --city-visit-scene-cache=1 (default) builds the two per-configure
# enumerations of this route once per SCENE and reuses them; 0 is today's path and
# re-enumerates both on every configure.
#   (a) every other block record's collision body, converted and box-filtered - a pure
#       function of scene._block (written once, main.gd:133) and of the site's _origin;
#   (b) interior.find_children("*","CollisionShape3D",true,false) - the same node list for
#       every route instance of the same interior adapter.
# The DATA lives in the metadata of the scene node and of the interior node (never in a
# global, never in a static), so it is dropped together with the objects it describes.
const DSH_VISIT_CACHE_KEY := "dsh_visit_scene_cache"  # DSH_VISITCACHE
const DSH_VISIT_CACHE_SCHEMA := 1  # DSH_VISITCACHE
const DSH_VISIT_PINS_KEY := "dsh_visit_pin_nodes"  # DSH_VISITCACHE
const DSH_VISIT_PINS_SCHEMA := 1  # DSH_VISITCACHE
static var _dsh_visit_cache := -1  # DSH_VISITCACHE

# DSH_VISITCACHE: --city-visit-scene-cache, read once per run (the route object itself is
# created and disposed per visit, so the flag cannot live on the instance).
static func _dsh_visit_cache_on() -> bool:  # DSH_VISITCACHE
	if _dsh_visit_cache < 0:
		_dsh_visit_cache = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-visit-scene-cache="):
				_dsh_visit_cache = 0 if int(argument.trim_prefix("--city-visit-scene-cache=")) == 0 else 1
	return _dsh_visit_cache == 1

# DSH_VISITCACHE: the scene-scoped cache dictionary, or {} when the flag is off / the scene is
# not the one the entry was built for. Every use re-proves the block revision: the same
# buildings/decor Array instances, the same counts and the same _origin. main.gd:133 is the
# only writer of `_block` in the tree and nothing mutates it afterwards, so this can only fail
# on a scene that was rebuilt - and then the entry is rebuilt from today's loops.
func _dsh_scene_cache() -> Dictionary:  # DSH_VISITCACHE
	if not _dsh_visit_cache_on() or not is_instance_valid(scene): return {}
	var value: Variant=scene.get_meta(DSH_VISIT_CACHE_KEY,{})
	var cache: Dictionary=value if value is Dictionary else {}
	var block_value: Variant=scene.get("_block")
	if not block_value is Dictionary: return {}
	var block: Dictionary=block_value
	if int(cache.get("schema",0))!=DSH_VISIT_CACHE_SCHEMA or not is_same(cache.get("buildings"),block.buildings) or not is_same(cache.get("decor"),block.decor) or cache.get("counts",{})!=block.get("counts",{}) or cache.get("origin",Vector3.INF)!=scene.get("_origin"):
		cache={"schema":DSH_VISIT_CACHE_SCHEMA,"buildings":block.buildings,"decor":block.decor,"counts":block.get("counts",{}),"origin":scene.get("_origin"),"parts":{},"hits":int(cache.get("hits",0)),"builds":int(cache.get("builds",0)),"lookups":int(cache.get("lookups",0)),"us":int(cache.get("us",0))}
		scene.set_meta(DSH_VISIT_CACHE_KEY,cache)
	return cache

# DSH_VISITCACHE: the trigger counters of the DSH_DAILY line in npc_city_daily.gd (lookups =
# cache decisions, hits/builds their outcome, us = the time this cache itself spent).
func _dsh_cache_count(cache: Dictionary,hit: bool,elapsed: int) -> void:  # DSH_VISITCACHE
	if cache.is_empty(): return
	cache["lookups"]=int(cache["lookups"])+1
	if hit: cache["hits"]=int(cache["hits"])+1
	else: cache["builds"]=int(cache["builds"])+1
	cache["us"]=int(cache["us"])+elapsed

# DSH_VISITCACHE (a): today's block enumeration of npc_daily_entry_route.gd:102-108, run once per
# scene and part. The part is keyed by the site source_id AND re-proved against the exact _origin
# and _data.bounds it was filtered with, because _near() reads both.
func _dsh_site_solids(id: String) -> Array:  # DSH_VISITCACHE
	var started:=Time.get_ticks_usec()
	var cache: Dictionary=_dsh_scene_cache()
	var key: String="site:"+id
	if not cache.is_empty():
		var parts: Dictionary=cache["parts"]
		var entry: Variant=parts.get(key)
		if entry is Dictionary and entry.get("origin")==_origin and entry.get("bounds")==_data.get("bounds"):
			_dsh_cache_count(cache,true,Time.get_ticks_usec()-started)
			return entry["solids"]
	var kept: Array=[]
	for building: Dictionary in scene.get("_block").buildings+scene.get("_block").decor:
		if building.id==id: continue
		for solid: Dictionary in building.collisionBodiesM:
			var points: Array=[]
			for p: Array in solid.polygonXZ: points.append([(p[0]+_origin.x)/4.1,(p[1]+_origin.z)/4.1])
			var candidate:={"polygonCR":points,"minYM":solid.minY,"maxYM":solid.maxY,"node":building.id}
			if _near(candidate): kept.append(candidate)
	if not cache.is_empty():
		var parts: Dictionary=cache["parts"]
		parts[key]={"origin":_origin,"bounds":_data.get("bounds"),"solids":kept}
	_dsh_cache_count(cache,false,Time.get_ticks_usec()-started)
	return kept

# DSH_VISITCACHE (b): the interior's CollisionShape3D list, cached in the INTERIOR's own
# metadata. A hit re-proves what the list was built from with O(1) metadata plus one
# is_instance_valid() per cached shape: the interior's identity (this metadata), the schema, the
# interior's direct-child count, and that every cached shape is still a live instance. A freed shape (removal, container
# removal, or a swap that freed one shape and added another) fails that test and forces a
# rebuild, so the cached list can never hand a dangling node to the pin loop. A live route also
# drops the entry from _child_changed(), i.e. from the watchers that already invalidate its own
# pins. A per-container child-count stamp was read, priced and REJECTED: it costs 107/404/136
# GDScript reads (~30-200 us) per hit, as much as the C++ traversal it would protect.
func _dsh_pin_nodes() -> Array:  # DSH_VISITCACHE
	var started:=Time.get_ticks_usec()
	var cache: Dictionary=_dsh_scene_cache()
	var held: Variant=null
	if not cache.is_empty() and is_instance_valid(interior) and interior.ready_for_use:
		var value: Variant=interior.get_meta(DSH_VISIT_PINS_KEY,{})
		var entry: Dictionary=value if value is Dictionary else {}
		if int(entry.get("schema",0))==DSH_VISIT_PINS_SCHEMA and int(entry.get("interior_children",-1))==interior.get_child_count():
			var current:=true
			for node: Node in entry["nodes"]:
				if not is_instance_valid(node):current=false;break
			if current: held=entry["nodes"]
	if held!=null:
		_dsh_cache_count(cache,true,Time.get_ticks_usec()-started)
		return held
	var nodes: Array=interior.find_children("*","CollisionShape3D",true,false)
	if not cache.is_empty() and is_instance_valid(interior) and interior.ready_for_use:
		interior.set_meta(DSH_VISIT_PINS_KEY,{"schema":DSH_VISIT_PINS_SCHEMA,"nodes":nodes,"interior_children":interior.get_child_count()})
	_dsh_cache_count(cache,false,Time.get_ticks_usec()-started)
	return nodes

# DSH_VISITCACHE: a membership change under the interior drops the cached node list. Every live
# route instance calls this from _child_changed(), i.e. from exactly the watchers that already
# invalidate its own pins, and the cache is then rebuilt by the next configure.
func _dsh_pins_invalidate() -> void:  # DSH_VISITCACHE
	if is_instance_valid(interior) and interior.has_meta(DSH_VISIT_PINS_KEY):interior.remove_meta(DSH_VISIT_PINS_KEY)

static func _hash(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()

func configure(owner: RefCounted, outdoor: RefCounted, navigation: RefCounted, root: Node3D, actor_token: Dictionary, site: Node3D, route_bytes: PackedByteArray, activity_owner: RefCounted) -> Dictionary:
	if not Thread.is_main_thread() or host!=null or _disposed or owner._navigation!=navigation or not owner.target_current(actor_token): return {"ok":false,"reason":"current_host"}
	if not is_instance_valid(site) or not site.get("ready_for_use") or not is_instance_valid(activity_owner): return {"ok":false,"reason":"loaded_site"}
	var targets: Dictionary=site.targets();var id: String=targets.get("source_id","")
	# DSH_DAILYPIN: same pin, same failure label; the proof is cached when the flag is on.
	var pinned: Variant=_dsh_pinned_data(route_bytes,id) if ACCEPTED.has(id) else null
	if pinned==null: return {"ok":false,"reason":"pinned_route_bytes"}
	var data: Variant=pinned
	if not data is Dictionary or data.get("source_id")!=id or data.get("interior_sha256")!=targets.get("data_sha256") or data.get("half_extent_m")!=HALF: return {"ok":false,"reason":"source_geometry_scope"}
	for method: String in ["access_version","_owner_allowed","_index","purposeful_entry_land_allowed","current_vehicle_clear_segment","admit_daily_handoff"]:
		if not outdoor.has_method(method): return {"ok":false,"reason":"current_source_policy:"+method}
	var lease: Dictionary=owner.daily_activity_status(actor_token.source_id)
	if lease.get("owner")!=activity_owner or not lease.get("current",false): return {"ok":false,"reason":"daily_owner"}
	var old: Variant=owner._records[actor_token.source_id].get("local_route_owner")
	if old is WeakRef and is_instance_valid(old.get_ref()): return {"ok":false,"reason":"local_owner_exists"}
	host=owner;policy=outdoor;base_nav=navigation;scene=root;interior=site;token=actor_token.duplicate();body=token.body;_activity=weakref(activity_owner);_data=data
	_origin=_v(data.originM);_version=policy.access_version();_handoff=body.global_position
	_visual=weakref(interior._visual);_visual_frame=interior._visual.global_transform
	if _handoff.distance_to(_v(data.goals.handoff))>.30: dispose();return {"ok":false,"reason":"actual_street_handoff_required"}
	# Before the special entry scope, the precise actual outdoor handoff still
	# requires current purposeful source/native admission for this daily actor.
	var excluded: Array[RID]=[body.get_rid()]
	if not policy.admit_daily_handoff(token,_handoff) or not host._physical_clear(_handoff,excluded): dispose();return {"ok":false,"reason":"purposeful_handoff_admission"}
	_capsule.shape=body.get_child(0).shape;_capsule.collision_mask=1|256;_capsule.margin=.001;_capsule.exclude=excluded
	var box:=BoxShape3D.new();box.size=Vector3(HALF*2,1.9,HALF*2)
	_square.shape=box;_square.collision_mask=1|256;_square.margin=.001
	_ray.collision_mask=1;_ray.exclude=excluded
	_solids=data.staticBodies.duplicate(true)
	_solids.append_array(_dsh_site_solids(id))  # DSH_VISITCACHE
	for node: Node in _dsh_pin_nodes():  # DSH_VISITCACHE
		var shape:=node as CollisionShape3D;var collider:=shape.get_parent() as CollisionObject3D
		if collider==null or collider.get_meta("source_id","")!=id or shape.disabled or shape.shape==null or collider.collision_layer!=1: dispose();return {"ok":false,"reason":"native_entry_geometry"}
		var moving:=false
		for door: Dictionary in interior._doors.values():
			if door.node.is_ancestor_of(shape): moving=true
		_pins.append({"node":weakref(shape),"parent":collider,"container":collider.get_parent(),"shape":shape.shape,"local":shape.transform,"frame":shape.global_transform,"layer":collider.collision_layer,"mask":collider.collision_mask,"moving":moving})
		if not collider.get_rid() in _entry_rids:_entry_rids.append(collider.get_rid())
		_watch_resource(shape.shape);_watch_parent(collider)
	if _pins.is_empty(): dispose();return {"ok":false,"reason":"native_shapes_missing"}
	for key: String in ["public_0","public_1"]:
		var door: Dictionary=interior._doors[key]
		_doors[key]={"node":door.node,"base":door.base,"spec":door.spec.duplicate(true)}
		_watch_parent(door.node)
	_watch_resource(_capsule.shape);_watch_parent(interior)
	_index_floors();_phase="READY"
	host._records[token.source_id]["local_route_owner"]=weakref(self)
	if not _current(): dispose();return {"ok":false,"reason":"geometry_or_actor_lease"}
	return {"ok":true,"source_id":id,"host_sole_mover":true}

func _watch_resource(resource: Resource) -> void:
	if resource in _resources:return
	_resources.append(resource);resource.changed.connect(_changed)
func _watch_parent(parent: Node) -> void:
	if parent in _parents:return
	_parents.append(parent);parent.child_entered_tree.connect(_child_changed);parent.child_exiting_tree.connect(_child_changed)
func _changed() -> void:_invalid=true
func _child_changed(_node: Node) -> void:_invalid=true;_dsh_pins_invalidate()

func _near(solid: Dictionary) -> bool:
	var min_x:=INF;var min_z:=INF;var max_x:=-INF;var max_z:=-INF
	for p: Array in solid.polygonCR:
		var x:float=p[0]*4.1-_origin.x;var z:float=p[1]*4.1-_origin.z
		min_x=minf(min_x,x);max_x=maxf(max_x,x);min_z=minf(min_z,z);max_z=maxf(max_z,z)
	var b:Array=_data.bounds
	return max_x>=b[0]-HALF and min_x<=b[2]+HALF and max_z>=b[1]-HALF and min_z<=b[3]+HALF

func _owns_life() -> bool:
	if host==null or not host.physical_life_current(token):return false
	var claim:Variant=host._records[token.source_id].get("local_route_owner")
	return claim is WeakRef and claim.get_ref()==self

func _current(full_geometry: bool=true) -> bool:
	var started:=Time.get_ticks_usec();var result:=_current_impl(full_geometry);var elapsed:=Time.get_ticks_usec()-started
	if elapsed>=1000:
		var peaks:Array=diagnostics.current_us_peaks;peaks.append(elapsed);peaks.sort();if peaks.size()>12:peaks.resize(12);diagnostics.current_us_peaks=peaks
	return result

func _current_impl(full_geometry: bool=true) -> bool:
	if not Thread.is_main_thread() or _disposed or _invalid or _phase=="SUPERSEDED" or not _owns_life():return false
	if not is_instance_valid(interior) or not interior.is_inside_tree() or not interior.ready_for_use or not interior.global_transform.is_equal_approx(Transform3D.IDENTITY):return false
	if _visual==null or not is_instance_valid(_visual.get_ref()) or interior._visual!=_visual.get_ref() or not _visual.get_ref().global_transform.is_equal_approx(_visual_frame):return false
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not scene.global_transform.is_equal_approx(Transform3D.IDENTITY) or body.get_parent()!=scene or interior.get_parent()!=scene or interior.get_world_3d()!=body.get_world_3d() or not host._local_walker_current(token):return false
	if policy.access_version()!=_version or not policy._owner_allowed(token.source_id,token.life_generation):return false
	var lease:Dictionary=host.daily_activity_status(token.source_id)
	if _activity==null or not is_instance_valid(_activity.get_ref()) or lease.get("owner")!=_activity.get_ref() or not lease.get("current",false):return false
	if _active>=0 and host._records[token.source_id].request!=_active:return false
	var shape:CollisionShape3D=body.get_child(0)
	if shape.shape!=_capsule.shape or not shape.position.is_equal_approx(Vector3(0,.95,0)) or not shape.basis.is_equal_approx(Basis.IDENTITY):return false
	if full_geometry:
		for pin:Dictionary in _pins:
			var node:CollisionShape3D=pin.node.get_ref()
			if not is_instance_valid(node) or not is_instance_valid(pin.parent) or node.get_parent()!=pin.parent or pin.parent.get_parent()!=pin.container or node.shape!=pin.shape or node.disabled or node.transform!=pin.local or pin.parent.collision_layer!=pin.layer or pin.parent.collision_mask!=pin.mask or (not pin.moving and not node.global_transform.is_equal_approx(pin.frame)):return false
	for key:String in _doors:
		var door:Dictionary=interior._doors[key];var pin:Dictionary=_doors[key]
		if door.node!=pin.node or door.base!=pin.base or door.node.get_parent()!=interior or (full_geometry and door.spec!=pin.spec):return false
		var f:float=door.fraction
		if not is_finite(f) or f<0 or f>1:return false
		var expected:Transform3D=pin.base*Transform3D(Basis(Vector3.UP,float(pin.spec.angle)*f*f*(3.0-2.0*f)),Vector3.ZERO)
		if not door.node.transform.is_equal_approx(expected):return false
	return true

func _index_floors() -> void:
	for tri:Dictionary in _data.floorTriangles:
		var a:=_v(tri.a);var b:=_v(tri.b);var c:=_v(tri.c)
		var item:={"a":a,"b":b,"c":c,"den":(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)}
		for x:int in range(floori(minf(a.x,minf(b.x,c.x))),floori(maxf(a.x,maxf(b.x,c.x)))+1):
			for z:int in range(floori(minf(a.z,minf(b.z,c.z))),floori(maxf(a.z,maxf(b.z,c.z)))+1):
				var key:=Vector2i(x,z)
				if not _floor_cells.has(key):_floor_cells[key]=[]
				_floor_cells[key].append(item)

func _source_floor(x:float,z:float) -> float:
	var result:=-INF
	for t:Dictionary in _floor_cells.get(Vector2i(floori(x),floori(z)),[]):
		if absf(t.den)<.0000000001:continue
		var a:Vector3=t.a;var b:Vector3=t.b;var c:Vector3=t.c
		var u:float=((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/t.den
		var v:float=((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/t.den
		var w:=1.0-u-v
		if minf(u,minf(v,w))<-.000001:continue
		var y:=u*a.y+v*b.y+w*c.y
		if y<=float(_data.ground_floor_max_y):result=maxf(result,y)
	return NAN if result==-INF else result

func _valid_terrain(rid:RID) -> bool:
	if not policy._floors.has(rid):return false
	var pin:Dictionary=policy._floors[rid];var collider:Variant=pin.body.get_ref();var shape:Variant=pin.shape.get_ref()
	return is_instance_valid(collider) and is_instance_valid(shape) and collider.get_parent()==scene and collider.global_transform.is_equal_approx(pin.frame) and collider.collision_layer==1 and not shape.disabled and shape.transform.is_equal_approx(Transform3D.IDENTITY) and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(pin.size)

func _floor_preview(x:float,z:float) -> float:
	var key:=Vector2(x,z)
	if _floors.has(key):return _floors[key]
	var index:int=policy._index(Vector3(x,0,z))
	if index<0 or policy._land[index]==0 or not policy.purposeful_entry_land_allowed(token,Vector3(x,0,z)):
		diagnostics["last_floor_failure"]={"point":Vector2(x,z),"reason":"terrain_land","index":index,"source_floor":_source_floor(x,z)}
		return NAN
	var expected:=_source_floor(x,z)
	if not is_finite(expected):expected=float(policy._heights[index])
	_ray.from=Vector3(x,expected+.25,z);_ray.to=Vector3(x,expected-.25,z)
	var space:PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
	var hit:Dictionary=space.intersect_ray(_ray);diagnostics.floor_queries+=1
	var result:=NAN
	if not hit.is_empty() and hit.normal.y>=.70 and absf(hit.position.y-expected)<.002:
		var collider:CollisionObject3D=hit.collider
		if _valid_terrain(hit.rid) or (hit.rid in _entry_rids and interior.is_ancestor_of(collider) and collider.get_meta("source_id","")==_data.source_id):result=hit.position.y
	elif not hit.is_empty() and hit.normal.y>=.70 and _pinned_bank_floor_seam(hit,expected):
		# The original 18.6m bank floor box overlaps the authored continuous
		# entrance ramp by 150mm at its east edge. There, its exact native top
		# (0.1m) is up to 6.77mm above the source ramp triangles. Keep the real
		# collision authoritative, but accept only this exact pinned floor and
		# only the measured <=10mm overlap band.
		result=hit.position.y
		diagnostics["bank_floor_seam"]={"point":Vector2(x,z),"source_y":expected,"native_y":hit.position.y,"delta_m":hit.position.y-expected}
	if not is_finite(result): diagnostics["last_floor_failure"]={"point":Vector2(x,z),"reason":"native_floor","expected":expected,"hit_position":hit.get("position"),"hit_normal":hit.get("normal"),"collider":str(hit.get("collider")),"entry_rid":hit.get("rid",RID()) in _entry_rids}
	_floors[key]=result;return result

func _pinned_bank_floor_seam(hit:Dictionary,source_y:float)->bool:
	if _data.source_id!="REBUILD-bank:small" or interior==null or interior.get("SOURCE_ID")!="REBUILD-bank:small" or interior.get("ASSET_SHA")!="ba3580e4549cf1cce5ceea826aad62158118271a2dbacf23723da7bc33664aab":return false
	if not is_finite(source_y) or not is_finite(hit.position.y) or absf(hit.position.y-source_y)>.01:return false
	var collider:Variant=hit.get("collider")
	if not collider is StaticBody3D or collider.get_parent()!=interior or collider.get_rid()!=hit.rid:return false
	if collider.get_meta("source_id","")!="REBUILD-bank:small" or collider.get_meta("source_node","")!="Bank_Floor" or collider.get_meta("source_asset_sha256","")!="ba3580e4549cf1cce5ceea826aad62158118271a2dbacf23723da7bc33664aab":return false
	var floor_spec:Dictionary=interior._data.get("nativeFloor",{})
	var floor_size:Variant=floor_spec.get("size")
	if floor_spec.get("sourceNode","")!="Bank_Floor" or not floor_size is Array or floor_size.size()!=3:return false
	for pin:Dictionary in _pins:
		if pin.parent!=collider:continue
		var shape:Variant=pin.node.get_ref()
		if not is_instance_valid(shape) or shape.get_parent()!=collider or shape.shape!=pin.shape or shape.disabled or shape.transform!=pin.local or collider.global_transform!=pin.parent.global_transform:return false
		if not shape.shape is BoxShape3D or not shape.shape.size.is_equal_approx(_v(floor_spec.size)) or not shape.global_transform.is_equal_approx(interior._matrix(floor_spec.transform)):return false
		return true
	return false
func _floor_world(x:float,z:float) -> float:return _floor_preview(x-_origin.x,z-_origin.z)

func _source_segment(from:Vector3,to:Vector3) -> bool:
	if not _current(false) or from.distance_to(to)>5.1:return false
	var fraction:float=interior.door_fraction("public")
	if fraction!=0.0 and fraction!=1.0:diagnostics.reason="door_moving";return false
	var bounds:Array=_data.bounds
	var count:=maxi(1,ceili(Vector2(to.x-from.x,to.z-from.z).length()/.35))
	for i:int in range(count+1):
		var p:=from.lerp(to,float(i)/count)
		if p.x<bounds[0] or p.x>bounds[2] or p.z<bounds[1] or p.z>bounds[3]:diagnostics.reason="outside_entry_scope";return false
		for offset:Vector2 in OFFSETS:
			if not is_finite(_floor_preview(p.x+offset.x,p.z+offset.y)):diagnostics.reason="source_native_corner_floor";return false
		if not host._owned_clear(p,token.source_id):diagnostics.reason="other_actor";return false
	if not _sweep.begin_segment([from.x+_origin.x,from.z+_origin.z],[to.x+_origin.x,to.z+_origin.z],HALF):return false
	for solid:Dictionary in _solids+(_data.openDoors if fraction==1.0 else _data.closedDoors):
		diagnostics.source_sweeps+=1
		if _sweep.blocks_polygon(solid.polygonCR,_floor_world,float(solid.minYM),float(solid.maxYM)):diagnostics.reason="source_square_solid";return false
	return _current(false)

func _native_clear(from:Vector3,to:Vector3) -> bool:
	var y0:=_floor_preview(from.x,from.z);var y1:=_floor_preview(to.x,to.z)
	if not is_finite(y0) or not is_finite(y1):return false
	# Purposeful city errands may cross roads. This separate current dynamic
	# predicate never substitutes for the source static-square/floor proof or
	# the native capsule and pinned-source square proof below.
	if not policy.current_vehicle_clear_segment(token,Vector3(from.x,y0,from.z),Vector3(to.x,y1,to.z)):
		diagnostics.reason="current_vehicle_or_actor_clearance";return false
	if not _current(false):return false
	var space:PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
	_capsule.transform=Transform3D(Basis.IDENTITY,Vector3(to.x,y1+.97,to.z));_capsule.motion=Vector3.ZERO
	if not space.intersect_shape(_capsule,1).is_empty():diagnostics.reason="native_capsule_overlap";return false
	_capsule.transform=Transform3D(Basis.IDENTITY,Vector3(from.x,y0+.97,from.z));_capsule.motion=Vector3(to.x-from.x,y1-y0,to.z-from.z)
	var cast:PackedFloat32Array=space.cast_motion(_capsule)
	if cast.size()!=2 or cast[0]<.99999:diagnostics.reason="native_capsule_sweep";return false
	# Only exact pinned source entry RIDs are replaced by their polygon-square
	# proof. Cars, new objects and every other current collider remain queried.
	var excluded:Array[RID]=[body.get_rid()];excluded.append_array(_entry_rids)
	_square.motion=Vector3.ZERO
	for p:Vector3 in [Vector3(from.x,y0,from.z),Vector3(to.x,y1,to.z)]:
		_square.exclude=excluded;_square.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.975)
		var hits:Array[Dictionary]=space.intersect_shape(_square,64)
		if hits.size()>=64:diagnostics.reason="native_square_query_saturated";return false
		for hit:Dictionary in hits:
			if not _valid_terrain(hit.rid):diagnostics.reason="native_square_obstacle";return false
			excluded.append(hit.rid)
	_square.exclude=excluded;_square.transform=Transform3D(Basis.IDENTITY,Vector3(from.x,y0+.975,from.z));_square.motion=Vector3(to.x-from.x,y1-y0,to.z-from.z)
	cast=space.cast_motion(_square)
	if cast.size()!=2 or cast[0]<.99999:diagnostics.reason="native_square_sweep";return false
	return true

func request_target(key:String) -> Dictionary:
	if _busy or not _current() or not _data.goals.has(key):return {"ok":false,"reason":"current_entry_goal"}
	if _requests.size()>=64:return {"ok":false,"reason":"bounded_entry_requests"}
	if key in ["threshold","inside","service"] and interior.door_fraction("public")!=1.0:return {"ok":false,"reason":"public_door_not_open"}
	var target:Vector3=_handoff if key=="handoff" else _v(_data.goals[key])
	var points:PackedVector3Array=[];var previous:=body.global_position
	var count:=maxi(1,ceili(Vector2(target.x-previous.x,target.z-previous.z).length()/1.0))
	if count>32:return {"ok":false,"reason":"entry_leg_too_long"}
	_floors.clear()
	for i:int in range(1,count+1):
		var point:=body.global_position.lerp(target,float(i)/count)
		if not _source_segment(previous,point) or not _native_clear(previous,point):return {"ok":false,"reason":diagnostics.reason}
		points.append(point);previous=point
	if _active>=0:cancel(_active)
	_next_id+=1;_active=_next_id;_phase=key
	_requests[_active]={"status":"READY","reason":"","points":points,"edge":0,"key":key}
	host._records[token.source_id].request=_active
	return {"ok":true,"request_id":_active,"goal_key":key}

func poll(id:int) -> Dictionary:
	if id<LOCAL_ID_BASE:return base_nav.poll(id)
	if not _requests.has(id):return {"status":"CANCELLED"}
	var record:Dictionary=_requests[id]
	if record.status!="CANCELLED" and not _current():record.status="STALE";record.reason="entry_owner_or_geometry_changed"
	return {"status":record.status,"reason":record.reason,"source_id":token.source_id,"life_generation":token.life_generation,"goal_key":record.key}
func request(owner:RefCounted,walker:CharacterBody3D,target:Vector3,admit:Callable) -> int:
	var id:int=base_nav.request(owner,walker,target,admit)
	if id>=0 and walker==body:
		if _active>=0:_requests[_active].status="CANCELLED"
		_active=-1;_phase="SUPERSEDED"
	return id
func state() -> String:return base_nav.state()

func purposeful_handoff_current() -> bool:
	if not _current() or body.global_position.distance_to(_handoff)>.08:return false
	# The user-authorized errand may return to a road. The outbound native
	# path lease was revoked at bind; do not fabricate an ordinary roam permit.
	# The exact pinned entry corridor, current daily/local leases, base terrain,
	# contact-floor square, native capsule and actual vehicles all remain gates.
	_floors.clear()
	var here:=body.global_position
	return _source_segment(here,here) and _native_clear(here,here) and policy.admit_daily_handoff(token,here) and _current()

func step(id:int,delta:float,speed:float,gravity:float) -> Dictionary:
	if id<LOCAL_ID_BASE:return base_nav.step(id,delta,speed,gravity)
	var result:=poll(id)
	if _busy or not host._busy or host._navigation!=self or result.status!="READY" or id!=_active or delta<=0 or delta>.05 or not is_finite(delta) or not is_finite(speed) or speed<=0 or speed>5:return result
	_busy=true;var start_us:=Time.get_ticks_usec();_floors.clear()
	var request:Dictionary=_requests[id];var before:=body.global_position;var target:Vector3=request.points[request.edge]
	var gap:=Vector2(target.x-before.x,target.z-before.z).length();var floor_y:=_floor_preview(before.x,before.z)
	if gap<=.025 and body.is_on_floor() and is_finite(floor_y) and absf(before.y-floor_y)<.06:
		request.edge+=1
		if request.edge>=request.points.size():request.status="ARRIVED";body.velocity=Vector3.ZERO;_busy=false;return poll(id)
		target=request.points[request.edge];gap=Vector2(target.x-before.x,target.z-before.z).length()
	var velocity:=Vector3(target.x-before.x,0,target.z-before.z).normalized()*minf(speed,gap/delta)
	var after:=before+velocity*delta
	var allowed:=is_finite(floor_y) and absf(before.y-floor_y)<.06 and _source_segment(before,after) and _native_clear(before,after)
	if allowed and _current(false):
		velocity.y=-2.0 if body.is_on_floor() else body.velocity.y-gravity*delta
		body.velocity=velocity;body.move_and_slide();diagnostics.travel_m+=body.global_position.distance_to(before)
		if body.global_position.distance_to(before)<.000001:request.status="BLOCKED";request.reason="native_body_blocked"
	else:request.status="BLOCKED";request.reason=diagnostics.reason;body.velocity=Vector3.ZERO
	var elapsed:=Time.get_ticks_usec()-start_us;diagnostics.steps+=1;diagnostics.step_us_total+=elapsed;diagnostics.step_us_max=maxi(diagnostics.step_us_max,elapsed);_busy=false
	return {"status":request.status,"reason":request.reason}

func cancel(id:int) -> void:
	if not Thread.is_main_thread():return
	if id<LOCAL_ID_BASE:base_nav.cancel(id);return
	if not _requests.has(id):return
	_requests[id].status="CANCELLED"
	if _active==id:
		_active=-1
		if _owns_life() and host._records[token.source_id].request==id:body.velocity=Vector3.ZERO
func dispose() -> void:
	if _disposed or not Thread.is_main_thread():return
	if _active>=0:cancel(_active)
	for resource:Resource in _resources:
		if resource.changed.is_connected(_changed):resource.changed.disconnect(_changed)
	for parent:Node in _parents:
		if is_instance_valid(parent):
			if parent.child_entered_tree.is_connected(_child_changed):parent.child_entered_tree.disconnect(_child_changed)
			if parent.child_exiting_tree.is_connected(_child_changed):parent.child_exiting_tree.disconnect(_child_changed)
	if host!=null and host._records.has(token.get("source_id","")):
		var record:Dictionary=host._records[token.source_id];var claim:Variant=record.get("local_route_owner")
		if _owns_life() and _requests.has(record.request):record.request=-1
		if claim is WeakRef and claim.get_ref()==self:record.erase("local_route_owner")
		if host._navigation==self:host._navigation=base_nav
	_resources.clear();_parents.clear();_disposed=true
