extends RefCounted

# Exact stepVehiclePanelMotion from vehicle_trunk.mjs, also used by hood.
static func step(amount: float, velocity: float, target: float, delta: float) -> Dictionary:
	if not is_finite(amount) or not is_finite(velocity) or not is_finite(target) or not is_finite(delta) or delta < 0.0 or target not in [0.0, 1.0]:
		return {"code": "INVALID_MOTION"}
	var h := minf(delta, .2)
	var omega := 18.0
	var offset := amount - target
	var blend := (velocity + omega * offset) * h
	var decay := exp(-omega * h)
	var next := clampf(target + (offset + blend) * decay, 0.0, 1.0)
	var speed := (velocity - omega * blend) * decay
	if absf(next - target) < .0002 and absf(speed) < .004:
		next = target
		speed = 0.0
	return {"code": "OK", "amount": next, "velocity": speed}

static func hinge_angle(amount: float, open_angle: float) -> float:
	var t := clampf(amount, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t) * open_angle
