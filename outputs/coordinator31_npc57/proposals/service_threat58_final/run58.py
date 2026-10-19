"""Final merged service interruptions: explicit source manifest+SHA, no overlays."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time,zipfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=ROOT/'outputs/coordinator31_npc57/game'
SCHEDULER_SHA='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
MERGED_FLEE_PINS={
 'scripts/city/runtime/npc_threat_route30.gd':'6b330fbf8374f4fb95064970a383bda0d4abb1011a3c5e4c5fd2338e64fb5968',
 'scripts/city/runtime/npc_threat_life30.gd':'ad989e07fc03691bceca3e751f03d42496aefbc1eab5c37064eda4cc8b6d13ae',
}
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,ERRORS

def need(value,message):
 if not value:raise RuntimeError(message)
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,value):p.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def pins(directory):return {p.relative_to(directory).as_posix():sha(p) for p in directory.rglob('*') if p.is_file() and '.godot' not in p.relative_to(directory).parts}
def delta(a,b):return sorted(k for k in a.keys()|b.keys() if a.get(k)!=b.get(k))
def control_pins(paths):return {str(p.resolve()):sha(p) if p.is_file() else None for p in paths}

def prepare(args):
 need(re.fullmatch(r'[A-Za-z0-9_-]+',args.name),'Unique simple run name required')
 need(0<args.wait<=120,'Bounded scheduler wait required')
 manifest_path=args.expected_source.resolve();manifest_path.relative_to(ROOT)
 need(re.fullmatch(r'[a-f0-9]{64}',args.expected_sha256),'Explicit SHA256 required')
 need(sha(manifest_path)==args.expected_sha256,'Explicit merged manifest SHA mismatch')
 manifest=read(manifest_path);expected=manifest['source_pins']
 need(manifest.get('baseline')=='release57' and manifest.get('source_count')==len(expected) and expected,'Expected merged release57-based source manifest required')
 need(all(expected.get(rel)==value for rel,value in MERGED_FLEE_PINS.items()),'Known flee fix must be MERGED in expected source; no runtime overlay')
 need(pins(GAME)==expected,'Exact merged source required; no child started')
 assembly_path=ROOT/'outputs/coordinator31_release57/ASSEMBLY.json';assembly=read(assembly_path)
 need(assembly['revision']=='s01-20261015-residents57','Unexpected ordinary launch baseline')
 need(assembly['source_pins']==manifest['baseline_source_pins'],'Candidate baseline manifest mismatch')
 flags=list(assembly['launch_arguments'])
 required={'--city-qa=10','--city-venue-staff29=1','--city-venue-sites29=1','--city-hp=100','--city-threat30=1','--city-physical-dispatch30=1','--city-multi-lifecycle30=1','--city-simple-hospital=1'}
 need(required.issubset(flags),'Ordinary10+12 behavior flags missing')
 keys=[arg.split('=',1)[0] for arg in flags]
 need(len(keys)==len(set(keys)) and all(re.fullmatch(r'--city-[a-z0-9-]+(?:=[^\s]+)?',arg) for arg in flags),'Invalid ordinary flags')
 need(not any('seed' in key or key in {'--city-wallet-start','--city-energy-start','--city-resident-name','--city-play-check','--city-quit-after'} for key in keys),'No global behavioral overrides')
 scheduler=ROOT/'tools/godot/test_scheduler.py';lock=ROOT/'docs/godot/ENGINE_LOCK.json'
 engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
 need(sha(scheduler)==SCHEDULER_SHA,'Scheduler pin changed')
 need(sha(engine)==read(lock)['editor']['gui']['sha256'],'Engine pin changed')
 files=[HERE/name for name in ['entry58.gd','observer58.gd','observer_base58.gd','run58.py','prepare_final58.py','PREPARATION58.json']]
 controls=control_pins([*files,manifest_path,assembly_path,scheduler,lock,engine,ROOT/'godot/current_version.json'])
 need(all(value is not None for value in controls.values()),'Missing required control')
 # Every non-engine control is preserved in the immutable HARNESS archive,
 # including manifests, scheduler, lock and F5. The engine is pinned separately.
 harness={Path(path).relative_to(ROOT).as_posix():digest for path,digest in controls.items() if Path(path)!=engine.resolve()}
 run=HERE/'runs'/args.name;need(not run.exists(),'Preserve existing run')
 flags+=['--qa-service-kind='+args.case,'--qa-service-resident='+args.resident,'--qa-out='+str(run)]
 command=[str(engine),'--headless','--path',str(GAME),'--script',str(HERE/'entry58.gd'),'--',*flags]
 return run,expected,harness,controls,command,flags,engine,manifest_path

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('name');parser.add_argument('--case',choices=['shop','restaurant'],required=True)
 parser.add_argument('--expected-source',type=Path,required=True)
 parser.add_argument('--expected-sha256',type=str.lower,required=True)
 parser.add_argument('--resident',choices=['resident_'+str(i) for i in range(1,11)],default='resident_1')
 parser.add_argument('--wait',type=int,default=30);parser.add_argument('--go',action='store_true')
 args=parser.parse_args()
 run,expected,harness,controls,command,flags,engine,manifest_path=prepare(args)
 if not args.go:
  print(json.dumps({'status':'PREPARED_NOT_NATIVE_TESTED','case':args.case,'source_count':len(expected),'expected_source':str(manifest_path),'expected_source_sha256':args.expected_sha256,'harness_pins':harness,'control_count':len(controls),'all_non_engine_controls_archived':True,'engine_started':False,'overlay':False},ensure_ascii=True));return 0
 need(shutil.disk_usage(ROOT).free>256*1024**2,'Require256MiB disk before native run')
 run.mkdir(parents=True,exist_ok=False)
 save(run/'SOURCE.json',expected);save(run/'CONTROL_PINS.json',controls);save(run/'HARNESS.json',harness);save(run/'FLAGS.json',flags)
 with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as z:
  for name in harness:z.write(ROOT/name,name)
 result={'passed':False,'case':args.case,'resident':args.resident,'project':str(GAME),'command':command,
  'mode':'headless','access':'read','performance_accepted':False,'source_stage':'merged58',
  'expected_source':str(manifest_path),'expected_source_sha256':args.expected_sha256,'source_count':len(expected),
  'engine_sha256':sha(engine),'scheduler_sha256':SCHEDULER_SHA,'overlay':False,
  'project_copied':False,'production_modified':False,'user_processes_closed':False,
  'all_non_engine_controls_archived':True,'harness_archive_sha256':sha(run/'HARNESS.zip'),'engine_started':False}
 try:
  with Lease('headless',GAME,'read',args.wait) as lease:
   need(pins(GAME)==expected and control_pins([Path(p) for p in controls])==controls,'Source/control drift before child')
   result['lease']=lease.request
   with (run/'stdout.log').open('wb') as out,(run/'stderr.log').open('wb') as err:
    start=time.monotonic();child=subprocess.Popen(command,cwd=GAME,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
    result['engine_started']=True
    try:
     result['child']=lease.register_child(child)
     while child.poll() is None:
      need(time.monotonic()-start<=310,'Owned child watchdog310s')
      need((run/'stderr.log').stat().st_size==0,'Native stderr; preserve failed run')
      need(sum(p.stat().st_size for p in run.rglob('*') if p.is_file())<=64*1024**2,'Output exceeds64MiB')
      need(shutil.disk_usage(ROOT).free>128*1024**2,'Disk reserve below128MiB')
      time.sleep(.2)
    finally:
     if child.poll() is None:
      child.terminate()
      try:child.wait(timeout=10)
      except subprocess.TimeoutExpired:child.kill();child.wait(timeout=5)
     result.update(exit_code=child.returncode,elapsed_seconds=time.monotonic()-start)
   native=read(run/'SERVICE_THREAT58.json')
   result.update(native_sha256=sha(run/'SERVICE_THREAT58.json'),native_passed=native.get('passed') is True,checks=native.get('checks',{}),semantic_reason=native.get('reason'))
 except Exception as error:result['error']=type(error).__name__+': '+str(error)
 finally:
  after=pins(GAME);after_controls=control_pins([Path(p) for p in controls]);after_harness={p:sha(ROOT/p) if (ROOT/p).is_file() else None for p in harness}
  save(run/'SOURCE_AFTER.json',after);save(run/'CONTROL_PINS_AFTER.json',after_controls);save(run/'HARNESS_AFTER.json',after_harness)
  result['source_drift']=delta(expected,after);result['control_drift']=delta(controls,after_controls);result['harness_drift']=delta(harness,after_harness)
  result['errors']=[line for name in ['stdout.log','stderr.log'] if (run/name).exists() for line in (run/name).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
  result['stderr_bytes']=(run/'stderr.log').stat().st_size if (run/'stderr.log').exists() else None
  result['passed']=bool(result.get('exit_code')==0 and result.get('native_passed') is True and result.get('checks') and all(v is True for v in result['checks'].values()) and not result.get('error') and not result['errors'] and result['stderr_bytes']==0 and not result['source_drift'] and not result['control_drift'] and not result['harness_drift'])
  save(run/'RUN.json',result)
 print(json.dumps({k:result.get(k) for k in ['passed','case','semantic_reason','checks','error','source_drift','control_drift','harness_drift']},ensure_ascii=True))
 return 0 if result['passed'] else 1

if __name__=='__main__':
 try:sys.exit(main())
 except Exception as error:print(json.dumps({'passed':False,'error':str(error),'engine_started':False}));sys.exit(1)
