extends RefCounted
## Pure source burn-color planner. Eligibility is supplied by the host and is
## not an authority receipt. Values remain linear Float64; native albedo
## conversion and alpha preservation belong to the material integration seam.

# Three r180 Color('#100f0e') in Linear-sRGB, pinned by source_burn_oracle.json.
const LERP_ALPHA:=0.94
const BURNED_ROUGHNESS:=0.99

static func plan(current_linear_rgb: Variant,captured_opaque_eligible: Variant) -> Dictionary:
	if not current_linear_rgb is PackedFloat64Array or current_linear_rgb.size()!=3: return {"ok":false,"error":"rgb"}
	for value in current_linear_rgb:
		if not is_finite(float(value)): return {"ok":false,"error":"rgb"}
	if not captured_opaque_eligible is bool: return {"ok":false,"error":"eligibility"}
	var current: PackedFloat64Array=current_linear_rgb
	if not captured_opaque_eligible:
		return {"ok":true,"apply_burn":false,"linear_rgb":current.duplicate(),"alpha_unchanged":true}
	# Keep the exact source operation order: channel += (target-channel)*.94.
	# Decode pinned Three bytes locally. GDScript's decimal constant conversion
	# rounds these target channels one ULP away from the JavaScript values.
	var target:=target_linear_rgb()
	var burned:=PackedFloat64Array([
		current[0]+(target[0]-current[0])*LERP_ALPHA,
		current[1]+(target[1]-current[1])*LERP_ALPHA,
		current[2]+(target[2]-current[2])*LERP_ALPHA,
	])
	for value in burned:
		if not is_finite(float(value)): return {"ok":false,"error":"nonfinite_result"}
	return {"ok":true,"apply_burn":true,"linear_rgb":burned,"roughness":BURNED_ROUGHNESS,"alpha_unchanged":true}

static func target_linear_rgb() -> PackedFloat64Array:
	var bytes:=PackedByteArray([177,187,83,204,54,57,117,63,249,134,111,175,255,144,115,63,9,184,200,190,194,252,113,63])
	return PackedFloat64Array([bytes.decode_double(0),bytes.decode_double(8),bytes.decode_double(16)])
