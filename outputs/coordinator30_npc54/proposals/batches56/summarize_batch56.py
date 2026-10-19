from pathlib import Path
import argparse, importlib.util, json, statistics
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('run',type=Path);a=p.parse_args()
spec=importlib.util.spec_from_file_location('batch_perf',HERE.parent/'perf30/perf_pair30.py')
perf=importlib.util.module_from_spec(spec);spec.loader.exec_module(perf)
native=json.loads((a.run/'MASS30.json').read_text(encoding='utf-8'))
receipt=json.loads((a.run/'RUN.json').read_text(encoding='utf-8'))
frames=native['frame_ms'];samples=[s for s in native['samples'] if s['measure_ms']>=0]
osrows=json.loads((a.run/'OS_MEMORY.json').read_text(encoding='utf-8'))['samples']
osrows=[s for s in osrows if native['measurement_start_unix_ms']<=s['unix_ms']<=native['measurement_end_unix_ms']]
report={'resident_count':native['expected_residents'],'staff_count':native['expected_staff'],'native_pass':receipt['passed'],'exclusive_clean':receipt.get('perf_environment_clean',False),'seconds':native['measurement_seconds'],'mean_fps':1000/statistics.mean(frames),'frame_ms':{f'p{q}':perf.pct(frames,q/100) for q in [50,95,99]},'moved_residents':native['moved_residents'],'completions':native['mass_samples'][-1]['completions'],'camera':native['camera'],'memory_trends':{k:perf.trend(osrows,k,'unix_ms') for k in ['rss_bytes','private_bytes']},'object_trends':{k:perf.trend(samples,k,'measure_ms') for k in ['objects','nodes','resources','orphans','static_memory']},'finite_window_only':True,'full_city_accepted':False,'services_and_reactions_separate':True}
report['performance_gate']=report['native_pass'] and report['exclusive_clean'] and report['frame_ms']['p95']<=1000/60 and report['mean_fps']>=60 and report['moved_residents']==report['resident_count']
(a.run/'PERFORMANCE_SUMMARY.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['memory_trends','object_trends','camera']},ensure_ascii=False))
