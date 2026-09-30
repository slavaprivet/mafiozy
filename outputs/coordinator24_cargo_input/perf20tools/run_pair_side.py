"""ROOT ONLY: executes one GPU side when explicitly invoked; never closes other apps."""
from pathlib import Path
import argparse,hashlib,json,subprocess,time
P=argparse.ArgumentParser();P.add_argument('--pack',type=Path,required=True);P.add_argument('--sha256',required=True);P.add_argument('--side',choices=['baseline','candidate'],required=True);P.add_argument('--out',type=Path,required=True);P.add_argument('--cache-note',required=True);a=P.parse_args()
base=Path(__file__).resolve().parent;pack=a.pack.resolve();out=a.out.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(pack)==a.sha256.lower(),'Exact PCK SHA mismatch'
if a.side=='baseline':assert a.sha256.lower()=='8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741','Must use accepted16'
receipt_path=pack.parent/'build_receipt.json';receipt=json.loads(receipt_path.read_text(encoding='utf-8-sig'));assert next(v['sha256'] for v in receipt['artifacts'] if v['filename']==pack.name)==a.sha256.lower()
assert not out.exists(),'Use fresh output folder';out.mkdir(parents=True)
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
cmd=[str(engine),'--main-pack',str(pack),'--position','-32000,-32000','--resolution','1280x720','--rendering-method','forward_plus','--rendering-driver','vulkan','--script',str(base/'capture.gd'),'--','--qa-out='+str(out),'--qa-side='+a.side,'--qa-pack='+str(pack),'--qa-sha='+a.sha256.lower()]
started=time.monotonic()
with (out/'engine.log').open('w',encoding='utf8') as log:
 try:
  proc=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=60);result={'exit_code':proc.returncode}
 except subprocess.TimeoutExpired:result={'timeout_seconds':60}
result.update(seconds=time.monotonic()-started,command=cmd,side=a.side,pack_sha256=a.sha256.lower(),receipt_sha256=sha(receipt_path),harness_sha256=sha(base/'capture.gd'),cache_note=a.cache_note,scope='Prepared sequential GPU pair; offscreen(-32000,-32000) NO_FOCUS window; no capture. Driver owns logical QA control, real scene/UI/inventory/collisions stay scheduled.')
(out/'RUN.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(result,ensure_ascii=False));raise SystemExit(result.get('exit_code',2))
