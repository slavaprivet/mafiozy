"""Exact scoped checkpoint; preserve pre-existing foreign index entries."""
from pathlib import Path
import hashlib, json, subprocess, sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
def git(*args,**kwargs):return subprocess.run(['git',*args],cwd=ROOT,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kwargs).stdout
def index():
    return {entry.split(b'\t',1)[1].decode('utf-8'):entry.split(b'\t',1)[0].decode('ascii') for entry in git('ls-files','--stage','-z').split(b'\0') if entry}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert git('branch','--show-current').decode().strip()=='main'
run=HERE/'checkpoint_fixes56'
assert not run.exists();run.mkdir()
paths=['AGENTS.md','docs/ai/COORDINATOR_30_MEMORY.md','docs/ai/CURRENT_COORDINATOR.json']
game='outputs/coordinator30_npc54/game/'
paths += [game+p for p in ['scripts/hospital/npc_restaurant_visit28.gd','scripts/hospital/npc_simple_hospital.gd','scripts/npc_city_daily.gd','scripts/npc_daily_life.gd','scripts/npc_visual/npc_attention29.gd','scripts/npc_visual/npc_resident_diag.gd','scripts/npc_visual/preview_resident_host.gd','scripts/shop/npc_economy_visit28.gd','scripts/shop/npc_local_account.gd','scripts/city/runtime/npc_wait_cohort56.gd']]
for name in ['stalls56','visual_perf56','wait_perf56','hp_release56','avoid_state56']:
    folder=HERE.parent/name
    for p in folder.rglob('*'):
        rel=p.relative_to(folder)
        if not p.is_file() or any(x in rel.parts for x in ['native_project','game','.godot','__pycache__']):continue
        if p.suffix in ['.py','.gd','.json','.md','.log','.zip','.png'] or p.name.endswith('.txt'):
            paths.append(p.relative_to(ROOT).as_posix())
for p in [HERE/'POLICY.json',HERE/'run_batch56.py',HERE/'entry_batch56.gd',HERE/'summarize_batch56.py',HERE/'checkpoint_fixes56.py']:
    paths.append(p.relative_to(ROOT).as_posix())
for p in (HERE/'runs/batch10_perf01').rglob('*'):
    if p.is_file() and p.suffix in ['.json','.log','.png']:paths.append(p.relative_to(ROOT).as_posix())
paths=sorted(set(paths));assert all((ROOT/p).is_file() for p in paths)
source={p:sha(ROOT/p) for p in paths}
before_index=index();foreign={p:v for p,v in before_index.items() if p not in paths}
parent=git('rev-parse','HEAD').decode().strip()
spec=run/'PATHS.nul';spec.write_bytes(b'\0'.join(p.encode('utf-8') for p in paths)+b'\0')
git('add','--force','--pathspec-from-file='+str(spec),'--pathspec-file-nul')
assert {p:v for p,v in index().items() if p not in paths}==foreign,'Foreign staged entries changed; stop before commit'
assert git('rev-parse','HEAD').decode().strip()==parent,'Concurrent commit; retry checkpoint deliberately'
assert all(sha(ROOT/p)==h for p,h in source.items()),'Source changed during staging'
git('commit','--only','--pathspec-from-file='+str(spec),'--pathspec-file-nul','-m','Fix NPC queues and avoidance state; verify first10 population performance')
commit=git('rev-parse','HEAD').decode().strip()
changed=[p.decode('utf-8') for p in git('diff-tree','--no-commit-id','--name-only','-r','-z',commit).split(b'\0') if p]
assert set(changed)<=set(paths),'Commit contains foreign paths'
assert {p:v for p,v in index().items() if p not in paths}==foreign,'Foreign index changed during commit'
assert git('rev-parse',commit+'^').decode().strip()==parent
git('push','origin','main')
remote=git('ls-remote','origin','refs/heads/main').decode().split()[0]
assert remote==commit
result={'commit':commit,'parent':parent,'origin_main':remote,'changed_paths':changed,'scoped_files':len(paths),'foreign_index_preserved':True,'batch10_performance_pass':True,'batch10_all_services_accepted':False,'ordinary_pointer_unchanged_55':True}
(run/'RESULT.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='changed_paths'}))
