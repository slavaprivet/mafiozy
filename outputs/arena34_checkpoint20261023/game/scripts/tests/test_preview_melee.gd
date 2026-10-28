extends SceneTree
## Actual main, actual input routing and source decisions. No damage fixtures.
var checks := 0
var failures: Array[String] = []
var main: Node3D
var player: CharacterBody3D
var host: Node
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func button(index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=index; event.pressed=pressed
	player._unhandled_input(event)
func pause(seconds: float) -> void: await create_timer(seconds).timeout
func run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	main.preview_melee_enabled=false
	root.add_child(main); current_scene=main
	player=main._player
	await pause(.5)
	check(main.preview_ready and player.is_on_floor(),"actual scene grounded")
	check(main._install_preview_melee_practice(),"practice actual rig configured")
	if not is_instance_valid(main.preview_melee):
		finish(); return
	host=main.preview_melee
	check(host.snapshot().targets==0,"practice explicitly owns no combat targets")
	player.set_mouse_captured(false)
	button(MOUSE_BUTTON_LEFT,true)
	check(player._free_mouse_look and host._source.snapshot().attackSeq==0,"first click captures without punching")
	button(MOUSE_BUTTON_LEFT,false)
	player._camera_yaw=.7
	var heading_before: float=player._heading
	button(MOUSE_BUTTON_LEFT,true)
	check(host._source.snapshot().attackSeq==1,"actual click admits source attack")
	check(absf(wrapf(player._heading-heading_before,-PI,PI))<.00001,"camera orbit alone cannot snap source attack facing")
	await pause(.09)
	check(host.last_error.is_empty() and player._pose_affine_active,"actual attack writes physical melee pose")
	check(host.snapshot().action.get("action",{}).get("type","") in ["punch","kick"],"source RNG chooses valid ordinary action")
	button(MOUSE_BUTTON_LEFT,false)
	await pause(.65)
	check(not player._pose_affine_active,"completed action restores ordinary writer")
	check(not host._cooldown and host._source.snapshot().pending.is_empty(),"source cooldown and empty-registry miss complete")
	button(MOUSE_BUTTON_RIGHT,true)
	await pause(.06)
	check(host._source.snapshot().block and player._pose_affine_active,"actual right mouse holds guard")
	var seq: int=host._source.snapshot().attackSeq
	button(MOUSE_BUTTON_LEFT,true); button(MOUSE_BUTTON_LEFT,false)
	check(host._source.snapshot().attackSeq==seq,"block prevents new punch")
	button(MOUSE_BUTTON_RIGHT,false)
	await pause(.12)
	button(MOUSE_BUTTON_LEFT,true)
	await pause(1.25)
	check(host._source.snapshot().animation.type=="heavy","held input admits charged heavy")
	button(MOUSE_BUTTON_LEFT,false)
	player.set_mouse_captured(false)
	check(not host._left_held and not host._source.snapshot().block and host._state.get("start")==null,"Esc/cursor cancellation drops held state")
	await pause(.5)
	check(not player._pose_affine_active and host._source.snapshot().timers==0,"cancelled timers drain without stuck pose")
	player.set_mouse_captured(true)
	button(MOUSE_BUTTON_LEFT,true)
	player.set_preview_pose_authority(&"vehicle")
	check(host._state.get("start")==null and not host._left_held,"vehicle handoff immediately cancels attack")
	seq=host._source.snapshot().attackSeq
	button(MOUSE_BUTTON_LEFT,true)
	check(host._source.snapshot().attackSeq==seq,"vehicle owner rejects attack")
	player.set_preview_pose_authority(&"on_foot",true)
	await pause(.4)
	var edit:=LineEdit.new(); root.add_child(edit); edit.grab_focus()
	button(MOUSE_BUTTON_LEFT,true)
	check(host._source.snapshot().attackSeq==seq,"typing focus prevents attack")
	edit.release_focus(); edit.free()
	button(MOUSE_BUTTON_LEFT,true)
	player._request_preview_jump(float(Time.get_ticks_msec()))
	await pause(.1)
	check(not player._jump.is_empty() and host._state.get("start")==null,"Max Payne jump keeps exclusive pose and cancels practice")
	check(host.last_error.is_empty(),"no host faults")
	check(host.resolve_contact({},{}).accepted==false,"practice cannot authorize a contact")
	finish()
func finish() -> void:
	print("PREVIEW_MELEE ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual scene/input/pose ownership and source admission; zero combat targets or damage"}))
	if is_instance_valid(main): main.free()
	quit(0 if failures.is_empty() else 1)
