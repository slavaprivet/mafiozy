from pathlib import Path
HERE=Path(__file__).resolve().parent
observer=(HERE/'observer_benches58_v2.gd').read_text(encoding='utf-8')
observer=observer.replace('var _reinstall:Dictionary={}','var _reinstall:Dictionary={}\nvar _sleep_proofs:Dictionary={}\nvar _night_started_ms:=-1')
observer=observer.replace('"pose_first_ms":-1}', '"pose_first_ms":-1,"night_displacement":0.0}')
anchor='\t\tif life._goal.get("kind","")=="leisure" and life._roam51_active:'
assert observer.count(anchor)==1
observer=observer.replace(anchor, '''		if _night_started_ms<0 and id in ["resident_2","resident_7"] and life._home58!=null:
			var home:Dictionary=life._home58.snapshot()
			if home.get("sleeping",false) and home.get("support_current",false) and home.get("claim_current",false):
				_sleep_proofs[id]={"home":home,"position":body.global_position,"elapsed_ms":now-_bound}
		if row.has("leisure_start_position"):
			row.night_displacement=maxf(float(row.night_displacement),body.global_position.distance_to(row.leisure_start_position))
'''+anchor+'\n\t\t\tif not row.leisure_started:row["leisure_start_position"]=body.global_position')
observer=observer.replace('\tif now>=_next:', '''	if _night_started_ms<0 and _sleep_proofs.size()==2:
		var clock:RefCounted=get_tree().root.get_meta("mafiozi_visual_clock")
		assert(clock.set_hour(22.5));clock.running=false;_night_started_ms=now
	if now>=_next:''')
observer=observer.replace('"ambient":life._ambient29.snapshot()', '"home":life._home58.snapshot() if life._home58!=null else {},"ambient":life._ambient29.snapshot()')
observer=observer.replace('if now-_bound>=90000:_finish("window_complete")', 'if _night_started_ms>=0 and now-_night_started_ms>=90000:_finish("window_complete")\n\telif now-_bound>=300000:_finish("home_sleep_or_night_timeout")')
observer=observer.replace('for id:String in ["resident_3","resident_5","resident_10"]:', 'checks["both_actual_home_sleep_before_night_walk"]=_sleep_proofs.size()==2\n\tfor id:String in ["resident_2","resident_7"]:')
observer=observer.replace('checks[id+"_no_teleport"]=float(row.get("max_step",INF))<=.2', 'checks[id+"_no_teleport"]=float(row.get("max_step",INF))<=.2\n\t\tchecks[id+"_actual_night_walk"]=row.get("leisure_started",false) and float(row.get("night_displacement",0.0))>=2.0')
observer=observer.replace('"rows":_rows,"samples":_samples,','"rows":_rows,"samples":_samples,"actual_sleep_proofs":_sleep_proofs,"night_started_ms":_night_started_ms,')
observer=observer.replace('Exact stage05 plus routine8 and bench helper overlays; physical home-bench arrival and committed pose. Sleep and night-walker cycle are separate checks.', 'Exact stage05 plus routine8 and bench helper overlays; original residents2/7 physically reach assigned home, sleep, physically exit and walk to real bench with committed pose.')
observer=observer.replace('same shared clock at20.8 paused; no NPC position/health/money writes', 'Same shared clock03:00 paused until both late residents have actual sleep/support/claim proof, then22:30 paused on same day; no NPC position/health/money writes')
observer=observer.replace('BENCHES58.json','NIGHT_BENCHES58.json').replace('BENCHES58_RESULT','NIGHT_BENCHES58_RESULT')
entry=(HERE/'entry_benches58_v2.gd').read_text(encoding='utf-8').replace('clock.set_hour(20.8)','clock.set_hour(3.0)').replace('observer_benches58_v2.gd','observer_night_benches58.gd').replace('NEW_BENCH_RESOURCES58_V2.zip','NEW_NIGHT_BENCH_RESOURCES58.zip')
runner=(HERE/'run_benches58_v2.py').read_text(encoding='utf-8').replace('prepare_benches58_v2.py','prepare_night_benches58.py').replace('entry_benches58_v2.gd','entry_night_benches58.gd').replace('observer_benches58_v2.gd','observer_night_benches58.gd').replace('NEW_BENCH_RESOURCES58_V2.zip','NEW_NIGHT_BENCH_RESOURCES58.zip').replace("'--timeout','180'","'--timeout','390'").replace('timeout=840','timeout=1060').replace('BENCHES58.json','NIGHT_BENCHES58.json')
for filename,content in [('observer_night_benches58.gd',observer),('entry_night_benches58.gd',entry),('run_night_benches58.py',runner)]:
    target=HERE/filename;assert not target.exists();target.write_text(content,encoding='utf-8')
