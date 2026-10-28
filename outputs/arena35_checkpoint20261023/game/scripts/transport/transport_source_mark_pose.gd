extends RefCounted
## Converts a source mark plan into the exact raw Three Matrix4.compose layout.
## Quaternion values are used directly and are never normalized or rebuilt.

static func compose(local_position_f64: Variant,raw_quaternion_f64: Variant,local_scale_f64: Variant) -> Dictionary:
	if not _f64_vector(local_position_f64,3): return _error("position")
	if not _f64_vector(raw_quaternion_f64,4): return _error("quaternion")
	if not _f64_vector(local_scale_f64,3): return _error("scale")
	var position: PackedFloat64Array=local_position_f64
	var quaternion: PackedFloat64Array=raw_quaternion_f64
	var scale: PackedFloat64Array=local_scale_f64
	if scale[0]<=0.0 or scale[1]<=0.0 or scale[2]<=0.0: return _error("scale")
	var native_scale:=Vector3(scale[0],scale[1],scale[2])
	if not native_scale.is_finite() or native_scale.x<=0.0 or native_scale.y<=0.0 or native_scale.z<=0.0: return _error("native_overflow")
	var x:=quaternion[0]; var y:=quaternion[1]; var z:=quaternion[2]; var w:=quaternion[3]
	var x2:=x+x; var y2:=y+y; var z2:=z+z
	var xx:=x*x2; var xy:=x*y2; var xz:=x*z2
	var yy:=y*y2; var yz:=y*z2; var zz:=z*z2
	var wx:=w*x2; var wy:=w*y2; var wz:=w*z2
	var matrix:=PackedFloat64Array([
		(1.0-(yy+zz))*scale[0],(xy+wz)*scale[0],(xz-wy)*scale[0],0.0,
		(xy-wz)*scale[1],(1.0-(xx+zz))*scale[1],(yz+wx)*scale[1],0.0,
		(xz+wy)*scale[2],(yz-wx)*scale[2],(1.0-(xx+yy))*scale[2],0.0,
		position[0],position[1],position[2],1.0,
	])
	for value in matrix:
		if not is_finite(value): return _error("nonfinite_result")
	var x_column:=PackedFloat64Array([matrix[0],matrix[1],matrix[2]])
	var y_column:=PackedFloat64Array([matrix[4],matrix[5],matrix[6]])
	var z_column:=PackedFloat64Array([matrix[8],matrix[9],matrix[10]])
	# Explicit columns preserve the source's nonorthogonal scratch basis. Do not
	# replace this with Basis(Quaternion), which normalizes/reinterprets it.
	var native_basis:=Basis(Vector3(x_column[0],x_column[1],x_column[2]),Vector3(y_column[0],y_column[1],y_column[2]),Vector3(z_column[0],z_column[1],z_column[2]))
	var native_transform:=Transform3D(native_basis,Vector3(position[0],position[1],position[2]))
	if not native_transform.basis.x.is_finite() or not native_transform.basis.y.is_finite() or not native_transform.basis.z.is_finite() or not native_transform.origin.is_finite(): return _error("native_overflow")
	return {"ok":true,"matrix_f64":matrix,"x_column_f64":x_column,"y_column_f64":y_column,"z_column_f64":z_column,"native_transform":native_transform}

static func _f64_vector(value: Variant,size: int) -> bool:
	if not value is PackedFloat64Array or value.size()!=size: return false
	for component in value:
		if not is_finite(component): return false
	return true

static func _error(reason: String) -> Dictionary: return {"ok":false,"error":reason}
