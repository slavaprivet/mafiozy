extends RefCounted
## Proposed on-foot presentation only. Never writes input, actor/bones, camera
## transform, yaw/roll, world collision layers or world health authority.
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
var _host: WeakRef
var _camera: Camera3D
var _arm: SpringArm3D
var _pivot: Node3D
var _base_position := Vector3.ZERO
var _base_fov := 65.0
var _blend := 0.0
var _owns := false
var _scoped := false
var _ready := false
var _hidden: Array[Dictionary] = []
var _layer: CanvasLayer
var _overlay: Control
var _mask: ColorRect
var _optic: TextureRect
var _scope_alpha := 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _query_count := 0

func configure(host: Node) -> bool:
	if _ready or not is_instance_valid(host) or not host._owner_current(): return false
	_host=weakref(host); _camera=host.player.get_preview_camera(); _arm=host.player._spring_arm; _pivot=host.player._yaw_pivot
	if _camera.get_parent()!=_arm or _arm.get_parent()!=_pivot or _camera.top_level or not _arm.shape is SphereShape3D: return false
	_base_position=_arm.position; _base_fov=_camera.fov
	_query.shape=_arm.shape; _query.exclude=[host.player.get_rid()]
	var svg_path: String=get_script().resource_path.get_base_dir().path_join("scope_optic.svg")
	# Use Godot's imported texture in both the editor and exported PCK. The raw
	# SVG is replaced by its import remap in exports and is not a readable file.
	var picture:=load(svg_path) as Texture2D
	if picture==null: return false
	_layer=CanvasLayer.new(); _layer.name="WalkSniperScope"; _layer.layer=13; host.add_child(_layer)
	_overlay=Control.new(); _overlay.name="ScopeOnly"; _overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; _overlay.focus_mode=Control.FOCUS_NONE; _layer.add_child(_overlay)
	_mask=ColorRect.new(); _mask.mouse_filter=Control.MOUSE_FILTER_IGNORE; _overlay.add_child(_mask)
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform vec2 rect_size=vec2(1280.,720.); void fragment(){float m=min(rect_size.x,rect_size.y);float r=length((UV-vec2(.5))*rect_size);float a=clamp((r-.37*m)/(.05*m),0.,1.);COLOR=vec4(2./255.,3./255.,4./255.,a);}"
	var material:=ShaderMaterial.new(); material.shader=shader; _mask.material=material
	_optic=TextureRect.new(); _optic.mouse_filter=Control.MOUSE_FILTER_IGNORE; _optic.texture=picture; _optic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; _optic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _overlay.add_child(_optic)
	_overlay.hide(); _ready=true; _resize()
	host.get_viewport().size_changed.connect(_resize)
	return true
func _resize() -> void:
	if not _ready or not is_instance_valid(_overlay) or _host==null or not is_instance_valid(_host.get_ref()): return
	var size: Vector2=_host.get_ref().get_viewport().get_visible_rect().size
	_overlay.size=size; _mask.size=size; _mask.material.set_shader_parameter("rect_size",size)
	var side:=minf(minf(size.x,size.y)*.92,920)
	_optic.position=(size-Vector2.ONE*side)*.5; _optic.size=Vector2.ONE*side
func _live() -> bool:
	return _ready and _host!=null and is_instance_valid(_host.get_ref()) and _host.get_ref()._owner_current() and is_instance_valid(_camera) and _camera.get_parent()==_arm and _arm.get_parent()==_pivot and not _camera.top_level
func _on_foot(host: Node) -> bool:
	return host._interaction_allowed() and not host.menu_open and not host.player._text_control_focused()
func _allowed(host: Node) -> bool:
	# Walk combatAllowed does not disable aim/scope during reload.
	return _on_foot(host) and host.armed()
func scoped() -> bool: return _scoped
func owns_distance() -> bool: return _owns and (_blend>.005 or _scoped)
func pitch_limits() -> Vector2:
	if _live() and _allowed(_host.get_ref()) and _host.get_ref()._aiming: return Vector2(-PI*.5+.0001,PI*.42)
	if _live() and _on_foot(_host.get_ref()): return Vector2(-PI*.5+.0001,-PI*.02)
	return Vector2(-1.05,.45)
func _hide_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		_hidden.append({"node":weakref(node),"layers":node.layers}); node.layers=0
	for child: Node in node.get_children(): _hide_geometry(child)
