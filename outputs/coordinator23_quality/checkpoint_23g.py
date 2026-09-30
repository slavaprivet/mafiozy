"""Stage accepted23g exact scoped runtime and evidence; preserve every foreign WIP."""
from pathlib import Path
import hashlib, json, subprocess, sys
root=Path(__file__).resolve().parents[2]
base='269b356ed2d1506b05d04d92f7d369b8b5a2c282'
def git(*args,data=None):
    p=subprocess.run(['git',*args],cwd=root,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode:raise RuntimeError(p.stderr.decode('utf8',errors='replace'))
    return p.stdout
assert git('rev-parse','HEAD').decode().strip()==base
assert git('branch','--show-current').decode().strip()=='main'
assert not git('diff','--cached','--name-only').strip()
files={}
def include(p):
    files[p.relative_to(root).as_posix()]=p.read_bytes()
promotion=json.loads((root/'outputs/coordinator23_delivery23g/PROMOTION.json').read_text(encoding='utf8'))
for row in promotion['guarded_paths']:
    p=root/row['path']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==row['accepted11_sha256'], row['path']
    include(p)
    uid=Path(str(p)+'.uid')
    if p.suffix=='.gd' and uid.exists(): include(uid)
for name in ['docs/ai/COORDINATOR_23_MEMORY.md','docs/ai/COORDINATOR_23_HANDOFF.md',
             'docs/godot/MIGRATION_BOARD.md','docs/godot/WEAPONS_23G_CHECKPOINT.md',
             'outputs/coordinator23_quality/prepare_candidate10.py',
             'outputs/coordinator23_quality/prepare_candidate11.py',
             'outputs/coordinator23_quality/promote_23g.py',
             'outputs/coordinator23_quality/open_23g.ps1',
             'outputs/coordinator23_quality/checkpoint_23g.py']:
    include(root/name)
trees=['coordinator23_trunk_window','coordinator23_trunk_layout11','coordinator23_trunk_visual10',
       'coordinator23_adoption11_guards','coordinator23_marks_visual23g',
       'coordinator23_marks_visual23g_clear','coordinator23_delivery23g']
excluded={'stage','before','proposed','.godot','exports','__pycache__'}
for name in trees:
    directory=root/'outputs'/name
    for p in sorted(directory.rglob('*')):
        if not p.is_file() or any(x in excluded for x in p.relative_to(directory).parts): continue
        if p.suffix in ['.pyc','.exe','.pck','.lnk','.uid']:continue
        include(p)
for name in ['coordinator23_compiled10/contact01']:
    for p in (root/'outputs'/name).rglob('*'):
        if p.is_file() and p.suffix in ['.gd','.json','.log','.md','.py']:include(p)
for candidate in ['candidate10','candidate11']:
    directory=root/'outputs/coordinator23_quality'/candidate
    include(directory/'INTEGRATION.json')
    include(directory/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23g/build_receipt.json')
for name in ['outputs/coordinator23_marks_fix10/ART_RECEIPT.json','outputs/coordinator23_marks_fix10/README.md',
             'outputs/coordinator23_compiled10/trunk01.log']:
    if (root/name).exists():include(root/name)
manifest={'schema':'coordinator23.accepted23g-checkpoint/v1','base':base,
    'pack_sha256':promotion['pack_sha256'], 'scope':'Accepted scoped runtime, actual GUI and visual evidence. Full Walk migration remains incomplete.',
    'files':[{'path':p,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)} for p,b in files.items()]}
path=root/'outputs/coordinator23_delivery23g/CHECKPOINT_MANIFEST.json'
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8'); include(path)
print(json.dumps({'files':len(files),'bytes':sum(map(len,files.values()))}))
if '--stage' in sys.argv:
    entries=[]
    for p,b in files.items():
        blob=git('hash-object','-w','--stdin',data=b).decode().strip()
        entries.append(f'100644 {blob}\t{p}\n')
    git('update-index','--index-info',data=''.join(entries).encode('utf8'))
    changed=set(git('diff','--cached','--name-only','-z').decode().split('\0'))-{''}
    assert changed.issubset(files)
    for p in changed:assert git('show',':'+p)==files[p],p
    print('STAGED_ACCEPTED_EXACT',len(changed))
