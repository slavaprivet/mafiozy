"""Read-only native receipt and immutable provenance audit; never relabel failed runs."""
import pathlib,json,hashlib,zipfile
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3]
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=ROOT/'outputs/coordinator31_npc57/extended31/stage58_02/CANDIDATE58.json'
expected=read(manifest)['source_pins'];run=OUT/'runs/merged58_services_graphical02'
receipt=read(run/'RUN.json');native=read(run/'SERVICES56.json')
pins=read(run/'HARNESS_PINS.json')
with zipfile.ZipFile(run/'HARNESS.zip') as archive:
    archived=set(archive.namelist())==set(pins) and all(hashlib.sha256(archive.read(name)).hexdigest()==digest for name,digest in pins.items())
source_match=read(run/'SOURCE.json')==read(run/'SOURCE_AFTER.json')==expected
controls_match=read(run/'CONTROL_PINS.json')==read(run/'CONTROL_PINS_AFTER.json') and receipt.get('control_drift')==[]
headless=OUT.parent/'services_regression31/runs/merged58_services01'
old=read(headless/'RUN.json');old_native=read(headless/'SERVICES56.json')
cases={}
for name,row in native['cases'].items():
    cases[name]={'id':row['id'],'entered':row['entered'],'completed':row['completed'],'outbound':row['outbound'],'travel_m':row['travel_m'],'max_physics_displacement_m':row['max_physics_displacement_m'],'service_frame':row.get('service',{}).get('frame'),'exit_frame':row.get('exit',{}).get('frame'),'native_payment_receipts':len(row.get('money_receipts',[])),'native_healing_receipts':len(row.get('heal_receipts',[]))}
result={'schema':'mafiozi.services58.acceptance/v1','passed':receipt['passed'] and source_match and controls_match and archived,'graphical_run':str(run.relative_to(ROOT)),'source_count':len(expected),'candidate_sha256':sha(manifest),'source_before_and_after_match_candidate':source_match,'controls_unchanged':controls_match,'immutable_harness_verified':archived,'checks_passed':sum(receipt['checks'].values()),'checks_total':len(receipt['checks']),'native_reason':native['reason'],'cases':cases,'failures':receipt.get('failed_checks',[]),'errors':receipt.get('errors',[]),'stderr_bytes':receipt.get('stderr_bytes'),'performance_accepted':False,'full_soak_accepted':False,'production_modified':False,'user_game_preserved':True,'headless_attempt':{'run':str(headless.relative_to(ROOT)),'passed':old['passed'],'reason':old_native['reason'],'failed_checks':old['failed_checks'],'restaurant_travel_m':old_native['cases']['restaurant']['travel_m'],'source_before_and_after_match_candidate':read(headless/'SOURCE.json')==read(headless/'SOURCE_AFTER.json')==expected,'classification':'Native deadline240s preserved as FAIL; hospital/bank/shop completed, restaurant still walking inbound. Later graphical420s is a distinct run.'},'evidence_sha256':{name:sha(run/name) for name in ['RUN.json','SERVICES56.json','SOURCE.json','SOURCE_AFTER.json','CONTROL_PINS.json','CONTROL_PINS_AFTER.json','HARNESS_PINS.json','HARNESS.zip']}}
(OUT/'SERVICES58_RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['evidence_sha256','cases','headless_attempt']}))
