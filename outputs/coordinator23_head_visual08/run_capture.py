from pathlib import Path
import argparse,json,hashlib,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--pack',type=Path,required=True);p.add_argument('--sha256',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
O=Path(__file__).resolve().parent;pack=a.pack.resolve();out=a.out.resolve();h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert h(pack)==a.sha256.lower(),'Exact accepted test pack SHA required'
receipt=json.loads((pack.parent/'build_receipt.json').read_text());assert next(x['sha256'] for x in receipt['artifacts'] if x['filename']==pack.name)==a.sha256.lower(),'Pack not bound to sibling build receipt'
for name,sha in json.loads((O/'HARNESS_PINS.json').read_text()).items():assert h(O/name)==sha,name
assert not out.exists(),'Use a fresh output directory';out.mkdir(parents=True)
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
cmd=[str(engine),'--main-pack',str(pack),'--position','-32000,-32000','--resolution','1280x720','--script',str(O/'capture.gd'),'--','--qa-out='+str(out),'--qa-pack-sha='+a.sha256.lower()]
started=time.monotonic()
with (out/'engine.log').open('w',encoding='utf8') as log:
 try:
  process=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=25);result={'exit_code':process.returncode}
 except subprocess.TimeoutExpired:result={'timeout':25}
result.update(seconds=time.monotonic()-started,command=cmd,pck_sha256=a.sha256.lower(),build_receipt_sha256=h(pack.parent/'build_receipt.json'),scope='Root-only offscreen actualGPU evidence; no native-camera or perf claim')
(out/'RUN.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8');print(json.dumps(result))
