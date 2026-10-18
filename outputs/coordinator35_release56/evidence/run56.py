from pathlib import Path
import json,subprocess,sys,hashlib
O=Path(__file__).parent; R=Path('C:/Users/Слава/Desktop/Мафиози')
E=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
name=sys.argv[1]; script=Path(sys.argv[2]) if len(sys.argv)>2 else O/'qa/sledge56.gd'; mode=sys.argv[3] if len(sys.argv)>3 else 'headless'
d=O/name; d.mkdir(exist_ok=False); game=O/'game'
pins={p:hashlib.sha256((game/p).read_bytes()).hexdigest() for p in json.loads((O/'BASE55.json').read_text(encoding='utf-8-sig'))['source_pins']}
(d/'SOURCE.json').write_text(json.dumps(pins,indent=2)+'\n')
cmd=[sys.executable,str(R/'tools/godot/test_scheduler.py'),'run','--mode',mode,'--project',str(game),'--timeout','220','--wait-seconds','360','--out',str(d/'native'),'--',str(E)]
if mode=='headless':cmd+=['--headless']
cmd+=['--path',str(game),'--script',str(script),'--','--qa-out='+str(d/'RESULT.json'),'--qa-dir='+str(d),*sys.argv[4:]]
proc=subprocess.run(cmd,capture_output=True);(d/'runner.log').write_bytes(proc.stdout+proc.stderr)
receipt=json.loads((d/'native/SCHEDULER_RUN.json').read_text(encoding='utf-8-sig'))
result=json.loads((d/'RESULT.json').read_text(encoding='utf-8-sig')) if (d/'RESULT.json').exists() else {}
drift=[p for p,h in pins.items() if hashlib.sha256((game/p).read_bytes()).hexdigest()!=h]
summary={'name':name,'passed':receipt.get('passed') and result.get('passed',True) and not drift,'errors':result.get('errors',[]),'scheduler_errors':receipt.get('errors',[]),'scheduler_error':receipt.get('error'),'drift':drift,'script_sha256':hashlib.sha256(script.read_bytes()).hexdigest()}
(d/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
sys.exit(0 if summary['passed'] else 1)
