extends Node3D
## Presentation only. Events originate in accepted damage/wounds and final poses.
## Offline layered CC0 foley; local RNG never advances the gameplay random stream.
const BUS := &"Combat30"
const KINDS := ["wood", "stone", "metal", "blunt", "slice", "stab", "sever", "swish", "armor_light", "armor_medium", "armor_heavy"]
const MASS := {"sword":1.0,"mace":1.5,"spear":1.35,"axe":2.1,"sledge":2.7}
const Puncture = preload("res://scripts/combat/puncture29.gd")
static var _shared_banks: Dictionary = {}
var banks: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var _voice_pool:Node3D
var events: Array[Dictionary] = []
var counts: Dictionary = {}
var rejected: Dictionary = {}
var _bags: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_event: Dictionary = {}
var _punctures: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _identity := ""
var _last_dir := Vector3.ZERO
var _last_player := Vector3.ZERO
var _last_cross := Vector3.ZERO
var _swish_ready := true
var _warmup := 0.0
var _clock := 0.0
var _last_swish := -10.0
var _generation := -1
var _voice_cursor := 0
var _recent_flesh_at := Vector3.INF
var _recent_flesh_time := -10.0
var _recent_armor_time := -10.0
var _recent_armor_at := Vector3.INF
var seed30 := 300712

func _ready() -> void:
	_rng.seed = seed30
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,BUS)
		AudioServer.set_bus_send(index,&"Master")
		var compressor := AudioEffectCompressor.new()
		compressor.threshold=-12.0;compressor.ratio=3.0
		compressor.attack_us=2000.0;compressor.release_ms=120.0
		AudioServer.add_bus_effect(index,compressor)
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db=-1.5;limiter.release=0.10
		AudioServer.add_bus_effect(index,limiter)
	# Immutable decoded assets are shared across actors; shuffle bags and voices
	# remain instance-owned. Never decode a fresh WAV on a contact callback.
	if _shared_banks.is_empty():
		for kind: String in KINDS:
			var variants: Array[AudioStreamWAV] = []
			for i in 4:
				variants.append(AudioStreamWAV.load_from_file("res://audio/combat30/%s_%s.wav"%[kind,i]))
			_shared_banks[kind]=variants
	banks=_shared_banks
	var scene:Node=get_tree().current_scene
	if not is_instance_valid(scene):scene=get_parent()
	_voice_pool=scene.get_meta("combat_voice_pool31") if scene.has_meta("combat_voice_pool31") else null
	if not is_instance_valid(_voice_pool):
		_voice_pool=preload("res://scripts/audio/combat_voice_pool31.gd").new()
		_voice_pool.name="CombatVoicePool31";scene.add_child(_voice_pool);scene.set_meta("combat_voice_pool31",_voice_pool)
	voices=_voice_pool.voices

func reset() -> void:
	if is_instance_valid(_voice_pool):_voice_pool.release(self)
	_identity="";_last_dir=Vector3.ZERO;_last_cross=Vector3.ZERO
	_warmup=0.0;_swish_ready=true;_last_swish=-10.0
	_punctures.clear();_last_event.clear()
	_recent_flesh_time=-10.0;_recent_flesh_at=Vector3.INF
	_recent_armor_time=-10.0;_recent_armor_at=Vector3.INF

static func material_kind(collider: Node) -> String:
	var node := collider
	for _level in 5:
		if not is_instance_valid(node):break
		for key: String in ["combat_surface30","surface","castle_furnishing_material"]:
			var material := str(node.get_meta(key,"" )).to_lower()
			if "wood" in material or "plank" in material:return "wood"
			if "metal" in material or "steel" in material or "iron" in material:return "metal"
			if "stone" in material or "concrete" in material or "brick" in material:return "stone"
		if node.has_meta("sword_npc_part") or node.has_meta("sword_player_part50"):return "blunt"
		if node.has_meta("sword_target"):return "wood"
		node=node.get_parent()
	return "stone"

func _variant(kind: String) -> int:
	var bag: Array = _bags.get(kind,[])
	if bag.is_empty():
		bag=[0,1,2,3]
		for i in range(3,0,-1):
			var pick := _rng.randi_range(0,i)
			var prior: int=bag[i];bag[i]=bag[pick];bag[pick]=prior
		if int(bag[-1])==int(_last_variant.get(kind,-1)):
			var prior: int=bag[0];bag[0]=bag[-1];bag[-1]=prior
	var result: int=bag.pop_back()
	_bags[kind]=bag;_last_variant[kind]=result
	return result

