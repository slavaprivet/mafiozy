from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];base=root/'outputs/coordinator23_quality/candidate15';target=root/'outputs/coordinator23_quality/candidate16'
assert not target.exists();shutil.copytree(base,target,ignore=shutil.ignore_patterns('exports'))
game=target/'godot/mafiozi_walk';manifest=json.loads((target/'INTEGRATION.json').read_text(encoding='utf8'))
name='scripts/weapons/weapon_pickup_visuals.gd';p=game/name;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(p)=='4300cf77d8b67e41b05703474f9b70409d218f3374641c6bc70d4c98994b934a'
source=root/'outputs/coordinator23_hover_prewarm17/files'/name
assert sha(source)=='3430c08e980d600bd0b408a84e11197f80c6976347b29af6e67f0d7ac647eb12'
p.write_bytes(source.read_bytes());manifest['changes'][name]['after']=sha(p)
manifest['changes'][name]['source']='hover12 + native empty instance startup material bind/free; no scene draw/physics or retained node'
manifest.update(parent='candidate15',status='FROZEN23h16; moves first hover material binding to startup; GPU acceptance pending')
(target/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Candidate16 one-file first-hover optimization frozen')
