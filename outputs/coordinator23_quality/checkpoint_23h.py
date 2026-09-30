from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[2];out=root/'outputs/coordinator23_delivery23h'
def git(*args,data=None):
    p=subprocess.run(['git',*args],cwd=root,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode:raise RuntimeError(p.stderr.decode('utf8',errors='replace'))
    return p.stdout
base='36b22251693e9951018679cd26d003169f657240'
assert git('rev-parse','HEAD').decode().strip()==base and git('branch','--show-current').decode().strip()=='main'
assert git('rev-parse','--show-object-format').decode().strip()=='sha1'
assert not git('diff','--cached','--name-only').strip()
files={}
def include(p):files[p.relative_to(root).as_posix()]=p.read_bytes()
promotion=json.loads((out/'PROMOTION.json').read_text(encoding='utf8'))
for row in promotion['guards']:
    p=root/row['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['after'];include(p)
for row in json.loads((out/'CURSOR_IMPORTS.json').read_text(encoding='utf8')):
    p=root/row['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256']
    if not row['cache']:include(p)
for rel in ['docs/ai/COORDINATOR_23_MEMORY.md','docs/ai/COORDINATOR_23_HANDOFF.md','docs/godot/MIGRATION_BOARD.md','docs/godot/WEAPONS_23H_CHECKPOINT.md']:include(root/rel)
for name in ['prepare_candidate16.py','promote_23h.py','install_cursor_imports23h.py','open_23h.ps1','test_shared_startup23h.gd','document_23h.py','checkpoint_23h.py']:include(root/'outputs/coordinator23_quality'/name)
trees=['coordinator23_delivery23h','coordinator23_adoption16_guards','coordinator23_hover_prewarm17','coordinator23_cargo_visual16','coordinator23_cargo_perf13']
for name in trees:
    directory=root/'outputs'/name
    for p in directory.rglob('*'):
        if not p.is_file():continue
        parts=p.relative_to(directory).parts
        if any(x.startswith('stage') or x in ['before','.godot','exports','__pycache__'] for x in parts):continue
        if p.suffix.lower() not in ['.gd','.py','.ps1','.json','.log','.md','.patch','.png','.txt']:continue
        include(p)
stage=root/'outputs/coordinator23_quality/candidate16';include(stage/'INTEGRATION.json')
include(stage/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23h/build_receipt.json')
manifest={'base':base,'revision':promotion['revision'],'pack_sha256':promotion['pack_sha256'],'status':'ACCEPTED_AND_DELIVERED; full migration incomplete','files':[{'path':p,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)} for p,b in files.items()]}
(out/'CHECKPOINT_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8');include(out/'CHECKPOINT_MANIFEST.json')
head={}
for entry in git('ls-tree','-rz','HEAD').split(b'\0'):
    if entry:
        metadata,path=entry.split(b'\t',1);head[path.decode('utf8')]=metadata.split()[2].decode()
blobsha=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
changes={p:b for p,b in files.items() if head.get(p)!=blobsha(b)}
assert changes and sum(map(len,changes.values()))<20_000_000
entries=[]
for p,b in changes.items():
    blob=git('hash-object','-w','--stdin',data=b).decode().strip();assert blob==blobsha(b)
    entries.append(f'100644 {blob}\t{p}\n')
git('update-index','--index-info',data=''.join(entries).encode('utf8'))
staged=set(git('diff','--cached','--name-only','-z').decode('utf8').split('\0'))-{''};assert staged==set(changes)
index={}
for entry in git('ls-files','--stage','-z').split(b'\0'):
    if entry:
        metadata,path=entry.split(b'\t',1);index[path.decode('utf8')]=metadata.split()[1].decode()
for p,b in changes.items():assert index[p]==blobsha(b)
print('Staged exact accepted scope',len(changes),'files',sum(map(len,changes.values())),'bytes; foreign WIP untouched')
