extends RefCounted
const Visit = preload("../hospital/npc_daily_hospital_visit.gd")
var _visit: RefCounted
var _dsh_elapsed := -1.0  # DSH_LIFECLOCK: real game time since the previous poll
## DSH_BANKRELEASE: the daily telemetry reads `_released` on the visit object
## (npc_city_daily.gd:500). The shop (npc_daily_shop.gd:385) and hospital
## (npc_daily_hospital_visit.gd:290) visits expose that field themselves; this
## wrapper did not, so every live bank visit counted as `act_released_unknown`.
## The field now always exists and mirrors the real visit.
var _released := false
var _dsh_bank_release := -1  # DSH_BANKRELEASE
var _dsh_unbound_reported := false  # DSH_BANKRELEASE
func _dsh_bank_release_on() -> int:  # DSH_BANKRELEASE
	if _dsh_bank_release < 0:
		_dsh_bank_release = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-bank-visit-release="):
				_dsh_bank_release = maxi(0, mini(1, int(argument.trim_prefix("--city-bank-visit-release="))))
	return _dsh_bank_release
func _sync_released() -> void:  # DSH_BANKRELEASE
	if _visit == null: return
	var inner: Variant = _visit.get("_released")
	if inner is bool: _released = inner
func configure(host:RefCounted,policy:RefCounted,hit_owner:RefCounted,bank:Node3D,scene:Node3D,local_session:String,activity_owner:RefCounted,account:RefCounted,goal:Dictionary) -> Dictionary:
	if _visit!=null:return {"ok":false,"reason":"lifetime"}
	_visit=Visit.new()
	return _visit.configure_bank(host,policy,hit_owner,bank,scene,local_session,activity_owner,account,goal)
func begin() -> Dictionary:return _visit.begin() if _visit!=null else {"ok":false,"reason":"unbound"}
func step(delta:float) -> void:
	if _visit!=null:
		_visit._dsh_elapsed=_dsh_elapsed  # DSH_LIFECLOCK: the inner visit's clocks
		_visit.step(delta)
		_sync_released()  # DSH_BANKRELEASE
func snapshot() -> Dictionary:
	if _visit==null:
		if _dsh_bank_release_on()==1:
			# DSH_BANKRELEASE: an unbound wrapper owns no navigation/body lease, so it
			# is already released. Publish a finishable terminal state instead of the
			# opaque UNBOUND that kept the daily activity alive forever; these are the
			# shop:369 / hospital:288 release semantics.
			if not _dsh_unbound_reported:
				_dsh_unbound_reported=true
				print("DSH_BANKRELEASE unbound released=true reason=bank_visit_unbound")
			return {"status":"FAILED","released":true,"reason":"bank_visit_unbound","kind":"bank"}
		return {"status":"UNBOUND"}
	var state:Dictionary=_visit.snapshot()
	_sync_released()
	# DSH_BANKRELEASE: guarantee the field the other two visits already publish.
	if not state.has("released"): state["released"]=_released
	if not state.has("kind"): state["kind"]="bank"
	return state
func cancel(reason:String="cancelled") -> Dictionary:return _visit.cancel(reason) if _visit!=null else {"ok":true,"status":"CANCELLED"}
func dispose() -> void:
	if _visit!=null:_visit.dispose()
