from pathlib import Path
import json,hashlib,subprocess,shutil,difflib

R=Path('C:/Users/Слава/Desktop/Мафиози')
W=Path('D:/MafioziCombat31/publish_mixed31')
O=Path(__file__).parent;G=O/'game'
base='46c3563e4e92706ca62776c5354d75b97c2a29b6'
rel='outputs/coordinator35_release54'
revision='castle-20261019-combined54-right-hand'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def git(root,*args):return subprocess.check_output(['git',*args],cwd=root)
def save(p,d):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

assert git(W,'rev-parse','HEAD').decode().strip()==base
assert not git(W,'status','--porcelain','--untracked-files=no').strip()
assert (R/'godot/current_version.json').read_bytes()==(O/'POINTER.before.json').read_bytes()
before=read(O/'WORKING.before.json')
assert all(sha(R/p)==h for p,h in before.items())
c=read(O/'CANDIDATE.json');pins=c['source_pins']
assert all(sha(G/p)==h for p,h in pins.items())
checks=[]
for name in ['INITIAL','LEFT','CONTACT','REGRESSION','VISUAL']:
    group=read(O/(name+'.json'));assert all(r['passed'] and not r['drift'] for r in group),name
    checks+=group
assert len(checks)==13
review=read(O/'review/REVIEW_FINAL03.json')
assert review['status']=='PASS_SOURCE_REVIEW' and not review['open_findings']
assert pins['scripts/weapons/sword_prototype.gd']=='31c8949c4825e5ca05f1489fb0e0c3b63705398adf624508a85f0ae70e778dda'
evidence=O/'evidence';evidence.mkdir(exist_ok=False)
for p in list(O.iterdir()):
    if p.name in ['game','evidence','__pycache__']:continue
    if p.is_dir():shutil.copytree(p,evidence/p.name)
    elif p.suffix in ['.json','.py','.gd']:shutil.copy2(p,evidence/p.name)
old=(R/'outputs/coordinator34_release53/game/scripts/weapons/sword_prototype.gd').read_bytes().decode('utf-8').replace('\r','').splitlines(True)
new=(G/'scripts/weapons/sword_prototype.gd').read_bytes().decode('utf-8').replace('\r','').splitlines(True)
(evidence/'sword54.patch').write_text(''.join(difflib.unified_diff(old,new,fromfile='53/sword_prototype.gd',tofile='54/sword_prototype.gd')),encoding='utf-8')
limits=['Source review proves LMB-only code equivalence, not a new subjective approval of all play states.','Clean full-game FPS not measured.','Existing head/torso self-clearance uses proxies, not full triangle self-collision.']
acceptance={'status':'ACCEPTED_FUNCTIONAL','base_commit':base,'revision':revision,'source_pins':pins,'changed':c['changed'],'checks':checks,'source_review':review,'raw_failures_preserved':True,'included':['All accepted53 map/soil/camp/armor/opponent/bow retained.','Holding RMB freely steers the right-hand sword/mace with existing LMB swing/IK/contact dynamics.','Same release momentum and continuous mouse-driven stroke, no automatic repeated clicks.','Shield defense, half-sword and two-hand modes preserved; invalid half-sword mode cleared when selecting a different weapon.','Numerically stable nearly parallel RMB endpoints; primary LMB interpolation unchanged.'],'limits':limits}
a=read(O/'BASE53.json')
a.update(revision=revision,game_relative=rel+'/game',source_pins=pins,base_published_commit=base,validation='13 final merged input/contact/graphical checks PASS; source review verifies LMB-only branch equivalence. One production file changed.')
a['included_packages']+=acceptance['included'][1:]
a['evidence']['combined54']=rel+'/ACCEPTANCE.json'
a['evidence']['current_scene']=rel+'/evidence/sword_visual01/hold_0.png'
a['combat54']={'acceptance':rel+'/ACCEPTANCE.json','source_on_D':str(G),'resume':'docs/ai/COORDINATOR_35_CONTINUE54.json','left_mouse_lock':'docs/ai/SINGLE_SWORD_LOCK52_AUDIT.json'}
pointer=read(O/'POINTER.before.json')
pointer.update(title='Замок и осада · общая сцена 54 · свободная правая рука',revision=revision,scope='All combined53 retained. User-requested held RMB sword/mace free swing; approved LMB-only behavior preserved.')
Wdest=W/rel;Wdest.mkdir(exist_ok=False)
for p,h in pins.items():
    dest=Wdest/'game'/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(G/p,dest);assert sha(dest)==h,p
