extends RefCounted
## Scene wiring for real admitted residents. Movement remains in population.step
## and transport._physics_process; visit/account code alone commits services.
const Life = preload("npc_daily_life.gd")
const Account = preload("shop/npc_local_account.gd")
const Drive = preload("npc_daily_drive.gd")
var _scene: WeakRef
var _population: RefCounted
var _hospital: WeakRef
var _bank: WeakRef
var _hospital_script: Script
var _bank_script: Script
var _shop_script: Script
var _entry := PackedByteArray()
var _geometry := PackedByteArray()
var _road_path := ""
var _road_sha := ""
var _lives := {}
var _accounts := {}
var _health := {}
var _failures := {}
var _disposed := false
var _frame := -1
var _cursor := 0
var _samples := 0
var _total_us := 0
var _max_us := 0
var _max_frame := -1
var _life_peaks:Array[Dictionary]=[]

func _init() -> void:
	for _index in 12: _life_peaks.append({"frame":-1,"source_id":"","phase":"","kind":"","us":0})

func _record_life_peak(frame: int, source_id: String, phase: String, kind: String, elapsed: int) -> void:
	var minimum_index:=0
	for index in range(1,_life_peaks.size()):
		if int(_life_peaks[index]["us"])<int(_life_peaks[minimum_index]["us"]): minimum_index=index
	if elapsed<=int(_life_peaks[minimum_index]["us"]): return
	var peak: Dictionary=_life_peaks[minimum_index]
	peak["frame"]=frame; peak["source_id"]=source_id; peak["phase"]=phase; peak["kind"]=kind; peak["us"]=elapsed

func _life_peaks_snapshot() -> Array[Dictionary]:
	var peaks: Array[Dictionary]=[]
	for peak: Dictionary in _life_peaks:
		if int(peak["frame"])>=0: peaks.append(peak.duplicate())
	peaks.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.us)>int(b.us))
	return peaks

func configure(scene: Node3D, population: RefCounted, hospital: Node3D, bank: Node3D, hospital_script: Script, bank_script: Script, shop_script: Script, entry_bytes: PackedByteArray, geometry_bytes: PackedByteArray, route_path: String, route_sha: String) -> Dictionary:
	if _scene!=null or _disposed or not is_instance_valid(scene) or not scene.is_inside_tree() or not is_instance_valid(population) or population.get("residents")==null or population.get("policy")==null: return {"ok":false,"reason":"current_population_required"}
	if not is_instance_valid(hospital) or not hospital.get("ready_for_use") or not is_instance_valid(bank) or not bank.get("ready_for_use"): return {"ok":false,"reason":"actual_hospital_and_bank_required"}
	for script: Script in [hospital_script,bank_script,shop_script]:
		if script==null or not script.can_instantiate(): return {"ok":false,"reason":"concrete_visit_scripts_required"}
	_scene=weakref(scene); _population=population; _hospital=weakref(hospital); _bank=weakref(bank)
	_hospital_script=hospital_script; _bank_script=bank_script; _shop_script=shop_script
	_entry=entry_bytes.duplicate(); _geometry=geometry_bytes.duplicate(); _road_path=route_path; _road_sha=route_sha
	scene.tree_exiting.connect(_retire_scene,CONNECT_ONE_SHOT)
	for owner: RefCounted in population.hit_owners:
		var token: Dictionary=owner.get("_token")
		if not population.residents.target_current(token): continue
		var id: String=token.source_id
		var account:=Account.new()
		var admitted: Dictionary=account.configure(population.residents,token,owner)
		if not admitted.get("ok",false): _failures[id]=admitted; continue
		var bank_bound: Dictionary=account.bind_bank(scene)
		if not bank_bound.get("ok",false): account.dispose(); _failures[id]=bank_bound; continue
		var life:=Life.new()
		var active: Dictionary=life.configure(population.residents,token,owner,account,population.policy,Callable(self,"_create_visit").bind(id))
		if not active.get("ok",false): life.dispose(); account.dispose(); _failures[id]=active; continue
		_accounts[id]=account; _lives[id]=life; _health[id]=owner
	return {"ok":not _lives.is_empty(),"residents":_lives.size(),"failures":_failures.duplicate(true),"scene_mechanics":"new_local_session"}

