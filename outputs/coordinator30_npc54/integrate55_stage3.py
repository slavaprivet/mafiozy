import importlib.util,json,pathlib,sys,hashlib
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game';DIAG=OUT/'proposals/diag_perf30'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
spec=importlib.util.spec_from_file_location('hp',DIAG/'apply_hp_core30.py');hp=importlib.util.module_from_spec(spec);spec.loader.exec_module(hp)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with Lease('headless',GAME,'write',180):
    for case in ['hp03','guards_off02','guards_on02']:
        result=json.loads((DIAG/'runs'/case/'RESULT.json').read_text(encoding='utf-8'));assert result['passed'],case
    pending,states=hp.proposed_files(GAME)
    for prefix,rel in [('target_current30','scripts/npc_visual/preview_resident_host.gd'),('damage_probe30','scripts/npc_visual/npc_local_preview_hit_owner.gd')]:
        before=(DIAG/'guards30'/f'{prefix}.before.txt').read_text(encoding='utf-8');after=(DIAG/'guards30'/f'{prefix}.after.txt').read_text(encoding='utf-8')
        text=pending.get(rel,(GAME/rel).read_text(encoding='utf-8'));assert text.count(before)==1,rel
        pending[rel]=text.replace(before,after,1)
    fixes=json.loads((OUT/'proposals/threat30/FIX_LOS_PENDING30.json').read_text(encoding='utf-8'))
    rel=fixes['changes'][0]['file'];assert sha(GAME/rel)==fixes['base_sha256']
    text=(GAME/rel).read_text(encoding='utf-8')
    for change in fixes['changes']:
        assert change['file']==rel and text.count(change['before'])==1
        text=text.replace(change['before'],change['after'],1)
    pending[rel]=text
    rel='scripts/main.gd';text=(GAME/rel).read_text(encoding='utf-8');assert text.count('s01-20261015-residents54')==1
    pending[rel]=text.replace('s01-20261015-residents54','s01-20261015-residents55')
    news={'title':'15.10 · Большой город и реакции жителей · версия55','runtime_revision':'s01-20261015-residents55','items':[
      'В городе 287 жителей и 12 сотрудников. Жители гуляют, отдыхают, ходят в магазины, банк, ресторан и больницу.',
      'Жители замечают оружие и реагируют на выстрелы. Испуганный беглец движется на 10% быстрее; без новой угрозы успокаивается через 15 секунд.',
      'После бегства житель может достать телефон. Выезд полиции будет подключён следующим шагом.',
      'При здоровье ниже половины житель идёт лечиться. Медик носит белый халат и шапочку; розовые плюсы показывают восстановление здоровья.',
      'Наведи взгляд на жителя — появится карточка здоровья. Красные цифры показывают реальные траты; у сотрудников действует очередь.',
      'Q — выбрать оружие; E — дверь. Это пробная массовая сборка для наблюдения за городом.'
    ]}
    pending['data/preview_updates.json']=json.dumps(news,ensure_ascii=False,indent=2)+'\n'
    rows=[]
    for rel,text in pending.items():
        p=GAME/rel;before=sha(p);p.write_text(text,encoding='utf-8',newline='\n');rows.append({'file':rel,'before':before,'after':sha(p)})
    (OUT/'INTEGRATION55_STAGE3.json').write_text(json.dumps({'files':rows,'hp_hunks':states,'user_authorized_trial_before_perf':True},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'merged_files':len(rows),'revision':news['runtime_revision'],'performance_accepted':False}))
