extends Node
## Scene-owned inventory and one weak reservation per physical bench centre.
## No resident population, skeleton, movement or collision-filter authority.
const META := "npc_ambient_benches29"
const SUPPORT_NAME := "AmbientBenchSupport28"
const MAX_BENCHES := 16
const HEARTBEAT_MS := 1000
const APPROACH_MS := 6000
var _scene: WeakRef
var _rows: Dictionary = {}
var _claims: Dictionary = {}
var _pending: Dictionary = {}
var _serial := 0
var _scans := 0

static func for_scene(scene: Node3D) -> Node:
	var previous: Variant = scene.get_meta(META) if scene.has_meta(META) else null
	if previous is WeakRef and is_instance_valid(previous.get_ref()):
		var found: Node = previous.get_ref()
		if found.get_parent() == scene and not found.is_queued_for_deletion(): return found
	var registry: Node = load("res://scripts/npc_ambient/ambient_bench_registry29.gd").new()
	registry.name = "AmbientBenchRegistry29"; scene.add_child(registry)
	registry.set("_scene",weakref(scene)); scene.set_meta(META,weakref(registry))
	registry.call("_build",scene)
	scene.get_tree().node_added.connect(Callable(registry,"_node_added"))
	return registry

func _build(scene: Node3D) -> void:
	_scans += 1
	for candidate: Node in scene.find_children("OriginalBench*","Node3D",true,false): _consider(candidate)

func _node_added(node: Node) -> void:
	var candidate: Node = node if node is Node3D and str(node.name).begins_with("OriginalBench") else node.get_parent()
	if not candidate is Node3D or not str(candidate.name).begins_with("OriginalBench"): return
	var id: int = candidate.get_instance_id()
	if _rows.has(id) or _pending.has(id): return
	_pending[id] = true
	_consider_deferred.call_deferred(weakref(candidate),id)

func _consider_deferred(reference: WeakRef, id: int) -> void:
	_pending.erase(id)
	var candidate: Variant = reference.get_ref()
	if is_instance_valid(candidate): _consider(candidate)

func _consider(candidate: Node) -> void:
	if not candidate is Node3D or _scene == null: return
	var scene: Node = _scene.get_ref()
	if not is_instance_valid(scene) or not scene.is_ancestor_of(candidate) or candidate.is_queued_for_deletion(): return
	var id: int = candidate.get_instance_id()
	if _rows.has(id) or _rows.size() >= MAX_BENCHES: return
	if not candidate.get_meta("palazzo_bench",false) or not candidate.is_visible_in_tree(): return
	var bench: Node3D = candidate
	if not bench.global_basis.is_equal_approx(bench.global_basis.orthonormalized()) or not bench.global_basis.y.is_equal_approx(Vector3.UP): return
	var meshes: Array[MeshInstance3D] = []
	for child: Node in bench.get_children():
		if child is MeshInstance3D and child.has_meta("box_size") and child.is_visible_in_tree(): meshes.append(child)
	if meshes.size() != 6: return
	var seat_count := 0
	for mesh: MeshInstance3D in meshes:
		var size: Variant = mesh.get_meta("box_size")
		if not size is Vector3 or not size.is_finite() or size.x <= 0 or size.y <= 0 or size.z <= 0 or not mesh.basis.is_equal_approx(Basis.IDENTITY): return
		if is_equal_approx(size.x,1.7) and is_equal_approx(size.y,.10) and is_equal_approx(size.z,.15) and is_equal_approx(mesh.position.y,.43): seat_count += 1
	if seat_count != 3: return
	var support: StaticBody3D = bench.get_node_or_null(SUPPORT_NAME) as StaticBody3D
	if support == null:
		support = StaticBody3D.new(); support.name = SUPPORT_NAME; support.collision_layer = 1; support.collision_mask = 1; support.set_meta("ambient_bench28",true)
		for mesh: MeshInstance3D in meshes:
			var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = mesh.get_meta("box_size"); shape.shape = box; shape.transform = mesh.transform; support.add_child(shape)
		bench.add_child(support)
	if not support.get_meta("ambient_bench28",false) or support.get_child_count() != 6: return
	var pins: Array[Dictionary] = []
	for mesh: MeshInstance3D in meshes: pins.append({"mesh":weakref(mesh),"frame":mesh.transform,"size":mesh.get_meta("box_size")})
	_rows[id] = {"bench_id":id,"bench":weakref(bench),"support":weakref(support),"frame":bench.global_transform,"pins":pins}
	bench.tree_exiting.connect(_remove.bind(id,"bench_removed"),CONNECT_ONE_SHOT)
	support.tree_exiting.connect(_remove.bind(id,"support_removed"),CONNECT_ONE_SHOT)

