from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=HERE.parents[1]/'game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):
    assert not p.exists(),p
    p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
patch=read(HERE/'PATCH.json')
flat={}
for row in patch['files']:
    source=GAME/row['path']
    assert (sha(source) if source.exists() else None)==row['base_sha256']
    assert sha(HERE/'patch'/row['path'])==row['sha256']
    flat[row['path']]={'base_sha256':row['base_sha256'],'candidate_sha256':row['sha256']}
bench_rel='scripts/homes/npc_home_benches58.gd'
assert not (GAME/bench_rel).exists()
bench=HERE/'bench_patch'/bench_rel
target=HERE/'patch'/bench_rel
target.parent.mkdir(parents=True,exist_ok=True)
assert not target.exists()
shutil.copyfile(bench,target)
assert sha(target)==sha(bench)
save(HERE/'PATCH_FOR_ROOT.json',flat)
save(HERE/'BENCH_PATCH_FOR_ROOT.json',{bench_rel:{'base_sha256':None,'candidate_sha256':sha(bench)}})
print(json.dumps({'core_files':len(flat),'bench_files':1,'bench_helper_sha256':sha(bench),'source_edited':False}))
