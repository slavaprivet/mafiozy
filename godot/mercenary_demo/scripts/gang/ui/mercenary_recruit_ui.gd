extends Control
## Source recruitment dialog + hire/equip/dismiss roster consumer.
## SERVICES host exclusively owns residents, inventory, authority and persistence.
signal open_changed(open:bool)
signal action_result(kind:String,id:String,result:Dictionary)
var presentation:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/gang/ui/data/presentation.json"))
var _host:Object
var _options:Dictionary={}
var _disposed=false
var _pending=false
var _dialog_id=""
var _member_mode=false
var _asked=false
var _clock=0.0
var _last_roster=-INF
var _last_dialog=-INF
var _generation=0
var _roster:Dictionary={"members":[],"candidates":[],"weapons":[]}
var _cards:Dictionary={}
var _previous_focus:WeakRef
var dialog:PanelContainer
var panel:PanelContainer
var dialog_name:Label
var subtitle:Label
var answer:Label
var status:Label
var panel_status:Label
var wallet:Label
var ask:Button
var hire:Button
var leave:Button
var members:VBoxContainer
var candidates:VBoxContainer
var _open_state=false
var _conversation_id=""
var notice:Label
var _notice_until=0.0

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	_build()

func configure(host:Object,options:Dictionary={})->Dictionary:
	if _disposed or _host!=null or not is_instance_valid(host):return {"ok":false,"reason":"ui_lifecycle"}
	for method:String in ["get_roster","recruit","equip","dismiss"]:
		if not host.has_method(method):return {"ok":false,"reason":"host_api:"+method}
	_host=host;_options=options.duplicate();refresh(true)
	return {"ok":true}

func _call_option(name:String,args:Array=[],fallback:Variant=null)->Variant:
	var cb:Callable=_options.get(name,Callable())
	return cb.callv(args) if cb.is_valid() else fallback

func _transport_interaction()->bool:
	# The shared transport owner reserves E BEFORE changing seat state and
	# keeps it reserved until release. UI never maintains a second press latch.
	return _call_option("is_transport_interaction",[],false)==true

func release_transport_controls()->void:
	# Public focus-loss hook: there is no local held/reserved state to reset.
	# Only the authoritative transport owner releases its E reservation.
	pass

func _interrupt_for_transport()->void:
	if _disposed:return
	var focus:Control=get_viewport().gui_get_focus_owner()
	var owns_focus:bool=focus!=null and (focus==self or is_ancestor_of(focus))
	if not _open_state and not owns_focus:return
	# Interrupt rather than restoring an old UI focus over the vehicle exit.
	_previous_focus=null
	for card:Dictionary in _cards.values():
		var selector:OptionButton=card.weapon
		if is_instance_valid(selector):selector.get_popup().hide()
	close_dialog();close_roster()
	if owns_focus and is_instance_valid(focus):focus.release_focus()

func _input(event:InputEvent)->void:
	if _disposed or not event is InputEventKey:return
	if event.physical_keycode!=KEY_E and event.keycode!=KEY_E:return
	if _transport_interaction():_interrupt_for_transport()
	# Down, echo and release must reach the authoritative vehicle controller.

func _label(text:String="",size_px:int=14)->Label:
	var label=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size_px);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func _button(text:String,cb:Callable)->Button:
	var button=Button.new();button.text=text;button.pressed.connect(cb);button.mouse_filter=Control.MOUSE_FILTER_STOP
	return button

func _style(bg:String,border:String,padding:int)->StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=Color(bg);box.border_color=Color(border);box.set_border_width_all(1);box.set_corner_radius_all(5);box.content_margin_left=padding;box.content_margin_right=padding;box.content_margin_top=padding;box.content_margin_bottom=padding;return box

func _dialog_style()->StyleBoxTexture:
	var image=Image.create(650,256,false,Image.FORMAT_RGBA8)
	for x:int in 650:
		var t:float=float(x)/649.0;var color:Color=Color("141516e8").lerp(Color("292324f5"),t*2.0) if t<=.5 else Color("292324f5").lerp(Color("141516e8"),(t-.5)*2.0)
		for y:int in 256:image.set_pixel(x,y,Color("ba9a59") if y==0 or y==255 else color)
	var style=StyleBoxTexture.new();style.texture=ImageTexture.create_from_image(image);style.texture_margin_top=1;style.texture_margin_bottom=1;style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=18;style.content_margin_bottom=18;return style

