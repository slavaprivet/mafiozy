from pathlib import Path
import subprocess,sys,json
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
project=OUT/'runs/oracle01/project';rows=[]
cases=[('slots02',['--slots']),('cancel_approach01',['--cancel-phase','APPROACH']),('cancel_dock01',['--cancel-phase','DOCK']),('cancel_align01',['--cancel-phase','ALIGN']),('cancel_bench01',['--cancel-phase','ACTING']),('cancel_phone01',['--cancel-phase','ACTING','--cancel-kind','phone']),('stale_approach01',['--cancel-phase','APPROACH','--stale-life']),('stale_phone01',['--cancel-phase','ACTING','--cancel-kind','phone','--stale-life'])]
for name,flags in cases:
    result=subprocess.run([sys.executable,'-B',str(OUT/'run_ambient30.py'),name,'--reuse-project',str(project),*flags],cwd=ROOT)
    rows.append({'name':name,'exit':result.returncode})
    if result.returncode:break
(OUT/'CONTRACT_SUITE30.json').write_text(json.dumps({'passed':len(rows)==len(cases) and all(r['exit']==0 for r in rows),'runs':rows},indent=2),encoding='utf-8')
sys.exit(0 if len(rows)==len(cases) and all(r['exit']==0 for r in rows) else 1)
