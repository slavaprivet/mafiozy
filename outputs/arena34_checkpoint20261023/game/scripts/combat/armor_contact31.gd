extends RefCounted
## Lab adapter for the existing deterministic coverage/residual-energy law.
## This is skin-hit coverage, not a claim of exact outer decorative plate contact.
const Armor = preload("res://scripts/combat/armor_damage31.gd")
var last: Dictionary = {}
var _generation := -1
var _weapon := 0
var _responses: Dictionary = {}
var _sounds: Dictionary = {}

static func canonical_part(part: String) -> String:
	if part.begins_with("spine"): return "chest"
	if part == "neck": return "head"
	if part.begins_with("clavicle_"): return part.replace("clavicle_", "upperarm_")
	return part

func evaluate(host: Node, part: String, point: Vector3, velocity: Vector3, normal: Vector3, kind: String) -> Dictionary:
	var mapped := canonical_part(part)
	var speed := velocity.length()
	var slot := Armor.slot_for_part(mapped)
	var equipment: Dictionary = host.get("_npc_armor_loadout31")
	var tier := Armor.tier_of(str(equipment.get(slot, "")), slot)
	var result := {"part": mapped, "tier": tier, "region": "skin", "factor": 1.0,
		"protected": false, "penetrates": true, "speed_factor": 1.0, "incoming": 0.0, "residual": 0.0}
	if tier.is_empty(): last = result; return result
	var collider: CollisionObject3D = host.call("_solid_collider29", mapped)
	var contact: Vector3 = host.call("_armor_point31", host.get("_npc_rig"), mapped, point, collider)
	var incidence := clampf(-velocity.normalized().dot(normal.normalized()), 0.0, 1.0) if speed > .000001 and normal.length_squared() > .5 else 1.0
	# Match the native contact-speed/mass/grip transfer. No unbounded invented
	# damage scale: a sufficiently fast real strike can pass the existing 28/14 gates.
	var incoming: float = host.call("_impact_damage31", speed * .6, 1.0, kind)
	var protection := Armor.resolve(equipment, mapped, kind, incoming, contact, incidence)
	result.region = protection.region; result.factor = protection.factor
	result.protected = str(protection.region) not in ["skin", "joint"]
	result.incoming = incoming; result.residual = protection.damage
	result.speed_factor = sqrt(clampf(float(protection.factor), 0.0, 1.0))
	result.penetrates = Armor.tissue_penetrates(str(protection.region), kind, float(protection.damage))
	result.normalized_point = contact; result.incidence = incidence
	last = result
	return result

func respond(host: Node, result: Dictionary, point: Vector3, velocity: Vector3) -> void:
	if not result.protected or velocity.length_squared() < 1e-8: return
	var weapon: Node3D = host.get("_sword")
	if not is_instance_valid(weapon): return
	var generation: int = host.get("lab_resets")
	if generation != _generation or weapon.get_instance_id() != _weapon:
		_responses.clear(); _sounds.clear(); _generation = generation; _weapon = weapon.get_instance_id()
	var key := "%s:%s" % [result.part, result.region]
	var frame := Engine.get_physics_frames()
	if int(_responses.get(key, -1)) != frame:
		_responses[key] = frame
		var direction: Vector3 = host.get("_dir")
		var gradient := direction.cross(velocity.normalized())
		if gradient.length_squared() > 1e-8:
			gradient = gradient.normalized()
			var omega: Vector3 = host.get("_omega")
			var advancing := omega.dot(gradient)
			if advancing > 0.0: host.set("_omega", omega - gradient * advancing * (1.0 - float(result.speed_factor)))
	var now := Time.get_ticks_msec()
	var sound: Dictionary = _sounds.get(key, {})
	if not sound.is_empty() and now-int(sound.time) < 100 and point.distance_squared_to(sound.point) < .04*.04: return
	_sounds[key] = {"time": now, "point": point}
	if host.has_method("combat_audio_event30"):
		host.call("combat_audio_event30", "armor_"+str(result.tier), point, clampf(float(result.incoming)/160.0, .08, 1.0), key)