func _build()->void:
	var theme=Theme.new();theme.set_color("font_color","Label",Color("f1e6c4"));theme.set_color("font_color","Button",Color("edcf82"))
	var font=SystemFont.new();font.font_names=PackedStringArray(["Segoe UI","sans-serif"]);theme.default_font=font
	theme.set_stylebox("normal","Button",_style("302b2b","8d7953",8));theme.set_stylebox("hover","Button",_style("593842","8b754b",8));self.theme=theme
	dialog=PanelContainer.new();dialog.name="RecruitConversation";dialog.add_theme_stylebox_override("panel",_dialog_style());dialog.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(dialog)
	var column=VBoxContainer.new();dialog.add_child(column)
	dialog_name=_label("",23);dialog_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(dialog_name)
	var serif=SystemFont.new();serif.font_names=PackedStringArray(["Georgia","serif"]);serif.font_weight=700;dialog_name.add_theme_font_override("font",serif)
	subtitle=_label("",12);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.modulate=Color("cabd99");column.add_child(subtitle)
	answer=_label();answer.custom_minimum_size.y=40;answer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(answer)
	var buttons=HBoxContainer.new();buttons.alignment=BoxContainer.ALIGNMENT_CENTER;column.add_child(buttons)
	ask=_button("Что ты умеешь?",func():_asked=true;refresh(true));buttons.add_child(ask)
	hire=_button("Нанять",_dialog_action);buttons.add_child(hire)
	leave=_button("Не сейчас",close_dialog);buttons.add_child(leave)
	for button:Button in [ask,hire,leave]:
		button.add_theme_font_override("font",serif);button.add_theme_font_size_override("font_size",14);button.add_theme_stylebox_override("normal",_style("00000000","8b754b",9));button.add_theme_stylebox_override("focus",_style("00000000","edcf82",9))
	status=_label("",12);status.modulate=Color("e9a99e");column.add_child(status)
	dialog.hide()
	panel=PanelContainer.new();panel.name="SquadPanel";panel.add_theme_stylebox_override("panel",_style("151b1efc","a68a59",12));panel.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(panel)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var roster_column=VBoxContainer.new();roster_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(roster_column)
	var heading=HBoxContainer.new();roster_column.add_child(heading);var title=_label("Мой отряд",19);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title);heading.add_child(_button("×",close_roster))
	wallet=_label("",12);roster_column.add_child(wallet)
	roster_column.add_child(_label("Бойцы отряда",12));members=VBoxContainer.new();roster_column.add_child(members)
	roster_column.add_child(_label("Нанять специалиста",12));candidates=VBoxContainer.new();roster_column.add_child(candidates)
	panel_status=_label("",12);panel_status.modulate=Color("efce8e");roster_column.add_child(panel_status);panel.hide()
	notice=_label("",12);notice.custom_minimum_size.x=230;notice.modulate=Color("efce8e");notice.hide();add_child(notice)
	resized.connect(_layout);_layout()

func _layout()->void:
	if dialog==null:return
	var viewport_size:Vector2=get_viewport_rect().size
	dialog.size.x=minf(650,viewport_size.x-36);dialog.size.y=0
	dialog.position=Vector2((viewport_size.x-dialog.size.x)*.5,viewport_size.y*.92-dialog.get_combined_minimum_size().y)
	panel.size=Vector2(minf(350,viewport_size.x-36),maxf(120,viewport_size.y-330));panel.position=Vector2(viewport_size.x-panel.size.x-18,minf(280,viewport_size.y*.4))
	if notice!=null:notice.position=Vector2(viewport_size.x-246,viewport_size.y-300)

func _profession(id:String)->Dictionary:
	return presentation.professions.get("electrician" if id=="engineer" else id,{"label":id,"description":""})

func _person(id:String,member:bool)->Dictionary:
	for row:Dictionary in _roster.get("members" if member else "candidates",[]):
		if str(row.get("id",""))==id:return row
	return {}

