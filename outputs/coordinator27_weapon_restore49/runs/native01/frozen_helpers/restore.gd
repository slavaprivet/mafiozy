extends RefCounted
const Checkpoint=preload("checkpoint.gd")
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
const SCHEMA:="mafiozi.private-local-weapon-save/v1"
class Capability extends RefCounted:
	pass
var _cap:Capability
var _document:Dictionary={}
var _bindings:Dictionary={}
var _used:=false
var _committing:=false
var _clock_anchor:=0.0
var _clock_started:=0.0
var _clock_running:=false
var result:Dictionary={}
func now()->float:
	return _clock_anchor+(Time.get_ticks_usec()/1000.0-_clock_started if _clock_running else 0.0)
static func fail(reason:String)->Dictionary:return {"ok":false,"reason":reason}
static func strict_fire(state:Variant,id:String)->bool:
	var sample:Dictionary=Fire.create_state(id)
	if not Checkpoint.keys(state,sample.keys()):return false
	if id=="none":return Checkpoint.canonical(state)==Checkpoint.canonical(sample)
	if not Checkpoint.fire(state,id):return false
	var profile:Dictionary=Fire.profile(id)
	if state.triggerHeld:return false
	if state.cooldown>profile.cooldown or state.reloadRemaining>profile.reloadSeconds or state.recoil>profile.recoil*2.15:return false
	if not Checkpoint.integer(state.sprayShots):return false
	if not Checkpoint.number(state.sprayHeat) or state.sprayHeat<0 or state.sprayHeat>1:return false
	if not Checkpoint.number(state.sprayRecoveryRemaining) or state.sprayRecoveryRemaining<0 or state.sprayRecoveryRemaining>profile.handling.recovery:return false
	if not Checkpoint.number(state.lastRecoilYaw) or absf(state.lastRecoilYaw)>1:return false
	return Checkpoint.number(state.lastRecoilScale) and state.lastRecoilScale>0 and state.lastRecoilScale<=maxf(1,profile.handling.visualKick*1.28)
static func validate(doc:Variant)->Dictionary:
	if not Checkpoint.keys(doc,["schema","clock_policy","checkpoint","transport","cargo_serial","source_process"]):return fail("ENVELOPE_KEYS")
	if doc.schema!=SCHEMA or doc.clock_policy!="LOCAL_OFFLINE_FREEZE":return fail("SCHEMA_CLOCK")
	if not Checkpoint.integer(doc.source_process,1) or not Checkpoint.integer(doc.cargo_serial):return fail("SERIAL")
	var v:Dictionary=doc.checkpoint
	var checked:=Checkpoint.validate(v)
	if not checked.ok:return checked
	if v.actor!={"actor_id":"player","life_generation":1}:return fail("ACTOR_DOMAIN")
	if checked.items!=14:return fail("COMPLETE_ARSENAL_REQUIRED")
	var seen:Dictionary={}
	for row:Dictionary in checked.locations:
		if seen.has(row.weapon_id) or not strict_fire(row.fire_state,row.weapon_id):return fail("STRICT_FIRE_OR_DUPLICATE_WEAPON")
		seen[row.weapon_id]=true
	if not strict_fire(v.inventory.host_fire_state,v.inventory.equippedId):return fail("STRICT_HOST_FIRE")
	var t:Variant=doc.transport
	if not Checkpoint.keys(t,["vehicle_id","life_generation","profile_id","position_m","yaw_rad","parking_id","origin_m"]):return fail("TRANSPORT_KEYS")
	if t.vehicle_id!=v.vehicles[0].vehicle_id or t.life_generation!=v.vehicles[0].life_generation:return fail("VEHICLE_REF")
	if not Checkpoint.ident(t.profile_id) or not Checkpoint.ident(t.parking_id) or not Checkpoint.vec(t.position_m) or not Checkpoint.vec(t.origin_m) or not Checkpoint.number(t.yaw_rad):return fail("TRANSPORT_POSE")
	return checked
static func capture(scene:Node)->Dictionary:
	var observed:=Checkpoint.capture(scene)
	if not observed.ok:return observed
	var t:Node=scene.preview_transport
	if t.body.linear_velocity.length()>.05 or t.body.angular_velocity.length()>.05:return fail("MOVING_VEHICLE")
	var c:Node=scene.preview_weapons.get_node("WeaponCargo")
	var record:Dictionary=t.runtime.host.vehicle_record(t._vehicle_ref)
	var doc:Dictionary={"schema":SCHEMA,"clock_policy":"LOCAL_OFFLINE_FREEZE","checkpoint":observed.document,"cargo_serial":c.cargo._serial,"source_process":OS.get_process_id(),"transport":{"vehicle_id":record.vehicle_id,"life_generation":record.life_generation,"profile_id":record.profile_id,"position_m":Checkpoint.plain(t.body.global_position),"yaw_rad":t.body.global_rotation.y,"parking_id":t.PARKING_ID,"origin_m":Checkpoint.plain(scene._origin)}}
	var checked:=validate(doc)
	if not checked.ok:return checked
	return {"ok":true,"document":doc,"text":Checkpoint.wire_text(doc)}
