from pathlib import Path
import argparse, hashlib, json, subprocess, time
p=argparse.ArgumentParser()
p.add_argument('--pack',type=Path,required=True)
p.add_argument('--sha256',required=True)
p.add_argument('--revision',required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args(); base=Path(__file__).resolve().parent; pack=a.pack.resolve(); out=a.out.resolve()
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(pack)==a.sha256.lower(), 'Exact pack SHA mismatch'
receipt_path=pack.parent/'build_receipt.json'; receipt=json.loads(receipt_path.read_text(encoding='utf-8-sig'))
assert next(x['sha256'] for x in receipt['artifacts'] if x['filename']==pack.name)==a.sha256.lower(), 'Sibling receipt mismatch'
assert not out.exists(), 'Use a fresh output directory'
out.mkdir(parents=True)
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
cmd=[str(engine),'--main-pack',str(pack),'--position','-32000,-32000','--resolution','1280x720','--script',str(base/'capture.gd'),'--','--qa-out='+str(out),'--qa-pack-sha='+a.sha256.lower(),'--qa-revision='+a.revision]
start=time.monotonic()
with (out/'engine.log').open('w',encoding='utf-8') as log:
    try:
        proc=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=40)
        result={'exit_code':proc.returncode}
    except subprocess.TimeoutExpired:
        result={'timeout_seconds':40}
result.update(seconds=time.monotonic()-start,command=cmd,pack_sha256=a.sha256.lower(),receipt_sha256=sha(receipt_path),harness_sha256=sha(base/'capture.gd'),scope='Root-only actual GUI acceptance, offscreen NO_FOCUS. No native camera or comparable performance claim. Does not manage other game processes.')
(out/'RUN.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
raise SystemExit(result.get('exit_code',2))