func _alive(row:Dictionary)->bool:
	return not row.is_empty() and not row.get("dead",false) and not row.get("downed",false) and float(row.get("hp",1))>0

func _available(row:Dictionary,member:bool)->bool:
	return _alive(row) and row.get("canDismiss" if member else "canRecruit",true)!=false and str(row.get("disabledReason",""))=="" and float(row.get("distanceMeters",0))<=(2.5 if member else 3.0)

func _read_roster()->void:
	if not is_instance_valid(_host):_roster={"members":[],"candidates":[],"weapons":[]};return
	var value:Variant=_host.call("get_roster")
	_roster=value if value is Dictionary else {"members":[],"candidates":[],"weapons":[]}

func refresh(force:bool=false)->void:
	if _disposed or dialog==null:return
	if force or _clock-_last_roster>=.1:
		_last_roster=_clock;_read_roster()
		if panel.visible:_refresh_cards()
	if dialog.visible and (force or _clock-_last_dialog>=.3):
		_last_dialog=_clock;var row:Dictionary=_person(_dialog_id,_member_mode)
		if row.is_empty() or row.get("dead",false) or float(row.get("hp",1))<=0:close_dialog();return
		var profession:Dictionary=_profession(str(row.get("profession","")))
		dialog_name.text=str(row.get("name","")) if str(row.get("name",""))!="" else str(profession.label);var weapon:Variant=row.get("weaponLabel",row.get("weaponId",""))
		subtitle.text=str(profession.label)+(" · "+("Пистолет" if str(weapon)=="pistol" else str(weapon)) if str(weapon)!="" else "")
		var speech:Array=presentation.speech.get("electrician" if row.get("profession")=="engineer" else str(row.get("profession","")),["Есть работа? Давай поговорим.","Расскажу, чем могу быть полезен вашему отряду."])
		answer.text="Я с тобой. Что нужно?" if _member_mode and not _asked else speech[1 if _asked else 0]
		hire.text="Уволить бойца" if _member_mode else "Нанять";leave.text="Продолжить" if _member_mode else "Не сейчас"
		hire.tooltip_text="Выданное вами оружие вернётся в инвентарь" if _member_mode else ""
		hire.disabled=_pending or not _available(row,_member_mode);ask.disabled=_pending
		if not _available(row,_member_mode):status.text=str(row.get("disabledReason","Подойдите ближе к собеседнику."))
	_layout()

func open_dialog(id:String,member:bool=false)->bool:
	if _disposed:return false
	if _transport_interaction():_interrupt_for_transport();return false
	if _pending or not is_instance_valid(_host):return false
	_read_roster()
	if not _available(_person(id,member),member):return false
	# Host conversation holds are keyed by ID, not reference-counted. Reopening
	# the same hold must not begin it again and then release it via close_dialog.
	if dialog.visible and _dialog_id==id and _conversation_id==id and _member_mode==member:
		refresh(true);return true
	# Validate the next target before releasing the old hold; on a valid switch,
	# end the old conversation before attempting the real new begin callback.
	if dialog.visible:close_dialog()
	var receipt:Variant=_call_option("begin_conversation",[id],{"ok":true})
	if (receipt is bool and not receipt) or (receipt is Dictionary and receipt.get("ok") is bool and not receipt.ok):show_notice(str(receipt.get("message",receipt.get("reason","Разговор сейчас недоступен."))) if receipt is Dictionary else "Разговор сейчас недоступен.");return false
	_conversation_id=id
	_save_focus();_dialog_id=id;_member_mode=member;_asked=false;status.text="";_generation+=1;dialog.show();refresh(true);_sync_open();ask.grab_focus();return true

func close_dialog()->void:
	if dialog==null or not dialog.visible:return
	dialog.hide();_dialog_id="";_generation+=1;_sync_open();_restore_focus()
	if _conversation_id!="":_call_option("end_conversation",[_conversation_id]);_conversation_id=""

func show_notice(message:String)->void:
	if _disposed or notice==null:return
	notice.text=message;notice.visible=message!="";_notice_until=_clock+2.5

