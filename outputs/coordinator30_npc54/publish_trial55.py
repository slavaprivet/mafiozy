"""User explicitly requested immediate mass trial; do not label it performance accepted."""
import hashlib,json,pathlib,shutil,sys,datetime
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game';RELEASE=ROOT/'outputs/coordinator30_release55'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(root):return {p.relative_to(root).as_posix():sha(p) for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts}
native=json.loads((OUT/'import_trial55/SCHEDULER_RUN.json').read_text(encoding='utf-8'));assert native['passed'] and native['stderr_bytes']==0
assert not RELEASE.exists(),'Use a new immutable release folder'
with Lease('headless',GAME,'read',180):
    before=pins(GAME);RELEASE.mkdir()
    with Lease('headless',RELEASE/'game','write',180):
        shutil.copytree(GAME,RELEASE/'game');shutil.copy2(OUT/'qa/bootstrap_play55.gd',RELEASE/'bootstrap_play55.gd')
        assert pins(RELEASE/'game')==before and pins(GAME)==before
        old=json.loads((ROOT/'outputs/coordinator29_release53a/ASSEMBLY.json').read_text(encoding='utf-8'))
        flags=[f for f in old['launch_arguments'] if not f.startswith(('--city-qa=','--city-resident-name='))]
        flags+=['--city-qa=287','--city-venue-staff29=1','--city-physical-dispatch30=1','--city-multi-lifecycle30=1','--city-threat30=1']
        manifest={'schema':'mafiozi.residents55-user-trial/v1','revision':'s01-20261015-residents55','game':str(RELEASE/'game'),'game_relative':'outputs/coordinator30_release55/game','source_count':len(before),'source_pins':before,'launch_arguments':flags,'ready_timeout_seconds':120,'requested_population':287,'staff':12,'performance_accepted':False,'mass_trial_explicitly_requested':True,'police_models_only':True}
        (RELEASE/'ASSEMBLY.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        acceptance={'status':'USER_REQUESTED_MASS_TRIAL_PENDING_RUNTIME_READY','created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'user_request':'Launch the scene with200+ residents now; investigate bugs and load afterwards. Save this build to main and GitHub after launch.','source_import_passed':True,'performance_accepted':False,'pending':['287 actual startup receipt','long mass performance/memory','service exit during threat'],'component_evidence':['proposals/threat30/runs/city02','proposals/lifecycle30/runs/multi05','proposals/diag_perf30/runs/hp03','proposals/diag_perf30/runs/guards_off02','proposals/diag_perf30/runs/guards_on02','proposals/heal_fx30/runs/visual03','proposals/police_response30/runs/models02']}
        (RELEASE/'TRIAL_STATUS.json').write_text(json.dumps(acceptance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
pointer=ROOT/'godot/current_version.json';oldpointer=json.loads(pointer.read_text(encoding='utf-8'));(RELEASE/'PREVIOUS_CURRENT.json').write_bytes(pointer.read_bytes())
current={'schema':'mafiozi.current-play/v1','title':'15.10 · Большой город и реакции жителей · версия55','revision':manifest['revision'],'assembly':'outputs/coordinator30_release55/ASSEMBLY.json','assembly_sha256':sha(RELEASE/'ASSEMBLY.json'),'bootstrap':'outputs/coordinator30_release55/bootstrap_play55.gd','bootstrap_sha256':sha(RELEASE/'bootstrap_play55.gd'),'engine_sha256':oldpointer['engine_sha256'],'scope':'Explicit user-requested200+resident trial.287requested residents+12staff; gun/shot/flee+10%/quiet15/phone, native services and independent respawn. Police models prepared; response AI deferred by user. Performance not accepted.'}
pointer.write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'release':str(RELEASE),'source_count':len(before),'assembly_sha256':current['assembly_sha256'],'performance_accepted':False}))
