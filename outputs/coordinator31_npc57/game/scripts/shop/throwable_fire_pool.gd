extends Node3D
## Six prewarmed Molotov fields. One billboard batch and one ground pool per
## field; shader time animates flames, smoke and embers without CPU particles.
const FireShader = preload("res://scripts/shop/throwable_fire.gdshader")
const CAPACITY := 6
const FLAMES := 24
const SMOKE := 10
const EMBERS := 12
const UPDATE_INTERVAL := 1.0 / 15.0
var _slots: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _quad: QuadMesh
var _ground: PlaneMesh
var _next_light := 0
var _ready_for_use := false
var _updates := 0

func configure(world: Node3D) -> bool:
	if _ready_for_use or not is_instance_valid(world) or not world.is_inside_tree(): return false
	world.add_child(self)
	_quad=QuadMesh.new(); _quad.size=Vector2.ONE
	_ground=PlaneMesh.new(); _ground.size=Vector2(4.9,4.9)
	for index in CAPACITY:
		var root:=Node3D.new(); root.name="FireField%02d"%index; add_child(root)
		var multimesh:=MultiMesh.new(); multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data=true; multimesh.mesh=_quad
		multimesh.instance_count=FLAMES+SMOKE+EMBERS
		multimesh.custom_aabb=AABB(Vector3(-4,-1,-4),Vector3(8,7,8))
		for particle in multimesh.instance_count:
			var seed: float=fposmod(float(particle+1)*.61803398875+float(index)*.137,1.0)
			var variant: float=fposmod(float(particle+1)*.41421356237+float(index)*.217,1.0)
			var kind:=0 if particle<FLAMES else 1 if particle<FLAMES+SMOKE else 2
			var radius: float=sqrt(variant)*2.20 if kind==0 else .55*variant if kind==1 else .18
			var angle: float=TAU*seed
			var height: float=.17 if kind==0 else .68+variant*.55 if kind==1 else .15
			multimesh.set_instance_transform(particle,Transform3D(Basis.IDENTITY,Vector3(cos(angle)*radius,height,sin(angle)*radius)))
			multimesh.set_instance_custom_data(particle,Color(seed,float(kind),variant,1.0))
		var material:=ShaderMaterial.new(); material.shader=FireShader
		var ground_material:=ShaderMaterial.new()
		ground_material.shader=preload("res://scripts/shop/throwable_scorch.gdshader")
		var flames:=MultiMeshInstance3D.new(); flames.multimesh=multimesh
		flames.material_override=material; flames.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flames)
		var scorch:=MeshInstance3D.new(); scorch.mesh=_ground; scorch.material_override=ground_material
		scorch.position.y=.018; scorch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(scorch)
		root.visible=false
		_slots.append({"root":root,"material":material,"ground_material":ground_material,"multimesh":multimesh,"active":false,"last_age":-1.0})
	for index in 2:
		var light:=OmniLight3D.new(); light.name="MolotovLight%02d"%index
		light.shadow_enabled=false; light.omni_range=5.0; light.light_color=Color("ff8137")
		light.light_energy=0.0; light.visible=false; add_child(light)
		_lights.append({"node":light,"slot":-1})
	_ready_for_use=true
	return true

func ignite(at: Vector3) -> int:
	if not _ready_for_use: return -1
	for index in _slots.size():
		var slot: Dictionary=_slots[index]
		if slot.active: continue
		slot.active=true; slot.last_age=-1.0; slot.root.global_position=at; slot.root.visible=true
		slot.multimesh.visible_instance_count=FLAMES+SMOKE+EMBERS
		update_field(index,0.0)
		var light: Dictionary=_lights[_next_light%_lights.size()]; _next_light+=1
		light.slot=index; light.node.global_position=at+Vector3.UP*.8
		light.node.visible=true; light.node.light_energy=2.6
		return index
	return -1

func update_field(index: int,age: float,camera_position: Vector3=Vector3.INF) -> void:
	if index<0 or index>=_slots.size(): return
	var slot: Dictionary=_slots[index]
	if not slot.active or age-slot.last_age<UPDATE_INTERVAL: return
	slot.last_age=age; slot.material.set_shader_parameter("age_seconds",age)
	slot.ground_material.set_shader_parameter("age_seconds",age); _updates+=1
	if camera_position.is_finite():
		var distance_sq: float=slot.root.global_position.distance_squared_to(camera_position)
		slot.multimesh.visible_instance_count=FLAMES+SMOKE+EMBERS if distance_sq<18.0*18.0 else FLAMES if distance_sq<34.0*34.0 else 8
	for light: Dictionary in _lights:
		if light.slot==index:
			light.node.light_energy=2.6*clampf((6.0-age)/.65,0.0,1.0)*(0.90+0.10*sin(age*17.0+float(index)))

func stop_field(index: int) -> void:
	if index<0 or index>=_slots.size(): return
	var slot: Dictionary=_slots[index]; slot.active=false; slot.root.visible=false
	for light: Dictionary in _lights:
		if light.slot==index: light.slot=-1; light.node.visible=false; light.node.light_energy=0.0

func snapshot() -> Dictionary:
	var active:=0
	for slot: Dictionary in _slots:
		if slot.active: active+=1
	return {"ready":_ready_for_use,"active":active,"capacity":CAPACITY,"maximum_quads":CAPACITY*(FLAMES+SMOKE+EMBERS),"maximum_draw_batches":CAPACITY*2,"dynamic_lights":2,"shadowed_lights":0,"per_impact_node_allocations":0,"shader_updates":_updates}

func dispose() -> void:
	for index in _slots.size(): stop_field(index)
	_ready_for_use=false; _slots.clear(); _lights.clear()
	if is_inside_tree(): queue_free()
