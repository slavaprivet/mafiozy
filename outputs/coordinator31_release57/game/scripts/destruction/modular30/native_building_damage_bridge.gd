extends RefCounted
## Local-session world damage admission. Cosmetic signals are never subscribed.
## The native RPG producer patch forwards its complete terminal observation;
## committed shot_emitted and current actor/scene bind that observation here.
const MAX_SHOTS := 128
const MAX_AGE_MS := 15000
var _host: WeakRef
var _blast_port: Callable
var _glass_port: Callable
var _glass_blast_port: Callable
var _shots: Dictionary = {}
var _ready := false
var _binding: Dictionary = {}
var _breach_radius_m := 0.8
var _stats := {"admitted_blast_events":0,"forwarded_glass_candidates":0,"forwarded_glass_blast_events":0,"rejected":0}

func configure(weapons: Node, blast_port: Callable, glass_port: Callable = Callable(), options: Dictionary = {}) -> Dictionary:
	if _ready or not is_instance_valid(weapons) or not weapons._owner_current() or not blast_port.is_valid():
		return {"ok":false,"reason":"local_owner_or_blast_port"}
	if weapons.rpg_effects == null or not weapons.rpg_effects.has_signal("native_impact"):
		return {"ok":false,"reason":"native_terminal_patch_required"}
	if glass_port.is_valid() and not weapons.effects.has_signal("projectile_resolved"):
		return {"ok":false,"reason":"native_bullet_terminal_required"}
	var radius: Variant = options.get("breach_radius_m",0.8)
	if not _number(radius) or radius<=0 or radius>0.9: return {"ok":false,"reason":"local_radius_metres"}
	if not options.get("glass_blast_port",Callable()) is Callable: return {"ok":false,"reason":"glass_blast_callback"}
	_breach_radius_m = float(radius)
	_host = weakref(weapons)
	_binding = {"actor_id":weapons.player.get_meta("actor_id"),"life_generation":weapons.player.get_meta("life_generation"),"scene_token":"preview-scene:"+str(weapons.scene.get_instance_id())}
	_blast_port = blast_port
	_glass_port = glass_port
	_glass_blast_port = options.get("glass_blast_port",Callable())
	weapons.shot_emitted.connect(_on_committed_shot)
	weapons.rpg_effects.connect("native_impact",_on_native_blast)
	if _glass_port.is_valid(): weapons.effects.connect("projectile_resolved",_on_native_bullet)
	weapons.tree_exiting.connect(dispose,CONNECT_ONE_SHOT)
	_ready = true
	return {"ok":true,"scope":"new_local_session_building_damage","server_authority":false}

func _current() -> bool:
	if not _ready or _host == null or not is_instance_valid(_host.get_ref()): return false
	var weapons: Node = _host.get_ref()
	return weapons._owner_current() and not weapons.scene.preview_dead and not weapons.scene.preview_physics_fault and weapons.player.get_meta("actor_id") == _binding.actor_id and weapons.player.get_meta("life_generation") == _binding.life_generation and "preview-scene:"+str(weapons.scene.get_instance_id()) == _binding.scene_token

func _on_committed_shot(shot: Dictionary, muzzle: Dictionary, _camera_origin: Vector3, _camera_direction: Vector3) -> void:
	if not _current() or not shot.get("shotId") is String or shot.shotId.is_empty() or not shot.get("projectiles") is Array or not muzzle.get("origin") is Vector3 or not muzzle.origin.is_finite(): return
	if muzzle.get("actor_id") != _binding.actor_id or muzzle.get("life_generation") != _binding.life_generation: return
	if not _number(shot.get("damage")) or shot.damage <= 0 or not _number(shot.get("sequence")): return
	var now := Time.get_ticks_msec()
	for key: String in _shots.keys():
		if now-int(_shots[key].at_ms)>MAX_AGE_MS: _shots.erase(key)
	if _shots.has(shot.shotId) or shot.projectiles.is_empty() or shot.projectiles.size()>7: return
	if _shots.size()>=MAX_SHOTS: _shots.erase(_shots.keys()[0])
	var weapons: Node = _host.get_ref()
	_shots[shot.shotId] = {"weapon_id":shot.weaponId,"sequence":shot.sequence,"damage":float(shot.damage),"origin":muzzle.origin,"at_ms":now,"item_uid":weapons.inventory.get_item_uid(shot.weaponId),"count":shot.projectiles.size(),"terminals":{},"producer_epoch":weapons.effects.resolution_epoch()}

