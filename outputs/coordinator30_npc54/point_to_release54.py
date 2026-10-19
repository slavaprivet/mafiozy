"""Publish the verified frozen54 to the existing F5/current-version launcher."""
import hashlib,json,pathlib

ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/coordinator30_npc54'
RELEASE=ROOT/'outputs/coordinator30_release54'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(p):return {x.relative_to(p).as_posix():sha(x) for x in p.rglob('*') if x.is_file() and '.godot' not in x.parts}
manifest=read(RELEASE/'ASSEMBLY.json')
proof=OUT/'frozen_play54_01'
run=read(proof/'RUN_CHECK.json');ready=read(proof/'CURRENT_READY.json')
assert run['exit']==0 and not run['source_drift'] and ready['ok']
assert ready['revision']==manifest['revision'] and ready['resident_count']==1 and ready['staff_count']==12 and ready['ambient_actions']==18
assert not (proof/'engine/stderr.log').read_text(encoding='utf-8-sig').strip()
assert read(proof/'SOURCE.json')==manifest['source_pins']==pins(RELEASE/'game')
assert sha(OUT/'qa/bootstrap_play54.gd')==sha(RELEASE/'bootstrap_play54.gd')
pointer=ROOT/'godot/current_version.json'
previous=read(RELEASE/'PREVIOUS_CURRENT_VERSION.json')
assert read(pointer)==previous, 'Another owner changed the current version; review before publishing'
updated={**previous,'title':ready['title'],'revision':manifest['revision'],
         'assembly':(RELEASE/'ASSEMBLY.json').relative_to(ROOT).as_posix(),'assembly_sha256':sha(RELEASE/'ASSEMBLY.json'),
         'bootstrap':(RELEASE/'bootstrap_play54.gd').relative_to(ROOT).as_posix(),'bootstrap_sha256':sha(RELEASE/'bootstrap_play54.gd'),
         'scope':'Verified common city54: one resident, 12 staff, white medical coat/cap/detailed kit, 18 activities, medical damage priority, bounded service routing and local avoidance. Bounded one-resident performance pair; not full migration or 286-resident acceptance.'}
pointer.write_text(json.dumps(updated,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'revision':manifest['revision'],'pointer_sha256':sha(pointer)}))
