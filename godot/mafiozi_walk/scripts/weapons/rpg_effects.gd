extends RefCounted
## Original source rocket geometry + explosion animation. Cosmetic only.
const Flight = preload("rpg_flight.gd")
const Geometry = preload("res://scripts/weapons/weapon_projectiles.gd")
const SURFACE_DATA := "res://data/weapons/surface_effect_meshes.json"
const SURFACE_SHA := "b968eb74064b3028cdcdbce0336ac90b174e5c2c98f9d2417905a1da0dd9a0c1"
const EXPLOSION_CAP := 6
signal cosmetic_impact(receipt: Dictionary)
## Observation only; the admitted world-damage bridge owns local consequences.
signal native_impact(receipt: Dictionary)
var _host: WeakRef
var _root: Node3D
var _flight: RefCounted
var _rockets: Array[Dictionary] = []
var _explosions: Array[Dictionary] = []
var _cursor := 0
var _explosion_count := 0
var _ready := false
var _pending: Dictionary = {}
var _impacts := 0
var _visual_count := 0
var _binding: Dictionary = {}
var _builder: RefCounted

func configure(host: Node, options: Dictionary = {}) -> Dictionary:
	if _ready or not is_instance_valid(host) or not host._owner_current(): return {"ok":false,"reason":"owner"}
	if not host.effects.get_script().get_script_constant_map().get("SHARED_RPG_FLIGHT",false): return {"ok":false,"reason":"shared_pool_patch_required"}
	if FileAccess.get_sha256(SURFACE_DATA) != SURFACE_SHA or FileAccess.get_sha256(Geometry.DATA_PATH) != Geometry.DATA_SHA256: return {"ok":false,"reason":"source_mesh_hash"}
	var surfaces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SURFACE_DATA))
	if surfaces.source_sha256 != Geometry.SOURCE_SHA256 or not host.effects._configured: return {"ok":false,"reason":"source"}
	var cap: Variant = options.get("capacity",112)
	if not cap is int or cap < 1 or cap > 112: return {"ok":false,"reason":"capacity"}
	_host = weakref(host); _builder = Geometry.new()
	_root = Node3D.new(); _root.name = "OriginalRpgEffects"; host.scene.add_child(_root); _root.top_level = true
	var meshes: Dictionary = {}
	for i: int in cap:
		_rockets.append({"node":null,"parts":[],"entry":{},"token":0})
	_collect_meshes(surfaces.explosion,surfaces.meshes,meshes)
	for i: int in EXPLOSION_CAP:
		var node: Node3D = _builder._node(surfaces.explosion,meshes); _root.add_child(node)
		var children := node.get_children()
		if children.size() != 28: dispose(); return {"ok":false,"reason":"source_explosion_parts"}
		_explosions.append({"node":node,"core":children[0],"fire":children.slice(1,9),"smoke":children.slice(9,15),"embers":children.slice(15,27),"shock":children[27],"active":false,"life":0.0,"angles":PackedFloat64Array(),"fire_cos":PackedFloat64Array(),"fire_sin":PackedFloat64Array(),"smoke_cos":PackedFloat64Array(),"smoke_sin":PackedFloat64Array(),"ember_cos":PackedFloat64Array(),"ember_sin":PackedFloat64Array()})
	_binding = {"actor_id":host.player.get_meta("actor_id"),"life_generation":host.player.get_meta("life_generation"),"scene_token":"preview-scene:"+str(host.scene.get_instance_id())}
	_flight = Flight.new(); _ready = true
	var result: Dictionary = _flight.configure(_binding,Callable(self,"_owner_state"),Callable(self,"_muzzle"),Callable(self,"_query"),Callable(self,"_impact"),{"capacity":cap})
	if not result.ok: dispose(); return result
	return {"ok":true,"rockets":cap,"explosions":EXPLOSION_CAP}
func _collect_meshes(spec: Dictionary, source: Dictionary, meshes: Dictionary) -> void:
	if spec.mesh!=null and not meshes.has(spec.mesh): meshes[spec.mesh]=_builder._mesh(source[spec.mesh])
	for child: Dictionary in spec.children: _collect_meshes(child,source,meshes)
func _live() -> bool:
	return _ready and _host != null and is_instance_valid(_host.get_ref()) and _host.get_ref()._owner_current() and is_instance_valid(_root) and not _root.is_queued_for_deletion()
func _owner_state() -> Dictionary:
	if not _live(): return {"active":false}
	var host: Node = _host.get_ref()
	return {"active":not host.scene.preview_dead and not host.scene.preview_physics_fault,"actor_id":host.player.get_meta("actor_id"),"life_generation":host.player.get_meta("life_generation"),"scene_token":"preview-scene:"+str(host.scene.get_instance_id()),"equipped_item_uid":host.inventory.get_item_uid("rpg") if host.fire_state.weaponId == "rpg" else ""}
func _muzzle() -> Dictionary:
	return _host.get_ref().presentation.current_muzzle() if _live() else {"ok":false}
