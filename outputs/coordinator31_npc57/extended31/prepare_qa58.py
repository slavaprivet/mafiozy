"""Create a new exact-candidate observer; preserve all previous receipts/harnesses."""
import pathlib,shutil,hashlib,json
ROOT=pathlib.Path(__file__).resolve().parents[3]
BASE=ROOT/'outputs/coordinator31_npc57/proposals/qa31_extended'
OUT=BASE.parent/'qa58_merged'
assert not OUT.exists();OUT.mkdir()
names=['archive_harness31.py','entry_soak31_extended.gd','observer_soak31_v3.gd','observer_soak31_v2.gd','observer_mass_extended.gd','observer_perf_extended.gd']
for name in names:shutil.copy2(BASE/name,OUT/name)
shutil.copy2(ROOT/'outputs/coordinator31_npc57/extended31/audit_spatial_liveness31.py',OUT/'audit_spatial_liveness31.py')

def replace(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)

runner=(BASE/'run_extended31.py').read_text(encoding='utf-8')
runner=replace(runner,"from archive_harness31 import archive","from archive_harness31 import archive\nfrom audit_spatial_liveness31 import audit as spatial_audit")
runner=replace(runner,"GAME = ROOT / 'outputs/coordinator31_release57/game'","GAME = ROOT / 'outputs/coordinator31_npc57/game'")
runner=replace(runner,"parser.add_argument('--project', type=Path, default=GAME)","parser.add_argument('--project', type=Path, default=GAME)\n    parser.add_argument('--expected-source', type=Path, required=True)")
runner=replace(runner,"'Extended QA is pinned to release57'","'Merged QA requires the owned candidate project'")
runner=replace(runner,"control_files = [*harness_files, engine]","harness_files += [OUT / 'audit_spatial_liveness31.py', args.expected_source.resolve()]\n    control_files = [*harness_files, engine, ROOT / 'godot/current_version.json']")
runner=replace(runner,"need(before == read(assembly_path)['source_pins'], 'Exact release57 ASSEMBLY source mismatch')","expected = read(args.expected_source)\n            need(before == expected.get('source_pins', expected), 'Exact reviewed candidate pins mismatch')")
runner=replace(runner,"record['release_source_matches_assembly'] = True","record['candidate_source_matches_reviewed_pins'] = True")
runner=replace(runner,"slow = read(run / 'SLOW_PLANNER31.json')","slow = read(run / 'SLOW_PLANNER31.json')\n            spatial = spatial_audit(run / 'SOAK31.json')\n            save(run / 'SPATIAL58.json', spatial)\n            record['spatial_liveness_passed'] = spatial['passed']\n            record['spatial_episodes'] = spatial['episodes']")
runner=replace(runner,"and record['resolution_ok'] and record['camera_matches_baseline']","and record['resolution_ok'] and record['camera_matches_baseline'] and record['spatial_liveness_passed']")
(OUT/'run58.py').write_text(runner,encoding='utf-8')

path=OUT/'observer_perf_extended.gd';text=path.read_text(encoding='utf-8')
text=replace(text,'\t\t_last_sample=now','\t\t# Keep the1Hz cadence on its original clock grid instead of accumulating frame rounding.\n\t\t_last_sample += maxi(1, int((now-_last_sample)/1000))*1000')
path.write_text(text,encoding='utf-8')
path=OUT/'observer_soak31_v2.gd';text=path.read_text(encoding='utf-8')
text=replace(text,'"motion_idle_s":0.0,"queue_idle_s":0.0,','"motion_idle_s":0.0,"queue_idle_s":0.0,\n\t\t"driver_target":[],"driver_waypoint":[],"door_fraction":-1.0,"door_blocked_reason":"",')
text=replace(text,'\t\tdriver = outer._drive','\t\tdriver = outer._drive\n\t\tif is_instance_valid(outer._door_owner):\n\t\t\trow.door_fraction = outer._door_owner.fraction\n\t\t\trow.door_blocked_reason = outer._door_owner._blocked_reason')
text=replace(text,'\t\trow.route_attempts = driver._attempts','\t\trow.route_attempts = driver._attempts\n\t\trow.driver_target = [driver._target.x,driver._target.y,driver._target.z]\n\t\tif driver._route != null and driver._way >= 0 and driver._way < driver._route.route.size():\n\t\t\tvar waypoint: Vector3 = driver._route.route[driver._way]\n\t\t\trow.driver_waypoint = [waypoint.x,waypoint.y,waypoint.z]')
path.write_text(text,encoding='utf-8')
evidence={'prepared_only':True,'production_modified':False,'base_harness':str(BASE),'changes':['Exact reviewed merged source pins required','Mandatory spatial confinement postgate','Absolute1Hz sampling cadence','Read-only driver target/waypoint and actual door fraction/blocker'], 'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.is_file()}}
(OUT/'PREPARED58.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'prepared':True,'files':len(evidence['files']),'out':str(OUT)}))
