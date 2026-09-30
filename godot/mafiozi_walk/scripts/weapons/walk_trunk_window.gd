extends Control
const WalkUI=preload("walk_weapon_ui.gd")
var host:Node
var panel:PanelContainer
var summary:Label
var grid:GridContainer
var scroll:ScrollContainer
var empty:Label
var feedback:Label
var held:Label
var store_button:Button
var gauge:ProgressBar
var cards:Dictionary={}
var _revision:=-1
var _last_size:=Vector2.ZERO
var _target_size:=Vector2.ZERO

func configure(cargo_host:Node)->void:
	host=cargo_host;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.48);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
	panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",WalkUI.panel_style("1d2429fc","ad956c",9));add_child(panel)
	var inset:=WalkUI.margins(20);panel.add_child(inset)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);inset.add_child(column)
	var top:=HBoxContainer.new();column.add_child(top)
	var copy:=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(copy)
	copy.add_child(WalkUI.label("Б А Г А Ж Н И К",23,"d8d1bd"));summary=WalkUI.label("",14,"b6c0c4");summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy.add_child(summary)
	var close:=Button.new();close.text="Закрыть  ×";close.custom_minimum_size=Vector2(112,42);close.pressed.connect(func():host.close_window());top.add_child(close)
	gauge=ProgressBar.new();gauge.show_percentage=false;gauge.custom_minimum_size.y=6;gauge.add_theme_stylebox_override("background",WalkUI.panel_style("303637","303637",2));gauge.add_theme_stylebox_override("fill",WalkUI.panel_style("aa9169","aa9169",2));column.add_child(gauge)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	var contents:=VBoxContainer.new();contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(contents)
	empty=WalkUI.label("В багажнике пока пусто.\nВозьмите оружие в руки и нажмите «Положить».",17,"aeb7bc");empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;empty.custom_minimum_size.y=150;empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;contents.add_child(empty)
	grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;contents.add_child(grid)
	var footer:=VBoxContainer.new();footer.add_theme_constant_override("separation",8);column.add_child(footer)
	held=WalkUI.label("",14,"d8d1bd");held.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;held.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(held)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);footer.add_child(actions)
	store_button=Button.new();store_button.text="G  Положить оружие";store_button.custom_minimum_size=Vector2(160,48);store_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;store_button.pressed.connect(func():host.window_store());actions.add_child(store_button)
	var shut:=Button.new();shut.text="Закрыть крышку";shut.custom_minimum_size=Vector2(160,48);shut.size_flags_horizontal=Control.SIZE_EXPAND_FILL;shut.pressed.connect(func():host.window_close_lid());actions.add_child(shut)
	feedback=WalkUI.label("",13,"d99b94");feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(feedback)
	var hint:=WalkUI.label("E / Q — закрыть окно     Esc — свободная мышь     Выберите «Взять» на нужной карточке",12,"aeb7bc");hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
	_layout()
func _process(_delta:float)->void:
	if visible:
		_layout()
		# Container minima settle after deferred sorts; retry only while the actual size differs.
		if panel.size!=_target_size:panel.size=_target_size
func _layout()->void:
	var area:=get_viewport_rect().size
	if area==_last_size:return
	_last_size=area
	var width:=minf(1000,maxf(400,area.x-48));var height:=minf(670,maxf(320,area.y-48))
	_target_size=Vector2(width,height)
	panel.position=(area-_target_size)*.5
	grid.columns=4 if width>=950 else (3 if width>=700 else 2)
	for entry:Dictionary in cards.values():entry.panel.custom_minimum_size.x=(width-66.0)/grid.columns-12.0
	# Update child minimum widths before requesting the smaller panel size.
	panel.size=_target_size
func present(snapshot:Dictionary,state:Dictionary,message:String="")->void:
	var used:=int(snapshot.used_units);var maximum:=int(snapshot.capacity_units)
	summary.text="Занято %d / %d · Свободно %d · Оружия: %d"%[used,maximum,maxi(0,maximum-used),snapshot.items.size()]
	gauge.max_value=maximum;gauge.value=used
	if _revision!=int(snapshot.revision):
		_revision=int(snapshot.revision)
		for child:Node in grid.get_children():grid.remove_child(child);child.queue_free()
		cards.clear()
		for entry:Dictionary in snapshot.items:
			var item:Dictionary=entry.item;var uid:String=item.uid;var id:String=item.weaponId
			var card:=PanelContainer.new();card.custom_minimum_size=Vector2(210,198);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",WalkUI.panel_style("252e35","4f595f",6));grid.add_child(card)
			var padding:=WalkUI.margins(12);card.add_child(padding);var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);padding.add_child(box)
			var picture:=WalkUI.picture(100);picture.texture=host.weapons._walk_ui.textures.get(id);box.add_child(picture)
			var name:=WalkUI.label(host.weapons.LABELS.get(id,id),16);name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(name)
			var ammo:=WalkUI.label("Патроны: %d / %d"%[int(item.fireState.magazine),int(item.fireState.reserveAmmo)],14,"b4bec4");ammo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(ammo)
			var take:=Button.new();take.text="Взять";take.custom_minimum_size.y=40;take.pressed.connect(Callable(host,"window_take").bind(uid));box.add_child(take)
			cards[uid]={"panel":card,"button":take,"ammo":ammo,"weapon_id":id}
		empty.visible=cards.is_empty();_last_size=Vector2.ZERO;_layout()
	var id:=str(state.get("weaponId","none"));var cost:=int(host.bridge.COSTS.get(id,0))
	held.text="В руках: %s"%host.weapons.LABELS.get(id,id)
	if id!="none":held.text+=" · %d / %d патронов · %d ед. места"%[int(state.magazine),int(state.reserveAmmo),cost]
	store_button.disabled=id=="none" or used+cost>maximum or bool(snapshot.pending)
	feedback.text=message;feedback.visible=not message.is_empty()
	for entry:Dictionary in cards.values():entry.button.disabled=bool(snapshot.pending)
