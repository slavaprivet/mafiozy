extends RefCounted
## One scene-owned snapshot adapter. No body ownership, movement or door claims.
const Core = preload("res://scripts/navigation/npc_local_avoidance29.gd")
const META := "npc_local_avoidance29"
var core:RefCounted=Core.new()
class Entry extends RefCounted:
	var body:WeakRef
	var shape:WeakRef
	var generation:int
	var input:Core.FrameInput
	var seen:int
var _keys:Dictionary={}
var _entries:Dictionary={}
var _frame:=-1
var _valid:=false

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
	_frame=frame;_keys.clear();_valid=false
	if not is_instance_valid(scene):return false
	var population:Variant=scene.get("preview_population")
	var residents:Variant=population.get("residents") if population!=null else null
	var records:Variant=residents.get("_records") if residents!=null else null
	var inputs:Array=[]
	if records is Dictionary:
		if records.size()>Core.MAX_ACTORS:return false
		inputs=records.values()
	elif is_instance_valid(fallback_actor):inputs.append({"body":fallback_actor,"row":{"source_id":fallback_id}})
	var registry:Variant=scene.get_meta("npc_venue_registry29") if scene.has_meta("npc_venue_registry29") else null
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
		rows.append(row)
	for id:Variant in _entries.keys():
		if _entries[id].seen!=frame:_entries.erase(id)
	_valid=core.snapshot(rows,frame,Time.get_ticks_msec())
	return _valid

func steer(actor:CharacterBody3D,direction:Vector3,speed:float)->Dictionary:
	if not _valid or _frame!=Engine.get_physics_frames() or not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.collision_layer!=1:
		return {"direction":Vector3.ZERO,"ratio":0.0,"waiting":true,"reason":"no_current_snapshot","replan":false}
	return core.steer(str(_keys.get(actor.get_instance_id(),"")),direction,speed)

