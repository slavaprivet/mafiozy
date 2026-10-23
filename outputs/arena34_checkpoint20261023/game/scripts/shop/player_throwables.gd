extends Node
## Purchased hand grenades and Molotovs. One right-button hold previews the same
## swept ballistic path that the thrown object follows; releasing it cancels aim.
const WeaponUI = preload("res://scripts/weapons/walk_weapon_ui.gd")
const PlayerHealth = preload("res://scripts/npc_visual/npc_melee_player_health.gd")
const ProjectilePool = preload("res://scripts/shop/throwable_projectile_pool.gd")
const FirePool = preload("res://scripts/shop/throwable_fire_pool.gd")
const GRAVITY := 9.8
const STEP := 0.10
const FLIGHT_LIMIT := 3.0
const GRENADE_FUSE := 2.6
const WINDUP_SECONDS := 0.22
const FOLLOW_SECONDS := 0.32
const FIRE_SECONDS := 6.0
const FIRE_TICK := 1.0
const MAX_IN_FLIGHT := 8
const MAX_FIRE_FIELDS := 6
const RADIUS := {"grenade":3.1,"molotov":2.6}
var _world: Node3D
var _shop: Node
var _weapons: Node
var _player: CharacterBody3D
var _blast: Node
var _c4: Node
var _player_health: RefCounted
var _ui: Control
var _mode := ""
var _aiming := false
var _throw_requested := false
var _throw_phase := ""
var _throw_clock := 0.0
var _preview_clock := 1.0
var _cached_path: Dictionary = {}
var _ray: PhysicsRayQueryParameters3D
var _projectile_pool: Node3D
var _fire_pool: Node3D
var _path: MeshInstance3D
var _line: ImmediateMesh
var _target: MeshInstance3D
var _rig: Skeleton3D
var _socket := -1
var _held_root: Node3D
var _held_grenade: Node3D
var _held_molotov: Node3D
var _upperarm := -1
var _forearm := -1
var _chest := -1
var _buttons: Dictionary = {}
var _projectiles: Array[Dictionary] = []
var _fires: Array[Dictionary] = []
var _area_events: Dictionary = {}
var _serial := 0
var _throws := 0
var _cancelled := 0
var _impacts := 0
var _bounces := 0
var _grenade_detonations := 0
var _molotov_shatters := 0
var _hud_cache := ""
var _last_area_result: Dictionary = {}

