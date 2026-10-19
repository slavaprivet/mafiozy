extends RefCounted
## Hero branch of water_interaction_fx.mjs. Explicit caller-owned advance, metres.
## Fixed particle objects; borrowed water samples; no nodes, solver or file I/O.
const RIPPLE_START := 0.08
const RIPPLE_SPEED := 1.35
const RIPPLE_LIFETIME := 4.5

class Particle extends RefCounted:
	var active := false
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var age := 0.0
	var life := 0.0
	var radius := 0.0
	var strength := 0.0
	var angle := 0.0

var droplets: Array[Particle] = []
var rings: Array[Particle] = []
var foam: Array[Particle] = []
var water_at: Callable
var ground_height: Callable
var random_callback: Callable
var gravity := 9.81
var drag := 0.65
var max_distance := 100.0
var disposed := false
var configured := false
var now := 0.0
var water_samples := 0
var particle_objects_created := 0
var bursts := 0
var impacts := 0
var wakes := 0
var emitted_droplets := 0
var recontacts := 0
var suppressed := 0
var peak_droplets := 0
var _budget := 0
var _tracked := false
var _hero_id := ""
var _px := 0.0
var _py := 0.0
var _pz := 0.0
var _contact_y := 0.0
var _wet := false
var _travel := 0.0

static func _finite(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))

static func number(v: Variant, fallback: float = 0.0) -> float:
	return float(v) if _finite(v) else fallback

static func point_valid(v: Variant) -> bool:
	if v is Vector3: return v.is_finite()
	return v is Dictionary and _finite(v.get("x")) and _finite(v.get("y")) and _finite(v.get("z"))

static func _truthy(v: Variant) -> bool:
	if v == null: return false
	if v is bool: return v
	if v is String: return not v.is_empty()
	if v is int or v is float: return float(v) != 0.0 and not is_nan(float(v))
	return true

static func ripple_radius(age: float) -> float:
	return RIPPLE_START + maxf(0.0, number(age)) * RIPPLE_SPEED

func configure(options: Dictionary) -> bool:
	if configured or disposed or not options.get("waterAt") is Callable: return false
	water_at = options.waterAt
	if not water_at.is_valid(): return false
	ground_height = options.get("groundHeight", Callable())
	random_callback = options.get("random", Callable())
	gravity = number(options.get("gravity"), 9.81)
	drag = number(options.get("drag"), 0.65)
	max_distance = clampf(number(options.get("maxDistance"), 100), 1, 1000)
	_fill(droplets, clampi(int(floor(number(options.get("maxDroplets"), 240))), 0, 1024))
	_fill(rings, clampi(int(floor(number(options.get("maxRings"), 24))), 0, 64))
	_fill(foam, clampi(int(floor(number(options.get("maxFoam"), 72))), 0, 256))
	configured = true
	return true

func _fill(list: Array[Particle], count: int) -> void:
	for i in range(count): list.append(Particle.new())
	particle_objects_created += count

func _rnd() -> float:
	return clampf(number(random_callback.call() if random_callback.is_valid() else randf(), 0.5), 0, 0.999999)

func depth(w: Dictionary) -> float:
	if _finite(w.get("depth")): return float(w.depth)
	return float(w.level) - float(w.floor) if _finite(w.get("floor")) else 0.0

func sample(x: float, z: float) -> Variant:
	water_samples += 1
	var w: Variant = water_at.call(x, z)
	if not w is Dictionary or not _finite(w.get("level")): return null
	return w if depth(w) > 0.012 else null

func _take(list: Array[Particle]) -> Particle:
	if list.is_empty(): return null
	var oldest: Particle = list[0]
	for p in list:
		if not p.active: return p
		if p.age > oldest.age: oldest = p
	return oldest

func _ring(x: float, z: float, y: float, strength: float) -> void:
	var p := _take(rings)
	if p == null: return
	p.active = true; p.x = x; p.z = z; p.y = y + 0.016
	p.age = 0; p.life = RIPPLE_LIFETIME; p.strength = clampf(strength, 0, 2); p.radius = ripple_radius(0)

func _foam_at(x: float, z: float, y: float, strength: float) -> void:
	var p := _take(foam)
	if p == null or sample(x, z) == null: return
	p.active = true; p.x = x; p.z = z; p.y = y + 0.022; p.age = 0
	p.life = 0.5 + _rnd() * 0.8; p.radius = 0.05 + minf(0.24, strength * 0.05); p.angle = _rnd() * TAU

