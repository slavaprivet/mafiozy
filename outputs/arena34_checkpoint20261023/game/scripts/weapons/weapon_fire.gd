extends RefCounted
## Source-local fire math, not network authority. Outputs are shot metadata;
## the host must admit ownership/ammo/hits and supply actual world transforms.
const Data = preload("res://scripts/weapons/weapon_fire_profiles.gd")
const FIREARM_IDS = Data.FIREARM_IDS
const SOURCE_SHA256 = Data.SOURCE_SHA256

static func ids() -> Array:
	return FIREARM_IDS.duplicate()

static func profile(id: Variant) -> Dictionary:
	return Data.PROFILES.get(id, {}).duplicate(true) if id != null else {}

static func _number(value: Variant) -> float:
	if value == null: return 0.0
	if value is bool: return 1.0 if value else 0.0
	if value is int or value is float: return float(value)
	if value is String:
		var text: String = value.strip_edges()
		if text.is_empty(): return 0.0
		if text.is_valid_float(): return float(text)
	return NAN

static func _zero(value: Variant) -> float:
	if value is int or value is float: return 0.0 if is_nan(float(value)) else float(value)
	var number := _number(value)
	return 0.0 if is_nan(number) else number

static func _clamp_option(options: Dictionary, key: String, upper: int, fallback: int) -> int:
	if not options.has(key): return fallback
	var number := _number(options[key])
	return int(clampf(floor(number), 0, upper)) if is_finite(number) else fallback

static func create_state(id: Variant, options: Dictionary = {}) -> Dictionary:
	if id != null and id != "none" and not Data.PROFILES.has(id): return {"error":"UNKNOWN_FIREARM"}
	var state := {"weaponId":"none" if id == null else id,"magazine":0,"reserveAmmo":0,"cooldown":0.0,"reloadRemaining":0.0,"recoil":0.0,"sequence":0,"triggerHeld":false}
	if id == null or id == "none": return state
	var p: Dictionary = Data.PROFILES[id]
	state.magazine = _clamp_option(options, "magazine", p.magazineSize, p.magazineSize)
	state.reserveAmmo = _clamp_option(options, "reserveAmmo", 9999, p.magazineSize * 3)
	state.merge({"sprayHeat":0.0,"sprayShots":0.0,"sprayRecoveryRemaining":0.0,"lastRecoilYaw":0.0,"lastRecoilScale":1.0})
	return state

static func begin_reload(state: Dictionary) -> Dictionary:
	var next := state.duplicate()
	var p: Dictionary = Data.PROFILES.get(state.get("weaponId"), {})
	if p.is_empty() or state.reloadRemaining > 0 or state.magazine >= p.magazineSize or state.reserveAmmo <= 0: return next
	next.reloadRemaining = p.reloadSeconds; next.triggerHeld = false
	return next

static func _recover(state: Dictionary, dt: float) -> void:
	var before := maxf(0, _zero(state.get("sprayRecoveryRemaining")))
	state.sprayRecoveryRemaining = maxf(0, before - dt)
	state.sprayHeat = maxf(0, _zero(state.get("sprayHeat"))) * state.sprayRecoveryRemaining / before if before > 0 else 0.0
	state.sprayShots = maxf(0, _zero(state.get("sprayShots"))) if state.sprayRecoveryRemaining > 1e-8 else 0.0
	if not state.sprayShots: state.sprayHeat = 0.0; state.sprayRecoveryRemaining = 0.0

