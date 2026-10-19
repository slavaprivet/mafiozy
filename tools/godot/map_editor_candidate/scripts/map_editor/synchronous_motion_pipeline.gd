extends RefCounted
## Candidate ONLY: native mouse-motion/object-mode route, never key/click/save/
## ground mode. Proof lifetime is ONE synchronous dispatch, not a frame cache.
const HostType = preload("res://scripts/map_editor/editor_host_adapter.gd")
const WorkspaceType = preload("res://scripts/map_editor/editor_workspace.gd")
const ControllerType = preload("res://scripts/map_editor/editor_controller.gd")
const CameraType = preload("res://scripts/map_editor/editor_camera.gd")
const PanelType = preload("res://scripts/map_editor/editor_panel.gd")
const SceneType = preload("res://scripts/map_editor/scene_pause_owner_v2.gd")
const AnimationType = preload("res://scripts/map_editor/animation_pause_adapter_v2.gd")
const CompoundType = preload("res://scripts/map_editor/compound_pause_owner.gd")
var _host: RefCounted
var _workspace: Node
var _compound: RefCounted
var _scene: RefCounted
var _animation: RefCounted
var _admitted := {}
var _proof: RefCounted
var _proof_binding := {}
var _used := true
var _busy := false
var _call_sequence := 0
var _callback_epoch := 0
var _callback_inflight := false
var _frame := -1
var _physics_frame := -1
var _editor_ref: WeakRef
var _camera_ref: WeakRef
var _panel_ref: WeakRef
var _editor_parent: WeakRef
var _workspace_parent: WeakRef
var last_token: RefCounted # diagnostic reference; never makes it reusable
var last_full_checks := 0
static func failure(message: String) -> Dictionary: return {"ok": false, "error": message}
static func accepted(value: Variant) -> bool: return (value is bool and value) or (value is Dictionary and value.get("ok", false) == true)
func configure(host: RefCounted, workspace: Node, compound: RefCounted, scene: RefCounted, animation: RefCounted) -> Dictionary:
	if not Thread.is_main_thread() or _host != null: return failure("Main-thread single pipeline configuration required")
	var pairs := [[host, HostType], [workspace, WorkspaceType], [compound, CompoundType], [scene, SceneType], [animation, AnimationType]]
	for pair: Array in pairs:
		if not is_instance_valid(pair[0]) or pair[0].get_script() != pair[1]: return failure("Unknown/subclassed helper requires its own trusted effect-free contract")
	if not is_instance_valid(workspace.editor) or workspace.editor.get_script() != ControllerType or workspace.editor.camera.get_script() != CameraType or workspace.editor.panel.get_script() != PanelType: return failure("Only reviewed object editor/camera/panel route admitted")
	if compound._scene != scene or compound._animation != animation or host._workspace == null or host._workspace.get_ref() != workspace: return failure("Explicit host/owner/workspace binding mismatch")
	if workspace._transaction_ready != host.transaction_ready: return failure("Additional Workspace readiness owner needs its own mandatory callback barrier; never bypass it")
	_host = host
	_workspace = workspace
	_compound = compound
	_scene = scene
	_animation = animation
	_editor_ref = weakref(workspace.editor)
	_camera_ref = weakref(workspace.editor.camera)
	_panel_ref = weakref(workspace.editor.panel)
	_editor_parent = weakref(workspace.editor.get_parent())
	_workspace_parent = weakref(workspace.get_parent())
	return {"ok": true}
