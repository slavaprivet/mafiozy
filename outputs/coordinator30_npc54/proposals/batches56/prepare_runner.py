from pathlib import Path
import json

here = Path(__file__).resolve().parent
source = (here.parent / 'cpu_perf56/run_city56.py').read_text(encoding='utf-8')
source = source.replace("default=16,choices=[1,3,16,64,200,287]", "default=10,choices=list(range(10,281,10))+[287]")
source = source.replace("OUT/'entry_city56.gd'", "OUT/'entry_batch56.gd'")
(here / 'run_batch56.py').write_text(source, encoding='utf-8')
entry = '''extends SceneTree
func _initialize() -> void:_start.call_deferred()
func _start() -> void:
\tvar count: int=10
\tfor arg: String in OS.get_cmdline_user_args():
\t\tif arg.begins_with("--qa-residents="):count=int(arg.trim_prefix("--qa-residents="))
\tvar scene: Node3D=load("res://scenes/main_city.tscn").instantiate()
\troot.add_child(scene);current_scene=scene
\tscene.add_child(load(get_script().resource_path.get_base_dir().path_join("../mass30/observer_mass30.gd")).new())
\tDisplayServer.window_set_title("Мафиози — ПРОВЕРКА ПАРТИИ: %d ЖИТЕЛЕЙ" % count)
'''
(here / 'entry_batch56.gd').write_text(entry, encoding='utf-8')
policy = {'schema':'mafiozi.batched_population56/v1','user_request':'Внедрять и проверять по 10 жителей вместо всей массы сразу.','initial_residents':10,'increment':10,'full_catalogue_retained':287,'staff':12,'increase_only_after':['no native script errors','original admitted identities and actual movement','venue cycle evidence','rendered FPS and frame latency measured'],'first_playable_delivery':10,'mass_performance_fixed':False}
(here / 'POLICY.json').write_text(json.dumps(policy,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