func rows() -> Array:
	return _rows.values()

func current(row: Dictionary) -> bool:
	var bench: Node3D = row.bench.get_ref()
	var support: StaticBody3D = row.support.get_ref()
	var scene: Node = _scene.get_ref() if _scene != null else null
	if not is_instance_valid(scene) or not is_instance_valid(bench) or not is_instance_valid(support) or not bench.is_inside_tree() or not scene.is_ancestor_of(bench) or not bench.is_visible_in_tree() or bench.is_queued_for_deletion() or support.is_queued_for_deletion(): return false
	if bench.global_transform != row.frame or support.get_parent() != bench or support.transform != Transform3D.IDENTITY or support.collision_layer != 1 or support.get_child_count() != row.pins.size(): return false
	for index: int in row.pins.size():
		var pin: Dictionary = row.pins[index]; var mesh: MeshInstance3D = pin.mesh.get_ref(); var shape: Node = support.get_child(index)
		if not is_instance_valid(mesh) or not mesh.is_visible_in_tree() or mesh.transform != pin.frame or mesh.get_meta("box_size") != pin.size: return false
		if not shape is CollisionShape3D or shape.disabled or not shape.shape is BoxShape3D or shape.shape.size != pin.size or shape.transform != pin.frame: return false
	return true

func _remove(id: int, reason: String) -> void:
	_drop(id,reason,true); _rows.erase(id); _pending.erase(id)

func _drop(id: int, reason: String, cancel_owner: bool) -> void:
	var claim: Dictionary = _claims.get(id,{})
	_claims.erase(id) # Erase BEFORE cancellation, whose release re-enters this registry.
	if cancel_owner and not claim.is_empty():
		var owner: Variant = claim.owner.get_ref()
		# A selection-time reservation belongs to the walking life, which may have no
		# cancellation entry point of its own: only signal an owner that offers one.
		if is_instance_valid(owner) and owner.has_method("cancel"): owner.cancel(reason)

func _live(id: int) -> bool:
	if not _claims.has(id): return false
	var claim: Dictionary = _claims[id]
	var owner: Variant = claim.owner.get_ref(); var body: Variant = claim.body.get_ref()
	if not _rows.has(id) or not current(_rows[id]): _drop(id,"bench_support_lost",true); return false
	# Task58: a reservation placed AT GOAL SELECTION belongs to the resident that chose
	# the place, and it lives exactly as long as that resident still holds it. There is
	# no second-scale deadline: a seat is not lost because its owner paused for a moment
	# between two actions, and it is not held by a resident that stopped holding it.
	if str(claim.get("mode","ambient")) == "reserved":
		return _reserved_owner_live(claim)
	if not is_instance_valid(owner) or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): _drop(id,"bench_owner_removed",true); return false
	# Only life-side acquisition/renew invokes this. Pose sampling NEVER re-enters host.
	if not owner.bench_slot_living29(int(claim.serial)): _drop(id,"bench_life_stale",true); return false
	if claim.phase == "OCCUPIED":
		# A live sitting/standing-up actor never loses its seat merely due to a slow frame.
		if body.global_position.distance_to(claim.anchor) > .12 or not body.is_on_floor(): _drop(id,"bench_contact_lost",true); return false
		return true
	var now: int = Time.get_ticks_msec()
	if now > int(claim.approach_deadline) or now > int(claim.heartbeat_deadline): _drop(id,"bench_approach_lease_expired",true); return false
	return true

func available(id: int) -> bool:
	return not _live(id)

## Task58: is this bench held by a reservation nobody has reached yet?
func reserved(id: int) -> bool:
	if not _claims.has(id): return false
	return str(_claims[id].get("mode","ambient")) == "reserved"

## Task58: the number of benches that currently hold a selection-time reservation.
func reservations() -> int:
	var total := 0
	for claim: Dictionary in _claims.values():
		if str(claim.get("mode","ambient")) == "reserved": total += 1
	return total

