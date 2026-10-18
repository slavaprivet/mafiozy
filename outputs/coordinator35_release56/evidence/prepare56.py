from pathlib import Path
import json,hashlib,subprocess,shutil,difflib
R=Path('C:/Users/Слава/Desktop/Мафиози');W=Path('D:/MafioziCombat31/publish_mixed31');O=Path(__file__).parent;G=O/'game'
rel='outputs/coordinator35_release56';revision='castle-20261019-combined56-free-sledge';base='6f6f8199b38c60a42b7527964930860e42585cf9'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def git(*args):return subprocess.check_output(['git',*args],cwd=W)
assert git('rev-parse','HEAD').decode().strip()==base
assert not git('status','--porcelain','--untracked-files=no').strip()
assert git('ls-remote','origin','refs/heads/main').decode().split()[0]==base
assert (R/'godot/current_version.json').read_bytes()==(O/'POINTER.before.json').read_bytes()
before=read(O/'WORKING.before.json');assert all(sha(R/p)==h for p,h in before.items())
a=read(O/'BASE55.json');oldpins=dict(a['source_pins']);pins={p:sha(G/p) for p in oldpins}
changed=[p for p in pins if pins[p]!=oldpins[p]];assert changed==['scripts/weapons/sword_prototype.gd']
review=read(O/'REVIEW56.json');assert review['status']=='PASS' and review['sha256']==pins[changed[0]]
checks=[]
for group in ['sledge_hold01','sledge_contact01','sword_left01','sword_right01']:
    s=read(O/group/'SUMMARY.json');assert s['passed'] and not s['drift'],s
    assert read(O/group/'SOURCE.json')==pins,group
    checks.append(s)
assert read(O/'VISUAL56.json')['status']=='PASS'
limits=['Clean FPS not measured. Visual review samples discrete poses; subjective feel remains for user feedback.', 'Two-handed grip, blunt damage and shared real contact/body protection remain.']
included=['Sledge uses the sword steering solver in every direction with7.6rad/s speed and28rad/s2 acceleration; heavier260ms coast and2.7 mass retained.', 'Removed forced shoulder offset and opposing chest rotation; shared two-hand reach follows input.', 'Sledge haft/head/bands extended forward20cm; reach0.92 to1.12m; rear haft and grips unchanged.', 'All55 masonry fixes retained; existing sword LMB/RMB behavior preserved.']
acceptance={'revision':revision,'status':'ACCEPTED_FUNCTIONAL','base_commit':base,'source_pins':pins,'changed':changed,'checks':checks,'source_review':review,'included':included,'limits':limits}
e=O/'evidence';e.mkdir(exist_ok=False)
for p in list(O.iterdir()):
    if p.name in ['game','evidence','__pycache__']:continue
    if p.is_dir():shutil.copytree(p,e/p.name)
    else:shutil.copy2(p,e/p.name)
old=(R/'outputs/coordinator35_release55/game'/changed[0]).read_text(encoding='utf-8').splitlines(True)
new=(G/changed[0]).read_text(encoding='utf-8').splitlines(True)
(e/'sledge56.patch').write_text(''.join(difflib.unified_diff(old,new,fromfile='55/sword_prototype.gd',tofile='56/sword_prototype.gd')),encoding='utf-8')
a.update(revision=revision,game_relative=rel+'/game',source_pins=pins,base_published_commit=base,validation='Sledge real hold/diagonals/grip/clearance/drop-pickup and real target contact; sword LMB/RMB regressions PASS. One production file changed.')
a['included_packages']+=included
a['evidence']['combined56']=rel+'/ACCEPTANCE.json';a['evidence']['current_scene']=rel+'/evidence/sledge_hold01/hold_2.png'
a['sledge56']={'acceptance':rel+'/ACCEPTANCE.json','source_on_D':str(G),'resume':'docs/ai/COORDINATOR_35_CONTINUE56.json'}
wd=W/rel;wd.mkdir(exist_ok=False)
for p,h in pins.items():
    dst=wd/'game'/p;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(G/p,dst);assert sha(dst)==h
