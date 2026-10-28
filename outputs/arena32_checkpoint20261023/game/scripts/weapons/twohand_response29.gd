extends RefCounted
## Optional polygon response. Weapon mass, damage, reachable grip and self/world
## collision remain owned by the ordinary melee implementation.
var enabled:=true
var visual_enabled:=true
const SPEED_SCALE:=1.20
const ACCEL_SCALE:=1.25
var _visual_modes:Dictionary={}
var _originals:Dictionary={}
var visuals_changed:=0

func limits(id:String,speed:float,acceleration:float)->Vector2:
	if enabled and id in ["axe","sledge"]:return Vector2(speed*SPEED_SCALE,acceleration*ACCEL_SCALE)
	return Vector2(speed,acceleration)

func motion_rate(id:String,rate:float)->float:
	return rate*SPEED_SCALE if enabled and id in ["axe","sledge"] else rate

func apply_visuals(host:Node)->void:
	var model:Node3D=host.get("_sword")
	if not is_instance_valid(model):return
	var id:=model.get_instance_id()
	if _visual_modes.has(id) and bool(_visual_modes[id])==visual_enabled:return
	_visual_modes[id]=visual_enabled
	for child:Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=child as MeshInstance3D
		var material:=mesh.material_override as StandardMaterial3D
		if material==null:continue
		var mesh_id:=mesh.get_instance_id()
		if not _originals.has(mesh_id):_originals[mesh_id]=material
		var original:StandardMaterial3D=_originals[mesh_id]
		if not visual_enabled:
			mesh.material_override=original
			continue
		if original.metallic<.5:continue
		var softened:StandardMaterial3D=original.duplicate()
		softened.roughness=maxf(original.roughness,.65)
		softened.metallic_specular=minf(original.metallic_specular,.35)
		# Contact classification must retain authored edge semantics after this
		# purely visual material duplication; the profile also accepts this tag.
		if original==host.get("_mat_edge") or bool(original.get_meta("combat_sharp29",false)):
			softened.set_meta("combat_sharp29",true)
		softened.set_meta("lab_visual_source29",original.get_instance_id())
		mesh.material_override=softened
		visuals_changed+=1

func status()->Dictionary:
	return {"enabled":enabled,"speed_scale":SPEED_SCALE,"acceleration_scale":ACCEL_SCALE,"visual_enabled":visual_enabled,"visuals_changed":visuals_changed}