func configure(world: Node3D, shop: Node, blast: Node, c4: Node) -> Dictionary:
	if _world != null or not is_instance_valid(world) or not is_instance_valid(shop) or not is_instance_valid(blast):
		return {"ok":false,"reason":"binding"}
	if not bool(shop.get("ready_for_use")) or not is_instance_valid(world.get("preview_weapons")):
		return {"ok":false,"reason":"shop_or_arsenal"}
	_world=world; _shop=shop; _weapons=world.preview_weapons; _player=world.get("_player"); _blast=blast; _c4=c4
	_ui=_weapons.get("_walk_ui")
	if not is_instance_valid(_player) or not is_instance_valid(_ui) or not _ui.get("grid") is GridContainer:
		return {"ok":false,"reason":"player_or_q_grid"}
	_ray=PhysicsRayQueryParameters3D.new(); _ray.collision_mask=1|2|512
	_ray.exclude=[_player.get_rid()]; _ray.hit_from_inside=false
	_projectile_pool=ProjectilePool.new(); _fire_pool=FirePool.new()
	if not _projectile_pool.configure(world) or not _fire_pool.configure(world):
		return {"ok":false,"reason":"visual_pool"}
	# Any native gun or C4 selection puts a held throwable away.
	for key: String in _ui.choices:
		var choice: Button=_ui.choices[key].button
		choice.pressed.connect(cancel_mode)
	if is_instance_valid(_c4):
		for button: Variant in [_c4.get("_button"),_c4.get("_remote_button")]:
			if button is Button: button.pressed.connect(cancel_mode)
	for kind: String in ["grenade","molotov"]:
		var button:=Button.new()
		button.custom_minimum_size=Vector2(190,139)
		button.add_theme_stylebox_override("normal",WeaponUI.panel_style("252e35","4f595f",5))
		var column:=VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(column); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.add_child(WeaponUI.label("ГРАНАТА" if kind=="grenade" else "МОЛОТОВ",16))
		column.add_child(WeaponUI.label("ПКМ — траектория\nЛКМ — бросить",12,"cbb98f"))
		var count_label: Label=WeaponUI.label("",13,"e4c678")
		column.add_child(count_label)
		_buttons[kind]={"button":button,"count":count_label}
		button.pressed.connect(select.bind(kind))
		_ui.grid.add_child(button)
	_line=ImmediateMesh.new(); _path=MeshInstance3D.new(); _path.mesh=_line
	var line_material:=StandardMaterial3D.new()
	line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo=true; line_material.no_depth_test=true
	_path.material_override=line_material; _path.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_path); _path.visible=false
	_target=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.17; sphere.height=.34
	_target.mesh=sphere; _target.material_override=_material(Color("f3c75a"),true)
	world.add_child(_target); _target.visible=false
	_rig=_player.get("_pose_skeleton")
	if is_instance_valid(_rig):
		_socket=_rig.find_bone("socket_weapon")
		_upperarm=_rig.find_bone("upperarm_r"); _forearm=_rig.find_bone("forearm_r"); _chest=_rig.find_bone("chest")
		if _socket>=0:
			_held_root=Node3D.new(); _held_root.name="HeldThrowable"; _rig.add_child(_held_root); _held_root.visible=false
			_held_grenade=_projectile_pool.build_model(_held_root,"grenade")
			_held_molotov=_projectile_pool.build_model(_held_root,"molotov")
	if not _player.set_throw_pose_decorator(Callable(self,"decorate_throw_pose")):
		return {"ok":false,"reason":"throw_pose_owner"}
	# The ordinary city has no melee health binding. Give purchased explosives a
	# current local player HP owner there; curated melee scenes keep their owner.
	if not bool(world.get("preview_residents_enabled")) and not _player.has_meta("local_contact_health_owner"):
		var health:=PlayerHealth.new()
		if health.configure(world,_player,self): _player_health=health
		else: health.dispose()
	set_physics_process(true); set_process(true)
	return {"ok":true,"items":["grenade","molotov"],"trajectory":true,"right_release_cancels":true,"grenade_fuse_seconds":GRENADE_FUSE,"pooled_projectiles":MAX_IN_FLIGHT,"pooled_fire_fields":MAX_FIRE_FIELDS}

func _material(color: Color, emissive: bool=false) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new(); material.albedo_color=color
	if emissive: material.emission_enabled=true; material.emission=color; material.emission_energy_multiplier=1.6
	return material

func select(kind: String) -> Dictionary:
	if kind not in ["grenade","molotov"] or not _current(): return {"ok":false,"reason":"inactive"}
	if _shop.backpack.count(kind)<=0: return {"ok":false,"reason":"not_owned"}
	var unequipped: Dictionary=_weapons.equip("none")
	if not unequipped.get("ok",false): return unequipped
	if is_instance_valid(_c4): _c4.call("_leave_mode")
	_mode=kind; _hud_cache=""; _cancel_aim(false); _throw_phase=""; _weapons.cancel_inputs()
	_refresh_hud()
	return {"ok":true,"mode":kind,"count":_shop.backpack.count(kind)}

func cancel_mode() -> void:
	_cancel_aim(false); _mode=""; _throw_phase=""
	if is_instance_valid(_held_root): _held_root.visible=false
	if is_instance_valid(_ui): _ui.set("_hud_signature",""); _ui.refresh()

func _cancel_aim(count_cancel: bool) -> void:
	if count_cancel and _throw_phase!="follow" and (_aiming or _throw_phase=="windup"): _cancelled+=1
	_aiming=false; _throw_requested=false; _cached_path={}; _preview_clock=1.0
	if _throw_phase=="windup": _throw_phase=""
	if is_instance_valid(_path): _path.visible=false
	if is_instance_valid(_target): _target.visible=false

