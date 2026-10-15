extends RefCounted
## One scene-owned snapshot adapter. No body ownership, movement or door claims.
const Passage31 = preload("res://scripts/navigation/npc_passage31.gd")
const Core = preload("res://scripts/navigation/npc_local_avoidance29.gd")
const META := "npc_local_avoidance29"
var core:RefCounted=Core.new()
var diagnostic_extra58:CharacterBody3D
class Entry extends RefCounted:
	var body:WeakRef
	var shape:WeakRef
	var source_id:String
	var generation:int
	var input:Core.FrameInput
	var seen:int
var _keys:Dictionary={}
var _entries:Dictionary={}
var _frame:=-1
var _valid:=false
## Coarse read view of the same current-frame inputs, shared with perception.
const QUERY_CELL30 := 16.0
var _query_cells30: Dictionary = {}
var _query_cursors30: Dictionary = {}
var _query_scans30 := 0
var _query_budget30: Dictionary = {"perception":0,"shot":0}

static func for_scene(scene:Node3D)->RefCounted:
	if not is_instance_valid(scene):return null
	var service:Variant=scene.get_meta(META) if scene.has_meta(META) else null
	if service is RefCounted:return service
	service=load("res://scripts/navigation/npc_avoidance_world29.gd").new()
	scene.set_meta(META,service)
	return service

static func refresh_scene(scene:Node3D)->void:
	var service:RefCounted=for_scene(scene)
	if service!=null:service.refresh(scene)

func refresh(scene:Node3D, fallback_actor:CharacterBody3D=null, fallback_id:String="fixture")->bool:
	var frame:int=Engine.get_physics_frames()
	if _frame==frame:return _valid
	_frame=frame;_keys.clear();_query_cells30.clear();_query_scans30=0;_valid=false
	_query_budget30.perception=0;_query_budget30.shot=0
	if not is_instance_valid(scene):return false
	var population:Variant=scene.get("preview_population")
	var residents:Variant=population.get("residents") if population!=null else null
	var records:Variant=residents.get("_records") if residents!=null else null
	var inputs:Array=[]
	if records is Dictionary:
		if records.size()>Core.MAX_ACTORS:return false
		inputs=residents.active_records30() if residents.has_method("active_records30") else records.values()
	elif is_instance_valid(fallback_actor):inputs.append({"body":fallback_actor,"row":{"source_id":fallback_id}})
	if is_instance_valid(diagnostic_extra58):
		inputs=inputs.duplicate()
		inputs.append({"body":diagnostic_extra58,"row":{"source_id":"qa_roam7_replay58"},"generation":1})
	var registry:Variant=scene.get_meta("npc_venue_registry29") if scene.has_meta("npc_venue_registry29") else null
	var passage31:Node=Passage31.for_scene(scene)
	passage31.refresh()
	var rows:Array[Core.FrameInput]=[]
	for record:Dictionary in inputs:
		var actor:Variant=record.get("body")
		# A record may outlive its freed body until the next lifecycle sweep.
		# Godot cannot evaluate `is` on a previously freed instance.
		if not is_instance_valid(actor) or not actor is CharacterBody3D or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.collision_layer!=1:continue
		var id:int=actor.get_instance_id();var generation:int=int(record.get("generation",0))
		var entry:Entry=_entries.get(id)
		if entry==null or entry.generation!=generation or entry.body.get_ref()!=actor:
			var shape:CollisionShape3D
			for child:Node in actor.get_children():
				if child is CollisionShape3D and not child.disabled and child.shape is CapsuleShape3D:shape=child;break
			if shape==null:continue
			entry=Entry.new();entry.body=weakref(actor);entry.shape=weakref(shape);entry.generation=generation
			entry.source_id=str(record.get("row",{}).get("source_id",""))
			entry.input=Core.FrameInput.new()
			entry.input.key=str(record.get("row",{}).get("source_id","actor"))+":life:"+str(generation)+":body:"+str(id)
			_entries[id]=entry
		var shape:Variant=entry.shape.get_ref()
		if not shape is CollisionShape3D or shape.disabled or not shape.shape is CapsuleShape3D:continue
		entry.seen=frame
		_keys[id]=entry.input.key
		var hint:Dictionary={}
		if registry!=null and registry.has_method("doorway_state29"):hint=registry.doorway_state29(actor)
		var row:Core.FrameInput=entry.input
		row.position=actor.global_position;row.velocity=actor.velocity;row.radius=shape.shape.radius;row.height=shape.shape.height
		row.priority=100 if bool(hint.get("portal_owner",false)) and str(hint.get("mode",""))=="crossing" else 0
		row.waiting=bool(hint.get("controlled",false)) and str(hint.get("mode",""))=="waiting"
		row.passage31=passage31.body_zone(actor)
		rows.append(row)
		var query_cell30 := Vector2i(floori(row.position.x/QUERY_CELL30),floori(row.position.z/QUERY_CELL30))
		if not _query_cells30.has(query_cell30):_query_cells30[query_cell30]=[]
		_query_cells30[query_cell30].append(entry)
	for id:Variant in _entries.keys():
		if _entries[id].seen!=frame:_entries.erase(id)
	_valid=core.snapshot(rows,frame,Time.get_ticks_msec())
	return _valid

