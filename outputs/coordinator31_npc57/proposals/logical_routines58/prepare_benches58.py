from pathlib import Path
HERE=Path(__file__).resolve().parent
entry=(HERE/'entry_parse58_v3.gd').read_text(encoding='utf-8')
entry=entry[:entry.index('\tvar out_path: String=""')].replace('NEW_RESOURCES58.zip','NEW_BENCH_RESOURCES58.zip')+'''
	var clock=load("res://scripts/quick_controls/day_night_clock.gd").new()
	clock.set_hour(20.8);clock.running=false
	root.set_meta("mafiozi_visual_clock",clock)
	var scene:Node=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	scene.add_child(load(here.path_join("observer_benches58.gd")).new())
'''
target=HERE/'entry_benches58.gd';assert not target.exists();target.write_text(entry,encoding='utf-8')
