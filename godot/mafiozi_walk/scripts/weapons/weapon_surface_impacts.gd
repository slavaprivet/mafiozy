extends RefCounted
## Original Walk surface effects; cosmetic only, never damage/ownership authority.
## Source: weapon_effects.mjs spawnImpact/markImpact/update, pinned exporter.
const Geometry = preload("res://scripts/weapons/weapon_projectiles.gd")
const DATA := "res://data/weapons/surface_effect_meshes.json"
const DATA_SHA := "b968eb74064b3028cdcdbce0336ac90b174e5c2c98f9d2417905a1da0dd9a0c1"
const SOURCE_SHA := "4dfa7adf47309b89dd1b87bb0776abd1b2385c15c24256b749b7c71dfa9ff7ec"
const MARK_CAP := 72
const IMPACT_CAP := 48
var _root: Node3D
var _owner: WeakRef
var _marks: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _mark_cursor := 0
var _impact_cursor := 0
var _mark_count := 0
var _impact_count := 0
var _total_marks := 0
var _total_impacts := 0
var _ready := false

func configure(scene: Node3D) -> bool:
	if _ready or not is_instance_valid(scene) or not scene.is_inside_tree(): return false
	if FileAccess.get_sha256(DATA)!=DATA_SHA: return false
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not data is Dictionary or data.get("source_sha256")!=SOURCE_SHA: return false
	var builder:=Geometry.new(); var meshes: Dictionary={}
	for id: String in data.meshes: meshes[id]=builder._mesh(data.meshes[id])
	_owner=weakref(scene); _root=Node3D.new(); _root.name="WalkSurfaceEffects"; scene.add_child(_root); _root.top_level=true
	for i: int in MARK_CAP:
		var mark: MeshInstance3D=builder._node(data.mark,meshes); _root.add_child(mark)
		_marks.append({"node":mark,"edge":mark.get_child(0),"center":mark.get_child(1),"cracks":mark.get_child(2),"active":false,"life":0.0,"parent":null,"local":Transform3D.IDENTITY,"last_parent":Transform3D.IDENTITY,"glass":false})
	for i: int in IMPACT_CAP:
		var impact: MeshInstance3D=builder._node(data.impact,meshes); _root.add_child(impact)
		# The original hides only the parent's material, leaving its chips/dust.
		impact.mesh=null
		_impacts.append({"node":impact,"chips":impact.get_children().slice(0,5),"dust":impact.get_child(5),"active":false,"life":0.0,"max_life":0.0,"surface":"masonry","seed":0.0})
	_ready=true
	return true

static func classify(node: Node) -> String:
	var tag:=""; var current: Node=node
	while is_instance_valid(current) and tag.is_empty():
		tag=str(current.get_meta("impactSurface","")).to_lower()
		if tag.is_empty(): tag=str(current.get_meta("surfaceType","")).to_lower()
		current=current.get_parent()
	var name: String=tag if not tag.is_empty() else str(node.name).to_lower()
	for pair: Array in [["glass",["glass","window"]],["metal",["metal","steel","iron","car_body"]],["wood",["wood","timber","plank"]],["soft",["soft","cloth","fabric","skin","flesh"]]]:
		for token: String in pair[1]:
			if name.contains(token): return pair[0]
	if not tag.is_empty():
		for token: String in ["masonry","stone","brick","concrete"]:
			if tag.contains(token): return "masonry"
	if node is MeshInstance3D:
		var material: Material=node.get_active_material(0) if node.mesh!=null and node.mesh.get_surface_count()>0 else null
		if material is BaseMaterial3D and material.metallic>.55: return "metal"
	return "masonry"

static func _opacity(node: MeshInstance3D, value: float) -> void:
	var material: StandardMaterial3D=node.material_override; var color:=material.albedo_color; color.a=value; material.albedo_color=color
static func _color(node: MeshInstance3D, value: String) -> void:
	var material: StandardMaterial3D=node.material_override; var color:=Color(value); color.a=material.albedo_color.a; material.albedo_color=color
func _live() -> bool:
	return _ready and is_instance_valid(_root) and _owner!=null and is_instance_valid(_owner.get_ref()) and not _root.is_queued_for_deletion() and _root.is_inside_tree() and not _owner.get_ref().is_queued_for_deletion() and _owner.get_ref().is_inside_tree()

func hit(receipt: Dictionary) -> bool:
	if not _live(): return false
	var collider: Variant=receipt.get("collider"); var point: Variant=receipt.get("point"); var normal: Variant=receipt.get("normal")
	if not is_instance_valid(collider) or not collider is Node3D or not collider.is_inside_tree() or collider.is_queued_for_deletion(): return false
	if not _owner.get_ref().is_ancestor_of(collider): return false
	if not point is Vector3 or not point.is_finite() or not normal is Vector3 or not normal.is_finite() or normal.length_squared()<.000001: return false
	if absf(collider.global_basis.determinant())<1e-8: return false
	normal=normal.normalized()
	var surface:=classify(collider)
	var explosive: bool=receipt.get("explosive",false)
	_mark(collider,point,normal,surface,receipt.get("projectile_kind","")=="pellet",explosive)
	if not explosive: _impact(point,normal,surface)
	return true