static func _handling(p: Dictionary, state: Dictionary, input: Dictionary) -> Dictionary:
	var tune: Dictionary = p.handling
	var heat := clampf(_zero(state.get("sprayHeat")), 0, 1)
	var index := maxf(0, _zero(state.get("sprayShots")))
	var posture: String = "prone" if input.get("posture") == "prone" else ("crouch" if input.get("posture") == "crouch" else "stand")
	var stance := .38 if posture == "prone" else (.65 if posture == "crouch" else 1.0)
	var movement := 1.7 if input.get("running", false) else (1.0 if input.get("moving", false) else 0.0)
	var accuracy := stance * (.48 if input.get("aiming", false) else 1.0)
	var kick := stance * (.70 if input.get("aiming", false) else 1.0)
	var angle: float = tune.seed * .61803398875 + (index + 1) * 2.39996322973
	var spread: float = (p.spread * tune.bloom * heat + tune.moveSpread * movement) * accuracy
	var cover := .09 if input.get("coverFire") == "blind" else 0.0
	var cover_angle: float = tune.seed * .754877666 + (maxf(0, _zero(state.get("sequence"))) + 1) * 2.39996322973
	var radius := cover * (.58 + .42 * (.5 + .5 * sin(cover_angle * 1.61803398875)))
	var cover_yaw := cos(cover_angle) * radius
	var cover_pitch := sin(cover_angle) * radius
	var rise: float = tune.pitchRise * heat * minf(1, .28 + index * .11) * kick
	var sweep: float = tune.yawSweep * heat * sin(index * tune.yawFrequency + tune.seed * .11) * minf(1, index / 5) * kick
	return {"posture":posture,"spread":spread+cover,"heat":heat,"burstIndex":index,"coverSpread":cover,"coverYaw":cover_yaw,"coverPitch":cover_pitch,
		"yaw":sweep+cos(angle)*spread*.72+cover_yaw,"pitch":rise+sin(angle)*spread*.38+cover_pitch,
		"visualScale":tune.visualKick*kick*(1+heat*.28),"visualYaw":sin((index+1)*tune.yawFrequency+tune.seed*.11),"pelletSpread":p.spread*tune.get("pelletSpread",0)*accuracy}

static func _shot(p: Dictionary, sequence: float, input: Dictionary, h: Dictionary) -> Dictionary:
	var projectiles: Array = []
	for index in p.pellets:
		var angle: float = (index-1)*PI*2/maxf(1,p.pellets-1)+p.handling.seed*.17+h.burstIndex*.37
		var radius: float = 0.0 if index == 0 else h.pelletSpread
		projectiles.append({"index":index,"yawOffset":h.yaw+cos(angle)*radius,"pitchOffset":h.pitch+sin(angle)*radius,"speed":p.projectileSpeed,"range":p.range,"color":p.color,"tracer":p.tracer,"explosive":p.explosive,"visualId":p.id,"visual":p.projectileVisual.duplicate()})
	var casing: Variant = null if p.casing == "none" or p.casing == "retained" else {"kind":"brass","delay":p.casingDelay,"side":"right","velocity":{"right":1.65,"up":2.2,"forward":-.4}}
	return {"weaponId":p.id,"balanceId":p.balanceId,"sequence":sequence,"shotId":p.id+":"+str(int(sequence)),"damage":p.damage,"mode":p.mode,"aiming":bool(input.get("aiming",false)),"projectiles":projectiles,"muzzleFlash":true,"casing":casing,
		"handling":{"posture":h.posture,"burstIndex":h.burstIndex,"heat":h.heat,"spread":h.spread,"yaw":h.yaw,"pitch":h.pitch,"coverSpread":h.coverSpread,"coverYaw":h.coverYaw,"coverPitch":h.coverPitch},
		"recoil":{"pitch":p.recoil*h.visualScale,"yaw":h.visualYaw*p.recoil*.075*h.visualScale,"recovery":p.recoilRecovery}}

