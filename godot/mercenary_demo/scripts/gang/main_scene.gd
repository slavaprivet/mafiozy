extends Node3D
## Single BUILD-owned composition of original core, actual ownership host,
## source UI/badges and transactional persistence. Controlled hiring fixture
## only; no replacement of original286, production motion or shared boarding.
const World = preload("res://scripts/gang/fixture_world.gd")
const Squad = preload("res://addons/walk_mercenary/mercenary_squad.gd")
const Host = preload("res://addons/walk_mercenary_host/mercenary_host.gd")
const RecruitUI = preload("res://scripts/gang/ui/mercenary_recruit_ui.gd")
const RecruitmentHostView = preload("res://scripts/gang/recruitment_host_view.gd")
const InteractionContext = preload("res://scripts/gang/interaction_context.gd")
const Badges = preload("res://scripts/gang/ui/mercenary_badges.gd")
const RenderOcclusion = preload("res://scripts/gang/ui/render_occlusion.gd")
const PersistenceOwner = preload("res://scripts/gang/persistence_owner.gd")
const SourceHero = preload("res://assets/hero.glb")

var world: Node3D
var core: RefCounted
var host: RefCounted
var persistence: RefCounted
var camera: Camera3D
var recruitment_ui: Control
var recruitment_host_view: RefCounted
var badges: Control
var occlusion: RefCounted
var hud: CanvasLayer
var toolbar: HBoxContainer
var status_label: Label
var stage_geometry: Node3D
var interaction_context := InteractionContext.new()
var _talk_clock := 0.2
var _talk_target: Dictionary = {}
var _owned := false
var ready_for_acceptance := false
var setup_error := ""

func _ready() -> void:
	get_window().focus_exited.connect(release_transport_controls)
	_build_stage()
	world = World.new()
	world.name = "PhysicalRegistry"
	add_child(world)
	var positions: Array = [Vector3(-1.7,0,-0.8),Vector3(0,0,-0.8),Vector3(1.7,0,-0.8),
		Vector3(-1.7,0,-2),Vector3(0,0,-2),Vector3(1.7,0,-2)]
	if not world.setup(SourceHero,Vector3.ZERO,positions,4.1,_fixture_resident_ids()):
		_fail_setup(world.last_error)
		return
	_owned = true
	occlusion = RenderOcclusion.new()
	occlusion.set_roots([stage_geometry,world])
	persistence = PersistenceOwner.new()
	var options: Dictionary = world.provider_options()
	options.persist = Callable(persistence,"persist")
	host = Host.new(options)
	core = Squad.new(host.core_options())
	if not host.bind_core(core):
		_fail_setup("host bind failed")
		return
	if not persistence.configure(world,core,host,Squad,Host,_fixture_save_path(),options):
		_fail_setup("persistence configure failed")
		return
	persistence.bindings_changed.connect(_on_bindings_changed)
	persistence.bindings_retiring.connect(_on_bindings_retiring)
	_build_toolbar()
	_rebuild_presentation()
	if not setup_error.is_empty():
		return
	# Inspect existing bytes before enabling the first operation that can autosave.
	# A rejected save stays intact; the source still allows hiring in memory.
	var startup_restore: Dictionary = persistence.load_now()
	if not setup_error.is_empty():
		return
	host.adopt_candidates(true)
	ready_for_acceptance = true
	status_label.text = "E — разговор · Отряд — найм и снаряжение" if startup_restore.get("ok",false) else "Сохранение не загружено: "+str(startup_restore.get("error",""))+" · автосохранение заблокировано"

func _fixture_save_path() -> String:
	# QA supplies an isolated path so its controlled fixture never touches a user's save.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gang-save-path="):
			return argument.trim_prefix("--gang-save-path=")
	return "user://gang_recruitment_save.json"

func _fixture_resident_ids() -> Array:
	# Seed existing physical identities for genuine original-JS save fixtures.
	# This never edits imported save text or substitutes an unrelated resident.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gang-resident-ids="):
			return Array(argument.trim_prefix("--gang-resident-ids=").split(",",false))
	return []

func _build_stage() -> void:
	stage_geometry = Node3D.new()
	stage_geometry.name = "ControlledStageGeometry"
	add_child(stage_geometry)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24,24)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24,0.27,0.25)
	material.roughness = 1.0
	var ground := MeshInstance3D.new()
	ground.name = "FixtureGround"
	ground.mesh = floor_mesh
	ground.material_override = material
	stage_geometry.add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	add_child(light)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08,0.11,0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72,0.76,0.85)
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	add_child(environment_node)
	camera = Camera3D.new()
	camera.name = "AcceptanceCamera"
	add_child(camera)
	camera.position = Vector3(0,5,3.8)
	# Controlled fixture framing keeps the source talk hint clear of the back row.
	camera.fov = 40.0
	camera.look_at(Vector3(0,0.8,-1.2))
	camera.current = true
	hud = CanvasLayer.new()
	hud.name = "SourceGangPresentation"
	add_child(hud)