func _on_native_blast(receipt: Dictionary) -> void:
	if not _current() or receipt.get("native_rpg_impact") != true or receipt.get("cosmetic_only",false): return
	var shot_id: String = str(receipt.get("shot_id",""))
	if not _shots.has(shot_id): _stats.rejected+=1; return
	var shot: Dictionary = _shots[shot_id]
	if shot.weapon_id != "rpg" or Time.get_ticks_msec()-int(shot.at_ms)>MAX_AGE_MS: _shots.erase(shot_id); _stats.rejected+=1; return
	for key: String in ["actor_id","life_generation","scene_token"]:
		if receipt.get(key) != _binding[key]: _stats.rejected+=1; return
	if receipt.get("sequence") != shot.sequence or receipt.get("item_uid") != shot.item_uid or receipt.get("origin") != shot.origin or not _vector(receipt.get("point")) or not _vector(receipt.get("normal")) or not _vector(receipt.get("direction")):
		_stats.rejected+=1; return
	if not _number(receipt.get("token")) or receipt.token<=0 or not _number(receipt.get("distance_world")) or receipt.distance_world<0 or receipt.distance_world>61.5001 or not _number(receipt.get("damage")) or receipt.damage!=shot.damage:
		_stats.rejected+=1; return
	if absf(receipt.direction.length_squared()-1.0)>.0001 or absf(receipt.normal.length_squared()-1.0)>.0001 or receipt.point.distance_to(shot.origin+receipt.direction*float(receipt.distance_world))>.001:
		_stats.rejected+=1; return
	var hit: Variant = receipt.get("hit")
	if not hit is Dictionary or not hit.get("hit") is bool: _stats.rejected+=1; return
	# Consume terminal before invoking an external port. A range-end explosion
	# is legitimate but does not pick an arbitrary nearby wall as a direct hit.
	_shots.erase(shot_id)
	if _glass_blast_port.is_valid():
		# Original Walk RPG glass presentation: walk_preview radius11/power1.4,
		# blast_response multiplies power120. Independent of actor HP damage160
		# and wall breach radius0.8; 2.7 native radius cells must not replace11m.
		_glass_blast_port.call({"scope":"new_local_session_building_damage","event_id":_binding.scene_token+":"+shot_id+":glass-blast","position":receipt.point,"direction":receipt.direction,"normal":receipt.normal,"power":168.0,"radius":11.0,"weapon_id":"rpg","explosive":true,"admitted":true,"authority":"local_preview","server_authority":false})
		_stats.forwarded_glass_blast_events+=1
	if not hit.hit: return
	var collider: Variant = hit.get("collider")
	if not is_instance_valid(collider) or not collider is PhysicsBody3D or not collider.is_inside_tree() or collider.is_queued_for_deletion(): _stats.rejected+=1; return
	var source_id := _source_id(collider)
	if source_id.is_empty(): return
	var event: Dictionary = {"scope":"new_local_session_building_damage","event_id":_binding.scene_token+":"+shot_id,"source_id":source_id,"position":receipt.point,"normal":receipt.normal,"direction":receipt.direction,"collider":collider,"power":shot.damage,"radius":_breach_radius_m,"weapon_id":"rpg","explosive":true,"admitted":true,"authority":"local_preview","server_authority":false}
	_blast_port.call(event)
	_stats.admitted_blast_events+=1

func _on_native_bullet(receipt: Dictionary) -> void:
	if not _current() or not _glass_port.is_valid(): return
	var shot_id: String = str(receipt.get("shotId",""))
	if not _shots.has(shot_id): return
	var shot: Dictionary = _shots[shot_id]
	if shot.weapon_id == "rpg" or Time.get_ticks_msec()-int(shot.at_ms)>MAX_AGE_MS: return
	if receipt.get("weaponId") != shot.weapon_id or receipt.get("producerEpoch") != shot.producer_epoch or receipt.get("projectileCount") != shot.count: return
	var index: Variant = receipt.get("projectileIndex")
	if not index is int or index<0 or index>=shot.count or shot.terminals.has(index): return
	shot.terminals[index] = true
	if shot.terminals.size()==shot.count: _shots.erase(shot_id)
	if receipt.get("status")!="hit" or not _vector(receipt.get("point")) or not _vector(receipt.get("normal")) or not _vector(receipt.get("direction")): return
	var collider: Variant = receipt.get("collider")
	if not is_instance_valid(collider) or not collider is PhysicsBody3D or not collider.is_inside_tree() or collider.is_queued_for_deletion(): return
	_glass_port.call({"scope":"new_local_session_building_glass","event_id":_binding.scene_token+":"+shot_id+":"+str(index),"source_id":_source_id(collider),"position":receipt.point,"normal":receipt.normal,"direction":receipt.direction,"collider":collider,"power":shot.damage,"weapon_id":shot.weapon_id,"explosive":false,"admitted":true,"authority":"local_preview","server_authority":false})
	_stats.forwarded_glass_candidates+=1

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
static func _vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()
static func _source_id(collider: Node) -> String:
	var current: Node = collider
	while current!=null:
		var id: String = str(current.get_meta("source_id",""))
		if not id.is_empty(): return id
		current=current.get_parent()
	return ""

func snapshot() -> Dictionary:
	return {"ready":_current(),"pending_shots":_shots.size(),"stats":_stats.duplicate()}

func dispose() -> void:
	_ready = false
	if _host!=null and is_instance_valid(_host.get_ref()):
		var weapons: Node = _host.get_ref()
		if weapons.shot_emitted.is_connected(_on_committed_shot): weapons.shot_emitted.disconnect(_on_committed_shot)
		if weapons.rpg_effects!=null and weapons.rpg_effects.has_signal("native_impact") and weapons.rpg_effects.is_connected("native_impact",_on_native_blast): weapons.rpg_effects.disconnect("native_impact",_on_native_blast)
		if weapons.effects!=null and weapons.effects.is_connected("projectile_resolved",_on_native_bullet): weapons.effects.disconnect("projectile_resolved",_on_native_bullet)
	_host=null
	_blast_port=Callable()
	_glass_port=Callable()
	_glass_blast_port=Callable()
	_shots.clear()
