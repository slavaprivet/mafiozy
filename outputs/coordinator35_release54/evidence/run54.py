from pathlib import Path
import concurrent.futures, hashlib, json, subprocess, sys

O=Path(__file__).parent
R=Path('C:/Users/Слава/Desktop/Мафиози')
E=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))

def run(job):
    name,kind,weapon,side,mode=job
    dest=O/name;dest.mkdir(exist_ok=False)
    game=O/'game'
    script=O/'qa'/('hold54.gd' if kind=='hold' else 'contact54.gd' if kind=='contact' else 'matrix54.gd')
    args=['--qa-out='+str(dest if kind=='hold' else dest/'RESULT.json'),'--weapon='+weapon]
    if side=='left':args+=['--left']
    if kind=='contact' and side=='right':args+=['--right-attack']
    command=[sys.executable,str(R/'tools/godot/test_scheduler.py'),'run','--mode',mode,'--project',str(game),'--timeout','180','--wait-seconds','240','--out',str(dest/'native'),'--',str(E)]
    if mode=='headless':command+=['--headless']
    command+=['--path',str(game),'--script',str(script),'--',*args]
    proc=subprocess.run(command,capture_output=True)
    (dest/'runner.log').write_bytes(proc.stdout+proc.stderr)
    scheduler=read(dest/'native/SCHEDULER_RUN.json')
    result=read(dest/'RESULT.json') if (dest/'RESULT.json').exists() else {}
    drift=[p for p,h in read(O/'CANDIDATE.json')['source_pins'].items() if hashlib.sha256((game/p).read_bytes()).hexdigest()!=h]
    row={'name':name,'passed':scheduler.get('passed') and result.get('passed') and not drift,'errors':result.get('errors',[]),'scheduler_errors':scheduler.get('errors',[]),'scheduler_error':scheduler.get('error'),'drift':drift,'result':str(dest/'RESULT.json'),'script_sha256':hashlib.sha256(script.read_bytes()).hexdigest()}
    print(json.dumps(row),flush=True)
    return row

groups={
 'initial':[('sword_right03','hold','sword','right','headless'),('mace_right03','hold','mace','right','headless')],
 'left':[('sword_left02','hold','sword','left','headless'),('mace_left02','hold','mace','left','headless')],
 'contact':[(w+'_'+s+'_contact03','contact',w,s,'headless') for w in ['sword','mace'] for s in ['left','right']],
 'regression':[(w+'_matrix01','matrix',w,'left','headless') for w in ['axe','sledge','bow']],
 'visual':[(w+'_visual01','hold',w,'right','graphical') for w in ['sword','mace']],
}
group=sys.argv[1]
with concurrent.futures.ThreadPoolExecutor(max_workers=1 if group=='visual' else 2) as pool:rows=list(pool.map(run,groups[group]))
(O/(group.upper()+'.json')).write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
sys.exit(0 if all(r['passed'] for r in rows) else 1)
