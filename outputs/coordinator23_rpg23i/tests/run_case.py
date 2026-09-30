from pathlib import Path
import argparse, hashlib, json, subprocess, time
p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True)
p.add_argument('--case',choices=['floor','wall','spread','range_end','cancel','context_dispose'],required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args();project=a.project.resolve();out=a.out.resolve();base=Path(__file__).resolve().parent
assert not out.exists(),'Fresh output directory required'
paths=['scripts/main.gd','scripts/preview_player.gd','scripts/weapons/preview_weapons.gd','scripts/weapons/rpg_effects.gd','scripts/weapons/rpg_flight.gd','scripts/weapons/npc_rpg_blast_gate.gd','scripts/npc_visual/npc_local_preview_hit_owner.gd','scripts/npc_visual/npc_ordinary_hit_lifecycle.gd']
# Discover relocated gate only from actual project files, never substitute another package.
if not (project/paths[5]).exists():
    choices=list(project.rglob('npc_rpg_blast_gate.gd'))
    assert len(choices)==1,'Exactly one current staged RPG gate required'
    paths[5]=choices[0].relative_to(project).as_posix()
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
before={x:sha(project/x) for x in paths};out.mkdir(parents=True)
engine=Path.home()/'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
cmd=[str(engine),'--headless','--path',str(project),'--script',str(base/'actual_main.gd'),'--','--case='+a.case,'--qa-out='+str(out)]
t=time.monotonic()
with (out/'engine.log').open('w',encoding='utf-8') as log:
    try:
        run=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=30)
        result={'exit_code':run.returncode}
    except subprocess.TimeoutExpired:result={'timeout_seconds':30}
result.update(case=a.case,seconds=time.monotonic()-t,command=cmd,before=before,after={x:sha(project/x) for x in paths},harness_sha256=sha(base/'actual_main.gd'))
result['stable_sources']=result['before']==result['after']
(out/'RUN.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
raise SystemExit(0 if result.get('exit_code')==0 and result['stable_sources'] else 2)
