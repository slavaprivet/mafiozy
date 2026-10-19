from pathlib import Path
import hashlib,json,shutil,sys,subprocess
R=Path('C:/Users/Слава/Desktop/Мафиози'); O=Path(__file__).parent; G=O/'game'
sys.path.insert(0,str(R/'tools/godot')); from test_scheduler import Lease
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pointer=json.loads((R/'godot/current_version.json').read_text(encoding='utf-8-sig'))
A=R/pointer['assembly'];assert sha(A)==pointer['assembly_sha256']
a=json.loads(A.read_text(encoding='utf-8-sig')); S=R/a['game_relative']
assert a['revision']=='castle-20261019-combined56-free-sledge'
before={}
for raw in subprocess.check_output(['git','diff','--name-only','-z'],cwd=R).decode().split('\0'):
    if raw and (R/raw).is_file():before[raw]=sha(R/raw)
before['.git/index']=sha(R/'.git/index')
save(O/'WORKING.before.json',before);shutil.copy2(R/'godot/current_version.json',O/'POINTER.before.json');shutil.copy2(A,O/'BASE56.json')
with Lease('headless',G,access='write',wait_seconds=300):
    G.mkdir(exist_ok=False)
    for p,h in a['source_pins'].items():
        assert sha(S/p)==h,p
        d=G/p;d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/p,d)
        if (S/(p+'.import')).is_file():shutil.copy2(S/(p+'.import'),G/(p+'.import'))
    shutil.copytree(S/'.godot',G/'.godot',ignore=shutil.ignore_patterns('editor'))
print(json.dumps({'pins':len(a['source_pins']),'game':str(G)}))
