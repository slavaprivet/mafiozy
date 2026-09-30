extends PanelContainer
const Layout=preload("context_plate_layout.gd")
## Original car prompt palette, border, keycaps and world projection:
## tools/city_rebuild_walk.html:12-15; walk_preview.mjs:1040-1052.
## Present only currently admitted actions supplied by cargo bridge.
var camera: Camera3D
var anchor_world := Vector3.ZERO
var heading: Label
var capacity: Label
var detail: Label
var rows: VBoxContainer
var gauge: ProgressBar
var action_rows: Array = []
var _active := false
var _fixed_ground := false
var _calling_ground := false
var _view_signature := ""
var _layout_targets: Array=[]
var _layout_hero: WeakRef
var _layout_controls: Array=[]
var _layout_signature: Array=[]
var _last_layout_rect:=Rect2()
var _layout_identity:=""
var layout_receipt: Dictionary={}

func set_layout_context(view_camera: Camera3D, identity: String, targets: Array, hero: Node3D, controls: Array) -> void:
	camera=view_camera; _layout_targets=targets; _layout_hero=weakref(hero); _layout_controls=controls
	if identity!=_layout_identity:
		_last_layout_rect=Rect2(); _layout_signature.clear(); _layout_identity=identity

func _place_clear() -> bool:
	if _layout_targets.is_empty() or not is_instance_valid(camera): return false
	var viewport:=get_viewport_rect()
	var signature: Array=[camera.global_transform,camera.fov,camera.keep_aspect,viewport,size]
	var live_targets: Array=[]
	for descriptor: Dictionary in _layout_targets:
		var node: Node3D=descriptor.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree(): continue
		live_targets.append({"bounds":descriptor.bounds,"world":node.global_transform})
		signature.append(node.global_transform); signature.append(descriptor.bounds)
	var hero: Node3D=_layout_hero.get_ref() if _layout_hero!=null else null
	var capsule: CollisionShape3D=hero.get_node_or_null("PlayerCapsule") if is_instance_valid(hero) else null
	if is_instance_valid(capsule): signature.append(capsule.global_transform); signature.append(capsule.shape.height)
	var obstacles: Array[Rect2]=[Rect2(viewport.get_center()-Vector2(12,12),Vector2(24,24))]
	for reference: WeakRef in _layout_controls:
		var control: Control=reference.get_ref()
		if is_instance_valid(control) and control.is_visible_in_tree(): obstacles.append(control.get_global_rect())
	signature.append(obstacles.duplicate())
	if signature==_layout_signature:
		visible=_active and bool(layout_receipt.get("ok",false)); return true
	_layout_signature=signature
	var target:=Rect2(); var first:=true
	for descriptor: Dictionary in live_targets:
		var projected: Dictionary=Layout.projected_bounds(camera,descriptor.bounds,descriptor.world)
		if not projected.ok: continue
		if first: target=projected.rect; first=false
		else: target=target.merge(projected.rect)
	if first or not target.intersects(viewport):
		visible=false; layout_receipt={"ok":false,"reason":"target_offscreen"}; return true
	if is_instance_valid(capsule):
		var radius: float=capsule.shape.radius+.12
		var height: float=capsule.shape.height
		var body: Dictionary=Layout.projected_bounds(camera,AABB(Vector3(-radius,-height*.5,-radius),Vector3(radius*2,height+.12,radius*2)),capsule.global_transform)
		if body.ok: obstacles.append(body.rect)
	layout_receipt=Layout.choose(viewport,size,target,obstacles,_last_layout_rect)
	layout_receipt.target_rect=target; layout_receipt.protected_rects=obstacles
	visible=_active and bool(layout_receipt.ok)
	if visible: position=layout_receipt.rect.position; _last_layout_rect=layout_receipt.rect
	return true

