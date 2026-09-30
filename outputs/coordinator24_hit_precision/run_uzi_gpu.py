"""Prepared root-only bounded GPU observer. Never kills an existing Godot process."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, time

p = argparse.ArgumentParser()
p.add_argument('--game', required=True)
p.add_argument('--assembly', required=True)
p.add_argument('--assembly-sha', required=True)
p.add_argument('--pack')
p.add_argument('--pack-sha')
p.add_argument('--expected-revision', required=True)
p.add_argument('--out', required=True)
p.add_argument('--test-sha', required=True)
p.add_argument('--allow-existing-pid', action='append', type=int, default=[])
a = p.parse_args()
here = Path(__file__).resolve().parent
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assembly_path = Path(a.assembly).resolve()
assert sha(assembly_path) == a.assembly_sha, 'Explicit frozen assembly SHA required'
assembly = json.loads(assembly_path.read_text(encoding='utf-8-sig'))
expected = assembly['source_pins']
assert len(expected) == int(assembly['source_count']) > 0
game = Path(a.game).resolve()
if 'game' in assembly:
    assert game == Path(assembly['game']).resolve(), 'Game must match frozen source receipt'
for name in expected:
    assert (game/name).resolve().is_relative_to(game)

def pins():
    return {path.relative_to(game).as_posix(): sha(path) for path in game.rglob('*')
            if path.is_file() and '.godot' not in path.parts and 'exports' not in path.parts
            and path.suffix != '.uid'}

def inventory():
    cmd = ('[Console]::OutputEncoding = [Text.UTF8Encoding]::new(); '
           'Get-CimInstance Win32_Process | Where-Object { $_.Name -match "Godot" } '
           '| Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress')
    got = subprocess.run(['powershell','-NoProfile','-Command',cmd],capture_output=True,
                         encoding='utf-8',errors='replace',timeout=15,
                         creationflags=subprocess.CREATE_NO_WINDOW)
    assert got.returncode == 0, 'Fresh inventory required'
    parsed = json.loads(got.stdout) if got.stdout.strip() else []
    return [parsed] if isinstance(parsed,dict) else parsed

before = pins()
assert all(before.get(name)==digest for name,digest in expected.items()), 'Frozen gameplay source pins mismatch'
generated = {'scripts/weapons/scope_optic.svg.import':'0081075e89bfbdcb69ea6dea5a1e021a38fa40a734c0a732cbdab2eac00fb006'}
extras = {name:digest for name,digest in before.items() if name not in expected}
assert all((name in generated and digest==generated[name]) or name.startswith(('tools/','docs/'))
           for name,digest in extras.items()), 'Unlisted gameplay source outside frozen closure'
test = here/'test_uzi_precision.gd'
assert sha(test) == a.test_sha, 'Explicit external harness SHA required'
pack = Path(a.pack).resolve() if a.pack else None
assert bool(pack) == bool(a.pack_sha), 'Pack path and exact SHA must be supplied together'
if pack:
    assert pack.is_file() and sha(pack)==a.pack_sha, 'Frozen compiled PCK required'
out = Path(a.out).resolve()
assert out.is_relative_to(here) and not out.exists(), 'Fresh QA evidence directory required'
existing = inventory()
unexpected = [row for row in existing if int(row['ProcessId']) not in a.allow_existing_pid]
assert not unexpected, 'Root must resolve/explicitly acknowledge fresh existing inventory before GPU: '+str(unexpected)
out.mkdir(parents=True)
(out/'TEST_SOURCE.gd').write_bytes(test.read_bytes())
engine = Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
assert engine.is_file()
cmd = [str(engine),'--path',str(game),'--position','-32000,-32000','--resolution','1280x720']
if pack: cmd += ['--main-pack',str(pack)]
cmd += ['--script',str(test),'--','--out='+str(out),'--expected-revision='+a.expected_revision]
if pack: cmd += ['--expect-compiled']
record = {'mode':'compiled' if pack else 'source','command':cmd,'game':str(game),
          'assembly':str(assembly_path),'assembly_sha256':a.assembly_sha,
          'source_count':len(expected),'all_source_before':before,'non_runtime_extra_pins':extras,
          'test_sha256':a.test_sha,'pack':str(pack) if pack else None,'pack_sha256':a.pack_sha,
          'concurrency_inventory_before':existing,'explicitly_allowed_existing_pids':a.allow_existing_pid,
          'GPU_runs':1,'hard_watchdog_seconds':110,'performance_acceptance':False,
          'scope':'Diagnostic render observer; root must schedule single sequential GPU. Does not assert physical OS focus/input or city-wide FPS acceptance.'}
(out/'RUN_STARTED.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lock = here/'OWN_GPU_OBSERVER_RUNNING.lock'
fd = os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
os.write(fd,str(os.getpid()).encode()); os.close(fd)
started=time.monotonic()
code=-998
try:
    with (out/'engine.log').open('w',encoding='utf-8') as log:
        proc=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,
                              creationflags=subprocess.CREATE_NO_WINDOW)
        record['own_engine_pid']=proc.pid
        print(json.dumps({'engine_pid':proc.pid,'out':str(out)}),flush=True)
        try: code=proc.wait(timeout=110)
        except subprocess.TimeoutExpired:
            proc.kill() # Only this owned handle, never a foreign process.
            proc.wait(timeout=10)
            code=-999
finally:
    lock.unlink(missing_ok=True)
after=pins()
logtext=(out/'engine.log').read_text(encoding='utf-8',errors='replace')
record.update(exit_code=code,seconds=time.monotonic()-started,
              all_source_after=after,
              changed=sorted(name for name in before.keys()|after.keys() if before.get(name)!=after.get(name)),
              test_after_sha256=sha(test),assembly_after_sha256=sha(assembly_path),
              pack_after_sha256=sha(pack) if pack else None,
              concurrency_inventory_after=inventory(),
              native_errors=any(x in logtext for x in ['SCRIPT ERROR','ERROR:','Parse Error']))
if (out/'RESULT.json').is_file():
    result=json.loads((out/'RESULT.json').read_text(encoding='utf-8-sig'))
    record.update(behavior_pass=result.get('passed',False),checks=result.get('checks',0),
                  errors=result.get('errors',[]),actual_shots=len(result.get('shots',[])),native_contacts=len(result.get('contacts',[])))
if (out/'GPU_METRICS.json').is_file():
    metrics=json.loads((out/'GPU_METRICS.json').read_text(encoding='utf-8-sig'))
    record.update(render_samples=len(metrics.get('samples',[])),gpu_telemetry_available=metrics.get('gpu_telemetry_available',False),
                  measured_phase_names=[x['name'] for x in metrics.get('phases',[])])
record['images']={path.name:sha(path) for path in out.glob('*.png')}
record['passed']=(code==0 and not record['changed'] and not record['native_errors']
                  and record.get('behavior_pass',False) and record.get('render_samples',0)>0
                  and len(record['images'])==2 and record['test_after_sha256']==a.test_sha
                  and record['assembly_after_sha256']==a.assembly_sha
                  and record['pack_after_sha256']==a.pack_sha)
(out/'RUN.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k not in ['all_source_before','all_source_after','command','concurrency_inventory_before','concurrency_inventory_after']},ensure_ascii=False),flush=True)
raise SystemExit(0 if record['passed'] else 1)
