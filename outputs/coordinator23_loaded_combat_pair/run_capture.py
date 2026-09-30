"""Run ONE explicitly selected pack. Root owns closing/restoring the visible game.
No other process is killed; no automatic second GPU process or pair launch.
"""
import argparse, hashlib, json, subprocess, time
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--engine',type=Path,required=True)
p.add_argument('--pack',type=Path,required=True)
p.add_argument('--expected-sha',required=True)
p.add_argument('--side',choices=['baseline','candidate'],required=True)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--run-gpu',action='store_true',help='Explicit root-only GPU launch after exclusive GPU slot is free')
p.add_argument('--behavior-only',action='store_true')
a=p.parse_args()
if a.run_gpu==a.behavior_only:p.error('Choose exactly one of --run-gpu or --behavior-only')
pack=a.pack.resolve();engine=a.engine.resolve();out=a.out.resolve();script=Path(__file__).with_name('capture.gd').resolve()
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(pack)==a.expected_sha,'Exact pack SHA mismatch'
if a.side=='baseline':assert a.expected_sha=='ec737f864181031e574bc4eb9e179a6d70cf3be6282a6068371b388b25167179','Wrong baseline'
out.mkdir(parents=True,exist_ok=True)
command=[str(engine)]
if a.behavior_only:command+=['--headless']
# Critical: pack directory as --path, never a raw source project fallback.
command+=['--path',str(pack.parent),'--main-pack',str(pack),'--script',str(script),'--log-file',str(out/'engine.log'),'--',f'--out={out}',f'--side={a.side}',f'--pack={pack}']
if a.behavior_only:command+=['--behavior-only']
receipt={'pack':str(pack),'pack_sha256':a.expected_sha,'test_sha256':sha(script),'runner_sha256':sha(Path(__file__)),'command':command,'gpu':a.run_gpu,'other_processes_untouched':True,'external_deadline_seconds':63}
(out/'RUN_RECEIPT.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
start=time.monotonic()
with (out/'stdout.log').open('w',encoding='utf-8') as log:
    child=subprocess.Popen(command,cwd=pack.parent,stdout=log,stderr=subprocess.STDOUT)
    try:code=child.wait(timeout=63)
    except subprocess.TimeoutExpired:
        child.kill();child.wait();code=124
receipt.update(exit_code=code,elapsed_seconds=time.monotonic()-start,pack_unchanged=sha(pack)==a.expected_sha,test_unchanged=sha(script)==receipt['test_sha256'])
(out/'RUN_RECEIPT.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({k:receipt[k] for k in ['exit_code','elapsed_seconds','pack_unchanged','test_unchanged']}))
raise SystemExit(code)
