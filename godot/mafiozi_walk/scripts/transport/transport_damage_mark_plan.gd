extends RefCounted
## Pure source-parity planner for the bounded 32-slot body-paint mark pool.
## The host owns cursor persistence, surface queries, transforms and authority.

const POOL_SIZE:=32
const SCRATCH_MODULO:=3
const SURFACE_OFFSET:=0.007
const ANGLE_STEP:=2.399
const SLIDE_THRESHOLD:=1.5
const MAX_SAFE_CURSOR:=9007199254740991 # JavaScript Number.MAX_SAFE_INTEGER.
const UNIT_TOLERANCE_SQUARED:=1.0e-8

static func plan_bullet(cursor_value: Variant,local_point: Variant,local_normal: Variant,damage_value: Variant=24.0) -> Dictionary:
	var common:=_common(cursor_value,local_point,local_normal)
	if not common.ok: return common
	if not _finite_number(damage_value) or float(damage_value)<0.0: return _error("damage")
	var cursor: int=common.cursor
	while (cursor%POOL_SIZE)%SCRATCH_MODULO==0: cursor+=1
	var next_cursor:=cursor+1
	if next_cursor>MAX_SAFE_CURSOR: return _error("cursor")
	var scalar:=minf(3.2,0.75+sqrt(maxf(0.0,float(damage_value)))*0.16)
	return _round_result("bullet",cursor%POOL_SIZE,next_cursor,common.point,common.normal,scalar)

static func plan_collision_round(cursor_value: Variant,local_point: Variant,local_normal: Variant) -> Dictionary:
	var common:=_common(cursor_value,local_point,local_normal)
	if not common.ok: return common
	var next_cursor: int=common.cursor+1
	if next_cursor>MAX_SAFE_CURSOR: return _error("cursor")
	return _round_result("collision_round",common.cursor%POOL_SIZE,next_cursor,common.point,common.normal,2.2)

static func plan_collision_scratch(cursor_value: Variant,local_point: Variant,local_normal: Variant,local_tangent: Variant,impact_speed_value: Variant,slide_speed_value: Variant) -> Dictionary:
	var common:=_common(cursor_value,local_point,local_normal)
	if not common.ok: return common
	if not _unit_f64_vec3(local_tangent): return _error("tangent")
	if not _finite_number(impact_speed_value) or float(impact_speed_value)<0.0: return _error("impact_speed")
	if not _finite_number(slide_speed_value) or float(slide_speed_value)<SLIDE_THRESHOLD: return _error("slide_speed")
	var tangent: PackedFloat64Array=local_tangent
	var cursor: int=common.cursor
	while cursor%SCRATCH_MODULO!=0: cursor+=1
	while (cursor%POOL_SIZE)%SCRATCH_MODULO!=0: cursor+=1
	var next_cursor:=cursor+1
	if next_cursor>MAX_SAFE_CURSOR: return _error("cursor")
	var y:=PackedFloat64Array([
		common.normal[1]*tangent[2]-common.normal[2]*tangent[1],
		common.normal[2]*tangent[0]-common.normal[0]*tangent[2],
		common.normal[0]*tangent[1]-common.normal[1]*tangent[0],
	])
	var y_length:=sqrt(y[0]*y[0]+y[1]*y[1]+y[2]*y[2])
	if not is_finite(y_length) or y_length<=0.0: return _error("tangent")
	for i in 3: y[i]/=y_length
	return {
		"ok":true,"kind":"collision_scratch","slot":cursor%POOL_SIZE,"slot_kind":_slot_kind(cursor%POOL_SIZE),"next_cursor":next_cursor,
		"position":_surface_position(common.point,common.normal),
		"quaternion":_basis_quaternion(tangent,y,common.normal),
		"scale":PackedFloat64Array([minf(5.0,1.0+float(slide_speed_value)*0.16),1.0+minf(2.0,float(impact_speed_value)*0.12),1.0]),
		"angle_after_increment":float(next_cursor)*ANGLE_STEP,
	}

