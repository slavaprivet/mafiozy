extends Node
## Presentation only. The caller owns the clock and the bounded update cadence.
## No world traversal, allocations, or processing loop is needed after configure().

const ORBIT_TILT := deg_to_rad(65.0)
const ORBIT_AZIMUTH := deg_to_rad(-32.0)
const SKY_STEP_HOURS := 1.0 / 120.0
const NIGHT_TOP := Color("0b1429")
const NIGHT_HORIZON := Color("18273f")
const NIGHT_GROUND := Color("10192a")
const TWILIGHT_TOP := Color("685979")
const TWILIGHT_HORIZON := Color("e69760")
const NIGHT_AMBIENT := Color("8095b3")
const MOON_COLOR := Color("bbcfff")
const MOON_ENERGY := 0.5
const NIGHT_AMBIENT_ENERGY := 0.35
const SKY_FILL_ENERGY := 0.25
const SKY_FILL_COLOR := Color("aebcdb")
const HORIZON_SUN := Color("ff9e53")

var world: Node3D
var world_environment: WorldEnvironment
var environment: Environment
var sky: Sky
var atmosphere: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_fill: DirectionalLight3D
var enabled := false
var hour := 12.0
var daylight := 1.0
var twilight := 0.0
var solar_direction := Vector3.UP
var sun_elevation_degrees := 65.0
var apply_count := 0
var sky_update_count := 0

var _original_environment: Environment
var _original_sun_transform := Transform3D.IDENTITY
var _original_sun_color := Color.WHITE
var _original_sun_energy := 1.5
var _original_sun_sky_mode := 0
var _day_top := Color("738eaf")
var _day_horizon := Color("c6cfce")
var _day_ground := Color("484c46")
var _day_ground_horizon := Color("bec7c7")
var _day_ambient_energy := 0.65
var _last_sky_bucket := -1


func configure(game: Node3D) -> bool:
	if enabled or not is_instance_valid(game):
		return false
	world_environment = null
	sun = null
	for child in game.get_children():
		if child is WorldEnvironment and world_environment == null:
			world_environment = child
		elif child is DirectionalLight3D and child.name == &"AfternoonSun":
			sun = child
	if not is_instance_valid(world_environment) or not is_instance_valid(sun):
		return false
	_original_environment = world_environment.environment
	if _original_environment == null or _original_environment.sky == null:
		return false
	if not _original_environment.sky.sky_material is ProceduralSkyMaterial:
		return false
	world = game
	_original_sun_transform = sun.transform
	_original_sun_color = sun.light_color
	_original_sun_energy = sun.light_energy
	_original_sun_sky_mode = sun.sky_mode
	_day_ambient_energy = _original_environment.ambient_light_energy
	# Copy the original native shadow settings exactly: the night key light
	# must preserve the player's/NPCs' shape and contact shadows, not flatten them.
	moon = sun.duplicate(0) as DirectionalLight3D
	for child in moon.get_children():
		moon.remove_child(child)
		child.free()
	moon.name = "Moonlight"
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.light_color = MOON_COLOR
	moon.light_energy = 0.0
	moon.visible = false
	world.add_child(moon)
	# Replace part of the uniform night fill with normal-sensitive sky light.
	# Its world-space direction is opposite the moon in azimuth, always above
	# the horizon. It retains facial/clothing form without another shadow pass.
	sky_fill = DirectionalLight3D.new()
	sky_fill.name = "NightSkyFill"
	sky_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sky_fill.light_color = SKY_FILL_COLOR
	sky_fill.light_bake_mode = Light3D.BAKE_DISABLED
	sky_fill.shadow_enabled = false
	sky_fill.light_energy = 0.0
	sky_fill.visible = false
	world.add_child(sky_fill)
	# Keep the existing reflection resolution and quality, amortizing filtering
	# over several frames rather than rebuilding all roughness levels at once.
	environment = _original_environment.duplicate(false) as Environment
	sky = _original_environment.sky.duplicate(false) as Sky
	atmosphere = _original_environment.sky.sky_material.duplicate(false) as ProceduralSkyMaterial
	_day_top = atmosphere.sky_top_color
	_day_horizon = atmosphere.sky_horizon_color
	_day_ground = atmosphere.ground_bottom_color
	_day_ground_horizon = atmosphere.ground_horizon_color
	sky.sky_material = atmosphere
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = NIGHT_AMBIENT
	# A compact sky sun gives a visible disc without enabling PCSS soft shadows
	# through light_angular_distance. The existing shadow settings stay intact.
	atmosphere.sun_angle_max = 1.25
	atmosphere.sun_curve = 0.12
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	world_environment.environment = environment
	_last_sky_bucket = -1
	apply_count = 0
	sky_update_count = 0
	enabled = true
	return true


