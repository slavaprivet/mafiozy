"""Root-only GPU31 acceptance. Preserves every existing process; never imports."""
from pathlib import Path
import argparse, hashlib, json, math, os, shlex, struct, subprocess, time

p = argparse.ArgumentParser()
p.add_argument('--out', required=True)
a = p.parse_args()
here = Path(__file__).resolve().parent
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
load = lambda f: json.loads(f.read_text(encoding='utf-8-sig'))
assembly_path = here / 'ASSEMBLY31.json'
assembly_sha = '3309bf75e46aab302793fab686373e4e8597ed714efb01f631117fdea0f93945'
pack_sha = '0bd000e02db726dd9e7eccff565982222ce8dc0ef5b950209edf0c0f600d945e'
qa_sha = '7364b6f2598576a596bf622e2eb985d70020081b279d52c9312d710aa260110f'
assert sha(assembly_path) == assembly_sha
assembly = load(assembly_path)
game = Path(assembly['game'])
pins = assembly['source_pins']
assert len(pins) == 272 and all(sha(game / n) == s for n, s in pins.items())
delivery_path = here / 'DELIVERY31.json'
delivery_sha = sha(delivery_path)
delivery = load(delivery_path)
assert delivery['assembly_sha256'] == assembly_sha and delivery['pck_sha256'] == pack_sha
pack = Path(delivery['pck'])
receipt = Path(delivery['build_receipt'])
assert sha(pack) == pack_sha
assert sha(receipt) == delivery['build_receipt_sha256'] == 'fa27ab4d982ce86c9d177bb66e885edb13f4c9864a9650645c063185ec7a2ad2'
qa = here / 'gpu_acceptance.gd'
assert sha(qa) == qa_sha
engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
assert sha(engine) == 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
out = Path(a.out).resolve()
assert out.parent == here and not out.exists(), 'Use a new direct child of the rear-lights output folder'
flags = subprocess.CREATE_NO_WINDOW

def inventory():
    script = '[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $rows=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match "Godot|MafioziPreview" } | Select-Object ProcessId,ParentProcessId,Name,CommandLine); ConvertTo-Json -InputObject $rows -Compress'
    result = subprocess.run(['powershell', '-NoProfile', '-Command', script], capture_output=True, encoding='utf-8-sig', timeout=15, creationflags=flags)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)

def permitted_manager(row):
    argv = shlex.split(row.get('CommandLine') or '', posix=False)
    return row['ProcessId'] == 45268 and row['Name'] == 'Godot_v4.6.3-stable_win64.exe' and len(argv) == 1

