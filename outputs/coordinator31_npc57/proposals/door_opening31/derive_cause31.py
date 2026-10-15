import json,pathlib,re,math,hashlib
OUT=pathlib.Path(__file__).resolve().parent
RUN=OUT.parent/'qa31_extended/runs/release57_1200_01'
soak=json.loads((RUN/'SOAK31.json').read_text())
rows=[dict(measure_ms=s['measure_ms'],frame=s['frame'],**r) for s in soak['samples'] if s['measure_ms']>=334314 for r in s['actors'] if r['id']=='resident_9']
positions=[r['position'] for r in rows]
events=[l for l in (RUN/'stdout.log').read_text(encoding='utf-8-sig').splitlines() if l.startswith('DSH_CLONEDOOR clone=VENUE29-SHOP-002 ')]
data={'schema':'mafiozi.door31.actual-cause/v1','source_run':str(RUN),'source_sha256':{n:hashlib.sha256((RUN/n).read_bytes()).hexdigest() for n in ['SOAK31.json','stdout.log']},'door_final_event':events[-1], 'door_previous_events':events[-10:], 'resident9':{'sample_count':len(rows),'start_ms':rows[0]['measure_ms'],'end_ms':rows[-1]['measure_ms'],'sampled_x_range':[min(p[0] for p in positions),max(p[0] for p in positions)],'sampled_z_range':[min(p[2] for p in positions),max(p[2] for p in positions)],'sampled_path_m':sum(math.dist(a,b) for a,b in zip(positions,positions[1:])),'max_motion_idle_s':max(r['motion_idle_s'] for r in rows),'all_roaming':all(r['roam_active'] and not r['venue'] for r in rows),'history':rows},'conclusion':'Actual native opening stopped at fraction0.692 by resident9; resident2 holds safe stage. Resident9 continues local motion inside leaf sweep, evading displacement-only idle gates. Inner-support cause is not needed to explain the actual closed fraction; current exact overlap and pair exceptions require new targeted fixture.'}
(OUT/'ACTUAL_CAUSE31.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps({k:v for k,v in data.items() if k!='resident9'}));print(json.dumps({k:v for k,v in data['resident9'].items() if k!='history'}))
