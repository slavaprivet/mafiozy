import pathlib,json,hashlib,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with Lease('headless',GAME,'write',180):
    pending={};report=[]
    for name in ['FIX_DISPOSE30.json','FIX_META30.json','FIX_FAIR_PERCEPTION30.json']:
        spec=json.loads((OUT/'proposals/threat30'/name).read_text(encoding='utf-8'));p=GAME/spec['file']
        text=pending.get(spec['file'],p.read_text(encoding='utf-8'))
        if spec.get('base_sha256'):assert sha(p)==spec['base_sha256']
        assert text.count(spec['before'])==1,name
        pending[spec['file']]=text.replace(spec['before'],spec['after'],1)
        report.append({'patch':name,'file':spec['file'],'before':sha(p)})
    for rel,value in pending.items():(GAME/rel).write_text(value,encoding='utf-8')
    for row in report:row['after']=sha(GAME/row['file'])
    (OUT/'INTEGRATION55_HOTFIX1.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
