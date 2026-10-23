extends SceneTree

const Store = preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
const Evidence = preload("res://scripts/transport/transport_cargo_evidence.gd")
const Compartments = preload("res://scripts/vehicle_visual/vehicle_compartments.gd")
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const Inventory = preload("res://scripts/weapons/weapon_inventory.gd")
var checks := 0
var failures: Array[String] = []
var scene: Node

class VisualFixture extends RefCounted:
	var root: Node3D
	var profile_id := "compact_sedan"
	var entry: Dictionary
	var nodes: Dictionary

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func vehicle(id: String, generation: int) -> Node3D:
	var node := Node3D.new(); node.set_meta("vehicle_id", id); node.set_meta("life_generation", generation); scene.add_child(node); return node

func fire_state(id: String) -> Dictionary:
	return {"weaponId": id, "magazine": mini(17, int(Fire.profile(id).magazineSize)), "reserveAmmo": 61, "cooldown": .2, "reloadRemaining": .4, "recoil": .1, "sequence": 9, "triggerHeld": true, "sprayHeat": .3, "nested": {"source": "root", "rows": [1, 2.5, false]}}

func weapon(uid: String, id: String = "ak74") -> Dictionary:
	return {"uid": uid, "weaponId": id, "fireState": fire_state(id)}

func test_fired_inventory_to_store(store: RefCounted) -> void:
	for id_value in Fire.ids():
		var id := String(id_value)
		var inventory := Inventory.new()
		check(inventory.configure(Fire.new(), {"ownedIds": [id]}).ok and inventory.equip(id).ok, "actual %s inventory equips" % id)
		var initial: Dictionary = inventory.get_fire_state(id)
		var fired: Dictionary = Fire.step(initial, {"triggerPressed": true}, .016)
		check(not fired.has("error") and fired.shots.size() == 1 and typeof(fired.state.sequence) == TYPE_FLOAT, "actual %s source fire yields whole-float sequence" % id)
		check(inventory.update_fire_state(fired.state).ok, "actual %s fired state passes inventory" % id)
		var export: Dictionary = inventory.begin_cargo_export()
		check(export.ok, "actual %s inventory reserves fired item" % id)
		var staged: Dictionary = store.prepare_store(export.item, 1, model_box(), 1, 7, 1)
		check(staged.ok and staged.entry.item.fireState.sequence == fired.state.sequence and typeof(staged.entry.item.fireState.sequence) == TYPE_FLOAT, "actual %s fired item and exact sequence pass cargo store" % id)
		if staged.ok: check(store.cancel(staged.token).ok, "actual %s staged cargo cancels" % id)
		check(inventory.cancel_cargo_transfer(export.token).ok, "actual %s export reservation cancels" % id)
		var reloaded: Dictionary = Fire.step(fired.state, {"reload": true}, 5.0)
		check(not reloaded.has("error") and reloaded.reloadFinished and typeof(reloaded.state.magazine) == TYPE_FLOAT and typeof(reloaded.state.reserveAmmo) == TYPE_FLOAT, "actual %s source reload yields whole-float ammo" % id)
		# Root owns the source-port reload cooldown: its early return can leave a
		# negative cooldown, independently rejected by Inventory. Isolate the
		# Store's integer-like ammo seam with only that unrelated field clamped.
		var reloaded_state: Dictionary = reloaded.state.duplicate(true)
		reloaded_state.cooldown = maxf(0.0, float(reloaded_state.cooldown))
		check(inventory.update_fire_state(reloaded_state).ok, "actual %s reloaded whole-float ammo passes inventory after cooldown seam" % id)
		export = inventory.begin_cargo_export()
		check(export.ok, "actual %s inventory reserves reloaded item" % id)
		staged = store.prepare_store(export.item, 1, model_box(), 1, 7, 1)
		check(staged.ok and staged.entry.item.fireState.magazine == reloaded_state.magazine and staged.entry.item.fireState.reserveAmmo == reloaded_state.reserveAmmo, "actual %s reloaded ammo passes cargo store" % id)
		if staged.ok: check(store.cancel(staged.token).ok, "actual %s reloaded cargo cancels" % id)
		check(inventory.cancel_cargo_transfer(export.token).ok, "actual %s reloaded export cancels" % id)
		var max_magazine := int(Fire.profile(id).magazineSize)
		var boundary := weapon("boundary-%s" % id, id)
		boundary.fireState.magazine = float(max_magazine)
		boundary.fireState.reserveAmmo = 9999.0
		boundary.fireState.sequence = 9007199254740991.0
		staged = store.prepare_store(boundary, 1, model_box(), 1, 7, 1)
		check(staged.ok, "actual %s source upper integer bounds accepted as floats" % id)
		if staged.ok: store.cancel(staged.token)
		boundary.fireState.magazine = float(max_magazine + 1)
		check(store.prepare_store(boundary, 1, model_box(), 1, 7, 1).error == "FIRE_STATE", "actual %s magazine above source profile rejected" % id)
		boundary.fireState.magazine = 0.0; boundary.fireState.reserveAmmo = 10000.0
		check(store.prepare_store(boundary, 1, model_box(), 1, 7, 1).error == "FIRE_STATE", "actual %s reserve above source limit rejected" % id)
		boundary.fireState.reserveAmmo = 0.0; boundary.fireState.sequence = 9007199254740992.0
		check(store.prepare_store(boundary, 1, model_box(), 1, 7, 1).error == "FIRE_STATE", "actual %s unsafe sequence rejected" % id)
	for invalid in [NAN, INF, -INF, .5, -1.0, "1", true, null]:
		var bad := weapon("bad-numeric")
		for key in ["magazine", "reserveAmmo", "sequence"]:
			bad.fireState[key] = invalid
			check(store.prepare_store(bad, 1, model_box(), 1, 7, 1).error == "FIRE_STATE", "%s %s rejects invalid whole-number state" % [key, str(invalid)])
			bad.fireState[key] = fire_state("ak74")[key]

