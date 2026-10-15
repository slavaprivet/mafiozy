from pathlib import Path
import hashlib,json,difflib
HERE=Path(__file__).resolve().parent
SOURCE=HERE.parents[1]/'game'
PATCH=HERE/'patch'
records=[]
def sha(data): return hashlib.sha256(data).hexdigest()
def edit(name, changes):
    path=SOURCE/name; raw=path.read_bytes(); before=raw.decode('utf-8-sig').replace('\r\n','\n'); after=before
    for old,new in changes:
        assert after.count(old)==1,(name,old[:100],after.count(old))
        after=after.replace(old,new)
    target=PATCH/name;target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(after,encoding='utf-8',newline='')
    records.append({'path':name,'base_sha256':sha(raw),'sha256':sha(target.read_bytes())})
    return ''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='base/'+name,tofile='patch/'+name))

diff=''
diff+=edit('scripts/quick_controls/day_night_clock.gd',[
('## Visual time only: no connection to NPC schedules, saving, or the economy.', '## Shared visual/routine time. Physics deadlines and transaction authority stay with their owners.'),
('var hour := 17.5','var day_index := 0\nvar hour := 17.5'),
('\tvar next := fposmod(elapsed + fposmod(delta, CYCLE_SECONDS), CYCLE_SECONDS)',
 '\t# Midnight is 4500s on the dawn-based axis. Whole cycles count once each.\n\t# Clamp only absurd >2-billion-day inputs before integer conversion.\n\tvar crossings: float = floorf((elapsed + delta + 900.0) / CYCLE_SECONDS) - floorf((elapsed + 900.0) / CYCLE_SECONDS)\n\tday_index = mini(2147483647, day_index + int(minf(crossings, 2147483647.0)))\n\tvar next := fposmod(elapsed + fposmod(delta, CYCLE_SECONDS), CYCLE_SECONDS)'),
('\thour = fposmod(value, 24.0)\n\treturn true', '\t# Manual clock setting selects another time on this same day. N calls this\n\t# repeatedly during its visual transition; it must not mint new daily errands.\n\thour = fposmod(value, 24.0)\n\treturn true')])

diff+=edit('scripts/shop/npc_economy_visit28.gd',[
('var _reason := ""', 'var _reason := ""\nvar _routine_failures58 := 0\nvar _routine_defer_until58 := 0.0'),
('\t_pending = {"kind":kind,"price":_rng.randi_range(5, 50),"restore_energy":energy}', '\t_pending = {"kind":kind,"price":_rng.randi_range(5, 50),"restore_energy":energy}\n\t_routine_failures58=0; _routine_defer_until58=0.0'),
('func request_food() -> void:', '''## Routine chooses only a purpose; this owner still chooses/stores the price,
## obtains the actual venue, and retains the same purchase through a bank detour.
func request_routine58(kind: String, ticket: String) -> bool:
	if not current() or active() or ticket.is_empty() or kind not in ["shop", "restaurant"]: return false
	if not _pending.is_empty(): return _pending.get("routine_ticket58", "") == ticket
	_choose_purchase(kind, kind == "restaurant")
	_pending["routine_ticket58"] = ticket
	return true

func request_food() -> void:'''),
('func request_food() -> void:\n\tif not current(): return', 'func request_food() -> void:\n\tif not current(): return\n\t# Actual urgent energy need outranks discretionary overnight/defer policy.\n\t_routine_failures58=0; _routine_defer_until58=0.0'),
('func desired_kind(now_ms: float) -> String:\n\tif not current() or active() or now_ms < _retry_at: return ""', 'func desired_kind(now_ms: float) -> String:\n\tif not current() or active() or now_ms < _retry_at or routine_deferred58(now_ms): return ""'),
('\t\t_phase = "IDLE"; _retry_at = now_ms + RETRY_MS; _log("blocked", _reason); return false', '\t\t_phase = "IDLE"; _retry_at = now_ms + RETRY_MS; _routine_failure58(now_ms); _log("blocked", _reason); return false'),
('\t\t_log("deferred", _reason); return false', '\t\t_routine_failure58(now_ms)\n\t\t_log("deferred", _reason); return false'),
('\t\t_route.cancel(); _route = null; _phase = "IDLE"; _retry_at = now_ms + RETRY_MS\n\t\t_log("blocked", _reason); return false', '\t\t_route.cancel(); _route = null; _phase = "IDLE"; _retry_at = now_ms + RETRY_MS\n\t\t_routine_failure58(now_ms)\n\t\t_log("blocked", _reason); return false'),
('\t\tif _kind != "bank":\n\t\t\tif bool(_pending.get("restore_energy", false))', '\t\tif _kind != "bank":\n\t\t\t_receipt["routine_ticket58"] = str(_pending.get("routine_ticket58", ""))\n\t\t\tif bool(_pending.get("restore_energy", false))'),
('\t\t\t_pending.clear()\n\t\t\tMoneyPopup.show_debit', '\t\t\tlife._routine58_paid(self, _receipt)\n\t\t\t_pending.clear()\n\t\t\tMoneyPopup.show_debit'),
('\t_retry_at = _now + 1000.0 if completed or not _interrupted.is_empty() else _now + RETRY_MS', '\t_retry_at = _now + 1000.0 if completed or not _interrupted.is_empty() else _now + RETRY_MS\n\tif not completed and _interrupted.is_empty(): _routine_failure58(_now)'),
('"pending":_pending.duplicate(true),"planned_amount"', '"pending":_pending.duplicate(true),"routine_failures58":_routine_failures58,"routine_defer_until58":_routine_defer_until58,"planned_amount"')])
p=PATCH/'scripts/shop/npc_economy_visit28.gd'
p.write_text(p.read_text(encoding='utf-8')+'\n'+(HERE/'economy_additions58.txt').read_text(encoding='utf-8'),encoding='utf-8',newline='')
records[-1]['sha256']=sha(p.read_bytes())

