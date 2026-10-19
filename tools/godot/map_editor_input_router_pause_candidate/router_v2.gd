extends "res://scripts/map_editor/editor_input_router.gd"
## Source-only pause-aware input route, not a gameplay pause owner.
## Explicit ALWAYS is confined to this editor-owned router. The game parent
## remains PAUSABLE, so native actors and physics are not accidentally resumed.
func configure(owner: Node, host: RefCounted) -> Dictionary:
	if is_queued_for_deletion() or not is_instance_valid(owner) or owner.is_queued_for_deletion():
		return {"ok":false,"error":"Editor router owner lifecycle ended"}
	var result: Dictionary = super.configure(owner, host)
	if result.get("ok",false):
		process_mode = Node.PROCESS_MODE_ALWAYS
	return result

func _live() -> bool:
	if is_queued_for_deletion(): return false
	var owner: Variant = _owner.get_ref() if _owner != null else null
	return is_instance_valid(owner) and not owner.is_queued_for_deletion() and super._live()
