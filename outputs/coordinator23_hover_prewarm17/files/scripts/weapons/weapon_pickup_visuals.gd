extends RefCounted
## Static original weapon presentation and explicit-action ray picking only.
## Inventory/cargo remain authoritative. Never scans in _process/_physics_process.
const Catalog=preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
const Sizes=preload("res://scripts/weapons/weapon_cargo_sizes.gd")
const GROUND_SCALE:=.368 # ground_weapons.mjs default, independently of hero scale.
const TRUNK_SCALE:=Sizes.TRUNK_SCALE
class PlacementToken extends RefCounted:
	pass
var _catalog:RefCounted
var _world:WeakRef
var _ground_layer:Node3D
var _validator:Callable
var _trunks:Dictionary={}
var _ground:Dictionary={}
var _falling:Dictionary={}
var _pending:Dictionary={}
var _geometry:Dictionary={}
var _native_bounds:Dictionary={}
var _aim_samples:Dictionary={}
var _hover:Dictionary={}
var _hover_parts:Array=[]
var _hover_material:StandardMaterial3D
var _ground_scale:=GROUND_SCALE
var _trunk_scale:=TRUNK_SCALE
var _max_items:=512
var _ready:=false
var _busy:=false
var _interrupted:=false
var _close_requested:=false
var _stats:Dictionary={"geometry_builds":0,"geometry_queries":0,"aabb_tests":0,"fall_updates":0}

static func _error(reason:String)->Dictionary:return {"ok":false,"reason":reason}
static func _ok(value:Variant)->bool:return value is Dictionary and value.get("ok") is bool and value.ok
static func _number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _node_live(node:Variant)->bool:
	if not is_instance_valid(node) or not node is Node or not node.is_inside_tree():return false
	while node!=null:
		if node.is_queued_for_deletion():return false
		node=node.get_parent()
	return true
static func _box_valid(box:AABB)->bool:return box.position.is_finite() and box.size.is_finite() and box.size.x>0 and box.size.y>0 and box.size.z>0
static func _same_box(a:AABB,b:AABB)->bool:return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)
static func _item(item:Variant)->bool:
	return item is Dictionary and item.get("uid") is String and not item.uid.is_empty() and item.get("weaponId") is String and item.weaponId!="none" and Catalog.IDS.has(item.weaponId) and item.get("fireState") is Dictionary

func configure(catalog:RefCounted,world_root:Node3D,ground_validator:Callable,options:Dictionary={})->Dictionary:
	if not Thread.is_main_thread() or _ready or _busy:return _error("state")
	if catalog==null or catalog.get_script()!=Catalog or not _node_live(world_root) or not ground_validator.is_valid() or ground_validator.get_argument_count()!=1:return _error("ports")
	if not Sizes.catalog_matches(catalog):return _error("cargo_size_catalog")
	var gs:Variant=options.get("ground_scale",GROUND_SCALE);var ts:Variant=options.get("trunk_scale",TRUNK_SCALE);var cap:Variant=options.get("max_items",512)
	if not _number(gs) or gs<=0 or gs>1 or not _number(ts) or ts<=0 or ts>1 or not cap is int or cap<1 or cap>4096:return _error("options")
	var bounds:Dictionary={}
	for id:String in Catalog.IDS:
		if id=="none":continue
		var record:Dictionary=catalog.get_entry(id);var value:Variant=record.get("profile",{}).get("bounds_native")
		if not value is Dictionary or not value.get("min") is Array or not value.get("max") is Array or value.min.size()!=3 or value.max.size()!=3:return _error("catalog_bounds")
		for axis in 3:
			if not _number(value.min[axis]) or not _number(value.max[axis]):return _error("catalog_bounds")
		var low:=Vector3(value.min[0],value.min[1],value.min[2]);var high:=Vector3(value.max[0],value.max[1],value.max[2]);var box:=AABB(low,high-low)
		if not _box_valid(box):return _error("catalog_bounds")
		bounds[id]=box
	_catalog=catalog;_world=weakref(world_root);_validator=ground_validator;_ground_scale=gs;_trunk_scale=ts;_max_items=cap;_native_bounds=bounds
	# Shared ordinary material, no new model nodes or custom first-hit shader.
	_hover_material=StandardMaterial3D.new()
	_hover_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_material.albedo_color=Color(1.0,.72,.16,.48)
	_hover_material.no_depth_test=false
	# Exercise the exact first overlay binding during startup, before interaction.
	# No mesh or tree attachment: no pixels, collision, retained node or idle pass.
	var warm_start:=Time.get_ticks_usec()
	var warm_instance:=MeshInstance3D.new()
	warm_instance.material_overlay=_hover_material
	warm_instance.material_overlay=null
	warm_instance.free()
	_stats.hover_material_prepare_us=Time.get_ticks_usec()-warm_start
	_busy=true;_interrupted=false;_ready=true
	_ground_layer=Node3D.new();_ground_layer.name="WeaponGroundItems";_ground_layer.top_level=true
	world_root.add_child(_ground_layer)
	if _node_live(_ground_layer):_ground_layer.global_transform=Transform3D.IDENTITY
	if not _live():_busy=false;dispose();return _error("world_changed")
	_ground_layer.global_transform=Transform3D.IDENTITY;_busy=false
	return {"ok":true,"ground_scale":_ground_scale,"trunk_scale":_trunk_scale}