diff+=edit('scripts/npc_ambient/ambient_controller28.gd',[
('func try_begin() -> bool:', 'func try_begin(allowed: Array = []) -> bool:'),
('\tvar choices: Array = Pose.KINDS.duplicate()\n\tchoices.erase(_previous)', '\tvar choices: Array = Pose.KINDS.duplicate()\n\tif not allowed.is_empty():\n\t\tchoices = choices.filter(func(kind: String) -> bool: return kind in allowed)\n\tchoices.erase(_previous)')])

diff+=edit('scripts/npc_city_daily.gd',[
('\treturn life._roam51_active or life._dsh_simple_goal_active()', '\treturn life._routine58_home_active() or life._routine58_rest_active() or life._roam51_active or life._dsh_simple_goal_active()')])

diff+=edit('scripts/city/runtime/npc_threat_life30.gd',[
('\tlife._ambient29_cancel("threat")\n\tif life._economy28_active()', '\tlife._ambient29_cancel("threat")\n\tif not life._routine58_release_home("threat"): return false\n\tif life._economy28_active()')])

daily_additions=(HERE/'daily_additions58.txt').read_text(encoding='utf-8')
daily_source=(SOURCE/'scripts/npc_daily_life.gd').read_text(encoding='utf-8-sig')
old_roam=daily_source[daily_source.index('# Finite local random legs'):daily_source.index('func _choose(row: Dictionary)')]
diff+=edit('scripts/npc_daily_life.gd',[
('const ThreatLife30 = preload(', 'const Routine58 = preload("res://scripts/city/runtime/npc_routine58.gd")\nconst Leisure58 = preload("res://scripts/city/runtime/npc_leisure58.gd")\nvar _routine58: RefCounted\nvar _leisure58: RefCounted\nvar _leisure_arrived58 := false\nvar _home58: RefCounted\nvar _home_intent58 := ""\nvar _rest_driver58: RefCounted\nvar _home_retry58 := 0.0\nconst ThreatLife30 = preload('),
('\tif _dsh_simple_on():\n\t\t_economy28_prepare()\n\t\t_next_decision', '\tif _dsh_simple_on():\n\t\t_routine58 = Routine58.new(); _routine58.configure(str(token.source_id))\n\t\t_economy28_prepare()\n\t\t_next_decision'),
('\t\t\tif result != "active": _phase="IDLE"; _next_decision=_now', '\t\t\tif result != "active":\n\t\t\t\tif _routine58 != null: _routine58.after_ambient(_now, _sandbox28_random(), _routine58_clock())\n\t\t\t\t_phase="IDLE"; _next_decision=_now'),
('\tif _dsh_simple_goal_active():\n\t\tif _health.should_pause_walk()', '\tif _routine58_home_active():\n\t\t_routine58_step_home(delta, row)\n\t\t_dsh_energy_drain(); _dsh_resdiag_step(row); _busy=false; return\n\tif _dsh_simple_goal_active():\n\t\tif _health.should_pause_walk()'),
('\t_dsh_energy_drain()  # DSH_ENERGY: spent by the metres', '\tif _routine58_rest_active(): _routine58_hold(delta)\n\t_dsh_energy_drain()  # DSH_ENERGY: spent by the metres'),
('\t\t\tvar roam_result: String = _roam51.step(delta)', '\t\t\tvar leisure_lost: bool = _leisure58 != null and not _leisure58.current()\n\t\t\tvar roam_result: String = "blocked" if leisure_lost else _roam51.step(delta)'),
('\t\t\t\tvar roam_reason: String=_roam51.last_reason()', '\t\t\t\tvar roam_reason: String="leisure_bench_removed" if leisure_lost else _roam51.last_reason()\n\t\t\t\t_leisure_arrived58=roam_result=="arrived"\n\t\t\t\tif _routine58 != null: _routine58.leisure_attempt(_now,_leisure_arrived58)\n\t\t\t\tif _leisure58 != null: _leisure58.clear()'),
('\t_ambient29_cancel("hit")\n\tif _disposed', '\t_ambient29_cancel("hit")\n\tif _routine58_home_active(): _home58.request_wake("hit")\n\tif _disposed'),
('\tif _economy28_active() and _hospital51_below_threshold(row):', '\tif _routine58_home_active() and _hospital51_below_threshold(row):\n\t\treturn {"ok":true,"reason":"hospital_pending_physical_home_exit","goal":"hospital"}\n\tif _economy28_active() and _hospital51_below_threshold(row):'),
('\tif _visit != null or _restaurant28_active() or _economy28_active(): return false', '\tif _visit != null or _restaurant28_active() or _economy28_active() or _routine58_home_active(): return false'),
('\tif not _economy28_prepare(): return\n\tvar action: String = _economy28.note_roam_arrived(goal_id)', '\t# The logical policy selects service intents independently of travelled legs.\n\tif _routine58 != null: return\n\tif not _economy28_prepare(): return\n\tvar action: String = _economy28.note_roam_arrived(goal_id)'),
('\tif _dsh_simple_goal_active() or _restaurant28_active() or _visit != null or _hospital51_below_threshold(row): return false', '\tif _dsh_simple_goal_active() or _restaurant28_active() or _visit != null or _hospital51_below_threshold(row) or _routine58_home_active(): return false'),
('\tif not _economy28.has_pending_need(): return false', '\tif not _economy28.has_pending_need() or _routine58_purchase_deferred(): return false'),
('and not _economy28.optional_retry56(_now))', 'and not _economy28.optional_retry56(_now) and not _routine58_purchase_deferred())'),
(old_roam,(HERE/'leisure_begin58.txt').read_text(encoding='utf-8')+'\n\n'),
('\t\tif dsh_take_ambient28_choice() and _ambient29_start(): return\n\t\t_roam51_begin()\n\t\treturn', '\t\t_routine58_choose(row)\n\t\treturn'),
('\t_ambient29_cancel("death")\n\t_hospital28_clear_treatment_pose()', '\t_ambient29_cancel("death")\n\tif _home58 != null: _home58.cancel("death"); _home58=null\n\tif _rest_driver58 != null: _rest_driver58.cancel(); _rest_driver58=null\n\tif _routine58 != null: _routine58.clear()\n\t_hospital28_clear_treatment_pose()'),
('\tif _disposed or _busy: return\n\t_hospital28_clear_treatment_pose()', '\tif _disposed or _busy: return\n\tif _home58 != null: _home58.cancel("disposed"); _home58=null\n\tif _rest_driver58 != null: _rest_driver58.cancel(); _rest_driver58=null\n\tif _routine58 != null: _routine58.clear()\n\t_hospital28_clear_treatment_pose()'),
('"sandbox28_action":_sandbox28_action,"pending_needs"', '"sandbox28_action":_sandbox28_action,"routine58":_routine58.snapshot() if _routine58!=null else {},"home58":_home58.snapshot() if _home58!=null else {},"pending_needs"'),
('func _ambient29_start() -> bool:\n\tif not _walk.cancel()', 'func _ambient29_start(allowed: Array = []) -> bool:\n\tif _routine58_home_active(): return false\n\tif not _walk.cancel()'),
('\tif not _ambient29.try_begin(): return false', '\tif not _ambient29.try_begin(allowed): return false')])
p=PATCH/'scripts/npc_daily_life.gd'; p.write_text(p.read_text(encoding='utf-8')+'\n'+daily_additions,encoding='utf-8',newline='')
records[-1]['sha256']=sha(p.read_bytes())
new=PATCH/'scripts/city/runtime/npc_routine58.gd'
records.append({'path':new.relative_to(PATCH).as_posix(),'base_sha256':None,'sha256':sha(new.read_bytes())})
new=PATCH/'scripts/city/runtime/npc_leisure58.gd'
records.append({'path':new.relative_to(PATCH).as_posix(),'base_sha256':None,'sha256':sha(new.read_bytes())})
# Recompute the complete diff after appended daily integration.
diff=''
for row in records:
    old=(SOURCE/row['path']).read_text(encoding='utf-8-sig') if row['base_sha256'] else ''
    new=(PATCH/row['path']).read_text(encoding='utf-8')
    diff+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='base/'+row['path'],tofile='patch/'+row['path']))
(HERE/'PATCH.diff').write_text(diff,encoding='utf-8')
(HERE/'PATCH.json').write_text(json.dumps({'schema':'logical_routines58_patch_v1','production_edited':False,'files':records,'home_controller_required':'scripts/homes/npc_home_controller58.gd','native_acceptance':'PENDING'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'files':len(records),'production_edited':False}))