func open_roster()->bool:
	if _disposed:return false
	if _transport_interaction():_interrupt_for_transport();return false
	if _call_option("is_blocked",[],false):return false
	_save_focus();panel.show();panel_status.text="";refresh(true);_sync_open();return true

func close_roster()->void:
	if panel==null:return
	panel.hide();_sync_open();_restore_focus()

func open_candidate(id:String)->bool:
	return open_dialog(id,false)

func open_member(id:String)->bool:
	return open_dialog(id,true)

func close()->void:
	close_dialog();close_roster()

func is_open()->bool:
	return _open_state

func _save_focus()->void:
	if not _open_state:_previous_focus=weakref(get_viewport().gui_get_focus_owner())

func _restore_focus()->void:
	if _open_state or _previous_focus==null:return
	var node:Variant=_previous_focus.get_ref()
	if is_instance_valid(node) and node is Control and node.is_visible_in_tree():node.grab_focus()
	_previous_focus=null

func _sync_open()->void:
	var now_open:bool=dialog.visible or panel.visible
	if now_open!=_open_state:_open_state=now_open;open_changed.emit(now_open);_call_option("on_open_change",[now_open])

func _dialog_action()->void:
	_read_roster()
	if _pending or not _available(_person(_dialog_id,_member_mode),_member_mode):refresh(true);return
	_request("dismiss" if _member_mode else "recruit",_dialog_id,"",true)

func _request(kind:String,id:String,argument:String="",conversation:bool=false)->void:
	if _disposed or _pending or not is_instance_valid(_host):return
	_pending=true;var generation:int=_generation;refresh(true)
	var args:Array=[id] if kind=="dismiss" else [id,argument]
	var value:Variant=await _host.callv(kind,args)
	if _disposed:return
	# Preserve source Promise completion ordering for synchronous native hosts.
	await get_tree().process_frame
	if _disposed:return
	var result:Dictionary=value if value is Dictionary else {"ok":false,"reason":"invalid_host_receipt"}
	var accepted:bool=result.get("ok") is bool and result.ok
	_pending=false;action_result.emit(kind,id,result)
	var text:String=str(result.get("message",result.get("reason","Приказ принят." if accepted else "Действие сейчас недоступно.")))
	if conversation:
		if generation==_generation and dialog.visible and _dialog_id==id:
			if accepted:close_dialog()
			else:status.text=text
	elif panel.visible:panel_status.text=text
	refresh(true)

func request_action(kind:String,id:String,argument:String="")->bool:
	if _disposed or _pending or kind not in ["recruit","equip","dismiss"]:return false
	_request(kind,id,argument,false);return true

func _create_card(id:String,candidate:bool)->Dictionary:
	var box=PanelContainer.new();box.add_theme_stylebox_override("panel",_style("28282bcc","75664e",8));var column=VBoxContainer.new();box.add_child(column)
	var card:Dictionary={"node":box,"candidate":candidate,"name":_label(),"detail":_label(),"description":_label("",11),"reason":_label("",11),"weapon":OptionButton.new(),"signature":"","row":{}}
	for key:String in ["name","detail","description"]:column.add_child(card[key])
	column.add_child(card.weapon);var buttons=HBoxContainer.new();column.add_child(buttons)
	card.primary=_button("Нанять" if candidate else "Выдать оружие",func():
		var weapon:String=str(card.weapon.get_item_metadata(card.weapon.selected)) if card.weapon.selected>=0 else ""
		_request("recruit" if candidate else "equip",id,weapon))
	buttons.add_child(card.primary)
	if not candidate:
		card.dismiss=_button("Уволить",func():_request("dismiss",id));card.dismiss.tooltip_text="Выданное оружие вернётся в инвентарь";buttons.add_child(card.dismiss)
	column.add_child(card.reason);(candidates if candidate else members).add_child(box)
	return card