func _live()->bool:return _ready and not _interrupted and _world!=null and _node_live(_world.get_ref()) and _node_live(_ground_layer) and _ground_layer.global_transform==Transform3D.IDENTITY and _validator.is_valid()
func _start(allow_pending:bool=false)->bool:
	if not Thread.is_main_thread():return false
	if _busy:_interrupted=true;return false
	_interrupted=false
	if not _live() or _close_requested or (not allow_pending and not _pending.is_empty()):return false
	_busy=true;_interrupted=false;return true
func _finish(result:Dictionary)->Dictionary:
	_busy=false
	return result
func model_aabb(weapon_id:String,scope:String="trunk")->AABB:
	if not _ready or not _native_bounds.has(weapon_id) or scope not in ["trunk","ground"]:return AABB()
	if scope=="trunk":return Transform3D(Basis.from_scale(Vector3.ONE*_trunk_scale),Vector3.ZERO)*_native_bounds[weapon_id]
	var box:AABB=Transform3D(Basis(Vector3.BACK,PI/2)*Basis.from_scale(Vector3.ONE*_ground_scale),Vector3.ZERO)*_native_bounds[weapon_id]
	return AABB(Vector3(-box.size.x/2,.009,-box.size.z/2),box.size)
func bind_trunk(vehicle_id:String,generation:int,cargo_root:Node3D)->Dictionary:
	if not _start():return _error("state")
	if vehicle_id.is_empty() or generation<1 or not _node_live(cargo_root) or not (_world.get_ref()==cargo_root or _world.get_ref().is_ancestor_of(cargo_root)):return _finish(_error("binding"))
	if _trunks.has(vehicle_id):return _finish(_error("already_bound"))
	var layer:=Node3D.new();layer.name="WeaponTrunkItems";cargo_root.add_child(layer)
	if not _live() or not _node_live(cargo_root) or not _node_live(layer):
		if is_instance_valid(layer):layer.free()
		return _finish(_error("binding_changed"))
	_trunks[vehicle_id]={"generation":generation,"root":weakref(cargo_root),"layer":layer,"items":{}}
	return _finish({"ok":true})
func unbind_trunk(vehicle_id:String,generation:int)->Dictionary:
	if not _start():return _error("state")
	var binding:=_binding(vehicle_id,generation)
	if binding.is_empty():return _finish(_error("binding"))
	if _hover.get("vehicle_id")==vehicle_id:clear_hover()
	if is_instance_valid(binding.layer):binding.layer.free()
	_trunks.erase(vehicle_id)
	return _finish({"ok":true})
func _binding(vehicle_id:String,generation:int)->Dictionary:
	var binding:Dictionary=_trunks.get(vehicle_id,{})
	if binding.is_empty() or binding.generation!=generation or not _node_live(binding.root.get_ref()) or not _node_live(binding.layer) or binding.layer.get_parent()!=binding.root.get_ref() or binding.layer.transform!=Transform3D.IDENTITY:return {}
	return binding
func _uid_exists(uid:String)->bool:
	for row:Dictionary in _ground.values():
		if row.uid==uid:return true
	for binding:Dictionary in _trunks.values():
		if binding.items.has(uid):return true
	return false
func _count()->int:
	var count:=_ground.size()
	for binding:Dictionary in _trunks.values():count+=binding.items.size()
	return count
static func _relative(root:Node3D,node:Node3D)->Transform3D:
	var value:=Transform3D.IDENTITY;var cursor:Node=node
	while cursor!=root and cursor!=null:
		if cursor is Node3D:value=cursor.transform*value
		cursor=cursor.get_parent()
	return value
static func _part_visible(root:Node3D,node:Node3D)->bool:
	var cursor:Node=node
	while cursor!=root and cursor!=null:
		if cursor is Node3D and not cursor.visible:return false
		cursor=cursor.get_parent()
	return cursor==root