before = inventory()
assert all(permitted_manager(row) for row in before), 'Existing game/engine preserved; Root must release the GPU window: ' + str(before)
out.mkdir()
frozen_qa = out / 'gpu_acceptance.gd'
frozen_qa.write_bytes(qa.read_bytes())
command = [str(engine), '--path', str(game), '--main-pack', str(pack), '--resolution', '1280x720', '--script', str(frozen_qa), '--', '--run-id=.']
record = {'assembly_sha256': assembly_sha, 'delivery_sha256': delivery_sha, 'pack_sha256': pack_sha, 'build_receipt_sha256': sha(receipt), 'source_count': len(pins), 'source_pins': pins, 'qa_sha256': qa_sha, 'inventory_before': before, 'command': command, 'hard_timeout_seconds': 90, 'original_script_watchdog_seconds': 60, 'performance_scope': 'Existing paired feature-absent/off/on/off comparison; fixed car and camera only, full 8-building/3-NPC scene. No whole-city acceptance or automatic cost threshold.'}
started = time.monotonic()
with (out / 'engine.log').open('w', encoding='utf-8') as log:
    process = subprocess.Popen(command, cwd=out, stdout=log, stderr=subprocess.STDOUT, creationflags=flags)
    record['own_engine_pid'] = process.pid
    (out / 'STARTED.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'started': process.pid, 'out': str(out)}), flush=True)
    try:
        code = process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        record['timeout'] = True
        process.kill()  # Only the child created immediately above.
        code = process.wait(timeout=10)
record['seconds'] = time.monotonic() - started
record['exit_code'] = code
record['inventory_after'] = inventory()
record['exclusive_inventory_endpoints'] = all(permitted_manager(row) for row in record['inventory_after'])
record['source_changed'] = [n for n, s in pins.items() if not (game / n).is_file() or sha(game / n) != s]
record['pack_unchanged'] = sha(pack) == pack_sha
record['metadata_unchanged'] = sha(assembly_path) == assembly_sha and sha(delivery_path) == delivery_sha and sha(receipt) == delivery['build_receipt_sha256']
record['qa_unchanged'] = sha(qa) == qa_sha and sha(frozen_qa) == qa_sha
lines = (out / 'engine.log').read_text(encoding='utf-8', errors='replace').splitlines()
record['native_errors'] = [line for line in lines if any(t in line for t in ['SCRIPT ERROR', 'ERROR:', 'Parse Error'])]
result = load(out / 'RESULT.json') if (out / 'RESULT.json').exists() else {}
record['result'] = result
expected_pngs = {'night_rear_off', 'night_tail_on', 'night_braking', 'night_reversing', 'paired_reverse_off', 'paired_reverse_on'}
images = {}
for file in out.glob('*.png'):
    data = file.read_bytes()
    dimensions = list(struct.unpack('>II', data[16:24])) if len(data) >= 24 and data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR' else []
    images[file.stem] = {'sha256': sha(file), 'bytes': len(data), 'dimensions': dimensions}
record['capture_pngs'] = images
record['capture_complete'] = set(images) == expected_pngs and all(v['dimensions'] == [1280, 720] and v['bytes'] > 1024 for v in images.values())
report = result.get('report', {})
paired = report.get('gpu_comparison', {})
finite = lambda v: isinstance(v, (int, float)) and math.isfinite(v)
phase_names = ['without_rear_lamps', 'off_before', 'reverse_on', 'off_after']
phase_checks = {name: (paired.get(name, {}).get('frames') == 180 and all(finite(paired.get(name, {}).get(k)) for k in ['p50_ms', 'p95_ms', 'max_ms', 'drawcalls', 'triangles', 'memory_bytes']) and 0 < paired[name]['p50_ms'] <= paired[name]['p95_ms'] <= paired[name]['max_ms']) for name in phase_names}
activation = report.get('first_activation_frames', {})
activation_checks = {name: (activation.get(name, {}).get('frames') == 30 and all(finite(activation.get(name, {}).get(k)) for k in ['activation_frame_ms', 'p95_ms', 'max_ms'])) for name in ['tail_emission', 'brake_emission', 'reverse_emission_and_beam']}
record['performance_evidence_checks'] = {'paired_phases': phase_checks, 'first_activation': activation_checks, 'deltas_recorded': all(finite(paired.get(k)) for k in ['p95_delta_ms', 'feature_on_p95_delta_ms']), 'cost_acceptance': 'Root must assess recorded deltas and first-activation spikes; no invented threshold.'}
record['performance_evidence_complete'] = all(phase_checks.values()) and all(activation_checks.values()) and record['performance_evidence_checks']['deltas_recorded']
record['passed'] = code == 0 and not record.get('timeout') and not record['native_errors'] and not record['source_changed'] and record['pack_unchanged'] and record['metadata_unchanged'] and record['qa_unchanged'] and record['exclusive_inventory_endpoints'] and result.get('gpu') is True and result.get('checks', 0) >= 33 and result.get('failures') == [] and record['capture_complete'] and record['performance_evidence_complete']
record['visual_acceptance'] = 'Pending Root inspection of six real PNGs.'
(out / 'RUN.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: record[k] for k in ['passed', 'own_engine_pid', 'exit_code', 'seconds', 'native_errors', 'source_changed', 'capture_complete', 'performance_evidence_complete']}), flush=True)
raise SystemExit(0 if record['passed'] else 1)
