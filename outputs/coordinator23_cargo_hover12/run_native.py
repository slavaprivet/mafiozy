from pathlib import Path
import shutil,json,hashlib,subprocess,time
R=Path.cwd();O=R/'outputs/coordinator23_cargo_hover12';S=O/'stage'
for origin in [R/'outputs/coordinator23_cargo_controls13/files',O/'files']:
 for p in origin.rglob('*.gd'):shutil.copy2(p,S/p.relative_to(origin))
(O/'STAGE_INPUTS.json').write_text(json.dumps({str(p.relative_to(S)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in S.rglob('*') if p.is_file() and '.godot' not in p.parts},indent=2)+'\n',encoding='utf8')
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');cmd=[str(engine),'--headless','--path',str(S),'--fixed-fps','60','--script',str(O/'test_native.gd')];start=time.monotonic()
with (O/'native01.log').open('w',encoding='utf8') as f:
 try:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=55);result={'exit_code':r.returncode}
 except subprocess.TimeoutExpired:result={'timeout':55}
result.update(seconds=time.monotonic()-start,command=cmd);(O/'RUN01.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8');print(json.dumps(result))

