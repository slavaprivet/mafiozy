"""Freeze reviewed lifecycle30 scoped sources and final native proof; no game writes."""
import hashlib,json,pathlib
OUT=pathlib.Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
files=read(OUT/'BASE30.json')
for rel,entry in files.items():
    assert sha(OUT/rel)==entry['candidate_sha256'] and sha(OUT/'baseline'/rel)==entry['base_sha256'],rel
rel='scripts/hospital/npc_population_lifecycle30.gd'
files[rel]={'base_sha256':None,'candidate_sha256':sha(OUT/rel)}
proof={}
for case,name,semantic in [('multi','multi05','MULTILIFE30.json'),('single','single02','DEATH28.json')]:
    folder=OUT/'runs'/name;result=read(folder/'RESULT.json');data=read(folder/semantic)
    assert result['passed'] and data['passed'] and not result['source_drift']
    assert (folder/'engine/stderr.log').stat().st_size==0
    pins=read(folder/'SOURCE.json')
    assert pins==read(folder/'SOURCE_AFTER.json')
    for rel,entry in files.items():assert pins[rel]==entry['candidate_sha256'],rel
    proof[case]={'run':str(folder.relative_to(OUT)),'passed':True,'checks':len(data.get('checks',{})),'semantic_sha256':sha(folder/semantic),'result_sha256':sha(folder/'RESULT.json'),'source_pin_sha256':sha(folder/'SOURCE.json'),'stderr_bytes':0,'source_drift':[]}
assert read(OUT/'runs/multi05/SOURCE.json')==read(OUT/'runs/single02/SOURCE.json')
manifest={'package':'lifecycle30','status':'NATIVE_VERIFIED_SCOPED_PACKAGE','owner':'release_qa30','apply_order':['population30','lifecycle30'],'files':files,'native':proof,'performance_accepted':False,'mass_64_287_accepted':False,'npc_fixture_relocations':0,'synthetic_damage':False,'shared_game_modified_by_this_package':False,'flags':['--city-simple-hospital=1','--city-physical-dispatch30=1','--city-multi-lifecycle30=1'],'proof_flags':'runs/multi05/FLAGS.json','peer_fixes':'PEER_FIXES30.json','apply':'apply30.py defaults to dry-run; caller holds target scheduler write lease; complete preflight precedes writes','limitations':['Headless native input/physics acceptance; graphical death acceptance is separate','Full mass cohort admission and comparable performance remain coordinator tests','Player fixture moves into valid shooting position; NPC positions are never changed by fixture']}
(OUT/'MANIFEST30.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'manifest_sha256':sha(OUT/'MANIFEST30.json'),'files':len(files),'native':proof}))
