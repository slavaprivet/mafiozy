extends Control
## Source mercenary_badges.mjs presentation only. No roster or actor owner.
var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/gang/ui/data/presentation.json"))
var camera:Camera3D
var options:Dictionary={}
var cards:Dictionary={}
var ring:MeshInstance3D
var _clock:float=0.0
var _last_registry:float=-INF
var _last_occlusion:float=-INF
var _last_hud:float=-INF
var _hud_rects:Array=[]
var _head_cache:Dictionary={}
var _actors:Array=[]
var _disposed=false
var selected_id:Variant=null
var raycasts:int=0
var aim_only:bool=true
var distance:float=12.0

func configure(view:Camera3D,providers:Dictionary,world:Node3D=null)->Dictionary:
	if _disposed or camera!=null or not is_instance_valid(view):return {"ok":false,"reason":"badge_lifecycle"}
	for provider:String in ["get_actors","occluded"]:
		if not providers.get(provider,Callable()).is_valid():return {"ok":false,"reason":"provider:"+provider}
	camera=view;options=providers.duplicate();aim_only=providers.get("aim_only",true);distance=providers.get("distance",12.0)
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if world!=null:_create_ring(world)
	return {"ok":true}

func _call(name:String,args:Array=[],fallback:Variant=null)->Variant:
	var cb:Callable=options.get(name,Callable());return cb.callv(args) if cb.is_valid() else fallback

func _source(actor:Dictionary)->Dictionary:
	return actor.get("source",{})

func _owned(source:Dictionary)->bool:
	return str(source.get("mercenary",{}).get("status",""))!="" and not source.get("mercenaryCandidate",false)

func _afraid(source:Dictionary)->bool:
	var expires:float=float(source.get("fearExpiresAt",0))
	return source.get("fearActive") is bool and source.fearActive and is_finite(expires) and expires>float(_call("wall_clock_ms",[],Time.get_unix_time_from_system()*1000.0)) and not source.get("dead",false) and not source.get("deathConfirmed",false) and not source.get("downed",false) and float(source.get("hp",1))>0

func _hidden(source:Dictionary)->bool:
	return (_call("hide_owned",[],false) and _owned(source)) or source.get("mercenary",{}).get("status","")=="hospital" or source.get("status","")=="hospital" or source.get("deathConfirmed",false) or source.get("lifeState","")=="dead" or (source.get("dead",false) and not source.get("downed",false))

func _visible(object:Variant)->bool:
	return is_instance_valid(object) and object is Node3D and object.is_inside_tree() and object.is_visible_in_tree()

func _role(source:Dictionary)->String:
	if source.has("mercenary"):return "Наёмник"
	var role:String=str(source.get("role",source.get("visualRole","")))
	if source.get("police",false) or "police" in role or "cop" in role:return "Полицейский"
	if source.get("empireBoss",source.get("_empireBoss",false)) or "boss" in role:return "Босс"
	if source.get("guard",source.get("_guard",false)) or "guard" in role:return "Охранник"
	if source.get("gang",false) or "gang_fighter" in role or "bandit" in role:return "Бандит"
	return "Гражданский"

func _bounds(object:Node3D)->AABB:
	var result=AABB();var found:bool=false
	var meshes:Array=object.find_children("*","MeshInstance3D",true,false)
	if object is MeshInstance3D:meshes.append(object)
	for mesh:MeshInstance3D in meshes:
		if mesh.mesh==null:continue
		var box:AABB=mesh.global_transform*mesh.get_aabb()
		result=result.merge(box) if found else box;found=true
	return result

