"""ROOT ONLY. One exact PCK/window per invocation; never closes another process."""
from pathlib import Path
import argparse, ctypes, hashlib, json, subprocess, time

P=argparse.ArgumentParser()
P.add_argument('--pack',type=Path,required=True);P.add_argument('--sha256',required=True)
P.add_argument('--side',choices=['baseline','candidate'],required=True)
P.add_argument('--mode',choices=['perf','visual'],default='perf')
P.add_argument('--out',type=Path,required=True);P.add_argument('--cache-note',required=True)
a=P.parse_args();base=Path(__file__).resolve().parent;pack=a.pack.resolve();out=a.out.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(pack)==a.sha256.lower(),'PCK mismatch'
if a.side=='baseline':assert a.sha256.lower()=='8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741','Need accepted16 baseline'
receipt_path=pack.parent/'build_receipt.json';receipt=json.loads(receipt_path.read_text(encoding='utf-8-sig'))
assert next(v['sha256'] for v in receipt['artifacts'] if v['filename']==pack.name)==a.sha256.lower()
assert not out.exists(),'Use fresh output folder';out.mkdir(parents=True)
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
cmd=[str(engine),'--main-pack',str(pack),'--position','-32000,-32000','--resolution','1280x720','--fixed-fps','60','--rendering-method','forward_plus','--rendering-driver','vulkan','--script',str(base/'capture.gd'),'--','--qa-out='+str(out),'--qa-side='+a.side,'--qa-mode='+a.mode,'--qa-pack='+str(pack),'--qa-sha='+a.sha256.lower()]

class Counters(ctypes.Structure):
    _fields_=[('cb',ctypes.c_ulong),('PageFaultCount',ctypes.c_ulong),('PeakWorkingSetSize',ctypes.c_size_t),('WorkingSetSize',ctypes.c_size_t),('QuotaPeakPagedPoolUsage',ctypes.c_size_t),('QuotaPagedPoolUsage',ctypes.c_size_t),('QuotaPeakNonPagedPoolUsage',ctypes.c_size_t),('QuotaNonPagedPoolUsage',ctypes.c_size_t),('PagefileUsage',ctypes.c_size_t),('PeakPagefileUsage',ctypes.c_size_t),('PrivateUsage',ctypes.c_size_t)]
k=ctypes.WinDLL('kernel32',use_last_error=True);ps=ctypes.WinDLL('psapi',use_last_error=True)
k.OpenProcess.argtypes=[ctypes.c_ulong,ctypes.c_bool,ctypes.c_ulong];k.OpenProcess.restype=ctypes.c_void_p
k.CloseHandle.argtypes=[ctypes.c_void_p];ps.GetProcessMemoryInfo.argtypes=[ctypes.c_void_p,ctypes.POINTER(Counters),ctypes.c_ulong]
started=time.monotonic();rows=[];timed_out=False;handle=None
with (out/'engine.log').open('w',encoding='utf-8') as log:
    proc=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        handle=k.OpenProcess(0x410,False,proc.pid)
        while proc.poll() is None:
            if time.monotonic()-started>88:
                timed_out=True;proc.kill();proc.wait(timeout=5);break # Only this owned child.
            if handle:
                c=Counters();c.cb=ctypes.sizeof(c)
                if ps.GetProcessMemoryInfo(handle,ctypes.byref(c),ctypes.sizeof(c)):
                    rows.append({'utc':time.time(),'working_set_bytes':c.WorkingSetSize,'private_bytes':c.PrivateUsage,'peak_working_set_bytes':c.PeakWorkingSetSize})
            time.sleep(.05)
    finally:
        if handle:k.CloseHandle(handle)
run={'exit_code':proc.returncode,'timeout_seconds':88 if timed_out else None,'seconds':time.monotonic()-started,'command':cmd,'pid':proc.pid,'side':a.side,'mode':a.mode,'pack_sha256':a.sha256.lower(),'receipt_sha256':sha(receipt_path),'harness_sha256':sha(base/'capture.gd'),'cache_note':a.cache_note,'memory_samples':rows,'scope':'Sequential exact PCK, offscreen NO_FOCUS, original3NPC; no OS capture. Explicit QA logical input admission. Fixed60 simulation; measured wall/GPU times are actual.'}
(out/'RUN.json').write_text(json.dumps(run,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'exit':proc.returncode,'timeout':timed_out,'seconds':run['seconds'],'memory_samples':len(rows)}))
raise SystemExit(proc.returncode if not timed_out else 124)
