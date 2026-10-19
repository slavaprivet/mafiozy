extends RefCounted
## Explicit Walk updateWaterInteractions/clearContent adapter; no scene loop installed.
## Dependencies injected by their owners. Hero transforms and solver stay read-only.
var _sampler: RefCounted
var _effects: Node3D

func bind(sampler: RefCounted, effects: Node3D) -> bool:
	if _sampler != null or is_instance_valid(_effects): return false
	if sampler == null or not sampler.has_method("sample") or not sampler.has_method("reset"): return false
	if not is_instance_valid(effects) or not effects.has_method("advance") or not effects.has_method("get_ripples") or not effects.has_method("dispose"): return false
	_sampler = sampler
	_effects = effects
	return true

func advance(hero: Node3D, dt: float, state: Dictionary = {}, focus: Variant = null) -> Dictionary:
	# Walk does not advance sampler history while waterEffects is unavailable.
	if _sampler == null or not is_instance_valid(_effects): return {}
	var actor: Dictionary = _sampler.sample(hero, dt, state)
	var input := {"hero": actor if not actor.is_empty() else null}
	if is_instance_valid(hero): input.focus = hero.global_position
	elif focus != null: input.focus = focus
	_effects.advance(dt, input)
	return {"hero": actor, "ripples": _effects.get_ripples()}

func reset_sampler() -> void:
	# Source inspection prepare resets input; teleport on next sample suppresses FX.
	if _sampler != null: _sampler.reset()

func clear_content() -> void:
	# Source content cleanup disposes effects and resets sampler. Caller frees Node.
	if is_instance_valid(_effects): _effects.dispose()
	if _sampler != null: _sampler.reset()
	_effects = null
	_sampler = null
