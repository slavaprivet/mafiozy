extends RefCounted
## Observation/export and reconciliation PLAN only. No adoption or scene writes.
const Profiles = preload("res://scripts/weapons/weapon_fire_profiles.gd")
const SCHEMA := "mafiozi.local-weapon-checkpoint/v1"
const BASE := "51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7"
const LIMIT := 262144
static func bad(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
static func number(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func integer(v: Variant, low: float=0, high: float=9007199254740991.0) -> bool:
	return number(v) and v>=low and v<=high and floor(float(v))==float(v)
static func ident(v: Variant) -> bool: return v is String and not v.is_empty() and v.length()<=128 and v.strip_edges()==v
static func keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size()!=expected.size(): return false
	for key: String in expected:
		if not value.has(key): return false
	return true
static func plain(v: Variant, depth: int=0) -> Variant:
	if depth>16: return null
	if v is Vector3: return {"x":v.x,"y":v.y,"z":v.z}
	if v is AABB: return {"position":plain(v.position),"size":plain(v.size)}
	if v is Dictionary:
		var result := {}
		for k: Variant in v:
			if not k is String: return null
			result[k]=plain(v[k],depth+1)
		return result
	if v is Array:
		var result: Array=[]
		for x: Variant in v: result.append(plain(x,depth+1))
		return result
	if number(v): return int(v) if integer(v,-9007199254740991.0) else float(v)
	if v is String or v is bool or v==null: return v
	return null
static func finite_plain(v: Variant, depth: int=0) -> bool:
	if depth>16: return false
	if v is Dictionary:
		if v.size()>1024: return false
		for k: Variant in v:
			if not k is String or not finite_plain(v[k],depth+1): return false
		return true
	if v is Array:
		if v.size()>1024: return false
		for x: Variant in v:
			if not finite_plain(x,depth+1): return false
		return true
	return number(v) or v is bool or (v is String and v.length()<=4096)
static func canonical(v: Variant) -> String: return JSON.stringify(plain(v),"",true,true)
## Godot's decimal JSON parser can round fractional clocks/positions differently.
## Preserve non-integral binary64 payloads explicitly; never loosen equality.
static func wire(v: Variant) -> Variant:
	if v is float and not integer(v,-9007199254740991.0):
		return {"@f64":PackedFloat64Array([v]).to_byte_array().hex_encode()}
	if v is Dictionary:
		var result:Dictionary={}
		for k:String in v: result[k]=wire(v[k])
		return result
	if v is Array:
		var result:Array=[]
		for x:Variant in v:result.append(wire(x))
		return result
	return v
static func unwire(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("@f64"):
			if v.size()!=1 or not v["@f64"] is String or v["@f64"].length()!=16: return null
			for ch:String in v["@f64"]:
				if not ch in "0123456789abcdef": return null
			var bytes:PackedByteArray=v["@f64"].hex_decode()
			var value:float=bytes.to_float64_array()[0]
			return value if is_finite(value) and not integer(value,-9007199254740991.0) else null
		var result:Dictionary={}
		for k:Variant in v:
			if not k is String:return null
			result[k]=unwire(v[k])
		return result
	if v is Array:
		var result:Array=[]
		for x:Variant in v:result.append(unwire(x))
		return result
	return v
static func wire_text(v: Variant) -> String: return JSON.stringify(wire(plain(v)),"",true,true)
static func fire(state: Variant, id: String) -> bool:
	if not state is Dictionary or not Profiles.PROFILES.has(id) or state.get("weaponId")!=id: return false
	if not integer(state.get("magazine"),0,Profiles.PROFILES[id].magazineSize) or not integer(state.get("reserveAmmo"),0,9999) or not integer(state.get("sequence")): return false
	for k: String in ["cooldown","reloadRemaining","recoil"]:
		if not number(state.get(k)) or state[k]<0: return false
	return state.get("triggerHeld") is bool and finite_plain(state)
static func vec(v: Variant) -> bool:
	return keys(v,["x","y","z"]) and number(v.x) and number(v.y) and number(v.z)
static func owned_ref(v: Variant) -> bool:
	return keys(v,["actor_id","life_generation"]) and ident(v.actor_id) and integer(v.life_generation,1)
static func _owners(scene: Node) -> Dictionary:
	if not Thread.is_main_thread() or not is_instance_valid(scene) or not scene.preview_ready: return bad("OWNER_NOT_READY")
	var w: Node=scene.preview_weapons
	var t: Node=scene.preview_transport
	if not is_instance_valid(w) or not is_instance_valid(t) or not w.ready_for_play or not t.ready_for_play: return bad("MISSING_OWNER")
	var c: Node=w.get_node_or_null("WeaponCargo")
	if c==null or not c._ready_for_play or c.transport!=t or c.weapons!=w or w.player!=scene._player: return bad("OWNER_BINDING")
	if w.inventory.cargo_transfer_pending() or c.bridge._busy or c._window_busy or not w._pending_plan.is_empty() or not w._pending_shots.is_empty() or not w.rpg_effects._pending.is_empty(): return bad("BUSY_RECONCILE")
	if w.effects.stats().activeProjectiles>0 or w.rpg_effects.stats().active_rockets>0: return bad("ACTIVE_PROJECTILES")
	if is_instance_valid(scene.preview_c4) and (not scene.preview_c4._hold.is_empty() or not scene.preview_c4._charges.is_empty()): return bad("C4_RECONCILIATION_REQUIRED")
	var transport: Dictionary=t.runtime.host.diagnostics()
	if transport.vehicles!=1 or transport.actors!=1 or transport.leases!=0 or t.phase!="ON_FOOT": return bad("TRANSPORT_RECONCILIATION_REQUIRED")
	var cargo: Dictionary=c.cargo.snapshot(c.generation)
	if not cargo.get("ok",false): return bad("CARGO_OWNER")
	if cargo.pending: return bad("BUSY_RECONCILE")
	if c.vehicle_id!=t.body.get_meta("vehicle_id") or c.generation!=t.body.get_meta("life_generation"): return bad("STALE_GENERATION")
	return {"ok":true,"weapons":w,"transport":t,"cargo_host":c,"cargo":cargo,"session":transport.session}
static func capture(scene: Node) -> Dictionary:
	var bound:=_owners(scene)
	if not bound.ok: return bound
	var w: Node=bound.weapons
	var c: Node=bound.cargo_host
	var actor: Dictionary={"actor_id":w.player.get_meta("actor_id",""),"life_generation":w.player.get_meta("life_generation",0)}
	var before := _state(bound)
	var data: Dictionary={"schema":SCHEMA,"authority":"local_session_observation","base_sha256":BASE,"catalog_sha256":FileAccess.get_sha256("res://scripts/weapons/weapon_fire_profiles.gd"),"session":bound.session.duplicate(true),"actor":actor,"capture":{"clock_domain":"process_monotonic_ms","mono_ms":Time.get_ticks_usec()/1000.0,"physics_frame":Engine.get_physics_frames()},"inventory":before.inventory,"vehicles":[before.cargo],"pending_transactions":[]}
	var after_bound:=_owners(scene)
	if not after_bound.ok: return after_bound
	if after_bound.weapons!=w or after_bound.cargo_host!=c or after_bound.session!=bound.session or canonical(before)!=canonical(_state(after_bound)): return bad("CAPTURE_CHANGED")
	var checked:=validate(data)
	if not checked.ok: return checked
	return {"ok":true,"document":plain(data),"state_digest":canonical(before).sha256_text(),"effects_applied":0}
static func _state(bound: Dictionary) -> Dictionary:
	var w: Node=bound.weapons
	var c: Node=bound.cargo_host
	var inventory: Dictionary=w.inventory.snapshot()
	inventory["identities"]=w.inventory.item_identity_snapshot()
	inventory["drop_serial"]=w.inventory._serial
	inventory["item_serial"]=w.inventory._item_serial
	inventory["destroy_receipts"]=w.inventory._destroy_receipts.duplicate(true)
	inventory["host_fire_state"]=w.fire_state.duplicate(true)
	var cargo: Dictionary=c.cargo.snapshot(c.generation)
	cargo["destroy_event_uid"]=c.cargo._destroy_event_uid
	cargo["destroy_receipt"]=c.cargo._destroy_receipt.duplicate(true)
	return plain({"inventory":inventory,"cargo":cargo})
static func validate(v: Variant) -> Dictionary:
	if not keys(v,["schema","authority","base_sha256","catalog_sha256","session","actor","capture","inventory","vehicles","pending_transactions"]): return bad("DOCUMENT_KEYS")
	if v.schema!=SCHEMA: return bad("SCHEMA")
	if v.authority!="local_session_observation": return bad("AUTHORITY_RECONCILIATION_REQUIRED")
	if v.base_sha256!=BASE or v.catalog_sha256!=FileAccess.get_sha256("res://scripts/weapons/weapon_fire_profiles.gd"): return bad("SOURCE_BINDING")
	if not finite_plain(v): return bad("PLAIN_FINITE_LIMIT")
	if not owned_ref(v.actor): return bad("MISSING_OWNER")
	if not keys(v.session,["session_id","mode","session_generation"]) or not ident(v.session.session_id) or not integer(v.session.session_generation,1) or v.session.mode!="NEW_SESSION_BOOTSTRAP": return bad("SESSION")
	if not keys(v.capture,["clock_domain","mono_ms","physics_frame"]) or v.capture.clock_domain!="process_monotonic_ms" or not number(v.capture.mono_ms) or v.capture.mono_ms<0 or not integer(v.capture.physics_frame): return bad("CLOCK")
	if not v.pending_transactions is Array or not v.pending_transactions.is_empty(): return bad("BUSY_RECONCILE")
	var inv: Variant=v.inventory
	if not keys(inv,["equippedId","ownedIds","fireStates","dropped","identities","drop_serial","item_serial","destroy_receipts","host_fire_state"]): return bad("INVENTORY_KEYS")
	if not inv.ownedIds is Array or not inv.fireStates is Dictionary or not inv.dropped is Array or not keys(inv.identities,["owned","dropped"]) or not inv.identities.owned is Dictionary or not inv.identities.dropped is Dictionary: return bad("INVENTORY_SHAPE")
	if not integer(inv.drop_serial) or not integer(inv.item_serial) or not inv.destroy_receipts is Dictionary: return bad("SERIAL_OR_TOMBSTONES")
	for receipt: String in inv.destroy_receipts:
		if not ident(receipt) or inv.destroy_receipts[receipt]!=true: return bad("TOMBSTONE")
	if inv.ownedIds.size()!=inv.fireStates.size() or inv.ownedIds.size()!=inv.identities.owned.size(): return bad("MISSING_IDENTITY")
	var seen := {}; var weapon_ids := {}; var drop_ids := {}; var locations: Array=[]; var ammo:=0.0
	for id: Variant in inv.ownedIds:
		if not id is String or weapon_ids.has(id) or not inv.fireStates.has(id) or not inv.identities.owned.has(id) or not fire(inv.fireStates[id],id): return bad("OWNED_STATE")
		var uid: Variant=inv.identities.owned[id]
		if not ident(uid) or seen.has(uid): return bad("DUPLICATE_UID")
		seen[uid]=true; weapon_ids[id]=true; locations.append({"item_uid":uid,"weapon_id":id,"location":"owned","owner":v.actor.duplicate(true),"fire_state":inv.fireStates[id].duplicate(true)})
		ammo+=inv.fireStates[id].magazine+inv.fireStates[id].reserveAmmo
	if not inv.equippedId is String or (inv.equippedId!="none" and not weapon_ids.has(inv.equippedId)): return bad("EQUIPPED")
	if inv.equippedId!="none" and canonical(inv.host_fire_state)!=canonical(inv.fireStates[inv.equippedId]): return bad("UNSETTLED_FIRE_STATE")
	if inv.equippedId=="none" and inv.host_fire_state.get("weaponId")!="none": return bad("HOST_FIRE_STATE")
	if inv.dropped.size()!=inv.identities.dropped.size(): return bad("MISSING_IDENTITY")
	for drop: Variant in inv.dropped:
		if not keys(drop,["uid","weaponId","position","yaw","droppedAt","expiresAt","fireState"]) or not ident(drop.uid) or drop_ids.has(drop.uid) or not inv.identities.dropped.has(drop.uid): return bad("GROUND_RECORD")
		var uid: Variant=inv.identities.dropped[drop.uid]
		if not ident(uid) or seen.has(uid): return bad("DUPLICATE_UID")
		if not drop.weaponId is String or not fire(drop.fireState,drop.weaponId) or not vec(drop.position) or not number(drop.yaw): return bad("GROUND_STATE")
		if not number(drop.droppedAt) or not number(drop.expiresAt) or drop.droppedAt<0 or drop.droppedAt>v.capture.mono_ms or drop.expiresAt!=drop.droppedAt+300000.0 or drop.expiresAt<=v.capture.mono_ms: return bad("EXPIRED_OR_INVALID_CLOCK")
		seen[uid]=true; drop_ids[drop.uid]=true; locations.append({"item_uid":uid,"weapon_id":drop.weaponId,"location":"ground","drop_uid":drop.uid,"owner":v.actor.duplicate(true),"fire_state":drop.fireState.duplicate(true),"remaining_ms":drop.expiresAt-v.capture.mono_ms})
		ammo+=drop.fireState.magazine+drop.fireState.reserveAmmo
	if not v.vehicles is Array or v.vehicles.size()!=1: return bad("MISSING_CARGO_OWNER")
	for vehicle: Variant in v.vehicles:
		if not keys(vehicle,["ok","vehicle_id","life_generation","revision","capacity_units","used_units","destroyed","pending","items","destroy_event_uid","destroy_receipt"]): return bad("CARGO_KEYS")
		if vehicle.ok!=true or not ident(vehicle.vehicle_id) or not integer(vehicle.life_generation,1) or not integer(vehicle.revision,1) or vehicle.capacity_units!=100 or not integer(vehicle.used_units,0,100) or not vehicle.destroyed is bool or not vehicle.pending is bool or not vehicle.items is Array or vehicle.items.size()>100: return bad("CARGO_STATE")
		if vehicle.pending: return bad("BUSY_RECONCILE")
		if not vehicle.destroy_event_uid is String or not vehicle.destroy_receipt is Dictionary: return bad("CARGO_TOMBSTONE")
		if vehicle.destroyed or not vehicle.destroy_event_uid.is_empty() or not vehicle.destroy_receipt.is_empty(): return bad("DESTROY_RECONCILIATION_REQUIRED")
		var units:=0
		for entry: Variant in vehicle.items:
			if not keys(entry,["item","capacity_units","model_aabb","item_bounds_local_m","model_origin_local_m"]): return bad("CARGO_ENTRY")
			var item: Variant=entry.item
			if not keys(item,["uid","itemUID","kind","weaponId","fireState"]) or item.kind!="weapon" or not ident(item.uid) or item.uid!=item.itemUID or not item.weaponId is String or not fire(item.fireState,item.weaponId): return bad("CARGO_ITEM")
			if seen.has(item.uid): return bad("DUPLICATE_UID")
			if not integer(entry.capacity_units,1,100): return bad("CAPACITY")
			for box: Variant in [entry.model_aabb,entry.item_bounds_local_m]:
				if not keys(box,["position","size"]) or not vec(box.position) or not vec(box.size) or box.size.x<=0 or box.size.y<=0 or box.size.z<=0: return bad("CARGO_GEOMETRY")
			if not vec(entry.model_origin_local_m): return bad("CARGO_GEOMETRY")
			units+=int(entry.capacity_units); seen[item.uid]=true
			locations.append({"item_uid":item.uid,"weapon_id":item.weaponId,"location":"cargo","owner":{"vehicle_id":vehicle.vehicle_id,"life_generation":vehicle.life_generation},"fire_state":item.fireState.duplicate(true)})
			ammo+=item.fireState.magazine+item.fireState.reserveAmmo
		if units!=vehicle.used_units or units>vehicle.capacity_units: return bad("CAPACITY")
	return {"ok":true,"items":seen.size(),"ammo_total":ammo,"locations":locations}
static func encode(document: Dictionary) -> Dictionary:
	var checked:=validate(document)
	if not checked.ok: return checked
	var payload:=wire_text(document)
	if payload.to_utf8_buffer().size()>LIMIT: return bad("SIZE")
	return {"ok":true,"text":payload,"sha256":payload.sha256_text()}
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size()>LIMIT: return bad("SIZE")
	var depth:=0; var quoted:=false; var escaped:=false
	for ch: String in text:
		if quoted:
			if escaped: escaped=false
			elif ch=="\\": escaped=true
			elif ch=='"': quoted=false
		elif ch=='"': quoted=true
		elif ch in ["{","["]:
			depth+=1
			if depth>16: return bad("DEPTH")
		elif ch in ["}","]"]: depth-=1
	var json:=JSON.new()
	if json.parse(text)!=OK: return bad("JSON")
	var document:Variant=unwire(json.data)
	var checked:=validate(document)
	if not checked.ok: return checked
	if wire_text(document)!=text: return bad("NON_CANONICAL_OR_DUPLICATE_KEYS")
	return {"ok":true,"document":document,"sha256":text.sha256_text()}
static func plan(document: Dictionary, current_document: Dictionary) -> Dictionary:
	var checked:=validate(document)
	if not checked.ok: return checked
	var current:=validate(current_document)
	if not current.ok: return bad("CURRENT_OWNER_UNAVAILABLE")
	if canonical(document.session)!=canonical(current_document.session): return bad("CROSS_SESSION")
	if canonical(document.actor)!=canonical(current_document.actor): return bad("STALE_ACTOR_GENERATION")
	if document.vehicles[0].vehicle_id!=current_document.vehicles[0].vehicle_id or document.vehicles[0].life_generation!=current_document.vehicles[0].life_generation: return bad("STALE_GENERATION")
	if document.vehicles[0].revision!=current_document.vehicles[0].revision: return bad("STALE_REVISION")
	if canonical(document.inventory)!=canonical(current_document.inventory) or canonical(document.vehicles)!=canonical(current_document.vehicles): return bad("OWNER_STATE_CHANGED")
	return {"ok":true,"status":"SAME_LOCAL_OBSERVATION_PLAN_ONLY","authority":"local_session_observation","restore_authorized":false,"server_grants":0,"effects_applied":0,"items":checked.items,"ammo_total":checked.ammo_total,"locations":checked.locations,"document_sha256":wire_text(document).sha256_text(),"required_before_restore":["trusted owner adoption APIs","new runtime capability binding","clock reconciliation","server acknowledgement for server domains"]}
