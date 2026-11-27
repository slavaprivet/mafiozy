extends Button
## Dragging this card outside the inventory requests one atomic world drop.

const ResourceItemIcon=preload("res://scripts/inventory/resource_item_icon.gd")
signal drop_outside(item_id: String, amount: int)

var item_id:=""
var available_count:=0
var drop_boundary: Control
var _drag_amount:=0

func configure(id: String,boundary: Control) -> void:
	item_id=id; drop_boundary=boundary

func set_available(value: int) -> void:
	available_count=maxi(0,value)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or available_count<=0: return null
	_drag_amount=available_count
	var preview:=PanelContainer.new(); preview.custom_minimum_size=Vector2(150,112); preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new(); style.bg_color=Color("26302f"); style.border_color=Color("e0b65f"); style.set_border_width_all(2); style.set_corner_radius_all(10); preview.add_theme_stylebox_override("panel",style)
	var icon:=ResourceItemIcon.new(); icon.custom_minimum_size=Vector2(100,72); preview.add_child(icon)
	var amount:=Label.new(); amount.text="× %d"%_drag_amount; amount.position=Vector2(102,73); amount.add_theme_font_size_override("font_size",18); amount.modulate=Color("f1d589"); preview.add_child(amount)
	set_drag_preview(preview)
	return {"resource_id":item_id,"amount":_drag_amount}

func _notification(what: int) -> void:
	if what!=NOTIFICATION_DRAG_END or _drag_amount<=0: return
	var amount:=_drag_amount; _drag_amount=0
	if get_viewport().gui_is_drag_successful() or not is_instance_valid(drop_boundary): return
	if not drop_boundary.get_global_rect().has_point(get_viewport().get_mouse_position()):
		drop_outside.emit(item_id,amount)
