extends Node
## Editor input must remain outside the stopped gameplay inventory. The host
## still gates every gameplay input/update path; GUI routing returning false
## is not permission to run gameplay. No discovery, global pause or flag edits.
var _host: RefCounted
var _owner: WeakRef
var _parent: WeakRef
var _mounted := false

func configure(owner: Node, host: RefCounted) -> Dictionary:
	if _mounted or not is_instance_valid(owner) or not owner.is_inside_tree() or not is_inside_tree() or get_parent() != owner:
		return {"ok": false, "error": "Маршрутизатор должен принадлежать текущей игровой сцене"}
	if host == null or not host.has_method("handle_input") or not host.has_method("is_mounted_owner") or not host.is_mounted_owner(owner):
		return {"ok": false, "error": "Нет подключённого игрового владельца редактора"}
	_host = host
	_owner = weakref(owner)
	_parent = weakref(get_parent())
	_mounted = true
	set_process_input(true)
	return {"ok": true}

func _live() -> bool:
	if not _mounted or _host == null: return false
	var owner: Variant = _owner.get_ref()
	return is_instance_valid(owner) and owner.is_inside_tree() and get_parent() == _parent.get_ref() and get_parent() == owner and _host.is_mounted_owner(owner)

func route(event: InputEvent) -> bool:
	if not _live(): return false
	return _host.handle_input(event)

func _input(event: InputEvent) -> void:
	if route(event): get_viewport().set_input_as_handled()