func _query(request: Dictionary) -> Dictionary:
	if not _live(): return {"hit":false}
	var hit: Dictionary = _host.get_ref()._projectile_ray(request)
	if hit.get("invalid",false): return {"invalid":true}
	if hit.is_empty(): return {"hit":false}
	# Starting inside a real collider has a zero surface normal in Godot. The
	# source fallback normal is opposite travel; preserve immediate contact.
	if hit.normal.length_squared() < 0.000001: hit.normal = -request.direction
	hit.hit = true
	return hit

func prepare_shot(shot: Dictionary, receipt: Dictionary, target: Vector3) -> Dictionary:
	if not _live() or not _pending.is_empty() or not target.is_finite() or not receipt.get("origin") is Vector3: return {"ok":false,"reason":"state"}
	var direction: Vector3 = target-receipt.origin
	if direction.length_squared() < 0.000001: return {"ok":false,"reason":"aim"}
	var host: Node = _host.get_ref()
	var result: Dictionary = _flight.prepare_launch(shot,receipt,host.inventory.get_item_uid("rpg"),direction.normalized())
	if result.get("ok",false): _pending = result.duplicate(); _pending.origin = receipt.origin
	return result
func cancel_shot(ticket: RefCounted) -> void:
	if _flight != null: _flight.cancel_launch(ticket)
	if _pending.get("ticket") == ticket: _pending = {}
func commit_shot(ticket: RefCounted) -> bool:
	# No externally supplied callback from here to visible launch. Host has just
	# committed inventory once; all data/resources were validated/prepared above.
	if not _live() or _pending.get("ticket") != ticket: return false
	var result: Dictionary = _flight.commit_launch(ticket)
	_pending = {}
	if not result.get("ok",false): return false
	var row: Dictionary = _rockets[result.slot]
	# An earlier shared-slot eviction can retire flight before this renderer's
	# next advance. Release that obsolete mapping before recycling its flight slot.
	if row.token>0: _release_visual(row)
	row.token = result.token; _visual_count += 1
	var fx: RefCounted = _host.get_ref().effects
	var shared: Dictionary = fx._take(fx._projectiles,"projectiles")
	shared.external_flight = _flight; shared.external_token = result.token
	shared.direction=result.direction; shared.remaining=result.range_world; shared.visual_id="rpg"
	row.entry=shared; row.node=shared.root; row.parts=shared.root.get_children()
	var node: Node3D = row.node; node.position = result.position; node.quaternion = Quaternion(Vector3.BACK,result.direction); node.visible = true
	var p: Array = row.parts; var visual: Dictionary = result.visual
	var caliber: float = visual.caliber; var length: float = visual.length; var trail: float = visual.trail
	p[0].scale = Vector3(caliber*2,length,caliber*2); p[0].position.z = 0
	p[1].visible = true; p[1].scale = Vector3(caliber*2.1,length*.45,caliber*2.1); p[1].position.z = length*.58
	p[2].scale = Vector3(maxf(.003,caliber*.24),trail,maxf(.003,caliber*.24)); p[2].position.z = -trail*.52-length*.42; p[2].visible = true
	_builder._opacity(p[2],.48); _builder._color(p[0],visual.color,true); _builder._color(p[1],visual.color,true); _builder._color(p[2],0xcf9752)
	p[3].visible = true; p[3].scale = Vector3(caliber*2.07,length*.08,caliber*2.07); p[3].position.z = -length*.33
	for i: int in [4,5]: p[i].visible = true; p[i].scale = Vector3(caliber*4.5,caliber*1.5,length*.3); p[i].position.z = -length*.35
	# Borrow the existing source flash pool; do not allocate a duplicate one.
	fx._rounds += 1; fx._shots += 1; fx._flash(result.position,result.direction,"rocket")
	return true

func _release_visual(row: Dictionary) -> void:
	# Only the currently owned token may hide a shared node. A bullet may have
	# already evicted this flight and taken the same render slot.
	if row.token>0 and row.entry.get("external_token",0)==row.token:
		row.entry.erase("external_flight"); row.entry.erase("external_token")
		if _host!=null and is_instance_valid(_host.get_ref()) and _host.get_ref().effects._configured: _host.get_ref().effects._hide(row.entry)
	if row.token>0: _visual_count-=1
	row.token=0

func _impact(receipt: Dictionary) -> void:
	if not _live(): return
	_impacts += 1
	for row: Dictionary in _rockets:
		if row.token == receipt.token: _release_visual(row); break
	_spawn_explosion(receipt.point)
	# One outward event, only for source scorch hook and diagnostics. No HP/AoE.
	var hit: Dictionary = receipt.hit
	if hit.get("hit",false):
		cosmetic_impact.emit({"weaponId":"rpg","shotId":receipt.shot_id,"point":receipt.point,"normal":receipt.normal,"direction":receipt.direction,"collider":hit.get("collider"),"projectile_kind":"rocket","explosive":true,"cosmetic_only":true})

	if _live(): native_impact.emit(receipt.duplicate(true))

