extends Node3D
## Fire3: six-step bounded volume lobes; same total88 particles and same pool.
## Cosmetic only. No collision, damage, receipts, screen shake or actor mutation.
## All nodes/materials/meshes/instance buffers are prewarmed before first blast.
const PlumeShader = preload("blast45_plume.gdshader")
const WaveShader = preload("blast45_wave.gdshader")
const CAPACITY := 6
const FLASH_CAPACITY := 2
const FIRE_PARTS := 10
const SMOKE_PARTS := 18
const DUST_PARTS := 10
const SPARK_PARTS := 48
const CORE_PARTS := 2
const LIFETIME := 4.8
const NOISE_SIZE := 128
var _slots: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _quad: QuadMesh
var _sphere: SphereMesh
var _noise: ImageTexture
var _fx_ready := false
var _disposed := false
var _cursor := 0
var _active := 0
var _evicted := 0
var _max_advance_usec := 0
var _prewarm_usec := 0

func configure(world: Node3D) -> Dictionary:
	if _fx_ready or _disposed or not Thread.is_main_thread() or not is_instance_valid(world) or not world.is_inside_tree() or get_parent()!=null: return {"ok":false,"reason":"fx_lifetime"}
	var started: int=Time.get_ticks_usec()
	name="C4BlastFX45"; world.add_child(self); top_level=true
	_quad=QuadMesh.new(); _quad.size=Vector2(1,1)
	_sphere=SphereMesh.new(); _sphere.radius=1; _sphere.height=2; _sphere.radial_segments=24; _sphere.rings=12
	_noise=_make_noise()
	for slot: int in CAPACITY:
		var node:=Node3D.new(); node.name="Burst%02d"%slot; add_child(node); node.visible=false
		var material:=ShaderMaterial.new(); material.shader=PlumeShader; material.set_shader_parameter("plume_noise",_noise)
		var smoke: MultiMeshInstance3D=_group(node,material,1,SMOKE_PARTS,slot)
		var dust: MultiMeshInstance3D=_group(node,material,2,DUST_PARTS,slot)
		var heat: MultiMeshInstance3D=_group(node,material,0,FIRE_PARTS+SPARK_PARTS+CORE_PARTS,slot)
		var wave_material:=ShaderMaterial.new(); wave_material.shader=WaveShader
		var wave:=MeshInstance3D.new(); wave.mesh=_sphere; wave.material_override=wave_material; wave.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; wave.custom_aabb=AABB(Vector3.ONE*-6,Vector3.ONE*12); node.add_child(wave)
		_slots.append({"node":node,"plume":material,"wave":wave_material,"meshes":[smoke,dust,heat,wave],"age":LIFETIME,"active":false})
	for i: int in FLASH_CAPACITY:
		var light:=OmniLight3D.new(); light.name="SharedBlastFlash%02d"%i; light.shadow_enabled=false; light.omni_range=7.5; light.light_color=Color("ffb969"); light.light_energy=0; light.visible=false; add_child(light)
		_flashes.append({"node":light,"age":1.0})
	_fx_ready=true; set_process(false); _prewarm_usec=Time.get_ticks_usec()-started
	return {"ok":true,"capacity":CAPACITY,"flash_capacity":FLASH_CAPACITY,"prewarm_usec":_prewarm_usec,"damage_authority":false}

func _make_noise() -> ImageTexture:
	var noise:=FastNoiseLite.new(); noise.seed=450031; noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH; noise.frequency=.041; noise.fractal_octaves=3
	var image:=Image.create(NOISE_SIZE,NOISE_SIZE,false,Image.FORMAT_RGBA8)
	for y: int in NOISE_SIZE:
		var v: float=float(y)/NOISE_SIZE
		for x: int in NOISE_SIZE:
			var u: float=float(x)/NOISE_SIZE
			# Periodic blend avoids scrolling texture seams; generated once, no files.
			var top: float=lerpf(noise.get_noise_2d(x,y),noise.get_noise_2d(x-NOISE_SIZE,y),u)
			var bottom: float=lerpf(noise.get_noise_2d(x,y-NOISE_SIZE),noise.get_noise_2d(x-NOISE_SIZE,y-NOISE_SIZE),u)
			var value: float=clampf(lerpf(top,bottom,v)*.72+.5,0,1)
			image.set_pixel(x,y,Color(value,value,value,1))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _group(parent: Node3D,material: ShaderMaterial,kind: int,count: int,slot: int) -> MultiMeshInstance3D:
	var mesh:=MultiMesh.new(); mesh.transform_format=MultiMesh.TRANSFORM_3D; mesh.use_custom_data=true; mesh.mesh=_quad; mesh.instance_count=count
	mesh.custom_aabb=AABB(Vector3(-15,-9,-15),Vector3(30,30,30))
	for i: int in count:
		var type: int=kind
		if kind==0 and i>=FIRE_PARTS: type=3 if i<FIRE_PARTS+SPARK_PARTS else 4
		var seed: float=fposmod((i+1)*.61803398875+slot*.137,1.0)
		var variant: float=fposmod((i+1)*.41421356237+slot*.219,1.0)
		var delay: float=variant*.075 if type in [0,3] else .11+variant*.16 if type==1 else variant*.04
		mesh.set_instance_transform(i,Transform3D.IDENTITY)
		mesh.set_instance_custom_data(i,Color(seed,float(type),delay,variant))
	var node:=MultiMeshInstance3D.new(); node.multimesh=mesh; node.material_override=material; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(node)
	return node

