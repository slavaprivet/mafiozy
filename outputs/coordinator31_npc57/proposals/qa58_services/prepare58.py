"""Create a new provenance adapter; retain byte-identical native service semantics."""
import pathlib,json,hashlib
OUT=pathlib.Path(__file__).resolve().parent;BASE=OUT.parent/'services_regression31'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
origins={}
for name in ['accept_services56.py','entry_services56.gd','observer_counts56.gd','observer_services56.gd']:
    (OUT/name).write_bytes((BASE/name).read_bytes());origins[name]={'source':str(BASE/name),'sha256':sha(BASE/name),'unchanged':sha(OUT/name)==sha(BASE/name)}
s=(BASE/'run_services56.py').read_text(encoding='utf-8')
s=s.replace('"""Read-lease shared-city acceptance. Default prepares only; --go starts after root coordination."""','"""Exact1135-pin candidate58 graphical services; unchanged native observer/checker."""')
s=s.replace("    harness = {p.name: sha(p) for p in OUT.iterdir() if p.is_file() and p.suffix in ('.gd', '.py')}","    harness = {name: sha(OUT/name) for name in ['accept_services56.py','entry_services56.gd','observer_counts56.gd','observer_services56.gd','run_services58.py']}")
s=s.replace("    run = OUT / 'runs' / args.name",'''    expected_path=ROOT/'outputs/coordinator31_npc57/extended31/stage58_02/CANDIDATE58.json'
    assert sha(expected_path)=='4a00c3c85b4d705ce917c60a7d0b92deb634d24eb57b41cff2664d24e2cfb70e'
    expected_source=read(expected_path)['source_pins']
    assert len(expected_source)==1135 and pins(project)==expected_source
    assert args.mode=='graphical', 'Delivery services contract requires graphical mode'
    controls_files=[*[OUT/name for name in harness],expected_path,flag_source,ROOT/'tools/godot/test_scheduler.py',ROOT/'docs/godot/ENGINE_LOCK.json',ROOT/'godot/current_version.json',ROOT/'outputs/coordinator31_release57/bootstrap_play57.gd',engine]
    controls={str(p.resolve()):sha(p) for p in controls_files}
    run = OUT / 'runs' / args.name''')
s=s.replace("    save(run / 'FLAGS.json', flags)","    save(run / 'FLAGS.json', flags)\n    save(run/'CONTROL_PINS.json',controls)")
s=s.replace("'HARNESS_SOURCES.zip'","'HARNESS.zip'")
s=s.replace("    before = {}","    record.update(engine_sha256=sha(engine),scheduler_sha256=SCHEDULER_SHA,candidate_sha256=sha(expected_path),harness_archive_sha256=sha(run/'HARNESS.zip'))\n    before = {}")
s=s.replace("            before = pins(project)","            before = pins(project)\n            assert before==expected_source, 'Candidate source changed before native launch'")
s=s.replace("                record['harness_drift'] =", "                after_controls={str(p.resolve()):sha(p) for p in controls_files}\n                save(run/'CONTROL_PINS_AFTER.json',after_controls)\n                record['control_drift']=drift(controls,after_controls)\n                assert after==expected_source, 'Candidate source changed during native run'\n                record['harness_drift'] =")
s=s.replace("and not record['harness_drift'] and all(checks.values())","and not record['harness_drift'] and not record['control_drift'] and all(checks.values())")
(OUT/'run_services58.py').write_text(s,encoding='utf-8')
(OUT/'PREPARATION58.json').write_text(json.dumps({'native_semantics_unchanged':origins,'original_runner_sha256':sha(BASE/'run_services56.py'),'adapter_sha256':sha(OUT/'run_services58.py'),'changes':['exact candidate1135 pins before and after','engine/scheduler and controls identities before/after','archive transitive five-file harness','graphical delivery mode required'],'production_modified':False},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'copied_native_files':len(origins),'native_unchanged':all(r['unchanged'] for r in origins.values()),'adapter_sha256':sha(OUT/'run_services58.py')}))
