extends Node3D
## Shared geometric tufts and embedded stones; one draw per visible tile/type.
## Sparse footprint pixels are updated at 10 Hz, never one script per blade.
const MAP_SIZE := 512
const TILE := 12.0
const RECOVERY_SECONDS := 11.0
const MAX_ACTIVE_PIXELS := 8192
var _field: Node3D
var _scene: Node
var _material: ShaderMaterial
var _image: Image
var _texture: ImageTexture
var _active: Dictionary = {}
var _clock := 0.0
var _accum := 0.0
var _last_position := Vector3.INF
var _height_grid := PackedFloat32Array()
var _batches: Array[MultiMeshInstance3D] = []
var _rig: Skeleton3D
var _leg_bones := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _stats := {"tufts":0,"blades":0,"stones":0,"grass_batches":0,"stone_batches":0,"stamps":0,"updates":0,"active_pixels":0,"colliders":0}

func install(field: Node3D, scene: Node) -> void:
	_field = field; _scene = scene; _rng.seed = 491810
	name = "GroundCover49"
	_image = Image.create(MAP_SIZE,MAP_SIZE,false,Image.FORMAT_RGBA8)
	_image.fill(Color(0,.5,.5,1))
	_texture = ImageTexture.create_from_image(_image)
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/terrain/grass49.gdshader")
	_material.set_shader_parameter("trample_map",_texture)
	_material.set_shader_parameter("field_origin",field.global_position)
	for iz in 67:
		for ix in 73:
			_height_grid.append(field.terrain_height(-90.0+ix*2.5,76.0+iz*(176.0/66.0)))
	var tuft := _make_tuft()
	var stone := SphereMesh.new()
	stone.radius = .5; stone.height = 1.0; stone.radial_segments = 6; stone.rings = 2
	var stone_material := StandardMaterial3D.new()
	stone_material.vertex_color_use_as_albedo = true
	stone_material.roughness = 1.0
	for tz in 15:
		for tx in 15:
			_build_tile(tx,tz,tuft,stone,stone_material)
	_stats.blades = _stats.tufts * 14
	set_process(true)

func _surface_y(x: float,z: float) -> float:
	# Exact triangle interpolation of the existing 73x67 ground grid, not the
	# analytic hill function between vertices (which can float above its mesh).
	var gx := clampf((x+90.0)/2.5,0,71.9999)
	var gz := clampf((z-76.0)/(176.0/66.0),0,65.9999)
	var ix := int(gx); var iz := int(gz)
	var fx := gx-ix; var fz := gz-iz
	var a := _height_grid[iz*73+ix]; var b := _height_grid[iz*73+ix+1]
	var c := _height_grid[(iz+1)*73+ix]; var d := _height_grid[(iz+1)*73+ix+1]
	return a+(b-a)*fx+(c-a)*fz if fx+fz <= 1.0 else d+(c-d)*(1.0-fx)+(b-d)*(1.0-fz)

func _density(x: float,z: float) -> float:
	if z < 98.0 or z > 244.0 or absf(x)>84.0: return 0.0
	var road: float = _field._road_weight(x,z)
	if road > .78: return 0.0
	# Keep canvas floors and the immediate gateway/working areas clear.
	for centre: Vector2 in [Vector2(-77,198),Vector2(-65,205),Vector2(-33,224),Vector2(-33,240),Vector2(33,240),Vector2(33,205),Vector2(65,225),Vector2(77,202)]:
		if absf(x-centre.x)<4.6 and absf(z-centre.y)<4.0: return 0.0
	var patch := .5+.5*sin(x*.27+sin(z*.13))*sin(z*.22-x*.09)
	var density := smoothstep(.16,.76,patch)*(.92-road*.87)
	for centre: Vector2 in _field.BURN_CENTERS:
		var radius := Vector2((x-centre.x)/15.0,(z-centre.y)/9.0).length()
		density *= smoothstep(.38,.93,radius)
	return density

