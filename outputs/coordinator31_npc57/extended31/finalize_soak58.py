"""Audit a terminal candidate58 soak without rewriting native receipts."""
import argparse,hashlib,json,math,pathlib,runpy,sys,zipfile
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2]
WORK=HERE.parent

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):
    assert not p.exists(),'Preserve existing audit: '+str(p)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('run',type=pathlib.Path)
    p.add_argument('--manifest',type=pathlib.Path,default=HERE/'stage58_02/CANDIDATE58.json')
    a=p.parse_args();folder=a.run.resolve();folder.relative_to(WORK/'proposals/qa58_merged/runs')
    receipt=read(folder/'RUN.json');assert 'exit_code' in receipt,'Native run has not ended'
    assert not (folder/'FINAL_AUDIT58.json').exists()
    raw_names=['RUN.json','SOURCE.json','SOURCE_AFTER.json','SOAK31.json','MASS30.json',
        'SLOW_PLANNER31.json','OS_MEMORY.json','CONTROL_PINS.json','CONTROL_PINS_AFTER.json',
        'HARNESS.json','HARNESS.zip','SPATIAL58.json','stdout.log','stderr.log']
    raw={name:sha(folder/name) for name in raw_names}
    analyzers=[WORK/'proposals/qa31_resume/analyze_soak31.py',
               WORK/'proposals/qa31_extended/analyze_cycles_extended31.py',
               HERE/'audit_spatial_liveness31.py',pathlib.Path(__file__)]
    script_pins={f.relative_to(ROOT).as_posix():sha(f) for f in analyzers}
    with zipfile.ZipFile(folder/'ANALYZERS58.zip','x',zipfile.ZIP_DEFLATED) as z:
        for f in analyzers:z.write(f,f.relative_to(ROOT).as_posix())
    for analyzer in analyzers[:2]:
        output='ANALYSIS.json' if analyzer==analyzers[0] else 'CYCLES31.json'
        assert not (folder/output).exists()
        old=sys.argv;sys.argv=[str(analyzer),str(folder)]
        try:runpy.run_path(str(analyzer),run_name='__main__')
        finally:sys.argv=old
    from audit_spatial_liveness31 import audit
    mass=read(folder/'MASS30.json');soak=read(folder/'SOAK31.json')
    analysis=read(folder/'ANALYSIS.json');cycles=read(folder/'CYCLES31.json')
    spatial=read(folder/'SPATIAL58.json');source=read(a.manifest)['source_pins']
    times=mass['frame_at_s'];samples=soak['samples'];sample_times=[s['measure_ms']/1000 for s in samples]
    # The inherited finish chain serializes large native reports BEFORE recording
    # actual_measurement_elapsed_s. Millisecond frame stamps may legitimately tie.
    elapsed=times[-1];reported=mass['actual_measurement_elapsed_s']
    frames=mass['frame_ms'];frame_duration=sum(frames)/1000
    ticks=sum(soak['physics_steps_per_render'])
    gates={
        'terminal_native_passed':receipt.get('passed') is True and receipt.get('exit_code')==0,
        'exact_candidate_before_after':read(folder/'SOURCE.json')==read(folder/'SOURCE_AFTER.json')==source,
        'unchanged_controls':read(folder/'CONTROL_PINS.json')==read(folder/'CONTROL_PINS_AFTER.json'),
        'no_source_control_harness_drift':all(receipt.get(k)==[] for k in ['source_drift','control_drift','harness_drift']),
        'no_native_errors':receipt.get('errors')==[] and receipt.get('stderr_bytes')==0 and not soak['errors'],
        'full1200_native_timeline':mass['measurement_seconds']>=1200 and 1199.9<=elapsed<=1201,
        'valid_native_frame_time':bool(times) and all(math.isfinite(t) and t>=0 for t in times)
            and all(b>=a for a,b in zip(times,times[1:]))
            and len(frames)==len(times) and all(math.isfinite(t) and t>0 for t in frames),
        'full1200_sampled_frame_duration':1199.9<=frame_duration<=1201,
        'complete_physics_accounting':soak['physics_sample_count']==mass['frame_count']==len(times),
        'sixty_native_ticks_per_second':59.5<=ticks/elapsed<=60.5,
        'complete_1hz_population_observation':len(samples)>=1197 and all(s['count']==10 for s in samples),
        'bounded_1hz_observation_gaps':all(0<b-a<=2.5 for a,b in zip(sample_times,sample_times[1:])),
        'spatial_recalculation_matches':spatial==audit(folder/'SOAK31.json'),
        'no_confined_motion_episodes':spatial.get('passed') is True and spatial.get('episodes')==[],
        'all_ten_moved':mass['moved_residents']==10,
    }
    result={'schema':'mafiozi.qa58.final-soak-audit/v1','passed':all(gates.values()),'gates':gates,
        'performance_accepted':False,'source_manifest':str(a.manifest.resolve()),'source_manifest_sha256':sha(a.manifest),
        'seconds':elapsed,'native_timeline_elapsed_s':elapsed,'sampled_frame_duration_s':frame_duration,
        'report_elapsed_including_serialization_s':reported,
        'post_observation_serialization_s':max(0,reported-elapsed),
        'physical_ticks':ticks,'actor_samples':len(samples),'render_samples':len(times),
        'max_motion_idle_s':max(r['max_motion_idle_s'] for r in analysis['per_id']),
        'max_queue_idle_s':max(r['max_queue_idle_s'] for r in analysis['per_id']),
        'completion_deltas':{key:sum(r['completion_deltas_within_measurement'].get(key,0) for r in analysis['per_id'])
            for key in ['shop','restaurant','hospital','bank','walk']},
        'full_shopping_cycles':cycles['full_observed_shopping_cycles'],
        'native_trends':analysis['native_trends'],'os_trends':analysis['os_trends'],
        'raw_evidence_sha256':raw,'analyzer_pins':script_pins,'analyzer_archive_sha256':sha(folder/'ANALYZERS58.zip'),
        'limitations':['Natural finite observation does not cover every service or threat; separate native fixtures are required.',
            'Headless alongside user game is functional evidence only, not comparable rendered FPS.',
            'Memory includes bounded observer buffers; finite increases alone do not establish a leak.']}
    assert raw=={name:sha(folder/name) for name in raw_names},'Native evidence changed during analysis'
    save(folder/'FINAL_AUDIT58.json',result)
    print(json.dumps({k:result[k] for k in ['passed','gates','seconds','physical_ticks','actor_samples','max_motion_idle_s','max_queue_idle_s','completion_deltas','full_shopping_cycles']}))
    return 0 if result['passed'] else 1

if __name__=='__main__':sys.exit(main())
