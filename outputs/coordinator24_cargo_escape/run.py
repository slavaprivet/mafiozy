"""Bounded exact-pack Escape regression; sequential root-only GPU mode."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--side',choices=['baseline','candidate'],required=True)
p.add_argument('--out',required=True);p.add_argument('--gpu',action='store_true');a=p.parse_args()
here=Path(__file__).resolve().parent;root=here.parents[1]
number,label,pin=(20,'24a','634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5') if a.side=='baseline' else (22,'24b','becb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749')
game=root/f'outputs/coordinator24_quality/candidate{number}/godot/mafiozi_walk'
export=game/f'exports/win64/s01-20260930-quality{label}';pack=export/'MafioziPreview.pck'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(pack)==pin
receipt=json.loads((export/'build_receipt.json').read_text(encoding='utf-8-sig'))
for row in receipt['inputs']:assert sha(game/row['path'])==row['sha256'],row['path']
assert len(receipt['inputs'])==209
out=Path(a.out).resolve();assert out.is_relative_to(here) and not out.exists();out.mkdir()
engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
harness=here/'test_escape.gd';assert harness.is_file()
cmd=[str(engine),'--main-pack',str(pack),'--script',str(harness),'--resolution','1280x720']
if not a.gpu:cmd+=['--headless','--fixed-fps','60']
cmd+=['--','--qa-out='+str(out),'--expected-sha='+pin,'--exact-pack='+str(pack)]
if a.side=='candidate':cmd+=['--expect-fixed']
if a.gpu:cmd+=['--gpu']
start=time.monotonic()
with (out/'engine.log').open('w',encoding='utf8') as log:
    try:
        result=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=45,creationflags=0 if a.gpu else subprocess.CREATE_NO_WINDOW)
        exit_code=result.returncode
    except subprocess.TimeoutExpired:exit_code=-999
record={'side':a.side,'gpu':a.gpu,'pack_sha256':pin,'harness_sha256':sha(harness),
 'source_inputs':209,'seconds':time.monotonic()-start,'exit_code':exit_code,'pack_unchanged':sha(pack)==pin,'command':cmd}
log=(out/'engine.log').read_text(encoding='utf8')
record['native_errors']=any(v in log for v in ['SCRIPT ERROR','ERROR:','Parse Error'])
if (out/'ESCAPE_RESULT.json').exists():record['result']=json.loads((out/'ESCAPE_RESULT.json').read_text(encoding='utf8'))
(out/'RUN.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({k:v for k,v in record.items() if k not in ['command','result']}))
raise SystemExit(0 if exit_code==0 and not record['native_errors'] and record['pack_unchanged'] and record.get('result',{}).get('valid') else 1)
