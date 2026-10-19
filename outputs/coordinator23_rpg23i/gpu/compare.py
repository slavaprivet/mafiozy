"""Compare only PERF runs; visual replay PNG readbacks are never timing evidence."""
from pathlib import Path
import argparse,json,math
p=argparse.ArgumentParser();p.add_argument('--before',type=Path,required=True);p.add_argument('--after',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
b,c=load(a.before/'RESULT.json'),load(a.after/'RESULT.json');br,cr=load(a.before/'RUN.json'),load(a.after/'RUN.json');errors=[]
def req(v,label):
    if not v:errors.append(label)
def stats(values):
    v=sorted(values)
    return {'n':len(v),'p50':v[math.ceil(len(v)*.5)-1],'p95':v[math.ceil(len(v)*.95)-1],'max':v[-1]} if v else {'n':0}
def near(x,y,tol=.01):return len(x)==len(y) and all(abs(i-j)<tol for i,j in zip(x,y))
for value,run,label in [(b,br,'baseline'),(c,cr,'candidate')]:
    req(value['valid'] and not value['errors'] and run.get('exit_code')==0,label+' runtime PASS')
    req(value['schema']=='rpg-render-pair/v2',label+' v2 retained-body accounting')
    req(value['mode']==run['mode']=='perf',label+' perf without readbacks')
    req(value['side']==label and value['pack_sha256']==run['pack_sha256'] and value['harness_sha256']==run['harness_sha256'],label+' closed receipt')
    req(len(value['phases'])==3 and len(value['samples'])==960,label+' complete960frames')
    req(bool(run['memory_samples']),label+' native process memory available')
req(b['pack_sha256']=='8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741','accepted16 baseline')
req(b['settings']==c['settings'] and b['harness_sha256']==c['harness_sha256'],'same settings/harness')
req(br['cache_note']==cr['cache_note'],'same declared cache policy')
for key in ['player','camera_position','camera_basis','aim_point']:req(near(b['fixture'][key],c['fixture'][key]),'same initial '+key)
req([(r['id'],r['hp'],r['bones']) for r in b['fixture']['actors']]==[(r['id'],r['hp'],r['bones']) for r in c['fixture']['actors']],'same initial original actors/health/rigs')
result=[]
for bp,cp in zip(b['phases'],c['phases']):
    req(bp['label']==cp['label'] and bp['frames']==cp['frames'],'matched phase/render count')
    for edge in ['before','after']:
        x,y=bp[edge],cp[edge]
        for state in [x,y]:req(state['npc']==3 and state['buildings']==8 and state['colliders']==state['shapes']==377 and all(r['bodies']==16 and r['parts_in_tree']==16 and r['body_in_tree'] and r['rig_in_tree'] and r['bones']==28 for r in state['actors']),'full content retained')
        for key in ['camera_top_level','yaw','pitch','fov','magazine','reserve','mouse_mode','unfocusable']:req(x[key]==y[key],bp['label']+'/'+edge+'/'+key)
        for key in ['player','camera_position','camera_basis']:req(near(x[key],y[key]),bp['label']+'/'+edge+'/'+key)
    metrics={}
    for key in ['wall_ms','gpu_ms','render_cpu_ms','static_bytes','video_bytes','drawcalls','primitives']:
        metrics[key]={'baseline':bp[key],'candidate':cp[key],'p95_delta':cp[key]['p95']-bp[key]['p95'],'max_delta':cp[key]['max']-bp[key]['max']}
    for key in ['working_set_bytes','private_bytes']:
        xs=stats([r[key] for r in br['memory_samples'] if bp['begin_utc']<=r['utc']<=bp['end_utc']]);ys=stats([r[key] for r in cr['memory_samples'] if cp['begin_utc']<=r['utc']<=cp['end_utc']]);req(xs['n']>0 and ys['n']>0,'process memory phase sample')
        metrics[key]={'baseline':xs,'candidate':ys}
    result.append({'label':bp['label'],'metrics':metrics,'baseline_living_npc':bp['after']['living_npc'],'candidate_living_npc':cp['after']['living_npc'],'baseline_actors':bp['after']['actors'],'candidate_actors':cp['after']['actors']})
report={'comparable':not errors,'errors':errors,'baseline_sha':b['pack_sha256'],'candidate_sha':c['pack_sha256'],'phases':result,'limits':['Additional candidate HP/ragdoll cost is intended workload, not a pure same-workload optimization test.','Original content is retained. Do not demand equal postblast HP/poses or compensate by hiding corpses.','Attached camera must remain comparable; spring collision difference invalidates strict view comparison.','Visual replay is separate, never used for timings.','No automatic acceptance threshold; root reviews p95/max/first-use events and raw samples.']}
a.out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps({'comparable':not errors,'errors':errors}));raise SystemExit(0 if not errors else 2)
