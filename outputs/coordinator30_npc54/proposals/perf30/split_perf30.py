"""Run the independent frozen baseline now, and the exact final candidate later."""
import argparse, json, sys
import perf_pair30 as perf

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('side',choices=['baseline','candidate'])
p.add_argument('name')
p.add_argument('--samples',type=int,default=300)
a=p.parse_args()
assert 150<=a.samples<=600
perf.POLICY.update(warmup_seconds=20,measurement_seconds=a.samples,seed=53)
pair=perf.OUT/'runs'/a.name
flags=perf.common_flags(20,a.samples,53)
baseline=perf.ROOT/'outputs/coordinator29_release53a/game'
candidate=perf.ROOT/'outputs/coordinator30_npc54/game'
plan={'baseline':str(baseline),'candidate':str(candidate),'flags':flags,'policy':perf.POLICY,
      'baseline_staff':0,'candidate_staff':12,'sequential_independent_sides':True}
if a.side=='baseline':
    pair.mkdir(parents=True,exist_ok=False)
    perf.write(pair/'PLAN.json',plan)
    sys.exit(0 if perf.run_one('baseline53a',baseline,pair/'baseline53a',0,flags) else 2)
assert json.loads((pair/'PLAN.json').read_text(encoding='utf-8'))==plan
camera=json.loads((pair/'baseline53a/PERF30.json').read_text(encoding='utf-8'))['camera']
flags+=['--qa-fixed-camera-json='+json.dumps(camera,separators=(',',':'))]
if not perf.run_one('candidate54',candidate,pair/'candidate54',12,flags):sys.exit(2)
result=perf.compare(pair)
print(json.dumps({'comparison':str(pair/'COMPARISON.json'),'measured_gates_passed':result['measured_gates_passed']}))
sys.exit(0 if result['measured_gates_passed'] else 3)
