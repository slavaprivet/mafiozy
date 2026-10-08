extends RefCounted
## Port of water_interaction_inputs.mjs hero branch. Read-only, source metres.
## Node origin must already represent source-normalized feet, not an ankle bone.
var _previous: Dictionary = {}
var _widths: Dictionary = {}

func reset() -> void:
	_previous.clear() # Source reset keeps cached immutable source bounds.

func sample(hero: Node3D, dt: float, state: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(hero):
		_previous.clear()
		return {}
	var position := hero.global_position
	var owner: Object = state.get("hero_owner", hero)
	if not is_instance_valid(owner): owner = hero
	var key := owner.get_instance_id()
	if not _widths.has(key):
		# WeakMap equivalent cleanup only when a new hero wrapper is encountered.
		for cached_key in _widths.keys():
			if _widths[cached_key].object.get_ref() == null: _widths.erase(cached_key)
		var width := 0.0
		var diagnostics: Callable = state.get("diagnostics", Callable())
		if diagnostics.is_valid():
			var data: Dictionary = diagnostics.call()
			var bounds: Dictionary = data.get("sourceBounds", {})
			var low: Array = bounds.get("min", [])
			var high: Array = bounds.get("max", [])
			var scale_value: Variant = state.get("source_scale", 1.0)
			var scale_number := _positive(scale_value)
			if scale_number <= 0.0: scale_number = 1.0
			if low.size() >= 1 and high.size() >= 1 and _finite(low[0]) and _finite(high[0]):
				width = _positive((float(high[0]) - float(low[0])) * scale_number)
		_widths[key] = {"object": weakref(owner), "width": width}
	# Walk reads/caches hero wrapper bounds before add() filters invalid position.
	if not position.is_finite():
		_previous.clear() # Source seen-set pruning drops invalid/missing actors.
		return {}
	var enabled := not _source_truthy(state.get("occupied_seat", null)) and not _source_truthy(state.get("transition", null))
	var old_node: Object = _previous.get("object").get_ref() if _previous.has("object") else null
	var valid_dt := is_finite(dt) and dt > 0.0 and dt <= 0.25
	var moved := position.distance_to(_previous.position) if not _previous.is_empty() else 0.0
	var teleported: bool = _source_truthy(state.get("teleport", false)) or _previous.is_empty() or old_node != hero or _previous.get("enabled") != enabled or not valid_dt or moved > 12.0
	var result := {"id": "hero", "kind": "hero", "position": position,
		"yaw": hero.rotation.y if is_finite(hero.rotation.y) else 0.0,
		"contactOffsetY": 0.0, "enabled": enabled, "teleport": teleported}
	var mass := _positive(state.get("mass_kg", null))
	if mass <= 0.0 and hero.has_meta("massKg"): mass = _positive(hero.get_meta("massKg"))
	if mass > 0.0: result.massKg = mass
	var width: float = _widths[key].width
	if width > 0.0: result.footprint = {"width": width, "length": width}
	if not teleported:
		var velocity: Vector3 = (position - _previous.position) / dt
		if _finite(state.get("vertical_velocity", null)): velocity.y = float(state.vertical_velocity)
		result.velocity = velocity
	var node_reference: WeakRef = _previous.object if old_node == hero else weakref(hero)
	_previous = {"position": position, "object": node_reference, "enabled": enabled}
	return result

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _positive(value: Variant) -> float:
	return float(value) if _finite(value) and float(value) > 0.0 else 0.0

static func _source_truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return float(value) != 0.0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true # JS objects/arrays, including an empty transition object, are truthy.
