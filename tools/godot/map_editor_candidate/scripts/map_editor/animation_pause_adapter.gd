extends RefCounted
## Explicit AnimationPlayer/base-Mixer lease. active=false preserves the engine
## playback clock; never stop/play/seek/restart or edit resources to fake restore.
var _main: WeakRef
var _owners: Array = []
var _capsules: Array = []
var _connections: Array = []
var _busy := false
var _dirty := false
var _fault := false

static func failure(message: String) -> Dictionary: return {"ok": false, "error": message}
static func _copy(value: Variant) -> Variant: return value.duplicate(true) if value is Array or value is Dictionary else value
func configure(main: Node, inventory: Array) -> Dictionary:
	if not Thread.is_main_thread() or _main != null or not is_instance_valid(main) or not main.is_inside_tree() or inventory.is_empty(): return failure("Existing scene and explicit main-thread animation inventory required")
	var seen := {}
	var owners: Array = []
	for supplied: Variant in inventory:
		if not supplied is Dictionary or not supplied.get("mixer") is AnimationMixer: return failure("Explicit AnimationMixer required")
		var mixer: AnimationMixer = supplied.mixer
		if mixer is AnimationTree or (not mixer is AnimationPlayer and mixer.get_class() != "AnimationMixer"): return failure("AnimationTree/derived mixer needs its specific state-machine owner")
		if not mixer.is_inside_tree() or not main.is_ancestor_of(mixer) or seen.has(mixer.get_instance_id()): return failure("Foreign or duplicate mixer owner")
		var identity: Variant = supplied.get("identity", {})
		if not identity is Dictionary: return failure("Invalid animation lifetime receipt")
		for key in identity:
			if not key is String or not mixer.has_meta(key) or mixer.get_meta(key) != identity[key]: return failure("Animation lifetime mismatch")
		var targets: Array = []
		for target: Variant in supplied.get("pose_targets", []):
			if not target is Dictionary or not target.get("node") is Node or not target.get("properties") is Array: return failure("Explicit pose target/property list required")
			var node: Node = target.node
			if not node.is_inside_tree() or not main.is_ancestor_of(node): return failure("Foreign animation pose target")
			for property: Variant in target.properties:
				if not property is String or not _property_exists(node, property) or node.get(property) is Object: return failure("Unsupported owned pose property")
			targets.append({"node": weakref(node), "parent": weakref(node.get_parent()), "instance": node.get_instance_id(), "properties": target.properties.duplicate()})
		seen[mixer.get_instance_id()] = true
		owners.append({"mixer": weakref(mixer), "parent": weakref(mixer.get_parent()), "instance": mixer.get_instance_id(), "identity": identity.duplicate(true), "targets": targets})
	_main = weakref(main)
	_owners = owners
	return {"ok": true}
static func _property_exists(node: Node, property: String) -> bool:
	for row: Dictionary in node.get_property_list():
		if row.name == property: return true
	return false
func _live(spec: Dictionary) -> bool:
	var main: Node = _main.get_ref() if _main != null else null
	var mixer: Node = spec.mixer.get_ref()
	var parent: Node = spec.parent.get_ref()
	if not is_instance_valid(main) or not main.is_inside_tree() or not is_instance_valid(mixer) or not mixer.is_inside_tree() or not is_instance_valid(parent) or mixer.get_parent() != parent or mixer.get_instance_id() != spec.instance or not main.is_ancestor_of(mixer): return false
	for key in spec.identity:
		if not mixer.has_meta(key) or mixer.get_meta(key) != spec.identity[key]: return false
	for target: Dictionary in spec.targets:
		var node: Node = target.node.get_ref()
		var target_parent: Node = target.parent.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or not is_instance_valid(target_parent) or node.get_parent() != target_parent or node.get_instance_id() != target.instance or not main.is_ancestor_of(node): return false
	return true
func _state(mixer: AnimationMixer) -> Dictionary:
	var state := {"deterministic": mixer.deterministic, "root_node": mixer.root_node, "root_motion_track": mixer.root_motion_track, "root_motion_local": mixer.root_motion_local, "audio_max_polyphony": mixer.audio_max_polyphony, "callback_mode_process": mixer.callback_mode_process, "callback_mode_method": mixer.callback_mode_method, "callback_mode_discrete": mixer.callback_mode_discrete,
		"root_position": mixer.get_root_motion_position(), "root_rotation": mixer.get_root_motion_rotation(), "root_scale": mixer.get_root_motion_scale(), "root_position_accumulator": mixer.get_root_motion_position_accumulator(), "root_rotation_accumulator": mixer.get_root_motion_rotation_accumulator(), "root_scale_accumulator": mixer.get_root_motion_scale_accumulator()}
	if mixer is AnimationPlayer:
		state.player = {"current_animation": mixer.current_animation, "assigned_animation": mixer.assigned_animation, "position": mixer.current_animation_position, "length": mixer.current_animation_length, "speed_scale": mixer.speed_scale, "playing_speed": mixer.get_playing_speed(), "playing": mixer.is_playing(), "queue": mixer.get_queue(), "section_start": mixer.get_section_start_time(), "section_end": mixer.get_section_end_time(), "has_section": mixer.has_section(), "autoplay": mixer.autoplay, "default_blend": mixer.playback_default_blend_time, "auto_capture": mixer.playback_auto_capture, "capture_duration": mixer.playback_auto_capture_duration, "capture_transition": mixer.playback_auto_capture_transition_type, "capture_ease": mixer.playback_auto_capture_ease_type}
	return state
