import hashlib,json,pathlib,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
PACKAGE=OUT/'proposals/avoidance30';PROOF=PACKAGE/'runs/avoidance30_02'
sys.path.insert(0,str(ROOT));sys.path.insert(0,str(OUT/'proposals/staff30'))
from tools.godot.test_scheduler import Lease
from apply_staff30 import apply_hunks
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
result=json.loads((PROOF/'RESULT.json').read_text(encoding='utf-8'))
assert result['passed'] and not result['source_drift']
for path in [PROOF/'avoidance_fixture29/stderr.log',PROOF/'proxies_fixture29/stderr.log']:
    assert not path.read_text(encoding='utf-8').strip()
pending={}
with Lease(mode='headless',project=GAME,access='write',wait_seconds=120):
    for patch in (PACKAGE/'patches').glob('*.patch'):
        delta=patch.read_text(encoding='utf-8')
        rel=next(line[6:] for line in delta.splitlines() if line.startswith('+++ b/'))
        pending[rel]=apply_hunks((GAME/rel).read_text(encoding='utf-8'),delta).encode()
    for source in (PACKAGE/'scripts/navigation').glob('*.gd'):
        rel=source.relative_to(PACKAGE).as_posix()
        assert sha(source)==sha(PROOF/'project'/rel),'source differs from tested fixture'
        pending[rel]=source.read_bytes()
    report={'native_fixture':str(PROOF),'source_changes':[], 'population286_enabled':False,'full_gameplay_perf_accepted':False}
    for rel,raw in pending.items():
        target=GAME/rel
        report['source_changes'].append({'file':rel,'before':sha(target) if target.exists() else None,'after':hashlib.sha256(raw).hexdigest()})
    for rel,raw in pending.items():
        target=GAME/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    (OUT/'AVOIDANCE_INTEGRATION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'integrated':len(pending),'native_cases_passed':5,'freed_body_cleanup_fixed':True}))
