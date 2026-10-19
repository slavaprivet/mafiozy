"""Freeze a new release only from exact, reviewed final acceptance source pins.

The acceptance plan supplies evidence folders and the reviewed result predicates.
Freezing never changes the user's current-version pointer; delivery is separate.
"""
import argparse, hashlib, json, pathlib, shutil, sys

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[1]
GAME = OUT/'game'
RELEASE = ROOT/'outputs/coordinator30_release54'
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def pins(folder):
    return {p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file() and '.godot' not in p.parts}
def field(value, dotted):
    for key in dotted.split('.'): value = value[key]
    return value

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--plan', required=True, type=pathlib.Path)
p.add_argument('--apply', action='store_true')
a = p.parse_args()
plan = read(a.plan)
assert not RELEASE.exists(), 'A release is immutable; use a new directory for a new release'
assert len(plan['evidence']) >= 4, 'Full final functional and performance evidence required'
validated = []
with Lease(mode='headless', project=GAME, access='read', wait_seconds=60):
    current = pins(GAME)
    for item in plan['evidence']:
        folder = (ROOT/item['folder']).resolve(strict=True)
        assert folder.is_relative_to(OUT)
        tested = read(folder/item.get('source', 'SOURCE.json'))
        assert tested == current, 'Current source differs from final evidence: '+str(folder)
        for predicate in item['predicates']:
            value = read(folder/predicate['file'])
            assert field(value,predicate['field']) == predicate['equals'], str(predicate)
        for filename in item['stderr']:
            assert not (folder/filename).read_text(encoding='utf-8-sig').strip(), 'Nonempty stderr: '+filename
        assert any(folder.rglob('SCHEDULER_RUN.json')) or any(folder.rglob('RUN.json')), 'No process receipt'
        validated.append({'name':item['name'], 'folder':str(folder), 'source_sha256':sha(folder/item.get('source','SOURCE.json'))})
    bootstrap = read(OUT/plan['bootstrap_result'])
    assert bootstrap['ok'] and bootstrap['resident_count']==1 and bootstrap['staff_count']==12 and bootstrap['ambient_actions']==18
    assert bootstrap['revision']=='s01-20261015-residents54'
if a.apply:
    with Lease(mode='headless', project=RELEASE/'game', access='write', wait_seconds=60):
        # Sequential leases avoid taking both headless lanes during freeze.
        # Any intervening source change is rejected before/after the copy.
        assert pins(GAME)==current, 'Source changed after acceptance validation'
        RELEASE.mkdir()
        shutil.copytree(GAME,RELEASE/'game')
        assert pins(RELEASE/'game')==current
        shutil.copy2(OUT/'qa/bootstrap_play54.gd', RELEASE/'bootstrap_play54.gd')
        (RELEASE/'.gitignore').write_text('game/.godot/\n',encoding='utf-8')
        (RELEASE/'.gitattributes').write_text('** -text\n',encoding='utf-8')
        flags=read(ROOT/'outputs/coordinator29_release53a/ASSEMBLY.json')['launch_arguments']
        flags=[f for f in flags if not f.startswith('--city-venue-staff29=')]+['--city-venue-staff29=1']
        manifest={'schema':'mafiozi.residents54-play/v1','revision':bootstrap['revision'],'game':str(RELEASE/'game'),
            'game_relative':(RELEASE/'game').relative_to(ROOT).as_posix(),'source_count':len(current),'source_pins':current,
            'launch_arguments':flags,'ready_timeout_seconds':100,'status':'verified_single_resident_play_preview',
            'full_migration_accepted':False,'population286_performance_accepted':False}
        save(RELEASE/'ASSEMBLY.json',manifest)
        proof_pins={}
        for item in plan['evidence']:
            source=(ROOT/item['folder']).resolve()
            destination=RELEASE/'proofs'/item['name']
            destination.mkdir(parents=True)
            for original in source.rglob('*'):
                if not original.is_file() or original.suffix.lower() not in ('.json','.log','.md','.gd','.py'):continue
                relative=original.relative_to(source)
                if any(part in ('game','project','.godot','__pycache__') for part in relative.parts):continue
                target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,target)
                proof_pins[target.relative_to(RELEASE).as_posix()]=sha(target)
        save(RELEASE/'PROOF_PINS.json',proof_pins)
        save(RELEASE/'ACCEPTANCE.json',{'status':'final_exact_source_functional_and_bounded_performance_verified',
            'ready':bootstrap,'evidence':validated,'review':plan['review'],'limitations':plan['limitations'],
            'source_verified_again_at_freeze':True,'full_migration_accepted':False,'population286_performance_accepted':False})
        save(RELEASE/'PREVIOUS_CURRENT_VERSION.json',read(ROOT/'godot/current_version.json'))
        save(RELEASE/'FREEZE_PLAN.json',plan)
        assert pins(GAME)==current, 'Source changed while freezing'
print(json.dumps({'validated':len(validated),'source_count':len(current),'applied':a.apply}))
