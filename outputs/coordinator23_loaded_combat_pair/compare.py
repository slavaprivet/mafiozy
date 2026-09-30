"""Read-only descriptive comparison; no automatic performance acceptance threshold."""
import argparse,hashlib,json
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('before',type=Path)
parser.add_argument('after',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--optimization-pair',action='store_true',help='Compare pinned candidate08 -> candidate09 without changing their raw candidate labels.')
args=parser.parse_args()
b=json.loads(args.before.read_text(encoding='utf-8'))
a=json.loads(args.after.read_text(encoding='utf-8'))
errors=[]
labels=('before','after') if args.optimization_pair else ('baseline','candidate')
if args.optimization_pair:
    for role,result,expected in [('before',b,'710f2d40d852c4181d874494294ef236e6bc2d215ab216b4c016ad92e82c3c72'),('after',a,'51892e6818d85edf4903362de225e4c71eaf262134df859c3c2a012751d5d83e')]:
        if result.get('side')!='candidate':errors.append(role+': optimization pair requires raw candidate side')
        if result.get('pack_sha256')!=expected:errors.append(role+': optimization pack SHA mismatch')
elif b.get('side')!='baseline' or a.get('side')!='candidate':errors.append('wrong side order')
for key in ['test_sha256','settings','camera','physics_hz']:
    if a.get(key)!=b.get(key):errors.append('pair mismatch: '+key)
if not b.get('performance_valid') or not a.get('performance_valid'):errors.append('one side lacks complete rendered behavior acceptance')
report={'comparable':False,'errors':errors,'phases':[],'limits':['One corpse / two living residents, not 3 corpse saturation.','Observer render view fixed, actual attached spring aim computations/collisions still run.','First-use input-to-hit event windows are descriptive, not exclusive CPU attribution.','Correct foot impulse changes physical trajectory and active-body work; do not divide FPS by hits.','Source clock and naturally moving actor positions can differ: phase snapshots retain exact differences.']}
report['comparison_mode']='candidate08_to_candidate09_optimization' if args.optimization_pair else 'baseline_to_candidate'
report['inputs']={role:{'path':str(path.resolve()),'result_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'raw_side':result.get('side'),'pack_sha256':result.get('pack_sha256')} for role,path,result in zip(labels,(args.before,args.after),(b,a))}
report['limits'].append('Comparability does not establish cold-cache provenance; inspect the independent cache creation/restoration receipt. OS/driver cache state is not certified here.')
bp={x['id']:x for x in b['phases']};ap={x['id']:x for x in a['phases']}
if bp.keys()!=ap.keys():errors.append('phase sets differ')
for name in sorted(bp.keys()&ap.keys()):
    before=bp[name];after=ap[name];row={'phase':name,labels[0]:{},labels[1]:{},'p95_delta_percent':{}}
    for key in ['buildings','source_colliders','collision_objects','collision_shapes']:
        if before['before'][key]!=after['before'][key]:errors.append(name+': physical content mismatch '+key)
    for edge in ['before','after']:
        for obj in [before[edge],after[edge]]:
            if sorted(x['id'] for x in obj['actors'])!=['resident_169','resident_252','resident_72'] or obj['buildings']!=8:errors.append(name+': original actor/building count missing')
    for key in ['wall_ms','gpu_ms','render_cpu_ms','static_bytes','vram_bytes','drawcalls','primitives']:
        row[labels[0]][key]=before[key];row[labels[1]][key]=after[key]
        if before[key].get('p95',0)>0:row['p95_delta_percent'][key]=100*(after[key]['p95']/before[key]['p95']-1)
    row['work']={side:{'health':phase['after']['health'],'physical':phase['after']['physical'],'sampler':phase['after']['sampler']} for side,phase in zip(labels,(before,after))}
    report['phases'].append(row)
def first_use(r):
    e=next((e for e in r['events'] if e['kind']=='input_LMB'),None)
    if not e:return {}
    t=e['at_us'];allrows=[x for p in r['phases'] for x in p.get('raw_samples',[])]
    # Include any frame interval overlapping the window, not only frames ending
    # inside it: a long first-use stall can finish well after input+500 ms.
    window=[x for x in allrows if x['at_us']>=t-200000 and x['at_us']-x['wall_ms']*1000<=t+500000]
    hp=next((x for x in r['events'] if x['kind']=='completed_HP' and x['at_us']>=t),None)
    event_end=max(t+500000,hp['at_us'] if hp else t+500000)
    return {'input_at_us':t,'window_selection':'frame-interval overlap [-200,+500]ms; includes stalls ending after window','maximum_rendered_wall_ms':max((x['wall_ms'] for x in window),default=None),'maximum_gpu_ms':max((x['gpu_ms'] for x in window),default=None),'input_to_observed_HP_ms':(hp['at_us']-t)/1000 if hp else None,'event_window':[x for x in r['events'] if t<=x['at_us']<=event_end],'raw_render_window':window}
report['first_use']={label:first_use(result) for label,result in zip(labels,(b,a))}
report['comparable']=not errors
out=args.output;out.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'comparable':report['comparable'],'errors':errors,'output':str(out)}))
