"""Save verified doorway candidates and diagnostic evidence, without claiming release58."""
import argparse,importlib.util,json,pathlib
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];WORK=HERE.parent
spec=importlib.util.spec_from_file_location('scoped_checkpoint57',WORK/'checkpoint57.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
git,sha,index,tree=base.git,base.sha,base.index,base.tree

def collect(folder,exclude_runs=False):
    blocked={'.godot','__pycache__','.git','checkpoint58_progress'}
    if exclude_runs:blocked.add('runs')
    return [p.relative_to(ROOT).as_posix() for p in folder.rglob('*') if p.is_file() and not blocked.intersection(p.relative_to(folder).parts)]

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--go',action='store_true');parser.add_argument('--candidate',type=pathlib.Path,required=True);args=parser.parse_args()
    manifest=base.read(args.candidate);assert manifest['gameplay_acceptance_pending']
    assert git('branch','--show-current').decode().strip()=='main'
    assert all(sha(WORK/'game'/rel)==digest for rel,digest in manifest['source_pins'].items())
    pointer=base.read(ROOT/'godot/current_version.json');assert pointer==base.read(ROOT/'outputs/coordinator31_release57/PROPOSED_CURRENT.json')
    paths=['AGENTS.md','docs/ai/COORDINATOR_31_MEMORY.md','docs/ai/CURRENT_COORDINATOR.json']
    for relative in manifest['changes']:
        if (WORK/'game'/relative).is_file():paths.append((WORK/'game'/relative).relative_to(ROOT).as_posix())
    for name in ['native_navigation31','native_profiler31','godot_addons31','door_opening31','qa31_extended']:
        paths+=collect(WORK/'proposals'/name)
    paths+=collect(WORK/'proposals/qa58_merged',exclude_runs=True)
    paths+=collect(WORK/'proposals/qa58_merged/runs/portal58_harness45')
    paths+=collect(HERE)
    for name in ['INTEGRATION_portal58_01.json','INTEGRATION_door58_01.json']:
        if (WORK/name).exists():paths.append((WORK/name).relative_to(ROOT).as_posix())
    paths=sorted(set(paths));parent=git('rev-parse','HEAD').decode().strip()
    source={name:sha(ROOT/name) for name in paths};before=index();foreign={name:item for name,item in before.items() if name not in paths}
    plan={'parent':parent,'scope_count':len(paths),'bytes':sum((ROOT/n).stat().st_size for n in paths),'release58_accepted':False,'f5_release':'57','first10_complete':False,'basis':'Native scoped tests plus built-in profiler/addon evaluation; combined soak pending'}
    if not args.go:print(json.dumps(plan));return
    output=HERE/'checkpoint58_progress';output.mkdir(exist_ok=False)
    pathspec=output/'PATHS.nul';pathspec.write_bytes(b'\0'.join(n.encode('utf-8') for n in paths)+b'\0')
    (output/'SOURCE.json').write_text(json.dumps(source,indent=2)+'\n',encoding='utf-8')
    git('add','--force','--pathspec-from-file='+str(pathspec),'--pathspec-file-nul')
    staged=index();assert {n:v for n,v in staged.items() if n not in paths}==foreign
    assert git('rev-parse','HEAD').decode().strip()==parent and all(sha(ROOT/n)==v for n,v in source.items())
    expected={}
    for name in paths:
        mode,oid,stage=staged[name].split();assert stage=='0';expected[name]=(mode,oid)
    git('commit','--only','--pathspec-from-file='+str(pathspec),'--pathspec-file-nul','-m','NPC58 candidate: concurrent doorways and physical backoff; profile Godot tools')
    commit=git('rev-parse','HEAD').decode().strip();changed=[n.decode('utf-8') for n in git('diff-tree','--no-commit-id','--name-only','-r','-z',commit).split(b'\0') if n]
    assert set(changed)<=set(paths) and git('rev-parse',commit+'^').decode().strip()==parent
    committed=tree(commit);assert all(committed.get(n)==v for n,v in expected.items())
    assert {n:v for n,v in index().items() if n not in paths}==foreign
    assert all(sha(ROOT/n)==v for n,v in source.items())
    git('push','origin','main');remote=git('ls-remote','origin','refs/heads/main').decode().split()[0];assert remote==commit
    result={**plan,'commit':commit,'origin_main':remote,'foreign_index_preserved':True,'changed_paths':changed}
    (output/'RESULT.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='changed_paths'}))

if __name__=='__main__':main()
