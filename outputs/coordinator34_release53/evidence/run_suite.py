from pathlib import Path
import json, hashlib, subprocess, sys, concurrent.futures
O=Path(__file__).parent; G=O/'game'; Q=O/'qa'
R=Path('C:/Users/Слава/Desktop/Мафиози')
E='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
pins=read(O/'CANDIDATE.json')['source_pins']
def run(job):
    name,script,mode,args,kind=job
    out=O/name;out.mkdir(exist_ok=False)
    result=out/('RESULT.json' if kind=='upper' else 'CURRENT_READY.json' if kind=='bootstrap' else 'result.json')
    outarg=str(out if kind in ['directory','upper'] else result)
    commands=[sys.executable,str(R/'tools/godot/test_scheduler.py'),'run','--mode',mode,'--project',str(G),'--wait-seconds','600','--timeout','180','--out',str(out/'native'),'--',E]
    if mode=='headless':commands+=['--headless']
    commands+=['--path',str(G),'--script',str(Q/script),'--','--qa-out='+outarg]
    if kind=='bootstrap':
        commands+=['--receipt-dir='+str(out),'--release-revision=castle-20261018-combined53-bot-bow','--release-title=Общая сцена 53','--castle-play-check=1','--castle=1','--castle-start-outside=1']
    commands+=args
    p=subprocess.run(commands,capture_output=True)
    (out/'runner.log').write_bytes(p.stdout+p.stderr)
    raw=read(result) if result.exists() else {}
    scheduler=read(out/'native/SCHEDULER_RUN.json') if (out/'native/SCHEDULER_RUN.json').exists() else {}
    errors=raw.get('errors',[])
    passed=raw.get('passed',raw.get('pass',raw.get('ok')))
    if name.startswith('bow_high') and raw:
        passed=all(r.get('stuck') and r.get('hit_parent')=='HighWall52' and abs(r['pitch_degrees']-r['requested_degrees'])<.1 and r['shots_after']==r['shots_before']+1 for r in raw['rows'][:2])
        ge=raw['rows'][-1];passed=passed and ge['after_g_dots']==0 and ge['carried'].get('bow') and not ge['grounded']
    drift=[r for r,h in pins.items() if hashlib.sha256((G/r).read_bytes()).hexdigest()!=h]
    row=dict(name=name,scheduler=scheduler.get('passed'),passed=passed,errors=errors,drift=drift,result=str(result),harness_sha256=hashlib.sha256((Q/script).read_bytes()).hexdigest())
    print(json.dumps(row),flush=True)
    return row
group=sys.argv[1] if len(sys.argv)>1 else 'core'
jobs=[]
if group=='core':
    jobs=[('ownership','ownership52.gd','headless',[],'file'),('law','law.gd','headless',[],'file'),('bow_high','bow52.gd','headless',[],'file'),('spear_high','spear52.gd','headless',[],'upper')]
    jobs += [('matrix_'+w,'matrix_switch52.gd','headless',['--weapon='+w],'file') for w in ['sword','mace','axe','sledge','bow']]
    jobs += [('matrix_spear_down','matrix_spear_down.gd','headless',['--weapon=spear'],'file')]
    jobs += [('npc_'+c,'chase.gd','headless',['--case='+c],'directory') for c in ['chase','detour','retreat']]
    jobs += [('moving_'+c,'moving53.gd','headless',['--scenario='+c],'directory') for c in ['weave','rush','diagonal']]
    jobs += [('tactics','armor53.gd','headless',[],'directory'),('armored_contact','aimed_player51.gd','headless',['--weapon=sledge','--strokes=8','--direction=left','--armor=heavy'],'directory')]
elif group=='visual':
    jobs=[('armor_visual','armor53.gd','graphical',['--visual'],'directory'),('armor_graphical','armor.gd','graphical',[],'upper'),('bootstrap','bootstrap.gd','graphical',[],'bootstrap')]
elif group=='soil':jobs=[('soil_graphical','soil.gd','graphical',[],'upper')]
else:raise ValueError(group)
with concurrent.futures.ThreadPoolExecutor(max_workers=1 if group!='core' else 2) as pool:rows=list(pool.map(run,jobs))
(O/(group.upper()+'_SUITE.json')).write_text(json.dumps(rows,indent=2),encoding='utf-8')
sys.exit(0 if all(r['passed'] and r['scheduler'] and not r['drift'] for r in rows) else 1)