func decorate_throw_pose(_delta: float,selected: Dictionary) -> Dictionary:
	if not selected.get("valid",false) or mini(_upperarm,_forearm)<0 or _mode.is_empty(): return selected
	if not _aiming and _throw_phase!="follow": return selected
	var poses: Array=selected.poses.duplicate()
	var shoulder: float=-.40
	var elbow: float=-.48
	var twist: float=-.045
	if _throw_phase=="windup":
		var k: float=clampf(_throw_clock/WINDUP_SECONDS,0.0,1.0)
		shoulder=lerpf(-.40,.47,k*k*(3.0-2.0*k)); elbow=lerpf(-.48,-1.08,k); twist=.10*k
	elif _throw_phase=="follow":
		var k: float=clampf(_throw_clock/FOLLOW_SECONDS,0.0,1.0)
		shoulder=lerpf(-1.04,-.08,k); elbow=lerpf(-.22,0.0,k); twist=lerpf(-.11,0.0,k)
	_turn_bone(poses,_upperarm,Vector3.RIGHT,shoulder)
	_turn_bone(poses,_forearm,Vector3.RIGHT,elbow)
	if _chest>=0: _turn_bone(poses,_chest,Vector3.UP,twist)
	var result:=selected.duplicate(); result.poses=poses; result["throwable_pose"]=true
	return result

func _turn_bone(poses: Array,bone: int,axis: Vector3,angle: float) -> void:
	var frame: Transform3D=poses[bone]
	frame.basis=frame.basis*Basis(axis,angle)
	poses[bone]=frame

func _current() -> bool:
	return is_instance_valid(_world) and is_instance_valid(_shop) and bool(_shop.get("ready_for_use")) and is_instance_valid(_weapons) and _weapons._owner_current() and is_instance_valid(_player) and _weapons.player==_player

func _allowed() -> bool:
	return _current() and not bool(_world.get("preview_dead")) and not bool(_world.get("preview_physics_fault")) and _player._free_mouse_look and _player._pose_authority==&"on_foot" and _player._jump.is_empty() and not _player._text_control_focused() and not _weapons.controls_blocked() and not _shop.modal_open() and str(_weapons.fire_state.get("weaponId","none"))=="none"

func _input(event: InputEvent) -> void:
	if _mode.is_empty() or not event is InputEventMouseButton: return
	var button: InputEventMouseButton=event
	if button.button_index not in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_LEFT]: return
	if not _allowed(): _cancel_aim(true); return
	get_viewport().set_input_as_handled()
	if button.button_index==MOUSE_BUTTON_RIGHT:
		if button.pressed: _aiming=true
		else: _cancel_aim(true)
	elif button.pressed and _aiming:
		_throw_requested=true

func _physics_process(delta: float) -> void:
	if not _current(): _cancel_aim(true)
	if _player_health!=null: _player_health.step(delta)
	if _current() and not _mode.is_empty():
		if str(_weapons.fire_state.get("weaponId","none"))!="none" or (is_instance_valid(_c4) and str(_c4.get("_mode"))!="off"):
			cancel_mode()
		elif _shop.backpack.count(_mode)<=0 and _throw_phase!="follow":
			cancel_mode()
		elif not _allowed() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_cancel_aim(true)
		elif _aiming:
			_preview_clock+=delta
			if _preview_clock>=.05:
				_preview_clock=0.0; _cached_path=_trajectory(); _draw_trajectory(_cached_path)
			if _throw_requested and _throw_phase.is_empty():
				_throw_requested=false; _throw_phase="windup"; _throw_clock=0.0
	if _throw_phase=="windup":
		_throw_clock+=delta
		if _throw_clock>=WINDUP_SECONDS:
			if _aiming and _allowed() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _launch(_trajectory()):
				_throw_phase="follow"; _throw_clock=0.0
			else: _cancel_aim(true)
	elif _throw_phase=="follow":
		_throw_clock+=delta
		if _throw_clock>=FOLLOW_SECONDS:
			_throw_phase=""
			if _current() and not _mode.is_empty() and _shop.backpack.count(_mode)<=0: cancel_mode()
	for index in range(_projectiles.size()-1,-1,-1):
		var row: Dictionary=_projectiles[index]
		row.age+=delta
		if row.kind=="grenade" and row.age>=GRENADE_FUSE:
			_impact(row.kind,row.position,row.last_normal,row.event_id)
			_projectile_pool.release(row.slot); _projectiles.remove_at(index); continue
		var remaining: float=minf(delta,.12)
		var shattered:=false
		while remaining>.0001 and not row.settled and not shattered:
			var step: float=minf(remaining,.035)
			var next: Vector3=row.position+row.velocity*step+Vector3.DOWN*(.5*GRAVITY*step*step)
			var hit: Dictionary=_sweep(row.position,next)
			remaining-=step
			if not hit.is_empty():
				var normal: Vector3=hit.normal.normalized()
				if row.kind=="molotov":
					_impact(row.kind,hit.position,normal,row.event_id)
					_projectile_pool.release(row.slot); _projectiles.remove_at(index); shattered=true
				else:
					row.bounces+=1; _bounces+=1; row.last_normal=normal; row.position=hit.position+normal*.04
					var incoming: Vector3=row.velocity+Vector3.DOWN*GRAVITY*step
					var reflected: Vector3=incoming.bounce(normal)*.48
					var tangent: Vector3=reflected-normal*reflected.dot(normal)
					row.velocity=reflected-tangent*.22
					row.spin*=.72
					if row.bounces>=5 or (normal.y>.52 and row.velocity.length()<1.55):
						row.settled=true; row.velocity=Vector3.ZERO
			else:
				row.position=next; row.velocity+=Vector3.DOWN*GRAVITY*step
			if not shattered:
				row.visual.global_position=row.position
				row.visual.rotate_object_local(row.spin_axis,row.spin*step)
		if not shattered and row.kind=="molotov" and row.age>=FLIGHT_LIMIT:
			_impact(row.kind,row.position,Vector3.UP,row.event_id)
			_projectile_pool.release(row.slot); _projectiles.remove_at(index); shattered=true
		if not shattered: _projectiles[index]=row
	for index in range(_fires.size()-1,-1,-1):
		var field: Dictionary=_fires[index]; field.age+=delta; field.tick+=delta
		if field.age>=FIRE_SECONDS:
			_fire_pool.stop_field(field.slot); _fires.remove_at(index); continue
		if field.tick>=FIRE_TICK:
			field.tick-=FIRE_TICK; field.serial+=1
			_apply_area("molotov",field.position,Vector3.UP,field.id+":fire:"+str(field.serial),9)
		_fires[index]=field

