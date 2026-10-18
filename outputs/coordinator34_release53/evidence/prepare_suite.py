from pathlib import Path
import json, hashlib, shutil
O=Path(__file__).parent
G=O/'game'
for p in (O/'qa').glob('*.gd'):
    s=p.read_text(encoding='utf-8-sig')
    s=s.replace('D:/MafioziCombat31/coordinator33/',O.as_posix()+'/')
    p.write_text(s,encoding='utf-8')
shutil.copy2('C:/Users/Слава/Desktop/Мафиози/outputs/coordinator31_castle_current/bootstrap_castle.gd',O/'qa/bootstrap.gd')
shutil.copy2('D:/MafioziCombat31/competitive_bot53_resume/qa/moving.gd',O/'qa/moving53.gd')
base=json.loads((O/'BASE52.json').read_text(encoding='utf-8-sig'))
pins={r:hashlib.sha256((G/r).read_bytes()).hexdigest() for r in base['source_pins']}
changed=[r for r in pins if pins[r]!=base['source_pins'][r]]
assert set(changed)=={'scripts/preview_player.gd','scripts/weapons/bow_prototype.gd','scripts/weapons/sword_prototype.gd','scripts/combat/castle_armor_visual.gd'},changed
(O/'CANDIDATE.json').write_text(json.dumps(dict(base_commit='33b8ad5388e846752a4111caffd56d9d15935174',source_pins=pins,changed=changed),indent=2),encoding='utf-8')
print(json.dumps(dict(pins=len(pins),changed=changed)))