func _set_scope(value: bool) -> void:
	if value==_scoped: return
	_scoped=value; _scope_alpha=0
	if value:
		# Native muzzle validation deliberately requires visible Node3D ancestry.
		# Render layers hide the source hero + mounted weapon without defeating it.
		_hide_geometry(_host.get_ref().player._visual)
	else:
		for entry: Dictionary in _hidden:
			var node: Variant=entry.node.get_ref()
			if is_instance_valid(node) and node.layers==0: node.layers=entry.layers
		_hidden.clear()
	if is_instance_valid(_overlay): _overlay.visible=value; _overlay.modulate.a=0
func _safe_arm_position(desired: Vector3) -> Vector3:
	if desired.is_equal_approx(_base_position): return desired
	var host: Node=_host.get_ref()
	var from: Vector3=_pivot.global_transform*_base_position
	var motion: Vector3=_pivot.global_basis*(desired-_base_position)
	_query.transform=Transform3D(Basis.IDENTITY,from); _query.collision_mask=_arm.collision_mask; _query.margin=_arm.margin; _query.motion=Vector3.ZERO
	_query_count+=1
	var space: PhysicsDirectSpaceState3D=host.player.get_world_3d().direct_space_state
	if not space.intersect_shape(_query,1).is_empty(): return _base_position
	_query.motion=motion; _query_count+=1
	var travel: PackedFloat32Array=space.cast_motion(_query)
	return _base_position+(desired-_base_position)*clampf(travel[0],0,1)
func advance(delta: float) -> void:
	if not _live(): reset(); return
	if not is_finite(delta) or delta<0 or delta>5: reset(); return
	var host: Node=_host.get_ref()
	if not _on_foot(host): reset(); return
	var desired: bool=_allowed(host) and host._aiming
	_owns=true
	var limits:=pitch_limits()
	var pitch: float=clampf(host.player._camera_pitch,limits.x,limits.y)
	if pitch!=host.player._camera_pitch: host.player._camera_pitch=pitch; host.player._update_camera_rotation()
	_blend+=(float(desired)-_blend)*(1-exp(-14*delta))
	var scope: bool=desired and host.fire_state.weaponId=="sniper"
	_set_scope(scope)
	var pivot_height: float=(_pivot.global_position-host.player.global_position).y
	var eye: float=host._posture_view.get("eyeHeight",1.64)
	var normal_position: Vector3=_base_position+Vector3(0,eye-pivot_height,0)
	var target: Vector3=_base_position+Vector3(0 if scope else .75,eye-pivot_height,0)
	var distance: float=.12 if scope else 4.2
	var rate: float=1-exp(-(10 if desired else 14)*delta)
	var position: Vector3=target if scope else _arm.position.lerp(target if desired else normal_position,rate)
	_arm.position=_safe_arm_position(position)
	_arm.spring_length=distance if scope else lerpf(_arm.spring_length,distance if desired else host.player.camera_distance,rate)
	# Walk applies45 even without a weapon.65 is restored only on ownership exit.
	var kick: float=Fire.sample_recoil(host.fire_state).weaponKick
	_camera.fov=(14.0 if scope else 45.0-3.0*_blend)+kick*.15
	if scope: _scope_alpha=minf(1,_scope_alpha+delta/.1); _overlay.modulate.a=_scope_alpha
	if not desired and _blend<.005:
		_blend=0; _arm.spring_length=host.player.camera_distance
func reset(release_owner: bool = false) -> void:
	var host: Variant=_host.get_ref() if _host!=null else null
	# Menu, blur and weapon changes release aim, not the on-foot camera owner.
	# Once handed to a seat/death owner, repeated ticks must not overwrite it.
	var retain_walk: bool=not release_owner and is_instance_valid(host) and host._owner_current() and host.player._pose_authority==&"on_foot" and not host.scene.preview_dead and not host.scene.preview_physics_fault
	var had_ownership: bool=_owns or _scoped
	_set_scope(false)
	if retain_walk or had_ownership:
		if is_instance_valid(_arm): _arm.position=_base_position
		if is_instance_valid(_camera): _camera.fov=45.0 if retain_walk else _base_fov
		if is_instance_valid(_arm) and _host!=null and is_instance_valid(_host.get_ref()) and is_instance_valid(_host.get_ref().player): _arm.spring_length=_host.get_ref().player.camera_distance
	_blend=0; _owns=retain_walk
func stats() -> Dictionary:
	return {"owns":_owns,"scoped":_scoped,"blend":_blend,"base_fov":_base_fov,"hidden_geometry":_hidden.size(),"queries":_query_count,"scope_alpha":_scope_alpha}
func dispose() -> void:
	reset(true)
	if _host!=null and is_instance_valid(_host.get_ref()):
		var viewport: Viewport=_host.get_ref().get_viewport()
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(_resize): viewport.size_changed.disconnect(_resize)
	_ready=false
	if is_instance_valid(_layer): _layer.queue_free()
	_host=null
