extends Node
## Single placed Palazzo. Main owns input; the site owns its original physics tick.
const DamageBridge = preload("res://scripts/destruction/modular30/native_building_damage_bridge.gd")
const SITE_PATH := "res://scripts/destruction/palazzo/palazzo_foundation12_site.tscn"
const BINDING_PATH := "res://data/palazzo_binding.json"
const SOURCE_ID := "PALAZZO-SHOWCASE-001"
var source_id := SOURCE_ID
var site: Node3D
var status := "disabled"
var report: Dictionary = {}
var _world: WeakRef
var _damage: RefCounted
var _disposed := false
var _events: Array[Dictionary] = []
var _command_serial := 0
var _push_actor_id := 0

func _ready() -> void:
	process_physics_priority=100
	set_physics_process(false)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func prepare(world: Node3D) -> Dictionary:
	if _disposed or _world!=null or not is_inside_tree() or not is_instance_valid(world) or not world.is_inside_tree(): return {"ok":false,"reason":"world_lifetime"}
	_world=weakref(world)
	if not FileAccess.file_exists(BINDING_PATH): return _abort("binding_missing")
	var binding: Variant=JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
	if not binding is Dictionary: return _abort("binding_dictionary")
	if binding.get("enabled",false)!=true:
		report={"ok":true,"enabled":false,"status":"disabled","source_id":source_id}; return report.duplicate(true)
	if binding.get("source_id")!=SOURCE_ID or not binding.get("frame") is Dictionary: return _abort("source_or_frame")
	var frame: Dictionary=binding.frame
	for field: String in ["x","y","z","yaw"]:
		if not _number(frame.get(field)): return _abort("frame_number:"+field)
	if not _number(frame.get("scale",1.0)) or float(frame.get("scale",1.0))!=1.0: return _abort("unit_scale_required")
	if not world.global_transform.is_finite() or absf(world.global_transform.basis.determinant())<.000001: return _abort("world_frame")
	for child: Node in world.get_children():
		if child.get_meta("source_id","")==source_id: return _abort("source_already_present")
	var packed: PackedScene=load(SITE_PATH) as PackedScene
	if packed==null: return _abort("site_scene_missing")
	var instance: Node=packed.instantiate()
	if not instance is Node3D or not instance.has_method("apply_explosion") or not instance.has_method("owns_collider"):
		instance.free(); return _abort("site_contract")
	site=instance
	site.name="PalazzoShowcaseSite"
	site.set("source_id",source_id)
	var world_frame:=Transform3D(Basis(Vector3.UP,float(frame.yaw)),Vector3(float(frame.x),float(frame.y),float(frame.z)))
	site.transform=world.global_transform.affine_inverse()*world_frame
	world.add_child(site)
	if not site.get_stats().get("ok",false) or not site.global_transform.is_equal_approx(world_frame): return _abort("site_ready_or_frame")
	load("res://scripts/destruction/palazzo/palazzo_access.gd").install(site)
	status="geometry_ready_waiting_native_weapons"
	report={"ok":true,"enabled":true,"status":status,"source_id":source_id,"frame":frame.duplicate(true),"site":site.get_stats(),"loaded_city_performance":"unverified"}
	set_physics_process(true)
	return report.duplicate(true)

func bind_weapons() -> Dictionary:
	if not _site_current(): return {"ok":false,"reason":"site_not_ready"}
	if _damage!=null: return {"ok":false,"reason":"already_bound"}
	var world: Node3D=_world.get_ref()
	if not is_instance_valid(world.preview_weapons): return {"ok":false,"reason":"native_weapon_host_missing"}
	var bridge: RefCounted=DamageBridge.new()
	var result: Dictionary=bridge.configure(world.preview_weapons,Callable(self,"_native_blast"),Callable(self,"_native_glass"),{"breach_radius_m":.8,"glass_blast_port":Callable(self,"_native_glass_blast")})
	if not result.get("ok",false): bridge.dispose(); return {"ok":false,"reason":"native_damage_bridge","detail":result}
	_damage=bridge; status="ready"; report.status=status; report.damage_bridge=result
	return report.duplicate(true)

func _site_current() -> bool:
	if _disposed or _world==null or not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion(): return false
	var world: Variant=_world.get_ref()
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and site.get_parent()==world and site.get("source_id")==source_id and site.get("site_ready")==true

func _native_blast(event: Dictionary) -> Dictionary:
	if not _site_current() or _damage==null or status!="ready": return {"ok":false,"reason":"retired_site"}
	if event.is_empty() or event.get("source_id")!=source_id: return {"ok":false,"reason":"source_not_admitted"}
	var collider: Variant=event.get("collider")
	var owned_pane: bool=is_instance_valid(site.get("_glazing")) and site._glazing.owns_collider(collider)
	if not is_instance_valid(collider) or (not site.owns_collider(collider) and not owned_pane): return {"ok":false,"reason":"foreign_native_collision"}
	var result: Dictionary=site.apply_explosion(event)
	_record("blast",str(event.get("event_id","")),result)
	return result

func _native_glass(event: Dictionary) -> Dictionary:
	if not _site_current() or _damage==null or status!="ready" or not is_instance_valid(site.get("_glazing")): return {"ok":false,"reason":"retired_glazing"}
	var result: Dictionary=site._glazing.apply_bullet(event)
	_record("glass_bullet",str(event.get("event_id","")),result)
	return result

