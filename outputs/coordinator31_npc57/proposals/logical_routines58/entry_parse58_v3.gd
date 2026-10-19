extends SceneTree
var held58: Array[Script] = []
func _initialize() -> void: _start.call_deferred()
func _start() -> void:
	await create_timer(3.0).timeout
	var here: String=get_script().resource_path.get_base_dir()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(here.path_join("PATCH.json")))
	var rows: Dictionary={}
	for row: Dictionary in manifest.files:
		rows[row.path]=row
		if row.base_sha256 != null: assert(FileAccess.get_sha256("res://"+row.path)==row.base_sha256)
		else: assert(not FileAccess.file_exists("res://"+row.path))
	# New resource IDs must exist in the VFS before a preload parses their path.
	assert(ProjectSettings.load_resource_pack(here.path_join("NEW_RESOURCES58.zip"),true))
	var parsed: Array=[]
	for rel: String in ["scripts/city/runtime/npc_routine58.gd","scripts/city/runtime/npc_leisure58.gd","scripts/quick_controls/day_night_clock.gd","scripts/shop/npc_economy_visit28.gd","scripts/npc_ambient/ambient_controller28.gd","scripts/city/runtime/npc_threat_life30.gd","scripts/npc_daily_life.gd","scripts/npc_city_daily.gd"]:
		var path: String=here.path_join("patch").path_join(rel)
		assert(FileAccess.get_sha256(path)==rows[rel].sha256)
		var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path)
		script.take_over_path("res://"+rel)
		var code: int=script.reload()
		if code!=OK or not script.can_instantiate(): quit(2);return
		held58.append(script)
		assert(load("res://"+rel)==script);parsed.append(rel)
	var out_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out_path=arg.trim_prefix("--qa-out=")
	assert(not out_path.is_empty())
	var checks: Dictionary=_counter_checks58()
	var file=FileAccess.open(out_path.path_join("PARSE58.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":parsed.size()==manifest.files.size(),"parsed":parsed,"counter_checks":checks,"scope":"Native GDScript compile and original resource identity only; no city behavior acceptance"},"\t"));file.close()
	quit(0 if not checks.values().has(false) else 2)

class CounterHost58 extends RefCounted:
	func target_current(_token: Dictionary)->bool:return true
class CounterAccount58 extends RefCounted:
	func snapshot()->Dictionary:return {"account":{"cash":1000}}
class CounterLife58 extends RefCounted:
	var _disposed:=false
	var _token:Dictionary={}
	var _account:RefCounted
func _counter_checks58()->Dictionary:
	# Only the failure/defer policy is under test; these doubles cannot settle.
	var account=CounterAccount58.new();var host=CounterHost58.new();var life=CounterLife58.new()
	life._account=account
	var economy=load("res://scripts/shop/npc_economy_visit28.gd").new()
	economy._life=weakref(life);economy._host=host;economy._account=account;economy._token=life._token
	var checks:Dictionary={"routine_request":economy.request_routine58("restaurant","test:meal")}
	var pending:Dictionary=economy._pending.duplicate(true)
	economy._routine_failure58(1000.0);economy._routine_failure58(2000.0)
	checks["first_two_not_deferred"]=not economy.routine_deferred58(2000.0)
	economy._routine_failure58(3000.0)
	checks["third_failure_defers_45s"]=economy.routine_deferred58(47999.0) and not economy.routine_deferred58(48000.0)
	checks["defer_keeps_ticket_and_price"]=economy._pending==pending
	checks["defer_refuses_start"]=economy.desired_kind(4000.0)==""
	economy.request_food()
	checks["urgent_food_clears_defer"]=not economy.routine_deferred58(4000.0) and economy._pending.price==pending.price and economy._pending.routine_ticket58==pending.routine_ticket58
	return checks