shutil.copytree(evidence,Wdest/'evidence')
save(Wdest/'ASSEMBLY.json',a);save(Wdest/'ACCEPTANCE.json',acceptance)
pointer['assembly_sha256']=sha(Wdest/'ASSEMBLY.json')
Rdest=R/rel;Rdest.mkdir(exist_ok=False)
for name,target in [('game',G),('evidence',evidence)]:
    command="New-Item -ItemType Junction -Path '"+str(Rdest/name).replace("'","''")+"' -Target '"+str(target).replace("'","''")+"' | Out-Null"
    subprocess.run(['pwsh','-NoProfile','-Command',command],check=True)
save(Rdest/'ASSEMBLY.json',a);save(Rdest/'ACCEPTANCE.json',acceptance)
handoff={'revision':revision,'base_commit':base,'game':str(G),'frozen':True,'coordinator_thread':'01a150c6-a336-72e3-9748-2446c3a8c29e','acceptance':rel+'/ACCEPTANCE.json','changed':c['changed'],'user_request':'Hold RMB with one-handed sword or mace and move the hand exactly as with held LMB.','left_mouse_preserved':True,'authorized_lock_exception':'Only add RMB one-hand equivalence and fix invalid half-sword carryover when changing weapons. Do not retune approved LMB coefficients, IK, camera or damage.','limits':limits,'instructions':'Resolve current_version.json and ASSEMBLY. All future candidates/tests on D through scheduler; preserve frozen53/54 and foreign WIP. Current game PID must be freshly checked. Do not wake old chats.'}
header='''## Координатор35 — общая54, свободный ПКМ, 19 октября 2026

Новое прямое поручение: при долгом удержании ПКМ одноручный меч и булава
двигаются свободно, как на ЛКМ. Это узкое разрешённое дополнение к эталону52;
ощущения одиночного ЛКМ не перенастраивать. Правая рука использует прежние
замах/IK/контакт/урон; отпускание ПКМ не прерывает продолжающийся ЛКМ.
Щит и полумеч сохраняют управление; старый режим полумеча сбрасывается при
смене на другое оружие, чтобы не блокировать свободную булаву.
Добавлена численная защита почти параллельного направления только для ПКМ.
1игровой файл,1347pins;13 final merged native/GUI проверок PASS,10 кадров;
ЛКМ input/phase/динамика и38 IK/contact функций сверены с53, коэффициенты прежние.
Все карта/грунт/лагерь/броня/NPC/лук53 сохранены. Raw FAIL не удалены.
Передача docs/ai/COORDINATOR_35_CONTINUE54.json; приёмка
outputs/coordinator35_release54/ACCEPTANCE.json. D:/MafioziCombat31/coordinator35_rmb54/game
frozen; локально release54/game junction, в Git обычные файлы.
Чужой WIP сохранять, старые чаты не будить. Текущий состав только по manifest.

'''.encode('utf-8')
for root in [R,W]:
    save(root/'godot/current_version.json',pointer)
    save(root/'outputs/coordinator31_castle_current/ASSEMBLY.json',a)
    save(root/'docs/ai/COORDINATOR_35_CONTINUE54.json',handoff)
    agents=root/'AGENTS.md';agents.write_bytes(header+agents.read_bytes())
    attrs=root/'.gitattributes';raw=attrs.read_bytes();extra=('/'+rel+'/game/** -text\n/'+rel+'/evidence/** -text\n/'+rel+'/ASSEMBLY.json -text\n').encode()
    attrs.write_bytes(raw+(b'' if raw.endswith(b'\n') else b'\n')+extra)
save(O/'RELEASE_PREPARED.json',{'revision':revision,'pins':len(pins),'checks':len(checks),'relative':rel,'source_sha256':pins['scripts/weapons/sword_prototype.gd']})
assert all(sha(R/p)==h for p,h in before.items() if p not in ['AGENTS.md','.gitattributes','godot/current_version.json'])
print(json.dumps(read(O/'RELEASE_PREPARED.json')))
