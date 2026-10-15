import pathlib,json,hashlib,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
PACKAGE=OUT/'proposals/injury30'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((PACKAGE/'PATCH.json').read_text(encoding='utf-8'))
with Lease(mode='headless',project=GAME,access='write',wait_seconds=120):
    for rel,row in manifest['changes'].items():
        assert sha(GAME/rel)==row['before'],rel
        assert sha(PACKAGE/'patch'/rel)==row['after'],rel
    for rel in manifest['changes']:
        (GAME/rel).write_bytes((PACKAGE/'patch'/rel).read_bytes())
    (OUT/'INJURY_INTEGRATION.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Medical attention priority applied to candidate54; native regression pending.')
