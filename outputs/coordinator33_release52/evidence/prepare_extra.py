from pathlib import Path
O=Path('D:/MafioziCombat31/coordinator33');Q=O/'qa'
p=Q/'matrix_spear_close.gd';s=(Q/'matrix_switch52.gd').read_text();p.write_text(s.replace('987.6 if weapon=="spear" else 988.7','988.3 if weapon=="spear" else 988.7'))
s=Path('D:/MafioziCombat31/armor46/check.gd').read_text(encoding='utf-8-sig').replace('D:/MafioziCombat31/armor46/check06','D:/MafioziCombat31/coordinator33/armor_graphical');(Q/'armor.gd').write_text(s,encoding="utf-8")
s=Path('D:/MafioziCombat31/opponent50/law_parity.gd').read_text(encoding='utf-8-sig').replace('D:/MafioziCombat31/opponent50/LAW_PARITY.json','D:/MafioziCombat31/coordinator33/law/result.json');(Q/'law.gd').write_text(s,encoding="utf-8")
s=(O/'run_qa.py').read_text(encoding='utf-8-sig').split('jobs=[')[0]
s+='''
jobs=[('matrix_spear_close','matrix_spear_close.gd','headless',['--weapon=spear'],False),('law','law.gd','headless',[],False),('player_contact','aimed_player51.gd','headless',['--weapon=sword','--strokes=8','--direction=left'],True)]
if len(sys.argv)>1:jobs=[('armor_graphical','armor.gd','graphical',[],True)]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(run,jobs))
(O/('ARMOR_SUITE.json' if len(sys.argv)>1 else 'EXTRA_SUITE.json')).write_text(json.dumps(rows,indent=2))
'''
# Armor fixture uses uppercase RESULT.
s=s.replace("name in ['spear_high','soil_graphical']","name in ['spear_high','soil_graphical','armor_graphical']")
(O/'run_extra.py').write_text(s,encoding="utf-8")

