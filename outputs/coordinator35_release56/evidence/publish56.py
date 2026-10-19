from pathlib import Path
import json, hashlib, subprocess, shutil

R=Path('C:/Users/Слава/Desktop/Мафиози')
W=Path('D:/MafioziCombat31/publish_mixed31')
O=Path(__file__).parent
rel='outputs/coordinator35_release56'
revision='castle-20261019-combined56-free-sledge'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def git(*args):return subprocess.check_output(['git',*args],cwd=W)

assert git('rev-parse','HEAD').decode().strip()=='6f6f8199b38c60a42b7527964930860e42585cf9'
receipt=read(R/'outputs/current_game/OPENED.json')
opened=receipt['revision']==revision and receipt['ready']
if opened:
    run=Path(receipt['run_directory'])
    assert not (run/'play.err').read_text(encoding='utf-8-sig').strip()
    for root in [R,W]:
        target=root/rel/'evidence/ordinary56'
        target.mkdir(exist_ok=True)
        for file in run.iterdir():
            if file.is_file():shutil.copy2(file,target/file.name)
delivery={'revision':revision,'status':'OPENED_READY' if opened else 'CHECK_ONLY_READY','receipt':receipt if opened else None,
          'source_sha256':sha(O/'game/scripts/weapons/sword_prototype.gd'),
          'validation':'Sledge directional hold/grip/self-clearance/G-E and real contact PASS; sword LMB/RMB regressions and source review PASS.',
          'prior_scene_closed_by_this_run':False,
          'limits':['Opening receipt is an observation, not permanent process ownership.','Clean FPS not measured.']}
for root in [R,W]:save(root/rel/'DELIVERY.json',delivery)

git('-c','core.autocrlf=false','add','--sparse','--','AGENTS.md','.gitattributes','godot/current_version.json','outputs/coordinator31_castle_current/ASSEMBLY.json','docs/ai/COORDINATOR_35_CONTINUE56.json')
git('-c','core.autocrlf=false','add','--sparse','-f','--',rel)
staged=git('diff','--cached','--name-only','-z').decode().split('\0')
allowed=['AGENTS.md','.gitattributes','godot/current_version.json','outputs/coordinator31_castle_current/ASSEMBLY.json','docs/ai/COORDINATOR_35_CONTINUE56.json']
assert all(p in allowed or p.startswith(rel+'/') for p in staged if p)
entries={}
for row in git('ls-files','--stage','-z','--',rel+'/game').decode().split('\0'):
    if not row:continue
    fields,path=row.split('\t',1)
    mode,oid,stage=fields.split();assert mode=='100644' and stage=='0'
    entries[path]=(mode,oid)
pins=read(W/rel/'ASSEMBLY.json')['source_pins']
assert len(entries)==len(pins)==1347
for p,h in pins.items():
    f=W/rel/'game'/p;b=f.read_bytes()
    assert hashlib.sha256(b).hexdigest()==h
    object_id=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
    assert entries[rel+'/game/'+p][1]==object_id,p
for p in allowed:
    if p in ['AGENTS.md','.gitattributes']:continue
    assert (R/p).read_bytes()==(W/p).read_bytes(),p
before=read(O/'WORKING.before.json')
old_agents=git('show','HEAD:AGENTS.md')
new_agents=(W/'AGENTS.md').read_bytes()
assert new_agents.endswith(old_agents)
header=new_agents[:-len(old_agents)]
root_agents=(R/'AGENTS.md').read_bytes()
assert root_agents.startswith(header) and hashlib.sha256(root_agents[len(header):]).hexdigest()==before['AGENTS.md']
old_attrs=git('show','HEAD:.gitattributes')
new_attrs=(W/'.gitattributes').read_bytes()
assert new_attrs.startswith(old_attrs)
extra=new_attrs[len(old_attrs):]
root_attrs=(R/'.gitattributes').read_bytes()
assert root_attrs.endswith(extra) and hashlib.sha256(root_attrs[:-len(extra)]).hexdigest()==before['.gitattributes']
assert all(sha(R/p)==h for p,h in before.items() if p not in ['AGENTS.md','.gitattributes','godot/current_version.json','outputs/coordinator31_castle_current/ASSEMBLY.json'])
report={'status':'PASS','source_pins':len(pins),'staged_files':len([p for p in staged if p]),'all_source_files_regular_blobs':True,'root_foreign_wip_and_index_unchanged':True,'ordinary_pid':receipt['pid'] if opened else None}
save(O/'PUBLISH_VALIDATION.json',report)
print(json.dumps(report))
