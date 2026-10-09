extends RefCounted
## Shared-owner seam for Walk E arbitration. This owns only the gesture latch.
## The actual seat/transition owner retains its 0.3-second hold/exit behavior.
## It must reserve_e_press() BEFORE a synchronous entry/exit changes its state.
## No proximity inference, vehicle exit request, physics or water simulation.
var _providers: Dictionary = {}
var _reserved := false

func configure(providers: Dictionary) -> bool:
	for name in providers:
		if not providers[name] is Callable or not providers[name].is_valid():
			return false
	_providers = providers.duplicate()
	return true

func _call(name: String,args: Array = [],fallback: Variant = null) -> Variant:
	var callback: Callable = _providers.get(name,Callable())
	return callback.callv(args) if callback.is_valid() else fallback

func _truth(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is String:
		return not value.is_empty()
	if value is int or value is float:
		return value!=0 and not is_nan(float(value))
	return true

func vehicle_context() -> bool:
	# mercenary_walk.mjs vehicleCommandContext, also the source hideOwned provider.
	return _call("is_player_in_vehicle",[],false)==true or _truth(_call("get_player_vehicle"))

func live_transport_context() -> bool:
	# walk_preview guards occupiedSeat/sourceVehicleActive/transition as well.
	return vehicle_context() or _truth(_call("get_occupied_seat")) \
		or _call("is_source_vehicle_active",[],false)==true \
		or _truth(_call("get_vehicle_transition"))

func reserve_e_press() -> void:
	_reserved = true

func release_controls() -> void:
	_reserved = false
	# Actual transport owner clears its hold/rearm bookkeeping; no exit is requested.
	_call("release_transport_controls")

func observe_key(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode!=KEY_E:
		return
	if not event.pressed:
		_reserved = false
	elif live_transport_context():
		reserve_e_press()
	# Every press/repeat/release continues to the real vehicle input owner.

func transport_interaction() -> bool:
	return live_transport_context() or _reserved or _call("is_e_press_reserved",[],false)==true

func has_priority_interaction(fresh: bool) -> bool:
	return transport_interaction() or _call("has_priority_interaction",[fresh],false)==true

func dispose() -> void:
	_providers.clear()
	_reserved = false