func _trajectory() -> Dictionary:
	var camera: Camera3D=_player.get_preview_camera()
	if not is_instance_valid(camera): return {}
	var forward: Vector3=-camera.global_basis.z.normalized()
	var flat:=Vector3(forward.x,0,forward.z).normalized()
	if flat.length_squared()<.01: flat=-_player.global_basis.z
	var start: Vector3=_player.global_position+Vector3.UP*1.48+flat*.62
	var velocity: Vector3=flat*16.0+Vector3.UP*clampf(5.0+forward.y*8.0,-1.0,11.0)
	var points: PackedVector3Array=PackedVector3Array([start])
	var position:=start
	var current_velocity:=velocity
	var bounces:=0
	var limit: float=GRENADE_FUSE if _mode=="grenade" else FLIGHT_LIMIT
	for step_index in int(ceil(limit/STEP)):
		var next: Vector3=position+current_velocity*STEP+Vector3.DOWN*(.5*GRAVITY*STEP*STEP)
		var hit: Dictionary=_sweep(position,next)
		if not hit.is_empty():
			points.append(hit.position)
			if _mode=="molotov": return {"points":points,"start":start,"velocity":velocity,"impact":hit.position}
			var normal: Vector3=hit.normal.normalized()
			bounces+=1; position=hit.position+normal*.04
			var reflected: Vector3=(current_velocity+Vector3.DOWN*GRAVITY*STEP).bounce(normal)*.48
			var tangent: Vector3=reflected-normal*reflected.dot(normal)
			current_velocity=reflected-tangent*.22
			if bounces>=5 or (normal.y>.52 and current_velocity.length()<1.55):
				return {"points":points,"start":start,"velocity":velocity,"impact":position}
		else:
			position=next; current_velocity+=Vector3.DOWN*GRAVITY*STEP; points.append(position)
	return {"points":points,"start":start,"velocity":velocity,"impact":position}

func _sweep(from: Vector3,to: Vector3) -> Dictionary:
	if from.distance_squared_to(to)<.000001: return {}
	_ray.from=from; _ray.to=to
	return _player.get_world_3d().direct_space_state.intersect_ray(_ray)

func _draw_trajectory(path: Dictionary) -> void:
	_line.clear_surfaces()
	if path.is_empty(): _path.visible=false; _target.visible=false; return
	var points: PackedVector3Array=path.points
	_line.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(points.size()-1):
		var tint:=Color("efc863") if _mode=="grenade" else Color("ff8b4d")
		_line.surface_set_color(tint); _line.surface_add_vertex(points[index])
		_line.surface_set_color(tint); _line.surface_add_vertex(points[index+1])
	_line.surface_end(); _path.visible=true; _target.visible=true
	_target.global_position=path.impact