static func _round_result(kind: String,slot: int,next_cursor: int,point: PackedFloat64Array,normal: PackedFloat64Array,scalar: float) -> Dictionary:
	var angle:=float(next_cursor)*ANGLE_STEP
	return {"ok":true,"kind":kind,"slot":slot,"slot_kind":_slot_kind(slot),"next_cursor":next_cursor,"position":_surface_position(point,normal),"quaternion":_round_quaternion(normal,angle),"scale":PackedFloat64Array([scalar,scalar,scalar]),"angle_after_increment":angle}

static func _slot_kind(slot: int) -> String: return "scratch" if slot%SCRATCH_MODULO==0 else "crater"

static func _surface_position(point: PackedFloat64Array,normal: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([point[0]+normal[0]*SURFACE_OFFSET,point[1]+normal[1]*SURFACE_OFFSET,point[2]+normal[2]*SURFACE_OFFSET])

static func _round_quaternion(normal: PackedFloat64Array,angle: float) -> PackedFloat64Array:
	var x: float; var y: float; var z: float; var w: float; var r:=normal[2]+1.0
	if r<2.220446049250313e-16:
		x=0.0; y=-1.0; z=0.0; w=0.0
	else:
		x=-normal[1]; y=normal[0]; z=0.0; w=r
	var inverse:=1.0/sqrt(x*x+y*y+z*z+w*w); x*=inverse; y*=inverse; z*=inverse; w*=inverse
	var sine:=sin(angle*0.5); var cosine:=cos(angle*0.5)
	return PackedFloat64Array([x*cosine+y*sine,y*cosine-x*sine,w*sine+z*cosine,w*cosine-z*sine])

static func _basis_quaternion(x_axis: PackedFloat64Array,y_axis: PackedFloat64Array,z_axis: PackedFloat64Array) -> PackedFloat64Array:
	var m11:=x_axis[0]; var m12:=y_axis[0]; var m13:=z_axis[0]
	var m21:=x_axis[1]; var m22:=y_axis[1]; var m23:=z_axis[1]
	var m31:=x_axis[2]; var m32:=y_axis[2]; var m33:=z_axis[2]
	var x: float; var y: float; var z: float; var w: float; var trace:=m11+m22+m33
	if trace>0.0:
		var s:=0.5/sqrt(trace+1.0); w=0.25/s; x=(m32-m23)*s; y=(m13-m31)*s; z=(m21-m12)*s
	elif m11>m22 and m11>m33:
		var s:=2.0*sqrt(1.0+m11-m22-m33); w=(m32-m23)/s; x=0.25*s; y=(m12+m21)/s; z=(m13+m31)/s
	elif m22>m33:
		var s:=2.0*sqrt(1.0+m22-m11-m33); w=(m13-m31)/s; x=(m12+m21)/s; y=0.25*s; z=(m23+m32)/s
	else:
		var s:=2.0*sqrt(1.0+m33-m11-m22); w=(m21-m12)/s; x=(m13+m31)/s; y=(m23+m32)/s; z=0.25*s
	return PackedFloat64Array([x,y,z,w])

static func _common(cursor_value: Variant,point_value: Variant,normal_value: Variant) -> Dictionary:
	if not cursor_value is int or int(cursor_value)<0 or int(cursor_value)>MAX_SAFE_CURSOR: return _error("cursor")
	if not _f64_vec3(point_value): return _error("point")
	if not _unit_f64_vec3(normal_value): return _error("normal")
	return {"ok":true,"cursor":int(cursor_value),"point":point_value,"normal":normal_value}

static func _f64_vec3(value: Variant) -> bool:
	if not value is PackedFloat64Array or value.size()!=3: return false
	return is_finite(value[0]) and is_finite(value[1]) and is_finite(value[2])

static func _unit_f64_vec3(value: Variant) -> bool:
	if not _f64_vec3(value): return false
	var length_squared: float=value[0]*value[0]+value[1]*value[1]+value[2]*value[2]
	return is_finite(length_squared) and absf(length_squared-1.0)<=UNIT_TOLERANCE_SQUARED

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _error(reason: String) -> Dictionary: return {"ok":false,"error":reason}
