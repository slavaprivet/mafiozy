import difflib,hashlib,json,pathlib
OUT=pathlib.Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
baseline=json.loads((OUT/'BASELINE30.json').read_text(encoding='utf-8'))
run=OUT/'runs/component04';result=json.loads((run/'RESULT.json').read_text(encoding='utf-8'))
assert result['passed'] and not result['drift'] and result['stderr_bytes']==0
pins=json.loads((run/'SOURCE.json').read_text(encoding='utf-8'))
files={};diff=[]
for rel,entry in baseline['files'].items():
    base=OUT/'baseline'/rel;candidate=OUT/rel
    assert sha(base)==entry['base_sha256'] and sha(candidate)==pins[rel],rel
    files[rel]={**entry,'candidate_sha256':sha(candidate)}
    diff.extend(difflib.unified_diff(base.read_text(encoding='utf-8').splitlines(keepends=True),candidate.read_text(encoding='utf-8').splitlines(keepends=True),fromfile='a/'+rel,tofile='b/'+rel))
(OUT/'CHANGES30.diff').write_text(''.join(diff),encoding='utf-8')
manifest={'status':'COMPONENT_PASS_PENDING_COHERENT55_MASS_AND_PERF','files':files,'last_component_run':'runs/component04','native_checks':result['native_checks'],'native_result_sha256':sha(run/'NATIVE.json'),'receipt_sha256':sha(run/'RESULT.json'),'changed_sources_archive_sha256':sha(run/'CHANGED_SOURCES.zip'),'source_pins_sha256':sha(run/'SOURCE.json'),'audit_sha256':sha(OUT/'AUDIT30.json'),'plan_sha256':sha(OUT/'PLAN30.md'),'apply_sha256':sha(OUT/'apply30.py'),'diff_sha256':sha(OUT/'CHANGES30.diff'),'production_modified':False,'native_capsules_peak':12,'pinned_residents':287,'separate_staff':12,'new_launch_flag':'--city-physical-dispatch30=1','physical_delta_scaled':False,'performance_accepted':False,'mass_behavior_accepted':False}
(OUT/'MANIFEST30.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(manifest))