func _make_row(uid:String,weapon_id:String,parent:Node3D,transform:Transform3D)->Dictionary:
	var made:Dictionary=_catalog.instantiate_weapon(weapon_id)
	if not _ok(made):return {}
	var model:Node3D=made.visual
	model.visible=false;model.transform=transform;model.set_meta("item_uid",uid);model.set_meta("weapon_id",weapon_id)
	var parts:Array=[]
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh!=null:parts.append({"node":weakref(mesh),"mesh":mesh.mesh,"transform":_relative(model,mesh),"visible":_part_visible(model,mesh)})
	if parts.is_empty() or not _same_box(model.local_bounds(),_native_bounds[weapon_id]):model.free();return {}
	# Attachment and all node initialization happen BEFORE paired ownership commits.
	parent.add_child(model)
	if not _live() or not _node_live(model) or model.get_parent()!=parent:
		if is_instance_valid(model):model.free()
		return {}
	var row: Dictionary={"uid":uid,"weapon_id":weapon_id,"visual":model,"parts":parts,"bounds":_native_bounds[weapon_id],"transform":transform,"parent":weakref(parent)}
	# Build immutable picking geometry during placement preparation, not hover.
	if _triangle_mesh(row)==null: model.free(); return {}
	return row
func _free_rows(rows:Array)->void:
	for row:Dictionary in rows:
		if _hover.get("item_uid")==row.uid:clear_hover()
		if is_instance_valid(row.get("visual")):row.visual.free()
func _row_live(row:Dictionary)->bool:
	return _node_live(row.visual) and _node_live(row.parent.get_ref()) and row.visual.get_parent()==row.parent.get_ref() and row.visual.transform==row.transform
func _model_current(row:Dictionary)->bool:
	if not _row_live(row):return false
	for part:Dictionary in row.parts:
		var mesh:Variant=part.node.get_ref()
		if not _node_live(mesh) or not row.visual.is_ancestor_of(mesh) or mesh.mesh!=part.mesh or _relative(row.visual,mesh)!=part.transform or _part_visible(row.visual,mesh)!=part.visible:return false
	return true
func _entry_row(entry:Variant,binding:Dictionary)->Dictionary:
	if not entry is Dictionary or not _item(entry.get("item")) or not entry.get("model_aabb") is AABB or not entry.get("item_bounds_local_m") is AABB or not entry.get("model_origin_local_m") is Vector3:return {}
	var expected:=model_aabb(entry.item.weaponId)
	if not _same_box(expected,entry.model_aabb) or not entry.model_origin_local_m.is_finite() or not _same_box(AABB(expected.position+entry.model_origin_local_m,expected.size),entry.item_bounds_local_m):return {}
	var row:=_make_row(entry.item.uid,entry.item.weaponId,binding.layer,Transform3D(Basis.from_scale(Vector3.ONE*_trunk_scale),entry.model_origin_local_m))
	if not row.is_empty():row.entry=entry.duplicate(true);row.local_box=entry.item_bounds_local_m
	return row
static func _overlaps(box:AABB,rows:Array)->bool:
	for row:Dictionary in rows:
		if box.intersects(row.local_box):return true
	return false
func _ground_row(item:Dictionary,placement:Variant)->Dictionary:
	if not _item(item) or not placement is Dictionary or not placement.get("position") is Dictionary or not _number(placement.get("yaw")):return {}
	for axis:String in ["x","y","z"]:
		if not _number(placement.position.get(axis)):return {}
	var p:Dictionary=placement.position;var position:=Vector3(p.x,p.y,p.z)
	var transform:=Transform3D(Basis(Vector3.UP,float(placement.yaw))*Basis(Vector3.BACK,PI/2)*Basis.from_scale(Vector3.ONE*_ground_scale),Vector3.ZERO)
	var row:=_make_row(item.uid,item.weaponId,_ground_layer,transform)
	if not row.is_empty():
		# Exact rest vertices, including asymmetric barrels. Never the pickup point
		# interpreted as model origin, nor a conservatively rotated aggregate box.
		var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
		for part:Dictionary in row.parts:
			var vertices:PackedVector3Array=part.mesh.get_faces()
			var part_transform:Transform3D=transform*part.transform
			for vertex:Vector3 in vertices:
				var point:Vector3=part_transform*vertex;low=low.min(point);high=high.max(point)
		if not low.is_finite() or not high.is_finite():_free_rows([row]);return {}
		var box:=AABB(low,high-low);var center:=box.get_center()
		transform.origin=Vector3(position.x-center.x,position.y-box.position.y+.009,position.z-center.z)
		row.item=item.duplicate(true);row.placement={"position":p.duplicate(true),"yaw":placement.yaw}
		row.world_box=AABB(box.position+transform.origin,box.size);row.rest_transform=transform;row.transform=transform;row.visual.transform=transform;row.age=0.0
	return row
