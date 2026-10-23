extends RefCounted
## Godot resource seam for a sampled time-of-day frame.
## It owns no clock, weather, interior decision, nodes or resources.

var environment: Environment
var atmosphere: ProceduralSkyMaterial
var sun: DirectionalLight3D
var applied_frames := 0
var skipped_interior_frames := 0
var disposed := false


func configure(target_environment: Environment, target_atmosphere: ProceduralSkyMaterial,
		target_sun: DirectionalLight3D) -> bool:
	if disposed or target_environment == null or target_atmosphere == null or target_sun == null:
		return false
	environment = target_environment
	atmosphere = target_atmosphere
	sun = target_sun
	return true


func apply(frame: RefCounted, interior_lighting_active := false) -> bool:
	if disposed or environment == null or atmosphere == null or not is_instance_valid(sun) or frame == null:
		return false
	if interior_lighting_active:
		skipped_interior_frames += 1
		return false

	# The source frame has one sky/background color and a separate ground bounce.
	# Keep the existing procedural-sky resource but avoid inventing a new palette.
	atmosphere.sky_top_color = frame.background
	atmosphere.sky_horizon_color = frame.background
	atmosphere.ground_bottom_color = frame.ambient_ground_color
	atmosphere.ground_horizon_color = frame.ambient_ground_color
	atmosphere.energy_multiplier = frame.environment_intensity

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = frame.ambient_color
	environment.ambient_light_energy = frame.ambient_intensity
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = frame.fog_color
	environment.fog_density = frame.fog_density
	environment.tonemap_exposure = frame.exposure

	sun.light_color = frame.sun_color
	sun.light_energy = frame.sun_intensity
	var direction: Vector3 = -frame.sun_offset.normalized()
	sun.basis = Basis.looking_at(direction, Vector3.UP)
	applied_frames += 1
	return true


func dispose() -> void:
	disposed = true
	environment = null
	atmosphere = null
	sun = null
