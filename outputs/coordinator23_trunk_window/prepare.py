from pathlib import Path
O=Path('outputs/coordinator23_trunk_window/files/scripts/weapons')
def rep(s,a,b):
 assert s.count(a)==1,(a[:90],s.count(a));return s.replace(a,b)
p=O/'preview_weapons.gd';s=p.read_text(encoding='utf8')
s=rep(s,'var menu_open := false','var menu_open := false\nvar cargo_menu_owner: Node')
s=rep(s,'func controls_blocked() -> bool:\n\treturn menu_open','func cargo_menu_active() -> bool:\n\treturn is_instance_valid(cargo_menu_owner) and cargo_menu_owner.window_open\n\nfunc controls_blocked() -> bool:\n\treturn menu_open or cargo_menu_active()')
s=rep(s,'func set_menu(open: bool) -> void:\n\tif open and not _interaction_allowed(): return','func set_menu(open: bool) -> void:\n\tif open and not _interaction_allowed(): return\n\tif open and cargo_menu_active(): cargo_menu_owner.close_window(false)')
s=rep(s,'func release_controls() -> void:\n\tcancel_inputs()','func release_controls() -> void:\n\tif cargo_menu_active(): cargo_menu_owner.close_window(false)\n\tcancel_inputs()')
s=rep(s,'func input_event(event: InputEvent) -> bool:\n\tif not _owner_current() or not player._free_mouse_look: return false','func input_event(event: InputEvent) -> bool:\n\tif cargo_menu_active(): return cargo_menu_owner.window_input(event)\n\tif not _owner_current() or not player._free_mouse_look: return false')
s=s.replace('if menu_open and event is InputEventKey and input_event(event):','if controls_blocked() and event is InputEventKey and input_event(event):')
s=rep(s,'\t\tif menu_open: set_menu(false)','\t\tif menu_open: set_menu(false)\n\t\tif cargo_menu_active(): cargo_menu_owner.close_window(false)')
s=rep(s,'var allowed: bool = _interaction_allowed() and not menu_open','var allowed: bool = _interaction_allowed() and not controls_blocked()')
p.write_text(s,encoding='utf8',newline='\n')
for n in ['walk_weapon_ui.gd','weapon_aim_camera.gd']:
 p=O/n;s=p.read_text(encoding='utf8').replace('not host.menu_open and not host.player._text_control_focused()','not host.controls_blocked() and not host.player._text_control_focused()');p.write_text(s,encoding='utf8',newline='\n')
p=O/'weapon_cargo_bridge.gd';s=p.read_text(encoding='utf8')
s=rep(s,'\treturn _open(evidence) and (evidence.aimed_trunk if action=="store" else not uid.is_empty() and evidence.aimed_item_uid==uid)','''\tif not _open(evidence):return false
	# Explicit near-open/modal selection is user intent, not a forged model ray.
	var mode:String=str(evidence.get("selection_mode","aim"))
	if mode=="trunk_window":
		if evidence.get("window_open")!=true or not evidence.get("window_epoch") is int or evidence.window_epoch<1:return false
		return action=="store" or (not uid.is_empty() and evidence.get("selected_item_uid")==uid)
	if mode=="near_open_trunk":return action=="store"
	return mode=="aim" and (evidence.aimed_trunk if action=="store" else not uid.is_empty() and evidence.aimed_item_uid==uid)''')
p.write_text(s,encoding='utf8',newline='\n')
p=O/'preview_weapon_cargo.gd';s=p.read_text(encoding='utf8')
s=rep(s,'const WalkCargoCard = preload("res://scripts/weapons/walk_cargo_card.gd")','''const WalkCargoCard = preload("res://scripts/weapons/walk_cargo_card.gd")
const TrunkWindow = preload("res://scripts/weapons/walk_trunk_window.gd")
var window_open:=false
var _window:Control
var _window_epoch:=0
var _window_selected_uid:=""
var _window_busy:=false
var _window_snapshot:Dictionary={}
var _window_revision:=-1''')
s=rep(s,'\t_hint=WalkCargoCard.new(); weapons._layer.add_child(_hint)','\t_hint=WalkCargoCard.new(); weapons._layer.add_child(_hint)\n\t_window=TrunkWindow.new();weapons._layer.add_child(_window);_window.configure(self)\n\tweapons.cargo_menu_owner=self')
s=rep(s,'\treturn {"revision":1,"sample":evidence.sample(),"target_open":bool(context.open),"interaction_allowed":_allowed() and bool(context.cargo_allowed),"aimed_trunk":bool(context.aimed_trunk),"aimed_item_uid":str(context.item_uid)}','''\tvar sample:Dictionary={"revision":1,"sample":evidence.sample(),"target_open":bool(context.open),"interaction_allowed":_allowed() and bool(context.cargo_allowed),"aimed_trunk":bool(context.aimed_trunk),"aimed_item_uid":str(context.item_uid)}
	if _window_access():
		sample.selection_mode="trunk_window" if window_open else "near_open_trunk"
		sample.window_open=window_open;sample.window_epoch=_window_epoch;sample.selected_item_uid=_window_selected_uid
	elif window_open:
		sample.interaction_allowed=false
	return sample''')
