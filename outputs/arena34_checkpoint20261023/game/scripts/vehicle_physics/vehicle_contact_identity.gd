extends RefCounted
## Cold identity adapter. Never promotes engine IDs or node names to wire IDs.
static func describe(collider: Object) -> Dictionary:
	if not is_instance_valid(collider):
		return {"valid":false, "reason":"missing_collider"}
	var runtime_id := collider.get_instance_id()
	if collider.has_meta("vehicle_id"):
		if not collider is RigidBody3D:
			return {"valid":false, "reason":"unsupported_vehicle_body"}
		var id: Variant = collider.get_meta("vehicle_id")
		var life: Variant = collider.get_meta("life_generation") if collider.has_meta("life_generation") else null
		if not id is String or id.strip_edges().is_empty() or not life is int or life < 1:
			return {"valid":false, "reason":"invalid_vehicle_identity"}
		return {"valid":true, "kind":"vehicle", "vehicle_id":id,
			"life_generation":life, "counterpart_runtime_id":runtime_id,
			"proposal_only":true, "server_admissible":false}
	if collider is StaticBody3D:
		var source: Variant = collider.get_meta("source_id") if collider.has_meta("source_id") else null
		var index: Variant = collider.get_meta("source_index") if collider.has_meta("source_index") else null
		if not source is String or source.strip_edges().is_empty() or not index is int or index < 0:
			return {"valid":false, "reason":"unbound_static_source"}
		return {"valid":true, "kind":"static", "source_id":source,
			"source_index":index, "counterpart_runtime_id":runtime_id,
			"proposal_only":true, "server_admissible":false}
	return {"valid":false, "reason":"unsupported_counterpart"}