func _native_glass_blast(event: Dictionary) -> Dictionary:
	if not _site_current() or _damage==null or status!="ready" or not is_instance_valid(site.get("_glazing")): return {"ok":false,"reason":"retired_glazing"}
	var result: Dictionary=site._glazing.apply_blast(event)
	_record("glass_blast",str(event.get("event_id","")),result)
	return result

func _record(kind: String,event_id: String,result: Dictionary) -> void:
	_events.append({"kind":kind,"event_id":event_id,"result":result.duplicate(true)})
	if _events.size()>32: _events.pop_front()

func _actor(require_floor: bool=false) -> CharacterBody3D:
	if not _site_current(): return null
	var world: Node3D=_world.get_ref()
	if not world.preview_ready or world.preview_dead or world.preview_physics_fault: return null
	var player: Variant=world._player
	if not is_instance_valid(player) or not player is CharacterBody3D or not player.is_inside_tree(): return null
	if player._pose_authority!=&"on_foot" or not player._free_mouse_look: return null
	if require_floor and (not player.is_on_floor() or not player._jump.is_empty()): return null
	var focused: Control=get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return null
	return player

func _near_site(actor: CharacterBody3D) -> bool:
	var offset: Vector3=site.to_local(actor.global_position)
	return Vector2(offset.x,offset.z).length()<=18.0 and absf(offset.y)<=8.0

func door_action() -> Dictionary:
	var actor: CharacterBody3D=_actor()
	if actor==null: return {}
	var prompt: Dictionary=site.get_door_prompt(actor)
	if not prompt.get("available",false): return {}
	var door: RigidBody3D=site.get("_door")
	if not is_instance_valid(door) or not site.owns_collider(door): return {}
	var size: Vector3=door.get_meta("section_size")
	return {"owner":"palazzo","door":"palazzo_entrance","source_id":source_id,"opening":bool(prompt.open),"label":str(prompt.text),"distance":float(prompt.distance),"world":site.building.to_global(site._door_closed.origin)+Vector3.UP*(size.y*.5+.25)}

func request_door() -> Dictionary:
	var actor: CharacterBody3D=_actor()
	if actor==null: return {"accepted":false,"reason":"actor_not_available"}
	var result: Dictionary=site.interact_door(actor)
	var reason: String=str(result.get("reason",""))
	if reason=="door_sweep_blocked": reason="door-sweep-occupied"
	return {"accepted":bool(result.get("ok",false)),"open":bool(result.get("opening",false)),"reason":reason,"detail":result}

func request_full_collapse(event_id: String="") -> Dictionary:
	var actor: CharacterBody3D=_actor()
	if actor==null or not _near_site(actor): return {"ok":false,"reason":"nearby_on_foot_actor_required"}
	if event_id.is_empty():
		_command_serial+=1; event_id="palazzo-command:"+str(get_instance_id())+":"+str(_command_serial)
	var result: Dictionary=site.request_full_collapse(event_id)
	result.event_id=event_id; _record("collapse",event_id,result)
	return result

func request_reset() -> Dictionary:
	var actor: CharacterBody3D=_actor()
	if actor==null or not _near_site(actor): return {"ok":false,"reason":"nearby_on_foot_actor_required"}
	_invalidate_push_sample()
	var result: Dictionary=site.request_reset()
	_record("reset","",result)
	return result

func event_status(event_id: String) -> Dictionary:
	return site.event_status(event_id) if _site_current() else {"ok":false,"reason":"site_not_ready"}

func _invalidate_push_sample() -> void:
	# Never turn movement accumulated while driving, airborne or UI-focused into a shove.
	if _push_actor_id!=0 and is_instance_valid(site): site._actor_positions.erase(_push_actor_id)
	_push_actor_id=0

func _physics_process(delta: float) -> void:
	var actor: CharacterBody3D=_actor(true)
	if actor==null: _invalidate_push_sample(); return
	var world: Node3D=_world.get_ref()
	var capsule: Variant=world._player_capsule
	if not is_instance_valid(capsule) or not capsule is CollisionShape3D: _invalidate_push_sample(); return
	if _push_actor_id!=0 and _push_actor_id!=actor.get_instance_id(): _invalidate_push_sample()
	_push_actor_id=actor.get_instance_id()
	# The site advances/render-syncs itself. Forward only the real player's movement sample.
	site.push_from_actor(actor,capsule,delta)

func snapshot() -> Dictionary:
	return {"status":status,"source_id":source_id,"report":report.duplicate(true),"events":_events.duplicate(true),"site":site.get_stats() if _site_current() else {},"damage":_damage.snapshot() if _damage!=null and not _disposed else {}}

func _abort(reason: String) -> Dictionary:
	dispose(); status="failed"
	report={"ok":false,"reason":reason,"status":status,"source_id":source_id}
	return report.duplicate(true)

func dispose() -> void:
	if _disposed: return
	_invalidate_push_sample(); _disposed=true; set_physics_process(false)
	if _damage!=null: _damage.dispose(); _damage=null
	if is_instance_valid(site):
		if site.get_parent()!=null: site.queue_free()
		else: site.free()
	site=null; _world=null; status="disposed"

func _exit_tree() -> void:
	dispose()
