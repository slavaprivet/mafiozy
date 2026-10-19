import hashlib,json,pathlib,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3];GAME=OUT.parent/'injury30/game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
SOURCE=ROOT/'outputs/coordinator30_npc54/game'
names=['FIX_META30.json','FIX_DISPOSE30.json','FIX_FAIR_PERCEPTION30.json']
patches=[(name,json.loads((OUT.parent/'threat30'/name).read_text(encoding='utf-8'))) for name in names]
with Lease('headless',SOURCE,'read',30):
    shared={fix['file']:(SOURCE/fix['file']).read_bytes() for _,fix in patches}
    for name,fix in patches:
        assert fix['after'] in shared[fix['file']].decode('utf-8').replace('\r\n','\n'),name
result=[]
with Lease('headless',GAME,'write',30):
    for name,fix in patches:
        source=OUT.parent/'threat30'/name;path=GAME/fix['file'];raw=path.read_bytes()
        path.write_bytes(shared[fix['file']])
        result.append({'owner':'injury_fix30','patch':name,'patch_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'file':fix['file'],'before_sha256':hashlib.sha256(raw).hexdigest(),'after_sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'PEER_FIXES30.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
