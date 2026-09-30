"""Scoped verified evidence checkpoint; candidate/runtime promotion stays separate."""
from pathlib import Path
import hashlib, json, subprocess, sys
root=Path(__file__).resolve().parents[2]
base='4c6d4f70fbdea70fb7c2470bb1547b7aca95fdb3'
def git(*args,data=None):
    r=subprocess.run(['git',*args],cwd=root,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode:raise RuntimeError(r.stderr.decode('utf8',errors='replace'))
    return r.stdout
assert git('rev-parse','HEAD').decode().strip()==base
assert not git('diff','--cached','--name-only').strip()
files={}
trees=['coordinator23_combo_merge06','coordinator23_combo_parallax07','coordinator23_contact_final_review',
       'coordinator23_head_merge07','coordinator23_head_export08','coordinator23_marks_prewarm09',
       'coordinator23_adoption09_guards']
for name in trees:
    directory=root/'outputs'/name
    for path in sorted(directory.rglob('*')):
        relative=path.relative_to(directory)
        if not path.is_file() or any(x in relative.parts for x in ['stage','proposed','__pycache__','empty_cwd','.godot']):continue
        if path.suffix in ['.pyc','.uid','.exe','.pck']:continue
        files[path.relative_to(root).as_posix()]=path.read_bytes()
for name,children in {
    'coordinator23_contact_port_proposal':['native12'],
    'coordinator23_contact_integration06':['main07_01','main07_02'],
    'coordinator23_compiled08':['contact01','contact02'],
    'coordinator23_loaded_combat_pair':['gpu_baseline01','gpu_candidate01','cold08_02','cold09_02'],
    'coordinator23_head_visual08':['gpu09_01'],
}.items():
    directory=root/'outputs'/name
    selected=list(directory.glob('*'))
    for child in children:selected.extend((directory/child).rglob('*'))
    for path in sorted(selected):
        if path.is_file() and path.suffix not in ['.pyc','.uid','.exe','.pck']:
            files[path.relative_to(root).as_posix()]=path.read_bytes()
for name in ['docs/ai/COORDINATOR_23_MEMORY.md','outputs/coordinator23_quality/checkpoint_combined23.py',
             'outputs/coordinator23_quality/prepare_candidate08.py','outputs/coordinator23_quality/freeze_candidate08.py',
             'outputs/coordinator23_quality/prepare_candidate09.py']:
    files[name]=(root/name).read_bytes()
for candidate in ['candidate08','candidate09']:
    directory=root/'outputs/coordinator23_quality'/candidate
    for relative in ['INTEGRATION.json','godot/mafiozi_walk/exports/win64/s01-20260930-quality23f/build_receipt.json']:
        path=directory/relative;files[path.relative_to(root).as_posix()]=path.read_bytes()
manifest={'schema':'coordinator23.combined-evidence-checkpoint/v1','base':base,
 'scope':'Compiled contact/head and loaded GPU evidence; first-hit stall/root warmup proposal; explicit visual skin-tag FAIL and trunk-window pending. No runtime delivery, foreign WIP, or candidate promotion.',
 'files':[{'path':p,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)} for p,b in files.items()]}
destination=root/'outputs/coordinator23_combined_checkpoint/MANIFEST.json'
destination.parent.mkdir(exist_ok=True)
destination.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
files[destination.relative_to(root).as_posix()]=destination.read_bytes()
print(json.dumps({'files':len(files),'bytes':sum(map(len,files.values()))}))
if '--stage' in sys.argv:
    assert not git('diff','--cached','--name-only').strip()
    entries=[]
    for path,data in files.items():
        blob=git('hash-object','-w','--stdin',data=data).decode().strip()
        entries.append(f'100644 {blob}\t{path}\n')
    git('update-index','--index-info',data=''.join(entries).encode('utf8'))
    changed=set(git('diff','--cached','--name-only','-z').decode().split('\0'))-{''}
    assert changed.issubset(files),changed-set(files)
    for path in changed:
        assert git('show',':'+path)==files[path],path
    print('STAGED_EXACT_VERIFIED_EVIDENCE',len(changed))