func _spawn_explosion(point: Vector3) -> void:
	var entry: Dictionary = _explosions[_cursor%EXPLOSION_CAP]; _cursor += 1
	if not entry.active: _explosion_count += 1
	entry.active = true; entry.life = 1.25
	var seed: float = _cursor*.618
	for name: String in ["angles","fire_cos","fire_sin","smoke_cos","smoke_sin","ember_cos","ember_sin"]: entry[name].clear()
	for n: int in 8:
		var angle: float = n*2.399+seed; entry.angles.append(angle); entry.fire_cos.append(cos(angle)); entry.fire_sin.append(sin(angle))
	for n: int in 6:
		var angle: float = n*2.4+seed; entry.smoke_cos.append(cos(angle)); entry.smoke_sin.append(sin(angle))
	for n: int in 12:
		var angle: float = n*2.17+seed; entry.ember_cos.append(cos(angle)); entry.ember_sin.append(sin(angle))
	entry.node.position = point; entry.node.scale = Vector3.ONE; entry.node.visible = true; entry.core.scale = Vector3.ONE
	_builder._opacity(entry.core,.96); entry.shock.scale = Vector3.ONE*.3; _builder._opacity(entry.shock,.8)

func advance(delta: float) -> void:
	if not _live() or not is_finite(delta) or delta < 0: return
	if _flight._active > 0:
		_flight.advance(delta)
		if not _live(): return
	if _visual_count>0:
		for i: int in _rockets.size():
			var row: Dictionary = _rockets[i]
			if row.token==0: continue
			var flight: Dictionary = _flight._slots[i]
			if flight.is_empty(): _release_visual(row)
			elif row.entry.get("external_token",0)==row.token: row.node.position=flight.position; row.entry.remaining=61.5-float(flight.travelled)
	if _explosion_count == 0: return
	var dt: float = minf(.1,delta)
	for entry: Dictionary in _explosions:
		if not entry.active: continue
		entry.life -= dt
		if entry.life <= 0: entry.active = false; entry.node.visible = false; _explosion_count -= 1; continue
		var p: float = 1-entry.life/1.25; var burst: float = sin(minf(1,p*1.7)*PI); var fade: float = maxf(0,1-p)
		entry.core.position.y = .18+burst*.48; entry.core.scale = Vector3.ONE*(.55+burst*3.6); _builder._opacity(entry.core,maxf(0,1-p*1.7)); _builder._color(entry.core,0xfff0a0 if p<.12 else 0xffa21d if p<.42 else 0xd9340c)
		entry.shock.scale = Vector3.ONE*(.3+p*8.5); _builder._opacity(entry.shock,maxf(0,1-p*2.3)*.76)
		for n: int in 8:
			var flame: MeshInstance3D = entry.fire[n]; var r: float = .12+(n%4)*.12+p*.75
			flame.position = Vector3(entry.fire_cos[n]*r,.2+burst*(.55+(n%3)*.2)+p*.38,entry.fire_sin[n]*r); flame.rotation = Vector3(entry.fire_sin[n]*.3,entry.angles[n],entry.fire_cos[n]*.22)
			flame.scale = Vector3.ONE*((.48+burst*(1.7+(n%3)*.22))*fade); _builder._opacity(flame,maxf(0,1-p*1.35))
		for n: int in 6:
			var puff: MeshInstance3D = entry.smoke[n]; var r: float = .2+p*(.85+(n%2)*.3)
			puff.position = Vector3(entry.smoke_cos[n]*r,.45+p*(1.4+(n%3)*.28),entry.smoke_sin[n]*r); puff.scale = Vector3.ONE*(.4+p*(1.9+(n%3)*.18)); _builder._opacity(puff,sin(minf(1,p*1.22)*PI)*.58)
		for n: int in 12:
			var ember: MeshInstance3D = entry.embers[n]; var travel: float = p*(1.1+(n%5)*.24); var arc: float = sin(p*PI)*(1.15+(n%4)*.24)
			ember.position = Vector3(entry.ember_cos[n]*travel,.15+arc,entry.ember_sin[n]*travel); ember.rotation = Vector3(p*(n+2)*5,p*(n+1)*6,p*(n+3)*4); ember.scale = Vector3.ONE*maxf(.12,.8-p*.66)
func stats() -> Dictionary:
	return {"active_rockets":_flight._active if _flight!=null else 0,"active_explosions":_explosion_count,"total_explosions":_cursor,"total_impacts":_impacts,"rocket_capacity":_rockets.size(),"explosion_capacity":EXPLOSION_CAP}
func dispose() -> void:
	_ready = false; _pending = {}
	if _flight != null: _flight.dispose()
	for row: Dictionary in _rockets: _release_visual(row)
	if is_instance_valid(_root): _root.hide(); _root.queue_free()
	_root = null; _host = null; _rockets.clear(); _explosions.clear(); _explosion_count = 0

