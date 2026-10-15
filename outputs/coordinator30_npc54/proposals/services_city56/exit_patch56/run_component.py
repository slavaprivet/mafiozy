import os,sys,json,subprocess,time
from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
project=ROOT/'outputs/coordinator30_npc54/game'
engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
with Lease('headless',project,'read',30) as lease:
 with (OUT/'component.stdout').open('wb') as out,(OUT/'component.stderr').open('wb') as err:
  child=subprocess.Popen([str(engine),'--headless','--path',str(project),'--script',str(OUT/'fixture.gd'),'--','--qa-out='+str(OUT/'COMPONENT.json')],stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
  try:
   lease.register_child(child); child.wait(timeout=40)
  finally:
   if child.poll() is None:child.terminate();child.wait(timeout=10)
print((OUT/'component.stdout').read_text(encoding='utf-8'))
print((OUT/'component.stderr').read_text(encoding='utf-8'))
sys.exit(child.returncode)
