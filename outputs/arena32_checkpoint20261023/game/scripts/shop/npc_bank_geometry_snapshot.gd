extends RefCounted
## Shared capture only. No actor, service arrival or physics admission is cached.
const BUILDING := "REBUILD-bank:small"
const ASSET_SHA := "ba3580e4549cf1cce5ceea826aad62158118271a2dbacf23723da7bc33664aab"
const WORLD_ORIGIN := Vector3(217.3,0,131.2)
static var _cache: Dictionary={}
static var captures: int=0
static var hits: int=0
var scene_ref: WeakRef
var root_ref: WeakRef
var frame:=Transform3D.IDENTITY
var floor_shape: CollisionShape3D
var doors: Array[CollisionShape3D]=[]
var pins: Array[Dictionary]=[]
var _containers: Array[Dictionary]=[]
var _resources: Array[Resource]=[]
var _source_record: Dictionary={}
var _scene_id: int=0
var _users: int=0
var _invalid:=false
var _disposed:=false
var capture_us: int=0

static func acquire(scene: Node3D) -> Dictionary:
	if not Thread.is_main_thread() or not is_instance_valid(scene) or not scene.is_inside_tree(): return {"ok":false,"reason":"bank_scene_lifetime"}
	for key: int in _cache.keys():
		if not is_instance_valid(_cache[key].get_ref()): _cache.erase(key)
	var id:=scene.get_instance_id()
	if _cache.has(id):
		var cached: RefCounted=_cache[id].get_ref()
		if not is_instance_valid(cached) or cached.scene_ref.get_ref()!=scene: return {"ok":false,"reason":"bank_scene_cache_identity"}
		var current: Dictionary=cached.current()
		if not current.get("ok",false): return current
		cached._users+=1;hits+=1
		return {"ok":true,"snapshot":cached,"cache_hit":true}
	if _cache.size()>=8: return {"ok":false,"reason":"bounded_bank_scene_cache"}
	var snapshot:=new()
	var captured: Dictionary=snapshot._capture(scene)
	if not captured.get("ok",false): snapshot._dispose(); return captured
	snapshot._users=1;_cache[id]=weakref(snapshot);captures+=1
	return {"ok":true,"snapshot":snapshot,"cache_hit":false}

func _capture(scene: Node3D) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var building: Dictionary={}
	for candidate: Dictionary in scene.get("_block").buildings:
		if candidate.id==BUILDING:
			if not building.is_empty(): return _fail("duplicate_original_bank_record")
			building=candidate
	if building.is_empty(): return _fail("original_bank_native_site_missing")
	if building.get("binding",{}).get("sha256")!=ASSET_SHA or building.get("assetId")!="bank_small_shell_v1": return _fail("bank_source_asset")
	var transform: Dictionary=building.get("transform",{})
	var position: Array=transform.get("positionM",[])
	if position.size()!=3 or Vector3(position[0],position[1],position[2]).distance_to(WORLD_ORIGIN)>.0001 or float(transform.get("yawDegrees",0))!=90.0 or float(transform.get("uniformScale",0))!=1.0: return _fail("bank_source_placement")
	var native_root: Node3D
	for node: Node in scene.get_children():
		if node is Node3D and not node is CollisionObject3D and node.get_meta("source_id","")==BUILDING:
			if native_root!=null: return _fail("ambiguous_bank_native_root")
			native_root=node
	if not is_instance_valid(native_root): return _fail("bank_native_root")
	var origin: Vector3=scene.get("_origin")
	frame=Transform3D(Basis(Vector3.UP,PI/2.0),WORLD_ORIGIN-origin)
	if not native_root.global_transform.is_equal_approx(frame): return _fail("bank_native_frame")
	var found: Dictionary={}
	var containers: Dictionary={}
	for node: Node in scene.find_children("*","CollisionShape3D",true,false):
		var shape:=node as CollisionShape3D
		var body:=shape.get_parent() as CollisionObject3D
		if not is_instance_valid(body) or body.get_meta("source_id","")!=BUILDING: continue
		if shape.shape==null: return _fail("bank_native_shape")
		var name: String=body.get_meta("source_node","")
		if name in ["Bank_Floor","Bank_Door_L","Bank_Door_R"]:
			if found.has(name) or not shape.shape is BoxShape3D or shape.disabled or body.collision_layer!=1: return _fail("bank_native_shape")
			found[name]=shape
		pins.append({"node":weakref(shape),"parent":weakref(body),"shape":shape.shape,"layer":body.collision_layer,"mask":body.collision_mask,"disabled":shape.disabled,"frame":shape.global_transform,"door":name in ["Bank_Door_L","Bank_Door_R"],"children":body.get_child_count(),"source_node":name,"asset":body.get_meta("source_asset_sha256","")})
		if not shape.shape in _resources: _resources.append(shape.shape); shape.shape.changed.connect(_changed)
		var container: Node=body.get_parent()
		# Avoid pinning unrelated scene children/actors. The actual bank geometry
		# container's count catches insertion/removal of its authored bodies.
		if container!=scene and not containers.has(container.get_instance_id()):
			containers[container.get_instance_id()]=true;_containers.append({"node":weakref(container),"parent":weakref(container.get_parent()),"children":container.get_child_count()})
	for name: String in ["Bank_Floor","Bank_Door_L","Bank_Door_R"]:
		if not found.has(name): return _fail("bank_physical_floor_and_doors_missing")
	floor_shape=found.Bank_Floor;doors.assign([found.Bank_Door_L,found.Bank_Door_R])
	if not floor_shape.shape.size.is_equal_approx(Vector3(18.6,.2,14.6)) or not floor_shape.global_transform.is_equal_approx(frame): return _fail("bank_original_floor")
	for door: CollisionShape3D in doors:
		if not door.shape.size.is_equal_approx(Vector3(1.4,3,.13)): return _fail("bank_original_leaf")
	_source_record=building.duplicate(true);scene_ref=weakref(scene);root_ref=weakref(native_root);_scene_id=scene.get_instance_id()
	capture_us=Time.get_ticks_usec()-started
	return {"ok":true,"shapes":pins.size(),"connections":_resources.size()}

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"building_id":BUILDING}
func _changed() -> void: _invalid=true

