from pathlib import Path
from collections import Counter
import hashlib,json,re
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'outputs/coordinator30_release55/game'
LOG=ROOT/'outputs/current_game/interactive/20261015T013457352Z/play.log'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

text=LOG.read_text(encoding='utf-8-sig',errors='replace')
lines=text.splitlines()
blocks=[line for line in lines if line.startswith('NPC_ECONOMY28 ') and ' stage=blocked ' in line]
physical=[line for line in blocks if 'reason=physical_route_required' in line]
report={'read_only_log':str(LOG),'captured_log_bytes':len(text.encode('utf-8')),'log_capture_sha256':hashlib.sha256(text.encode('utf-8')).hexdigest(),
        'physical_route_required_count':len(physical),'affected_ids':sorted(set(re.findall(r'id=([^ ]+)', '\n'.join(physical)))),
        'blocked_reason_counts':dict(Counter(re.search(r'reason=(.*) frame=',s).group(1) for s in blocks if re.search(r'reason=(.*) frame=',s))),
        'latest_lives':[s for s in lines if s.startswith('DSH_LIVES ')][-4:],
        'latest_daily':[s for s in lines if s.startswith('DSH_DAILY ')][-4:],
        'latest_resident':[s for s in lines if s.startswith('DSH_RESID ')][-2:],
        'runtime_comparison_accepted':False,'leak_absence_claimed':False}
(HERE/'LOG_AUDIT56.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
proof={}
for name in ['baseline03','fixed03']:
    folder=HERE/'runs'/name
    result=json.loads((folder/'RESULT.json').read_text(encoding='utf-8'))
    check=json.loads((folder/'RUN_CHECK.json').read_text(encoding='utf-8'))
    sched=json.loads((folder/'engine/SCHEDULER_RUN.json').read_text(encoding='utf-8'))
    assert result['passed'] and check['exit']==0 and not check['source_drift'] and not check['harness_drift'] and sched['passed']
    proof[name]={'passed':True,'fixed':result['fixed'],'checks':len(result['checks']),'details':result['details'],'pins':{str(p.relative_to(HERE)):sha(p) for p in [folder/'RESULT.json',folder/'RUN_CHECK.json',folder/'SOURCE.json',folder/'SOURCE.zip',folder/'HARNESS.json',folder/'fixture56.gd',folder/'engine/SCHEDULER_RUN.json',folder/'engine/stdout.log',folder/'engine/stderr.log']}}
assert proof['baseline03']['fixed']==False and proof['fixed03']['fixed']==True
spec=json.loads((HERE/'PATCH56.json').read_text(encoding='utf-8'))
assert all(sha(BASE/f)==h for f,h in spec['baseline_sha256'].items())
acceptance={'status':'COMPONENT_PASS_CITY_INTEGRATION_PENDING','proof':proof,'frozen55_changed':False,'full_city_services_accepted':False,'287_fps_accepted':False,'leak_absence_claimed':False,'package_pins':{str(p.relative_to(HERE)):sha(p) for p in [HERE/'PATCH56.json',HERE/'apply56.py',HERE/'build_patch56.py',HERE/'run56.py',HERE/'fixture56.gd',HERE/'observer_counts56.gd']},'failure_history':{'baseline01':'Missing extends dependency in minimal fixture staging; preserved, not accepted.','fixed01':'Runner omitted --fixed; actually a baseline run. Preserved, not fixed evidence.','fixed02':'Wallet test compared reservation serial as if it were money; corrected to cash/bank/spent/inventory/receipts, preserved.'}}
(HERE/'ACCEPTANCE56.json').write_text(json.dumps(acceptance,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'proof':{k:{'checks':v['checks'],'fixed':v['fixed']} for k,v in proof.items()},'blocked_count':len(physical),'affected_ids':len(report['affected_ids']),'patch_sha256':sha(HERE/'PATCH56.json')},ensure_ascii=True))