func _ground_valid(rows:Array,ignored_drop_uids:Array=[])->bool:
	var occupied:Array=[]
	for uid:String in _ground:
		if not ignored_drop_uids.has(uid):
			if not _row_live(_ground[uid]):return false
			occupied.append(_ground[uid].world_box)
	var candidates:Array=[]
	for row:Dictionary in rows:
		var box:AABB=row.world_box
		candidates.append({"item_uid":row.uid,"weapon_id":row.weapon_id,"position":row.placement.position.duplicate(),"yaw":row.placement.yaw,"world_aabb":box,"floor_samples":[Vector3(box.position.x,row.placement.position.y,box.position.z),Vector3(box.end.x,row.placement.position.y,box.position.z),Vector3(box.position.x,row.placement.position.y,box.end.z),Vector3(box.end.x,row.placement.position.y,box.end.z)]})
	var result:Variant=_validator.call({"phase":"ground_placement","items":candidates})
	if not _live() or not _ok(result):return false
	var floors:Variant=result.get("floors")
	if floors!=null and (not floors is Array or floors.size()!=rows.size()):return false
	var offsets:Array=[]
	for index in rows.size():
		var row:Dictionary=rows[index]
		if not _model_current(row):return false
		var offset:=0.0;var proposed:AABB=row.world_box
		if floors!=null:
			if not _number(floors[index]) or floors[index]<row.placement.position.y:return false
			offset=float(floors[index])+.009-row.world_box.position.y
			proposed.position.y+=offset
		for box:AABB in occupied:
			if proposed.intersects(box):return false
		occupied.append(proposed);offsets.append(offset)
	for index in rows.size():
		var row:Dictionary=rows[index];var offset:float=offsets[index]
		row.world_box.position.y+=offset;row.rest_transform.origin.y+=offset;row.transform.origin.y+=offset;row.visual.transform=row.transform
	return true
static func _start_fall(row:Dictionary)->void:
	row.age=0.0;row.transform=row.rest_transform;row.transform.origin.y+=.55;row.visual.transform=row.transform

func prepare_placement(request:Dictionary)->Dictionary:
	if not _start():return _error("state")
	if not request.get("vehicle_id") is String or not request.get("generation") is int:return _finish(_error("binding"))
	var binding:=_binding(request.vehicle_id,request.generation)
	if binding.is_empty():return _finish(_error("binding"))
	var action:Variant=request.get("action");var rows:Array=[];var removed:Array=[]
	if action=="store":
		if not request.get("entry") is Dictionary or not _item(request.entry.get("item")) or _uid_exists(request.entry.item.uid) or _count()>=_max_items:return _finish(_error("item_or_capacity"))
		var row:=_entry_row(request.entry,binding)
		if row.is_empty():return _finish(_error("model_bounds"))
		rows.append(row)
		if _overlaps(row.local_box,binding.items.values()):_free_rows(rows);return _finish(_error("overlap"))
	elif action=="take":
		if not request.get("entry") is Dictionary or not _item(request.entry.get("item")) or not binding.items.has(request.entry.item.uid):return _finish(_error("missing_visual"))
		var row:Dictionary=binding.items[request.entry.item.uid]
		if row.entry!=request.entry or not _model_current(row):return _finish(_error("changed_visual"))
		removed.append(row)
	elif action=="destroy":
		if not request.get("entries") is Array or not request.get("placements") is Array or request.entries.size()!=request.placements.size() or not request.get("receipt") is String or request.receipt.is_empty() or request.entries.size()!=binding.items.size():return _finish(_error("batch"))
		var unique:Dictionary={}
		for index in request.entries.size():
			var entry:Variant=request.entries[index]
			if not entry is Dictionary or not _item(entry.get("item")) or unique.has(entry.item.uid) or not binding.items.has(entry.item.uid) or binding.items[entry.item.uid].entry!=entry:_free_rows(rows);return _finish(_error("batch_item"))
			unique[entry.item.uid]=true;removed.append(binding.items[entry.item.uid])
			var row:=_ground_row(entry.item,request.placements[index])
			if row.is_empty():_free_rows(rows);return _finish(_error("ground_model"))
			rows.append(row)
		if not _ground_valid(rows):_free_rows(rows);return _finish(_error("ground_placement"))
		for row:Dictionary in rows:_start_fall(row)
	else:return _finish(_error("action"))
	if not _live() or _binding(request.vehicle_id,request.generation).is_empty():_free_rows(rows);return _finish(_error("lifetime"))
	for row:Dictionary in rows+removed:
		if not _model_current(row):_free_rows(rows);return _finish(_error("model_changed"))
	var token:=PlacementToken.new()
	_pending={"token":token,"request":request.duplicate(true),"rows":rows,"removed":removed}
	return _finish({"ok":true,"token":token})
