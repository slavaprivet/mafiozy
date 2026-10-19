extends "res://test_unified_registry.gd"
const TransportFactory = preload("res://transport_decor_factory.gd")
const TransportRegistry = preload("res://transport_registry.gd")
func transport_registry_class() -> Script: return TransportRegistry
func baseline_count() -> int: return 9901
func clone_count() -> int: return 3
func extra_owners(world: Node3D) -> Array:
	var transport := TransportFactory.new()
	var admitted: Dictionary = transport.configure("res://transport_source", "69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b")
	check(admitted.ok, "original transport source admission")
	if not admitted.ok: return []
	var parking: Dictionary = transport.build_parking()
	check(parking.ok, "233 original parking visual IDs")
	if not parking.ok: return []
	world.add_child(parking.root)
	var registry: RefCounted = transport_registry_class().new()
	check(registry.configure(transport, owner).ok, "all265 transport records, rail32 intentionally HOLD")
	return [{"owner_id": "transport", "registry": registry, "factory": transport}]
func extra_templates(session: Dictionary) -> Array:
	for id: String in session.composite.ids():
		if id.begins_with("parking-bays:"):
			check(session.composite.is_editable(id), "actual parking template admitted")
			return [id]
	check(false, "parking template missing")
	return []
func dispose_extras(session: Dictionary) -> void:
	for entry: Dictionary in session.owners:
		if entry.owner_id == "transport":
			entry.registry.dispose()
			entry.factory.dispose()
