extends "res://scripts/npc_visual/npc_local_printshop_visit.gd"
## Optional source-checkout composer. The parent still owns the original
## entrance/door/exit phases; the existing resident host remains sole mover.
var commerce: RefCounted
var commerce_goal := ""
var commerce_service := -1
var commerce_result := {}
const Account = preload("npc_local_account.gd")

## Same entrance contract as the frozen three-actor composer, generalized only
## to source rows already authenticated and physically owned by this host.
func configure(host: RefCounted, interior: Node3D, entry_bytes: PackedByteArray, local_session: String, id: String, request_route: Callable, poll_route: Callable, cancel_route: Callable, door_started: Callable, occupants: Callable) -> bool:
	if _phase!="UNBOUND" or _busy or not local_session.begins_with("LOCAL_NPC_VISIT23:") or _hash(entry_bytes)!=ENTRY_SHA: return false
	if not is_instance_valid(interior) or not interior.get("ready_for_use") or not host._records.has(id): return false
	for callback: Callable in [request_route,poll_route,cancel_route,door_started,occupants]:
		if not callback.is_valid(): return false
	var data: Dictionary=JSON.parse_string(entry_bytes.get_string_from_utf8())
	if data.get("source_id")!=BUILDING or data.get("scope")!="NEW_LOCAL_PREVIEW_SESSION_ONE_ORIGINAL_PHYSICAL_ENTRY": return false
	var record: Dictionary=host._records[id]
	var token: Dictionary=host.target_from_collider(record.body)
	if not token.get("ok",false) or not host.target_current(token) or not Account.ordinary_record_matches(record,token): return false
	var claim: Variant=record.get("local_route_owner")
	if not claim is WeakRef or not is_instance_valid(claim.get_ref()): return false
	var route: RefCounted=claim.get_ref()
	if route.get("host")!=host or route.get("token")!=token or route.get("_disposed")!=false or route.get("_phase")!="READY": return false
	_host=host; _interior=weakref(interior); _token=token; _id=id; _generation=token.life_generation; _session=local_session
	_route_owner=weakref(route); _request=request_route; _poll=poll_route; _cancel=cancel_route; _door_started=door_started; _occupants=occupants
	_outside=_point(data.public_approach_preview); _inside=_point(data.public_inside_preview)
	_phase="READY"
	return true

func bind_commerce(account: RefCounted, goal_id: String) -> bool:
	if commerce != null or _phase!="READY" or not is_instance_valid(account) or account.get("_host")!=_host or account.get("_token")!=_token or goal_id.is_empty(): return false
	commerce = account; commerce_goal = goal_id; return true

func tick(now_ms: float) -> Dictionary:
	# Settle against the current physical BROWSING proof before the parent can
	# advance to EXITING on a sparse daily tick. The account remains sole money owner.
	if commerce != null and commerce_service >= 0 and _phase == "BROWSING" and not _busy and is_finite(now_ms) and now_ms >= _now:
		commerce_result = commerce.poll_service(commerce_service,now_ms)
		var settled_result: Dictionary = super.tick(now_ms)
		settled_result.commerce = commerce_result.duplicate(true)
		return settled_result
	var result: Dictionary = super.tick(now_ms)
	if commerce == null: return result
	if commerce._health.should_pause_walk():
		if commerce_service >= 0: commerce_result = commerce.poll_service(commerce_service,now_ms)
		return result
	if result.phase == "BROWSING" and commerce_service < 0:
		commerce_result = commerce.begin_service({"goal_id":commerce_goal,"kind":"shop"},self,now_ms)
		if commerce_result.get("ok",false) and commerce_result.has("service_id"): commerce_service = commerce_result.service_id
	elif commerce_service >= 0:
		commerce_result = commerce.poll_service(commerce_service,now_ms)
	result.commerce = commerce_result.duplicate(true)
	return result

func cancel() -> void:
	if commerce != null and commerce_service >= 0: commerce.cancel_service(commerce_service)
	super.cancel()