func cancel_placement(token:Variant)->Dictionary:
	if not Thread.is_main_thread() or _busy or _pending.is_empty() or token!=_pending.token:return _error("token")
	_free_rows(_pending.rows);_pending={}
	if _close_requested:dispose()
	return {"ok":true}
func prepare_ground_drop(item:Dictionary,placement:Dictionary)->Dictionary:
	if not _start():return _error("state")
	if not _item(item) or _uid_exists(item.uid) or _count()>=_max_items:return _finish(_error("item_or_capacity"))
	var row:=_ground_row(item,placement)
	if row.is_empty():return _finish(_error("ground_model"))
	if not _ground_valid([row]):_free_rows([row]);return _finish(_error("ground_placement"))
	_start_fall(row)
	var token:=PlacementToken.new()
	_pending={"token":token,"request":{"action":"ground_drop"},"rows":[row],"removed":[]}
	return _finish({"ok":true,"token":token})
func activate_ground_drop(token:Variant,actual_drop:Dictionary,item_uid:String)->Dictionary:
	if not Thread.is_main_thread() or _busy or _pending.is_empty() or token!=_pending.token or _pending.request.action!="ground_drop":return _error("activation")
	var row:Dictionary=_pending.rows[0]
	if not _live() or not _row_live(row):return _error("lifetime")
	if item_uid!=row.uid or not actual_drop.get("uid") is String or actual_drop.uid.is_empty() or _ground.has(actual_drop.uid) or actual_drop.get("weaponId")!=row.weapon_id or actual_drop.get("position")!=row.placement.position or actual_drop.get("yaw")!=row.placement.yaw:return _error("ground_receipt")
	# Inventory owns stowing/ammo. No resources, callbacks, attachments or physics
	# queries after its drop commit; prepared node is already in the scene.
	_busy=true;row.drop_uid=actual_drop.uid;_ground[row.drop_uid]=row;_falling[row.drop_uid]=row
	row.visual.set_meta("drop_uid",row.drop_uid);row.visual.visible=true
	_pending={};_busy=false
	if _close_requested:dispose()
	return {"ok":true}
func activate_placement(token:Variant,bridge_result:Dictionary)->Dictionary:
	if not Thread.is_main_thread() or _busy or _pending.is_empty() or token!=_pending.token or not _ok(bridge_result) or bridge_result.get("placement_token")!=token or bridge_result.get("action")!=_pending.request.action:return _error("activation")
	if _pending.request.action=="ground_drop":return _error("activation_kind")
	var request:Dictionary=_pending.request;var binding:=_binding(request.vehicle_id,request.generation)
	if not _live() or binding.is_empty():return _error("lifetime")
	for row:Dictionary in _pending.rows+_pending.removed:
		if not _row_live(row):return _error("prepared_node_changed")
	if request.action=="store":
		if bridge_result.get("cargo",{}).get("entry")!=request.entry or bridge_result.get("inventory",{}).get("item",{}).get("uid")!=request.entry.item.uid:return _error("receipt")
	elif request.action=="take":
		if bridge_result.get("cargo",{}).get("entry")!=request.entry or bridge_result.get("inventory",{}).get("item",{}).get("uid")!=request.entry.item.uid:return _error("receipt")
	else:
		var drops:Variant=bridge_result.get("inventory",{}).get("dropped")
		if not drops is Array or drops.size()!=_pending.rows.size() or bridge_result.get("cargo",{}).get("receipt",{}).get("items")!=request.entries:return _error("receipt")
		var unique_drops:Dictionary={}
		for index in drops.size():
			var drop:Variant=drops[index];var row:Dictionary=_pending.rows[index]
			if not drop is Dictionary or not drop.get("uid") is String or drop.uid.is_empty() or unique_drops.has(drop.uid) or _ground.has(drop.uid) or drop.get("weaponId")!=row.weapon_id or drop.get("position")!=row.placement.position or drop.get("yaw")!=row.placement.yaw or drop.get("fireState")!=row.item.fireState:return _error("ground_receipt")
			unique_drops[drop.uid]=true
		for index in drops.size():_pending.rows[index].drop_uid=drops[index].uid
	# All parenting/loading/physics checks already happened during preparation.
	_busy=true
	for row:Dictionary in _pending.removed:
		if _hover.get("item_uid")==row.uid:clear_hover()
		binding.items.erase(row.uid);row.visual.visible=false;row.visual.queue_free()
	for row:Dictionary in _pending.rows:
		if request.action=="store":binding.items[row.uid]=row
		else:_ground[row.drop_uid]=row;_falling[row.drop_uid]=row;row.visual.set_meta("drop_uid",row.drop_uid)
		row.visual.visible=true
	_pending={};_busy=false
	if _close_requested:dispose()
	return {"ok":true}

