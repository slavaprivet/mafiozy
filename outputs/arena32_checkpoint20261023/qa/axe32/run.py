from pathlib import Path
import sys,subprocess,json,hashlib
root=Path(__file__).parent
game=root.parents[1]/'arena32_injuries_axes/game'
name,fixture=sys.argv[1:3]
extra=sys.argv[3:]
queue_wait='90'
for a in list(extra):
    if a.startswith('--queue-wait='):
        queue_wait=a.split('=',1)[1];extra.remove(a)
graphical='--graphical' in extra
extra=[a for a in extra if a!='--graphical']
for a in list(extra):
    if a.startswith('--game='):
        game=Path(a.removeprefix('--game='));extra.remove(a)
out=root/name;out.mkdir(exist_ok=False)
def pins():
    return {p.relative_to(game).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (game/'scripts').rglob('*') if p.suffix in ('.gd','.gdshader')}
before=pins()
cmd=[sys.executable,'C:/Users/Слава/Desktop/Мафиози/tools/godot/test_scheduler.py','run','--mode','graphical' if graphical else 'headless','--project',str(game),'--access','read','--wait-seconds',queue_wait,'--timeout','180','--out',str(out/'run'),'--',str(Path.home()/'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'),*(['--windowed','--resolution','1280x720','--max-fps','60'] if graphical else ['--headless','--max-fps','60']),'--path',str(game),'--script',fixture,'--','--qa-out='+str(out),'--lab-out='+str(out),*extra]
(out/'COMMAND.json').write_text(json.dumps(cmd,ensure_ascii=False,indent=2),encoding='utf-8')
with (out/'launcher.log').open('wb') as log: rc=subprocess.call(cmd,stdout=log,stderr=log)
result=json.loads((out/'RESULT.json').read_text(encoding='utf-8')) if (out/'RESULT.json').exists() else {}
sched=json.loads((out/'run/SCHEDULER_RUN.json').read_text(encoding='utf-8')) if (out/'run/SCHEDULER_RUN.json').exists() else {}
summary={'exit_code':rc,'passed':result.get('passed',result.get('pass',False)),'source_unchanged':before==pins(),'scheduler_passed':sched.get('passed',False),'stderr_bytes':sched.get('stderr_bytes'),'checks':result.get('checks'),'failures':result.get('failures',[]),'source_pins':before}
(out/'CHECK.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({**{k:v for k,v in summary.items() if k not in ('source_pins','checks')},'check_count':len(summary.get('checks') or [])}))
sys.exit(rc or (0 if summary['passed'] and summary['source_unchanged'] and summary['scheduler_passed'] else 1))

