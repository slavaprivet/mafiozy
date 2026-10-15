"""Preserve the verified54 delta, then merge heal effects and bounded population dispatch."""
import hashlib, importlib.util, json, pathlib, sys, zipfile
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(data):return hashlib.sha256(data).hexdigest()
def pins(root):return {p.relative_to(root).as_posix():sha(p.read_bytes()) for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts}
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
heal=module('heal',OUT/'proposals/heal_fx30/apply_heal_fx30.py')
pop=module('pop',OUT/'proposals/population30/apply30.py')
with Lease('headless',GAME,'write',180):
    before=pins(GAME);base=pins(ROOT/'outputs/coordinator29_release53a/game')
    archive=OUT/'VERIFIED54_SOURCE_DELTA.zip'
    if not archive.exists():
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
            z.writestr('SOURCE.json',json.dumps(before,indent=2))
            for rel,pin in before.items():
                if base.get(rel)!=pin:z.write(GAME/rel,'delta/'+rel)
    heal.apply(GAME,OUT/'HEAL_FX30_APPLY.json')
    manifest=json.loads((pop.OUT/'MANIFEST30.json').read_text(encoding='utf-8'))
    pending=[]
    for rel,row in manifest['files'].items():
        old=(pop.OUT/'baseline'/rel).read_bytes();new=(pop.OUT/rel).read_bytes();current=(GAME/rel).read_bytes()
        assert sha(old)==row['base_sha256'] and sha(new)==row['candidate_sha256']
        pending.append((rel,pop.merge(old,new,current)))
    for rel,data in pending:(GAME/rel).write_bytes(data)
    after=pins(GAME)
    report={'status':'CANDIDATE55_STAGE1_NOT_ACCEPTED','source_before':before,'source_after':after,'changed':[r for r in after if before.get(r)!=after[r]],'verified54_archive_sha256':sha(archive.read_bytes()),'packages':['heal_fx30','population30'],'ordinary_pointer_changed':False}
    (OUT/'INTEGRATION55_STAGE1.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'changed':report['changed'],'pins':len(after),'ordinary_pointer_changed':False}))
