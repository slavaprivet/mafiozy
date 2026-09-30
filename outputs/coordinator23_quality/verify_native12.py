from pathlib import Path
import argparse,hashlib,json,subprocess,time
parser=argparse.ArgumentParser();parser.add_argument('--candidate',default='candidate12');parser.add_argument('--out',default='coordinator23_compiled12');parser.add_argument('--pointer',action='store_true');args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
export=root/'outputs/coordinator23_quality'/args.candidate/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23h'
pack=export/'MafioziPreview.pck';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
receipt=json.loads((export/'build_receipt.json').read_text(encoding='utf-8-sig'))
assert next(x['sha256'] for x in receipt['artifacts'] if x['filename']==pack.name)==sha(pack)
out=root/'outputs'/args.out;out.mkdir(exist_ok=True)
engine='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
results=[]
for name,path in [('controls','coordinator23_cargo_pointer14/test_native.gd' if args.pointer else 'coordinator23_cargo_controls13/test_native.gd'),('hover','coordinator23_cargo_hover12/test_native.gd'),('return','coordinator23_cargo_return12/test_return_input.gd'),('invalidation','coordinator23_cargo_return12/invalidation/test_invalidation.gd')]:
    script=root/'outputs'/path;target=out/name;target.mkdir()
    cmd=[engine,'--headless','--main-pack',str(pack),'--script',str(script),'--','--qa-out='+str(target)]
    start=time.monotonic()
    with (target/'engine.log').open('w',encoding='utf8') as log:
        p=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=50)
    data=(target/'engine.log').read_text(encoding='utf8')
    result={'name':name,'code':p.returncode,'seconds':time.monotonic()-start,'script_sha256':sha(script),'pack_sha256':sha(pack),'error_log':any(x in data for x in ['SCRIPT ERROR','ERROR:','FAIL '])}
    results.append(result);print(json.dumps(result),flush=True)
    (out/'RESULT.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf8')
    assert p.returncode==0 and not result['error_log']