func _burst(x: float, z: float, vx: float, vy: float, vz: float, mass: float, water_depth: float, wake: bool) -> void:
	var w: Variant = sample(x, z)
	if w == null: return
	var horizontal := sqrt(vx * vx + vz * vz)
	var down := maxf(0, -vy)
	var depth_scale := clampf(sqrt(maxf(0, water_depth) / 0.6), 0.12, 1)
	var energy := 0.5 * mass * (down * down + 0.08 * horizontal * horizontal) * depth_scale
	var power := clampf(log(1 + energy / 35), 0.12, 5)
	var strength := clampf((0.08 if wake else 0.28) + power * (0.14 if wake else 0.3), 0.08, 2)
	var count := mini(_budget, int(floor((2 if wake else 5) + power * 4)))
	if count == 0: return
	_budget -= count; bursts += 1
	if wake: wakes += 1
	else: impacts += 1
	_ring(x, z, w.level, strength)
	for i in range(count):
		var p := _take(droplets)
		if p == null: break
		var angle := _rnd() * TAU
		var side := 0.4 + power * (0.25 + _rnd() * 0.35)
		var up := (0.3 if wake else 0.65) + power * (0.24 + _rnd() * 0.42)
		p.vx = sin(angle) * side + vx * 0.18; p.vz = cos(angle) * side + vz * 0.18; p.vy = up
		p.active = true; p.x = x + (_rnd() - 0.5) * 0.12; p.y = w.level + 0.03; p.z = z + (_rnd() - 0.5) * 0.12
		p.radius = 0.014 + _rnd() * 0.027; p.age = 0; p.life = 1.2 + power * 0.28
		emitted_droplets += 1
	_foam_at(x, z, w.level, power)

func _step_particles(dt: float) -> void:
	var steps := maxi(1, int(ceil(dt / (1.0 / 60))))
	var h := dt / steps
	var damping := exp(-maxf(0, drag) * h)
	for s in range(steps):
		for p in droplets:
			if not p.active: continue
			var before_y := p.y
			p.age += h; p.vx *= damping; p.vz *= damping; p.vy = p.vy * damping - maxf(0, gravity) * h
			p.x += p.vx * h; p.y += p.vy * h; p.z += p.vz * h
			var w: Variant = sample(p.x, p.z)
			if w != null and p.vy < 0 and before_y > float(w.level) and p.y <= float(w.level):
				p.active = false; recontacts += 1; _foam_at(p.x, p.z, w.level, 0.3)
				if _rnd() < 0.16: _ring(p.x, p.z, w.level, 0.08)
			elif p.age >= p.life or p.y < -1000 or (w == null and ground_height.is_valid() and p.y <= number(ground_height.call(p.x, p.z), -INF)):
				p.active = false
	for p in rings:
		if not p.active: continue
		p.age += dt; p.radius = ripple_radius(p.age)
		if p.age >= p.life: p.active = false
	for p in foam:
		if not p.active: continue
		p.age += dt
		if p.age >= p.life or sample(p.x, p.z) == null: p.active = false

