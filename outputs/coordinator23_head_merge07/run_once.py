from pathlib import Path
import shutil,json,hashlib,subprocess,time
R=Path.cwd();O=R/'outputs/coordinator23_head_merge07';B=R/'outputs/coordinator23_quality/candidate07/godot/mafiozi_walk';S=O/'stage'
assert not S.exists()
shutil.copytree(B,S,ignore=shutil.ignore_patterns('exports','exported','editor','shader_cache'))
for p in (O/'files').rglob('*'):
 if p.is_file():shutil.copy2(p,S/p.relative_to(O/'files'))
# Bind exact res resource inputs observed before execution; no mutation to source stage.
files=[p for p in S.rglob('*') if p.is_file() and '.godot' not in p.parts]
(O/'STAGE_INPUTS.json').write_text(json.dumps({str(p.relative_to(S)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n',encoding='utf8')
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
cmd=[str(engine),'--headless','--path',str(S),'--fixed-fps','60','--script',str(O/'tests/native_head_only.gd')]
start=time.monotonic()
with (O/'native01.log').open('w',encoding='utf8') as log:
 try:
  p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=90);status={'exit_code':p.returncode}
 except subprocess.TimeoutExpired:status={'timeout':90}
status.update(seconds=time.monotonic()-start,command=cmd)
(O/'RUN01.json').write_text(json.dumps(status,indent=2)+'\n',encoding='utf8');print(json.dumps(status))
