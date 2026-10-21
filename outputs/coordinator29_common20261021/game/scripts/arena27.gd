extends "res://scripts/main.gd"
## Separate scene; the release pointer and frozen gameplay scripts stay intact.
const LabTarget = preload("res://scripts/clay_target.gd")
const LAB_IDS := ["sword", "mace", "axe", "sledge", "spear", "bow", "shield"]
const LAB_NAMES := ["Меч", "Булава", "Топор", "Кувалда", "Копьё", "Лук", "Щит"]
var lab: Node3D
var lab_status: Label
var lab_controls: Label
var lab_out := ""
var lab_ready := false
var lab_clock := 0.0
var lab_notice := ""
var _lab_restart_pending := false

func _ready() -> void:
	get_window().title = "Мафиози · Полигон 29 · замах и щит"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-out="): lab_out = arg.trim_prefix("--lab-out=")
	castle_map = false
	preview_ready = false
	_build_lab()
	_start_lab.call_deferred()

func _build_lab() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("263344")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfdef2")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_energy = 0.55
	add_child(fill)
	_lab_box(Vector3(0,-0.35,0), Vector3(36,0.7,36), Color("565f66"), true)
	for i: int in range(-16,17,2):
		_lab_box(Vector3(i,0.005,0),Vector3(0.018,0.006,34),Color("737f88"),false)
		_lab_box(Vector3(0,0.005,i),Vector3(34,0.006,0.018),Color("737f88"),false)
	_lab_box(Vector3(0,1,-18),Vector3(36,2,0.4),Color("3b4858"),true)
	_lab_box(Vector3(-18,1,0),Vector3(0.4,2,36),Color("3b4858"),true)
	_lab_box(Vector3(18,1,0),Vector3(0.4,2,36),Color("3b4858"),true)
	_lab_box(Vector3(0,1,18),Vector3(36,2,0.4),Color("3b4858"),true)
	_lab_label("ПОЛИГОН 29 · ЗАМАХ И ЩИТ", Vector3(0,3,-12), 40)
	_lab_label("ОРУЖИЕ  1–7  /  Q", Vector3(-6,2,0), 34)
	# A step and wall allow repeatable ground, jump and weapon contact checks.
	_lab_box(Vector3(7,0.2,-4),Vector3(3,0.4,3),Color("6a737b"),true)
	_lab_box(Vector3(7,1.2,-7),Vector3(4,2.4,0.5),Color("8a9299"),true)
	_player = load("res://scripts/preview_player.gd").new()
	_player.position = Vector3(0,0.05,1.6)
	_player.set_meta("actor_id", "player")
	_player.set_meta("life_generation", 1)
	add_child(_player)
	_player.camera_distance = 3.4
	_player._camera_pitch = -0.10
	_player._update_camera_rotation()
	_build_lab_ui()

