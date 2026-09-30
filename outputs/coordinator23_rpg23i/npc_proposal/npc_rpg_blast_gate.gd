extends RefCounted
## Local ordinary-NPC adapter. A cosmetic signal or supplied receipt alone can
## never admit damage. Root installs these hooks around the real ammo/flight
## commit and makes this instance the RPG closest-hit query owner.
const Rules=preload("res://scripts/weapons/weapon_hit_rules.gd")
const SCALE:=4.1
const RADIUS_CELLS:=2.7
const CAP:=112
class FireTicket extends RefCounted:
	pass
class TargetTicket extends RefCounted:
	pass
var _weapons: WeakRef
var _world: WeakRef
var _player: WeakRef
var _flight: RefCounted
var _inventory: RefCounted
var _resident_host: RefCounted
var _owners: Array[RefCounted]=[]
var _damage_context: Callable
var _binding: Dictionary
var _pending: Dictionary={}
var _launches: Dictionary={}
var _targets: Dictionary={}
var _highest_token:=0
var _disposed:=false
var _busy:=false
var _epoch:=0
var _ray:=PhysicsRayQueryParameters3D.new()
var last_result: Dictionary={}

func configure(weapons: Node, resident_host: RefCounted, owners: Array[RefCounted], current_damage_context: Callable) -> Dictionary:
	if _weapons!=null or _disposed or not is_instance_valid(weapons) or not weapons.is_inside_tree() or not weapons._owner_current(): return _bad("owner")
	if not is_instance_valid(weapons.rpg_effects) or not is_instance_valid(weapons.rpg_effects._flight) or not is_instance_valid(weapons.inventory) or not is_instance_valid(resident_host): return _bad("owners")
	if owners.size()!=3 or not current_damage_context.is_valid(): return _bad("bounded_three_and_damage_context")
	var ids: Dictionary={}
	for owner: RefCounted in owners:
		if not is_instance_valid(owner) or owner._host!=resident_host or owner._weapons!=weapons or owner._token.source_id not in ["resident_72","resident_169","resident_252"] or ids.has(owner._token.source_id) or owner._current(owner._binding).is_empty(): return _bad("ordinary_current_owners")
		if not owner.has_method("accept_native_rpg_blast") or not owner.has_method("bind_native_rpg_gate"): return _bad("recipient_seam_required")
		ids[owner._token.source_id]=true
	_weapons=weakref(weapons); _world=weakref(weapons.scene); _player=weakref(weapons.player)
	_flight=weapons.rpg_effects._flight; _inventory=weapons.inventory; _resident_host=resident_host
	_owners=owners.duplicate(); _damage_context=current_damage_context
	_binding={"actor_id":weapons.player.get_meta("actor_id"),"life_generation":weapons.player.get_meta("life_generation"),"scene_token":"preview-scene:"+str(weapons.scene.get_instance_id()),"world_rid":weapons.scene.get_world_3d().space}
	_ray.collision_mask=5|256; _ray.hit_from_inside=true
	for owner: RefCounted in _owners:
		if owner.bind_native_rpg_gate(self)!=true: dispose(); return _bad("recipient_gate_binding")
	return {"ok":true,"scope":"new_local_session_ordinary_rpg","source_occlusion":"none_horizontal_rpg_radius","server_authority":false}