func _head(object:Node3D,source:Dictionary)->Vector3:
	var provided:Variant=_call("get_head",[object,source])
	if provided is Vector3 and provided.is_finite():return provided
	var id:int=object.get_instance_id()
	if not _head_cache.has(id) or _head_cache[id].object.get_ref()!=object:
		var head:Variant=null;var skeleton:Skeleton3D=null;var bone:int=-1
		for sk:Skeleton3D in object.find_children("*","Skeleton3D",true,false):
			for i:int in sk.get_bone_count():
				var name:String=sk.get_bone_name(i).to_lower()
				if name.ends_with("head") or "head_" in name or "head." in name or "head " in name:skeleton=sk;bone=i;break
			if bone>=0:break
		if bone<0:head=object.find_child("Head",true,false)
		var box:AABB=_bounds(object);var offset:float=float(source.get("height",1.9))+.2
		if offset<=1.2 or offset>=3.2:offset=2.1
		if box.size.y>.5:offset=box.end.y-object.global_position.y+.2
		var margin:float=.4
		if skeleton!=null or head is Node3D:
			var hp:Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin if skeleton!=null else head.global_position
			if box.size.y>0:margin=clampf(box.end.y-hp.y+.12,.4,.9)
		_head_cache[id]={"object":weakref(object),"head":weakref(head) if head!=null else null,"skeleton":weakref(skeleton) if skeleton!=null else null,"bone":bone,"offset":offset,"margin":margin}
	var cache:Dictionary=_head_cache[id]
	if cache.skeleton!=null:
		var skeleton:Skeleton3D=cache.skeleton.get_ref()
		if is_instance_valid(skeleton):return skeleton.global_transform*skeleton.get_bone_global_pose(cache.bone).origin+Vector3.UP*cache.margin
	if cache.head!=null:
		var head:Node3D=cache.head.get_ref()
		if is_instance_valid(head):return head.global_position+Vector3.UP*cache.margin
	return object.global_position+Vector3.UP*cache.offset

func _ndc(point:Vector3)->Vector2:
	var pixel:Vector2=camera.unproject_position(point);var viewport_size:Vector2=get_viewport_rect().size
	return Vector2(pixel.x/viewport_size.x*2.0-1.0,1.0-pixel.y/viewport_size.y*2.0)

func _depth_ok(point:Vector3)->bool:
	var depth:float=-camera.to_local(point).z
	return depth>=camera.near and depth<=camera.far

func _aim(actor:Dictionary)->float:
	var object:Variant=actor.get("object");var source:Dictionary=_source(actor)
	if not _visible(object) or _hidden(source) or source.get("dead",false) or source.get("downed",false) or float(source.get("hp",1))<=0:return INF
	var focus:Variant=_call("get_focus");var origin:Vector3=focus if focus is Vector3 else camera.global_position
	if object.global_position.distance_to(origin)>distance:return INF
	var head:Vector3=_head(object,source)-Vector3.UP*.3;var torso:Vector3=object.global_position;torso.y+=(head.y-torso.y)*.55
	if not _depth_ok(head) or not _depth_ok(torso):return INF
	var a:Vector2=_ndc(head);var b:Vector2=_ndc(torso);var delta:Vector2=a-b
	var t:float=clampf(-b.dot(delta)/delta.length_squared(),0,1) if delta.length_squared()>0 else 0.0
	var score:float=(b+t*delta).length_squared();return score if score<=.18*.18 else INF

func _label(text:String,size_px:int)->Label:
	var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",size_px);var font=SystemFont.new();font.font_names=PackedStringArray(["Segoe UI","sans-serif"]);node.add_theme_font_override("font",font);node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;return node

