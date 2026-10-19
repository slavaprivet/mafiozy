"""Read-only post-audit of final native receipts; writes one separate handoff."""
from pathlib import Path
import hashlib,json,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
results={}
for name in ['shop_final01','restaurant_final01']:
 folder=HERE/'runs'/name
 if not (folder/'RUN.json').exists():continue
 run=read(folder/'RUN.json');native=read(folder/'SERVICE_THREAT58.json')
 inventory=read(folder/'HARNESS.json');controls=read(folder/'CONTROL_PINS.json')
 with zipfile.ZipFile(folder/'HARNESS.zip') as archive:
  exact=len(archive.namelist())==len(set(archive.namelist())) and set(archive.namelist())==set(inventory)
  hashes=all(hashlib.sha256(archive.read(rel)).hexdigest()==digest for rel,digest in inventory.items())
  missing=[path for path,digest in controls.items() if Path(path).suffix.lower()!='.exe' and inventory.get(Path(path).relative_to(ROOT).as_posix())!=digest]
 entry=Path(run['command'][run['command'].index('--script')+1]).relative_to(ROOT).as_posix()
 source=read(folder/'SOURCE.json')
 snapshot=read(Path(run['expected_source']))
 checks={
  'run_passed':run.get('passed') is True,'native_all_checks_passed':native.get('passed') is True and all(v is True for v in native['checks'].values()),
  'nineteen_checks':len(native['checks'])==19,'ordinary_source_no_overlay':run.get('overlay') is False and run.get('source_stage')=='merged58',
  'explicit_manifest_sha':sha(Path(run['expected_source']))==run['expected_source_sha256'],
  'exact_full_source_before_after':source==snapshot['source_pins']==read(folder/'SOURCE_AFTER.json'),
  'full_controls_before_after':controls==read(folder/'CONTROL_PINS_AFTER.json'),
  'immutable_archive_inventory':exact,'immutable_archive_all_hashes':hashes,'all_non_engine_controls_archived':not missing,
  'harness_before_after':inventory==read(folder/'HARNESS_AFTER.json'),
  'ordinary_entry_pin':inventory.get(entry)=='64898ff896767bceb81da3ac6d35bfc4a1b8c508b2a8f5f7e769f4c01c4ab986',
  'native_receipt_sha':sha(folder/'SERVICE_THREAT58.json')==run['native_sha256'],
  'clean_process':run.get('exit_code')==0 and run.get('stderr_bytes')==0 and run.get('errors')==[],
 }
 record={'passed':all(checks.values()),'checks':checks,'native_checks':native['checks'],'path':str(folder.relative_to(ROOT)),
  'run_sha256':sha(folder/'RUN.json'),'native_sha256':sha(folder/'SERVICE_THREAT58.json'),
  'harness_archive_sha256':sha(folder/'HARNESS.zip'),'source_count':len(source),'control_count':len(controls),
  'harness_count':len(inventory),'expected_source':run['expected_source'],'expected_source_sha256':run['expected_source_sha256'],
  'elapsed_seconds':run['elapsed_seconds'],
 }
 record.update({k:native[k] for k in ['flee_m','max_flee_speed','max_step_m','fire_sent58','interruption','payment','other_nine_distance_m']})
 record['flee_samples']=[{'ms':row['ms'],'position':row['position'],'driver':row['threat']['driver']} for row in native['samples'] if row['threat'].get('phase')=='FLEE'][:3]
 results[name]=record
passed=set(results)=={'shop_final01','restaurant_final01'} and all(row['passed'] for row in results.values())
summary={'status':'FINAL_MERGED_SERVICE_INTERRUPTION_PASS' if passed else 'PENDING_OR_FAILED','passed':passed,
 'scope':'Native shop and restaurant service interruptions in exact merged candidate58. FullHP, real inside unpaid shot, physical exit, flee, quiet15, actual saved purchase, normal walk, other9 movement.',
 'runs':results,'performance_accepted':False,'ordinary_release_accepted':False,
 'limits':['These two functional runs do not replace the coordinator1200s ordinary soak, other service/health regressions, clean paired FPS or delivery.'],
 'evidence_specs':{role:{'run':'outputs/coordinator31_npc57/proposals/service_threat58_final/runs/'+name,'harness_root':'.','entry':'outputs/coordinator31_npc57/proposals/service_threat58_final/entry58.gd','entry_sha256':'64898ff896767bceb81da3ac6d35bfc4a1b8c508b2a8f5f7e769f4c01c4ab986','pins_file':'HARNESS.json','archive':'HARNESS.zip'} for role,name in [('shop_interruption','shop_final01'),('restaurant_interruption','restaurant_final01')]}}
(HERE/'HANDOFF58.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({'status':summary['status'],'runs':{n:{'passed':r['passed'],'flee_m':r['flee_m'],'max_flee_speed':r['max_flee_speed']} for n,r in results.items()}}))
