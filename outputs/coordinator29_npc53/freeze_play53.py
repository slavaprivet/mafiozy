import pathlib,sys,json,shutil,hashlib
OUT=pathlib.Path(__file__).resolve().parent; ROOT=OUT.parents[1]; GAME=OUT/'game'; RELEASE=ROOT/'outputs/coordinator29_release53a'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not RELEASE.exists(), 'Freeze must be new'
result=json.loads((OUT/'play53_01/CURRENT_READY.json').read_text(encoding='utf-8'))
run=json.loads((OUT/'play53_01/RUN_CHECK.json').read_text(encoding='utf-8'))
assert result['ok'] and run['exit']==0 and not run['source_drift']
with Lease(mode='headless',project=GAME,access='read',wait_seconds=30):
    with Lease(mode='headless',project=RELEASE/'game',access='write',wait_seconds=30):
        RELEASE.mkdir()
        shutil.copytree(GAME,RELEASE/'game')
        shutil.copy2(OUT/'qa/bootstrap_play53.gd',RELEASE/'bootstrap_play53.gd')
        (RELEASE/'.gitignore').write_text('game/.godot/\n',encoding='utf-8')
        (RELEASE/'.gitattributes').write_text('** -text\n',encoding='utf-8')
        sources={p.relative_to(RELEASE/'game').as_posix():sha(p) for p in (RELEASE/'game').rglob('*') if p.is_file() and '.godot' not in p.parts}
        flags=[x for x in run['flags'] if x.startswith('--city-') and x not in ['--city-play-check=1','--city-resident-detail=1']]
        manifest={'schema':'mafiozi.residents53-play/v1','revision':result['revision'],'game':str(RELEASE/'game'),'game_relative':(RELEASE/'game').relative_to(ROOT).as_posix(),'source_count':len(sources),'source_pins':sources,'launch_arguments':flags,'ready_timeout_seconds':100,'status':'functional_play_preview','full_migration_accepted':False,'population286_performance_accepted':False}
        (RELEASE/'ASSEMBLY.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        proofs=RELEASE/'proofs';proofs.mkdir()
        selected=[('play53_01','CURRENT_READY.json'),('play53_01','RUN_CHECK.json'),('play53_01','SOURCE.json'),('attention_alarm53_01','ATTENTION29.json'),('attention_alarm53_01','RUN_CHECK.json'),('attention_alarm53_01','SOURCE.json'),('money53_02','MONEY29.json'),('money53_02','RUN_CHECK.json'),('cycle53_02','BEHAVIOR_ACCEPTANCE29.json'),('death53_02','DEATH28.json')]
        for folder,name in selected:
            target=proofs/folder/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OUT/folder/name,target)
        (RELEASE/'ACCEPTANCE.json').write_text(json.dumps({'status':'user_requested_playable_snapshot','ready':result,'functional_checks':'proofs; earlier cycle/death receipts name their exact source revisions','open_work':['ambient collar/pocket clipping repair and phone18','cashier/medic staff with one-client FIFO service','resident local avoidance and 286-agent scalability','comparable exclusive performance with final combined features'],'previous_accepted':'48 retained unchanged; this is an active development snapshot'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        old=json.loads((ROOT/'godot/current_version.json').read_text(encoding='utf-8-sig'))
        (RELEASE/'PREVIOUS_CURRENT_VERSION.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        pointer={**old,'title':result['title'],'revision':result['revision'],'assembly':(RELEASE/'ASSEMBLY.json').relative_to(ROOT).as_posix(),'assembly_sha256':sha(RELEASE/'ASSEMBLY.json'),'bootstrap':(RELEASE/'bootstrap_play53.gd').relative_to(ROOT).as_posix(),'bootstrap_sha256':sha(RELEASE/'bootstrap_play53.gd'),'scope':'User-requested current playable city snapshot: resident_1, health/focus/instant route resume, red expenses, physical services/capacity, 8 additional owned sites. Staff/avoidance/phone repair continue separately. Not full migration or 286-resident performance acceptance.'}
        (ROOT/'godot/current_version.json').write_text(json.dumps(pointer,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'release':str(RELEASE),'files':len(sources),'pointer_revision':result['revision']},ensure_ascii=False))