func _card(id:String,profession:String)->Dictionary:
	var node=PanelContainer.new();node.name="Badge_"+id;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(node)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",1);node.add_child(column)
	var role:Label=_label("",11);var name_label:Label=_label("",12);var row=HBoxContainer.new();row.add_theme_constant_override("separation",5)
	var icon=TextureRect.new();icon.custom_minimum_size=Vector2(18,18);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if profession!="":icon.texture=load("res://scripts/gang/ui/icons/"+profession+".svg")
	var label:Label=_label(data.badgeProfessions.get(profession,[""])[0],14)
	row.add_child(icon);row.add_child(label);var fear:Label=_label("Страх",12)
	for child:Control in [role,name_label,row,fear]:column.add_child(child)
	# A sibling overlay avoids PanelContainer arranging the absolute source hint.
	var talk:Label=_label("Поговорить — E",13);talk.name="Talk_"+id;talk.custom_minimum_size.x=130
	var talk_font:SystemFont=SystemFont.new();talk_font.font_names=PackedStringArray(["Segoe UI","sans-serif"]);talk_font.font_weight=700;talk.add_theme_font_override("font",talk_font)
	talk.add_theme_color_override("font_color",Color("ffe6a1"));talk.add_theme_color_override("font_shadow_color",Color("000000"));talk.add_theme_constant_override("shadow_offset_x",0);talk.add_theme_constant_override("shadow_offset_y",1)
	var talk_style:StyleBoxFlat=StyleBoxFlat.new();talk_style.bg_color=Color("201a1ad9");talk_style.set_corner_radius_all(4);talk_style.content_margin_left=8;talk_style.content_margin_right=8;talk_style.content_margin_top=3;talk_style.content_margin_bottom=3;talk.add_theme_stylebox_override("normal",talk_style)
	add_child(talk);talk.hide()
	var record:Dictionary={"id":id,"node":node,"role":role,"name":name_label,"label":label,"icon":icon,"fear":fear,"talk":talk,"talk_active":false,"profession":profession,"object":null,"source":{},"occluded":true,"checked":-INF,"fear_only":false,"owned":false}
	node.hide();return record

func _drop_card(id:String)->void:
	var record:Dictionary=cards[id]
	record.node.hide();record.talk.hide();record.node.queue_free();record.talk.queue_free();cards.erase(id)

func _update_card(record:Dictionary,actor:Dictionary,feared:bool)->void:
	var source:Dictionary=_source(actor);var owned:bool=_owned(source);record.source=source;record.owned=owned;record.fear_only=feared and not owned
	var bg:String="452c24ec" if record.fear_only else "153c29ed" if owned else "302029e8"
	var border:String="c69369" if record.fear_only else "82dca1" if owned else "e2c17d"
	# Style instances change only when the state changes.
	if record.get("style_key","")!=bg:
		var box=StyleBoxFlat.new();box.bg_color=Color(bg);box.border_color=Color(border);box.set_border_width_all(1);box.set_corner_radius_all(6);box.content_margin_left=7;box.content_margin_right=7;box.content_margin_top=3;box.content_margin_bottom=3
		record.node.add_theme_stylebox_override("panel",box);record.style_key=bg
	var color=Color("b6f4cb" if owned else "f5db9a")
	for key:String in ["label","name","icon"]:record[key].modulate=color
	record.role.text="МОЯ БАНДА" if owned else _role(source);record.role.modulate=Color("a4efbb" if owned else "f1dfb6")
	record.role.visible=not record.fear_only and (record.profession!="" or owned)
	var person_name:String=str(actor.get("name",""))
	if person_name=="":person_name=str(source.get("name",""))
	record.name.text=person_name if person_name!="" else "Боец";record.name.visible=owned and not record.fear_only
	record.label.visible=not record.fear_only;record.icon.visible=record.profession!="" and not record.fear_only;record.fear.visible=feared
	if record.profession=="":record.label.text=_role(source)
	var talk:Variant=_call("get_talk_id");var raw:String=str(talk).trim_prefix("npc:") if talk!=null else ""
	record.talk_active=not record.fear_only and raw!="" and (str(actor.id)==raw or str(actor.id)=="npc_"+raw or str(source.get("id",""))==raw)
	if record.object==null or record.object.get_ref()!=actor.object:record.object=weakref(actor.object);record.checked=-INF;record.occluded=true