func _launch(path: Dictionary) -> bool:
	if path.is_empty() or _projectiles.size()>=MAX_IN_FLIGHT or _shop.backpack.count(_mode)<=0: return false
	if not path.get("start") is Vector3 or not path.get("velocity") is Vector3: return false
	var slot: int=_projectile_pool.acquire(_mode,path.start)
	if slot<0: return false
	var taken: Dictionary=_shop.backpack.take(_mode,1)
	if not taken.get("ok",false): _projectile_pool.release(slot); return false
	_serial+=1; _throws+=1
	var event_id: String="throw:"+str(get_instance_id())+":"+str(_serial)
	var visual: Node3D=_projectile_pool.visual(slot)
	var lateral: Vector3=Vector3.UP.cross(path.velocity).normalized()
	if lateral.length_squared()<.01: lateral=Vector3.RIGHT
	var spin_axis: Vector3=(lateral+Vector3(.08,.03,.05)).normalized() if _mode=="molotov" else Vector3(.73,.42,.55).rotated(Vector3.UP,float(_serial)*.71).normalized()
	_projectiles.append({"id":event_id,"event_id":event_id,"kind":_mode,"position":path.start,"velocity":path.velocity,"visual":visual,"slot":slot,"age":0.0,"bounces":0,"settled":false,"last_normal":Vector3.UP,"spin_axis":spin_axis,"spin":14.0 if _mode=="molotov" else 10.5})
	_refresh_hud()
	_shop.call("_refresh_window","Брошено: "+("граната" if _mode=="grenade" else "Молотов"),"d8b778")
	return true

func _impact(kind: String,at: Vector3,normal: Vector3,event_id: String) -> void:
	_impacts+=1
	if kind=="grenade":
		_grenade_detonations+=1; _apply_area(kind,at,normal,event_id,80)
	else:
		_molotov_shatters+=1
		# A bottle can strike a vertical wall. Keep the burning pool on the
		# nearest walkable surface on the impact side of that wall.
		at=_fire_surface(at,normal)
		if _fires.size()>=MAX_FIRE_FIELDS:
			_fire_pool.stop_field(_fires[0].slot); _fires.remove_at(0)
		var slot: int=_fire_pool.ignite(at)
		if slot>=0: _fires.append({"id":event_id,"position":at,"slot":slot,"age":0.0,"tick":0.0,"serial":0})
		_apply_area(kind,at,normal,event_id+":fire:0",12)

func _fire_surface(at: Vector3,normal: Vector3) -> Vector3:
	var lateral: Vector3=Vector3(normal.x,0.0,normal.z).normalized()
	var above: Vector3=at+lateral*.35+Vector3.UP*.45
	var below: Vector3=above+Vector3.DOWN*4.5
	var query:=PhysicsRayQueryParameters3D.create(above,below,1|512,[_player.get_rid()])
	var hit: Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y>.45: return hit.position+Vector3.UP*.02
	return Vector3(at.x,at.y if normal.y>.45 else .05,at.z)

func _apply_area(kind: String,at: Vector3,normal: Vector3,event_id: String,damage: int) -> void:
	_area_events[event_id]={"kind":kind,"position":at,"until":Time.get_ticks_msec()+2000}
	for key: String in _area_events.keys():
		if Time.get_ticks_msec()>int(_area_events[key].until): _area_events.erase(key)
	while _area_events.size()>96: _area_events.erase(_area_events.keys()[0])
	var result: Dictionary=_blast.apply_throwable(self,kind,at,normal,event_id)
	_last_area_result=result.duplicate(true)
	var population: Variant=_world.get("preview_population")
	if population!=null:
		for owner: RefCounted in population.hit_owners:
			if not owner.has_method("apply_throwable_area"): continue
			var token: Variant=owner.get("_token")
			if not token is Dictionary or not is_instance_valid(token.get("body")): continue
			if (token.body.global_position-at).length_squared()>18.0: continue
			owner.call("apply_throwable_area",self,event_id,kind,at,float(RADIUS[kind]),damage)
	var health: Variant=_player_health
	if health==null:
		var melee: Variant=_world.get("preview_melee")
		if is_instance_valid(melee): health=melee.get("_health")
	if health!=null and health.has_method("apply_throwable_area"):
		health.call("apply_throwable_area",self,event_id,kind,at,float(RADIUS[kind]),damage)
	if kind=="grenade" or event_id.ends_with(":fire:0"):
		print("DSH_THROWABLE impact=",kind," id=",event_id," blast=",JSON.stringify(result))