func emit_event(host: Node, kind: String, at: Vector3, strength: float, event_key: String="") -> bool:
	if kind=="flesh":kind="blunt"
	# User preference31: the sword is quiet in air; real contacts remain audible.
	if kind=="swish" and is_instance_valid(host) and str(host.get("_weapon_id"))=="sword":return false
	if not banks.has(kind) or not at.is_finite():return false
	var now := float(Time.get_ticks_msec())*.001
	var key := kind+":"+event_key
	var interval := 0.18 if kind in ["slice","stab"] else 0.09
	if now-float(_last_event.get(key,-10.0))<interval:
		rejected["debounce"]=int(rejected.get("debounce",0))+1;return false
	# One accepted blow may report several adjacent limbs. Merge close body
	# reports, but keep a later committed sever's distinct separation transient.
	if kind in ["blunt","slice","stab"] and now-_recent_flesh_time<0.075 and at.distance_squared_to(_recent_flesh_at)<0.09:
		rejected["same_blow"]=int(rejected.get("same_blow",0))+1;return false
	var armor := kind in ["armor_light","armor_medium","armor_heavy"]
	# Accepted armor callback owns this blow. The body/legacy metal observer
	# may see the same contact; it must not create a second impact voice.
	if kind in ["metal","blunt","slice","stab"] or armor:
		if now-_recent_armor_time<.075 and at.distance_squared_to(_recent_armor_at)<.09:
			rejected["same_armor_blow"]=int(rejected.get("same_armor_blow",0))+1;return false
	if armor and now-_recent_flesh_time<.075 and at.distance_squared_to(_recent_flesh_at)<.09:
		rejected["same_blow"]=int(rejected.get("same_blow",0))+1;return false
	var voice:AudioStreamPlayer3D=_voice_pool.claim(self,at) if is_instance_valid(_voice_pool) else null
	if voice==null:
		# Swishes never steal a body/material impact. Skip rather than hard-stop
		# a tail when the bounded pool is full.
		rejected["voice_budget"]=int(rejected.get("voice_budget",0))+1;return false
	_last_event[key]=now
	if _last_event.size()>128:
		for old in _last_event.keys():
			if now-float(_last_event[old])>2.0:_last_event.erase(old)
	if kind in ["blunt","slice","stab"]:_recent_flesh_time=now;_recent_flesh_at=at
	if armor:_recent_armor_time=now;_recent_armor_at=at
	var weapon := str(host.get("_weapon_id")) if is_instance_valid(host) else "sword"
	var mass := float(MASS.get(weapon,1.0))
	var variant := _variant(kind)
	voice.stream=banks[kind][variant]
	voice.global_position=at
	voice.pitch_scale=clampf(pow(mass,-0.09)*_rng.randf_range(.97,1.03),.88,1.05)
	var gain := lerpf(-15.0,-1.0,sqrt(clampf(strength,0.0,1.0)))
	if kind=="swish":gain-=7.0
	if kind=="stab":gain-=2.0
	if kind=="armor_light":gain-=1.0
	if kind=="armor_medium":gain-=2.0
	voice.volume_db=gain
	voice.play()
	counts[kind]=int(counts.get(kind,0))+1
	events.append({"kind":kind,"key":event_key,"variant":variant,"weapon":weapon,"strength":strength,"gain_db":gain,"pitch":voice.pitch_scale,"point":at,"ms":Time.get_ticks_msec(),"physics_frame":Engine.get_physics_frames()})
	if events.size()>160:events.pop_front()
	return true

