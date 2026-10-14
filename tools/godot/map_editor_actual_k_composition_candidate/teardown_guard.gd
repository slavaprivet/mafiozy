extends Node
## Root-owned escrow for a pause-only workspace whose owner scene is being freed.
## It never releases a live scene or an altered SceneTree ownership token.

var _tree: SceneTree
var _owner: WeakRef
var _meta_key: String
var _token: String
var _armed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func configure(tree: SceneTree, owner: Node, meta_key: String, token: String) -> void:
	_tree = tree
	_owner = weakref(owner)
	_meta_key = meta_key
	_token = token

func arm() -> void:
	_armed = true
	set_process(true)

func disarm() -> void:
	_armed = false
	set_process(false)

func _process(_delta: float) -> void:
	if not _armed: return
	# A workspace removed on its own is not authority to resume this scene.
	if _owner.get_ref() != null:
		disarm()
		queue_free()
		return
	_armed = false
	if _tree != null and _tree.paused and _tree.get_meta(_meta_key, "") == _token:
		_tree.remove_meta(_meta_key)
		_tree.paused = false
	queue_free()
