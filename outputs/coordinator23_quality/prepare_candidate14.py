from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];base=root/'outputs/coordinator23_quality/candidate13';target=root/'outputs/coordinator23_quality/candidate14'
assert not target.exists()
proposal=root/'outputs/coordinator23_cargo_pointer14'
receipt=json.loads((proposal/'RECEIPT.json').read_text(encoding='utf-8-sig'))
shutil.copytree(base,target,ignore=shutil.ignore_patterns('exports'))
game=target/'godot/mafiozi_walk';manifest=json.loads((target/'INTEGRATION.json').read_text(encoding='utf8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for row in receipt['files']:
    name=row['path'];p=game/name;source=proposal/'files'/name
    assert sha(p)==row['before_sha256'] and sha(source)==row['after_sha256']
    p.write_bytes(source.read_bytes());manifest['changes'][name]['after']=sha(p)
    manifest['changes'][name]['source']='controls13 + pointer14 actual input-event coordinates, exit invalidation;277nativePASS'
name='data/preview_updates.json';p=game/name
s=p.read_text(encoding='utf8').replace('«Закрыть багажник»','«Закрыть крышку»');p.write_text(s,encoding='utf8',newline='')
manifest['changes'][name]['after']=sha(p)
manifest.update(parent='candidate13',status='FROZEN23h14; actual-event pointer coordinates and honest lid label; acceptance pending')
(target/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Candidate14 pointer/exit fix frozen')
