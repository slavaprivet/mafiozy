"""Hourly recovery checkpoint. No unaccepted production integration or foreign WIP."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[2];out=root/'outputs/coordinator23_pending23h'
out.mkdir(exist_ok=True);sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args,data=None):
    p=subprocess.run(['git',*args],cwd=root,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode:raise RuntimeError(p.stderr.decode('utf8',errors='replace'))
    return p.stdout
base='27ee4b39b13124a940d4ecd3e3df2047053e5c51'
assert git('rev-parse','HEAD').decode().strip()==base and git('branch','--show-current').decode().strip()=='main'
assert not git('diff','--cached','--name-only').strip()
stage=root/'outputs/coordinator23_quality/candidate15';manifest=json.loads((stage/'INTEGRATION.json').read_text(encoding='utf8'))
for name,record in manifest['changes'].items():
    src=stage/'godot/mafiozi_walk'/name;assert sha(src.read_bytes())==record['after']
    dest=out/'files'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(src.read_bytes())
(out/'STATUS.md').write_text('''# 23h hourly recovery checkpoint — NOT DELIVERED

Candidate15 compiled277+85+49+18 PASS. Actual rendered UI/clear world hover247PASS, original3NPC/8buildings/377colliders. E world/model or modalhover takes exactUID/ammo, F contents, native Take immediate return, no accidental shot. Custom arrow/hand; proper native cursor teardown. Input-event pointer coordinates plus window exit fix, explicit unfocusable guard.

Root reviewed actual PNGs including clear visible TT. Still HOLD for first-use optimization: first material_overlay binding measured32.467ms, next78us; source proposal pending. GPU15_01 observer was hero-occluded despite functionalPASS; visual16/gpu15_01 corrects observer placement without hiding actors. Earlier failed results preserved.

Shared production remains accepted23g; existing game12304 was absent in fresh inventory before QA, not closed by root. Only Manager45268 remained. No candidate delivered yet. Continue serialized GPU/perf after material prewarm fix. NPC/transport/physics WIP preserved. Full migration/RPG blastHP still incomplete; RPG audits/proposals outputs-only.
''',encoding='utf8')
files={}
def include(p):files[p.relative_to(root).as_posix()]=p.read_bytes()
trees=['coordinator23_pending23h','coordinator23_cursor12','coordinator23_cargo_controls13','coordinator23_cargo_hover12','coordinator23_cargo_return12','coordinator23_cargo_pointer14','coordinator23_cargo_visual12','coordinator23_cargo_visual13','coordinator23_cargo_visual15','coordinator23_cargo_visual16','coordinator23_compiled12','coordinator23_compiled15','coordinator23_adoption12_guards','coordinator23_adoption13_guards','coordinator23_adoption15_guards','coordinator23_rpg23h','coordinator23_cargo_perf13']
for name in trees:
    directory=root/'outputs'/name
    for p in directory.rglob('*'):
        if not p.is_file():continue
        parts=p.relative_to(directory).parts
        if any(x.startswith('stage') or x in ['.godot','exports','__pycache__','before','after'] for x in parts):continue
        if p.suffix.lower() not in ['.gd','.py','.ps1','.json','.log','.md','.patch','.svg','.png','.txt']:continue
        include(p)
for name in ['prepare_candidate12.py','guard_candidate12.py','freeze_candidate12.py','prepare_candidate13.py','prepare_candidate14.py','prepare_candidate15.py','verify_native12.py','promote_23h.py','open_23h.ps1','checkpoint_pending23h.py']:include(root/'outputs/coordinator23_quality'/name)
include(stage/'INTEGRATION.json');include(stage/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23h/build_receipt.json')
record={'base':base,'status':'PENDING_PERF_NOT_DELIVERED','files':[{'path':p,'sha256':sha(b),'bytes':len(b)} for p,b in files.items()]}
(out/'CHECKPOINT.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8');include(out/'CHECKPOINT.json')
assert sum(map(len,files.values()))<25_000_000
entries=[]
for p,b in files.items():
    blob=git('hash-object','-w','--stdin',data=b).decode().strip();entries.append(f'100644 {blob}\t{p}\n')
git('update-index','--index-info',data=''.join(entries).encode('utf8'))
changed=set(git('diff','--cached','--name-only','-z').decode().split('\0'))-{''};assert changed.issubset(files)
for p in changed:assert git('show',':'+p)==files[p]
print('Staged verified pending recovery scope:',len(changed),sum(map(len,files.values())),'bytes')