static func decode(text:String)->Dictionary:
	if text.to_utf8_buffer().size()>Checkpoint.LIMIT:return fail("SIZE")
	var parser:=JSON.new()
	if parser.parse(text)!=OK:return fail("JSON")
	var doc:Variant=Checkpoint.unwire(parser.data)
	var checked:=validate(doc)
	if not checked.ok:return checked
	if Checkpoint.wire_text(doc)!=text:return fail("NONCANONICAL")
	return {"ok":true,"document":doc}
func admit(text:String,trusted_digest:String,grant:String)->Dictionary:
	if _used or _cap!=null:return fail("REPLAY")
	_used=true
	if grant.length()!=64 or trusted_digest.length()!=64 or text.sha256_text()!=trusted_digest:return fail("PROVENANCE")
	var parsed:=decode(text)
	if not parsed.ok:return parsed
	_document=parsed.document.duplicate(true)
	_clock_anchor=_document.checkpoint.capture.mono_ms
	_cap=Capability.new()
	return {"ok":true,"capability":_cap,"server_grants":0}
func bind(owner:Object,role:String)->bool:
	if _cap==null or _committing or _bindings.has(role) or not is_instance_valid(owner):return false
	_bindings[role]=owner
	return true
func allows(cap:RefCounted,owner:Object,role:String)->bool:
	return cap!=null and cap==_cap and _bindings.get(role)==owner
func capability()->RefCounted:return _cap
func data()->Dictionary:return _document.duplicate(true)
func transport_packet(owner:Node,origin:Vector3)->Dictionary:
	if not bind(owner,"transport"):return fail("TRANSPORT_CAPABILITY")
	var record:Dictionary=_document.transport.duplicate(true)
	if Checkpoint.plain(origin)!=record.origin_m:return fail("ORIGIN")
	var clock:int=maxi(1,Time.get_ticks_usec())
	var session:Dictionary=_document.checkpoint.session.duplicate(true)
	session.source_clock=clock
	record.erase("origin_m")
	record.merge({"source_clock":clock+1,"active":true,"seats":{}})
	if owner.runtime.catalog.profile(record.profile_id).is_empty():return fail("PROFILE")
	var roster:Dictionary={"session_id":session.session_id,"session_generation":session.session_generation,"source_clock":clock+1,"roster_revision":1,"actors":[],"vehicles":[record]}
	return {"ok":true,"session":session,"roster":roster,"physics_births":[{"vehicle_record":record,"profile_descriptor":owner.runtime.catalog.profile(record.profile_id)}]}
func commit(scene:Node)->Dictionary:
	if _cap==null or _committing or not result.is_empty():return fail("REPLAY")
	var w:Node=scene.preview_weapons
	var c:Node=w.get_node("WeaponCargo")
	var empty_before:String=Checkpoint.canonical({"inventory":w.inventory.snapshot(),"ids":w.inventory.item_identity_snapshot(),"cargo":c.cargo.snapshot(c.generation)})
	if not bind(w.inventory,"inventory") or not bind(c.cargo,"cargo"):return fail("OWNER_BIND")
	var inv:Dictionary=w.inventory.prepare_local_restore(self,_cap,_document.checkpoint.inventory)
	var cargo:Dictionary=c.cargo.prepare_local_restore(self,_cap,_document.checkpoint.vehicles[0],int(_document.cargo_serial))
	if not inv.ok or not cargo.ok:return fail("OWNER_PREPARE:"+str(inv)+str(cargo))
	if not w.presentation.equip(_document.checkpoint.inventory.equippedId).get("ok",false):return fail("PRESENTATION")
	var trunk:Dictionary=c.renderer.sync_trunk(c.vehicle_id,c.generation,cargo.items)
	var ground:Dictionary=c.renderer.sync_ground(_document.checkpoint.inventory.dropped,_document.checkpoint.inventory.identities.dropped)
	if not trunk.ok or not ground.ok:return fail("RENDERER_PREPARE:"+str(trunk)+str(ground))
	if empty_before!=Checkpoint.canonical({"inventory":w.inventory.snapshot(),"ids":w.inventory.item_identity_snapshot(),"cargo":c.cargo.snapshot(c.generation)}):return fail("PREPARE_MUTATED_OWNERS")
	# All fallible work finished. Synchronous owner assignments only: no awaits,
	# callbacks, IO, UI notifications or gameplay signals inside this block.
	_committing=true
	w.inventory.commit_local_restore(self,_cap,inv)
	c.cargo.commit_local_restore(self,_cap,cargo)
	w.fire_state=_document.checkpoint.inventory.host_fire_state.duplicate(true)
	w._profile=Fire.profile(w.fire_state.weaponId)
	_clock_started=Time.get_ticks_usec()/1000.0
	_clock_running=true
	result={"ok":true,"items":14,"server_grants":0,"bootstrap_items_minted":w.inventory.local_restore_minted,"clock_policy":"LOCAL_OFFLINE_FREEZE","native_process":OS.get_process_id(),"source_process":_document.source_process}
	_cap=null
	scene.preview_ready=true
	return result.duplicate(true)