func sync_trunk(vehicle_id:String,generation:int,entries:Array)->Dictionary:
	if not _start():return _error("state")
	var binding:=_binding(vehicle_id,generation)
	if binding.is_empty() or _count()-binding.items.size()+entries.size()>_max_items:return _finish(_error("binding_or_capacity"))
	var unchanged:bool=entries.size()==binding.items.size();var seen:Dictionary={}
	for entry:Variant in entries:
		if not entry is Dictionary or not _item(entry.get("item")) or seen.has(entry.item.uid):unchanged=false;break
		seen[entry.item.uid]=true
		var old:Dictionary=binding.items.get(entry.item.uid,{})
		if old.is_empty() or old.entry!=entry or not _model_current(old):unchanged=false;break
	if unchanged:return _finish({"ok":true,"count":entries.size(),"created":0})
	var rows:Array=[];var unique:Dictionary={}
	for entry:Variant in entries:
		if not entry is Dictionary or not _item(entry.get("item")) or unique.has(entry.item.uid) or (_uid_exists(entry.item.uid) and not binding.items.has(entry.item.uid)):_free_rows(rows);return _finish(_error("item"))
		var row:=_entry_row(entry,binding)
		if row.is_empty():_free_rows(rows);return _finish(_error("model"))
		if _overlaps(row.local_box,rows):rows.append(row);_free_rows(rows);return _finish(_error("overlap"))
		unique[row.uid]=true;rows.append(row)
	if not _live():_free_rows(rows);return _finish(_error("lifetime"))
	_free_rows(binding.items.values());binding.items={}
	for row:Dictionary in rows:binding.items[row.uid]=row;row.visual.visible=true
	return _finish({"ok":true,"count":rows.size(),"created":rows.size()})
func sync_ground(drops:Array,item_identity_by_drop_uid:Dictionary)->Dictionary:
	if not _start():return _error("state")
	if _count()-_ground.size()+drops.size()>_max_items:return _finish(_error("capacity"))
	var next:Dictionary={};var created:Array=[];var unique:Dictionary={}
	for drop:Variant in drops:
		if not drop is Dictionary or not drop.get("uid") is String or drop.uid.is_empty() or not item_identity_by_drop_uid.get(drop.uid) is String:_free_rows(created);return _finish(_error("drop_identity"))
		var uid:String=item_identity_by_drop_uid[drop.uid]
		if uid.is_empty() or next.has(drop.uid) or unique.has(uid):_free_rows(created);return _finish(_error("duplicate_uid"))
		var item:Dictionary={"uid":uid,"weaponId":drop.get("weaponId"),"fireState":drop.get("fireState")}
		var placement:Dictionary={"position":drop.get("position"),"yaw":drop.get("yaw")}
		if not _item(item):_free_rows(created);return _finish(_error("item"))
		for binding:Dictionary in _trunks.values():
			if binding.items.has(uid):_free_rows(created);return _finish(_error("duplicate_uid"))
		var row:Dictionary=_ground.get(drop.uid,{})
		if not row.is_empty() and row.uid==uid and row.weapon_id==item.weaponId and row.placement==placement and _model_current(row):next[drop.uid]=row
		else:
			row=_ground_row(item,placement)
			if row.is_empty():_free_rows(created);return _finish(_error("ground_model"))
			row.drop_uid=drop.uid;created.append(row);next[drop.uid]=row
		unique[uid]=true
	if not created.is_empty() and not _ground_valid(next.values(),_ground.keys()):_free_rows(created);return _finish(_error("ground_placement"))
	if not _live():_free_rows(created);return _finish(_error("lifetime"))
	for uid:String in _ground:
		if not next.has(uid) or next[uid]!=_ground[uid]:_falling.erase(uid);_free_rows([_ground[uid]])
	_ground=next
	for row:Dictionary in created:_start_fall(row);_falling[row.drop_uid]=row;row.visual.set_meta("drop_uid",row.drop_uid);row.visual.visible=true
	return _finish({"ok":true,"count":_ground.size(),"created":created.size()})