func owns_area_event(event_id: String,kind: String,at: Vector3) -> bool:
	if not _area_events.has(event_id): return false
	var row: Dictionary=_area_events[event_id]
	return row.kind==kind and row.position.distance_to(at)<.01 and Time.get_ticks_msec()<=int(row.until)

func _refresh_hud() -> void:
	var signature: String=_mode+":"+str(_shop.backpack.count("grenade"))+":"+str(_shop.backpack.count("molotov"))
	if signature!=_hud_cache:
		_hud_cache=signature
		for kind: String in _buttons:
			(_buttons[kind].count as Label).text="В рюкзаке: %d"%_shop.backpack.count(kind)
	if _mode.is_empty() or not is_instance_valid(_ui): return
	var heading: String="ГРАНАТА" if _mode=="grenade" else "МОЛОТОВ"
	var detail: String="ПКМ — держать и прицелиться · ЛКМ — бросить · %d шт."%_shop.backpack.count(_mode)
	if _ui.title.text!=heading: _ui.title.text=heading
	if _ui.ammo.text!=detail: _ui.ammo.text=detail

func _process(_delta: float) -> void:
	if _current(): _refresh_hud()
	if is_instance_valid(_held_root):
		var show: bool=_current() and not _mode.is_empty() and _allowed() and _socket>=0 and _shop.backpack.count(_mode)>0 and _throw_phase!="follow"
		_held_root.visible=show
		if show:
			var frame: Transform3D=_rig.global_transform*_rig.get_bone_global_pose(_socket)
			_held_root.global_transform=Transform3D(frame.basis.orthonormalized(),frame.origin)
			_held_grenade.visible=_mode=="grenade"; _held_molotov.visible=_mode=="molotov"
	var camera: Camera3D=_player.get_preview_camera() if is_instance_valid(_player) else null
	var camera_position: Vector3=camera.global_position if is_instance_valid(camera) else Vector3.INF
	for field: Dictionary in _fires:
		_fire_pool.update_field(field.slot,field.age,camera_position)

func snapshot() -> Dictionary:
	return {"ready":_current(),"mode":_mode,"aiming":_aiming,"throw_phase":_throw_phase,"trajectory_visible":is_instance_valid(_path) and _path.visible,"in_flight":_projectiles.size(),"fire_fields":_fires.size(),"throws":_throws,"cancelled":_cancelled,"impacts":_impacts,"bounces":_bounces,"grenade_detonations":_grenade_detonations,"molotov_shatters":_molotov_shatters,"last_area":_last_area_result.duplicate(true),"projectiles":_projectile_pool.snapshot() if is_instance_valid(_projectile_pool) else {},"fire_fx":_fire_pool.snapshot() if is_instance_valid(_fire_pool) else {},"grenades":_shop.backpack.count("grenade") if is_instance_valid(_shop) else 0,"molotovs":_shop.backpack.count("molotov") if is_instance_valid(_shop) else 0}

func dispose() -> void:
	_cancel_aim(false); set_process(false); set_physics_process(false); set_process_input(false)
	for choice: Dictionary in _buttons.values():
		if is_instance_valid(choice.button): choice.button.queue_free()
	_buttons.clear()
	for row: Dictionary in _projectiles:
		if is_instance_valid(_projectile_pool): _projectile_pool.release(row.slot)
	for row: Dictionary in _fires:
		if is_instance_valid(_fire_pool): _fire_pool.stop_field(row.slot)
	_projectiles.clear(); _fires.clear(); _area_events.clear()
	if is_instance_valid(_path): _path.queue_free()
	if is_instance_valid(_target): _target.queue_free()
	if is_instance_valid(_held_root): _held_root.queue_free()
	if _player_health!=null: _player_health.dispose(); _player_health=null
	if is_instance_valid(_player) and _player._throw_pose_decorator==Callable(self,"decorate_throw_pose"):
		_player.set_throw_pose_decorator(Callable())
	if is_instance_valid(_projectile_pool): _projectile_pool.dispose()
	if is_instance_valid(_fire_pool): _fire_pool.dispose()
	_world=null; _shop=null; _weapons=null; _player=null; _blast=null; _c4=null; _ui=null
	queue_free()
