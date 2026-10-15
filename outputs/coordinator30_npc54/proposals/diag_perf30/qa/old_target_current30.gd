extends "res://scripts/npc_visual/preview_resident_host.gd"
func target_current(token: Dictionary) -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or token.get("ok") != true or token.get("source_authority") != false: return false
	var body: Variant = token.get("body")
	if not is_instance_valid(body) or not body is CharacterBody3D: return false
	var fresh: Dictionary = target_from_collider(body)
	if not fresh.get("ok", false): return false
	for key: String in ["session_id", "source_id", "bridge_id", "render_id", "life_generation", "descriptor_sha256", "placement_mode", "body_instance_id", "body_rid", "rig", "rig_instance_id", "rig_epoch"]:
		if token.get(key) != fresh.get(key): return false
	return true