## Task58: the live reservation placed by one searcher, so the action that finally
## reaches the bench can adopt that exact claim instead of trying to claim again.
func reserved_by(owner: RefCounted, body: CharacterBody3D) -> Dictionary:
	if not is_instance_valid(owner) or not is_instance_valid(body): return {}
	for id: int in _claims.keys():
		var claim: Dictionary = _claims[id]
		if str(claim.get("mode","ambient")) != "reserved": continue
		var searcher: RefCounted = claim.get("searcher",{}).get("owner",{}).get_ref() if claim.get("searcher",{}).get("owner") is WeakRef else null
		var at: CharacterBody3D = claim.get("searcher",{}).get("body",{}).get_ref() if claim.get("searcher",{}).get("body") is WeakRef else null
		if searcher != owner or at != body: continue
		if int(claim.get("searcher",{}).get("action_serial",-1)) != int(claim.get("action_serial",-2)): continue
		if not _live(id): return {}
		var row: Dictionary = _rows[id]
		var bench: Node3D = row.bench.get_ref()
		if not is_instance_valid(bench): return {}
		var out: Dictionary = row.duplicate()
		out["approach"] = claim.get("approach", Vector3.ZERO)
		out["seat"] = claim.get("seat", Vector3.ZERO)
		out["right"] = claim.get("right", Vector3.ZERO)
		out["bench_path"] = str(bench.get_path())
		out["support_path"] = str(row.support.get_ref().get_path()) if row.support.get_ref() != null else ""
		out["slot"] = {"bench_id":id,"serial":int(claim.serial),"action_serial":int(claim.action_serial),"body_id":int(claim.body_id)}
		return out
	return {}

## Task58: THE SELECTION-TIME RESERVATION. Two residents that both see the same bench
## free must not both be sent to it: availability is tested and the claim is written
## in the same main-thread call, with no await between the test and the write.
## The approach point is the one the searcher already proved walkable, so the action
## that adopts this reservation never re-derives the seat from a blocked position.
func reserve(row: Dictionary, searcher: RefCounted, body: CharacterBody3D, action_serial: int, approach: Vector3, seat: Vector3, right: Vector3) -> Dictionary:
	var id: int = int(row.get("bench_id",0))
	if not Thread.is_main_thread() or not _rows.has(id) or not current(row): return {}
	if not is_instance_valid(searcher) or not is_instance_valid(body) or not approach.is_finite() or not seat.is_finite(): return {}
	if _live(id): return {}
	_serial += 1
	# No deadline field at all: a reservation has no timer to expire. It ends when its
	# owner releases it, loses it, or stops holding it, never because a second passed.
	_claims[id] = {"serial":_serial,"action_serial":action_serial,"mode":"reserved",
		"owner":weakref(searcher),"body":weakref(body),"body_id":body.get_instance_id(),
		"searcher":{"owner":weakref(searcher),"body":weakref(body),"action_serial":action_serial},
		"approach":approach,"seat":seat,"right":right,"phase":"APPROACH","anchor":Vector3.ZERO}
	return {"bench_id":id,"serial":_serial,"action_serial":action_serial,"body_id":body.get_instance_id()}

## Task58: the owner keeps its reservation alive by holding it. There is nothing to
## renew on a timer, so a pause of any length between two actions of the same resident
## cannot lose the seat, and no deadline can free a seat that is still wanted.
func renew_reservation(lease: Dictionary, searcher: RefCounted, body: CharacterBody3D) -> bool:
	var id: int = int(lease.get("bench_id",0)); var claim: Dictionary = _claims.get(id,{})
	if claim.is_empty() or claim.serial != lease.get("serial") or claim.action_serial != lease.get("action_serial"): return false
	if str(claim.get("mode","ambient")) != "reserved": return false
	if claim.searcher.owner.get_ref() != searcher or claim.searcher.body.get_ref() != body: return false
	return _live(id)

## Task58: ownership handover of one reservation, choosing action -> sitting action.
## The physical claim, the seat point and the dwell time are the SAME claim, so the
## bench can never be double-sold between the two actions.
func adopt_reservation(lease: Dictionary, from: RefCounted, to: RefCounted, body: CharacterBody3D, action_serial: int) -> Dictionary:
	var id: int = int(lease.get("bench_id",0)); var claim: Dictionary = _claims.get(id,{})
	if not Thread.is_main_thread() or claim.is_empty() or not is_instance_valid(to) or not is_instance_valid(body): return {}
	if claim.serial != lease.get("serial") or str(claim.get("mode","ambient")) != "reserved": return {}
	if claim.searcher.owner.get_ref() != from or claim.searcher.body.get_ref() != body: return {}
	if claim.body.get_ref() != body or not _live(id): return {}
	_serial += 1
	claim.mode = "ambient"; claim.owner = weakref(to); claim.action_serial = action_serial
	claim.serial = _serial
	claim.heartbeat_deadline = Time.get_ticks_msec()+HEARTBEAT_MS
	claim.approach_deadline = Time.get_ticks_msec()+APPROACH_MS
	return {"bench_id":id,"serial":_serial,"action_serial":action_serial,"body_id":body.get_instance_id()}