func _build_toolbar() -> void:
	toolbar = HBoxContainer.new()
	toolbar.name = "FixtureActions"
	toolbar.position = Vector2(18,18)
	toolbar.add_theme_constant_override("separation",12)
	hud.add_child(toolbar)
	for action in [["Отряд",Callable(self,"_open_roster")],
		["Сохранить",Callable(self,"_save_clicked")],["Загрузить",Callable(self,"_load_clicked")]]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(action[1])
		toolbar.add_child(button)
	status_label = Label.new()
	status_label.position = Vector2(18,62)
	hud.add_child(status_label)
	var scope_label := Label.new()
	scope_label.text = "Найм · проверочная сцена"
	scope_label.position = Vector2(18,88)
	hud.add_child(scope_label)

func _rebuild_presentation() -> void:
	if is_instance_valid(recruitment_ui):
		recruitment_ui.dispose()
		hud.remove_child(recruitment_ui)
		recruitment_ui.queue_free()
	if is_instance_valid(badges):
		badges.dispose()
		hud.remove_child(badges)
		badges.queue_free()
	badges = Badges.new()
	badges.name = "OriginalGangBadges"
	hud.add_child(badges)
	recruitment_ui = RecruitUI.new()
	recruitment_ui.name = "OriginalRecruitmentUI"
	hud.add_child(recruitment_ui)
	recruitment_host_view = RecruitmentHostView.new(host,world)
	var ui_receipt: Dictionary = recruitment_ui.configure(recruitment_host_view,{
		"begin_conversation":Callable(host,"begin_conversation"),
		"end_conversation":Callable(host,"end_conversation"),
		"get_talk_target":Callable(self,"_get_talk_target"),
		"is_blocked":Callable(self,"_external_blocked"),
		"has_priority_interaction":Callable(interaction_context,"has_priority_interaction"),
		"is_transport_interaction":Callable(interaction_context,"transport_interaction")})
	var badge_receipt: Dictionary = badges.configure(camera,{
		"get_actors":Callable(host,"presentation_actors"),
		"get_focus":Callable(self,"_focus_position"),
		"get_talk_id":Callable(self,"_get_talk_id"),
		"hide_owned":Callable(self,"_hide_owned"),
		"get_hud_rects":Callable(self,"_hud_rects"),
		"wall_clock_ms":Callable(self,"_wall_clock_ms"),
		"occluded":Callable(occlusion,"occluded")},null)
	# null reproduces mercenary_walk.mjs:28: optional proximity ring is inactive.
	if not ui_receipt.get("ok",false) or not badge_receipt.get("ok",false):
		_fail_setup("presentation configuration rejected")

func _focus_position() -> Vector3:
	return world.player.global_position

func _wall_clock_ms() -> float:
	return world.now()*1000.0

func _hide_owned() -> bool:
	# Visual hiding follows live source vehicle state, not the post-exit key latch.
	return interaction_context.vehicle_context()

func _external_blocked() -> bool:
	return not ready_for_acceptance or interaction_context.transport_interaction()

func configure_interaction_providers(providers: Dictionary) -> bool:
	return interaction_context.configure(providers)

func reserve_transport_e_press() -> void:
	# Actual transport owner calls this before its own synchronous state change.
	interaction_context.reserve_e_press()

func release_transport_controls() -> void:
	# Walk blur/releaseControls: a missing keyup must not retain the old gesture.
	interaction_context.release_controls()
	if is_instance_valid(recruitment_ui) and recruitment_ui.has_method("release_transport_controls"):
		recruitment_ui.release_transport_controls()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_transport_controls()

func _input(event: InputEvent) -> void:
	interaction_context.observe_key(event)
	# Never consume the vehicle owner's E gesture here.

func _hud_rects() -> Array:
	var rectangles: Array = recruitment_ui.hud_rects() if is_instance_valid(recruitment_ui) else []
	if is_instance_valid(toolbar):
		rectangles.append(toolbar.get_global_rect())
	return rectangles

func _get_talk_id() -> Variant:
	if interaction_context.transport_interaction():
		return null
	return _talk_target.get("id")