func _mark(collider: Node3D, point: Vector3, normal: Vector3, surface: String, pellet: bool, explosive: bool = false) -> void:
	var entry: Dictionary=_marks[_mark_cursor%MARK_CAP]; _mark_cursor+=1
	if not entry.active: _mark_count+=1
	entry.active=true; entry.life=5.0; entry.glass=surface=="glass"
	var factor:=1.65 if explosive else .38 if pellet else .58 if entry.glass else .72
	var orientation:=Quaternion(Vector3.BACK,normal)*Quaternion(Vector3.BACK,fmod(_total_marks*2.399963229728653,6.283)-3.1415)
	var world:=Transform3D(Basis(orientation).scaled(Vector3.ONE*factor),point+normal*.004)
	entry.node.global_transform=world; entry.node.visible=true
	entry.parent=weakref(collider); entry.local=collider.global_transform.affine_inverse()*world; entry.last_parent=collider.global_transform
	_color(entry.node,"29383c" if entry.glass else "100d0b" if explosive else "171411"); _opacity(entry.node,.30 if entry.glass else .84)
	_color(entry.edge,"8c8f91" if surface=="metal" else "9d7951" if surface=="wood" else "99bac2" if entry.glass else "928571")
	_opacity(entry.edge,.7); _opacity(entry.center,.22 if entry.glass else .9); _opacity(entry.cracks,.65); entry.cracks.visible=entry.glass and not explosive
	_total_marks+=1

func _impact(point: Vector3, normal: Vector3, surface: String) -> void:
	var entry: Dictionary=_impacts[_impact_cursor%IMPACT_CAP]; _impact_cursor+=1
	if not entry.active: _impact_count+=1
	entry.active=true; entry.surface=surface; entry.seed=_total_impacts*1.618
	entry.max_life=.22 if surface=="metal" else .40 if surface=="glass" else .46; entry.life=entry.max_life
	entry.node.global_transform=Transform3D(Basis(Quaternion(Vector3.BACK,normal)),point); entry.node.visible=true
	var color:="ffd789" if surface=="metal" else "8b6a43" if surface=="wood" else "9db4bb" if surface=="glass" else "aaa18f"
	entry.dust.visible=surface in ["masonry","wood"]; entry.dust.scale=Vector3.ONE*.3; entry.dust.position=Vector3(0,0,.025); _color(entry.dust,color); _opacity(entry.dust,0)
	for chip: MeshInstance3D in entry.chips:
		_color(chip,color); chip.visible=surface!="soft"; chip.position=Vector3.ZERO
		var material: StandardMaterial3D=chip.material_override
		material.roughness=.12 if surface=="glass" else .25 if surface=="metal" else .85
		material.metallic=.65 if surface=="metal" else .25 if surface=="glass" else 0.0
		material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD if surface=="metal" else BaseMaterial3D.BLEND_MODE_MIX
		material.emission_enabled=surface=="metal"; material.emission=Color(color)*.9; material.emission_energy_multiplier=1
		_opacity(chip,1 if surface=="metal" else .8)
	_total_impacts+=1

func advance(delta: float) -> void:
	if not _live() or not is_finite(delta) or delta<0 or (_mark_count==0 and _impact_count==0): return
	if _mark_count>0:
		for entry: Dictionary in _marks:
			if not entry.active: continue
			entry.life=maxf(0,entry.life-delta)
			var parent: Variant=entry.parent.get_ref() if entry.parent!=null else null
			if entry.life<=0 or not is_instance_valid(parent) or parent.is_queued_for_deletion() or not parent.is_inside_tree():
				entry.active=false; entry.node.visible=false; entry.parent=null; _mark_count-=1; continue
			if parent.global_transform!=entry.last_parent:
				entry.node.global_transform=parent.global_transform*entry.local; entry.last_parent=parent.global_transform
			if entry.life<.25:
				var alpha: float=entry.life/.25
				_opacity(entry.node,minf(.30 if entry.glass else .84,alpha)); _opacity(entry.edge,minf(.7,alpha)); _opacity(entry.center,minf(.22 if entry.glass else .9,alpha)); _opacity(entry.cracks,minf(.65,alpha))
	if _impact_count>0:
		for entry: Dictionary in _impacts:
			if not entry.active: continue
			entry.life-=delta
			if entry.life<=0: entry.active=false; entry.node.visible=false; _impact_count-=1; continue
			var p: float=entry.life/entry.max_life; var age:=1-p
			var metal: bool=entry.surface=="metal"; var glass: bool=entry.surface=="glass"; var wood: bool=entry.surface=="wood"
			entry.dust.scale=Vector3.ONE*(.3+age*3.5); entry.dust.position.z=.025+age*.1; _opacity(entry.dust,sin(age*PI)*.23)
			for n: int in entry.chips.size():
				var chip: MeshInstance3D=entry.chips[n]; var angle: float=n*2.399963+entry.seed; var travel:=age*(.32 if metal else .18)*(1+n*.16)
				chip.position=Vector3(cos(angle)*travel,sin(angle)*travel-age*age*.15,age*(.12+n*.025)); chip.rotation=Vector3(age*(n+2)*5,n+entry.seed,age*9)
				chip.scale=Vector3(.26 if metal else 1.5 if glass else .6 if wood else 1,3.4 if metal else 2.4 if wood else 1,.18 if glass else 1)
				_opacity(chip,p*(1 if metal else .8))
				if metal: chip.material_override.emission_energy_multiplier=p*2

func stats() -> Dictionary:
	return {"marks":_mark_count,"impacts":_impact_count,"total_marks":_total_marks,"total_impacts":_total_impacts,"mark_capacity":MARK_CAP,"impact_capacity":IMPACT_CAP}
func dispose() -> void:
	_ready=false; _owner=null; _marks.clear(); _impacts.clear(); _mark_count=0; _impact_count=0
	if is_instance_valid(_root): _root.hide(); _root.queue_free()
	_root=null
