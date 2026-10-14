extends RefCounted
const Visit = preload("../hospital/npc_daily_hospital_visit.gd")
var _visit: RefCounted
func configure(host:RefCounted,policy:RefCounted,hit_owner:RefCounted,bank:Node3D,scene:Node3D,local_session:String,activity_owner:RefCounted,account:RefCounted,goal:Dictionary) -> Dictionary:
	if _visit!=null:return {"ok":false,"reason":"lifetime"}
	_visit=Visit.new()
	return _visit.configure_bank(host,policy,hit_owner,bank,scene,local_session,activity_owner,account,goal)
func begin() -> Dictionary:return _visit.begin() if _visit!=null else {"ok":false,"reason":"unbound"}
func step(delta:float) -> void:
	if _visit!=null:_visit.step(delta)
func snapshot() -> Dictionary:return _visit.snapshot() if _visit!=null else {"status":"UNBOUND"}
func cancel(reason:String="cancelled") -> Dictionary:return _visit.cancel(reason) if _visit!=null else {"ok":true,"status":"CANCELLED"}
func dispose() -> void:
	if _visit!=null:_visit.dispose()