func advance(delta:float)->void:
	if _disposed or not is_instance_valid(camera):return
	if not is_finite(delta):delta=0.0
	_clock+=clampf(delta,0,1)
	if _clock-_last_registry>=1.0/30.0:
		_last_registry=_clock;_actors=_call("get_actors",[],[])
		var selected:Variant=null;var best:float=INF if aim_only else 3.5
		var focus:Variant=_call("get_focus");var requested:Variant=_call("get_selected_id")
		for actor:Dictionary in _actors:
			if not actor.has("id") or not _visible(actor.get("object")):continue
			var source:Dictionary=_source(actor)
			if _hidden(source) or source.get("dead",false) or source.get("downed",false) or float(source.get("hp",1))<=0:continue
			var score:float=_aim(actor) if aim_only else Vector2(actor.object.global_position.x-focus.x,actor.object.global_position.z-focus.z).length() if focus is Vector3 else INF
			if score<best or (not aim_only and score<=best):selected=actor;best=score
			if not aim_only and requested!=null and str(actor.id)==str(requested) and score<=3.5:selected=actor;break
		selected_id=selected.id if selected is Dictionary else null
		var frightened:Array=[]
		for actor:Dictionary in _actors:
			if _afraid(_source(actor)) and _visible(actor.get("object")) and actor.object.global_position.distance_squared_to(camera.global_position)<=1024:frightened.append(actor)
		frightened.sort_custom(func(a:Dictionary,b:Dictionary):return a.object.global_position.distance_squared_to(camera.global_position)<b.object.global_position.distance_squared_to(camera.global_position))
		if frightened.size()>12:frightened.resize(12)
		if selected is Dictionary and _afraid(_source(selected)) and selected not in frightened:
			if frightened.size()==12:frightened.pop_back()
			frightened.append(selected)
		var seen:Dictionary={};var next:Variant=null;var actor_nodes:Array=[]
		for actor:Dictionary in _actors:
			if _visible(actor.get("object")):actor_nodes.append(actor.object)
		for actor:Dictionary in _actors:
			if not actor.has("id") or not _visible(actor.get("object")):continue
			var source:Dictionary=_source(actor);var profession:String=str(source.get("mercenary",{}).get("profession",""));if profession=="electrician":profession="engineer"
			var specialist:bool=data.badgeProfessions.has(profession);var feared:bool=actor in frightened
			if (aim_only and actor!=selected and not _owned(source) and not feared) or (not aim_only and not specialist and actor!=selected and not _owned(source) and not feared):continue
			var id:String=str(actor.id);if seen.has(id):continue
			seen[id]=true;profession=profession if specialist else ""
			if cards.has(id) and cards[id].profession!=profession:_drop_card(id)
			if not cards.has(id):cards[id]=_card(id,profession)
			var record:Dictionary=cards[id];_update_card(record,actor,feared)
			if _hidden(source):continue
			var head:Vector3=_head(actor.object,source)
			if head.distance_to(camera.global_position)>32 or not _depth_ok(head):continue
			if next==null or record.checked<next.record.checked:next={"record":record,"head":head}
		if next!=null and _clock-_last_occlusion>=.1:
			_last_occlusion=_clock;raycasts+=1;next.record.checked=_clock
			next.record.occluded=_call("occluded",[camera.global_position,next.head,actor_nodes],true)
		for id:String in cards.keys():
			if not seen.has(id):_drop_card(id)
		for id:int in _head_cache.keys():
			if not is_instance_valid(_head_cache[id].object.get_ref()):_head_cache.erase(id)
	_refresh_screen()