shutil.copytree(e,wd/'evidence');save(wd/'ASSEMBLY.json',a);save(wd/'ACCEPTANCE.json',acceptance)
pointer=read(O/'POINTER.before.json');pointer.update(title='Замок и осада · общая сцена 56 · свободная кувалда',revision=revision,assembly_sha256=sha(wd/'ASSEMBLY.json'),scope='All55 retained; freer, heavier sledge with20cm longer haft. Approved sword behavior unchanged.')
rd=R/rel;rd.mkdir(exist_ok=False)
for name,target in [('game',G),('evidence',e)]:
    cmd="New-Item -ItemType Junction -Path '"+str(rd/name).replace("'","''")+"' -Target '"+str(target).replace("'","''")+"' | Out-Null"
    subprocess.run(['pwsh','-NoProfile','-Command',cmd],check=True)
save(rd/'ASSEMBLY.json',a);save(rd/'ACCEPTANCE.json',acceptance)
handoff={'revision':revision,'base_commit':base,'frozen_source':str(G),'acceptance':rel+'/ACCEPTANCE.json','changed':changed,'included':included,'limits':limits,'optimization_handoff':'Base further optimization on56. Preserve55 bounds-aware masonry destruction/collision refinement and56 sledge steering. User-approved sword LMB/RMB unchanged. Current manifest is authoritative; do not overwrite newer combined scene with54 baseline.','instructions':'New candidates/tests on D via scheduler. Preserve foreign WIP and frozen releases. Old chats remain idle.'}
header='''## Координатор35 — общая56, свободная кувалда, 19 октября 2026

Вся разрушаемая кладка55 сохранена. По поручению пользователя кувалда
использует общий алгоритм свободного движения меча с весом:7.6rad/s,
28rad/s², масса2.7 и выбег260мс. Убраны отдельное торможение верхнего
замаха, принудительный увод рук к плечу и противоворот груди.
Древко/голова/кольца вынесены вперёд на20см; reach0.92→1.12м,
задняя рукоять и точки хвата сохранены. Кувалда остаётся двуручной и тупой.
Реальные боковые/верхние/диагональные движения, хват, защита от своего
тела, G/E, контакт с целью и regression меча ЛКМ/ПКМ PASS; GUI проверен.
1игровой файл sword_prototype.gd. Алгоритм утверждённого меча не менять.
Source D:/MafioziCombat31/coordinator35_sledge56/game frozen; release56/game
локально junction, в Git обычные файлы. Приёмка outputs/coordinator35_release56/ACCEPTANCE.json.
Передача docs/ai/COORDINATOR_35_CONTINUE56.json. Оптимизацию базировать на56.
Чистый FPS не принят; чужой WIP сохранить, новые проверки наD через scheduler.

'''.encode('utf-8')
for root in [R,W]:
    save(root/'godot/current_version.json',pointer);save(root/'outputs/coordinator31_castle_current/ASSEMBLY.json',a);save(root/'docs/ai/COORDINATOR_35_CONTINUE56.json',handoff)
    ag=root/'AGENTS.md';ag.write_bytes(header+ag.read_bytes())
    attrs=root/'.gitattributes';raw=attrs.read_bytes();attrs.write_bytes(raw+(b'' if raw.endswith(b'\n') else b'\n')+('/'+rel+'/game/** -text\n/'+rel+'/evidence/** -text\n/'+rel+'/ASSEMBLY.json -text\n').encode())
assert all(sha(R/p)==h for p,h in before.items() if p not in ['AGENTS.md','.gitattributes','godot/current_version.json','outputs/coordinator31_castle_current/ASSEMBLY.json'])
save(O/'RELEASE_PREPARED.json',{'revision':revision,'pins':len(pins),'changed':changed,'checks':len(checks)})
print(json.dumps(read(O/'RELEASE_PREPARED.json')))