func tick(host: Node, delta: float) -> void:
	_clock+=maxf(delta,0.0)
	var generation := int(host.get("lab_resets")) if host.get("lab_resets")!=null else 0
	if generation!=_generation:reset();_generation=generation
	var weapon: Node3D=host.get("_sword")
	var player: Node3D=host.get("_player")
	var world: Node=host.get("_world")
	var eligible := bool(host.get("_ready")) and bool(host.get("_selected")) and not bool(host.get("_unarmed")) and not bool(host.get("_sword_grounded")) and is_instance_valid(weapon) and is_instance_valid(player)
	if eligible and is_instance_valid(world):eligible=not bool(world.get("preview_dead"))
	if not eligible:
		_identity="";_warmup=0.0;_last_dir=Vector3.ZERO;return
	var identity := "%s:%s:%s"%[weapon.get_instance_id(),generation,host.get("_weapon_id")]
	var direction := weapon.global_basis.x.normalized()
	if identity!=_identity or delta<=0.0 or delta>.12 or player.global_position.distance_to(_last_player)>.4:
		_identity=identity;_last_dir=direction;_last_player=player.global_position
		_warmup=0.0;_swish_ready=true;_last_cross=Vector3.ZERO
		_prime_existing_puncture(host)
		return
	_warmup+=delta
	var cross := _last_dir.cross(direction)
	var angular_speed := acos(clampf(_last_dir.dot(direction),-1.0,1.0))/delta
	var air_speed := angular_speed*float(host.get("_weapon_length"))
	var held := bool(host.get("_held")) and not bool(host.get("_blocking"))
	if air_speed<.7 or not held:_swish_ready=true
	if cross.length_squared()>.00001 and _last_cross.length_squared()>.00001 and cross.normalized().dot(_last_cross.normalized())<-.3:_swish_ready=true
	if str(host.get("_weapon_id"))!="sword" and held and _warmup>.18 and air_speed>1.8 and air_speed<20.0 and _swish_ready and _clock-_last_swish>.20:
		if emit_event(host,"swish",weapon.global_position+direction*float(host.get("_weapon_length"))*.55,clampf(air_speed/8.0,.1,1.0),"air"):
			_swish_ready=false;_last_swish=_clock
	if cross.length_squared()>.00001:_last_cross=cross
	_last_dir=direction;_last_player=player.global_position
	_tick_puncture(host)

func _puncture_key(channel: Dictionary, node: Node3D) -> String:
	return "%s:%s:%s:%s"%[channel.get("weapon_instance_id",-1),channel.get("generation",-1),node.get_instance_id(),channel.get("bone",-1)]

func _prime_existing_puncture(host: Node) -> void:
	# Drawing/reselecting a weapon or recovering a discontinuity does not play
	# an old injury again. Later genuine additional depth may emit a new texture.
	var channel: Dictionary=host.get_meta("puncture29_channel",{})
	if channel.get("node_ref")==null:return
	var node: Node3D=channel.node_ref.get_ref()
	if not is_instance_valid(node):return
	var depth := float(channel.get("cut_depth",0.0))
	if depth>.0001:_punctures[_puncture_key(channel,node)]={"depth":depth,"time":_clock}

func _tick_puncture(host: Node) -> void:
	if host.has_method("_solid_tip_committed29") and not host.call("_solid_tip_committed29"):return
	var channel: Dictionary=host.get_meta("puncture29_channel",{})
	if not channel.get("valid",false) or not channel.get("actual_hit",false) or channel.get("withdrawn",false):return
	if int(channel.get("generation",-1))!=_generation or str(channel.get("weapon",""))!=str(host.get("_weapon_id")):return
	var weapon: Node=host.get("_sword")
	if not is_instance_valid(weapon) or int(channel.get("weapon_instance_id",-1))!=weapon.get_instance_id():return
	var depth := float(channel.get("cut_depth",0.0))
	if depth<=.0001 or channel.get("node_ref")==null:return
	var node: Node3D=channel.node_ref.get_ref()
	if not is_instance_valid(node):return
	var key := _puncture_key(channel,node)
	var old: Dictionary=_punctures.get(key,{"depth":0.0,"time":-10.0})
	if depth>float(old.depth)+.0001:
		if float(old.depth)==0.0 or (depth-float(old.depth)>=.012 and _clock-float(old.time)>=.16):
			var strength := clampf(.12+depth/maxf(.08,float(channel.get("max_depth",.3)))*.55,.12,.65)
			if emit_event(host,"stab",node.global_position,strength,key):old={"depth":depth,"time":_clock}
		_punctures[key]=old
	if _punctures.size()>64:
		for old_key in _punctures.keys():
			if _clock-float(_punctures[old_key].time)>20.0:_punctures.erase(old_key)

func report() -> Dictionary:
	return {"events":counts.duplicate(),"recent":events.duplicate(true),"rejected":rejected.duplicate(),"voices":voices.size(),"voice_scope":"scene_shared","variant_sets":banks.size(),"seed":seed30,"bus":BUS}