func update(dt:float)->Dictionary:
	# Source fall only: bounded .4 seconds, then zero traversal of settled items.
	if not is_finite(dt):return _error("delta")
	if not _hover.is_empty():
		var selected:Variant=_hover.node.get_ref()
		if not _node_live(selected) or not selected.is_visible_in_tree():clear_hover()
	if _falling.is_empty():return {"ok":true,"updated":0}
	if not _start():return _error("state")
	var updated:=0
	for uid:String in _falling.keys():
		var row:Dictionary=_falling[uid]
		if not _row_live(row):_falling.erase(uid);continue
		row.age+=clampf(dt,0,.1)
		var t:=minf(1.0,row.age/.4)
		row.transform=row.rest_transform;row.transform.origin.y+=.55*(1-t*t);row.visual.transform=row.transform
		updated+=1;_stats.fall_updates+=1
		if row.age>=.4:_falling.erase(uid)
	return _finish({"ok":true,"updated":updated})

func _triangle_mesh(row:Dictionary)->TriangleMesh:
	if _geometry.has(row.weapon_id):return _geometry[row.weapon_id]
	var faces:=PackedVector3Array()
	for part:Dictionary in row.parts:
		if not part.visible:continue
		var local:PackedVector3Array=part.mesh.get_faces()
		if local.size()%3!=0:return null
		for vertex:Vector3 in local:faces.append(part.transform*vertex)
	if faces.is_empty():return null
	var mesh:=TriangleMesh.new()
	if not mesh.create_from_faces(faces):return null
	# At most 32 actual triangle centroids per weapon, prepared once with BVH.
	# Hover never reads mesh arrays or constructs geometry.
	var samples:=PackedVector3Array()
	var triangles:=faces.size()/3
	var count:=mini(32,triangles)
	for index:int in count:
		var first:=int(float(index)*float(triangles)/float(count))*3
		samples.append((faces[first]+faces[first+1]+faces[first+2])/3.0)
	_aim_samples[row.weapon_id]=samples
	_geometry[row.weapon_id]=mesh;_stats.geometry_builds+=1
	return mesh
func pick(origin:Vector3,direction:Vector3,max_distance:float,options:Dictionary={})->Dictionary:
	# No focus or geometry work when root releases player control, or closes lid.
	if options.get("enabled")!=true:return {"ok":true,"hit":false}
	var scope:Variant=options.get("scope")
	if scope=="trunk" and options.get("trunk_open")!=true:return {"ok":true,"hit":false}
	if not _start(true):return _error("state")
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared()<1e-12 or not is_finite(max_distance) or max_distance<=0 or max_distance>10000:return _finish(_error("ray"))
	var clipped:=max_distance
	if options.has("blocker_distance"):
		if not _number(options.blocker_distance) or options.blocker_distance<0:return _finish(_error("blocker"))
		clipped=minf(clipped,float(options.blocker_distance))
	var candidates:Array=[]
	if scope=="ground":candidates=_ground.values()
	elif scope=="trunk":
		if not options.get("vehicle_id") is String or not options.get("generation") is int:return _finish(_error("binding"))
		var binding:=_binding(options.vehicle_id,options.generation)
		if binding.is_empty():return _finish(_error("binding"))
		candidates=binding.items.values()
	else:return _finish(_error("scope"))
	var end:=origin+direction.normalized()*clipped;var nearest:=INF;var best:Dictionary={}
	for row:Dictionary in candidates:
		if not _row_live(row) or not row.visual.is_visible_in_tree():continue
		var transform:Transform3D=row.visual.global_transform
		if not transform.is_finite() or absf(transform.basis.determinant())<1e-12:continue
		var inverse:=transform.affine_inverse();var begin_local:=inverse*origin;var end_local:=inverse*end
		_stats.aabb_tests+=1
		if not row.bounds.intersects_segment(begin_local,end_local):continue
		if not _model_current(row):return _finish(_error("model_changed"))
		var mesh:=_triangle_mesh(row)
		if mesh==null:return _finish(_error("geometry"))
		_stats.geometry_queries+=1
		var hit:Dictionary=mesh.intersect_segment(begin_local,end_local)
		if hit.is_empty():continue
		var point:Vector3=transform*hit.position;var distance:=origin.distance_to(point)
		if distance>=nearest:continue
		nearest=distance
		best={"ok":true,"hit":true,"item_uid":row.uid,"weaponId":row.weapon_id,"scope":scope,"distance":distance,"point":point,"normal":(transform.basis.inverse().transposed()*hit.normal).normalized(),"drop_uid":row.get("drop_uid","")}
		if scope=="trunk":best.vehicle_id=options.vehicle_id;best.generation=options.generation
	return _finish(best if not best.is_empty() else {"ok":true,"hit":false})
func debug_snapshot()->Dictionary:
	var result:Dictionary=_stats.duplicate();result.ground_count=_ground.size();result.total_count=_count();result.pending=not _pending.is_empty();result.geometry_cache=_geometry.size();result.falling_count=_falling.size()
	var rows:Array=[]
	for row:Dictionary in _ground.values():
		if _row_live(row):rows.append({"item_uid":row.uid,"drop_uid":row.drop_uid,"weaponId":row.weapon_id,"world_aabb":row.visual.global_transform*row.bounds})
	result.ground=rows;result.hover=hover_snapshot();return result
