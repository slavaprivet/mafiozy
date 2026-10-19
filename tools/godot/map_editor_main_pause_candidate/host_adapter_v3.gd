extends "res://scripts/map_editor/editor_host_adapter_v2.gd"
## A faulted host still routes Escape to its SAME attached owner for exact
## read-only recovery; no edit/leave/foreign-owner callback is bypassed.
func handle_input(event: InputEvent) -> bool:
	if _fault and event is InputEventKey and not event.echo:
		var workspace := _workspace_node()
		if workspace != null:
			if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
				if workspace.has_method("handle_recovery"):
					return workspace.handle_recovery(event)
			if not event.pressed and (event.physical_keycode == KEY_K or event.keycode == KEY_K):
				return workspace.handle_input(event)
	return super.handle_input(event)