func _create_visit(kind: String, goal: Dictionary, activity_owner: RefCounted, id: String) -> Dictionary:
	if _disposed or _scene==null or not is_instance_valid(_scene.get_ref()) or not _lives.has(id) or _lives[id]!=activity_owner: return {"ok":false,"reason":"current_daily_owner_required"}
	var host: RefCounted=_population.residents
	var token: Dictionary=_health[id]._token
	if not host.target_current(token): return {"ok":false,"reason":"current_walker_required"}
	var scene: Node3D=_scene.get_ref()
	var controller: RefCounted
	var result: Dictionary
	match kind:
		"hospital":
			controller=_hospital_script.new()
			result=controller.configure(host,_population.policy,_health[id],_hospital.get_ref(),scene,"LOCAL_DAILY24:"+id,activity_owner)
		"bank":
			controller=_bank_script.new()
			result=controller.configure(host,_population.policy,_health[id],_bank.get_ref(),scene,"LOCAL_DAILY24:"+id,activity_owner,_accounts[id],goal)
		"shop":
			controller=_shop_script.new()
			result=controller.configure(host,_population.policy,_health[id],scene,activity_owner,_accounts[id],goal,_entry,_geometry)
		"drive":
			var transport: Node3D=scene.get("preview_transport")
			if not is_instance_valid(transport): return {"ok":false,"reason":"native_transport_unavailable"}
			controller=Drive.new()
			result=controller.configure(host,token,activity_owner,transport,_road_path,_road_sha)
		_: return {"ok":false,"reason":"unknown_activity"}
	if not result.get("ok",false):
		controller.dispose(); return result
	return {"ok":true,"controller":controller}

func step(delta: float) -> void:
	if _disposed or _scene==null or not is_instance_valid(_scene.get_ref()) or not is_finite(delta) or delta<=0.0 or delta>.05: return
	var frame:=Engine.get_physics_frames()
	if frame==_frame: return
	_frame=frame
	var started:=Time.get_ticks_usec()
	# Services need consecutive actual physics samples; only inactive decisions
	# are spread over frames. No missed movement time is injected as a large dt.
	var ids: Array=_lives.keys()
	var count:=ids.size()
	for offset in count:
		var index:=(_cursor+offset)%count
		var life: RefCounted=_lives[ids[index]]
		if life._phase in ["ACTIVITY","WALKING"] or offset<4:
			var life_started:=Time.get_ticks_usec()
			var life_phase:String=life._phase
			var life_kind:String=str(life._goal.get("kind",""))
			life.step(delta)
			var life_us:=Time.get_ticks_usec()-life_started
			if life_us>=1000:
				_record_life_peak(frame,str(ids[index]),life_phase,life_kind,life_us)
	if count>0: _cursor=(_cursor+4)%count
	var elapsed:=Time.get_ticks_usec()-started
	_samples+=1; _total_us+=elapsed
	if elapsed>_max_us: _max_us=elapsed; _max_frame=frame

func snapshot(include_details: bool=false) -> Dictionary:
	var rows:=[]
	for id: String in _lives:
		var life: RefCounted=_lives[id]
		rows.append(life.snapshot() if include_details else {"source_id":id,"phase":life._phase,"reason":life._reason,"kind":life._goal.get("kind",""),"completed":life._completed.duplicate()})
	return {"residents":rows,"failures":_failures.duplicate(true),"scope":"local_daily_services","cost":{"samples":_samples,"total_us":_total_us,"max_us":_max_us,"max_frame":_max_frame},"life_peaks":_life_peaks_snapshot(),"native_movement_tick_added":false}

func dispose() -> void:
	if _disposed: return
	var pending:=false
	for life: RefCounted in _lives.values():
		life.dispose()
		if life._phase!="DISPOSED" and life._phase!="RETIRED": pending=true
	if pending: return
	for account: RefCounted in _accounts.values(): account.dispose()
	_disposed=true; _lives.clear(); _accounts.clear(); _health.clear(); _scene=null

func _retire_scene() -> void:
	# A destroyed scene cannot physically unwind a visit. Its existing host owns
	# body teardown; retire our goals and break factory reference cycles now.
	for life: RefCounted in _lives.values(): life._end_life()
	for account: RefCounted in _accounts.values(): account.dispose()
	_disposed=true; _lives.clear(); _accounts.clear(); _health.clear(); _scene=null
