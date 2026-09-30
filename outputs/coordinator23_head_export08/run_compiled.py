from pathlib import Path
import json,hashlib,subprocess,sys,time
O=Path(__file__).resolve().parent;R=O.parent.parent
assert len(sys.argv)==2 and sys.argv[1] in ['active','native'],'Choose active or native'
mode=sys.argv[1]
for rel,h in json.loads((O/'EXTERNAL_TEST_PINS.json').read_text()).items():
 assert hashlib.sha256((R/rel).read_bytes()).hexdigest()==h,rel
proof=json.loads((O/'EXPORT_PROOF.json').read_text());pack=Path(proof['pck_path'])
assert hashlib.sha256(pack.read_bytes()).hexdigest()==proof['pck_sha256']
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
cwd=O/'empty_cwd';cwd.mkdir(exist_ok=True);assert not list(cwd.iterdir())
log=O/('compiled_'+mode+'.log');assert not log.exists(),'Preserve prior result before repeat'
cmd=[str(engine),'--headless','--main-pack',str(pack),'--fixed-fps','60','--script',str(O/('compiled_'+mode+'.gd'))]
t=time.monotonic()
with log.open('w',encoding='utf8') as f:
 try:
  p=subprocess.run(cmd,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=90)
  result={'exit_code':p.returncode}
 except subprocess.TimeoutExpired:result={'timeout':90}
text=log.read_text(encoding='utf8');prefix='ACTIVE_HEAD_RESULT ' if mode=='active' else 'HIT_IMPULSE_RESULT '
result.update(command=cmd,seconds=time.monotonic()-t,pck_sha256=proof['pck_sha256'])
result['binding']=next((json.loads(l.split(' ',1)[1]) for l in text.splitlines() if l.startswith('COMPILED_HEAD_BINDING ')),None)
result['test']=next((json.loads(l.split(' ',1)[1]) for l in text.splitlines() if l.startswith(prefix)),None)
result['accepted']=result.get('exit_code')==0 and bool(result['binding']) and result['binding'].get('ok') and bool(result['test']) and result['test'].get('errors')==[] and not any(k in text for k in ['SCRIPT ERROR','Parse Error','FAIL '])
(O/('compiled_'+mode+'_result.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
print(json.dumps({'accepted':result['accepted'],'seconds':result['seconds'],'checks':result['test'].get('checks') if result['test'] else None}))
sys.exit(0 if result['accepted'] else 1)