func _refresh_screen()->void:
	var viewport_size:Vector2=get_viewport_rect().size
	# The owner clears cached talk selection immediately when transport owns E.
	var talk:Variant=_call("get_talk_id");var raw_talk:String=str(talk).trim_prefix("npc:") if talk!=null else ""
	if _clock-_last_hud>=.2:_last_hud=_clock;_hud_rects=_call("get_hud_rects",[],[])
	for id:String in cards:
		var record:Dictionary=cards[id];var object:Variant=record.object.get_ref();var source:Dictionary=record.source
		var talk_visible:bool=record.talk_active and raw_talk!="" and (id==raw_talk or id=="npc_"+raw_talk or str(source.get("id",""))==raw_talk)
		var show:bool=_visible(object) and not _hidden(source) and not record.occluded and (not record.fear_only or _afraid(source))
		if show:
			var actor:Dictionary={"id":id,"object":object,"source":source}
			var head:Vector3=_head(object,source);var pixel:Vector2=camera.unproject_position(head)
			show=_depth_ok(head) and head.distance_to(camera.global_position)<=32 and (not aim_only or _owned(source) or _afraid(source) or is_finite(_aim(actor)))
			var minimum:Vector2=record.node.get_combined_minimum_size();record.node.size=minimum
			record.node.position=Vector2(snappedf(pixel.x,.1)-minimum.x*.5,snappedf(pixel.y,.1)-8-minimum.y)
			var talk_size:Vector2=record.talk.get_combined_minimum_size();record.talk.size=talk_size
			record.talk.position=Vector2(record.node.position.x+(minimum.x-talk_size.x)*.5,record.node.position.y-20-talk_size.y)
			var rect:Rect2=record.node.get_global_rect()
			if talk_visible:rect=rect.merge(record.talk.get_global_rect())
			show=show and Rect2(Vector2.ZERO,viewport_size).encloses(rect)
			for hud:Rect2 in _hud_rects:
				if rect.intersects(hud):show=false;break
		record.node.visible=show
		record.talk.visible=show and talk_visible
	if ring!=null:
		ring.visible=selected_id!=null and cards.has(str(selected_id)) and cards[str(selected_id)].node.visible
		if ring.visible:
			var record:Dictionary=cards[str(selected_id)];var object:Node3D=record.object.get_ref()
			ring.visible=not aim_only or is_finite(_aim({"object":object,"source":record.source}))
			ring.global_position=object.global_position+Vector3.UP*.025

func _create_ring(world:Node3D)->void:
	var vertices=PackedVector3Array();var colors=PackedColorArray()
	for outline:Array in [[.416,.426,Color("967747")],[.487,.500,Color("d9bd7d")]]:
		for i:int in 64:
			var a:float=i*PI/32.0;var b:float=(i+1)*PI/32.0
			var p=Vector3(cos(a)*outline[0],0,sin(a)*outline[0]);var q=Vector3(cos(a)*outline[1],0,sin(a)*outline[1]);var r=Vector3(cos(b)*outline[1],0,sin(b)*outline[1]);var s=Vector3(cos(b)*outline[0],0,sin(b)*outline[0])
			for v:Vector3 in [p,q,r,p,r,s]:vertices.append(v);colors.append(outline[2])
	for i:int in 4:
		var a:float=i*PI/2.0;var basis=Basis(Vector3.UP,-a)
		for v:Vector3 in [Vector3(.453,0,0),Vector3(.493,0,.022),Vector3(.533,0,0),Vector3(.453,0,0),Vector3(.533,0,0),Vector3(.493,0,-.022)]:vertices.append(basis*v);colors.append(Color("d9bd7d"))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color.a=.85;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	ring=MeshInstance3D.new();ring.name="Npc_Proximity_Ring";ring.mesh=mesh;ring.material_override=material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ring.set_meta("mercenaryPickIgnore",true);world.add_child(ring);ring.hide()

func get_speaker_anchor(id:String)->Variant:
	var requested:String=_key(id)
	for actor_id:String in cards:
		var record:Dictionary=cards[actor_id]
		if _key(actor_id)!=requested and _key(str(record.source.get("id","")))!=requested:continue
		if not record.node.visible or record.occluded or record.source.get("downed",false) or float(record.source.get("hp",1))<=0:return null
		return Vector2(record.node.position.x+record.node.size.x*.5,record.node.position.y-10)
	return null

func _key(id:String)->String:
	return id.trim_prefix("npc:").trim_prefix("npc_").trim_prefix("crew_")

func stats()->Dictionary:
	var fear_badges:int=0
	for record:Dictionary in cards.values():
		if record.fear.visible:fear_badges+=1
	return {"badges":cards.size(),"fearBadges":fear_badges,"raycasts":raycasts,"selectedId":selected_id,"ringVisible":ring!=null and ring.visible}

func _process(delta:float)->void:
	advance(delta)

func dispose()->void:
	if _disposed:return
	_disposed=true;set_process(false)
	for id:String in cards.keys():_drop_card(id)
	cards.clear();_head_cache.clear();options.clear();camera=null
	if is_instance_valid(ring):ring.queue_free()
	ring=null

func _exit_tree()->void:
	dispose()
