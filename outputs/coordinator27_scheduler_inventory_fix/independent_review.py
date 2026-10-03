"""Read-only scheduler review; only direct owned Python/PowerShell children."""
from pathlib import Path
import hashlib,importlib.util,json,os,queue,shutil,subprocess,sys,threading,time
from unittest.mock import patch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
TARGET=ROOT/'tools/godot/test_scheduler.py'
EXPECTED='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(TARGET)==EXPECTED
spec=importlib.util.spec_from_file_location('review_scheduler',TARGET)
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
checks=[]
def passed(label):checks.append(label)
def result(code,stdout=b'[]',stderr=b''):
    return subprocess.CompletedProcess([],code,stdout,stderr)
with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.time,'monotonic',side_effect=[0,0,6,14]),patch.object(s.subprocess,'run',side_effect=[result(75,b'[{"pid":1}]'),result(75,b'[{"pid":2}]'),result(0,b'[{"pid":3}]')]) as run:
    assert s.inventory()==[{'pid':3}]
    assert [c.kwargs['timeout'] for c in run.call_args_list]==[15,9,1]
passed('partial failed snapshots discarded; decreasing shared15s budget [15,9,1]')
with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.time,'monotonic',side_effect=[0,0,16]),patch.object(s.subprocess,'run',return_value=result(75)) as run:
    try:s.inventory();raise AssertionError('must fail')
    except RuntimeError as e:assert 'deadline expired' in str(e)
    assert run.call_count==1
passed('budget expired between attempts prevents a second launch')
for code in [1,2,74,76]:
    with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.subprocess,'run',return_value=result(code,b'[{"pid":1}]',b'other failure')) as run:
        try:s.inventory();raise AssertionError('must fail')
        except RuntimeError as e:assert 'other failure' in str(e)
        assert run.call_count==1
passed('all tested non75 failures deny without retry despite partial JSON')
with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.subprocess,'run',side_effect=subprocess.TimeoutExpired('pwsh',15)) as run:
    try:s.inventory();raise AssertionError('must fail')
    except subprocess.TimeoutExpired:pass
    assert run.call_count==1
passed('subprocess timeout propagates failclosed without retry')
for payload in [b'{"pid":1}',b'[',b'']:
    with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.subprocess,'run',return_value=result(0,payload)) as run:
        try:s.inventory();raise AssertionError('must fail')
        except (RuntimeError,json.JSONDecodeError):pass
        assert run.call_count==1
passed('malformed/non-list successful output denied')
with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.subprocess,'run',return_value=result(75)) as run:
    try:s.inventory();raise AssertionError('must fail')
    except RuntimeError as e:assert 'exit 75' in str(e)
    assert run.call_count==3
passed('race retries capped at exactly three')

# Obtain the exact PowerShell classifier from the pinned production function.
with patch.object(s.shutil,'which',return_value='pwsh'),patch.object(s.subprocess,'run',return_value=result(0)) as run:
    s.inventory(123)
    production_code=run.call_args.args[0][-1]
body=production_code.split(' | ForEach-Object ',1)[1]
pwsh=shutil.which('pwsh')
child=None;worker=None
native={}
start=time.monotonic()
try:
    child=subprocess.Popen([sys.executable,'-B','-c','import sys; sys.stdin.read(1)'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW)
    # The first real CIM row (this parent) is live and would be an unsafe partial
    # snapshot. The second is a genuine captured child that exits after snapshot.
    code=("$ErrorActionPreference='Stop';[Console]::OutputEncoding=[Text.UTF8Encoding]::new();"
          f"$first=Get-CimInstance Win32_Process -Filter 'ProcessId={os.getpid()}';"
          f"$second=Get-CimInstance Win32_Process -Filter 'ProcessId={child.pid}';"
          "if($null -eq $first -or $null -eq $second){throw 'CIM snapshot missing'};"
          "[Console]::WriteLine('SNAPSHOT_READY');[Console]::ReadLine()|Out-Null;"
          "$rows=@(@($first,$second) | ForEach-Object "+body)
    (HERE/'independent_native_classifier.ps1').write_text(code,encoding='utf-8')
    worker=subprocess.Popen([pwsh,'-NoProfile','-NonInteractive','-Command',code],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8',creationflags=subprocess.CREATE_NO_WINDOW)
    first_line=queue.Queue()
    threading.Thread(target=lambda:first_line.put(worker.stdout.readline()),daemon=True).start()
    assert first_line.get(timeout=10).strip()=='SNAPSHOT_READY'
    child.stdin.write(b'x');child.stdin.flush()
    assert child.wait(timeout=5)==0
    stdout,stderr=worker.communicate(input='continue\n',timeout=10)
    assert worker.returncode==75,(worker.returncode,stdout,stderr)
    assert not stdout.strip() and not stderr.strip(),(stdout,stderr)
    native={'captured_child_pid':child.pid,'captured_live_parent_pid':os.getpid(),'child_exit':child.returncode,'powershell_exit':worker.returncode,'partial_json_emitted':False,'stderr_bytes':len(stderr.encode()),'elapsed_seconds':time.monotonic()-start}
    passed('actual two-row CIM snapshot, own child exit, exact classifier exit75, no partial JSON')
finally:
    for owned in [worker,child]:
        if owned is not None and owned.poll() is None:owned.kill();owned.wait(timeout=5)
fresh=s.inventory()
assert sha(TARGET)==EXPECTED
report={'passed':True,'checks':checks,'native':native,'fresh_inventory_pids':[r['pid'] for r in fresh],'source_unchanged':True,'scheduler_sha256':EXPECTED,'before_sha256':sha(HERE/'scheduler_before.py'),'runner_sha256':sha(__file__),'powershell_sha256':sha(HERE/'independent_native_classifier.ps1')}
(HERE/'INDEPENDENT_RESULT.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(report,indent=2))
