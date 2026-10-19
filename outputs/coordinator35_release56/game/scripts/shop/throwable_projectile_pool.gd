extends Node3D
## Prewarmed low-polygon models. The safety lever/pin and bottle neck/liquid/
## wick make their end-over-end rotations legible at gameplay camera distance.
const CAPACITY := 8
var _slots: Array[Dictionary] = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _ready_for_use := false
var _acquires := 0

func configure(world: Node3D) -> bool:
	if _ready_for_use or not is_instance_valid(world) or not world.is_inside_tree(): return false
	world.add_child(self)
	_make_resources()
	for index in CAPACITY:
		var root:=Node3D.new(); root.name="Thrown%02d"%index; add_child(root)
		var grenade:=build_model(root,"grenade")
		var molotov:=build_model(root,"molotov")
		root.visible=false; grenade.visible=false; molotov.visible=false
		_slots.append({"root":root,"grenade":grenade,"molotov":molotov,"active":false})
	_ready_for_use=true
	return true

func _make_resources() -> void:
	_materials={
		"grenade":_mat(Color("485440"),.36),"metal":_mat(Color("8b8d81"),.25),
		"lever":_mat(Color("565e55"),.30),"glass":_mat(Color(.61,.44,.28,.56),.16),
		"liquid":_mat(Color("5f2118"),.22),"paper":_mat(Color("d4b995"),.92),
		"wick":_mat(Color("45382e"),.96),"flame":_mat(Color("ff9a38"),.18,true)
	}
	(_materials.glass as StandardMaterial3D).transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var shell:=SphereMesh.new(); shell.radius=.14; shell.height=.28; shell.radial_segments=12; shell.rings=6; _meshes.grenade=shell
	var band:=CylinderMesh.new(); band.top_radius=.143; band.bottom_radius=.143; band.height=.045; band.radial_segments=12; _meshes.band=band
	var cap:=CylinderMesh.new(); cap.top_radius=.065; cap.bottom_radius=.068; cap.height=.055; cap.radial_segments=10; _meshes.cap=cap
	var pin:=CylinderMesh.new(); pin.top_radius=.014; pin.bottom_radius=.014; pin.height=.11; pin.radial_segments=6; _meshes.pin=pin
	var bottle:=CylinderMesh.new(); bottle.top_radius=.091; bottle.bottom_radius=.108; bottle.height=.33; bottle.radial_segments=10; _meshes.bottle=bottle
	var liquid:=CylinderMesh.new(); liquid.top_radius=.092; liquid.bottom_radius=.109; liquid.height=.15; liquid.radial_segments=10; _meshes.liquid=liquid
	var neck:=CylinderMesh.new(); neck.top_radius=.044; neck.bottom_radius=.055; neck.height=.13; neck.radial_segments=10; _meshes.neck=neck
	var cork:=CylinderMesh.new(); cork.top_radius=.039; cork.bottom_radius=.045; cork.height=.055; cork.radial_segments=8; _meshes.cork=cork
	var wick:=CylinderMesh.new(); wick.top_radius=.016; wick.bottom_radius=.028; wick.height=.10; wick.radial_segments=6; _meshes.wick=wick
	var flame:=CylinderMesh.new(); flame.top_radius=.005; flame.bottom_radius=.043; flame.height=.13; flame.radial_segments=7; _meshes.flame=flame
	var lever:=BoxMesh.new(); lever.size=Vector3(.055,.035,.20); _meshes.lever=lever
	var label:=BoxMesh.new(); label.size=Vector3(.145,.083,.012); _meshes.label=label

func _mat(color: Color,roughness: float,glow: bool=false) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new(); material.albedo_color=color; material.roughness=roughness
	if glow: material.emission_enabled=true; material.emission=color; material.emission_energy_multiplier=1.8
	return material

func _part(parent: Node3D,mesh: Mesh,material: Material,offset: Vector3,rotation: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var part:=MeshInstance3D.new(); part.mesh=mesh; part.material_override=material
	part.position=offset; part.rotation=rotation
	part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(part)
	return part

func build_model(parent: Node3D,kind: String) -> Node3D:
	var root:=Node3D.new(); root.name="GrenadeModel" if kind=="grenade" else "MolotovModel"; parent.add_child(root)
	if kind=="grenade":
		_part(root,_meshes.grenade,_materials.grenade,Vector3.ZERO)
		_part(root,_meshes.band,_materials.metal,Vector3(0,-.015,0))
		_part(root,_meshes.cap,_materials.metal,Vector3(0,.145,0))
		_part(root,_meshes.lever,_materials.lever,Vector3(.108,.09,0))
		_part(root,_meshes.pin,_materials.metal,Vector3(-.083,.16,0),Vector3(0,0,PI*.5))
	else:
		_part(root,_meshes.bottle,_materials.glass,Vector3.ZERO)
		_part(root,_meshes.liquid,_materials.liquid,Vector3(0,-.085,0))
		_part(root,_meshes.neck,_materials.glass,Vector3(0,.22,0))
		_part(root,_meshes.cork,_materials.wick,Vector3(0,.30,0))
		_part(root,_meshes.label,_materials.paper,Vector3(0,.005,-.106))
		_part(root,_meshes.wick,_materials.wick,Vector3(0,.37,0))
		_part(root,_meshes.flame,_materials.flame,Vector3(0,.46,0))
	return root

func acquire(kind: String,at: Vector3) -> int:
	if not _ready_for_use or kind not in ["grenade","molotov"]: return -1
	for index in _slots.size():
		var slot: Dictionary=_slots[index]
		if slot.active: continue
		slot.active=true; slot.root.global_position=at; slot.root.rotation=Vector3.ZERO
		slot.grenade.visible=kind=="grenade"; slot.molotov.visible=kind=="molotov"
		slot.root.visible=true; _acquires+=1
		return index
	return -1

func visual(index: int) -> Node3D:
	return _slots[index].root if index>=0 and index<_slots.size() else null

func release(index: int) -> void:
	if index<0 or index>=_slots.size(): return
	var slot: Dictionary=_slots[index]; slot.active=false; slot.root.visible=false

func snapshot() -> Dictionary:
	var active:=0
	for slot: Dictionary in _slots:
		if slot.active: active+=1
	return {"ready":_ready_for_use,"capacity":CAPACITY,"active":active,"acquires":_acquires,"per_throw_node_allocations":0,"maximum_model_draws":CAPACITY*7}

func dispose() -> void:
	_ready_for_use=false; _slots.clear(); _meshes.clear(); _materials.clear()
	if is_inside_tree(): queue_free()
