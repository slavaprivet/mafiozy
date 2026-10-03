extends "res://scripts/npc_visual/npc_ragdoll_host.gd"
## OUTPUTS-ONLY, unrun. Explicit configure option; no default/startup enable.
const BLOCKING_BIT := 1024
const BLOCKING_LAYER := 256 | BLOCKING_BIT
const BLOCK_ENGINE_HASH := "ed1daf0bf001b61586d9930840f2f1394092c079"
var _blocking_enabled := false
var _blocking_fault := ""
var _blocking_death_key := ""
var _blocking_player: WeakRef
var _blocking_player_id := 0
var _blocking_player_rid: RID

static func blocking_contract() -> Dictionary:
	return {"ok":true, "schema":"npc_final_dead_contact/v2", "blocking_bit":BLOCKING_BIT, "part_layer":BLOCKING_LAYER, "part_mask":257, "player_layer":2, "world_support_mask":1, "movement_mask":1025, "engine_hash":BLOCK_ENGINE_HASH, "physics_backend":"GodotPhysics3D"}

func _blocking_player_current(active: bool) -> bool:
	var player: CharacterBody3D = _blocking_player.get_ref() if _blocking_player != null else null
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or player.get_instance_id() != _blocking_player_id or player.get_rid() != _blocking_player_rid or not player.has_method("final_dead_block_contract_receipt"): return false
	var receipt: Dictionary = player.final_dead_block_contract_receipt()
	if receipt.get("contract") != blocking_contract() or receipt.get("active") != active or receipt.get("actor_instance_id") != _blocking_player_id or receipt.get("actor_rid") != _blocking_player_rid or receipt.get("actor_layer") != player.collision_layer or receipt.get("actor_mask") != player.collision_mask: return false
	# Once Root bound v2, seat/exit authority may temporarily change player filters.
	# That does not revoke final-dead blocking. Force admission still requires2/1025.
	return active or (player.collision_layer == 2 and player.collision_mask == 1)

static func blocking_backend_current() -> bool:
	var backend: String = str(ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"))
	return str(Engine.get_version_info().get("hash", "")) == BLOCK_ENGINE_HASH and backend in ["DEFAULT", "GodotPhysics3D"]

func configure(token: Dictionary, parent: Node3D, current_binding: Callable, confirmed_events: Callable, options: Dictionary = {}) -> Dictionary:
	var bit: Variant = options.get("final_dead_blocking_bit", 0)
	if not bit is int or bit not in [0, BLOCKING_BIT]: return _result(false, "blocking_allocation")
	if bit == BLOCKING_BIT and (not blocking_backend_current() or options.get("collision_layer", 256) != 256 or options.get("collision_mask", 257) != 257): return _result(false, "blocking_backend_or_base_filters")
	if bit == BLOCKING_BIT:
		var player: CharacterBody3D = options.get("blocking_player") as CharacterBody3D
		if not is_instance_valid(player) or str(player.get_script().resource_path) != "res://scripts/preview_player.gd" or player.get_parent() != parent or player.get_world_3d() != parent.get_world_3d(): return _result(false,"blocking_original_player")
		_blocking_player = weakref(player); _blocking_player_id = player.get_instance_id(); _blocking_player_rid = player.get_rid()
		if not _blocking_player_current(false): return _result(false,"blocking_negotiated_receipt")
	var result: Dictionary = super.configure(token, parent, current_binding, confirmed_events, options)
	if result.get("ok", false): _blocking_enabled = bit == BLOCKING_BIT
	return result

func final_dead_block_contract() -> Dictionary:
	if not Thread.is_main_thread() or not _blocking_enabled or mode in ["UNBOUND", "RETIRED"] or not blocking_backend_current(): return {"ok": false}
	return blocking_contract()

func _install_final_dead_blocking() -> bool:
	if not _blocking_enabled: return true
	if not _blocking_player_current(true): return false
	if not Thread.is_main_thread() or _busy or mode != "ACTIVE" or not _final_dead or _death_key.is_empty() or not _is_current(): return false
	var actor: CharacterBody3D = _actor.get_ref()
	if actor.collision_layer != 0 or actor.collision_mask != 0: return false
	var parts: Array[RigidBody3D] = owned_bodies()
	if parts.size() != 16: return false
	# Validate the whole current pool first; no partially changed collision pool.
	for part: RigidBody3D in parts:
		if not is_instance_valid(part) or not part.is_inside_tree() or part.is_queued_for_deletion() or part.freeze or part.get_world_3d() != actor.get_world_3d(): return false
		if part.collision_layer not in [256, BLOCKING_LAYER] or part.collision_mask != 257: return false
	# No callback between this current-life validation and these synchronous writes.
	# Body.start's configured base layer remains256 for medical/recovery paths.
	for part: RigidBody3D in parts:
		if part.collision_layer == 256: part.collision_layer = BLOCKING_LAYER
	return true

func _blocking_result(result: Dictionary) -> Dictionary:
	if not result.get("ok", false) or not _blocking_enabled or not _final_dead: return result
	var applied: bool = _install_final_dead_blocking()
	_blocking_fault = "" if applied else "final_dead_blocking_admission"
	if applied: _blocking_death_key = _death_key
	result["blocking_ready"] = applied
	result["blocking_error"] = _blocking_fault
	# Physical activation has already committed. Never report it as rolled back
	# or restore a standing collider if only the optional blocking admission fails.
	return result

func activate(event_id: String) -> Dictionary:
	return _blocking_result(super.activate(event_id))

func confirm_final_death(event_id: String) -> Dictionary:
	return _blocking_result(super.confirm_final_death(event_id))

func cancel_recovery(reason := "blocked") -> Dictionary:
	# super.start restores configured layer256. Install B only after its success.
	return _blocking_result(super.cancel_recovery(reason))

func status() -> Dictionary:
	var result: Dictionary = super.status()
	result["blocking_enabled"] = _blocking_enabled
	result["blocking_error"] = _blocking_fault
	result["blocking_death_key"] = _blocking_death_key
	return result