s=rep(s,'func _input(event: InputEvent) -> void:\n\tif not _allowed()', 'func _input(event: InputEvent) -> void:\n\tif window_open: return # Weapon host owns modal keys before transport/player shortcuts.\n\tif not _allowed()')
s=rep(s,'\tif key==KEY_G and context.near_trunk:','\tif key==KEY_E and context.near_trunk and context.open:\n\t\topen_window();get_viewport().set_input_as_handled();return\n\tif key==KEY_G and context.near_trunk:')
s=rep(s,'if context.cargo_allowed and context.open and context.aimed_trunk: store_held()','if _window_access(): store_held()')
s=rep(s,'\t_refresh=0\n\treturn result\n\nfunc _ground_reservations','\t_refresh=0\n\tif window_open: _refresh_window(true)\n\treturn result\n\nfunc _ground_reservations')
s=rep(s,'\tif not _ready_for_play: return\n\tif renderer.has_method','\tif not _ready_for_play: return\n\tif window_open and (not _allowed() or not transport.compartments.is_open("trunk")):close_window(false)\n\tif renderer.has_method')
s=rep(s,'\tif not _allowed(): return\n\tvar context:=aim_context()\n\tvar camera: Camera3D=weapons.player.get_preview_camera()','\tif not _allowed(): return\n\tif window_open:\n\t\tif not _window_access():close_window(false)\n\t\telse:_refresh_window()\n\t\treturn\n\tvar context:=aim_context()\n\tvar camera: Camera3D=weapons.player.get_preview_camera()')
a=s.index('\t\tvar actions: Array=[]',s.index('func _process('));b=s.index('\t\tif int(state.get("selected_cost",0))>0:',a)
s=s[:a]+'''\t\tvar actions:Array=[{"key":"E","label":"Открыть содержимое"}]
		if weapons.armed():actions.append({"key":"G","label":"Положить оружие"})
		transport.set_cargo_item_hint_focus(bool(context.cargo_allowed))
		var detail:String="Выберите оружие в окне багажника"
''' +s[b:]
s=rep(s,'func _exit_tree() -> void:\n\t_ready_for_play=false','func _exit_tree() -> void:\n\tclose_window(false)\n\tif is_instance_valid(weapons) and weapons.cargo_menu_owner==self:weapons.cargo_menu_owner=null\n\tif is_instance_valid(_window):_window.queue_free()\n\t_ready_for_play=false')
s+='''
## Explicit modal selection retains actual access/lid/body/ownership admission.
func _window_access()->bool:
	if not _allowed() or not _near_trunk_geometry() or transport._nearest_panel().get("kind")!="trunk" or not transport.compartments.is_open("trunk"):return false
	var sample:Dictionary=evidence.sample()
	if not sample.get("available",false) or not sample.get("has_floor",false) or float(sample.get("amount",0))<.85:return false
	var profile:Dictionary=transport.compartments.access_profile("trunk")
	var point:Vector3=transport.body.to_global(profile.position_local_m+profile.outward_local*.12)
	var ray:Dictionary=_ray_hit(weapons.player.global_position+Vector3.UP*.9,point,true)
	return ray.is_empty() or ray.position.distance_to(point)<.03

func _release_window_actions()->void:
	for action:StringName in [weapons.player.ACTION_LEFT,weapons.player.ACTION_RIGHT,weapons.player.ACTION_FORWARD,weapons.player.ACTION_BACK,weapons.player.ACTION_RUN,weapons.player.ACTION_JUMP]:
		if InputMap.has_action(action):Input.action_release(action)

func open_window()->bool:
	if window_open:return true
	if not _window_access():return false
	var state:Dictionary=cargo.snapshot(generation)
	if not state.get("ok",false) or state.destroyed or state.pending:return false
	weapons.cancel_inputs();weapons.set_menu(false);_release_window_actions()
	_window_epoch+=1;window_open=true;_window_selected_uid="";_window_revision=-1;_window.visible=true
	_clear_cargo_ui();transport.set_cargo_item_hint_focus(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_refresh_window(true);return true

func close_window(capture:bool=true)->void:
	if not window_open:return
	window_open=false;_window_epoch+=1;_window_selected_uid="";_window_snapshot.clear();_window_revision=-1
	if is_instance_valid(_window):_window.visible=false
	if is_instance_valid(transport):transport.set_cargo_item_hint_focus(false)
	if is_instance_valid(weapons):
		weapons.cancel_inputs();_release_window_actions()
		if capture and weapons._interaction_allowed():Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	_refresh=0

func window_input(event:InputEvent)->bool:
	if not window_open:return false
	if event is InputEventKey:
		_release_window_actions()
		if event.pressed and not event.echo:
			var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			if code in [KEY_E,KEY_Q]:close_window()
			elif code==KEY_ESCAPE:close_window(false);weapons.player.set_mouse_captured(false)
			elif code==KEY_G:window_store()
		return true
	return event is InputEventMouseButton or event is InputEventMouseMotion

func window_store()->Dictionary:
	if _window_busy or not window_open or not _window_access():return {"ok":false,"reason":"window_access"}
	_window_busy=true
	var result:Dictionary=store_held()
	_window_busy=false;_refresh_window(true);return result

func window_take(uid:String)->Dictionary:
	if _window_busy or not window_open or not _window_access():return {"ok":false,"reason":"window_access"}
	_window_busy=true;_window_selected_uid=uid
	var result:Dictionary=take_item(uid)
	_window_selected_uid="";_window_busy=false;_refresh_window(true);return result

func window_close_lid()->void:
	if not window_open or not _window_access():return
	close_window();transport.compartments.set_open("trunk",false)

func _refresh_window(force:bool=false)->void:
	if not window_open:return
	var summary:Dictionary=cargo.summary(generation)
	if not summary.get("ok",false) or summary.destroyed:close_window(false);return
	if force or _window_revision!=int(summary.revision):
		_window_snapshot=cargo.snapshot(generation)
		if not _window_snapshot.get("ok",false):close_window(false);return
		_window_revision=int(summary.revision)
	_window.present(_window_snapshot,weapons.fire_state,_feedback if _feedback_time>0 else "")
'''
p.write_text(s,encoding='utf8',newline='\n')
print('Wrote outputs-only modal UI, controller, input and explicit selection patches')