func _build_tile(tx: int,tz: int,tuft: Mesh,stone: Mesh,stone_material: Material) -> void:
	var grass_transforms: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	var stone_transforms: Array[Transform3D] = []
	var stone_colors: Array[Color] = []
	var origin := Vector3(-90.0+tx*TILE,0,76.0+tz*TILE)
	for i in 1152:
		var x := origin.x+_rng.randf()*TILE; var z := origin.z+_rng.randf()*TILE
		if z>=248 or _rng.randf()>_density(x,z): continue
		var h := _rng.randf_range(.23,.49)
		var basis := Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3(h*1.18,h,h*1.18))
		grass_transforms.append(Transform3D(basis,Vector3(x,_surface_y(x,z)-.024,z)-origin))
		var dry := _rng.randf()
		var color := Color(.22,.34,.075).lerp(Color(.38,.37,.15),dry*.76)
		grass_colors.append(color*Color(_rng.randf_range(.86,1.13),_rng.randf_range(.92,1.09),1))
	for i in 80:
		var x := origin.x+_rng.randf()*TILE; var z := origin.z+_rng.randf()*TILE
		if z<101 or z>242 or absf(x)>83: continue
		var size := _rng.randf_range(.045,.16)
		var basis := Basis.from_euler(Vector3(_rng.randf()*.3,_rng.randf()*TAU,_rng.randf()*.25)).scaled(Vector3(size,size*.62,size*.8))
		stone_transforms.append(Transform3D(basis,Vector3(x,_surface_y(x,z)+size*.08,z)-origin))
		stone_colors.append(Color(.16,.12,.08).lerp(Color(.30,.29,.24),_rng.randf()))
	if not grass_transforms.is_empty():
		_add_batch("Grass",origin,tuft,_material,grass_transforms,grass_colors,46.0)
		_stats.grass_batches += 1; _stats.tufts += grass_transforms.size()
	if not stone_transforms.is_empty():
		_add_batch("Stones",origin,stone,stone_material,stone_transforms,stone_colors,32.0)
		_stats.stone_batches += 1; _stats.stones += stone_transforms.size()

func _add_batch(prefix: String,origin: Vector3,mesh: Mesh,material: Material,transforms: Array[Transform3D],colors: Array[Color],distance_end: float) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D; multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh; multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i]); multi.set_instance_color(i,colors[i])
		multi.set_instance_custom_data(i,Color(float(i)/float(transforms.size()),0,0,1))
	var node := MultiMeshInstance3D.new()
	node.name = prefix+"_%d" % _batches.size(); node.multimesh = multi
	node.material_override = material; node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = distance_end+9.0
	node.extra_cull_margin = .6
	add_child(node); _batches.append(node)

func _make_tuft() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 14:
		var angle := float(blade)*TAU/8.0+.3*sin(blade*3.1)
		var direction := Vector3(cos(angle),0,sin(angle))
		var right := Vector3(-sin(angle),0,cos(angle))
		var root := direction*(.12+.13*sin(blade*1.7))
		var height := (.67+.32*absf(sin(blade*1.8+.7))) if blade<8 else (.28+.22*absf(sin(blade*2.3)))
		var curl := .30 if blade<8 else .72
		for segment in 2:
			var a := 0.0 if segment==0 else .55
			var b := .55 if segment==0 else 1.0
			var ca := root+Vector3.UP*(a*height)+direction*(a*a*curl)
			var cb := root+Vector3.UP*(b*height)+direction*(b*b*curl)
			var wa := .038*(1.0-a); var wb := .038*(1.0-b)
			var ridge_a := ca-direction*.023*(1.0-a)
			var ridge_b := cb-direction*.023*(1.0-b)
			var positions: Array
			var heights: Array
			if segment==0:
				positions = [ca-right*wa,ridge_a,ridge_b,ca-right*wa,ridge_b,cb-right*wb,ridge_a,ca+right*wa,cb+right*wb,ridge_a,cb+right*wb,ridge_b]
				heights = [a,a,b,a,b,b,a,a,b,a,b,b]
			else:
				positions = [ca-right*wa,ridge_a,cb,ridge_a,ca+right*wa,cb]
				heights = [a,a,b,a,a,b]
			for j in positions.size():
				st.set_uv(Vector2(.5,heights[j]))
				st.set_color(Color.WHITE if blade<8 else Color(.79,.86,.69))
				st.add_vertex(positions[j])
	st.generate_normals()
	return st.commit()

