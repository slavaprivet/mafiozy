from pathlib import Path
import shutil
O=Path('D:/MafioziCombat31/coordinator33');Q=O/'qa';Q.mkdir(exist_ok=True)
for root in ['resume52_allweapons','resume51_opponent']:
 for p in (Path('D:/MafioziCombat31')/root).glob('*.gd'):shutil.copy2(p,Q/p.name)
for name,src in [('bow52.gd','resume52_bow/bow52_v2.gd'),('spear52.gd','resume52_spear/spear52_v3.gd')]:
 s=(Path('D:/MafioziCombat31')/src).read_text(encoding='utf-8-sig')
 s=s.replace('D:/MafioziCombat31/resume52_bow/',str(O/'bow_high')+'/').replace('D:/MafioziCombat31/resume52_spear/RESULT03.json',str(O/'spear_high/RESULT.json'))
 (Q/name).write_text(s,encoding='utf-8')
S=Path('C:/Users/Слава/Documents/Codex/2026-10-08/task-7/SOIL49_RECOVERY_20261018T154550Z')
s=(S/'provenance/check.gd').read_text(encoding='utf-8-sig').replace('D:/MafioziCombat31/soil49_resume/check07',str(O/'soil_graphical')).replace('D:/MafioziCombat31/soil49_resume/terrain.base.gd',str(S/'provenance/terrain.base.gd')).replace('D:/MafioziCombat31/soil49_resume/shader.base.gdshader',str(S/'provenance/shader.base.gdshader'))
(Q/'soil.gd').write_text(s,encoding='utf-8')
for name in ['bow_high','spear_high']: (O/name).mkdir(exist_ok=True)
