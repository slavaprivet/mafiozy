extends RefCounted
## Source-exact cell ownership for vehicle_crash.mjs gridInterval/gridBlend.
## Input is the native mesh point; output indices retain source z/y/x order.

static func bind_native(profile: Dictionary, point_native: Vector3) -> Dictionary:
	if not point_native.is_finite(): return {"ok":false,"error":"point"}
	return bind_source(profile,PackedFloat64Array([-float(point_native.x),float(point_native.y),-float(point_native.z)]))

static func bind_source(profile: Dictionary, coordinates: PackedFloat64Array) -> Dictionary:
	if coordinates.size()!=3 or not is_finite(coordinates[0]) or not is_finite(coordinates[1]) or not is_finite(coordinates[2]): return {"ok":false,"error":"point"}
	for field in ["halfWidth","halfLength","height"]:
		if not (profile.get(field) is float or profile.get(field) is int) or not is_finite(float(profile[field])) or float(profile[field])<=0.0: return {"ok":false,"error":"profile"}
	var half_width:=float(profile.halfWidth); var half_length:=float(profile.halfLength); var height:=float(profile.height)
	var x:=PackedFloat64Array([-half_width,0.0,half_width])
	var y:=PackedFloat64Array([.28,height*.46,height*.91])
	var z:=PackedFloat64Array([-half_length,-half_length*.5,0.0,half_length*.5,half_length])
	if not _strictly_increasing(y): return {"ok":false,"error":"profile_grid"}
	var xi:=_source_interval(x,coordinates[0]); var yi:=_source_interval(y,coordinates[1]); var zi:=_source_interval(z,coordinates[2])
	var blend_f64:=PackedFloat64Array([_source_blend(x,coordinates[0],xi),_source_blend(y,coordinates[1],yi),_source_blend(z,coordinates[2],zi)])
	var indices:=PackedByteArray(); var mask_lo:=0; var mask_hi:=0
	for zz in 2:
		for yy in 2:
			for xx in 2:
				var index:=((zi+zz)*3+yi+yy)*3+xi+xx; indices.append(index)
				if index<32: mask_lo|=1<<index
				else: mask_hi|=1<<(index-32)
	# blend_f64 is authoritative source arithmetic. The Vector3 view exists only
	# for optional presentation/debug callers and intentionally loses precision.
	return {"ok":true,"cell":Vector3i(xi,yi,zi),"blend_f64":blend_f64,"blend":Vector3(blend_f64[0],blend_f64[1],blend_f64[2]),"node_indices":indices,"mask_lo":mask_lo,"mask_hi":mask_hi}

static func _source_interval(values: PackedFloat64Array, value: float) -> int:
	if value<=values[0]: return 0
	var last:=values.size()-1
	if value>=values[last]: return last-1
	for i in last:
		if value<=values[i+1]: return i
	return last-1

static func _source_blend(values: PackedFloat64Array, value: float, index: int) -> float:
	var bounded:=clampf(value,values[0],values[values.size()-1])
	return (bounded-values[index])/(values[index+1]-values[index])

static func _strictly_increasing(values: PackedFloat64Array) -> bool:
	for i in values.size()-1:
		if not is_finite(values[i]) or values[i+1]<=values[i]: return false
	return is_finite(values[-1])
