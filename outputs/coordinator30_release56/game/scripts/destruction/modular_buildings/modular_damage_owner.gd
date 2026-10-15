extends Node
## DSH_CITYTOWN (flag --city-town-damage=1): local-session damage owner for a ported
## modular destructible site (restaurant pizza, hospital structural01, small bank).
##
## WHAT IT IS
## Exactly the two things one ported "box" was missing to become a real damage target
## in the living city, and nothing else:
##
##  1. DAMAGE OWNER (native weapons). Same ports as `palazzo_host.gd:59-95`:
##     `native_building_damage_bridge.gd` is bound to the current native weapon host
##     and forwards (a) committed RPG direct hits to `site.apply_explosion()`,
##     (b) glass bullets to `site._glazing.apply_bullet()`, (c) the independent
##     11 m RPG glass wave to `site._glazing.apply_blast()`. The bridge itself
##     validates every native receipt; this node only re-checks ownership and the
##     site's own source_id/generation, then lets the accepted Palazzo chain
##     (`palazzo_finished_site.gd:188`) decide.
##
##  2. C4 TARGET. The site is registered in `modular_c4_site_registry.gd`, which
##     widens the single target-provider Callable of `c4_building_blast.gd`.
##
## WHAT IT IS NOT
## No inventory, no input, no UI, no new damage model, no charge fabrication, no
## change to any accepted Palazzo/modular30 file. `modular_site.gd` (byte-identical
## to the accepted package) is untouched: every call below is a public/known member
## the site already owns through the Palazzo chain.
##
## LIFETIME
## Created by `modular_building_site.gd::prepare()` (the port instantiator) only when
## `--city-town-damage=1` is present AND the site profile is on the owner allow-list.
## Binding is a bounded late poll: the instantiator runs before `main.gd` creates the
## weapon host (main.gd:295) and the C4 blast owner (main.gd:319). Default (no flag):
## this node is never created.

const DamageBridge = preload("res://scripts/destruction/modular30/native_building_damage_bridge.gd")
const C4Registry = preload("modular_c4_site_registry.gd")
const C4Probe = preload("modular_c4_probe.gd")

const FLAG := "--city-town-damage=1"
const PROBE_FLAG := "--city-town-damage-test=1"
const BREACH_RADIUS_M := 0.8
const MAX_BIND_FRAMES := 3600 # ~60 s at 60 Hz
const MAX_EVENTS := 32

var source_id := ""
var profile_id := ""
var status := "disabled" # disabled, geometry_ready_waiting_native_weapons, ready, failed, disposed
var report: Dictionary = {}
var _world: WeakRef
var _site_ref: WeakRef
var _damage: RefCounted
var _registry_ref: WeakRef
var _probe: Node
var _events: Array[Dictionary] = []
var _frames := 0
var _bound := false
var _disposed := false

static func flag_present() -> bool:
	return OS.get_cmdline_user_args().has(FLAG)

static func probe_flag_present() -> bool:
	return OS.get_cmdline_user_args().has(PROBE_FLAG)

func attach(world: Node3D, site: Node3D, site_source_id: String, site_profile_id: String) -> Dictionary:
	if _disposed or _world != null: return {"ok":false,"reason":"owner_lifetime"}
	if not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(site) or not site.is_inside_tree(): return {"ok":false,"reason":"world_or_site_lifetime"}
	if site_source_id.is_empty() or not site.has_method("owns_collider") or not site.has_method("_release") or not site.has_method("apply_explosion"): return {"ok":false,"reason":"site_damage_contract"}
	_world = weakref(world)
	_site_ref = weakref(site)
	source_id = site_source_id
	profile_id = site_profile_id
	status = "geometry_ready_waiting_native_weapons"
	report = {"ok":true,"enabled":true,"status":status,"source_id":source_id,"profile_id":profile_id,"flag":FLAG,
		"damage_owner":"native_building_damage_bridge","c4_target":"pending","server_authority":false,"production_accepted":false}
	set_physics_process(true)
	print("CITY_TOWN_DAMAGE_OWNER ", source_id, " ", JSON.stringify(report.duplicate(true)))
	return report.duplicate(true)

func _world_ref() -> Node3D:
	return _world.get_ref() if _world != null else null

func _site() -> Node3D:
	return _site_ref.get_ref() if _site_ref != null else null

func site_current() -> bool:
	if _disposed: return false
	var world: Node3D = _world_ref()
	var site: Node3D = _site()
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion(): return false
	if not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion(): return false
	return site.get_parent() == world and str(site.get("source_id")) == source_id and site.get("site_ready") == true

func _physics_process(_delta: float) -> void:
	if _disposed or _bound: return
	_frames += 1
	if not site_current():
		if _frames >= MAX_BIND_FRAMES: _fail("site_not_current")
		return
	var world: Node3D = _world_ref()
	var weapons: Variant = world.get("preview_weapons")
	if not is_instance_valid(weapons) or not weapons._owner_current():
		if _frames >= MAX_BIND_FRAMES: _fail("native_weapon_host_missing")
		return
	var bridge: RefCounted = DamageBridge.new()
	var result: Dictionary = bridge.configure(weapons, Callable(self, "_native_blast"), Callable(self, "_native_glass"), {"breach_radius_m":BREACH_RADIUS_M,"glass_blast_port":Callable(self, "_native_glass_blast")})
	if not result.get("ok", false):
		bridge.dispose()
		_fail("native_damage_bridge:" + str(result.get("reason", "unknown")))
		return
	_damage = bridge
	_bound = true
	status = "ready"
	var c4: Dictionary = _register_c4(world)
	report.status = status
	report.damage_bridge = result
	report.c4_target = c4
	report.bind_frames = _frames
	print("CITY_TOWN_DAMAGE_READY ", source_id, " ", JSON.stringify({"ok":true,"status":status,"source_id":source_id,"profile_id":profile_id,"bind_frames":_frames,"damage_bridge":result,"c4_target":c4}))
	if probe_flag_present(): _start_probe(world)

