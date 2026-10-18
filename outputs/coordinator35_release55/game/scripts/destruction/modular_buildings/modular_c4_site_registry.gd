extends Node
## DSH_CITYTOWN (flag --city-town-damage=1): world-level C4 target registry for the
## ported modular destructible sites (restaurant / hospital / small bank).
##
## WHY THIS NODE EXISTS
## The C4 charge owner `scripts/destruction/palazzo/c4_building_blast.gd` receives its
## target list through exactly ONE Callable, installed by `scripts/main.gd`:
##
##   main.gd:322   if blast.configure(self,Callable(self,"_c4_sites")):
##   main.gd:599   func _c4_sites() -> Array: ... return [preview_palazzo.site]
##   c4_building_blast.gd:41   for site: Node3D in _sites.call():
##
## main.gd is owned by another workstream in this session and is deliberately NOT
## touched. Therefore this node RE-BINDS that one Callable to a superset: the
## original provider's rows (Palazzo) plus every registered, ready modular site.
## It never removes a target, never changes the blast's apply logic, never
## fabricates a receipt and never consumes a charge.
##
## The site contract required by the blast (c4_building_blast.gd:42-44,74-78,81-112)
## is already satisfied by `modular_site.gd` through the accepted Palazzo chain:
## site_ready, rebuilding, rebuild_generation, global_transform, pieces,
## owns_collider(), _release(), _mark_structure_dirty(), optional _glazing.
##
## Default (no --city-town-damage=1): this node is never created and the blast keeps
## the provider main.gd installed - byte-for-byte current behaviour.

const NODE_NAME := "CityTownC4SiteRegistry"
const MAX_INSTALL_ATTEMPTS := 3600 # ~60 s at 60 Hz; honest bounded late binding.

var _world: WeakRef
var _sites: Dictionary = {} # site instance id -> WeakRef(site)
var _original: Callable = Callable()
var _installed := false
var _install_attempts := 0
var _registered_total := 0
var _rejected := 0

func configure(world: Node) -> bool:
	if _world != null or not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion(): return false
	_world = weakref(world)
	set_physics_process(true)
	return true

## Idempotent: the same live site instance is never registered twice.
func register_site(site: Node3D) -> Dictionary:
	if _world == null or not is_instance_valid(site) or not site.is_inside_tree(): _rejected += 1; return {"ok":false,"reason":"site_not_live"}
	if not site.has_method("owns_collider") or not site.has_method("_release"): _rejected += 1; return {"ok":false,"reason":"site_contract"}
	if not site.get("site_ready") is bool or not site.get("rebuild_generation") is int or not site.get("pieces") is Array: _rejected += 1; return {"ok":false,"reason":"site_damage_fields"}
	var id: int = site.get_instance_id()
	if _sites.has(id):
		var previous: Variant = _sites[id].get_ref()
		if previous == site: return {"ok":true,"already":true,"site_id":id}
	_sites[id] = weakref(site)
	_registered_total += 1
	return {"ok":true,"already":false,"site_id":id,"source_id":str(site.get("source_id"))}

## C4 blast provider. Same shape as main.gd::_c4_sites (Array of live sites).
func targets() -> Array:
	var out: Array = []
	if _original.is_valid():
		var listed: Variant = _original.call()
		if listed is Array:
			for row: Variant in listed:
				if not out.has(row): out.append(row)
	for key: int in _sites.keys():
		var site: Variant = _sites[key].get_ref()
		if not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion(): continue
		if site.get("site_ready") != true or site.get("rebuilding") == true: continue
		if out.has(site): continue
		out.append(site)
	return out

func _physics_process(_delta: float) -> void:
	if _installed: set_physics_process(false); return
	_install_attempts += 1
	var world: Node = _world.get_ref() if _world != null else null
	if not is_instance_valid(world) or not world.is_inside_tree():
		if _install_attempts >= MAX_INSTALL_ATTEMPTS: set_physics_process(false)
		return
	var blast: Variant = world.get("preview_c4_blast")
	if not is_instance_valid(blast) or not blast.has_method("detonate"):
		if _install_attempts >= MAX_INSTALL_ATTEMPTS:
			set_physics_process(false)
			print("CITY_TOWN_C4_TARGET ", JSON.stringify({"ok":false,"reason":"blast_owner_not_created","attempts":_install_attempts,"registered":_sites.size(),"flag":"--city-town-damage=1"}))
		return
	var current: Variant = blast.get("_sites")
	if not current is Callable or not current.is_valid():
		set_physics_process(false)
		print("CITY_TOWN_C4_TARGET ", JSON.stringify({"ok":false,"reason":"target_provider_missing","registered":_sites.size()}))
		return
	# Keep the exact Callable main.gd installed; only widen its result set.
	_original = current
	blast.set("_sites", Callable(self, "targets"))
	_installed = true
	set_physics_process(false)
	print("CITY_TOWN_C4_TARGET ", JSON.stringify(snapshot()))

func snapshot() -> Dictionary:
	var live: Array = []
	for key: int in _sites.keys():
		var site: Variant = _sites[key].get_ref()
		if not is_instance_valid(site): continue
		live.append({"source_id":str(site.get("source_id")),"site_id":key,"site_ready":bool(site.get("site_ready")),"generation":int(site.get("rebuild_generation")),"owned_parts":(site.get("pieces") as Array).size(),"glazing":is_instance_valid(site.get("_glazing"))})
	return {"ok":_installed,"status":"c4_target_registered" if _installed else "c4_target_pending","registry":NODE_NAME,"provider_replaced":_installed,"original_provider_kept":_installed,"install_attempts":_install_attempts,"registered":_sites.size(),"registered_total":_registered_total,"rejected":_rejected,"sites":live,"flag":"--city-town-damage=1"}

func dispose() -> void:
	if _world != null:
		var world: Node = _world.get_ref()
		# Give the provider back to its original owner before this node dies.
		if _installed and is_instance_valid(world):
			var blast: Variant = world.get("preview_c4_blast")
			if is_instance_valid(blast) and blast.get("_sites") is Callable and (blast.get("_sites") as Callable) == Callable(self, "targets"):
				blast.set("_sites", _original)
	_installed = false
	_sites.clear()
	_world = null
	set_physics_process(false)
	if is_inside_tree(): queue_free()

func _exit_tree() -> void:
	set_physics_process(false)
