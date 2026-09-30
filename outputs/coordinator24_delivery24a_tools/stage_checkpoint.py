"""Stage only Root24 runtime, proof files and own document blocks; preserve all WIP."""
from pathlib import Path
import subprocess, hashlib, json
root=Path(__file__).resolve().parents[2]
def git(*args, data=None):
    result=subprocess.run(['git',*args],cwd=root,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if result.returncode:
        print(result.stderr.decode('utf8',errors='replace'))
        raise RuntimeError('Git failed: '+args[0]+' '+str(result.returncode))
    return result.stdout
existing=git('diff','--cached','--name-only','-z').decode().strip('\0').split('\0')
existing=[p for p in existing if p]
head=git('rev-parse','HEAD').decode().strip()
assert head=='59731b44d60ecdcdffa4b8afeea69f9b1938ae00', 'Concurrent root Git change'
paths=['godot/mafiozi_walk/'+p for p in [
 'scripts/main.gd','scripts/weapons/preview_weapon_cargo.gd',
 'scripts/weapons/preview_weapons.gd','data/preview_updates.json']]
paths += ['docs/ai/COORDINATOR_24_MEMORY.md','docs/ai/COORDINATOR_24_HANDOFF.md',
 'outputs/coordinator24_quality/candidate20/INTEGRATION.json']
for folder in ['outputs/coordinator24_cargo_input/compiled20tools',
 'outputs/coordinator24_cargo_input/compiled20_headless01',
 'outputs/coordinator24_cargo_input/compiled20_focused01',
 'outputs/coordinator24_cargo_input/compiled20_focused02',
 'outputs/coordinator24_cargo_input/perf20tools',
 'outputs/coordinator24_cargo_input/perf20_baseline',
 'outputs/coordinator24_cargo_input/perf20_candidate',
 'outputs/coordinator24_cargo_aim_race/compiled20',
 'outputs/coordinator24_delivery24a_tools',
 'outputs/coordinator24_delivery24a']:
    for f in (root/folder).rglob('*'):
        if not f.is_file() or 'before' in f.parts or '__pycache__' in f.parts:continue
        if f.suffix.lower() not in ['.json','.gd','.py','.ps1','.md','.log']:continue
        paths.append(f.relative_to(root).as_posix())
for name in ['README.md','RECEIPT.json','REVIEW20.md','COMPARISON20.json','prepare20.py',
 'prepare_perf20.py','promote24a.py','test_inputs.gd','baseline_final.log','patched02.log']:
    paths.append('outputs/coordinator24_cargo_input/'+name)
for name in ['CARGO20_FINAL_AUDIT.json','CARGO20_FINAL_AUDIT.md','CARGO20_METADATA_DRIFT.json',
 'audit_cargo20.py','audit_cargo20_metadata.py','finalize_cargo20_audit.py']:
    paths.append('outputs/coordinator24_takeover/rpg_audit/'+name)
for name in ['01_modal_before_E.png','02_after_E_and_keyup.png']:
    paths.append('outputs/coordinator24_cargo_input/compiled20_focused02/'+name)
paths=sorted(set(paths))
assert all((root/p).is_file() for p in paths)
assert all((root/p).stat().st_size<1500000 for p in paths)
assert set(existing)<=set(paths), 'Unexpected shared index path; review before staging'
git('add','-f','--',*paths)
partial={}
def section(text, heading):
    start=text.index(heading)
    end=text.find('\n## ',start+len(heading))
    return text[start:] if end<0 else text[start:end+1]
for path, headings in {
 'AGENTS.md':['## Действующий Координатор 24 — 30 сентября 2026'],
 'docs/ai/AGENT_HUB.md':['## 30 сентября17:18 — Root24 доставил cargo24a, QUIET24 RELEASED',
                      '## 30 сентября16:43 — пользователь передал root Координатору24'],
 'docs/godot/MIGRATION_BOARD.md':['## 30 September17:18 — cargo24a accepted and opened by Root24',
                               '## 30 September16:43 — user appointed Coordinator24, accepted23h reopened']
}.items():
    working=(root/path).read_bytes()
    text=working.decode('utf8').replace('\r\n','\n')
    base=git('show','HEAD:'+path)
    added=('\n'.join(section(text,h).strip() for h in headings)+'\n\n').encode('utf8')
    if base.startswith(b'# '):
        pos=base.index(b'\n\n')+2
        staged=base[:pos]+added+base[pos:]
    else:staged=added+base
    blob=git('hash-object','-w','--stdin',data=staged).decode().strip()
    mode=git('ls-files','-s','--',path).decode().split()[0]
    git('update-index','--cacheinfo',mode+','+blob+','+path)
    assert (root/path).read_bytes()==working, 'Worktree altered unexpectedly'
    partial[path]={'staged_blob':blob,'preserved_worktree_sha256':hashlib.sha256(working).hexdigest()}
record={'parent':head,'full_paths':paths,'partial_document_blocks':partial,'scope':'No other owner WIP or export binaries staged'}
record_path=root/'outputs/coordinator24_delivery24a/GIT_STAGE.json'
record_path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
git('add','--',record_path.relative_to(root).as_posix())
print(json.dumps({'files':len(paths)+len(partial)+1,'partial_docs':list(partial),'parent':head}))