func _observe(hero: Variant, raw_dt: float, focus: Variant) -> void:
	if not hero is Dictionary or (hero.get("enabled") is bool and hero.enabled == false) or not point_valid(hero.get("position")):
		_tracked = false; return
	var p: Variant = hero.position
	var x: float = p.x; var y: float = p.y; var z: float = p.z
	if focus is Dictionary or focus is Vector3:
		var focus_x := number(focus.get("x"),NAN) if focus is Dictionary else number(focus.x,NAN)
		var focus_z := number(focus.get("z"),NAN) if focus is Dictionary else number(focus.z,NAN)
		if sqrt(pow(x - focus_x, 2) + pow(z - focus_z, 2)) > max_distance:
			_tracked = false; return
	var id_value: Variant = hero.get("id", "player")
	var hero_id := "hero:" + str(id_value if id_value != null else "player")
	var contact_y := y + number(hero.get("contactOffsetY"))
	var w: Variant = sample(x, z)
	var wet := w != null and contact_y <= float(w.level) + 0.045
	var movement := sqrt(pow(x - _px, 2) + pow(y - _py, 2) + pow(z - _pz, 2)) if _tracked else 0.0
	var actor_velocity: Variant = hero.get("velocity")
	var speed := 0.0
	if point_valid(actor_velocity): speed = sqrt(pow(float(actor_velocity.x), 2) + pow(float(actor_velocity.y), 2) + pow(float(actor_velocity.z), 2))
	if not _tracked or hero_id != _hero_id or _truthy(hero.get("teleport")) or raw_dt > 0.25 or movement > maxf(8, speed * raw_dt * 2 + 2):
		suppressed += 1; _travel = 0
	else:
		var vx := (x - _px) / raw_dt; var vy := (y - _py) / raw_dt; var vz := (z - _pz) / raw_dt
		if (actor_velocity is Dictionary and _finite(actor_velocity.get("y"))) or (actor_velocity is Vector3 and is_finite(actor_velocity.y)):
			vy = minf(vy, float(actor_velocity.y))
		var horizontal := sqrt(vx * vx + vz * vz)
		var mass := clampf(number(hero.get("massKg"), 80), 10, 20000)
		var entered := false
		if not _wet:
			var contact_distance := sqrt(pow(x - _px, 2) + pow(contact_y - _contact_y, 2) + pow(z - _pz, 2))
			var steps := clampi(int(ceil(contact_distance / 0.22)), 1, 40)
			for i in range(1, steps + 1):
				var t := float(i) / steps
				var hx := lerpf(_px, x, t); var hy := lerpf(_contact_y, contact_y, t); var hz := lerpf(_pz, z, t)
				var hit: Variant = sample(hx, hz)
				if hit == null or hy > float(hit.level) + 0.045: continue
				var impact := maxf(0, -vy) > 1.35
				if impact or horizontal > 0.35:
					_burst(hx, hz, vx, vy, vz, mass, depth(hit), not impact); entered = true
				break
		_travel += sqrt(pow(x - _px, 2) + pow(z - _pz, 2))
		if not entered and horizontal > 0.35 and _travel >= 0.55:
			if wet: _burst(x, z, vx, vy, vz, mass, depth(w), true)
			_travel = fmod(_travel, 0.55)
		if entered or not wet or horizontal < 0.1: _travel = 0
	_tracked = true; _hero_id = hero_id; _px = x; _py = y; _pz = z; _contact_y = contact_y; _wet = wet

func update(dt: float, input: Dictionary = {}) -> void:
	if disposed or not configured or not is_finite(dt) or dt <= 0: return
	var bounded_dt := clampf(dt, 0, 1.0 / 15)
	now += bounded_dt; _budget = 96
	_step_particles(bounded_dt)
	_observe(input.get("hero"), dt, input.get("focus"))
	peak_droplets = maxi(peak_droplets, _active_count(droplets))

static func _active_count(list: Array[Particle]) -> int:
	var count := 0
	for p in list:
		if p.active: count += 1
	return count

func get_ripples() -> Array[Dictionary]:
	var selected: Array[int] = []
	for i in range(rings.size()):
		var p: Particle = rings[i]
		if p.active and p.age < RIPPLE_LIFETIME: selected.append(i)
	# JS Array.sort is stable: ties keep original ring-pool order. Godot's sort
	# does not guarantee stability, so use the pool index as the explicit tie key.
	selected.sort_custom(func(a: int, b: int) -> bool:
		var score_a := rings[a].strength * (1 - rings[a].age / RIPPLE_LIFETIME)
		var score_b := rings[b].strength * (1 - rings[b].age / RIPPLE_LIFETIME)
		return a < b if score_a == score_b else score_a > score_b)
	var result: Array[Dictionary] = []
	for i in range(mini(8, selected.size())):
		var p: Particle = rings[selected[i]]
		result.append({"x":p.x,"z":p.z,"y":p.y,"age":p.age,"strength":p.strength,"radius":p.radius,"duration":RIPPLE_LIFETIME})
	return result

func stats() -> Dictionary:
	return {"bursts":bursts,"impacts":impacts,"wakes":wakes,"droplets":emitted_droplets,"recontacts":recontacts,"suppressed":suppressed,"peakDroplets":peak_droplets,
		"activeDroplets":_active_count(droplets),"activeRings":_active_count(rings),"activeFoam":_active_count(foam),"trackedActors":int(_tracked),
		"maxDroplets":droplets.size(),"maxRings":rings.size(),"maxFoam":foam.size(),"time":now,"disposed":disposed,
		"waterSamples":water_samples,"particleObjectsCreated":particle_objects_created}

func dispose() -> void:
	disposed = true; _tracked = false
	for list in [droplets, rings, foam]:
		for p in list: p.active = false
	water_at = Callable(); ground_height = Callable(); random_callback = Callable()