func emit_blast(at: Vector3,normal: Vector3=Vector3.UP,power: float=960.0,radius: float=3.2) -> Dictionary:
	if not _fx_ready or _disposed or not is_inside_tree() or is_queued_for_deletion() or not Thread.is_main_thread() or not at.is_finite() or not normal.is_finite() or normal.length_squared()<.001 or not is_finite(power) or power<=0 or not is_finite(radius) or radius<=0: return {"ok":false,"reason":"fx_input"}
	var index: int=_cursor%CAPACITY
	var row: Dictionary=_slots[index]
	if row.active: _evicted+=1
	else: _active+=1
	_cursor+=1; row.age=0.0; row.active=true; row.node.global_position=at; row.node.visible=true
	for mesh: GeometryInstance3D in row.meshes: mesh.visible=true
	var scale: float=clampf(sqrt(power/960.0)*radius/3.2,.65,1.25)
	row.plume.set_shader_parameter("burst_age",0.0); row.plume.set_shader_parameter("burst_scale",scale); row.plume.set_shader_parameter("burst_seed",fposmod(_cursor*.381966,1.0)); row.plume.set_shader_parameter("blast_normal",normal.normalized())
	row.wave.set_shader_parameter("burst_age",0.0); row.wave.set_shader_parameter("burst_scale",scale)
	var flash: Dictionary=_flashes[(_cursor-1)%FLASH_CAPACITY]
	flash.age=0.0; flash.node.global_position=at+normal.normalized()*.18; flash.node.visible=true; flash.node.light_energy=7.5
	set_process(true)
	return {"ok":true,"slot":index,"serial":_cursor,"cosmetic_only":true}

func _process(delta: float) -> void:
	if not _fx_ready or _disposed or not is_finite(delta) or delta<0: return
	var started: int=Time.get_ticks_usec()
	# Real elapsed delta: even a long frame retires old FX instead of extending it.
	for row: Dictionary in _slots:
		if not row.active: continue
		row.age+=delta
		if row.age>=LIFETIME: row.active=false; row.node.visible=false; _active-=1; continue
		row.plume.set_shader_parameter("burst_age",row.age); row.wave.set_shader_parameter("burst_age",row.age)
		row.meshes[0].visible=row.age<4.6
		row.meshes[1].visible=row.age<2.35
		row.meshes[2].visible=row.age<2.0
		row.meshes[3].visible=row.age<.48
	for row: Dictionary in _flashes:
		if row.age>=.24: continue
		row.age+=delta
		row.node.light_energy=7.5*pow(maxf(0.0,1.0-row.age/.24),2.0)
		if row.age>=.24: row.node.visible=false
	_max_advance_usec=maxi(_max_advance_usec,Time.get_ticks_usec()-started)
	if _active==0: set_process(false)

func snapshot() -> Dictionary:
	return {"ready":_fx_ready and not _disposed,"capacity":CAPACITY,"active":_active,"total":_cursor,"evicted":_evicted,"flash_capacity":FLASH_CAPACITY,"maximum_billboards":CAPACITY*(FIRE_PARTS+SMOKE_PARTS+DUST_PARTS+SPARK_PARTS+CORE_PARTS),"maximum_draw_batches":CAPACITY*4,"maximum_lifetime_seconds":LIFETIME,"prewarm_usec":_prewarm_usec,"max_cpu_advance_usec":_max_advance_usec,"noise_texture_count":int(_noise!=null),"pooled_nodes":CAPACITY*5+FLASH_CAPACITY,"per_blast_node_or_mesh_allocations":0,"cosmetic_only":true,"gpu_and_loaded_scene_performance":"NOT_RUN"}

func dispose() -> void:
	if _disposed: return
	_disposed=true; _fx_ready=false; set_process(false); visible=false; _active=0
	for flash: Dictionary in _flashes: flash.node.light_energy=0; flash.node.visible=false
	_slots.clear(); _flashes.clear(); _noise=null; _quad=null; _sphere=null
	if is_inside_tree(): queue_free()
