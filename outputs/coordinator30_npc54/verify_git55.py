import hashlib,json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[2];REL=ROOT/'outputs/coordinator30_release55'
manifest=json.loads((REL/'ASSEMBLY.json').read_text(encoding='utf-8'));expected={'outputs/coordinator30_release55/game/'+k:v for k,v in manifest['source_pins'].items()}
for name in ['ASSEMBLY.json','bootstrap_play55.gd']:
    expected['outputs/coordinator30_release55/'+name]=hashlib.sha256((REL/name).read_bytes()).hexdigest()
expected['godot/current_version.json']=hashlib.sha256((ROOT/'godot/current_version.json').read_bytes()).hexdigest()
entries=subprocess.check_output(['git','ls-files','-s','-z'],cwd=ROOT).split(b'\0');index={}
for entry in entries:
    if not entry:continue
    info,path=entry.split(b'\t',1);parts=info.split();index[path.decode('utf-8')]=parts[1].decode()
process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
bad=[]
for path,pin in expected.items():
    oid=index.get(path)
    if oid is None:bad.append([path,'missing']);continue
    process.stdin.write((oid+'\n').encode());process.stdin.flush()
    header=process.stdout.readline().split();size=int(header[2]);digest=hashlib.sha256()
    while size:
        chunk=process.stdout.read(min(size,1024*1024));assert chunk;digest.update(chunk);size-=len(chunk)
    assert process.stdout.read(1)==b'\n'
    if digest.hexdigest()!=pin:bad.append([path,'index_bytes_differ'])
process.stdin.close();process.wait()
result={'exact_staged_release_pins':len(expected),'mismatches':bad,'passed':not bad};(REL/'GIT_SOURCE_VERIFY.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result));sys.exit(bool(bad))
