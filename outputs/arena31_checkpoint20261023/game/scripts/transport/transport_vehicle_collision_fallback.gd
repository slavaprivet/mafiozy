extends RefCounted
## vehicle_damage.mjs collision(before,after), source +Z coordinates.
## Host owns the car pose and recursive Three-style raycast. No Godot forward
## axis conversion or native physics query is performed here.
const RAY_NEAR_M:=0.0
const RAY_FAR_M:=5.0
var _authority: RefCounted
var _vehicle_id: String
var _generation:=0
var _pending: Dictionary={}

func configure(authority: RefCounted,vehicle_id: String,generation: int) -> bool:
	if _authority!=null or authority==null or vehicle_id.is_empty() or generation<1: return false
	_authority=authority; _vehicle_id=vehicle_id; _generation=generation
	return true

## Input receipt: authority/id/generation, before:{speed,travelYaw?,yaw?},
## after:{bumped,contact?}, source_object_world:Transform3D,
## source_object_rotation_y:float. The latter is local object.rotation.y,
## not a yaw inferred from a native basis.
func plan(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or not _pending.is_empty(): return {"ok":false,"error":"authority_or_pending"}
	var before: Variant=receipt.get("before"); var after: Variant=receipt.get("after")
	if not before is Dictionary or not after is Dictionary or not after.get("bumped") is bool: return {"ok":false,"error":"motion_receipt"}
	if not after.bumped: return {"ok":true,"action":"none","source_return":false}
	var direct_contact: Variant=after.get("contact")
	if _source_truthy(direct_contact):
		if not direct_contact is Dictionary: return {"ok":false,"error":"direct_contact"}
		return {"ok":true,"action":"direct_contact","contact_source":direct_contact}
	var speed_before: Variant=before.get("speed"); var speed_after: Variant=after.get("speed")
	if not _number(speed_before) or not _number(speed_after): return {"ok":false,"error":"speed_receipt"}
	var yaw_value: Variant=before.get("travelYaw")
	if yaw_value==null: yaw_value=before.get("yaw")
	if yaw_value==null: yaw_value=receipt.get("source_object_rotation_y")
	if not _number(yaw_value) or not receipt.get("source_object_world") is Transform3D:
		return {"ok":false,"error":"source_pose"}
	var frame: Transform3D=receipt.source_object_world
	if not frame.is_finite(): return {"ok":false,"error":"source_pose"}
	var sign: float=1.0 if float(speed_before)>=0.0 else -1.0
	var yaw: float=float(yaw_value)
	var normal:=Vector3(sin(yaw)*sign,0.0,cos(yaw)*sign)
	var center: Vector3=frame*Vector3(0.0,.75,0.0)
	var ray_origin: Vector3=center+normal*4.0
	var ray_direction: Vector3=-normal
	var fallback_point: Vector3=center+normal*2.0
	if not normal.is_finite() or not center.is_finite() or not ray_origin.is_finite() or not fallback_point.is_finite():
		return {"ok":false,"error":"nonfinite_fallback"}
	var lost: float=maxf(0.0,absf(float(speed_before))-absf(float(speed_after)))
	var ticket:=RefCounted.new()
	_pending={"ticket":ticket,"normal":normal,"center":center,"fallback_point":fallback_point,"lost":lost}
	return {"ok":true,"action":"raycast","ticket":ticket,"ray_origin_source":ray_origin,"ray_direction_source":ray_direction,"ray_near_m":RAY_NEAR_M,"ray_far_m":RAY_FAR_M,"recursive":true,"filter":"first ordered hit with object.visible and no directly transparent scalar material","center_source":center,"fallback_point_source":fallback_point,"normal_source":normal,"impact_speed_mps":lost}

## The host returns recursive intersection hits in ascending ray distance.
## Filtering happens AFTER the raycast, matching source .find(...).
## Each hit: {point_source:Vector3,distance_m:number,object_visible:bool,
## direct_scalar_material_transparent:bool}.
func resolve_raycast(receipt: Dictionary) -> Dictionary:
	if not _identity(receipt) or _pending.is_empty() or receipt.get("ticket")!=_pending.ticket or receipt.get("raycast_complete")!=true or not receipt.get("hits") is Array:
		return {"ok":false,"error":"raycast_receipt"}
	var chosen: Variant=null; var prior_distance: float=-INF
	for item: Variant in receipt.hits:
		if not item is Dictionary or not item.get("point_source") is Vector3 or not item.point_source.is_finite() or not _number(item.get("distance_m")) or not item.get("object_visible") is bool or not item.get("direct_scalar_material_transparent") is bool:
			return {"ok":false,"error":"raycast_hit"}
		var distance: float=float(item.distance_m)
		if distance<RAY_NEAR_M or distance>RAY_FAR_M or distance<prior_distance: return {"ok":false,"error":"raycast_order_or_range"}
		prior_distance=distance
		if chosen==null and item.object_visible and not item.direct_scalar_material_transparent: chosen=item.point_source
	var pending: Dictionary=_pending; _pending={}
	var point: Vector3=chosen if chosen!=null else pending.fallback_point
	return {"ok":true,"action":"contact","used_hit":chosen!=null,"contact_source":{"point":point,"normal":pending.normal,"impactSpeed":pending.lost,"slideSpeed":0.0}}

func cancel_pending(ticket: RefCounted) -> bool:
	if _pending.is_empty() or _pending.ticket!=ticket: return false
	_pending={}; return true

func dispose() -> void:
	_pending={}; _authority=null

func _identity(receipt: Dictionary) -> bool:
	return _authority!=null and receipt.get("authority")==_authority and receipt.get("vehicle_id")==_vehicle_id and receipt.get("life_generation")==_generation

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _source_truthy(value: Variant) -> bool:
	if value==null: return false
	if value is bool: return value
	if value is int or value is float: return float(value)!=0.0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true
