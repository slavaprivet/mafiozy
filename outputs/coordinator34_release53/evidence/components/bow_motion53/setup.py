from pathlib import Path
import json,hashlib,shutil
R=Path.cwd(); O=Path('D:/MafioziCombat31/bow_motion53'); G=O/'game';a=json.loads((R/'outputs/coordinator31_castle_current/ASSEMBLY.json').read_text(encoding='utf-8-sig'));base=R/a['game_relative']
for r,h in a['source_pins'].items():
 p=base/r;assert hashlib.sha256(p.read_bytes()).hexdigest()==h,r
 q=G/r;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
(O/'BASE.json').write_text(json.dumps(a,indent=2))
print(len(a['source_pins']))
