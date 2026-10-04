extends RefCounted
## Approach on foot, lease the actual driver's seat, drive, park and walk out.
## The existing vehicle owner alone ticks its adapter and physics body.
const Walk = preload("npc_daily_walk.gd")
var _host: RefCounted
var _token := {}
var _owner: WeakRef
var _transport: WeakRef
var _walk: RefCounted
var _trip: RefCounted
var _path := ""
var _sha := ""
var _phase := "UNBOUND"
var _reason := ""
var _released := true
var _cancelled := false
var _driving := false
var _time := 0.0
var _frame := -1

func configure(host: RefCounted, token: Dictionary, owner: RefCounted, transport: Node3D, route_path: String, route_sha256: String) -> Dictionary:
	if _phase!="UNBOUND" or not is_instance_valid(host) or not host.target_current(token) or not is_instance_valid(owner) or not is_instance_valid(transport): return {"ok":false,"reason":"current_owners_required"}
	if not transport.has_method("request_npc_trip") or not transport.has_method("approach") or route_path.is_empty() or route_sha256.length()!=64: return {"ok":false,"reason":"native_trip_route_required"}
	if FileAccess.get_sha256(route_path)!=route_sha256: return {"ok":false,"reason":"route_file_changed"}
	_host=host; _token=token.duplicate(); _owner=weakref(owner); _transport=weakref(transport); _path=route_path; _sha=route_sha256
	_walk=Walk.new()
	var result: Dictionary=_walk.configure(host,token,owner)
	if not result.get("ok",false): return result
	_phase="READY"; return {"ok":true}

func begin() -> Dictionary:
	if _phase!="READY" or not _host.target_current(_token) or not is_instance_valid(_transport.get_ref()): return {"ok":false,"reason":"trip_lifetime"}
	var transport: Node3D=_transport.get_ref()
	if not transport.ready_for_play or transport.phase!="ON_FOOT": return {"ok":false,"reason":"car_in_use"}
	var result: Dictionary=_walk.begin(transport.approach("front_left"))
	if result.get("ok",false): _phase="APPROACHING"; _released=false
	return result

func step(delta: float) -> void:
	if _phase in ["UNBOUND","READY","COMPLETE","CANCELLED","BLOCKED","DISPOSED"] or not is_finite(delta) or delta<=0.0 or delta>.05: return
	var frame:=Engine.get_physics_frames()
	if _frame==frame: return
	_frame=frame; _time+=delta
	if _trip!=null:
		var state: Dictionary=_trip.state()
		if state.phase=="SEATED" and not _driving and not _cancelled:
			var result: Dictionary=_trip.drive_to(_path,_sha)
			if result.get("ok",false): _driving=true; _phase="DRIVING"
			else: cancel(str(result.get("reason","drive_refused")))
		if state.phase=="DONE":
			_released=true; _phase="CANCELLED" if _cancelled else "COMPLETE"
		elif state.phase in ["RETIRED","FAILED"]:
			var lease: Dictionary=_host.get("_transport_lease")
			_released=lease.is_empty() or lease.get("adapter").get_ref()!=_trip
			if _released: _phase="BLOCKED"; _reason=str(state.reason)
		elif state.get("driver",{}).get("status")=="BLOCKED" and not _cancelled: cancel(str(state.driver.get("reason","road_blocked")))
		elif _time>900.0 and not _cancelled: cancel("trip_deadline")
		return
	if not _host.target_current(_token) or not is_instance_valid(_transport.get_ref()): cancel("actor_or_car_ended"); return
	if _phase=="APPROACHING":
		_walk.step(delta)
		var walking: Dictionary=_walk.snapshot()
		if walking.status=="COMPLETE":
			if not _walk.cancel().get("ok",false): return
			var result: Dictionary=_transport.get_ref().request_npc_trip(_host,_token,_owner.get_ref())
			if result.get("ok",false): _trip=result.adapter; _phase="BOARDING"
			elif result.get("cleanup_pending",false):
				_trip=_transport.get_ref().get("_npc_trip"); _cancelled=true; _phase="RELEASING"; _reason=str(result.reason)
			else: cancel(str(result.get("reason","seat_unavailable")))
		elif walking.status in ["BLOCKED","CANCELLED"]: cancel(str(walking.reason))

func cancel(reason: String="cancelled") -> void:
	_reason=reason; _cancelled=true
	if _trip!=null:
		_trip.cancel(); _phase="RELEASING"; return
	if _walk==null or _walk.cancel().get("ok",false): _released=true; _phase="CANCELLED"

func snapshot() -> Dictionary:
	return {"phase":_phase,"reason":_reason,"released":_released,"trip":_trip.state() if _trip!=null else {},"movement_tick":"existing_transport_owner"}

func dispose() -> void:
	if not _released: cancel("disposed"); return
	if _walk!=null: _walk.dispose()
	_phase="DISPOSED"; _trip=null; _transport=null; _owner=null
