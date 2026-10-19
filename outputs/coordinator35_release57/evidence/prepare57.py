from pathlib import Path
import json,hashlib,subprocess,shutil,difflib
R=Path('C:/Users/Слава/Desktop/Мафиози');W=Path('D:/MafioziCombat31/publish_mixed31');O=Path(__file__).parent;G=O/'game'
rel='outputs/coordinator35_release57';revision='castle-20261019-combined57-tougher-opponents';base='3c250cab41613732fd8e4ee7c043266a8efd28e7'
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
a=read(O/'BASE56.json');oldpins=dict(a['source_pins']);pins={p:sha(G/p) for p in oldpins}
changed=[p for p in pins if pins[p]!=oldpins[p]];assert changed==['scripts/weapons/sword_prototype.gd']
review=read(O/'REVIEW57.json');assert review['status']=='PASS' and review['sha256']==pins[changed[0]]
checks=[]
for group in ['duelist01','health04']:
    s=read(O/group/'SUMMARY.json');assert s['passed'] and not s['drift'],s
    assert read(O/group/'SOURCE.json')==pins,group
    checks.append(s)
assert read(O/'health04/RESULT.json')['passed'] and read(O/'duelist01/RESULT.json')['passed']
limits=['Clean FPS not measured. Castle duelist was struck by real input in a repeatable test; resident head/chest thresholds were exercised through the native wound owner.', 'User may still tune the desired fight duration by feel after playing.']
included=['Castle duelist health increased fourfold from120 to480; four actual sledge swings left341HP.', 'Resident total health increased from90 to270; separate NPC head/chest/limb thresholds increased while player thresholds stay unchanged.', 'Removed the forced one-hit heavy-head damage floor and spear instant fatality; ordinary wound health decides death.', 'All56 weapon controls and55 destructible masonry retained.']
acceptance={'revision':revision,'status':'ACCEPTED_FUNCTIONAL','base_commit':base,'source_pins':pins,'changed':changed,'checks':checks,'source_review':review,'included':included,'limits':limits}
e=O/'evidence';e.mkdir(exist_ok=False)
for p in list(O.iterdir()):
    if p.name in ['game','evidence','__pycache__']:continue
    if p.is_dir():shutil.copytree(p,e/p.name)
    else:shutil.copy2(p,e/p.name)
old=(R/'outputs/coordinator35_release56/game'/changed[0]).read_text(encoding='utf-8').splitlines(True)
new=(G/changed[0]).read_text(encoding='utf-8').splitlines(True)
(e/'health57.patch').write_text(''.join(difflib.unified_diff(old,new,fromfile='56/sword_prototype.gd',tofile='57/sword_prototype.gd')),encoding='utf-8')
a.update(revision=revision,game_relative=rel+'/game',source_pins=pins,base_published_commit=base,validation='Four real sledge swings against castle duelist; resident head/chest maximum single wounds survived and repeat wounds killed. One production file changed.')
a['included_packages']+=included
a['evidence']['combined57']=rel+'/ACCEPTANCE.json'
a['health57']={'acceptance':rel+'/ACCEPTANCE.json','source_on_D':str(G),'resume':'docs/ai/COORDINATOR_35_CONTINUE57.json'}
wd=W/rel;wd.mkdir(exist_ok=False)
for p,h in pins.items():
    dst=wd/'game'/p;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(G/p,dst);assert sha(dst)==h
shutil.copytree(e,wd/'evidence');save(wd/'ASSEMBLY.json',a);save(wd/'ACCEPTANCE.json',acceptance)
pointer=read(O/'POINTER.before.json');pointer.update(title='Замок и осада · общая сцена 57 · живучие противники',revision=revision,assembly_sha256=sha(wd/'ASSEMBLY.json'),scope='All56 retained; castle duelist480HP and resident270HP with stronger body parts. Weapon controls unchanged.')
rd=R/rel;rd.mkdir(exist_ok=False)
for name,target in [('game',G),('evidence',e)]:
    cmd="New-Item -ItemType Junction -Path '"+str(rd/name).replace("'","''")+"' -Target '"+str(target).replace("'","''")+"' | Out-Null"
    subprocess.run(['pwsh','-NoProfile','-Command',cmd],check=True)
save(rd/'ASSEMBLY.json',a);save(rd/'ACCEPTANCE.json',acceptance)
handoff={'revision':revision,'base_commit':base,'frozen_source':str(G),'acceptance':rel+'/ACCEPTANCE.json','changed':changed,'included':included,'limits':limits,'optimization_handoff':'Base further optimization on57. Preserve55 masonry destruction,56 weapon controls and57 opponent health. Current manifest is authoritative.','instructions':'New candidates/tests on D via scheduler. Preserve foreign WIP and frozen releases. Old chats remain idle.'}
header='''## Координатор35 — общая57, живучие противники, 19 октября 2026

По жалобе пользователя замковый дуэлянт получил480HP вместо120;
резидент270 вместо90 и усиленные локальные пороги частей тела.
Убраны принудительная смерть от одного сильного удара в голову и
мгновенное убийство копьём без исчерпания здоровья.
Четыре настоящих удара кувалдой оставили замковому дуэлянту341HP.
Нативно проверены резидент, голова/корпус и смерть от следующих попаданий.
Здоровье игрока, управление мечом/кувалдой и разрушения55 сохранены.
Source D:/MafioziCombat31/coordinator35_health57/game frozen; release57/game
локально junction, в Git обычные файлы. Приёмка outputs/coordinator35_release57/ACCEPTANCE.json.
Передача docs/ai/COORDINATOR_35_CONTINUE57.json. Оптимизацию базировать на57.
Чистый FPS не принят; чужой WIP сохранить, новые проверки наD через scheduler.

'''.encode('utf-8')
for root in [R,W]:
    save(root/'godot/current_version.json',pointer);save(root/'outputs/coordinator31_castle_current/ASSEMBLY.json',a);save(root/'docs/ai/COORDINATOR_35_CONTINUE57.json',handoff)
    ag=root/'AGENTS.md';ag.write_bytes(header+ag.read_bytes())
    attrs=root/'.gitattributes';raw=attrs.read_bytes();attrs.write_bytes(raw+(b'' if raw.endswith(b'\n') else b'\n')+('/'+rel+'/game/** -text\n/'+rel+'/evidence/** -text\n/'+rel+'/ASSEMBLY.json -text\n').encode())
assert all(sha(R/p)==h for p,h in before.items() if p not in ['AGENTS.md','.gitattributes','godot/current_version.json','outputs/coordinator31_castle_current/ASSEMBLY.json'])
save(O/'RELEASE_PREPARED.json',{'revision':revision,'pins':len(pins),'changed':changed,'checks':len(checks)})
print(json.dumps(read(O/'RELEASE_PREPARED.json')))