func _refresh_cards()->void:
	var member_rows:Array=_roster.get("members",[]);var candidate_rows:Array=_roster.get("candidates",[])
	wallet.text=str(member_rows.size())+("/"+str(_roster.capacity) if _roster.has("capacity") else "")+" в отряде"+(" · $"+str(_roster.cash) if _roster.has("cash") else "")
	var seen:Dictionary={};var weapons:Array=[]
	for weapon:Dictionary in _roster.get("weapons",[]):
		if weapon.has("id") and float(weapon.get("count",weapon.get("qty",1)))>0:weapons.append(weapon)
	for candidate:bool in [false,true]:
		for row:Dictionary in candidate_rows if candidate else member_rows:
			var id:String=str(row.get("id",""));if id=="":continue
			var key:String=("candidate:" if candidate else "member:")+id;seen[key]=true
			if not _cards.has(key):_cards[key]=_create_card(id,candidate)
			var card:Dictionary=_cards[key];card.row=row;var profession:Dictionary=_profession(str(row.get("profession","")))
			card.name.text=str(row.get("name",profession.label));card.description.text=profession.description
			card.detail.text=str(profession.label)+(" · ур. "+str(row.level) if row.has("level") else "")+(" · HP "+str(row.hp)+"/"+str(row.maxHp) if row.has("hp") and row.has("maxHp") else "")+(" · "+str(row.weaponLabel) if row.has("weaponLabel") else "")
			var items:Array=[{"id":"","label":"Без выдачи оружия"}]+weapons
			var signature:String=JSON.stringify(items)
			if signature!=card.signature:
				var chosen:String=str(card.weapon.get_item_metadata(card.weapon.selected)) if card.weapon.selected>=0 else ""
				card.weapon.clear();var choice:int=0
				for index:int in items.size():
					card.weapon.add_item(str(items[index].get("label",items[index].id)));card.weapon.set_item_metadata(index,str(items[index].id))
					if str(items[index].id)==chosen:choice=index
				if items.size()>0:card.weapon.select(choice)
				card.signature=signature
			var hospital:bool=row.get("status","")=="hospital" or row.get("phase","")=="hospital" or row.get("hospital",false)
			card.weapon.visible=not weapons.is_empty();card.weapon.disabled=_pending or hospital
			var selected_weapon:String=str(card.weapon.get_item_metadata(card.weapon.selected)) if card.weapon.selected>=0 else ""
			card.primary.visible=candidate or not weapons.is_empty()
			card.primary.disabled=_pending or hospital or not _alive(row) or row.get("canRecruit" if candidate else "canEquip",true)==false or str(row.get("disabledReason",""))!="" or (not candidate and selected_weapon=="")
			if not candidate:card.dismiss.disabled=_pending or row.get("canDismiss",true)==false
			card.reason.text=str(row.get("disabledReason",""));card.reason.visible=card.reason.text!=""
	for key:String in _cards.keys():
		if not seen.has(key):_cards[key].node.queue_free();_cards.erase(key)

func blocks_world_input()->bool:
	if _transport_interaction():return false
	return _open_state or _text_focus()

func _text_focus()->bool:
	var focus:Control=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or focus is OptionButton

func _unhandled_key_input(event:InputEvent)->void:
	if _transport_interaction():_interrupt_for_transport();return
	if _disposed or not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or _text_focus():return
	if event.keycode==KEY_ESCAPE and _open_state:
		close_dialog();close_roster();get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_E and not _open_state and not _call_option("is_blocked",[],false) and not _call_option("has_priority_interaction",[true],false):
		var target:Variant=_call_option("get_talk_target")
		if target is Dictionary and open_dialog(str(target.get("id","")),target.get("member",false)):get_viewport().set_input_as_handled()

func _process(delta:float)->void:
	_clock+=maxf(0,delta)
	if _transport_interaction():_interrupt_for_transport()
	if notice!=null and notice.visible and _clock>=_notice_until:notice.hide()
	if _open_state:refresh()

func hud_rects()->Array:
	var result:Array=[]
	for node:Control in [dialog,panel]:
		if node!=null and node.visible:result.append(node.get_global_rect())
	return result

func dispose()->void:
	if _disposed:return
	close_dialog();close_roster();hide();_disposed=true;_pending=false;_generation+=1;_host=null;_options.clear();set_process(false);set_process_input(false);set_process_unhandled_key_input(false)

func _exit_tree()->void:
	dispose()
