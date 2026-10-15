from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
WORK, ROOT = HERE.parents[1], HERE.parents[3]
GAME = WORK / 'game'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path, data): path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

def main():
    name = sys.argv[1]
    assert name.replace('_','').isalnum()
    out = HERE / 'runs' / name
    out.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((WORK / 'extended31/stage58_06/CANDIDATE58.json').read_text())
    before = {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.parts}
    assert before == manifest['source_pins']
    patch = json.loads((HERE / 'PATCH.json').read_text())
    with zipfile.ZipFile(HERE / 'overlay58.zip', 'w', zipfile.ZIP_STORED) as pack:
        for relative, item in patch.items():
            assert sha(GAME / relative) == item['base_sha256']
            assert sha(HERE / 'patch' / relative) == item['candidate_sha256']
            pack.write(HERE / 'patch' / relative, relative)
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    command = [sys.executable, str(ROOT / 'tools/godot/test_scheduler.py'), 'run', '--mode','headless', '--project',str(GAME),
               '--access','read','--wait-seconds','120','--timeout','30','--out',str(out / 'scheduler'), '--',str(engine),
               '--headless','--path',str(GAME),'--script',str(HERE / 'check58_v2.gd'),'--','--city-simple-hospital=1',
               '--city-medical-threshold=0.5','--city-hp=100','--city-energy-drain-per-m=0.05','--medical-output='+str(out/'BOUNDARY58.json')]
    result = subprocess.run(command, capture_output=True, timeout=180)
    (out/'adapter_stdout.log').write_bytes(result.stdout)
    (out/'adapter_stderr.log').write_bytes(result.stderr)
    after = {r:sha(GAME/r) for r in before}
    native = json.loads((out/'BOUNDARY58.json').read_text(encoding='utf-8')) if (out/'BOUNDARY58.json').exists() else {}
    passed = result.returncode==0 and before==after and native.get('passed',False)
    save(out/'RESULT.json', {'passed':passed,'exit_code':result.returncode,'source_drift':before!=after,
        'source_manifest_sha256':sha(WORK/'extended31/stage58_06/CANDIDATE58.json'),
        'patch_sha256':sha(HERE/'PATCH.json'),'overlay_sha256':sha(HERE/'overlay58.zip'),
        'test_sha256':sha(HERE/'check58_v2.gd'),'engine_sha256':sha(engine),'checks':len(native.get('checks',[])),
        'scope':'native boundary/priority component; real shot/physical medical cycle pending'})
    print(json.dumps({'passed':passed,'checks':len(native.get('checks',[])),'output':str(out)}))
    return 0 if passed else 1

if __name__=='__main__': sys.exit(main())
