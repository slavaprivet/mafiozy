from pathlib import Path
import sys,subprocess,json,hashlib
root=Path(__file__).parent
game=root.parent/'game'
name,fixture=sys.argv[1:3]
fixture=str((root/fixture).resolve()) if not Path(fixture).is_absolute() else fixture
extra=sys.argv[3:]
verbose='--verbose-engine' in extra
extra=[a for a in extra if a!='--verbose-engine']
perf='--perf' in extra
graphical='--graphical' in extra or perf
extra=[a for a in extra if a not in ('--graphical','--perf')]
for a in list(extra):
    if a.startswith('--game='):
        game=Path(a.removeprefix('--game='));extra.remove(a)
out=root/'results'/name;out.mkdir(parents=True,exist_ok=False)
def pins():
    return {p.relative_to(game).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (game/'scripts').rglob('*') if p.suffix in ('.gd','.gdshader')}
before=pins()
cmd=[sys.executable,str(root.parents[2]/'tools/godot/test_scheduler.py'),'run','--mode','perf' if perf else ('graphical' if graphical else 'headless'),'--project',str(game),'--access','read','--wait-seconds','90','--timeout','180','--out',str(out/'run'),'--',str(Path.home()/'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'),*(['--verbose'] if verbose else []),*(['--windowed','--resolution','1280x720','--max-fps','60'] if graphical else ['--headless','--max-fps','60']),'--path',str(game),'--script',fixture,'--','--qa-out='+str(out),'--lab-out='+str(out),*extra]
(out/'COMMAND.json').write_text(json.dumps(cmd,ensure_ascii=False,indent=2),encoding='utf-8')
with (out/'launcher.log').open('wb') as log: rc=subprocess.call(cmd,stdout=log,stderr=log)
result=json.loads((out/'RESULT.json').read_text(encoding='utf-8')) if (out/'RESULT.json').exists() else {}
sched=json.loads((out/'run/SCHEDULER_RUN.json').read_text(encoding='utf-8')) if (out/'run/SCHEDULER_RUN.json').exists() else {}
summary={'exit_code':rc,'passed':result.get('passed',result.get('pass',False)),'source_unchanged':before==pins(),'scheduler_passed':sched.get('passed',False),'stderr_bytes':sched.get('stderr_bytes'),'checks':result.get('checks'),'failures':result.get('failures',[]),'source_pins':before}
(out/'CHECK.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({**{k:v for k,v in summary.items() if k not in ('source_pins','checks')},'check_count':len(summary.get('checks') or [])}))
sys.exit(rc or (0 if summary['passed'] and summary['source_unchanged'] and summary['scheduler_passed'] else 1))

