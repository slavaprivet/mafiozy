import pathlib,json,hashlib,zipfile,difflib
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3];GAME=ROOT/'outputs/coordinator31_release57/game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
manifest=read(OUT/'PATCH.json');reports=[]
for case in ['recovery','closed','pause','cancel','revoke','player','retire','watch']:
    run=OUT/'runs'/(case+'_final03');r=read(run/'RUN.json');native=read(run/'NATIVE31.json');harness=read(run/'HARNESS.json')
    assert r['passed'] and r['execution_clean'] and not r['source_drift'] and not r['harness_drift'],case
    for rel,pins in manifest.items():
        assert sha(OUT/'patch'/rel)==pins['candidate_sha256']==harness['patch/'+rel],(case,rel)
    reports.append({'case':case,'run':str(run.relative_to(OUT)),'passed':True,'checks':len(r['native_checks']),'elapsed_s':native['elapsed_s'],'wall_s':native['wall_s'],'max_native_step_m':native['max_native_step_m'],'watch':native['watch'] if case=='watch' else {},'hashes':{n:sha(run/n) for n in ['RUN.json','NATIVE31.json','SOURCE.json','SOURCE_AFTER.json','HARNESS.json','HARNESS.zip']}})
diff=''
for rel,pins in manifest.items():
    base=(GAME/rel).read_text(encoding='utf-8').splitlines(keepends=True) if pins['base_sha256'] else []
    patch=(OUT/'patch'/rel).read_text(encoding='utf-8').splitlines(keepends=True)
    diff+=''.join(difflib.unified_diff(base,patch,fromfile='a/'+rel if base else '/dev/null',tofile='b/'+rel))
(OUT/'DOOR_OPENING31.patch').write_text(diff,encoding='utf-8')
with zipfile.ZipFile(OUT/'DOOR_OPENING31_SOURCE.zip','w',zipfile.ZIP_DEFLATED) as z:
    for rel in manifest:z.write(OUT/'patch'/rel,rel)
    z.write(OUT/'PATCH.json','PATCH.json')
result={'schema':'mafiozi.door-opening31.acceptance/v1','targeted_acceptance':True,'full_scene_acceptance':False,'performance_accepted':False,'production_modified':False,'user_game_preserved':True,'manifest':manifest,'cases':reports,'checks_passed':sum(r['checks'] for r in reports),'checks_total':sum(r['checks'] for r in reports),'source_zip_sha256':sha(OUT/'DOOR_OPENING31_SOURCE.zip'),'diff_sha256':sha(OUT/'DOOR_OPENING31.patch'),'actual_cause_sha256':sha(OUT/'ACTUAL_CAUSE31.json'),'review':{'reviewer':'/root/godot_addons31','status':'Limited read-only review clean after fixing per-step RoamWait accounting; reviewer independently confirmed watch_final03 receipt.'},'limits':['Actual prolonged failure is preserved in release57_1200_01. Short targeted baseline reproduces blocked sweep, but may clear with a simpler outdoor waypoint; it does not reproduce the exact865s treadmill.','Merged natural1200s plus spatial-progress gate and all-service regressions remain required before delivery.','Behavior is deliberately roam-only; medical/service routes retain their existing staged passage, flee drivers are unaffected.','Physical player obstruction remains physical: bounded helper failure is not an accepted successful exit.']}
(OUT/'ACCEPTANCE.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'targeted_acceptance':True,'checks':result['checks_passed'],'cases':[{k:r[k] for k in ['case','elapsed_s','checks']} for r in reports],'source_zip_sha256':result['source_zip_sha256']}))