func current() -> Dictionary:
	if _invalid or _disposed or scene_ref==null or root_ref==null: return _fail("bank_geometry_changed")
	var scene: Node3D=scene_ref.get_ref();var native_root: Node3D=root_ref.get_ref()
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not is_instance_valid(native_root) or native_root.get_parent()!=scene or native_root.get_meta("source_id","")!=BUILDING or not native_root.global_transform.is_equal_approx(frame): return _fail("bank_frame_changed")
	var source_current:=false
	var source_count:=0
	for record: Dictionary in scene.get("_block").buildings:
		if record.id==BUILDING: source_current=record==_source_record;source_count+=1
	if not source_current or source_count!=1: return _fail("bank_source_record_changed")
	for container: Dictionary in _containers:
		var node: Node=container.node.get_ref()
		if not is_instance_valid(node) or node.get_parent()!=container.parent.get_ref() or node.get_child_count()!=int(container.children): return _fail("bank_geometry_membership_changed")
	for pin: Dictionary in pins:
		var shape: CollisionShape3D=pin.node.get_ref();var body: CollisionObject3D=pin.parent.get_ref()
		if not is_instance_valid(shape) or not is_instance_valid(body) or shape.get_parent()!=body or shape.shape!=pin.shape or shape.disabled!=pin.disabled or body.collision_layer!=pin.layer or body.collision_mask!=pin.mask or body.get_child_count()!=int(pin.children): return _fail("bank_geometry_changed")
		if body.get_meta("source_id","")!=BUILDING or body.get_meta("source_node","")!=pin.source_node or body.get_meta("source_asset_sha256","")!=pin.asset: return _fail("bank_source_identity_changed")
		if not pin.door and not shape.global_transform.is_equal_approx(pin.frame): return _fail("bank_static_frame_changed")
	if not is_instance_valid(floor_shape) or not floor_shape.global_transform.is_equal_approx(frame): return _fail("bank_floor_moved")
	return {"ok":true,"shapes":pins.size()}

func release() -> void:
	if _disposed:return
	_users=maxi(0,_users-1)
	if _users==0:_dispose()

func _dispose() -> void:
	if _disposed:return
	_disposed=true
	for resource: Resource in _resources:
		if is_instance_valid(resource) and resource.changed.is_connected(_changed):resource.changed.disconnect(_changed)
	_resources.clear();pins.clear();_containers.clear();doors.clear();floor_shape=null
	if _cache.has(_scene_id) and _cache[_scene_id].get_ref()==self:_cache.erase(_scene_id)
	scene_ref=null;root_ref=null
