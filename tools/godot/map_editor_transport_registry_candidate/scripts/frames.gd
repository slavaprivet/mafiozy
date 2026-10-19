extends RefCounted
static func encode_transform(frame: Transform3D) -> Dictionary:
	var rotation := frame.basis.orthonormalized().get_euler()
	var scale := frame.basis.get_scale()
	return {"position":[frame.origin.x,frame.origin.y,frame.origin.z],"rotation":[rotation.x,rotation.y,rotation.z],"scale":[scale.x,scale.y,scale.z]}
static func decode_transform(data: Dictionary) -> Variant:
	var vectors: Array[Vector3] = []
	for key in ["position","rotation","scale"]:
		var array: Variant = data.get(key)
		if not array is Array or array.size() != 3: return null
		for number in array:
			if not typeof(number) in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)): return null
		vectors.append(Vector3(array[0],array[1],array[2]))
	if vectors[2].x < 0.0001 or vectors[2].y < 0.0001 or vectors[2].z < 0.0001: return null
	return Transform3D(Basis.from_euler(vectors[1]).scaled_local(vectors[2]),vectors[0])
