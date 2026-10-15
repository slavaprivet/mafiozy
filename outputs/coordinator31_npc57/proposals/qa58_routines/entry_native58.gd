extends SceneTree
## Ordinary startup and native N/T inputs. No resident intent/body substitutions.
const Benches=preload("res://scripts/npc_ambient/ambient_bench_registry29.gd")
var scene: Node3D
var output: String
var test_case:="startup"
var checks:Array=[]
var result:Dictionary={"scope":"Exact combined source ordinary startup; short coverage only, not full behavioral/performance acceptance","samples":[]}
var started:int
func _initialize()->void:_start.call_deferred()
func check(ok:bool,name:String,detail:Variant=null)->bool:
	checks.append({"ok":ok,"name":name,"detail":detail});return ok
func finish()->void:
	result.checks=checks;result.passed=checks.all(func(c:Dictionary)->bool:return c.ok)
	result.elapsed_s=float(Time.get_ticks_usec()-started)/1000000.0
	var file:=FileAccess.open(output.path_join("NATIVE58.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE58 terminal case=",test_case," passed=",result.passed," checks=",checks.size())
	quit(0 if result.passed else 1)
func key(code:Key,down:bool)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;Input.parse_input_event(event)
func tap(code:Key)->void:
	key(code,true);await physics_frame;key(code,false);await process_frame
func clock_row()->Dictionary:
	var clock:RefCounted=root.get_meta("mafiozi_visual_clock")
	return {"hour":clock.hour,"day":clock.day_index,"running":clock.running,"frame":Engine.get_physics_frames(),"at_us":Time.get_ticks_usec()}
func sample()->void:
	var rows:Array=[]
	for id:String in scene.preview_population.daily._lives:
		var life:RefCounted=scene.preview_population.daily._lives[id]
		var body:CharacterBody3D=life._token.body
		rows.append({"id":id,"generation":life._token.life_generation,"position":[body.global_position.x,body.global_position.y,body.global_position.z],"phase":life._phase,"goal":life._goal.duplicate(true),"next_decision_ms":life._next_decision,"now_ms":life._now,"routine":life._routine58.snapshot() if life._routine58!=null else {},"home":life._home58.snapshot() if life._home58!=null else {},"economy_phase":life._economy28._phase if life._economy28!=null else "","completed":life._completed.duplicate(true),"ambient_active":life._ambient29.active() if life._ambient29!=null else false})
	result.samples.append({"clock":clock_row(),"actors":rows})
func observe(seconds:float)->void:
	var stop:int=Time.get_ticks_usec()+int(seconds*1000000);var next:int=Time.get_ticks_usec()
	while Time.get_ticks_usec()<stop:
		await process_frame
		if Time.get_ticks_usec()>=next:sample();next+=1000000
func _start()->void:
	started=Time.get_ticks_usec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-case="):test_case=arg.trim_prefix("--qa-case=")
	if output.is_empty():quit(2);return
	scene=load("res://scenes/main_city.tscn").instantiate();root.add_child(scene);current_scene=scene
	var stop:int=Time.get_ticks_msec()+110000
	while Time.get_ticks_msec()<stop:
		await process_frame
		if scene.preview_ready and scene.preview_population!=null and scene.preview_population.city_ready and scene.preview_population.city_stream_complete() and scene.preview_population.daily._lives.size()==10:break
	if not check(scene.preview_ready and scene.preview_population!=null and scene.preview_population.city_ready and scene.preview_population.city_stream_complete(),"ordinary city READY"):finish();return
	check(Engine.physics_ticks_per_second==60,"native physics60",Engine.physics_ticks_per_second)
	check(scene.preview_population.daily._lives.size()==10 and scene.preview_population.residents._records.size()==287,"ten residents and catalogue287")
	var homes:Dictionary=scene.preview_homes58.registry58.snapshot()
	check(homes.homes==4 and homes.beds==10 and homes.available_beds==10,"four real homes and ten current beds",homes)
	var benches:Node=Benches.for_scene(scene)
	check(benches.rows().size()==9 and benches.rows().all(func(row:Dictionary)->bool:return benches.current(row)),"nine native current benches",benches.snapshot())
	check(scene.preview_service_sites29.current_sites().size()==8,"eight compact service sites")
	var staff:Array=scene.preview_venue_staff29._rows.values()
	check(staff.size()==12 and staff.all(func(row:Dictionary)->bool:return is_instance_valid(row.actor) and row.actor.is_inside_tree()),"twelve live service staff",staff.size())
	var shop:Node=scene.player_shop;var throwables:Node=scene.player_throwables
	if not check(is_instance_valid(shop) and shop.ready_for_use,"ordinary player shop bound"):finish();return
	result.shop=shop.snapshot();result.throwables=throwables.snapshot() if is_instance_valid(throwables) else {}
	check(shop._c4_bound,"native purchased-C4 provider bound")
	check(is_instance_valid(throwables) and throwables.snapshot().ready,"native throwables bound")
	check(shop._keepers.size()==1,"one weapon-shop keeper",shop._keepers.size())
	var clock:RefCounted=root.get_meta("mafiozi_visual_clock")
	var profiles:Array=[];var all_shared:=true
	for life:RefCounted in scene.preview_population.daily._lives.values():
		all_shared=all_shared and life._routine58!=null and life._routine58_clock()==clock
		if life._routine58!=null:profiles.append(life._routine58.snapshot().profile)
	check(all_shared and profiles.size()==10,"all ten read the same native clock",profiles)
	var begin:Dictionary=clock_row();await observe(15.0);var end:Dictionary=clock_row()
	check(end.hour>begin.hour and end.day==begin.day,"ordinary shared clock advances",{"before":begin,"after":end})
	result.ready_observation={"before":begin,"after":end,"actual_physics_ticks":end.frame-begin.frame}
	if test_case=="clock":await clock_case()
	finish()
func clock_case()->void:
	result.scope="Exact combined source native N/T day/night control with ordinary residents; controlled clock scenario, not natural full-day acceptance"
	if not scene._player._free_mouse_look:
		var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down)
		await physics_frame
		var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up)
		await process_frame
	await tap(KEY_T);var paused:Dictionary=clock_row();await observe(2.0);var still:Dictionary=clock_row()
	check(not paused.running and not still.running and absf(still.hour-paused.hour)<.0000001,"native T pauses shared clock",{"before":paused,"after":still})
	check(still.frame-paused.frame>=110,"native physics continues during clock pause",still.frame-paused.frame)
	await tap(KEY_T);check(clock_row().running,"native T resumes shared clock")
	var day:int=clock_row().day
	await tap(KEY_N);await observe(2.3);var night:Dictionary=clock_row()
	check(night.hour>=22.0 and night.hour<22.1 and night.day==day,"native N reaches night without minting day",night)
	await tap(KEY_N);await observe(2.3);var noon:Dictionary=clock_row()
	check(noon.hour>=12.0 and noon.hour<12.1 and noon.day==day,"native N returns to noon on same day",noon)
