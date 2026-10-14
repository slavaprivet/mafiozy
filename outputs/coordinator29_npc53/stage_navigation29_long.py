import pathlib,sys,json,hashlib,shutil
OUT=pathlib.Path(__file__).resolve().parent; ROOT=OUT.parents[1]; GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
long=OUT/'proposals/navigation29_long'; merged=OUT/'proposals/navigation29_integration'
handoff=json.loads((merged/'HANDOFF.json').read_text(encoding='utf-8'))
with Lease(mode='headless',project=GAME,access='write',wait_seconds=30):
    for item in handoff['current_base_files']:
        assert sha(ROOT/item['path'])==item['sha256'],item['path']
    for item in json.loads((long/'MANIFEST.json').read_text(encoding='utf-8'))['files']:
        rel=item['path']
        if not rel.startswith('scripts/') or rel.endswith('npc_roam_wait29.gd'):continue
        assert sha(long/rel)==item['sha256'],rel
        target=GAME/rel
        baseline=long/'baseline'/target.name
        if target.exists(): assert sha(target)==sha(baseline),rel
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(long/rel,target)
    for item in handoff['production_files']:
        rel=item['path'];assert sha(merged/rel)==item['sha256'],rel
        shutil.copy2(merged/rel,GAME/rel)
print('Native-verified common navigation queue, roam time accounting and instant attention resume staged.')