func _process(delta: float) -> void:
	_clock += delta; _accum += delta
	_material.set_shader_parameter("wind_time",_clock)
	_update_actor()
	if _accum < .1: return
	_update_lod()
	var elapsed := _accum; _accum = 0.0
	var had_pixels := not _active.is_empty()
	_decay(elapsed)
	var player = _scene.get("_player")
	if is_instance_valid(player) and player is CharacterBody3D and player.is_on_floor() and not bool(_scene.get("preview_dead")):
		var local: Vector3 = _field.to_local(player.global_position)
		if local.x>-89 and local.x<89 and local.z>77 and local.z<251 and absf(local.y-_surface_y(local.x,local.z))<.7:
			var direction := Vector2(0,1)
			if _last_position.is_finite():
				var travel := local-_last_position
				if travel.length()>.02 and travel.length()<2: direction = Vector2(travel.x,travel.z).normalized()
			_stamp(local,direction)
			_last_position = local
	if had_pixels or not _active.is_empty(): _texture.update(_image)
	_stats.active_pixels = _active.size(); _stats.updates += 1

func _update_actor() -> void:
	var player = _scene.get("_player")
	if not is_instance_valid(player) or bool(_scene.get("preview_dead")):
		_material.set_shader_parameter("actor_position",Vector3(0,10000,0))
		return
	_material.set_shader_parameter("actor_position",player.global_position)
	var rig = player.get("_pose_skeleton")
	if rig != _rig:
		_rig = rig as Skeleton3D; _leg_bones.clear()
		if is_instance_valid(_rig):
			for key in ["foot_l","shin_l","foot_r","shin_r"]: _leg_bones.append(_rig.find_bone(key))
	var params := ["left_foot","left_knee","right_foot","right_knee"]
	for i in 4:
		var point: Vector3 = player.global_position+Vector3(-.16 if i<2 else .16,.1 if i%2==0 else .6,0)
		if is_instance_valid(_rig) and _leg_bones.size()==4 and _leg_bones[i]>=0:
			point = _rig.to_global(_rig.get_bone_global_pose(_leg_bones[i]).origin)
		_material.set_shader_parameter(params[i],point)

func _update_lod() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	var submitted := 0
	for batch in _batches:
		var centre := batch.global_position+Vector3(6,0,6)
		var distance := Vector2(camera.global_position.x-centre.x,camera.global_position.z-centre.z).length()
		var count := batch.multimesh.instance_count
		if batch.name.begins_with("Grass") and distance>33.0: count = int(ceil(float(count)*.25))
		if distance > (55.0 if batch.name.begins_with("Grass") else 41.0): count = 0
		batch.multimesh.visible_instance_count = count
		submitted += count
	_stats["submitted_instances"] = submitted
	_stats["leg_bones_bound"] = _leg_bones.size()==4 and not _leg_bones.has(-1)

func _stamp(local: Vector3,direction: Vector2) -> void:
	var px := (local.x+90.0)/180.0*MAP_SIZE-.5
	var py := (local.z-76.0)/176.0*MAP_SIZE-.5
	for y in range(maxi(0,int(py)-3),mini(MAP_SIZE,int(py)+4)):
		for x in range(maxi(0,int(px)-3),mini(MAP_SIZE,int(px)+4)):
			var radius := Vector2((float(x)-px)*180.0/MAP_SIZE,(float(y)-py)*176.0/MAP_SIZE).length()
			var strength := 1.0-smoothstep(.22,.72,radius)
			if strength <= .01: continue
			var key := y*MAP_SIZE+x
			if not _active.has(key) and _active.size()>=MAX_ACTIVE_PIXELS: continue
			var old: Color = _image.get_pixel(x,y)
			var value := Color(maxf(strength,old.r),direction.x*.5+.5,direction.y*.5+.5,1)
			_image.set_pixel(x,y,value); _active[key] = value
	_stats.stamps += 1

func _decay(delta: float) -> void:
	for key in _active.keys():
		var value: Color = _active[key]
		value.r = maxf(0,value.r-delta/RECOVERY_SECONDS)
		var x := int(key)%MAP_SIZE; var y := int(key)/MAP_SIZE
		_image.set_pixel(x,y,value)
		if value.r <= .001: _active.erase(key)
		else: _active[key] = value
	# _process uploads even when the last active pixel was just cleared.

func pressure_at(local: Vector3) -> float:
	var x := clampi(int((local.x+90.0)/180.0*MAP_SIZE),0,MAP_SIZE-1)
	var y := clampi(int((local.z-76.0)/176.0*MAP_SIZE),0,MAP_SIZE-1)
	return _image.get_pixel(x,y).r

func get_stats() -> Dictionary:
	return _stats.duplicate(true)
