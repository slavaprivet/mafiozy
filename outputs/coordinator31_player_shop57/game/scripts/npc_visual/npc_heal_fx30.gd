extends Node3D
## Cosmetic only: consume a completed native hospital HP receipt, never sample HP
## changes or infer treatment from a pose/timer. No health/route/lifecycle writes.
const LIMIT30 := 12
const BURST30 := 4
const LIFETIME30 := 1.45
const POOL_NAME30 := "NpcHealFxPool30"
var _slots30: Array[Dictionary] = []
var _mesh30: ArrayMesh
var _material30: StandardMaterial3D
var _emitted30 := 0
var _spawned30 := 0
var _released30 := 0
var _peak30 := 0

static func confirmed30(health: RefCounted, event_id: String) -> bool:
	if not Thread.is_main_thread() or not is_instance_valid(health) or not health.has_method("_current") or not health.get("_ready"): return false
	var binding: Dictionary = health.get("_binding")
	var current: Dictionary = health._current(binding)
	var row: Dictionary = health.get("_row")
	var token: Dictionary = health.get("_token")
	var adapter: RefCounted = health.get("_adapter")
	if current.is_empty() or not is_same(current.get("row"), row) or not is_instance_valid(adapter): return false
	var receipt: Dictionary = adapter.receipt(event_id)
	if not receipt.get("ok",false) or not receipt.get("applied",false) or receipt != health.get("last_result"): return false
	if receipt.get("binding") != binding or int(receipt.get("revision",-1)) != int(adapter.get("_revision")): return false
	if receipt.get("reason","") not in ["hospital51_native_walk_in_treatment", "hospital_walk_in_treatment"]: return false
	var hospital: Dictionary = receipt.get("hospital",{})
	var before: float = float(hospital.get("hp_before",NAN))
	var after: float = float(hospital.get("hp_after",NAN))
	if not is_finite(before) or not is_finite(after) or before <= 0.0 or after <= before or after != float(row.get("hp",0)) or after > float(row.get("max_hp",0)): return false
	if row.get("dead",false) or row.get("_medicalDowned",false) or row.get("alive",true) == false: return false
	if row.get("source_id") != token.get("source_id") or row.get("life_generation") != token.get("life_generation"): return false
	var revision: int = int(receipt.revision)
	if int(health.get_meta("heal_fx_revision30",-1)) >= revision: return false
	var body: CharacterBody3D = token.get("body")
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	var scene: Node = body.get_tree().current_scene
	if not is_instance_valid(scene) or not scene is Node3D: return false
	var pool: Node = scene.get_node_or_null(NodePath(POOL_NAME30))
	if pool == null:
		pool = load("res://scripts/npc_visual/npc_heal_fx30.gd").new()
		pool.name = POOL_NAME30; scene.add_child(pool)
	if pool.get_script() != load("res://scripts/npc_visual/npc_heal_fx30.gd"): return false
	health.set_meta("heal_fx_revision30",revision)
	pool._emit30(health, body, after, int(token.life_generation))
	return true

func _ready() -> void:
	set_process(false)

func _build30() -> void:
	if _mesh30 != null: return
	var outline := PackedVector2Array([Vector2(-.16,-.5),Vector2(.16,-.5),Vector2(.16,-.16),Vector2(.5,-.16),Vector2(.5,.16),Vector2(.16,.16),Vector2(.16,.5),Vector2(-.16,.5),Vector2(-.16,.16),Vector2(-.5,.16),Vector2(-.5,-.16),Vector2(-.16,-.16)])
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	for point: Vector2 in outline: vertices.append(Vector3(point.x,point.y,0)); normals.append(Vector3.FORWARD)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline)
	_mesh30 = ArrayMesh.new(); _mesh30.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_material30 = StandardMaterial3D.new()
	_material30.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material30.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material30.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material30.billboard_keep_scale = true
	_material30.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material30.albedo_color = Color(.98,.56,.73,.72)
	_mesh30.surface_set_material(0,_material30)

func _emit30(health: RefCounted, body: CharacterBody3D, hp_after: float, generation: int) -> void:
	_build30(); _emitted30 += 1
	var offsets: Array[Vector3] = [Vector3(-.32,1.05,0),Vector3(.30,.98,.03),Vector3(-.13,1.36,-.02),Vector3(.20,1.24,.02)]
	var right := Vector3.RIGHT; var toward := Vector3.FORWARD
	var camera: Camera3D = body.get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		right = camera.global_basis.x; toward = camera.global_position-body.global_position; toward.y = 0; toward = toward.normalized()
	for number: int in BURST30:
		var chosen := -1
		for index: int in _slots30.size():
			if not _slots30[index].active: chosen = index; break
		if chosen < 0:
			if _slots30.size() >= LIMIT30: break
			var node := MeshInstance3D.new(); node.name = "HealCross30_"+str(_slots30.size())
			node.mesh = _mesh30; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(node)
			_slots30.append({"node":node,"active":false}); chosen = _slots30.size()-1
		var slot: Dictionary = _slots30[chosen]
		slot.active = true; slot.age = -float(number)*.12; slot.health = weakref(health); slot.body = weakref(body)
		slot.hp = hp_after; slot.generation = generation; slot.offset = right*offsets[number].x+Vector3.UP*offsets[number].y+toward*(.38+offsets[number].z); slot.origin = body.global_position
		slot.node.scale = Vector3.ONE*(.16+float(number%2)*.025); slot.node.visible = false
		_spawned30 += 1
	_peak30 = maxi(_peak30,_active30()); set_process(_active30()>0)

func _valid30(slot: Dictionary) -> bool:
	var health: RefCounted = slot.health.get_ref()
	var body: CharacterBody3D = slot.body.get_ref()
	if not is_instance_valid(health) or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or health.get("_ready") != true: return false
	var token: Dictionary = health.get("_token"); var row: Dictionary = health.get("_row")
	return token.get("body") == body and token.get("life_generation") == slot.generation and row.get("life_generation") == slot.generation and not row.get("dead",false) and not row.get("_medicalDowned",false) and float(row.get("hp",0)) >= float(slot.hp)

func _process(delta: float) -> void:
	for slot: Dictionary in _slots30:
		if not slot.active: continue
		slot.age += maxf(0.0,delta)
		if slot.age > LIFETIME30 or not _valid30(slot):
			slot.active = false; slot.node.visible = false; slot.erase("health"); slot.erase("body"); _released30 += 1; continue
		if slot.age < 0.0: continue
		var alpha: float = minf(slot.age/.10,1.0)*clampf((LIFETIME30-slot.age)/.50,0.0,1.0)
		slot.node.visible = true; slot.node.transparency = 1.0-alpha
		# Follow the still-current body while rising so a walking healed NPC does
		# not overtake and occlude the crosses immediately on the hospital exit.
		slot.origin = slot.body.get_ref().global_position
		slot.node.global_position = slot.origin+slot.offset+Vector3(0,slot.age*.52,0)
	set_process(_active30()>0)

func _active30() -> int:
	var count := 0
	for slot: Dictionary in _slots30:
		if slot.active: count += 1
	return count

func snapshot30() -> Dictionary:
	return {"events":_emitted30,"spawned":_spawned30,"released":_released30,"active":_active30(),"allocated":_slots30.size(),"peak":_peak30,"limit":LIMIT30,"processing":is_processing(),"mesh_vertices":12,"mesh_triangles":10,"colliders":0}