static func sample_accuracy(state: Dictionary, input: Dictionary = {}) -> Dictionary:
	var p: Dictionary = Data.PROFILES.get(state.get("weaponId"), {})
	if p.is_empty(): return {"spread":0,"recoilYaw":0,"recoilPitch":0,"heat":0,"burstIndex":0,"pelletSpread":0}
	var h := _handling(p, state, input)
	return {"spread":h.spread+h.pelletSpread,"recoilYaw":h.yaw,"recoilPitch":h.pitch,"heat":h.heat,"burstIndex":h.burstIndex,"pelletSpread":h.pelletSpread,"coverSpread":h.coverSpread,"coverYaw":h.coverYaw,"coverPitch":h.coverPitch}

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func sample_recoil(state: Dictionary) -> Dictionary:
	var p: Dictionary = Data.PROFILES.get(state.get("weaponId"), {})
	if p.is_empty(): return {"amount":0,"normalized":0,"pitch":0,"yaw":0,"weaponKick":0,"bodyKick":0,"cameraKick":0,"recoilYaw":0}
	var amount := maxf(0, _zero(state.get("recoil")))
	var normalized := minf(1, amount / maxf(.001, p.recoil))
	var side: float = state.lastRecoilYaw if _finite(state.get("lastRecoilYaw")) else (-1.0 if int(state.sequence) & 1 else 1.0)
	var scale: float = state.lastRecoilScale if _finite(state.get("lastRecoilScale")) else 1.0
	return {"amount":amount,"normalized":normalized,"pitch":amount*.012*scale,"yaw":side*amount*.0009*scale,"weaponKick":normalized*scale,"bodyKick":normalized*(.82 if p.recoil>=3 else .52)*scale,"cameraKick":normalized*minf(.045,.009+p.recoil*.005)*scale,"recoilYaw":side*normalized*scale}

static func step(state: Dictionary, input: Dictionary = {}, dt: float = 0) -> Dictionary:
	if not is_finite(dt) or dt < 0 or dt > 5: return {"error":"DT_OUTSIDE_0_TO_5"}
	var id: Variant = state.get("weaponId")
	if id != null and id != "none" and not Data.PROFILES.has(id): return {"error":"UNKNOWN_FIREARM"}
	var p: Dictionary = Data.PROFILES.get(id, {})
	var held := bool(input.get("triggerHeld",false))
	var pressed := bool(input.get("triggerPressed",false))
	var next := state.duplicate()
	var shots: Array = []
	if p.is_empty():
		next.triggerHeld = held
		return {"state":next,"shots":shots,"dryFire":false,"reloadStarted":false,"reloadFinished":false}
	var started := false; var finished := false; var dry := false
	next.recoil = maxf(0, _zero(next.get("recoil")) - dt*(p.recoil/p.recoilRecovery))
	next.cooldown = maxf(-dt, maxf(0, _zero(next.get("cooldown"))) - dt)
	if input.get("reload",false):
		var reloaded := begin_reload(next)
		started = reloaded.reloadRemaining > next.reloadRemaining
		next = reloaded
	if next.reloadRemaining > 0:
		_recover(next,dt)
		var before: float = next.reloadRemaining
		next.reloadRemaining = maxf(0,before-dt)
		if before > 0 and next.reloadRemaining == 0:
			var loaded: float = minf(p.magazineSize-next.magazine,next.reserveAmmo)
			next.magazine += loaded; next.reserveAmmo -= loaded; finished = true
		next.triggerHeld = held
		return {"state":next,"shots":shots,"dryFire":false,"reloadStarted":started,"reloadFinished":finished}
	var rising: bool = pressed or (held and not state.triggerHeld)
	var continuous: bool = p.automatic and held
	var wants := rising or continuous
	var spray_clock := 0.0
	if wants and next.magazine <= 0: dry = rising
	elif wants:
		var allowance := 64 if continuous else 1
		while next.cooldown <= 0 and next.magazine > 0 and shots.size() < allowance:
			var sequence := _zero(next.get("sequence")) + 1
			var shot_time := maxf(spray_clock,minf(dt,dt+next.cooldown))
			_recover(next,shot_time-spray_clock); spray_clock = shot_time
			var h := _handling(p,next,input)
			shots.append(_shot(p,sequence,input,h))
			next.sequence = sequence; next.magazine -= 1; next.cooldown += p.cooldown
			next.recoil = minf(p.recoil*2.15,next.recoil+p.recoil)
			next.sprayHeat = minf(1,next.sprayHeat+p.handling.heatPerShot)
			next.sprayShots += 1; next.sprayRecoveryRemaining = p.handling.recovery
			next.lastRecoilYaw = h.visualYaw; next.lastRecoilScale = h.visualScale
			if not continuous: break
	_recover(next,dt-spray_clock)
	next.cooldown = maxf(0,next.cooldown); next.triggerHeld = held
	return {"state":next,"shots":shots,"dryFire":dry,"reloadStarted":started,"reloadFinished":finished}
