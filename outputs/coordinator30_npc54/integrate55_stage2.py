import hashlib,importlib.util,json,pathlib,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(data):return hashlib.sha256(data).hexdigest()
folder=OUT/'proposals/lifecycle30'
spec=importlib.util.spec_from_file_location('life',folder/'apply30.py');life=importlib.util.module_from_spec(spec);spec.loader.exec_module(life)
with Lease('headless',GAME,'write',180):
    manifest=json.loads((folder/'MANIFEST30.json').read_text(encoding='utf-8'));pending={};rows=[]
    for rel,entry in manifest['files'].items():
        candidate=(folder/rel).read_bytes();target=GAME/rel;current=target.read_bytes() if target.exists() else None
        assert sha(candidate)==entry['candidate_sha256'],rel
        if entry['base_sha256'] is None:
            assert current is None;updated=candidate
        else:
            baseline=(folder/'baseline'/rel).read_bytes();assert sha(baseline)==entry['base_sha256'] and current is not None
            updated=life.merge(baseline,candidate,current)
        pending[rel]=updated;rows.append({'file':rel,'before':sha(current) if current else None,'after':sha(updated)})
    raw=json.loads((OUT/'proposals/threat30/FIX_RAW_SHOTS30.json').read_text(encoding='utf-8'))
    rel=raw['changes'][0]['file'];target=GAME/rel;current=target.read_bytes();assert sha(current)==raw['base_sha256'];text=target.read_text(encoding='utf-8')
    for change in raw['changes']:
        assert change['file']==rel and text.count(change['before'])==1
        text=text.replace(change['before'],change['after'],1)
    updated=text.replace('\n','\r\n').encode('utf-8') if b'\r\n' in current else text.encode('utf-8')
    assert sha(updated)==raw['after_sha256'];pending[rel]=updated;rows.append({'file':rel,'before':sha(current),'after':sha(updated)})
    for rel,data in pending.items():
        target=GAME/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    (OUT/'INTEGRATION55_STAGE2.json').write_text(json.dumps({'files':rows,'packages':['lifecycle30','threat30/raw_shots'],'ordinary_pointer_changed':False},indent=2)+'\n',encoding='utf-8')
print(json.dumps(rows))