static func _style(background: String, border: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=Color(background); style.border_color=Color(border)
	style.set_border_width_all(1); style.set_corner_radius_all(radius)
	style.shadow_color=Color(0,0,0,.55); style.shadow_size=9; style.shadow_offset=Vector2(0,4)
	return style

static func _label(text: String, pixels: int, color: String) -> Label:
	var label := Label.new(); label.text=text; label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",Color(color)); label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; visible=false
	add_theme_stylebox_override("panel",_style("202629f5","ad956c",12))
	var margin := MarginContainer.new(); margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_"+side,15)
	for side: String in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	add_child(margin)
	var column := VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_theme_constant_override("separation",6); margin.add_child(column)
	heading=_label("Багажник",16,"d8d1bd"); column.add_child(heading)
	rows=VBoxContainer.new(); rows.mouse_filter=Control.MOUSE_FILTER_IGNORE; rows.add_theme_constant_override("separation",5); column.add_child(rows)
	# Fixed two rows avoid rebuilding controls at the 150ms aim sample rate.
	for index: int in 2:
		var row := HBoxContainer.new(); row.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation",7); rows.add_child(row)
		var key := PanelContainer.new(); key.mouse_filter=Control.MOUSE_FILTER_IGNORE; key.custom_minimum_size=Vector2(25,25); key.add_theme_stylebox_override("panel",_style("9c8155","bba783",4)); row.add_child(key)
		var letter := _label("",16,"211d17"); letter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; key.add_child(letter)
		var action := _label("",13,"d8d1bd"); row.add_child(action)
		action_rows.append({"row":row,"key":letter,"label":action})
	capacity=_label("",11,"aaa38f"); column.add_child(capacity)
	gauge=ProgressBar.new(); gauge.custom_minimum_size=Vector2(260,3); gauge.show_percentage=false
	gauge.mouse_filter=Control.MOUSE_FILTER_IGNORE; gauge.add_theme_stylebox_override("background",_style("303637","303637",1)); gauge.add_theme_stylebox_override("fill",_style("aa9169","aa9169",1)); column.add_child(gauge)
	detail=_label("",11,"aaa38f"); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.custom_minimum_size.x=260; column.add_child(detail)

func clear() -> void:
	_active=false; visible=false; _layout_signature.clear(); _last_layout_rect=Rect2()

func present(view_camera: Camera3D, world_anchor: Vector3, card_title: String, actions: Array, used: int = -1, maximum: int = 100, message: String = "") -> void:
	if _fixed_ground and not _calling_ground:
		_fixed_ground=false
		add_theme_stylebox_override("panel",_style("202629f5","ad956c",12))
	camera=view_camera; anchor_world=world_anchor; _active=true
	var signature: String=card_title+"|"+str(actions)+"|"+str(used)+":"+str(maximum)+"|"+message
	if signature==_view_signature:
		_project(); return
	_view_signature=signature
	heading.text=card_title
	for index: int in action_rows.size():
		var record: Dictionary=action_rows[index]; record.row.visible=index<actions.size()
		if index<actions.size(): record.key.text=str(actions[index].key); record.label.text=str(actions[index].label)
	capacity.visible=used>=0; gauge.visible=used>=0
	if used>=0:
		capacity.text="Занято %d / %d · Свободно %d" % [used,maximum,maxi(0,maximum-used)]
		gauge.max_value=maximum; gauge.value=used
	detail.text=message; detail.visible=not message.is_empty()
	reset_size()
	_project()

func _process(_delta: float) -> void:
	if _active: _project()

func _project() -> void:
	if _place_clear(): return
	if _fixed_ground:
		var area:=get_viewport_rect().size
		visible=_active; position=Vector2((area.x-size.x)*.5,maxf(12,area.y-140-size.y))
		return
	if not is_instance_valid(camera) or camera.is_position_behind(anchor_world): visible=false; return
	var screen := camera.unproject_position(anchor_world)
	var viewport := get_viewport_rect().size
	# Like Walk, hide off-screen rather than pretending the target is at an edge.
	if screen.x<0 or screen.x>viewport.x or screen.y<0 or screen.y>viewport.y: visible=false; return
	visible=true; position=Vector2(clampf(screen.x-size.x*.5,12,maxf(12,viewport.x-size.x-12)),maxf(12,screen.y-size.y-12))

func present_ground(card_title: String, magazine: int, reserve: int) -> void:
	# Source walk_preview.mjs:665,1692. Stable nearest-item plate bottom-centre.
	_calling_ground=true
	present(camera,Vector3.ZERO,"%s · %d / %d" % [card_title,magazine,reserve],[{"key":"E","label":"Подобрать"}],-1,100,"")
	_calling_ground=false
	if not _fixed_ground: add_theme_stylebox_override("panel",_style("202629f5","ad956c",6))
	_fixed_ground=true
	_project()