func admit_current_lease() -> Dictionary:
	if _busy or _host == null or _host._busy or _host._fault or _compound._busy or _compound._fault or _scene._busy or _animation._busy or _scene._fault or _animation._fault or not _workspace.editor.active: return failure("Current held lease required")
	if _workspace.editor.camera.get_child_count() != 0: return failure("Unknown editor camera child/effect needs separate motion-owner contract")
	if _host._receipt.is_empty() or _host._receipt != _compound._receipt or _host._request != _compound._request or _compound._scene_receipt != _scene._receipt or _compound._scene_handle != _scene._issued or _compound._animation_handle != _animation._issued: return failure("Owner/child issued capsule mismatch")
	# ClassDB lists native getters without invoking arbitrary script getters.
	# Captured script fields are REFUSED, not hidden behind a guessed cachetrue.
	var native_properties := {}
	for saved: Dictionary in _scene._capsule.nodes:
		var node: Node = saved.spec.node.get_ref()
		if not is_instance_valid(node): return failure("Missing owned participant")
		var native_class: String = node.get_class()
		if not native_properties.has(native_class):
			var fields := {}
			for row: Dictionary in ClassDB.class_get_property_list(native_class): fields[str(row.name)] = true
			native_properties[native_class] = fields
		for field: String in saved.fields:
			if not native_properties[native_class].has(field): return failure("Captured script getter field requires actual trusted read-only source contract: " + field)
	for saved: Dictionary in _animation._capsules:
		var mixer: AnimationMixer = saved.spec.mixer.get_ref()
		if not is_instance_valid(mixer) or mixer.get_class() != "AnimationPlayer" or mixer.get_script() != null: return failure("Scripted/derived animation mixer needs its specific read-only owner proof")
		for pose: Dictionary in saved.poses:
			var node: Node = pose.target.node.get_ref()
			if not is_instance_valid(node): return failure("Missing owned pose target")
			var native_class: String = node.get_class()
			if not native_properties.has(native_class):
				var fields := {}
				for row: Dictionary in ClassDB.class_get_property_list(native_class): fields[str(row.name)] = true
				native_properties[native_class] = fields
			for property: String in pose.values:
				if not native_properties[native_class].has(property): return failure("Captured script pose getter requires actual trusted read-only source contract")
	if not _full_check(): return failure("Lease preflight refused")
	_admitted = {"scene": _scene._issued, "animation": _animation._issued, "receipt": _host._receipt.duplicate(true), "request": _host._request.duplicate(true), "scene_receipt": _scene._receipt.duplicate(true)}
	return {"ok": true}
func _binding_live() -> bool:
	if _admitted.is_empty() or not is_instance_valid(_workspace) or not _workspace.is_inside_tree() or _workspace.get_script() != WorkspaceType or _workspace.get_parent() != _workspace_parent.get_ref() or _workspace._transaction_ready != _host.transaction_ready or _workspace.mode != "objects": return false
	var editor: Node = _editor_ref.get_ref()
	if not is_instance_valid(editor) or not editor.is_inside_tree() or editor.get_script() != ControllerType or _workspace.editor != editor or editor.get_parent() != _editor_parent.get_ref() or not editor.active or editor.camera != _camera_ref.get_ref() or editor.panel != _panel_ref.get_ref(): return false
	if not is_instance_valid(editor.camera) or not is_instance_valid(editor.panel) or editor.camera.get_script() != CameraType or editor.panel.get_script() != PanelType or editor.camera.get_parent() != editor or editor.panel.get_parent() != editor or editor.camera.get_child_count() != 0: return false
	return _host._receipt == _admitted.receipt and _host._request == _admitted.request and _compound._receipt == _admitted.receipt and _compound._request == _admitted.request and _scene._receipt == _admitted.scene_receipt and _compound._scene_receipt == _admitted.scene_receipt and _scene._issued == _admitted.scene and _animation._issued == _admitted.animation and _compound._scene_handle == _admitted.scene and _compound._animation_handle == _admitted.animation
func _full_check() -> bool:
	last_full_checks += 1
	# Do not short-circuit the second owner: every callback fence checks BOTH.
	var scene_ok: bool = _scene.preflight_restore(_scene._issued).ok
	var animation_ok: bool = _animation.preflight_restore(_animation._issued).ok
	return scene_ok and animation_ok and not _scene._fault and not _animation._fault
func _issue() -> RefCounted:
	if not _busy or _callback_inflight or not _binding_live(): return null
	_proof = RefCounted.new()
	_used = false
	_proof_binding = {"sequence": _call_sequence, "epoch": _callback_epoch, "scene": _admitted.scene, "animation": _admitted.animation, "request": _admitted.request.duplicate(true), "receipt": _admitted.receipt.duplicate(true)}
	last_token = _proof
	return _proof
func consume_proof(token: Variant) -> bool:
	if not Thread.is_main_thread() or not _busy or _callback_inflight or _used or token == null or token != _proof or not _binding_live() or Engine.get_process_frames() != _frame or Engine.get_physics_frames() != _physics_frame or _proof_binding.sequence != _call_sequence or _proof_binding.epoch != _callback_epoch or _proof_binding.scene != _scene._issued or _proof_binding.animation != _animation._issued or _proof_binding.request != _host._request or _proof_binding.receipt != _host._receipt: return false
	_used = true
	return true
