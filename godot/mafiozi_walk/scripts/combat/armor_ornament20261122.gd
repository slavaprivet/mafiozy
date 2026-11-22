extends RefCounted
## Close-range ornament only. One cached mesh per tier/slot; the fitted Skin,
## contact surface, collision and absorption values stay with their owners.
static var _cache: Dictionary = {}
static var _materials: Dictionary = {}

static func mesh_for(tier: String, slot: String) -> ArrayMesh:
	var key := tier + ":" + slot
	if _cache.has(key): return _cache[key]
	var steel := Color(.53, .58, .59) if tier == "medium" else Color(.39, .45, .48)
	var edge := Color(.52, .34, .18) if tier == "light" else Color(.42, .47, .47) if tier == "medium" else Color(.51, .49, .40)
	var dark := Color(.15, .095, .055) if tier == "light" else Color(.15, .19, .21) if tier == "medium" else Color(.11, .14, .16)
	var main := Color(.43, .25, .12) if tier == "light" else steel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match slot:
		"head":
			# Brow stitching, nasal/rim trim and a small badge, clear of the eyes.
			var z := .62 if tier == "light" else .59
			_ribbon(st, Vector3(-.43,.88,z), Vector3(.43,.88,z), Vector3(0,.018,0), edge)
			if tier == "light":
				for x in [-.35,-.24,-.13,.13,.24,.35]:
					_ribbon(st, Vector3(x,.84,z+.008), Vector3(x+.018,.91,z+.008), Vector3(.007,0,0), dark)
			elif tier == "medium":
				_ribbon(st, Vector3(0,.87,z+.01), Vector3(0,.42,z+.06), Vector3(.026,0,0), steel.lightened(.12))
				for x in [-.32,-.16,.16,.32]: _stud(st, Vector3(x,.89,z+.015), .020, edge)
			else:
				_ribbon(st, Vector3(-.29,1.01,z-.035), Vector3(.29,1.01,z-.035), Vector3(0,.025,0), edge)
				_stud(st, Vector3(0,1.02,z), .045, edge)
		"torso":
			var z := .56 if tier == "light" else .67 if tier == "medium" else .75
			if tier == "light":
				_ribbon(st, Vector3(-.45,.86,z-.07), Vector3(.34,-.40,z), Vector3(.030,.020,0), dark)
				_ribbon(st, Vector3(.45,.86,z-.07), Vector3(-.34,-.40,z), Vector3(.030,-.020,0), edge)
				for y in [-.24,.02,.28,.54]:
					_stud(st, Vector3(-.12,y,z+.018), .014, edge)
					_stud(st, Vector3(.12,y,z+.018), .014, edge)
			elif tier == "medium":
				for y in [-.28,-.04,.20,.44,.68]:
					_ribbon(st, Vector3(-.48,y,z-.04), Vector3(.48,y,z-.04), Vector3(0,.019,0), edge)
					for x in [-.31,0.0,.31]: _stud(st, Vector3(x,y+.025,z-.01), .014, dark)
				_ribbon(st, Vector3(0,-.36,z+.015), Vector3(0,.82,z+.015), Vector3(.021,0,0), dark)
			else:
				_ribbon(st, Vector3(0,-.32,z), Vector3(0,.91,z-.06), Vector3(.022,0,0), edge)
				for side in [-1.0,1.0]:
					_ribbon(st, Vector3(side*.07,.80,z-.01), Vector3(side*.48,.28,z-.10), Vector3(.014,.012,0), edge)
					for y in [-.21,.06,.33]: _stud(st, Vector3(side*.43,y,z-.09), .016, edge)
			_ribbon(st, Vector3(-.47,-.46,z-.07), Vector3(.47,-.46,z-.07), Vector3(0,.032,0), dark)
			_stud(st, Vector3(0,-.46,z-.035), .052, edge)
		"hands":
			var z := .15 if tier == "light" else .18 if tier == "medium" else .23
			for y in [-.22,-.09,.04,.18]:
				_ribbon(st, Vector3(-.14,y,z), Vector3(.14,y,z), Vector3(0,.012 if tier == "light" else .021,0), edge if tier != "heavy" else steel)
			if tier == "light":
				_ribbon(st, Vector3(0,-.29,z+.01), Vector3(0,.25,z+.01), Vector3(.009,0,0), dark)
			else:
				for x in [-.09,0.0,.09]: _stud(st, Vector3(x,-.20,z+.01), .014, edge)
		"legs":
			var z := .25 if tier == "light" else .29 if tier == "medium" else .35
			for y in [-.37,-.14,.10]:
				_ribbon(st, Vector3(-.18,y,z), Vector3(.18,y,z), Vector3(0,.014 if tier == "light" else .022,0), edge)
			if tier == "light":
				_ribbon(st, Vector3(.10,-.42,z+.008), Vector3(-.10,.20,z+.008), Vector3(.014,.005,0), dark)
			else:
				_ribbon(st, Vector3(0,-.40,z+.008), Vector3(0,.21,z+.008), Vector3(.015,0,0), steel)
				for y in [-.31,-.06,.17]: _stud(st, Vector3(0,y,z+.016), .015, edge)
		"feet":
			var y := .16 if tier == "light" else .19
			for z in [.03,.20,.37]:
				_ribbon(st, Vector3(-.17,y,z), Vector3(.17,y,z), Vector3(0,0,.014 if tier == "light" else .022), edge)
			if tier == "light":
				for z in [.11,.28]: _ribbon(st, Vector3(-.06,y+.008,z), Vector3(.06,y+.008,z+.07), Vector3(.007,0,0), dark)
			else:
				_ribbon(st, Vector3(0,y+.008,.04), Vector3(0,y+.008,.46), Vector3(.014,0,0), steel)
	st.index()
	st.generate_normals()
	var result: ArrayMesh = st.commit()
	_cache[key] = result
	return result

static func material_for(tier: String) -> StandardMaterial3D:
	if _materials.has(tier): return _materials[tier]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.0 if tier == "light" else .42 if tier == "medium" else .55
	mat.roughness = .79 if tier == "light" else .58
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[tier] = mat
	return mat

static func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3, half_width: Vector3, color: Color) -> void:
	var p0 := a - half_width
	var p1 := a + half_width
	var p2 := b - half_width
	var p3 := b + half_width
	st.set_color(color)
	for p in [p0,p2,p1,p1,p2,p3]: st.add_vertex(p)

static func _stud(st: SurfaceTool, center: Vector3, radius: float, color: Color) -> void:
	st.set_color(color)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var b := TAU * float(i + 1) / 6.0
		st.add_vertex(center + Vector3(0,0,.008))
		st.add_vertex(center + Vector3(cos(a)*radius,sin(a)*radius,0))
		st.add_vertex(center + Vector3(cos(b)*radius,sin(b)*radius,0))
