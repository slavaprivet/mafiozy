from pathlib import Path
import hashlib,json,subprocess,shutil,difflib
R=Path('C:/Users/Слава/Desktop/Мафиози'); W=Path('D:/MafioziCombat31/publish_mixed31')
O=Path(__file__).parent;G=O/'game';rel='outputs/coordinator35_release55'
revision='castle-20261019-combined55-destructible-walls';base='1d30d97e7a94519762caf34d48be2e079fe15f19'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=W)
def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert git('rev-parse','HEAD').decode().strip()==base
assert not git('status','--porcelain','--untracked-files=no').strip()
assert git('ls-remote','origin','refs/heads/main').decode().split()[0]==base
assert (R/'godot/current_version.json').read_bytes()==(O/'POINTER.before.json').read_bytes()
before=read(O/'WORKING.before.json');assert all(sha(R/p)==h for p,h in before.items())
a=read(O/'BASE54.json');old_pins=dict(a['source_pins']);pins={p:sha(G/p) for p in old_pins}
changed=[p for p,h in pins.items() if old_pins[p]!=h]
assert changed==['scripts/city/castle_site.gd']
review=read(O/'review/REVIEW_FINAL02.json')
assert review['status']=='PASS_SOURCE_REVIEW' and review['reviewed_source_sha256']==pins[changed[0]]
assert pins[changed[0]]=='3a35a58a1366195b31b703cc5da8446262816787cd0c6d124224766dab7d0250'
groups=['candidate02','coverage02','projectiles03','navigation04','sword_contact02']
checks=[]
for group in groups:
    summary=read(O/group/'SUMMARY.json');assert summary['passed'] and not summary['drift'],summary
    assert read(O/group/'SOURCE.json')==pins,group
    checks.append(summary)
assert read(O/'coverage02/RESULT.json')['passed']
shutil.copy2(R/'outputs/coordinator35_release54/evidence/qa/contact54.gd',O/'qa/contact54.gd')
e=O/'evidence';e.mkdir(exist_ok=False)
for p in list(O.iterdir()):
    if p.name in ['game','evidence','__pycache__']:continue
    if p.is_dir():shutil.copytree(p,e/p.name)
    elif p.is_file():shutil.copy2(p,e/p.name)
old=(R/'outputs/coordinator35_release54/game/scripts/city/castle_site.gd').read_text(encoding='utf-8').splitlines(True)
new=(G/'scripts/city/castle_site.gd').read_text(encoding='utf-8').splitlines(True)
(e/'castle55.patch').write_text(''.join(difflib.unified_diff(old,new,fromfile='54/castle_site.gd',tofile='55/castle_site.gd')),encoding='utf-8')
limits=['Clean game FPS not measured; native group timings were functional checks alongside the user game, not a clean performance benchmark.',
        'Blast radius and power are unchanged. Stone resists ordinary sword melee as before; masonry destruction uses siege/explosion impacts.',
        'Existing local support heuristic and capped debris physics remain; this is not a full structural engineering simulation.']
acceptance={'revision':revision,'status':'ACCEPTED_FUNCTIONAL','base_commit':base,'source_pins':pins,'changed':changed,'checks':checks,'source_review':review,
    'coverage_groups':81,'real_catapult_shots':3,'raw_failures_preserved':True,
    'included':['Remaining wall layers stay collidable and can be hit again after the front layer breaks.',
        'Blast queries include full member bounds; surface hits break long columns, bastions and rotated stonework.',
        'Projecting masonry has physical hit shapes; sills, corbels and round tower platforms/roofs participate in destruction.',
        'Destroyed cells and support cascades remove their collision while preserving adjacent intact masonry.',
        'All1346 other54 files unchanged, including approved sword and held RMB controls.'], 'limits':limits}
a.update(revision=revision,game_relative=rel+'/game',source_pins=pins,base_published_commit=base,
    validation='81 masonry groups,3 real catapult shots, repeat impacts,4 stair climbs, gate, breach traversal, floor and sword contact PASS. One production file changed.')
a['included_packages']+=acceptance['included'][:4]
a['evidence']['combined55']=rel+'/ACCEPTANCE.json';a['evidence']['current_scene']=rel+'/evidence/projectiles03/layered_gate_wall_after.png'
a['masonry55']={'acceptance':rel+'/ACCEPTANCE.json','source_on_D':str(G),'resume':'docs/ai/COORDINATOR_35_CONTINUE55.json'}
Wdest=W/rel;Wdest.mkdir(exist_ok=False)
for p,h in pins.items():
    dest=Wdest/'game'/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(G/p,dest);assert sha(dest)==h
