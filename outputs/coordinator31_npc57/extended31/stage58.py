"""Import only the owned candidate, then pin its complete delta against frozen57."""
import argparse,hashlib,json,os,pathlib,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
GAME=HERE.parent/'game'
FROZEN=ROOT/'outputs/coordinator31_release57/game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,ERRORS
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def pins(p):return {f.relative_to(p).as_posix():sha(f) for f in p.rglob('*') if f.is_file() and '.godot' not in f.parts}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('name');p.add_argument('--expected',type=pathlib.Path,required=True);a=p.parse_args()
    assert a.name and all(c.isalnum() or c in '_-' for c in a.name)
    out=HERE/a.name;out.mkdir(exist_ok=False)
    assembly=read(FROZEN.parent/'ASSEMBLY.json');frozen=pins(FROZEN);assert frozen==assembly['source_pins']
    control=sha(ROOT/'godot/current_version.json');before=pins(GAME);assert before==read(a.expected)['source_pins']
    save(out/'SOURCE_BEFORE.json',before)
    exe=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    assert sha(exe)==read(ROOT/'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
    result={'passed':False,'gameplay_acceptance_pending':True,'f5_changed':False}
    try:
        with Lease('headless',GAME,'write',60) as lease:
            assert pins(GAME)==before
            command=[str(exe),'--headless','--editor','--path',str(GAME),'--quit'];result['command']=command
            with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
                started=time.monotonic();child=subprocess.Popen(command,cwd=GAME,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-started>120:raise TimeoutError('Owned import deadline')
                        time.sleep(.2)
                finally:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
                result.update(exit_code=child.returncode,elapsed_s=time.monotonic()-started)
            after=pins(GAME)
            differences={r for r in before.keys()|after.keys() if before.get(r)!=after.get(r)}
            assert differences <= {'scripts/hospital/npc_door_clearance31.gd.uid'},'Unexpected import source change: '+str(differences)
            errors=[line for name in ['stdout.log','stderr.log'] for line in (out/name).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
            result.update(import_source_changes=sorted(differences),errors=errors,stderr_bytes=(out/'stderr.log').stat().st_size)
            assert result['exit_code']==0 and not errors and result['stderr_bytes']==0
            assert pins(FROZEN)==frozen and sha(ROOT/'godot/current_version.json')==control
            delta={r:{'base_sha256':frozen.get(r),'candidate_sha256':after.get(r)} for r in sorted(frozen.keys()|after.keys()) if frozen.get(r)!=after.get(r)}
            manifest={'source_pins':after,'baseline':'release57','baseline_source_pins':frozen,'changes':delta,'gameplay_acceptance_pending':True,'source_count':len(after),'import_receipt':str(out/'RESULT.json')}
            save(out/'CANDIDATE58.json',manifest);result.update(passed=True,source_count=len(after),changes=list(delta))
    except Exception as error:result['error']=type(error).__name__+': '+str(error)
    save(out/'SOURCE_AFTER.json',pins(GAME));save(out/'RESULT.json',result)
    print(json.dumps({k:result.get(k) for k in ['passed','error','source_count','changes','elapsed_s']},ensure_ascii=False));return 0 if result['passed'] else 1
if __name__=='__main__':sys.exit(main())
