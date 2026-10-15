import hashlib, json, pathlib, shutil, sys
from datetime import datetime, timezone

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT / 'outputs/coordinator29_release53a/game'
GAME = OUT / 'game'
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

def pins(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob('*') if p.is_file() and '.godot' not in p.parts}

manifest = json.loads((SOURCE.parent / 'ASSEMBLY.json').read_text(encoding='utf-8'))
before = pins(SOURCE)
assert before == manifest['source_pins'], 'Frozen53a drift'
assert not GAME.exists(), 'New destination required'
with Lease(mode='headless', project=GAME, access='write', wait_seconds=120):
    shutil.copytree(SOURCE, GAME, ignore=shutil.ignore_patterns('.godot'))
    assert pins(SOURCE) == before == pins(GAME)
    (OUT/'BASELINE.json').write_text(json.dumps({
        'source': str(SOURCE), 'source_manifest': 'outputs/coordinator29_release53a/ASSEMBLY.json',
        'source_pins': before, 'source_drift': [],
        'copied_at': datetime.now(timezone.utc).isoformat(),
        'purpose': 'Coordinator30 isolated integration; current user game preserved'
    }, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'staged':str(GAME),'source_count':len(before),'source_drift':[]}))