shutil.copytree(e,Wdest/'evidence');save(Wdest/'ASSEMBLY.json',a);save(Wdest/'ACCEPTANCE.json',acceptance)
pointer=read(O/'POINTER.before.json');pointer.update(title='Замок и осада · общая сцена 55 · разрушаемые стены',revision=revision,assembly_sha256=sha(Wdest/'ASSEMBLY.json'),scope='All54 retained; destructible masonry layers, columns, projecting stonework and tower platforms. Approved weapon controls unchanged.')
Rdest=R/rel;Rdest.mkdir(exist_ok=False)
for name,target in [('game',G),('evidence',e)]:
    cmd="New-Item -ItemType Junction -Path '"+str(Rdest/name).replace("'","''")+"' -Target '"+str(target).replace("'","''")+"' | Out-Null"
    subprocess.run(['pwsh','-NoProfile','-Command',cmd],check=True)
save(Rdest/'ASSEMBLY.json',a);save(Rdest/'ACCEPTANCE.json',acceptance)
handoff={'revision':revision,'base_commit':base,'game':str(G),'frozen':True,'acceptance':rel+'/ACCEPTANCE.json','changed':changed,
    'user_request':'Break remaining rear wall layers, columns and all wall masonry; publish main.',
    'root_causes':['Centre-only blast distance and centre-only spatial index missed large members.', 'Whole coarse collision panels disappeared after a small breach, leaving visible rear/neighbor stones unhittable.', 'Some stone dressing/platforms were outside damage ownership.'],
    'optimization_handoff':'Use55, not54. Main walls retain coarse collision until locally damaged; preserve lazy refinement and geometry-aware spatial bounds. New compound hit shapes cover projecting masonry. Do not revert to centre-only queries or erase whole panel collision. Benchmark before tuning; no clean FPS acceptance here.',
    'limits':limits,'instructions':'Read current_version and ASSEMBLY. Candidate/tests on D through scheduler. Preserve frozen55, foreign WIP and approved54 weapons. Old chats remain idle.'}
header='''## Координатор35 — общая55, разрушаемая кладка, 19 октября 2026

По фото пользователя исправлены непробиваемый второй слой стены и колонны.
Причины: урон/пространственный поиск только по центру крупных элементов;
после пробоины отключался целый coarse collider, оставляя видимые камни без попаданий.
Теперь поиск учитывает габариты и поворот, остатки кладки сохраняют точную
коллизию; разрушение и delayed support отключают только разрушенные элементы.
Выступающая кладка имеет hit shapes;24подоконника,8консолей,4башенных пола
и4крыши включены в разрушения с сохранением круглой формы и debris shape.
81группа кладки/опор,3реальных выстрела катапульты,повторные попадания,
4лестницы,ворота,физический проход сквозь пробоину,пол и меч ПКМ проверены.
1игровой файл castle_site.gd;1346остальных файлов54 неизменны, меч не трогать.
Raw FAIL и исправления harness сохранены; чистый FPS не принят.
Source D:/MafioziCombat31/coordinator35_walls55/game frozen. Release55/game
локально junction, в Git обычные файлы. Приёмка outputs/coordinator35_release55/ACCEPTANCE.json.
Передача docs/ai/COORDINATOR_35_CONTINUE55.json. Оптимизацию базировать на55.
Чужой WIP не трогать, новый source/tests наD через scheduler; старые чаты не будить.

'''.encode('utf-8')
for root in [R,W]:
    save(root/'godot/current_version.json',pointer);save(root/'outputs/coordinator31_castle_current/ASSEMBLY.json',a)
    save(root/'docs/ai/COORDINATOR_35_CONTINUE55.json',handoff)
    ag=root/'AGENTS.md';ag.write_bytes(header+ag.read_bytes())
    attrs=root/'.gitattributes';raw=attrs.read_bytes();attrs.write_bytes(raw+(b'' if raw.endswith(b'\n') else b'\n')+('/'+rel+'/game/** -text\n/'+rel+'/evidence/** -text\n/'+rel+'/ASSEMBLY.json -text\n').encode())
assert all(sha(R/p)==h for p,h in before.items() if p not in ['AGENTS.md','.gitattributes','godot/current_version.json'])
save(O/'RELEASE_PREPARED.json',{'revision':revision,'pins':len(pins),'changed':changed,'checks':len(checks)})
print(json.dumps(read(O/'RELEASE_PREPARED.json')))