func apply_hour(value: float) -> void:
	if not enabled or not is_finite(value) or not is_instance_valid(sun):
		return
	hour = fposmod(value, 24.0)
	var orbit_angle := (hour - 6.0) * TAU / 24.0
	# Sunrise is east at 06:00, sunset west at 18:00. A tilted orbit avoids a
	# look-at singularity at noon while taking the sun below the earth at night.
	solar_direction = Vector3(cos(orbit_angle), sin(orbit_angle) * sin(ORBIT_TILT),
		sin(orbit_angle) * cos(ORBIT_TILT)).rotated(Vector3.UP, ORBIT_AZIMUTH).normalized()
	sun_elevation_degrees = rad_to_deg(asin(clampf(solar_direction.y, -1.0, 1.0)))
	sun.global_basis = Basis.looking_at(-solar_direction, Vector3.UP)
	var height := solar_direction.y
	daylight = smoothstep(-0.12, 0.30, height)
	twilight = 1.0 - smoothstep(0.015, 0.34, absf(height))
	var direct := smoothstep(-0.015, 0.0, height) * lerpf(0.20, 1.0, smoothstep(0.0, 0.35, height))
	sun.light_energy = _original_sun_energy * direct
	sun.light_color = _original_sun_color.lerp(HORIZON_SUN, twilight)
	if is_instance_valid(moon):
		moon.global_basis = Basis.looking_at(solar_direction, Vector3.UP)
		moon.light_energy = MOON_ENERGY * smoothstep(0.0, 0.20, -height)
		moon.visible = moon.light_energy > 0.0001
	if is_instance_valid(sky_fill):
		var fill_direction := Vector3(solar_direction.x, 0.45, solar_direction.z).normalized()
		sky_fill.global_basis = Basis.looking_at(-fill_direction, Vector3.UP)
		sky_fill.light_energy = SKY_FILL_ENERGY * smoothstep(0.0, 0.20, -height)
		sky_fill.visible = sky_fill.light_energy > 0.0001
	environment.ambient_light_energy = lerpf(NIGHT_AMBIENT_ENERGY, _day_ambient_energy, daylight)
	# Color-based blue fill keeps night readable independently of the dark sky.
	# At full daylight the exact original sky-based ambient is restored.
	environment.ambient_light_sky_contribution = daylight
	apply_count += 1
	# A half-game-minute palette step is imperceptible at the natural clock
	# speed, but avoids invalidating sky radiance for tiny color changes.
	var bucket := int(floor(hour / SKY_STEP_HOURS))
	if bucket == _last_sky_bucket:
		return
	_last_sky_bucket = bucket
	_update_sky()


func _update_sky() -> void:
	atmosphere.sky_top_color = NIGHT_TOP.lerp(_day_top, daylight).lerp(TWILIGHT_TOP, twilight * 0.38)
	atmosphere.sky_horizon_color = NIGHT_HORIZON.lerp(_day_horizon, daylight).lerp(TWILIGHT_HORIZON, twilight * 0.83)
	atmosphere.ground_bottom_color = NIGHT_GROUND.lerp(_day_ground, daylight)
	atmosphere.ground_horizon_color = NIGHT_HORIZON.lerp(_day_ground_horizon, daylight).lerp(TWILIGHT_HORIZON, twilight * 0.50)
	sky_update_count += 1


func snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"hour": hour,
		"daylight": daylight,
		"twilight": twilight,
		"sun_elevation_degrees": sun_elevation_degrees,
		"solar_direction": solar_direction,
		"sun_energy": sun.light_energy if is_instance_valid(sun) else 0.0,
		"moon_energy": moon.light_energy if is_instance_valid(moon) else 0.0,
		"moon_visible": moon.visible if is_instance_valid(moon) else false,
		"sky_fill_energy": sky_fill.light_energy if is_instance_valid(sky_fill) else 0.0,
		"ambient_energy": environment.ambient_light_energy if environment != null else 0.0,
		"sky_updates": sky_update_count,
		"apply_count": apply_count,
	}


func dispose() -> void:
	if not enabled:
		return
	enabled = false
	if is_instance_valid(world_environment) and world_environment.environment == environment:
		world_environment.environment = _original_environment
	if is_instance_valid(sun):
		sun.transform = _original_sun_transform
		sun.light_color = _original_sun_color
		sun.light_energy = _original_sun_energy
		sun.sky_mode = _original_sun_sky_mode
	if is_instance_valid(moon):
		moon.visible = false
		moon.queue_free()
	if is_instance_valid(sky_fill):
		sky_fill.visible = false
		sky_fill.queue_free()
	world = null
	world_environment = null
	sun = null
	moon = null
	sky_fill = null
	environment = null
	sky = null
	atmosphere = null
	_original_environment = null


func _exit_tree() -> void:
	dispose()