func dispose()->void:
	if not Thread.is_main_thread():return
	clear_hover()
	if not _pending.is_empty():_close_requested=true;return
	_ready=false;_interrupted=true
	# Host calls this from _exit_tree while its parent is already removing children.
	# Queueing also remains safe when that parent frees these nodes itself first.
	if is_instance_valid(_ground_layer):_ground_layer.visible=false;_ground_layer.queue_free()
	for binding:Dictionary in _trunks.values():
		if is_instance_valid(binding.layer):binding.layer.visible=false;binding.layer.queue_free()
	_ground_layer=null;_trunks={};_ground={};_falling={};_geometry={};_native_bounds={};_aim_samples={};_hover_material=null;_catalog=null;_world=null;_validator=Callable();_close_requested=false
func _notification(what:int)->void:
	if what==NOTIFICATION_PREDELETE and Thread.is_main_thread():
		# RefCounted script methods cannot be dispatched during PREDELETE.
		if is_instance_valid(_ground_layer):_ground_layer.queue_free()
		for binding:Dictionary in _trunks.values():
			if is_instance_valid(binding.layer):binding.layer.queue_free()

func ground_receipt(drop_uid: String, item_uid: String) -> Dictionary:
	# Cheap original-mesh/UID lifetime admission, no triangle search or ownership.
	if not _live() or not _ground.has(drop_uid): return {"ok":false}
	var row: Dictionary=_ground[drop_uid]
	if row.uid!=item_uid or not _model_current(row) or not row.visual.visible or not row.visual.is_visible_in_tree(): return {"ok":false}
	return {"ok":true,"point":row.visual.global_transform*row.bounds.get_center(),"weapon_id":row.weapon_id}

func ui_bounds(scope: String, uid: String, vehicle_id: String="", generation: int=0) -> Dictionary:
	# Read-only original bounds descriptor; no triangle query/authority mutation.
	var row: Dictionary={}
	if scope=="ground": row=_ground.get(uid,{})
	elif scope=="trunk":
		var binding: Dictionary=_trunks.get(vehicle_id,{})
		if binding.get("generation")!=generation: return {}
		row=binding.get("items",{}).get(uid,{})
	if row.is_empty() or not _row_live(row) or not row.visual.is_visible_in_tree(): return {}
	return {"node":weakref(row.visual),"bounds":row.bounds}

## Cosmetic only. Caller supplies fresh admitted aim_context; never owns an item.
func set_hover(context:Dictionary)->void:
	if not Thread.is_main_thread() or _busy:return
	var row:Dictionary={};var scope:="";var vehicle_id:=""
	var uid:=str(context.get("item_uid",""));var drop_uid:=str(context.get("drop_uid",""))
	if not uid.is_empty() and context.get("cargo_allowed",false) and context.get("open",false):
		for id:String in _trunks:
			var binding:Dictionary=_binding(id,int(_trunks[id].generation))
			if binding.get("items",{}).has(uid):row=binding.items[uid];scope="trunk";vehicle_id=id;break
	elif not drop_uid.is_empty():row=_ground.get(drop_uid,{});scope="ground"
	if not _live() or row.is_empty() or not _row_live(row) or not row.visual.is_visible_in_tree():clear_hover();return
	if _hover.get("node") is WeakRef and _hover.node.get_ref()==row.visual:return
	clear_hover()
	for part:Dictionary in row.parts:
		var node:MeshInstance3D=part.node.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree():continue
		_hover_parts.append({"node":weakref(node),"overlay":node.material_overlay})
		node.material_overlay=_hover_material
	_hover={"node":weakref(row.visual),"item_uid":row.uid,"scope":scope,"vehicle_id":vehicle_id,"drop_uid":drop_uid}

func clear_hover()->void:
	if not Thread.is_main_thread():return
	for part:Dictionary in _hover_parts:
		var node:MeshInstance3D=part.node.get_ref()
		# Restore precisely our override; do not clobber a later owner's material.
		if is_instance_valid(node) and node.material_overlay==_hover_material:node.material_overlay=part.overlay
	_hover_parts.clear();_hover.clear()

func hover_snapshot()->Dictionary:
	if _hover.is_empty():return {"active":false,"parts":0}
	return {"active":true,"item_uid":_hover.item_uid,"scope":_hover.scope,"vehicle_id":_hover.vehicle_id,"drop_uid":_hover.drop_uid,"parts":_hover_parts.size(),"depth_test":not _hover_material.no_depth_test}
