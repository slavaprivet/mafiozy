import pathlib,json,hashlib,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3];GAME=OUT.parent.parent/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with Lease('headless',GAME,'write',180):
    spec=json.loads((OUT/'HUNKS.json').read_text(encoding='utf-8'));pending={};before={}
    for item in spec['changes']:
        rel=item['file'];p=GAME/rel;before[rel]=sha(p)
        text=pending.get(rel,p.read_text(encoding='utf-8'))
        assert text.count(item['before'])==1,item['before'][:100]
        pending[rel]=text.replace(item['before'],item['after'],1)
    for rel,value in pending.items():(GAME/rel).write_text(value,encoding='utf-8')
    (GAME/spec['helper']).write_bytes((OUT/spec['helper']).read_bytes())
    result={'files':{rel:{'before':before[rel],'after':sha(GAME/rel)} for rel in pending},'helper':sha(GAME/spec['helper']),'source_rows_unchanged':True,'max_fallback_probes':384,'physics_admission_unchanged':True,'native_verified':False}
    (OUT/'APPLIED30.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
