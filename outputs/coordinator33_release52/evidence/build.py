import pathlib,json,hashlib,subprocess,shutil
R=pathlib.Path.cwd(); O=pathlib.Path('D:/MafioziCombat31/coordinator33'); G=O/'game'; G.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
a=read(R/'outputs/coordinator31_castle_current/ASSEMBLY.json'); base=R/a['game_relative']
commit='9c726d5c05e97ef9de676977694ae84645c80ddc'
published=json.loads(subprocess.check_output(['git','show',commit+':outputs/coordinator31_castle_current/ASSEMBLY.json']))
assert a==published
for rel,h in a['source_pins'].items():
 p=base/rel; assert sha(p)==h,(rel,'base mismatch'); q=G/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
(O/'working_status_before.txt').write_bytes(subprocess.check_output(['git','status','--porcelain=v1']))
(O/'tracked_changes_before.patch').write_bytes(subprocess.check_output(['git','diff','--binary']))
(O/'staged_changes_before.patch').write_bytes(subprocess.check_output(['git','diff','--cached','--binary']))
changes=[]
bow=pathlib.Path('D:/MafioziCombat31/resume52_bow')
for x in read(bow/'SOURCE52.json'):
 rel=x['path'];assert sha(G/rel)==x['base_sha256'];p=bow/'candidate_game'/rel;assert sha(p)==x['candidate_sha256'];shutil.copy2(p,G/rel);changes.append(rel)
spear=pathlib.Path('D:/MafioziCombat31/resume52_spear');rel='scripts/weapons/sword_prototype.gd'
assert sha(G/rel)==sha(spear/'sword.base51.gd'), 'spear base mismatch'
shutil.copy2(spear/'game'/rel,G/rel);changes.append(rel)
S=pathlib.Path('C:/Users/Слава/Documents/Codex/2026-10-08/task-7'); rec=S/'SOIL49_RECOVERY_20261018T154550Z'; review=read(S/'SOIL49_SOURCE_REVIEW_20261018T1606/REPORT.json')
assert sha(rec/'MANIFEST.json')==review['recovery_manifest_sha256']
for x in review['integrity']:assert sha(rec/x['path'])==x['sha256'],x['path']
for x in review['source_comparison']:
 rel=x['path'];p=rec/'files'/rel;assert sha(p)==x['candidate_sha256']
 if x['base_sha256']:assert sha(G/rel)==x['base_sha256']
 else:assert not (G/rel).exists()
 (G/rel).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,G/rel);changes.append(rel)
pins={rel:sha(G/rel) for rel in set(a['source_pins'])|set(changes)}
(O/'CANDIDATE.json').write_text(json.dumps(dict(status='NOT_ACCEPTED',base_commit=commit,game=str(G),source_pins=pins,changed=changes),indent=2))
print(json.dumps(dict(base_verified=len(a['source_pins']),pins=len(pins),changed=changes,sword_sha=sha(G/'scripts/weapons/sword_prototype.gd'))))
