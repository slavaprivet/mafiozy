extends RefCounted
## Presentation input only. The resident host remains the sole gait/yaw writer.
## The physical mover publishes measured endpoints AFTER move_and_slide(), not
## its requested velocity. Stale frames, replacement bodies and later movement
## reject this input rather than animating a blocked or different resident.
const META := "npc_physical_drive51"
const TREATMENT_META := "npc_treatment28"


static func consume(body: CharacterBody3D, delta: float) -> Dictionary:
	if not is_instance_valid(body) or not body.has_meta(META): return {}
	if not is_finite(delta) or delta <= 0.0: return {}
	var sample: Variant = body.get_meta(META)
	if not sample is Dictionary: return {}
	if int(sample.get("frame", -1)) != Engine.get_physics_frames(): return {}
	if int(sample.get("body_id", -1)) != body.get_instance_id(): return {}
	var source_delta: float = float(sample.get("delta", 0.0))
	if not is_finite(source_delta) or source_delta <= 0.0 or absf(source_delta - delta) > .00001: return {}
	var first: Variant = sample.get("from")
	var last: Variant = sample.get("to")
	if not first is Vector3 or not last is Vector3: return {}
	var start: Vector3 = first
	var finish: Vector3 = last
	if not start.is_finite() or not finish.is_finite(): return {}
	if finish.distance_squared_to(body.global_position) > .000004: return {}
	var measured: Vector3 = finish - start
	measured.y = 0.0
	return {"active": true, "horizontal": measured}


## The life owner publishes this only after proving actual hospital TREATING.
## A current stopped physical sample is required; route intent cannot start a gesture.
static func treatment(body: CharacterBody3D, delta: float, physical: Dictionary) -> Dictionary:
	if physical.is_empty(): return {}
	if not is_instance_valid(body) or not body.is_inside_tree() or not body.is_on_floor(): return {}
	if not physical.get("horizontal") is Vector3 or not is_finite(delta) or delta <= 0.0: return {}
	if Vector3(physical.horizontal).length() / delta > .05: return {}
	if not body.has_meta(TREATMENT_META): return {}
	var sample: Variant = body.get_meta(TREATMENT_META)
	if not sample is Dictionary or not bool(sample.get("active", false)) or str(sample.get("kind", "")) != "hospital": return {}
	if int(sample.get("frame", -1)) != Engine.get_physics_frames() or int(sample.get("body_id", -1)) != body.get_instance_id(): return {}
	var source_delta: float = float(sample.get("delta", 0.0))
	if not is_finite(source_delta) or absf(source_delta - delta) > .00001: return {}
	var elapsed: float = float(sample.get("elapsed_s", -1.0))
	var duration: float = float(sample.get("duration_s", 1.5))
	if not is_finite(elapsed) or not is_finite(duration) or duration <= .5 or elapsed < 0.0 or elapsed > duration: return {}
	return {"active":true, "elapsed_s":elapsed, "duration_s":duration}
