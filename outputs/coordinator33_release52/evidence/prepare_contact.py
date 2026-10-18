from pathlib import Path
O=Path('D:/MafioziCombat31/coordinator33');Q=O/'qa'
s=(Q/'matrix_spear_close.gd').read_text();s=s.replace('motion((-10.0 if tick<12 or tick>=24 else 20.0)*(1.0 if attempt%2==0 else -1.0),0)','motion((-10.0 if tick<12 or tick>=24 else 20.0)*(1.0 if attempt%2==0 else -1.0),12.0 if tick<18 else -12.0)');(Q/'matrix_spear_down.gd').write_text(s,encoding='utf-8')
s=(O/'run_qa.py').read_text(encoding='utf-8-sig').split('jobs=[')[0]
s+='''
jobs=[('matrix_spear_down','matrix_spear_down.gd','headless',['--weapon=spear'],False),('armored_contact','aimed_player51.gd','headless',['--weapon=sledge','--strokes=8','--direction=left','--armor=heavy'],True)]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(run,jobs))
(O/'CONTACT_SUITE.json').write_text(json.dumps(rows,indent=2))
''';(O/'run_contact.py').write_text(s,encoding='utf-8')
