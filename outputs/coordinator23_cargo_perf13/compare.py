from pathlib import Path
import argparse,json,math,hashlib
P=argparse.ArgumentParser();P.add_argument('--before',type=Path,required=True);P.add_argument('--after',type=Path,required=True);P.add_argument('--candidate-sha',required=True);P.add_argument('--out',type=Path,required=True);a=P.parse_args()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
b=load(a.before/'RESULT.json');c=load(a.after/'RESULT.json');br=load(a.before/'RUN.json');cr=load(a.after/'RUN.json');errors=[]
def require(value,msg):
 if not value:errors.append(msg)
require(b['side']=='baseline' and c['side']=='candidate','side labels')
require(b['pack_sha256']=='ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e','baseline hash')
require(c['pack_sha256']==a.candidate_sha.lower(),'candidate hash')
for raw,run,label in [(b,br,'before'),(c,cr,'after')]:
 require(raw['valid'] and not raw['errors'] and run.get('exit_code')==0,label+' runtime PASS')
 require(raw['pack_sha256']==run['pack_sha256'] and raw['harness_sha256']==run['harness_sha256'],label+' run closure')
 require(len(raw['phases'])==3 and len(raw['samples'])==720,label+' full720 frames')
require(b['settings']==c['settings'],'same rendering/window/camera settings');require(b['harness_sha256']==c['harness_sha256'],'identical harness')
require(br['cache_note']==cr['cache_note'],'declared matching cache policy')
def ammo(state):return {k:{f:v[f] for f in ['magazine','reserve']} for k,v in state['cargo_identity'].items()}
def stat(values):
 values=sorted(values);return {'n':len(values),'p50':values[math.ceil(len(values)*.5)-1],'p95':values[math.ceil(len(values)*.95)-1],'max':values[-1]} if values else {'n':0}
result_phases=[]
for bp,cp in zip(b['phases'],c['phases']):
 require(bp['label']==cp['label'] and bp['frames']==cp['frames']==240,'same phase/frame count')
 for edge in ['before','after']:
  x=bp[edge];y=cp[edge]
  for field in ['npc','buildings','bodies','shapes','cargo_count','used_units','camera_top_level','fov','yaw','pitch','window_open','lid_open','mouse_mode','unfocusable','window_focused','window_position']:
   require(x[field]==y[field],bp['label']+'/'+edge+'/'+field)
  require(x['npc']==3 and x['buildings']==8 and x['bodies']==x['shapes']==377 and x['cargo_count']==14 and x['used_units']==100,'full content')
  require(ammo(x)==ammo(y),'same original ammunition')
  require([(v['id'],v['bones'],v['hp']) for v in x['actors']]==[(v['id'],v['bones'],v['hp']) for v in y['actors']],'same3 original healthy rigs')
  for field in ['camera_position','camera_basis','player']:
   require(max(abs(i-j) for i,j in zip(x[field],y[field]))<.01,bp['label']+'/'+edge+'/'+field+' within1cm or.01basis')
 metrics={}
 for field in ['wall_ms','gpu_ms','render_cpu_ms','static_bytes','vram_bytes','drawcalls','primitives']:
  metrics[field]={'before':bp[field],'after':cp[field],'p95_delta':cp[field]['p95']-bp[field]['p95'],'max_delta':cp[field]['max']-bp[field]['max']}
 result_phases.append({'label':bp['label'],'metrics':metrics})
first={}
for raw,label in [(b,'before'),(c,'after')]:
 phase=raw['phases'][0];start=phase['transition_us'];end=min(start+1000000,phase['end_us'])
 # Include every frame interval overlapping the window, even if a stall ends later.
 rows=[v for v in raw['samples'] if v['phase']==phase['label'] and v['at_us']>start and v['at_us']-v['wall_ms']*1000<end]
 first[label]={'interval_start_us':start,'nominal_end_us':end,'wall_ms':stat([v['wall_ms'] for v in rows]),'gpu_ms':stat([v['gpu_ms'] for v in rows]),'actual_first_hover':raw['first_hover'],'hover_status':raw['first_hover_status']}
report={'comparable':not errors,'errors':errors,'baseline_sha':b['pack_sha256'],'candidate_sha':c['pack_sha256'],'phases':result_phases,'first_transition_window':first,'cache_note':br['cache_note'],'limits':['No automatic performance acceptance threshold; root reviews raw tails and first-use maxima','Offscreen NO_FOCUS conditional measurement; not global FPS/native input acceptance','Natural3NPC simulation not frozen, actor positions recorded in raw snapshots','First model hover can be SKIP at fixed attached yaw; no substituted camera']}
a.out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps({'comparable':report['comparable'],'errors':errors}));raise SystemExit(0 if report['comparable'] else 2)