func _get_talk_target() -> Dictionary:
	_refresh_talk_target()
	return _talk_target

func _refresh_talk_target() -> void:
	_talk_target.clear()
	if not ready_for_acceptance or interaction_context.transport_interaction() or recruitment_ui.blocks_world_input():
		return
	# Source mercenary_walk nearestOwnMember: first five, 2.5 horizontal metres,
	# +/-1.5 vertical metres, live status, projected bounds, score and line of sight.
	var focus: Vector3 = _focus_position()
	var roster: Dictionary = host.get_roster()
	var owned: Array = []
	for row: Dictionary in roster.members.slice(0,5):
		var live: Variant = host.get_member(str(row.id))
		var body: Node3D = host.get_actor(str(row.id))
		if not live is Dictionary or not is_instance_valid(body) or not body.is_visible_in_tree():
			continue
		var point := Vector3(float(live.position.x),float(live.position.y),float(live.position.z))
		var metres := Vector2(point.x-focus.x,point.z-focus.z).length()
		if metres>2.5 or absf(point.y-focus.y)>1.5 or float(live.hp)<=0 or live.dead or live.downed or not live.available:
			continue
		var talk_point := point+Vector3.UP*1.2
		var camera_depth := -camera.to_local(talk_point).z
		if camera_depth<camera.near or camera_depth>camera.far:
			continue
		var pixel := camera.unproject_position(talk_point)
		var viewport_size := get_viewport().get_visible_rect().size
		var ndc := Vector2(pixel.x/viewport_size.x*2-1,1-pixel.y/viewport_size.y*2)
		if absf(ndc.x)>0.72 or absf(ndc.y)>0.9:
			continue
		owned.append({"id":str(row.id),"position":point,"body":body,"score":absf(ndc.x)*2+metres})
	owned.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.score<b.score)
	for row: Dictionary in owned:
		# Source mercenary_targets.hasLineOfSight excludes the intended actor;
		# another visible actor can block this segment. Hero is excluded by metadata.
		if not occlusion.occluded(focus+Vector3.UP*1.15,row.position+Vector3.UP*1.05,[row.body]):
			_talk_target = {"id":row.id,"member":true}
			return
	# Source world.nearestCandidate is horizontal proximity, not camera selection.
	var candidates: Array = host.candidate_rows()
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distanceMeters<b.distanceMeters)
	for row: Dictionary in candidates:
		if row.distanceMeters<=3:
			_talk_target = {"id":str(row.id),"member":false}
			return

func _process(delta: float) -> void:
	if not ready_for_acceptance:
		return
	host.tick()
	_talk_clock += maxf(0,delta)
	if _talk_clock>=0.2:
		_talk_clock = 0
		_refresh_talk_target()
	# Source badges/UI own their bounded process cadence; no duplicate advance.

func _open_roster() -> void:
	if ready_for_acceptance:
		recruitment_ui.open_roster()

func _save_clicked() -> void:
	var receipt: Dictionary = persistence.save_now()
	status_label.text = "Сохранено" if receipt.get("ok",false) else "Ошибка сохранения: "+str(receipt.get("error",receipt.get("reason","")))

func _load_clicked() -> void:
	var receipt: Dictionary = persistence.load_now()
	status_label.text = "Загружено" if receipt.get("ok",false) else "Ошибка загрузки: "+str(receipt.get("error",receipt.get("reason","")))

func _on_bindings_retiring(old_host: RefCounted) -> void:
	# Release the actual tracked conversation while its owner is still live.
	# Emitted only after a successful restore; rejected input preserves the UI.
	if is_same(old_host,host) and is_instance_valid(recruitment_ui):
		recruitment_ui.dispose()

func _on_bindings_changed(next_core: RefCounted,next_host: RefCounted) -> void:
	core = next_core
	host = next_host
	# All old-host holds have ended. Remove their released metadata identities.
	world.prune_released_conversation_rows()
	_talk_target.clear()
	_rebuild_presentation()

func _fail_setup(message: String) -> void:
	setup_error = message
	ready_for_acceptance = false
	push_error(message)

func _exit_tree() -> void:
	ready_for_acceptance = false
	if is_instance_valid(recruitment_ui):
		recruitment_ui.dispose()
	if is_instance_valid(badges):
		badges.dispose()
	if occlusion != null:
		occlusion.dispose()
	if host != null:
		host.dispose()
	if persistence != null:
		persistence.dispose()
	interaction_context.dispose()
	# Fixture owns only its actors; scene tree owns teardown after host callbacks stop.