## Task58: an abandoned walk or a finished action frees its bench at once, instead of
## holding it until some deadline. Only the exact owner may drop its reservation.
func release_reservation(lease: Dictionary, searcher: RefCounted, body: CharacterBody3D, reason: String) -> void:
	var id: int = int(lease.get("bench_id",0)); var claim: Dictionary = _claims.get(id,{})
	if claim.is_empty() or str(claim.get("mode","ambient")) != "reserved": return
	if claim.serial != lease.get("serial"): return
	if claim.owner.get_ref() != searcher: return
	if is_instance_valid(body) and claim.body.get_ref() != body: return
	_drop(id,"reservation_"+reason,false)

func _reserved_owner_live(claim: Dictionary) -> bool:
	var owner: Variant = claim.owner.get_ref()
	var body: Variant = claim.body.get_ref()
	# The owner is the resident that chose this place. The seat lives exactly as long as
	# that resident is present and still holds it - no second-scale deadline exists.
	if not is_instance_valid(owner) or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): _drop(int(claim.get("bench_id",0)),"bench_seat_owner_removed",true); return false
	return true

func claim(row: Dictionary, owner: RefCounted, body: CharacterBody3D, action_serial: int) -> Dictionary:
	var id: int = int(row.get("bench_id",0))
	if not Thread.is_main_thread() or not _rows.has(id) or not current(row) or not is_instance_valid(owner) or not is_instance_valid(body) or _live(id): return {}
	_serial += 1
	var now: int = Time.get_ticks_msec()
	_claims[id] = {"serial":_serial,"action_serial":action_serial,"owner":weakref(owner),"body":weakref(body),"body_id":body.get_instance_id(),"phase":"APPROACH","approach_deadline":now+APPROACH_MS,"heartbeat_deadline":now+HEARTBEAT_MS,"anchor":Vector3.ZERO}
	return {"bench_id":id,"serial":_serial,"action_serial":action_serial,"body_id":body.get_instance_id()}

func matches(lease: Dictionary, owner: RefCounted, body: CharacterBody3D) -> bool:
	if lease.is_empty() or not is_instance_valid(body): return false
	var claim: Dictionary = _claims.get(int(lease.get("bench_id",0)),{})
	return not claim.is_empty() and claim.serial == lease.get("serial") and claim.action_serial == lease.get("action_serial") and claim.body_id == body.get_instance_id() and claim.owner.get_ref() == owner and claim.body.get_ref() == body

func renew(lease: Dictionary, owner: RefCounted, body: CharacterBody3D) -> bool:
	if not matches(lease,owner,body) or not _live(int(lease.bench_id)): return false
	_claims[int(lease.bench_id)].heartbeat_deadline = Time.get_ticks_msec()+HEARTBEAT_MS
	return true

func occupy(lease: Dictionary, owner: RefCounted, body: CharacterBody3D, approach: Vector3) -> bool:
	if not renew(lease,owner,body) or not body.is_on_floor() or body.global_position.distance_to(approach) > .04: return false
	var claim: Dictionary = _claims[int(lease.bench_id)]
	claim.phase = "OCCUPIED"; claim.anchor = body.global_position
	return true

func release(lease: Dictionary, owner: RefCounted, body: CharacterBody3D) -> void:
	# Cancellation on a freed body still compares the exact weak owner + serial.
	if lease.is_empty(): return
	var id: int = int(lease.get("bench_id",0)); var claim: Dictionary = _claims.get(id,{})
	if claim.is_empty() or claim.serial != lease.get("serial") or claim.owner.get_ref() != owner: return
	if is_instance_valid(body) and claim.body.get_ref() != body: return
	_drop(id,"released",false)

func snapshot() -> Dictionary:
	var occupied := 0
	var reserved := 0
	for claim: Dictionary in _claims.values():
		if str(claim.get("mode","ambient")) == "leisure": reserved += 1
		elif claim.phase == "OCCUPIED": occupied += 1
	return {"scene_scans":_scans,"benches":_rows.size(),"claims":_claims.size(),"occupied":occupied,"reserved":reserved,"slots_per_bench":1}
