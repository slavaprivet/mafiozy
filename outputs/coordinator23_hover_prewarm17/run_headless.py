from pathlib import Path
import subprocess,time,json,hashlib
r=Path.cwd();o=r/'outputs/coordinator23_hover_prewarm17';stage=o/'stage';engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
cmd=[str(engine),'--headless','--path',str(stage),'--fixed-fps','60','--script',str(o/'test_native.gd')];start=time.monotonic()
with (o/'native01.log').open('w',encoding='utf8') as log:
 try:p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=55);result={'exit_code':p.returncode}
 except subprocess.TimeoutExpired:result={'timeout':55}
result.update(command=cmd,seconds=time.monotonic()-start);(o/'RUN01.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8');print(json.dumps(result))
