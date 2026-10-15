extends Node
## One event-driven controller per admitted identity; no polling of living actors.
## A common admission gate bounds simultaneous corpse replacement work.
const Life = preload("res://scripts/hospital/npc_single_lifecycle28.gd")
var _population: WeakRef
var _scene: WeakRef
var _packet := PackedByteArray()
var _trust: Dictionary = {}
var _controllers: Dictionary = {}
var _disposed := false
var _admission_frame := -1

static func enabled30() -> bool:
	return OS.get_cmdline_user_args().has("--city-multi-lifecycle30=1")

func configure30(scene: Node3D, population: RefCounted, packet: PackedByteArray, trust: Dictionary) -> bool:
	set_process(false);set_physics_process(false)
	if _population!=null or not is_instance_valid(scene) or population.daily==null:return false
	_population=weakref(population);_scene=weakref(scene);_packet=packet;_trust=trust.duplicate(true)
	for health: RefCounted in population.hit_owners:
		if not bind_health30(health):return false
	return true

func bind_health30(health: RefCounted) -> bool:
	var population: RefCounted=_population.get_ref() if _population!=null else null
	var scene: Node3D=_scene.get_ref() if _scene!=null else null
	if _disposed or population==null or not is_instance_valid(scene) or not is_instance_valid(health):return false
	var token: Dictionary=health.get("_token")
	var id: String=str(token.get("source_id",""))
	if id.is_empty() or not population.daily._lives.has(id) or not population.residents.target_current(token):return false
	if _controllers.has(id):return _controllers[id].owns_health(health)
	var controller: Node=Life.new();scene.add_child(controller)
	if not controller.configure_resident30(scene,population,_packet,_trust,health,self):
		controller.dispose();return false
	_controllers[id]=controller
	return true

func admit_respawn30(controller: Node) -> bool:
	if _disposed or not is_instance_valid(controller) or _controllers.get(controller.get("source_id30"))!=controller:return false
	var frame: int=Engine.get_physics_frames()
	if frame==_admission_frame:return false
	_admission_frame=frame
	return true

func snapshot30() -> Dictionary:
	var phases: Dictionary={};var deaths:=0;var births:=0
	for controller: Node in _controllers.values():
		var value: Dictionary=controller.snapshot()
		phases[value.phase]=int(phases.get(value.phase,0))+1
		deaths+=int(value.death_count);births+=int(value.respawn_count)
	return {"controllers":_controllers.size(),"phases":phases,"deaths":deaths,"respawns":births,"per_frame_callback":false,"max_births_per_frame":1}

func dispose() -> void:
	if _disposed:return
	_disposed=true
	for controller: Node in _controllers.values():
		if is_instance_valid(controller):controller.dispose()
	_controllers.clear();_population=null;_scene=null;_packet=PackedByteArray();_trust.clear()
	queue_free()
