"""Promote a reviewed frozen cargo/cursor export only; retain all unrelated shared edits."""
from pathlib import Path
import argparse,hashlib,json,shutil
p=argparse.ArgumentParser();p.add_argument('--candidate',required=True);p.add_argument('--gpu',required=True);p.add_argument('--sha256',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];stage=root/'outputs/coordinator23_quality'/a.candidate
game=stage/'godot/mafiozi_walk';export=game/'exports/win64/s01-20260930-quality23h'
out=root/'outputs/coordinator23_delivery23h';dest=root/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23h-play'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
assert not out.exists() and not dest.exists()
assert sha(export/'MafioziPreview.pck')==a.sha256
gpu=load(root/a.gpu/'RESULT.json');assert gpu['valid'] and not gpu['errors'] and gpu['pack_sha256']==a.sha256
log=(root/a.gpu/'engine.log').read_text(encoding='utf8')
assert all(s not in log for s in ['SCRIPT ERROR','ERROR:','FAIL '])
manifest=load(stage/'INTEGRATION.json');guards=[]
for name,change in manifest['changes'].items():
    source=root/'godot/mafiozi_walk'/name
    assert sha(source)==change['before'],'Concurrent shared edit: '+name
    assert sha(game/name)==change['after'],'Frozen target changed: '+name
    guards.append(dict(path='godot/mafiozi_walk/'+name,relative_path=name,before=change['before'],after=change['after']))
preserved={}
for p in (root/'godot/mafiozi_walk').rglob('*'):
    if not p.is_file() or any(x in ['.godot','exports'] for x in p.parts):continue
    rel=p.relative_to(root/'godot/mafiozi_walk').as_posix()
    if rel not in manifest['changes']:preserved[rel]=sha(p)
receipt=load(export/'build_receipt.json')
for item in receipt['artifacts']:assert sha(export/item['filename'])==item['sha256']
out.mkdir()
for row in guards:
    source=root/row['path'];assert sha(source)==row['before']
    if source.exists():
        backup=out/'before'/row['relative_path'];backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(source.read_bytes())
    source.parent.mkdir(parents=True,exist_ok=True);source.write_bytes((game/row['relative_path']).read_bytes());assert sha(source)==row['after']
for rel,value in preserved.items():assert sha(root/'godot/mafiozi_walk'/rel)==value,'Unscoped change: '+rel
dest.mkdir(parents=True)
for name in ['MafioziPreview.exe','MafioziPreview.pck','build_receipt.json']:
    shutil.copyfile(export/name,dest/name);assert sha(dest/name)==sha(export/name)
(out/'PROMOTION.json').write_text(json.dumps({'status':'ACCEPTED_SCOPED_PROMOTION','candidate':a.candidate,'revision':'s01-20260930-quality23h','pack_sha256':a.sha256,'guards':guards,'preserved_unscoped':preserved,'gpu':a.gpu,'export_path':str(dest.relative_to(root)),'limits':'Shared foreign transport/palette work retained; exact frozen export differs there. Full migration/RPG HP remains pending.'},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Scoped source promotion complete',len(guards),'exact export',a.sha256)
