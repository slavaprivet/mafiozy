from pathlib import Path
import hashlib,json,os,subprocess,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
name=sys.argv[1] if len(sys.argv)>1 else 'policy01'
project=HERE/'policy_projects'/name
project.mkdir(parents=True,exist_ok=False)
copies={'day_night_clock.gd':HERE/'patch/scripts/quick_controls/day_night_clock.gd','npc_routine58.gd':HERE/'patch/scripts/city/runtime/npc_routine58.gd','checks.gd':HERE/'check_policy58.gd'}
for target,path in copies.items(): (project/target).write_bytes(path.read_bytes())
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Routine58 policy check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pins={name:sha(path) for name,path in copies.items()}
(project/'PINS.json').write_text(json.dumps(pins,indent=2)+'\n',encoding='utf-8')
engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
command=[sys.executable,str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode','headless','--project',str(project),'--access','write','--wait-seconds','60','--timeout','30','--out',str(HERE/'runs'/name),'--',str(engine),'--headless','--path',str(project),'--script','res://checks.gd']
result=subprocess.run(command,timeout=120,capture_output=True)
after={name:sha(path) for name,path in copies.items()}
print(json.dumps({'code':result.returncode,'source_drift':pins!=after,'output':str(HERE/'runs'/name)},ensure_ascii=True))
if result.returncode: print(result.stdout.decode('utf-8','replace')[-3000:]);print(result.stderr.decode('utf-8','replace')[-1000:])
sys.exit(result.returncode if pins==after else 3)
