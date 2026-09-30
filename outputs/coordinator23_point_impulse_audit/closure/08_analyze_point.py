from pathlib import Path
import json,math,sys,hashlib,re
O=Path(__file__).resolve().parent;name=sys.argv[1]
r=json.loads((O/(name+'.json')).read_text()); rows=r['report']['rows'];out=[]
def key(x):return (x['actor'],x['height'],tuple(x['direction']),x['medical'])
base={key(x):x for x in rows if not x['candidate']}
for c in rows:
 if not c['candidate']:continue
 b=base[key(c)];bone=c['impulse']['point_result']['bone'];cs={s['tick']:s for s in c['samples']};bs={s['tick']:s for s in b['samples']}
 delta=math.dist(cs[2]['segments'][bone]['angular'],bs[2]['segments'][bone]['angular'])
 qa=cs[10]['segments'][bone]['rotation'];qb=bs[10]['segments'][bone]['rotation'];dot=abs(sum(a*b for a,b in zip(qa,qb)));angle=2*math.acos(min(1,dot))*180/math.pi
 torque=[float(x) for x in re.findall(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?',c['impulse'].get('point_torque_ns_m',''))]
 angular_delta=[x-y for x,y in zip(cs[2]['segments'][bone]['angular'],bs[2]['segments'][bone]['angular'])]
 sign=sum(x*y for x,y in zip(torque,angular_delta)) if torque else None
 out.append({'actor':c['actor'],'height':c['height'],'direction':c['direction'],'medical':c['medical'],'bone':bone,'second_tick_angular_delta_rad_s':delta,'delta_omega_dot_actual_point_torque':sign,'tenth_tick_orientation_delta_deg':angle,'distance_baseline_m':b['metrics']['distance'],'distance_point_m':c['metrics']['distance'],'joint_baseline_m':b['metrics']['joint'],'joint_point_m':c['metrics']['joint'],'floor_delta_m':c['metrics']['floor']-b['metrics']['floor']})
errors=[]
for x in out:
 if x['second_tick_angular_delta_rad_s']<.01:errors.append('no measurable point torque '+str(x))
 if x['floor_delta_m']<-.00001:errors.append('floor worse than baseline '+str(x))
 if x['delta_omega_dot_actual_point_torque'] is not None and x['delta_omega_dot_actual_point_torque']<=0:errors.append('point angular response sign mismatch '+str(x))
report={'native_checks':r['report']['checks'],'native_errors':r['report']['errors'],'comparison_errors':errors,'rows':out,'source_report_sha256':hashlib.sha256((O/(name+'.json')).read_bytes()).hexdigest()}
(O/(name+'_comparison.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