## Fair bounded candidate discovery only. Consumers recheck identity/LOS/authority.
## Each empty cell or candidate costs one scan unit; only two bounded cursors exist.
func query_near30(origin: Vector3, radius: float, max_results: int=8, max_scan: int=64, channel: String="perception") -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not _valid or _frame!=Engine.get_physics_frames() or not origin.is_finite() or not is_finite(radius) or radius<=0 or radius>64.0 or channel not in ["perception","shot"]:return result
	max_results=clampi(max_results,1,32);max_scan=clampi(max_scan,1,128)
	max_scan=mini(max_scan,128-int(_query_budget30[channel]))
	if max_scan<=0:return result
	var lower := Vector2i(floori((origin.x-radius)/QUERY_CELL30),floori((origin.z-radius)/QUERY_CELL30))
	var upper := Vector2i(floori((origin.x+radius)/QUERY_CELL30),floori((origin.z+radius)/QUERY_CELL30))
	var width: int=upper.x-lower.x+1;var cells: int=width*(upper.y-lower.y+1)
	var cursor: Dictionary=_query_cursors30.get(channel,{})
	if cursor.is_empty() or cursor.lower!=lower or cursor.upper!=upper:
		cursor={"lower":lower,"upper":upper,"cell":0,"member":0};_query_cursors30[channel]=cursor
	var scanned:=0;var completed_cells:=0
	while scanned<max_scan and result.size()<max_results and completed_cells<cells:
		var cell := lower+Vector2i(int(cursor.cell)%width,int(cursor.cell)/width)
		var bucket: Array=_query_cells30.get(cell,[])
		if bucket.is_empty() or int(cursor.member)>=bucket.size():
			scanned+=1;cursor.cell=(int(cursor.cell)+1)%cells;cursor.member=0;completed_cells+=1
			continue
		var entry: Entry=bucket[int(cursor.member)];cursor.member=int(cursor.member)+1;scanned+=1
		var actor: Variant=entry.body.get_ref()
		if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.collision_layer!=1 or entry.seen!=_frame:continue
		if entry.input.position.distance_squared_to(origin)>radius*radius:continue
		result.append({"body":actor,"source_id":entry.source_id,"life_generation":entry.generation,"position":entry.input.position})
	_query_scans30+=scanned
	_query_budget30[channel]=int(_query_budget30[channel])+scanned
	return result

func query_state30() -> Dictionary:
	return {"frame":_frame,"cells":_query_cells30.size(),"cursors":_query_cursors30.size(),"scans_this_frame":_query_scans30,"entries":_entries.size()}

func steer(actor:CharacterBody3D,direction:Vector3,speed:float)->Dictionary:
	if not _valid or _frame!=Engine.get_physics_frames() or not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.collision_layer!=1:
		return {"direction":Vector3.ZERO,"ratio":0.0,"waiting":true,"reason":"no_current_snapshot","replan":false}
	return core.steer(str(_keys.get(actor.get_instance_id(),"")),direction,speed)