func _invalidate() -> void:
	_proof = null
	_proof_binding.clear()
	_used = true
func _call_owner(callback: Callable, argument: Dictionary) -> Dictionary:
	# A previously issued proof cannot cross any external owner Callable.
	_invalidate()
	_callback_epoch += 1
	_callback_inflight = true
	_scene._busy = true
	_animation._busy = true
	var decision: Variant = callback.call(argument.duplicate(true))
	_scene._busy = false
	_animation._busy = false
	_callback_inflight = false
	var owners_held := _full_check() # Mandatory BOTH-owner postflight even if route binding changed.
	var still_held := _binding_live() and owners_held
	if not still_held: return failure("Owner callback changed lifetime/clock/control/pose; retained freeze")
	return {"ok": true, "accepted": accepted(decision), "proof": _issue()}
func _call_external_ready() -> Dictionary:
	_invalidate()
	_callback_epoch += 1
	_callback_inflight = true
	_scene._busy = true
	_animation._busy = true
	var decision: bool = _compound._gate("ready", {"receipt": _admitted.receipt})
	_scene._busy = false
	_animation._busy = false
	_callback_inflight = false
	var owners_held := _full_check()
	var still_held := _binding_live() and owners_held
	if not still_held: return failure("External owner callback changed held scene; retained freeze")
	return {"ok": true, "accepted": decision, "proof": _issue()}
func _finish(result: Dictionary, fault: bool = false) -> Dictionary:
	_invalidate()
	_callback_inflight = false
	if fault:
		_scene.hold(_admitted.get("scene"))
		_animation.hold(_admitted.get("animation"))
		_compound._fault = true
		_host._fault = true
	_host._busy = false
	_compound._busy = false
	_busy = false
	return result
func _pending() -> Dictionary:
	_workspace.editor.camera.clear_motion() # Exact Workspace blocked-readiness behavior.
	return _finish({"ok": false, "eligible": true, "handled": true, "pending": true})
func try_motion(event: InputEvent) -> Dictionary:
	if not Thread.is_main_thread() or _busy: return {"ok": false, "eligible": true, "handled": true, "error": "Reentrant/off-thread proof dispatch refused"}
	if not event is InputEventMouseMotion or event.get_script() != null or _host == null or not _binding_live() or _workspace.mode != "objects": return {"ok": false, "eligible": false}
	if _host._busy or _host._fault or _compound._busy or _compound._fault or _scene._busy or _animation._busy or _scene._fault or _animation._fault or _workspace._cleanup_blocked or _workspace._recovery_required or _workspace.editor.atomic_install_active: return {"ok": false, "eligible": false}
	_busy = true
	_host._busy = true
	_compound._busy = true
	_call_sequence += 1
	_callback_epoch = 0
	_frame = Engine.get_process_frames()
	_physics_frame = Engine.get_physics_frames()
	last_full_checks = 0
	if not _full_check(): return _finish({"ok": false, "eligible": true, "handled": true, "error": "Initial all-owner proof refused"}, true)
	if not consume_proof(_issue()): return _finish(failure("Initial proof identity refused"), true)
	if _scene._settled_frame < 0 or Engine.get_physics_frames() <= _scene._settled_frame: return _pending()
	var owner_ready := _call_owner(_scene._callbacks.transaction_ready, _scene._receipt)
	if not owner_ready.ok: return _finish({"ok": false, "eligible": true, "handled": true, "error": owner_ready.error}, true)
	if not owner_ready.accepted: return _pending()
	if not consume_proof(owner_ready.proof): return _finish(failure("Owner-ready proof identity refused"), true)
	var external_ready := _call_external_ready()
	if not external_ready.ok: return _finish({"ok": false, "eligible": true, "handled": true, "error": external_ready.error}, true)
	if not external_ready.accepted: return _pending()
	if not consume_proof(external_ready.proof): return _finish(failure("External-ready proof identity refused"), true)
	if _workspace._cleanup_blocked or _workspace._recovery_required or _workspace.editor.atomic_install_active: return _pending()
	# Exact frozen native-motion controller path: GUI focus/pointer guards and
	# camera/drag bookkeeping only; no pick/mutation or external owner callbacks.
	var handled: bool = _workspace.editor.handle_input(event)
	return _finish({"ok": true, "eligible": true, "handled": handled, "full_checks": last_full_checks})
