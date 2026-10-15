extends RefCounted
## Grounded local response proposal. No node, transform or movement ownership.
## CharacterBody has no mass; 60 kg is explicit response tuning, not a solver mass.
const RESPONSE_MASS_KG := 60.0
const DRAG := 5.0
const DURATION := .35
const MAX_SPEED := 2.0
const MAX_TRAVEL := .30
var _velocity := Vector3.ZERO
var _remaining := 0.0
var _budget := 0.0
var _epoch := -1

func add(direction: Vector3, strength_ns: float, epoch: int) -> bool:
	if not direction.is_finite() or not is_finite(strength_ns) or strength_ns<=0.0 or strength_ns>120.0 or epoch<0:return false
	var flat := Vector3(direction.x,0.0,direction.z)
	if flat.length_squared()<.000001:return false
	if epoch!=_epoch:clear()
	_epoch=epoch
	_velocity=(_velocity+flat.normalized()*(strength_ns/RESPONSE_MASS_KG)).limit_length(MAX_SPEED)
	_remaining=DURATION
	_budget=MAX_TRAVEL
	return true

func sample_velocity(delta: float,epoch: int) -> Vector3:
	if epoch!=_epoch or not is_finite(delta) or delta<=0.0 or delta>.05:clear();return Vector3.ZERO
	if _remaining<=0.0 or _budget<=0.0:return Vector3.ZERO
	var dt := minf(delta,_remaining)
	var attenuation := exp(-DRAG*dt)
	var displacement := (_velocity*((1.0-attenuation)/DRAG)).limit_length(_budget)
	_velocity*=attenuation;_remaining-=dt;_budget=maxf(0.0,_budget-displacement.length())
	return displacement/delta

func clear() -> void:
	_velocity=Vector3.ZERO;_remaining=0.0;_budget=0.0;_epoch=-1

func snapshot() -> Dictionary:
	return {"velocity":_velocity,"remaining":_remaining,"budget":_budget,"epoch":_epoch}
