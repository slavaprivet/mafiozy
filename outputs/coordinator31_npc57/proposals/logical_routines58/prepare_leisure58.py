from pathlib import Path
HERE=Path(__file__).resolve().parent
entry=(HERE/'entry_parse58_v3.gd').read_text(encoding='utf-8')
entry=entry[:entry.index('\tvar out_path: String=""')]+'''
	var clock=load("res://scripts/quick_controls/day_night_clock.gd").new()
	clock.set_hour(22.5);clock.running=false
	root.set_meta("mafiozi_visual_clock",clock)
	var scene:Node=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	scene.add_child(load(here.path_join("observer_leisure58.gd")).new())
'''
target=HERE/'entry_leisure58.gd';assert not target.exists();target.write_text(entry,encoding='utf-8')
runner=(HERE/'run_parse58_v3.py').read_text(encoding='utf-8').replace('entry_parse58_v3.gd','entry_leisure58.gd').replace("HERE/'prepare_parse_v3.py'","HERE/'prepare_leisure58.py',HERE/'observer_leisure58.gd'")
runner=runner.replace("'--timeout','30'","'--timeout','180'").replace('timeout=120','timeout=250').replace("'PARSE58.json'","'LEISURE58.json'")
runner=runner.replace("command=[sys.executable", "assembly=ROOT/'outputs/coordinator31_release57/ASSEMBLY.json'\ncandidate=ROOT/'outputs/coordinator31_npc57/extended31/stage58_04/CANDIDATE58.json'\nassert read(candidate)['source_pins']==before\nflags=read(assembly)['launch_arguments']\ncontrols += [assembly,candidate]\ncp={str(p):sha(p) for p in controls}\ncommand=[sys.executable")
runner=runner.replace("'--qa-out='+str(run)]","'--qa-out='+str(run),*flags]")
target=HERE/'run_leisure58.py';assert not target.exists();target.write_text(runner,encoding='utf-8')