func _lab_box(at: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var node := StaticBody3D.new() if solid else Node3D.new()
	node.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh.material_override = material
	node.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		node.add_child(collider)
	add_child(node)

func _lab_label(text: String, at: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("e8d7a7")
	add_child(label)

func _start_lab() -> void:
	await get_tree().physics_frame
	preview_weapons = load("res://scripts/weapons/preview_weapons.gd").new()
	add_child(preview_weapons)
	var arsenal: Dictionary = preview_weapons.configure(self,_player)
	if not arsenal.get("ok",false): push_error(str(arsenal)); return
	_player._weapon_host = preview_weapons
	lab = LabTarget.new()
	lab.name = "LaboratoryTargetHost"
	add_child(lab)
	preview_sword_prototype = lab
	var installed: Dictionary = lab.install(self,_player)
	if not installed.get("ok",false): push_error(str(installed)); return
	if not lab.lab_spawn(): push_error("Laboratory NPC failed"); return
	_install_bow_prototype()
	if is_instance_valid(lab.get("_hint_layer")): lab.get("_hint_layer").hide()
	lab.set_meta("cap_warmup28", await preload("res://scripts/combat/cap_warmup28.gd").run(self,lab))
	preview_ready = true
	lab_ready = true
	_lab_equip(0)
	_player.set_mouse_captured(false)
	_build_lab_rack()
	for tick: int in 8: await get_tree().physics_frame
	_lab_receipt("READY.json", {"ok":true,"scene":"res://scenes/arena27.tscn","weapons":LAB_IDS,"npc":lab.snapshot(),"fixed_target":true,"regrow":true})
	print("ARENA27_READY")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(lab_out.path_join("opened.png"))
	if OS.get_cmdline_user_args().has("--lab-check=1"): await _lab_check()

func _build_lab_rack() -> void:
	for i: int in 5:
		var model: Node3D = lab.call("_build_weapon_model", self, LAB_IDS[i])
		model.position = Vector3(-6,0.9,-2.6 + i*1.3)
		model.rotation.z = PI*0.5
		_lab_box(Vector3(-6,0.38,-2.6+i*1.3),Vector3(2,0.76,0.9),Color("313d4a"),true)
		_lab_label(str(i+1)+" · "+LAB_NAMES[i],Vector3(-6,1.55,-2.6+i*1.3),28)

func _build_lab_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.visible = false
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14,14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.04,0.06,0.90)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	lab_status = Label.new()
	lab_status.add_theme_font_size_override("font_size",19)
	rows.add_child(lab_status)
	lab_controls = Label.new()
	lab_controls.text = "1 Меч   2 Булава   3 Топор   4 Кувалда   5 Копьё   6 Лук   7 Щит\nQ — весь арсенал   G — бросить   E — подобрать\nF2 — восстановление   F3 — мишень / бой   F4 — броня\nF5 — вернуться на полигон   F6 — новый NPC\nF7 — кадр и запись   F8 — убрать остатки\nF9 — начать заново   Esc — курсор   щелчок — управление"
	lab_controls.add_theme_font_size_override("font_size",15)
	rows.add_child(lab_controls)

func _lab_equip(index: int) -> void:
	if not lab_ready: return
	preview_weapons.set_menu(true)
	var result: Dictionary = preview_weapons.equip(LAB_IDS[index])
	lab_notice = LAB_NAMES[index] if result.get("ok",false) else "Не выбрано: "+str(result.get("reason"))
	if not result.get("ok",false): preview_weapons.set_menu(false)

func _input(event: InputEvent) -> void:
	if not lab_ready or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key >= KEY_1 and key <= KEY_7: _lab_equip(key-KEY_1)
	elif key == KEY_F2: lab.lab_regrow = not lab.lab_regrow
	elif key == KEY_F3:
		lab.lab_fixed = not lab.lab_fixed
		lab.lab_reset()
	elif key == KEY_F4:
		lab.lab_armored = not lab.lab_armored
		lab.lab_reset()
	elif key == KEY_F6: lab.lab_reset()
	elif key == KEY_F7: _lab_capture()
	elif key == KEY_F8: lab.lab_clear_debris()
	elif key == KEY_F5 or key == KEY_F9: _lab_return_to_start()
	else: return
	get_viewport().set_input_as_handled()

func _lab_return_to_start() -> void:
	if _lab_restart_pending: return
	_lab_restart_pending = true
	# Recreate all owners together: teleport alone leaves authored jump paths,
	# flight impulses and the blade's previous sweep at the abandoned location.
	_lab_receipt("RETURN.json", {"requested":true,"reason":"return_key","from":str(_player.global_position),"time_ms":Time.get_ticks_msec()})
	get_tree().reload_current_scene.call_deferred()

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

func _process(delta: float) -> void:
	if not lab_ready: return
	# The user hid this panel. Avoid collecting the full combat snapshot and
	# formatting its labels every 150 ms while nobody can see them.
	if not lab_status.is_visible_in_tree(): return
	lab_clock += delta
	if lab_clock < 0.15: return
	lab_clock = 0
	var hit: Dictionary = lab.lab_last_hit
	var state: Dictionary = lab.snapshot()
	var mode: String = "МИШЕНЬ · закреплена, падения отключены" if lab.lab_fixed else "БОЙ · обычная физика и AI"
	lab_status.text = "%s\nHP %.0f · восстановление %s · броня %s · сбросов %d\n%s\n%s" % [mode,float(state.get("npc_hp",0)),"ВКЛ" if lab.lab_regrow and lab.lab_fixed else "ВЫКЛ","ВКЛ" if lab.lab_armored else "ВЫКЛ",lab.lab_resets,"Попадание: %s · %.1f HP · %.1f м/с" % [str(hit.get("part","—")),float(hit.get("damage",0)),float(hit.get("speed",0))],lab_notice]

func _lab_receipt(filename: String, data: Dictionary) -> void:
	if lab_out.is_empty(): return
	DirAccess.make_dir_recursive_absolute(lab_out)
	var file := FileAccess.open(lab_out.path_join(filename),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(data,"\t"))

func _lab_capture() -> void:
	var stamp := str(Time.get_ticks_msec())
	if lab_out.is_empty(): lab_out = "user://arena27"
	_lab_receipt(stamp+".json",{"npc":lab.snapshot(),"events":lab.lab_events,"player":str(_player.global_position),"camera_distance":_player.camera_distance,"fixed":lab.lab_fixed})
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(lab_out.path_join(stamp+".png"))
	lab_notice = "Кадр сохранён: "+stamp

func _lab_check() -> void:
	var checks: Dictionary = {"player_grounded":_player.is_on_floor(),"npc_present":is_instance_valid(lab.get("_npc_rig"))}
	for i: int in 6:
		_lab_equip(i)
		await get_tree().physics_frame
		checks["equip_"+LAB_IDS[i]] = str(preview_weapons.fire_state.get("weaponId")) == LAB_IDS[i]
	_lab_equip(0)
	_lab_equip(6)
	checks["shield"] = bool(lab.shield_status().get("worn",false))
	lab.set_shield_worn(false)
	# This is a restoration unit check, not a claim about natural attack acceptance.
	var rig: Skeleton3D = lab.get("_npc_rig")
	var head: int = rig.find_bone("head")
	var at: Vector3 = rig.global_transform * rig.get_bone_global_pose(head).origin
	lab.call("_npc_take_blade_part","head",at,12.0,Vector3.RIGHT,250.0,true,true)
	checks["head_severed"] = lab.get("_npc_severed").has("head")
	await get_tree().create_timer(1.0).timeout
	checks["head_restored"] = lab.get("_npc_severed").is_empty() and not lab.get("_npc_dead") and lab.lab_resets > 0
	checks["target_stays_at_station"] = lab.get("_npc_body").global_position.distance_to(Vector3(0,0.02,-2)) < 0.02
	checks["all_hitboxes_restored"] = lab.get("_npc_rig").find_children("*","AnimatableBody3D",true,false).size() == 15
	for part: String in ["forearm_l", "thigh_r", "shin_l"]:
		rig = lab.get("_npc_rig")
		var bone := rig.find_bone(part)
		at = rig.global_transform * rig.get_bone_global_pose(bone).origin
		lab.call("_npc_take_blade_part",part,at,12.0,Vector3.RIGHT,250.0,true,true)
		checks[part+"_severed"] = lab.get("_npc_severed").has(part)
		await get_tree().create_timer(0.8).timeout
		checks[part+"_restored"] = lab.get("_npc_severed").is_empty() and not lab.get("_npc_dead")
	lab.lab_fixed = false
	lab.lab_reset()
	await get_tree().create_timer(0.4).timeout
	checks["combat_mode_alive"] = not lab.get("_npc_dead") and not lab.lab_fixed
	lab.lab_fixed = true
	lab.lab_reset()
	await get_tree().create_timer(0.1).timeout
	lab.lab_clear_debris()
	var ok := true
	for value: bool in checks.values(): ok = ok and value
	_lab_receipt("CHECK.json",{"passed":ok,"checks":checks,"scope":"Isolated scene startup, all medieval equip and explicit restoration fixture. Natural strike/player acceptance still interactive."})
	print("ARENA27_CHECK ",JSON.stringify(checks))
	get_tree().quit(0 if ok else 1)
