extends RefCounted
## Read-only native admission for the original small bank. This script creates
## no bank, floor, teleport, route or money. The eight-building preview currently
## has NONE of the required native bank bodies, so configure fails closed.
const Geometry=preload("npc_bank_geometry_snapshot.gd")
var _geometry: RefCounted
const BUILDING := "REBUILD-bank:small"
const ASSET_SHA := "ba3580e4549cf1cce5ceea826aad62158118271a2dbacf23723da7bc33664aab"
const WORLD_ORIGIN := Vector3(217.3,0,131.2)
const SERVICE_LOCAL := Vector3(0,.1,3.208333333333332)
const HALF := .738
var _scene: WeakRef
var _host: RefCounted
var _token := {}
var _bank_root: WeakRef
var _frame := Transform3D.IDENTITY
var _floor: CollisionShape3D
var _doors: Array[CollisionShape3D] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _square := PhysicsShapeQueryParameters3D.new()
var _invalid := false
var _body_pins := []

func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason,"building_id":BUILDING}
func _changed() -> void: _invalid = true

func configure(scene: Node3D, host: RefCounted, token: Dictionary) -> Dictionary:
	if _scene != null or not is_instance_valid(scene) or not scene.is_inside_tree() or not host.target_current(token): return _fail("bank_lifetime")
	var captured: Dictionary=Geometry.acquire(scene)
	if not captured.get("ok",false):return captured
	_geometry=captured.snapshot
	if not host.target_current(token): _geometry.release();_geometry=null;return _fail("bank_actor_life_changed")
	_frame=_geometry.frame;_floor=_geometry.floor_shape;_doors.assign(_geometry.doors);_body_pins=_geometry.pins
	var native_root: Node3D=_geometry.root_ref.get_ref()
	_scene = weakref(scene); _bank_root = weakref(native_root); _host = host; _token = token.duplicate()
	_ray.collision_mask = 1; _ray.exclude = [token.body.get_rid()]
	var box := BoxShape3D.new(); box.size = Vector3(HALF*2,1.9,HALF*2)
	_square.shape = box; _square.collision_mask = 1|256; _square.margin = .001; _square.exclude = [token.body.get_rid()]
	return {"ok":true,"building_id":BUILDING,"service_world":_frame*SERVICE_LOCAL,"source_authority":false,"scope":"new_local_bank_service_at_original_lobby"}

func current_arrival() -> Dictionary:
	if _invalid or _scene == null or not is_instance_valid(_scene.get_ref()) or not _host.target_current(_token) or not is_instance_valid(_bank_root.get_ref()): return _fail("bank_or_actor_life_changed")
	if not _bank_root.get_ref().global_transform.is_equal_approx(_frame): return _fail("bank_frame_changed")
	if _geometry==null:return _fail("bank_geometry_lifetime")
	var current: Dictionary=_geometry.current()
	if not current.get("ok",false):return current
	if not _floor.global_transform.is_equal_approx(_frame): return _fail("bank_floor_moved")
	# Source building_entry_profiles.mjs opens the two authored leaves by
	# +/-pi/2 around their outer edges. Require those actual collider poses.
	for index in 2:
		var side := -1.0 if index==0 else 1.0
		var expected := _frame * Transform3D(Basis.IDENTITY,Vector3(side*1.41,.1,7.15)) * Transform3D(Basis(Vector3.UP,-side*PI/2.0),Vector3.ZERO) * Transform3D(Basis.IDENTITY,Vector3(-side*.7,1.5,0))
		if not _doors[index].global_transform.is_equal_approx(expected): return _fail("bank_public_door_not_open")
	var body: CharacterBody3D = _token.body
	var target: Vector3 = _frame*SERVICE_LOCAL
	if not body.is_on_floor() or body.global_position.distance_to(target)>.12: return _fail("bank_physical_service_arrival_required")
	var space: PhysicsDirectSpaceState3D = _scene.get_ref().get_world_3d().direct_space_state
	for offset: Vector2 in [Vector2.ZERO,Vector2(-HALF,-HALF),Vector2(-HALF,HALF),Vector2(HALF,-HALF),Vector2(HALF,HALF)]:
		var point := body.global_position+Vector3(offset.x,0,offset.y)
		_ray.from = point+Vector3.UP*.2; _ray.to = point-Vector3.UP*.2
		var hit: Dictionary = space.intersect_ray(_ray)
		if hit.is_empty() or hit.collider!=_floor.get_parent() or hit.normal.y<.99 or absf(hit.position.y-target.y)>.002: return _fail("bank_source_square_floor")
	_square.transform = Transform3D(Basis.IDENTITY,body.global_position+Vector3.UP*.975)
	if not space.intersect_shape(_square,1).is_empty(): return _fail("bank_service_occupied")
	if not _host._owned_clear(body.global_position,_token.source_id): return _fail("bank_actor_occupant")
	return {"ok":true,"building_id":BUILDING,"position":[body.global_position.x,body.global_position.y,body.global_position.z]}

func dispose() -> void:
	if _geometry!=null:_geometry.release();_geometry=null
	_scene=null;_bank_root=null;_host=null;_floor=null;_doors.clear();_body_pins=[];_token={};_invalid=true

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and _geometry!=null:_geometry.release();_geometry=null