func model_box() -> AABB:
	return AABB(Vector3(-.15, -.05, -.15), Vector3(.3, .2, .3))

func actual_weapon_box(size: Vector3) -> AABB:
	return AABB(size * -.5, size)

func separated_by_at_least(left: AABB, right: AABB, gap: float) -> bool:
	return right.position.x - left.end.x >= gap or left.position.x - right.end.x >= gap or right.position.y - left.end.y >= gap or left.position.y - right.end.y >= gap or right.position.z - left.end.z >= gap or left.position.z - right.end.z >= gap

func mesh_with_bounds(minimum: Vector3, maximum: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array([minimum, Vector3(maximum.x,minimum.y,minimum.z), Vector3(minimum.x,maximum.y,minimum.z), maximum, Vector3(minimum.x,maximum.y,maximum.z), Vector3(maximum.x,minimum.y,maximum.z)])
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh

func access_fixture(vehicle_root: Node3D) -> Dictionary:
	var file := FileAccess.open("res://assets/vehicle_visual/compartments.json", FileAccess.READ); var doc: Dictionary = JSON.parse_string(file.get_as_text()); var spec: Dictionary = doc.profiles.compact_sedan
	var lo := Vector3(float(spec.cargo_bounds.min[0]),float(spec.cargo_bounds.min[1]),float(spec.cargo_bounds.min[2])); var hi := Vector3(float(spec.cargo_bounds.max[0]),float(spec.cargo_bounds.max[1]),float(spec.cargo_bounds.max[2]))
	var native_lo := Vector3(-hi.x,lo.y,-hi.z); var native_hi := Vector3(-lo.x,hi.y,-lo.z)
	var visual_root := Node3D.new(); vehicle_root.add_child(visual_root)
	var nodes: Dictionary = {}; var controls: Dictionary = {}
	for kind in ["hood","trunk"]:
		var panel: Dictionary = spec.panels[kind]
		var hinge := Node3D.new(); visual_root.add_child(hinge); nodes[panel.hinge]=hinge; controls[kind]=panel.hinge
		var lid: Node3D
		if kind == "trunk":
			var mesh_lid := MeshInstance3D.new(); mesh_lid.mesh = mesh_with_bounds(Vector3(native_lo.x,native_hi.y+.05,native_lo.z-.25),Vector3(native_hi.x,native_hi.y+.15,native_lo.z-.05)); lid=mesh_lid
		else: lid=Node3D.new()
		hinge.add_child(lid); nodes[panel.lid]=lid
		for support_value in panel.supports:
			var support: Dictionary = support_value
			var parent: Node3D = nodes.get(support.parent_key)
			if parent == null: parent=Node3D.new(); visual_root.add_child(parent); nodes[support.parent_key]=parent
			var support_node: Node3D = nodes.get(support.key)
			if support_node == null: support_node=Node3D.new(); parent.add_child(support_node); nodes[support.key]=support_node
		for key_value in panel.engine_nodes:
			var key := String(key_value)
			if not nodes.has(key):
				var engine:=Node3D.new(); visual_root.add_child(engine); nodes[key]=engine
	var floor := MeshInstance3D.new(); floor.set_meta("source_name","Trunk_cargo_floor"); floor.mesh = mesh_with_bounds(Vector3(native_lo.x,native_lo.y-.03,native_lo.z),Vector3(native_hi.x,native_lo.y,native_hi.z)); visual_root.add_child(floor)
	nodes["fixture-floor"]=floor
	var visual := VisualFixture.new(); visual.root=visual_root; visual.entry={"sha256":spec.visual_sha256,"controls":controls}; visual.nodes=nodes
	var compartments := Compartments.new(); var compartment_receipt: Dictionary = compartments.configure(visual); check(compartment_receipt.ok,"actual VehicleCompartments configures")
	compartments.set_open("trunk",true)
	for step in range(20): compartments.step(.1)
	var provider := Evidence.new(); var receipt := provider.configure(visual,compartments); check(receipt.ok,"actual CargoEvidence configures against exact same compartments instance")
	return {"provider":provider,"compartments":compartments,"visual_root":visual_root}

func run() -> void:
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/vehicle_trunk.mjs") == Store.SOURCE_TRUNK_SHA256, "source trunk SHA pinned")
	check(FileAccess.get_sha256("res://../../assets/maps/city_rebuild_v1/weapon_inventory.mjs") == Store.SOURCE_WEAPON_INVENTORY_SHA256, "source weapon inventory SHA pinned")
	check(FileAccess.get_sha256("res://scripts/transport/transport_cargo_admission.gd") == Store.CARGO_ADMISSION_SHA256, "cargo admission SHA pinned")
	check(FileAccess.get_sha256("res://scripts/transport/transport_cargo_evidence.gd") == Store.CARGO_EVIDENCE_SHA256, "cargo evidence SHA pinned")
	scene = Node.new(); root.add_child(scene)
	var root_vehicle := vehicle("vehicle:test:1", 7); var store := Store.new(); var access := access_fixture(root_vehicle)
	var wrong_vehicle:=vehicle("vehicle:wrong",7); var wrong_store:=Store.new()
	check(not wrong_store.configure(wrong_vehicle,"vehicle:wrong",7,access.provider,access.compartments).ok,"cargo evidence from another vehicle root rejects")
	var configured := store.configure(root_vehicle, "vehicle:test:1", 7, access.provider, access.compartments)
	check(configured.ok and configured.capacity_units == 100 and configured.revision == 1, "store binds actual vehicle lifetime with capacity100")
	test_fired_inventory_to_store(store)
	var noncanonical_ak := store.prepare_store(weapon("ak-no-store-hardcode"), 14, model_box(), 1, 7, 1)
	check(noncanonical_ak.ok, "store accepts positive AK units and leaves exact model-volume cost to trusted Root catalog")
	check(store.cancel(noncanonical_ak.token).ok and not store.prepare_store(weapon("zero-units"), 0, model_box(), 1, 7, 1).ok, "positive capacity units remain mandatory without per-weapon hardcoding")
	access.compartments.set_open("trunk",false); access.compartments.step(.05); access.compartments.set_open("trunk",true)
	check(not store.prepare_store(weapon("not-raised"), 15, model_box(), 1, 7, 1).ok, "target open still rejects below physical opening threshold")
	for step in range(20): access.compartments.step(.1)
	access.compartments.set_open("trunk",false); check(not store.prepare_store(weapon("closing"), 15, model_box(), 2, 7, 1).ok, "closing target rejects even while lid amount remains fully open"); access.compartments.set_open("trunk",true)
	var prepared := store.prepare_store(weapon("ak-one"), 15, model_box(), 10, 7, 1)
	check(prepared.ok and prepared.entry.item.uid == "ak-one" and prepared.entry.item.itemUID == "ak-one", "canonical uid and itemUID alias remain stable")
	check((prepared.entry.item_bounds_local_m as AABB).size == model_box().size, "slot uses exact model AABB size")
	var public_entry: Dictionary = prepared.entry; public_entry.item.fireState.magazine = 0
	check(store.snapshot(7).items.is_empty(), "prepare does not transfer cargo ownership")
	check(not store.prepare_store(weapon("other-pending", "tt_pistol"), 5, model_box(), 10, 7, 1).ok, "one pending transfer blocks another")
	var prepared_validation := store.validate_pending(prepared.token,"store",7,1,10); check(prepared_validation.ok,"pending validation resamples exact open evidence")
	check(not store.commit_store(prepared.token, prepared_validation.validation, 7, 1, 11).ok, "evidence revision mismatch cannot commit")
	var committed := store.commit_store(prepared.token, prepared_validation.validation, 7, 1, 10)
	check(committed.ok and committed.used_units == 15 and committed.entry.item.fireState.magazine == 17, "commit preserves private full fireState after returned mutation")
	check(not store.commit_store(prepared.token, prepared_validation.validation, 7, 1, 10).ok, "used token cannot commit twice")
	var closes_between := store.prepare_store(weapon("close-between","tt_pistol"), 3, model_box(), 10, 7, 2); access.compartments.set_open("trunk",false)
	check(closes_between.ok and not store.validate_pending(closes_between.token,"store",7,2,10).ok, "target closing after prepare invalidates evidence before sealed commit")
	check(store.cancel(closes_between.token).ok, "host cancels cargo reservation after callback invalidation"); access.compartments.set_open("trunk",true)
	check(not store.prepare_store(weapon("ak-one"), 15, model_box(), 11, 7, 2).ok, "same uid cannot be stored twice")
	var pistol := store.prepare_store(weapon("pistol-one", "tt_pistol"), 7, model_box(), 11, 7, 2)
	check(pistol.ok, "all weapon types accept explicit validated units")
	var pistol_entry: Dictionary = pistol.entry
	check(not (pistol_entry.item_bounds_local_m as AABB).intersects(committed.entry.item_bounds_local_m), "deterministic slots do not overlap")
	check(store.cancel(pistol.token).ok and store.snapshot(7).used_units == 15, "cancel retains cargo revision and ownership")
	check(not store.commit_store(pistol.token, null, 7, 2, 11).ok, "cancelled token stays stale")
	var p2 := store.prepare_store(weapon("pistol-one", "tt_pistol"), 7, model_box(), 12, 7, 2)
	var p2_validation:=store.validate_pending(p2.token,"store",7,2,12)
	check(store.commit_store(p2.token, p2_validation.validation, 7, 2, 12).ok and store.snapshot(7).used_units == 22, "second physical slot commits atomically")
	var take := store.prepare_take("ak-one", 13, 7, 3)
	check(take.ok and take.entry.item.fireState.nested.rows[1] == 2.5, "take stages lossless fireState without removing cargo")
	take.entry.item.fireState.nested.rows[1] = 99
	check(store.snapshot(7).items.size() == 2, "mutating take receipt cannot mutate storage")
	var take_validation:=store.validate_pending(take.token,"take",7,3,13); var taken := store.commit_take(take.token, take_validation.validation, 7, 3, 13)
	check(taken.ok and taken.entry.item.uid == "ak-one" and taken.entry.item.fireState.nested.rows[1] == 2.5 and store.snapshot(7).used_units == 7, "take commits exact stable item only after host import seam")
	var drop_two:=store.prepare_store(weapon("shotgun-drop","shotgun"),10,model_box(),14,7,4); var drop_two_validation:=store.validate_pending(drop_two.token,"store",7,4,14)
	check(drop_two.ok and drop_two_validation.ok and store.commit_store(drop_two.token,drop_two_validation.validation,7,4,14).ok,"second destruction item reserves a distinct physical slot")
	var bad_plain := weapon("bad-plain", "sniper"); bad_plain.fireState.extra = NAN
	check(not store.prepare_store(bad_plain, 12, model_box(), 15, 7, 5).ok, "nonfinite nested fireState rejects")
	var resource_plain := weapon("bad-resource", "sniper"); resource_plain.fireState.extra = Resource.new()
	check(not store.prepare_store(resource_plain, 12, model_box(), 15, 7, 5).ok, "Resource in fireState rejects")
	var cyclic: Dictionary = fire_state("sniper"); cyclic.self = cyclic
	check(not store.prepare_store({"uid":"bad-cycle","weaponId":"sniper","fireState":cyclic}, 12, model_box(), 15, 7, 5).ok, "cyclic fireState rejects")
	var too_big := AABB(Vector3.ZERO, Vector3(5, 5, 5))
	check(not store.prepare_store(weapon("too-big", "sniper"), 12, too_big, 15, 7, 5).ok, "capacity units cannot bypass physical cargo bounds")
	var pack_root:=vehicle("vehicle:actual-pack",1); var pack_store:=Store.new(); var pack_access:=access_fixture(pack_root); pack_store.configure(pack_root,"vehicle:actual-pack",1,pack_access.provider,pack_access.compartments)
	var actual_ak:=pack_store.prepare_store(weapon("actual-ak"),15,actual_weapon_box(Vector3(.069362,.194555,.314078)),1,1,1); var actual_ak_validation:=pack_store.validate_pending(actual_ak.get("token"),"store",1,1,1); var actual_ak_commit:=pack_store.commit_store(actual_ak.get("token"),actual_ak_validation.get("validation"),1,1,1)
	var actual_pistol:=pack_store.prepare_store(weapon("actual-pistol","tt_pistol"),5,actual_weapon_box(Vector3(.054862,.138537,.150304)),2,1,2)
	check(actual_ak.ok and actual_ak_validation.ok and actual_ak_commit.ok and actual_pistol.ok,"actual scaled AK then pistol both obtain physical compact-sedan slots")
	if actual_pistol.ok:
		check(separated_by_at_least(actual_ak_commit.entry.item_bounds_local_m,actual_pistol.entry.item_bounds_local_m,Store.GAP_M),"actual AK/pistol slots retain at least5mm float32 separation")
		pack_store.cancel(actual_pistol.token)
	root_vehicle.set_meta("transport_destroying",true)
	check(not store.prepare_take("pistol-one",15,7,5).ok,"destroying vehicle rejects interactive take before destruction reservation")
	var destroy_stage := store.prepare_destroy("blast:event:1", 7, 5)
	check(destroy_stage.ok and destroy_stage.items.size() == 2 and store.snapshot(7).items.size() == 2, "destroy prepare retains cargo until ground batch reservation")
	check(not (destroy_stage.items[0].item_bounds_local_m as AABB).intersects(destroy_stage.items[1].item_bounds_local_m), "ground import receives per-item nonoverlapping physical slots")
	check(store.prepare_destroy("blast:event:1", 7, 5).duplicate, "same pending destruction event is idempotent")
	check(not store.prepare_take("pistol-one", 15, 7, 5).ok, "pending destruction freezes store and take")
	destroy_stage.items[0].item.fireState.magazine = 0
	check(store.cancel(destroy_stage.token).ok and store.snapshot(7).items[0].item.fireState.magazine == 12, "cancelled destruction retains private cargo exactly")
	var destroy_retry := store.prepare_destroy("blast:event:1", 7, 5); var destroy_validation:=store.validate_pending(destroy_retry.token,"destroy",7,5,-1)
	check(store.prepare_destroy("blast:event:1",7,5).duplicate and not store.commit_destroy(destroy_retry.token,destroy_validation.validation,7,5).ok,"duplicate pending destroy invalidates any prior validation seal")
	destroy_validation=store.validate_pending(destroy_retry.token,"destroy",7,5,-1)
	var destroyed := store.commit_destroy(destroy_retry.token, destroy_validation.validation, 7, 5)
	check(destroyed.ok and destroyed.receipt.items.size() == 2 and destroyed.receipt.items[0].item.fireState.magazine == 12, "destroy commit emits exact physical drop payload once")
	destroyed.receipt.items.clear()
	access.visual_root.free()
	var replay_prepare := store.prepare_destroy("blast:event:1", 7, 6)
	check(replay_prepare.ok and replay_prepare.duplicate and replay_prepare.committed and replay_prepare.receipt.items.size() == 2, "committed destruction replays after explosion frees visual without creating new drops")
	var duplicate_destroy := store.destroy_once("blast:event:1", 7)
	check(duplicate_destroy.ok and duplicate_destroy.duplicate and duplicate_destroy.receipt.items.size() == 2, "committed destruction receipt is defensive and retry-idempotent")
	check(not store.destroy_once("blast:event:2", 7).ok and store.snapshot(7).destroyed, "different destruction event cannot duplicate drops")
	root_vehicle.set_meta("life_generation",8); check(not store.prepare_destroy("blast:event:1",7,6).ok,"committed duplicate destruction rejects stale actual incarnation before receipt replay"); root_vehicle.set_meta("life_generation",7)
	var corpse_root := vehicle("vehicle:corpse", 2); var corpse_store := Store.new(); var corpse_access:=access_fixture(corpse_root); corpse_store.configure(corpse_root, "vehicle:corpse", 2, corpse_access.provider, corpse_access.compartments)
	var corpse := {"uid":"corpse-1","kind":"corpse"}
	check(not corpse_store.prepare_store(corpse, 99, model_box(), 1, 2, 1).ok, "future corpse requires exactly100 units")
	var corpse_stage := corpse_store.prepare_store(corpse, 100, model_box(), 1, 2, 1)
	var corpse_validation:=corpse_store.validate_pending(corpse_stage.token,"store",2,1,1)
	check(corpse_stage.ok and corpse_store.commit_store(corpse_stage.token,corpse_validation.validation,2,1,1).ok, "future corpse policy allows one exclusive full-capacity record")
	check(not corpse_store.prepare_store(weapon("after-corpse"), 15, model_box(), 2, 2, 2).ok, "corpse excludes every other item")
	var stale_root := vehicle("vehicle:stale", 4); var stale_store := Store.new(); var stale_access:=access_fixture(stale_root); stale_store.configure(stale_root, "vehicle:stale", 4, stale_access.provider, stale_access.compartments)
	var stale := stale_store.prepare_store(weapon("stale-ak"), 15, model_box(), 1, 4, 1); stale_root.set_meta("life_generation", 5)
	check(not stale_store.validate_pending(stale.token,"store",4,1,1).ok and not stale_store.snapshot(4).ok, "preflight callback reincarnation rejects old token and snapshot")
	var reparent_root:=vehicle("vehicle:reparent",3); var reparent_store:=Store.new(); var reparent_access:=access_fixture(reparent_root); reparent_store.configure(reparent_root,"vehicle:reparent",3,reparent_access.provider,reparent_access.compartments)
	var reparent_stage:=reparent_store.prepare_store(weapon("reparent-ak"),15,model_box(),1,3,1); var reparent_seal:=reparent_store.validate_pending(reparent_stage.token,"store",3,1,1); reparent_access.visual_root.reparent(wrong_vehicle)
	check(reparent_seal.ok and not reparent_store.validate_pending(reparent_stage.token,"store",3,1,1).ok and not reparent_store.commit_store(reparent_stage.token,reparent_seal.validation,3,1,1).ok and not reparent_store.snapshot(3).ok,"failed revalidation after visual reparent revokes old seal and rejects commit")
	# Bounded transaction cost with actual admission and slot calculation.
	var cost_root := vehicle("vehicle:cost", 1); var cost_store := Store.new(); var cost_access:=access_fixture(cost_root); cost_store.configure(cost_root, "vehicle:cost", 1, cost_access.provider, cost_access.compartments)
	var samples := PackedFloat64Array()
	for block in range(20):
		var started := Time.get_ticks_usec()
		for iteration in range(500):
			var candidate := weapon("cost-%s-%s" % [block, iteration], "tt_pistol")
			var stage := cost_store.prepare_store(candidate, 1, model_box(), block + 1, 1, 1)
			if stage.ok: cost_store.cancel(stage.token)
		samples.append(float(Time.get_ticks_usec() - started) / 500.0)
	samples.sort()
	var pop_root:=vehicle("vehicle:populated",1); var pop_store:=Store.new(); var pop_access:=access_fixture(pop_root); pop_store.configure(pop_root,"vehicle:populated",1,pop_access.provider,pop_access.compartments)
	var tiny_box:=AABB(Vector3(-.015,-.015,-.015),Vector3(.03,.03,.03)); var populated_us:=PackedFloat64Array()
	for index in range(100):
		var started:=Time.get_ticks_usec(); var stage:=pop_store.prepare_store(weapon("pop-%03d"%index,"tt_pistol"),1,tiny_box,index+1,1,index+1)
		var validation:=pop_store.validate_pending(stage.get("token"),"store",1,index+1,index+1)
		var committed_pop:=pop_store.commit_store(stage.get("token"),validation.get("validation"),1,index+1,index+1)
		populated_us.append(float(Time.get_ticks_usec()-started)); check(stage.ok and validation.ok and committed_pop.ok,"populated capacity transaction %s commits"%index)
	var populated_snapshot:=pop_store.snapshot(1); check(populated_snapshot.items.size()==100 and populated_snapshot.used_units==100,"capacity100 has100 distinct physical slots")
	var summary_started:=Time.get_ticks_usec(); var populated_summary:=pop_store.summary(1); var summary_us:=Time.get_ticks_usec()-summary_started
	check(populated_summary.ok and populated_summary.count==100 and populated_summary.used_units==100 and not populated_summary.pending and not populated_summary.destroyed,"cheap summary exposes only bounded HUD scalars")
	check(not populated_summary.has("items"),"HUD summary does not deep-copy item or fireState payloads")
	for left in range(populated_snapshot.items.size()):
		for right in range(left+1,populated_snapshot.items.size()): check(not (populated_snapshot.items[left].item_bounds_local_m as AABB).intersects(populated_snapshot.items[right].item_bounds_local_m),"populated slots %s/%s do not overlap"%[left,right])
	populated_us.sort(); var destroy_started:=Time.get_ticks_usec(); var pop_destroy:=pop_store.prepare_destroy("blast:populated",1,101); var pop_destroy_prepare_us:=Time.get_ticks_usec()-destroy_started
	destroy_started=Time.get_ticks_usec(); var pop_destroy_validation:=pop_store.validate_pending(pop_destroy.token,"destroy",1,101,-1); var pop_destroy_validate_us:=Time.get_ticks_usec()-destroy_started
	destroy_started=Time.get_ticks_usec(); var pop_destroyed:=pop_store.commit_destroy(pop_destroy.token,pop_destroy_validation.validation,1,101); var pop_destroy_commit_us:=Time.get_ticks_usec()-destroy_started
	check(pop_destroyed.ok and pop_destroyed.receipt.items.size()==100,"populated destruction emits all100 stable items exactly once")
	var cost := {"empty_prepare_cancel_cycles":10000,"empty_block_mean_us_p50":(samples[9]+samples[10])*.5,"empty_block_mean_us_p95":samples[18],"populated_transaction_us_p50":(populated_us[49]+populated_us[50])*.5,"populated_transaction_us_p95":populated_us[94],"populated_transaction_us_max":populated_us[99],"summary_100_items_us":summary_us,"snapshot_var_to_bytes":var_to_bytes(populated_snapshot).size(),"destroy_prepare_us":pop_destroy_prepare_us,"destroy_validate_us":pop_destroy_validate_us,"destroy_commit_us":pop_destroy_commit_us}
	check(samples[18] < 500.0, "prepare plus cancel stays bounded below500us p95 block mean")
	scene.queue_free(); await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"cost":cost,"scope":"isolated physical trunk cargo ownership; no Root inventory/input/model/corpse movement"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