func _bad(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _live() -> bool:
	if _disposed or _weapons==null or not is_instance_valid(_weapons.get_ref()) or not is_instance_valid(_world.get_ref()) or not is_instance_valid(_player.get_ref()): return false
	var w: Node=_weapons.get_ref(); var p: CharacterBody3D=_player.get_ref(); var world: Node3D=_world.get_ref()
	if not w.is_inside_tree() or w.is_queued_for_deletion() or not world.is_inside_tree() or world.is_queued_for_deletion() or not p.is_inside_tree() or p.is_queued_for_deletion(): return false
	if not is_instance_valid(w.rpg_effects) or not is_instance_valid(w.rpg_effects._flight) or not is_instance_valid(w.inventory) or not is_instance_valid(_flight) or not is_instance_valid(_inventory): return false
	if w.scene!=world or w.player!=p or w.inventory!=_inventory or w.rpg_effects._flight!=_flight or not w._owner_current(): return false
	return p.get_meta("actor_id")==_binding.actor_id and p.get_meta("life_generation")==_binding.life_generation and world.get_world_3d().space==_binding.world_rid and p.get_world_3d()==world.get_world_3d() and not w.scene.preview_dead and not w.scene.preview_physics_fault
func _slot(token: int) -> Dictionary:
	for row: Dictionary in _flight._slots:
		if row.get("token")==token: return row
	return {}

## Immediately after prepare_shot and BEFORE _settle_pending(true).
## Capture live inventory, actual Flight reservation and current muzzle epoch.
func before_ammo_commit(effects: RefCounted, ticket: RefCounted) -> Dictionary:
	if _busy or not _pending.is_empty() or not _live() or effects!=_weapons.get_ref().rpg_effects or ticket==null or ticket!=_flight._ticket: return _bad("reservation")
	for token: int in _launches.keys():
		if _slot(token).is_empty() or Time.get_ticks_usec()-int(_launches[token].accepted_usec)>15000000: _launches.erase(token)
	var row: Dictionary=_flight._prepared.get("row",{})
	var ammo: Variant=_inventory.get_fire_state("rpg")
	if row.is_empty() or not ammo is Dictionary or ammo.weaponId!="rpg" or ammo.magazine<1 or row.item_uid!=_inventory.get_item_uid("rpg") or row.sequence!=int(ammo.sequence)+1: return _bad("ammo_sequence")
	if row.token<=_highest_token or _launches.size()>=CAP: return _bad("token_or_capacity")
	var current: Dictionary=_weapons.get_ref().presentation.current_muzzle()
	if current!=row.muzzle or not _flight._current_muzzle(row.muzzle): return _bad("muzzle_epoch")
	var capability:=FireTicket.new()
	_pending={"ticket":capability,"flight_ticket":ticket,"row":row.duplicate(true),"ammo":ammo.duplicate(true),"inventory_uid":row.item_uid}
	return {"ok":true,"ticket":capability}
func cancel_ammo_commit(ticket: RefCounted) -> void:
	if _pending.get("ticket")==ticket: _pending={}

## Immediately after inventory and commit_shot, before outward shot signals.
func after_ammo_commit(effects: RefCounted, ticket: RefCounted) -> Dictionary:
	if _busy or not _live() or effects!=_weapons.get_ref().rpg_effects or ticket==null or ticket!=_pending.get("ticket"): return _bad("commit_ticket")
	var prepared:=_pending; _pending={}
	var row: Dictionary=prepared.row
	var current:=_slot(row.token)
	var ammo: Variant=_inventory.get_fire_state("rpg")
	if current!=row or _flight._ticket!=null or not ammo is Dictionary or ammo.sequence!=row.sequence or ammo.magazine!=prepared.ammo.magazine-1 or ammo.reserveAmmo!=prepared.ammo.reserveAmmo or _inventory.get_item_uid("rpg")!=prepared.inventory_uid: return _bad("actual_ammo_and_flight_commit")
	_highest_token=row.token
	_launches[row.token]={"row":row,"accepted_usec":Time.get_ticks_usec(),"query":{},"result":{}}
	return {"ok":true,"token":row.token}

## Called only from the bound Flight's real query callback. Performs the native
## closest-contact ray itself; caller hit dictionaries never become proof.
func native_query(effects: RefCounted, request: Dictionary) -> Dictionary:
	if _busy or not _live() or effects!=_weapons.get_ref().rpg_effects or not _flight._busy or not request.get("token") is int or not _launches.has(request.token): return {"invalid":true}
	var row:=_slot(request.token)
	if row.is_empty() or request.get("origin")!=row.position or request.get("direction")!=row.direction or request.get("item_uid")!=row.item_uid or request.get("shot_id")!=row.shot_id or not Rules._finite(request.get("range")) or request.range<=0 or request.range>15*SCALE-row.travelled+.0001: return {"invalid":true}
	var launch: Dictionary=_launches[request.token]
	if Time.get_ticks_usec()-launch.accepted_usec>15000000: _launches.erase(request.token); return {"invalid":true}
	_ray.from=request.origin; _ray.to=request.origin+request.direction*float(request.range); _ray.exclude=[_player.get_ref().get_rid()]
	var raw: Dictionary=_world.get_ref().get_world_3d().direct_space_state.intersect_ray(_ray)
	var hit:={"hit":false}
	if not raw.is_empty():
		var collider: Variant=raw.collider
		if not collider is CollisionObject3D or not is_instance_valid(collider) or collider.is_queued_for_deletion() or collider.get_world_3d()!=_world.get_ref().get_world_3d(): return {"invalid":true}
		hit={"hit":true,"point":raw.position,"normal":raw.normal if raw.normal.length_squared()>.000001 else -request.direction,"distance":request.origin.distance_to(raw.position),"collider":collider,"rid":collider.get_rid(),"instance_id":collider.get_instance_id(),"shape":raw.shape}
	launch.query=request.duplicate(true); launch.result=hit.duplicate(true); launch.travelled_before=row.travelled
	return hit

## Called BEFORE cosmetic publication, only inside Flight's impact callback.
func native_impact(effects: RefCounted, receipt: Dictionary) -> Dictionary:
	if _busy or not _live() or effects!=_weapons.get_ref().rpg_effects or not _flight._busy or not receipt.get("token") is int or not _launches.has(receipt.token): return _bad("native_flight_callback_required")
	var launch: Dictionary=_launches[receipt.token]; var row: Dictionary=launch.row
	if not _slot(receipt.token).is_empty() or launch.query.is_empty() or Time.get_ticks_usec()-launch.accepted_usec>15000000: return _bad("unconsumed_or_stale_flight")
	for key: String in ["actor_id","life_generation","scene_token"]:
		if receipt.get(key)!=_binding[key]: return _bad("actor_or_scene")
	for key: String in ["shot_id","item_uid","sequence","origin","direction"]:
		if receipt.get(key)!=row[key]: return _bad("launch_mismatch")
	if receipt.get("hit")!=launch.result or receipt.get("damage")!=160 or receipt.get("source_radius_cells")!=RADIUS_CELLS or receipt.get("native_rpg_impact")!=true or receipt.get("explosive")!=true or receipt.get("authority")!="EXTERNAL_OWNER_REQUIRED": return _bad("native_receipt")
	var hit: Dictionary=launch.result; var query: Dictionary=launch.query
	var point: Vector3=hit.point if hit.hit else query.origin+query.direction*float(query.range)
	var travelled: float=float(launch.travelled_before)+(float(hit.distance) if hit.hit else float(query.range))
	var range_end: bool=not hit.hit and absf(travelled-15*SCALE)<.00001
	var normal: Vector3=hit.normal.normalized() if hit.hit else -row.direction
	if receipt.get("point")!=point or receipt.get("normal")!=normal or receipt.get("distance_world")!=travelled or receipt.get("range_end")!=range_end or (not hit.hit and not range_end): return _bad("endpoint")
	if hit.hit:
		var c: Variant=hit.collider
		if not is_instance_valid(c) or c.is_queued_for_deletion() or c.get_instance_id()!=hit.instance_id or c.get_rid()!=hit.rid or c.get_world_3d()!=_world.get_ref().get_world_3d(): return _bad("collider_lifetime")
	_launches.erase(receipt.token) # Consume before any recipient/context callback.
	_busy=true; var epoch:=_epoch
	var ctx: Variant=_damage_context.call()
	if epoch!=_epoch or not _live() or not ctx is Dictionary or not Rules._finite(ctx.get("marksman")) or not ctx.get("critical") is bool or not Rules._finite(ctx.get("critical_multiplier")): _busy=false; return _bad("current_damage_context")
	var hits: Array[Dictionary]=[]
	for owner: RefCounted in _owners:
		if epoch!=_epoch or not _live(): break
		var leased:=_target_current(owner)
		if leased.is_empty(): continue
		var dx: float=(leased.position.x-point.x)/SCALE
		var dz: float=(leased.position.z-point.z)/SCALE
		var distance: float=sqrt(dx*dx+dz*dz)
		var damage:=blast_damage(distance,ctx.marksman,ctx.critical,ctx.critical_multiplier)
		if damage<=0: continue
		var direction:=Vector2(dx/distance,dz/distance) if distance>.01 else Vector2(1,0)
		var target_ticket:=TargetTicket.new()
		var id: String="rpg:"+str(_binding.life_generation)+":"+str(receipt.token)+":"+leased.token.source_id
		var player: CharacterBody3D=_player.get_ref()
		_targets[target_ticket]={"owner":owner,"token":leased.token.duplicate(),"binding":leased.binding.duplicate(),"event_id":id,"point":point,"target_position":leased.position,"hit":{"weapon_id":"rpg","damage":damage,"dir_r":direction.y,"dir_c":direction.x,"player_r":(player.global_position.z+45.1)/SCALE,"player_c":(player.global_position.x+395.65)/SCALE,"source":{"kind":"player","uid":"local"},"blast_origin_world":point},"admission_kind":"owner_proved_native_rpg"}
		var result: Variant=owner.accept_native_rpg_blast(self,target_ticket)
		_targets.erase(target_ticket)
		hits.append({"source_id":leased.token.source_id,"damage":damage,"result":result})
	_busy=false; last_result={"ok":epoch==_epoch and _live(),"token":receipt.token,"hits":hits,"scope":"new_local_session_ordinary_rpg","occlusion":"source_rpg_has_no_npc_LOS","source_callbacks_complete":false}
	return last_result.duplicate(true)

func _target_current(owner: RefCounted) -> Dictionary:
	if not is_instance_valid(owner) or owner._host!=_resident_host or owner._weapons!=_weapons.get_ref() or owner._rpg_blast_gate!=self: return {}
	var token: Dictionary=owner._token
	if not _resident_host.physical_life_current(token) or owner._current(owner._binding).is_empty(): return {}
	var body: Variant=token.get("body")
	if not body is CharacterBody3D or not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_inside_tree() or body.get_world_3d()!=_world.get_ref().get_world_3d() or token.body_instance_id!=body.get_instance_id() or token.body_rid!=body.get_rid(): return {}
	if owner._row.get("dead",false) or owner._row.get("_evacuated",false): return {}
	var position: Vector3=body.global_position
	if _resident_host._ragdolls.has(token.source_id):
		var physical: RefCounted=_resident_host._ragdolls[token.source_id]
		if physical.mode in ["ACTIVE","RECOVERING","RECOVERY_HOLD"]:
			var sample: Dictionary=physical._body.snapshot()
			if not sample.get("valid",false) or not sample.get("active",false) or not sample.get("anchor_world") is Vector3: return {}
			position=sample.anchor_world
	if not position.is_finite(): return {}
	return {"body":body,"token":token,"binding":owner._binding,"position":position}

## The recipient takes the opaque ticket while called synchronously above.
## A copied Dictionary, replayed ticket, different owner/life or later callback
## is rejected even if it repeats every printed receipt field.
func take_target(owner: RefCounted, ticket: RefCounted) -> Dictionary:
	if not _busy or not _live() or ticket==null or not _targets.has(ticket): return _bad("target_capability")
	var value: Dictionary=_targets[ticket]; _targets.erase(ticket)
	var current:=_target_current(owner)
	if value.owner!=owner or current.is_empty() or current.token!=value.token or current.binding!=value.binding: return _bad("target_life")
	var result:=value.duplicate(true); result.erase("owner"); result.ok=true
	return result

static func blast_damage(distance_cells: float, marksman: float, critical: bool, critical_multiplier: float) -> int:
	if not is_finite(distance_cells) or distance_cells<0 or distance_cells>RADIUS_CELLS or not is_finite(marksman) or not is_finite(critical_multiplier): return 0
	return Rules.current_shot_damage(maxi(8,Rules._round(160*(1-distance_cells/RADIUS_CELLS*.72))),marksman,critical,critical_multiplier)
func dispose() -> void:
	_disposed=true; _epoch+=1; _pending={}; _launches.clear(); _targets.clear()
	for owner: RefCounted in _owners:
		if is_instance_valid(owner) and owner._rpg_blast_gate==self: owner._rpg_blast_gate=null
	_owners.clear(); _damage_context=Callable()
