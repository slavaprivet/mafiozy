from pathlib import Path
HERE=Path(__file__).resolve().parent
entry=(HERE/'entry_parse58_v2.gd').read_text(encoding='utf-8')
entry=entry.replace('["scripts/city/runtime/npc_routine58.gd",','["scripts/city/runtime/npc_routine58.gd","scripts/city/runtime/npc_leisure58.gd",')
entry=entry.replace('parsed.size()==7','parsed.size()==manifest.files.size()')
entry=entry.replace('\tvar file=FileAccess.open(out_path.path_join("PARSE58.json"),FileAccess.WRITE)', '\tvar checks: Dictionary=_counter_checks58()\n\tvar file=FileAccess.open(out_path.path_join("PARSE58.json"),FileAccess.WRITE)')
entry=entry.replace('"parsed":parsed,','"parsed":parsed,"counter_checks":checks,')
entry=entry.replace('\tquit(0)','\tquit(0 if not checks.values().has(false) else 2)')
entry+='''
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
'''
target=HERE/'entry_parse58_v3.gd';assert not target.exists();target.write_text(entry,encoding='utf-8')
runner=(HERE/'run_parse58_v2.py').read_text(encoding='utf-8').replace('entry_parse58_v2.gd','entry_parse58_v3.gd').replace("HERE/'prepare_parse_v2.py'","HERE/'prepare_parse_v3.py',HERE/'economy_additions58.txt',HERE/'leisure_begin58.txt'")
target=HERE/'run_parse58_v3.py';assert not target.exists();target.write_text(runner,encoding='utf-8')