func _resource_changed() -> void: _dirty = true
func _watch(resource: Resource, seen: Dictionary) -> void:
	if seen.has(resource.get_instance_id()): return
	seen[resource.get_instance_id()] = true
	resource.changed.connect(_resource_changed)
	_connections.append(resource)
func _disconnect_resources() -> void:
	for resource: Resource in _connections:
		if resource.changed.is_connected(_resource_changed): resource.changed.disconnect(_resource_changed)
	_connections.clear()
func pause() -> Dictionary:
	if not Thread.is_main_thread() or _main == null or _busy or _fault or not _capsules.is_empty(): return failure("Animation owner busy or requires repair")
	_busy = true
	var capsules: Array = []
	var watched := {}
	for spec: Dictionary in _owners:
		if not _live(spec):
			_disconnect_resources()
			_busy = false
			return failure("Animation owner lifetime changed before pause")
		var mixer: AnimationMixer = spec.mixer.get_ref()
		var libraries := {}
		for name: StringName in mixer.get_animation_library_list():
			var library: AnimationLibrary = mixer.get_animation_library(name)
			_watch(library, watched)
			var animations := {}
			for animation_name: StringName in library.get_animation_list():
				var animation: Animation = library.get_animation(animation_name)
				_watch(animation, watched)
				animations[animation_name] = animation
			libraries[name] = {"library": library, "animations": animations}
		var poses: Array = []
		for target: Dictionary in spec.targets:
			var values := {}
			for property: String in target.properties: values[property] = _copy(target.node.get_ref().get(property))
			poses.append({"target": target, "values": values})
		capsules.append({"spec": spec, "active": mixer.active, "state": _state(mixer), "libraries": libraries, "poses": poses})
	_capsules = capsules
	_dirty = false
	for capsule: Dictionary in _capsules: capsule.spec.mixer.get_ref().active = false
	_busy = false
	if not verify():
		_fault = true
		return failure("Native animation freeze changed the owned state")
	return {"ok": true}
func verify() -> bool:
	if not Thread.is_main_thread() or _busy or _dirty or _capsules.is_empty(): return false
	for capsule: Dictionary in _capsules:
		if not _live(capsule.spec): return false
		var mixer: AnimationMixer = capsule.spec.mixer.get_ref()
		if mixer.active or _state(mixer) != capsule.state or mixer.get_animation_library_list().size() != capsule.libraries.size(): return false
		for name: StringName in capsule.libraries:
			if not mixer.has_animation_library(name): return false
			var saved: Dictionary = capsule.libraries[name]
			var library: AnimationLibrary = mixer.get_animation_library(name)
			if library != saved.library or library.get_animation_list().size() != saved.animations.size(): return false
			for animation_name: StringName in saved.animations:
				if not library.has_animation(animation_name) or library.get_animation(animation_name) != saved.animations[animation_name]: return false
		for pose: Dictionary in capsule.poses:
			for property: String in pose.values:
				if pose.target.node.get_ref().get(property) != pose.values[property]: return false
	return true
func restore() -> Dictionary:
	if not Thread.is_main_thread() or _busy: return failure("Reentrant or off-thread animation restoration refused")
	if _capsules.is_empty(): return {"ok": true, "unchanged": true}
	if not verify():
		_fault = true
		return failure("Animation phase/resource/pose/lifetime changed; owner repair required")
	_busy = true
	for capsule: Dictionary in _capsules: capsule.spec.mixer.get_ref().active = capsule.active
	# active toggles alone must not restart playback or re-evaluate the pose.
	for capsule: Dictionary in _capsules:
		var mixer: AnimationMixer = capsule.spec.mixer.get_ref()
		if not _live(capsule.spec) or mixer.active != capsule.active or _state(mixer) != capsule.state:
			for own: Dictionary in _capsules:
				if _live(own.spec): own.spec.mixer.get_ref().active = false
			_busy = false
			_fault = true
			return failure("Animation resume failed exact-state check; owned mixers remain stopped")
	_disconnect_resources()
	_capsules.clear()
	_busy = false
	_fault = false
	return {"ok": true}
func state() -> Dictionary: return {"paused": not _capsules.is_empty(), "fault": _fault, "resource_changed": _dirty, "busy": _busy}