## Registers this site as a C4 blast target through the world-level registry, which
## widens (never replaces) the provider Callable main.gd installed.
func _register_c4(world: Node3D) -> Dictionary:
	var registry: Node = _ensure_registry(world)
	if registry == null: return {"ok":false,"reason":"registry_unavailable"}
	_registry_ref = weakref(registry)
	var registered: Dictionary = registry.call("register_site", _site())
	if not registered.get("ok", false): return {"ok":false,"reason":"registry_reject:" + str(registered.get("reason", "unknown"))}
	return {"ok":true,"registered":true,"registry":str(registry.name),"detail":registered}

func _ensure_registry(world: Node3D) -> Node:
	var existing: Node = world.get_node_or_null(NodePath("CityTownC4SiteRegistry"))
	if is_instance_valid(existing) and existing.has_method("register_site"): return existing
	var registry: Node = C4Registry.new()
	registry.name = "CityTownC4SiteRegistry"
	world.add_child(registry)
	if not registry.call("configure", world):
		registry.queue_free()
		return null
	return registry

func _start_probe(world: Node3D) -> void:
	if is_instance_valid(_probe): return
	var probe: Node = C4Probe.new()
	probe.name = "CityTownC4Probe"
	world.add_child(probe)
	if not probe.call("attach", world, _site(), self):
		probe.queue_free()
		return
	_probe = probe

func _native_blast(event: Dictionary) -> Dictionary:
	if _disposed or not _bound or status != "ready" or not site_current(): return {"ok":false,"reason":"retired_site"}
	if event.is_empty() or event.get("source_id") != source_id: return {"ok":false,"reason":"source_not_admitted"}
	var site: Node3D = _site()
	var collider: Variant = event.get("collider")
	var glazing: Variant = site.get("_glazing")
	var owned_pane: bool = is_instance_valid(glazing) and glazing.owns_collider(collider)
	if not is_instance_valid(collider) or (not site.owns_collider(collider) and not owned_pane): return {"ok":false,"reason":"foreign_native_collision"}
	var result: Dictionary = site.apply_explosion(event)
	_record("blast", str(event.get("event_id", "")), result)
	return result

func _native_glass(event: Dictionary) -> Dictionary:
	if _disposed or not _bound or status != "ready" or not site_current(): return {"ok":false,"reason":"retired_glazing"}
	var site: Node3D = _site()
	var glazing: Variant = site.get("_glazing")
	if not is_instance_valid(glazing): return {"ok":false,"reason":"retired_glazing"}
	var result: Dictionary = glazing.apply_bullet(event)
	_record("glass_bullet", str(event.get("event_id", "")), result)
	return result

func _native_glass_blast(event: Dictionary) -> Dictionary:
	if _disposed or not _bound or status != "ready" or not site_current(): return {"ok":false,"reason":"retired_glazing"}
	var site: Node3D = _site()
	var glazing: Variant = site.get("_glazing")
	if not is_instance_valid(glazing): return {"ok":false,"reason":"retired_glazing"}
	var result: Dictionary = glazing.apply_blast(event)
	_record("glass_blast", str(event.get("event_id", "")), result)
	return result

func _record(kind: String, event_id: String, result: Dictionary) -> void:
	_events.append({"kind":kind,"event_id":event_id,"result":result.duplicate(true)})
	if _events.size() > MAX_EVENTS: _events.pop_front()

func _fail(reason: String) -> void:
	status = "failed"
	report.status = status
	report.reason = reason
	set_physics_process(false)
	print("CITY_TOWN_DAMAGE_OWNER ", source_id, " ", JSON.stringify({"ok":false,"status":status,"reason":reason,"source_id":source_id,"profile_id":profile_id,"frames":_frames}))

func snapshot() -> Dictionary:
	var site: Node3D = _site()
	var registry: Node = _registry_ref.get_ref() if _registry_ref != null else null
	return {"owner":status,"bound":_bound,"source_id":source_id,"profile_id":profile_id,"frames":_frames,"events":_events.duplicate(true),"site_current":site_current(),
		"site":site.get_stats() if is_instance_valid(site) and site.has_method("get_stats") else {},
		"damage":_damage.snapshot() if _damage != null and not _disposed else {},
		"c4":registry.snapshot() if is_instance_valid(registry) and registry.has_method("snapshot") else {}}

func dispose() -> void:
	if _disposed: return
	_disposed = true
	set_physics_process(false)
	_bound = false
	if _damage != null: _damage.dispose(); _damage = null
	var registry: Node = _registry_ref.get_ref() if _registry_ref != null else null
	if is_instance_valid(registry): registry.queue_free()
	_registry_ref = null
	if is_instance_valid(_probe): _probe.queue_free()
	_probe = null
	_site_ref = null
	_world = null
	status = "disposed"
	if is_inside_tree(): queue_free()

func _exit_tree() -> void:
	if not _disposed:
		set_physics_process(false)
		if _damage != null: _damage.dispose(); _damage = null
		_bound = false
